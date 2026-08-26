#!/usr/bin/env bash
#
# publish-repo.sh — Publish a built OSTree commit and/or TEZI installer to
# the EdgeFirst software repository (S3 + CloudFront, see
# github.com/EdgeFirstAI/terraform-edgefirst-repo / ~/terraform/edgefirst-repo
# for the infra it targets), for self-hosted OTA + network installs.
#
# This is the one canonical publish path for every EdgeFirst-Torizon build —
# run it by hand, or call it unmodified from CI (Jenkins, GitHub Actions):
# every caller gets the same OSTree branch/version/delta handling and the
# same TEZI feed layout, instead of each CI job growing its own variant.
#
# Deliberately NOT Torizon Cloud OTA (see torizon-walnascar's deploy-ota.sh
# for that model) — this publishes to its own S3 bucket/CloudFront
# distribution, kept separate from torizon-maivin's (bucket "maivin",
# maivin.deepviewml.com).
#
# Adapted from torizon-maivin's Jenkins OSTree + Publish stages
# (torizon-maivin/.repo/manifests/Jenkinsfile), generalized to run
# identically on a persistent build agent (Jenkins) or an ephemeral one
# (GitHub Actions runners, ad hoc `repo sync` checkouts):
#
#   1. Ensure a local OSTree staging repo exists and has history to diff
#      against. If one isn't already on disk (ephemeral runner, first run
#      on a new agent), restore it from S3 first rather than initializing
#      empty — `ostree static-delta generate` only produces a real
#      incremental delta when the ref's parent commit is present locally;
#      losing that history silently degrades every delta to a full-content
#      delta, which still works but defeats the point of OTA deltas.
#   2. pull-local the build's OSTree commit into that staging repo
#   3. commit it onto a per-machine/channel branch with version metadata
#   4. generate a static delta, update the repo summary
#   5. sync the staging repo to s3://$S3_BUCKET/ostree (additive: no
#      --delete — ostree's object store is content-addressed and old
#      objects are still referenced by history/deltas)
#   6. extract the TEZI tarball and publish it to s3://$S3_BUCKET/tezi,
#      regenerating the shared image_list.json feed index by querying S3
#      for what's already published (never re-downloads prior multi-
#      hundred-MB tarballs just to list them) — feed format per
#      https://developer.toradex.com/easy-installer/toradex-easy-installer/toradex-easy-installer-configuration-files/
#   7. invalidate CloudFront for the paths that changed
#   8. (unless --skip-verify) HEAD the published URLs through CloudFront —
#      informational only: edge propagation can lag a few seconds after
#      invalidation, so this warns rather than fails the run.
#
# All settings are environment variables so CI systems can set them the
# same way they already set MACHINE/EULA for bitbake (Jenkins
# `environment {}` blocks, GitHub Actions `env:`), with no flags required
# beyond selecting what to publish.
#
# Usage:
#   MACHINE=verdin-imx8mp ./publish-repo.sh          # publish ostree + tezi
#   MACHINE=verdin-imx8mp ./publish-repo.sh -n       # dry run
#   MACHINE=verdin-imx8mp ./publish-repo.sh --ostree-only
#   MACHINE=verdin-imx8mp ./publish-repo.sh --tezi-only
#   MACHINE=verdin-imx95 CHANNEL=release VERSION=2026.09.0 ./publish-repo.sh
#
# Required:
#   MACHINE                     Toradex machine name (e.g. verdin-imx8mp)
#
# Build layout (defaults match this manifest's own checkout; override for
# a differently-laid-out CI workspace):
#   BUILD_DIR                   default: <script's repo root>/build-$MACHINE
#   IMAGES_DIR                  default: $BUILD_DIR/deploy/images/$MACHINE
#   OSTREE_REPO                 default: $IMAGES_DIR/ostree_repo
#   OSTREE_REF                  default: auto-detected (must be the only ref
#                                under $OSTREE_REPO/refs/heads if unset)
#
# Publish target:
#   S3_BUCKET                   default: edgefirst-repo
#   S3_REGION                   default: us-west-2
#   CLOUDFRONT_DISTRIBUTION_ID  default: ENV44D23AY6RF (repo.edgefirst.ai)
#   PUBLIC_URL                  default: https://repo.edgefirst.ai
#
# OSTree versioning:
#   CHANNEL                     default: develop
#   OSTREE_STAGING_REPO         default: $HOME/ostree/edgefirst-torizon
#   OSTREE_PUBLISH_BRANCH       default: torizon/edgefirst/$MACHINE/$CHANNEL
#   VERSION                     default: $(date +%Y.%m.%d)-$MACHINE
#   MESSAGE                     default: "torizon-minimal $VERSION ($MACHINE)"
#
set -euo pipefail

# BASH_SOURCE doesn't follow symlinks, and this script is checked out at
# layers/edgefirst-yocto/scripts/ then linked to the checkout root as
# ./publish-repo.sh — resolve the real path first or REPO_ROOT silently
# climbs from the symlink's directory instead.
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"

# --- Configuration (override via environment) --------------------------------
MACHINE="${MACHINE:-}"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build-${MACHINE}}"
IMAGES_DIR="${IMAGES_DIR:-${BUILD_DIR}/deploy/images/${MACHINE}}"
OSTREE_REPO="${OSTREE_REPO:-${IMAGES_DIR}/ostree_repo}"
OSTREE_REF="${OSTREE_REF:-}"     # auto-detected from the build repo if empty

CHANNEL="${CHANNEL:-develop}"
OSTREE_STAGING_REPO="${OSTREE_STAGING_REPO:-${HOME}/ostree/edgefirst-torizon}"
OSTREE_PUBLISH_BRANCH="${OSTREE_PUBLISH_BRANCH:-torizon/edgefirst/${MACHINE}/${CHANNEL}}"

S3_BUCKET="${S3_BUCKET:-edgefirst-repo}"
S3_REGION="${S3_REGION:-us-west-2}"
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-ENV44D23AY6RF}"
PUBLIC_URL="${PUBLIC_URL:-https://repo.edgefirst.ai}"

TEZI_STAGING_DIR="${TEZI_STAGING_DIR:-${REPO_ROOT}/publish/tezi}"

DO_OSTREE=1
DO_TEZI=1
DO_VERIFY=1
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        --ostree-only) DO_TEZI=0 ;;
        --tezi-only) DO_OSTREE=0 ;;
        --skip-verify) DO_VERIFY=0 ;;
        -h|--help) sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed '$d'; exit 0 ;;
        *) echo "ERROR: unknown argument: $arg (see --help)" >&2; exit 2 ;;
    esac
done

die() { echo "ERROR: $*" >&2; exit "${2:-1}"; }
run() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '    [dry-run] %q' "$@"; echo
    else
        "$@"
    fi
}

# --- Preflight ----------------------------------------------------------------
[[ -n "$MACHINE" ]] || die "MACHINE must be set, e.g. MACHINE=verdin-imx8mp ./publish-repo.sh"
command -v aws    >/dev/null 2>&1 || die "aws CLI not found on PATH"
command -v ostree >/dev/null 2>&1 || die "ostree CLI not found on PATH"
command -v tar     >/dev/null 2>&1 || die "tar not found on PATH"
[[ -d "$IMAGES_DIR" ]] || die "image deploy dir not found: $IMAGES_DIR (build torizon-minimal for $MACHINE first?)"

VERSION="${VERSION:-}"
OSTREE_PUBLISHED=0
TEZI_PUBLISHED=0

# --- OSTree publish -------------------------------------------------------
publish_ostree() {
    [[ -d "$OSTREE_REPO" ]] || die "ostree_repo not found at: $OSTREE_REPO"

    if [[ -z "$OSTREE_REF" ]]; then
        mapfile -t _refs < <(find "$OSTREE_REPO/refs/heads" -type f -printf '%P\n' 2>/dev/null | sort)
        case "${#_refs[@]}" in
            0) die "no OSTree refs found under $OSTREE_REPO/refs/heads" ;;
            1) OSTREE_REF="${_refs[0]}" ;;
            *) { echo "ERROR: multiple OSTree refs found; set OSTREE_REF to one of:" >&2
                 printf '  %s\n' "${_refs[@]}" >&2; } ; exit 2 ;;
        esac
    fi

    local rev
    rev="$(ostree --repo="$OSTREE_REPO" rev-parse "$OSTREE_REF")"

    local version="${VERSION:-$(date +%Y.%m.%d)-${MACHINE}}"
    local message="${MESSAGE:-torizon-minimal ${version} (${MACHINE})}"

    cat <<EOF
==> Publishing OSTree commit
    machine  : ${MACHINE}
    ref      : ${OSTREE_REF}
    revision : ${rev}
    branch   : ${OSTREE_PUBLISH_BRANCH}
    version  : ${version}
    staging  : ${OSTREE_STAGING_REPO}
    target   : s3://${S3_BUCKET}/ostree  (${PUBLIC_URL}/ostree)
EOF

    if [[ ! -f "${OSTREE_STAGING_REPO}/config" ]]; then
        run mkdir -p "$OSTREE_STAGING_REPO"
        # Restore from S3 first if a repo is already published there, so
        # static-delta generate sees real ancestor history even on a fresh
        # agent (ephemeral CI runner, or a persistent one whose cache was
        # evicted) instead of silently degrading every delta to full content.
        if aws s3api head-object --bucket "$S3_BUCKET" --key "ostree/config" --region "$S3_REGION" >/dev/null 2>&1; then
            echo "==> No local staging repo — restoring from s3://${S3_BUCKET}/ostree"
            run aws s3 sync "s3://${S3_BUCKET}/ostree" "$OSTREE_STAGING_REPO" --region "$S3_REGION"
        else
            echo "==> No local staging repo and nothing published yet — initializing new repo"
            run ostree --repo="$OSTREE_STAGING_REPO" init --mode=archive
        fi
    fi

    run ostree --repo="$OSTREE_STAGING_REPO" pull-local "$OSTREE_REPO" "$rev"
    run ostree --repo="$OSTREE_STAGING_REPO" commit \
        -b "$OSTREE_PUBLISH_BRANCH" \
        -s "$message" \
        --add-metadata-string=version="$version" \
        --tree=ref="$rev"
    run ostree --repo="$OSTREE_STAGING_REPO" static-delta generate "$OSTREE_PUBLISH_BRANCH"
    run ostree --repo="$OSTREE_STAGING_REPO" summary -u

    run aws s3 sync "$OSTREE_STAGING_REPO" "s3://${S3_BUCKET}/ostree" --region "$S3_REGION"

    OSTREE_PUBLISHED=1
}

# --- TEZI publish ----------------------------------------------------------
publish_tezi() {
    local symlink="${IMAGES_DIR}/torizon-minimal-${MACHINE}-Tezi.tar"
    [[ -e "$symlink" ]] || die "Tezi tarball not found: $symlink"
    local tarball
    tarball="$(readlink -f "$symlink")"
    local imgdir
    imgdir="$(basename "$tarball" .tar)"

    cat <<EOF
==> Publishing TEZI image
    machine  : ${MACHINE}
    tarball  : ${tarball}
    image dir: ${imgdir}
    target   : s3://${S3_BUCKET}/tezi/${imgdir}/  (${PUBLIC_URL}/tezi)
EOF

    run mkdir -p "$TEZI_STAGING_DIR"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        rm -rf "${TEZI_STAGING_DIR:?}/${imgdir}"
        tar -C "$TEZI_STAGING_DIR" -xf "$tarball"
    else
        echo "    [dry-run] extract ${tarball} into ${TEZI_STAGING_DIR}/${imgdir}"
    fi

    run aws s3 sync "${TEZI_STAGING_DIR}/${imgdir}" "s3://${S3_BUCKET}/tezi/${imgdir}" --region "$S3_REGION"

    # image_list.json must list every currently-published image (not just
    # this one) - query S3 directly rather than round-tripping every TEZI
    # tarball (hundreds of MB each) through this host on every publish.
    echo "==> Rebuilding image_list.json from published images on S3"
    local existing
    existing="$(aws s3api list-objects-v2 --bucket "$S3_BUCKET" --prefix "tezi/" --query "Contents[?ends_with(Key, 'image.json')].Key" --output text --region "$S3_REGION" 2>/dev/null || true)"
    [[ "$existing" == "None" ]] && existing=""

    local -a images=("${imgdir}/image.json")
    local key name
    for key in $existing; do
        name="${key#tezi/}"
        [[ "$name" == "${imgdir}/image.json" ]] && continue
        images+=("$name")
    done

    local list_json
    list_json="$(printf '"%s"' "${images[0]}")"
    local i
    for ((i = 1; i < ${#images[@]}; i++)); do
        list_json="${list_json}, $(printf '"%s"' "${images[$i]}")"
    done
    list_json="{\"config_format\": 1, \"images\": [${list_json}]}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "    [dry-run] would write image_list.json:"
        echo "    ${list_json}"
    else
        echo "$list_json" > "${TEZI_STAGING_DIR}/image_list.json"
        aws s3 cp "${TEZI_STAGING_DIR}/image_list.json" "s3://${S3_BUCKET}/tezi/image_list.json" --region "$S3_REGION"
    fi

    TEZI_PUBLISHED=1
}

[[ "$DO_OSTREE" -eq 1 ]] && publish_ostree
[[ "$DO_TEZI" -eq 1 ]] && publish_tezi

# --- CloudFront invalidation -------------------------------------------------
paths=()
[[ "$OSTREE_PUBLISHED" -eq 1 ]] && paths+=("/ostree/*")
[[ "$TEZI_PUBLISHED" -eq 1 ]] && paths+=("/tezi/*")

if [[ "${#paths[@]}" -gt 0 ]]; then
    echo "==> Invalidating CloudFront (${CLOUDFRONT_DISTRIBUTION_ID}): ${paths[*]}"
    run aws cloudfront create-invalidation \
        --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
        --paths "${paths[@]}"
fi

# --- Verify -------------------------------------------------------------------
if [[ "$DO_VERIFY" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
    echo "==> Verifying published URLs (informational — edge caches can lag briefly)"
    if [[ "$OSTREE_PUBLISHED" -eq 1 ]]; then
        code="$(curl -s -o /dev/null -w '%{http_code}' "${PUBLIC_URL}/ostree/summary" || echo000)"
        echo "    ${PUBLIC_URL}/ostree/summary -> HTTP ${code}"
        [[ "$code" == "200" ]] || echo "    WARNING: expected 200"
    fi
    if [[ "$TEZI_PUBLISHED" -eq 1 ]]; then
        code="$(curl -s -o /dev/null -w '%{http_code}' "${PUBLIC_URL}/tezi/image_list.json" || echo 000)"
        echo "    ${PUBLIC_URL}/tezi/image_list.json -> HTTP ${code}"
        [[ "$code" == "200" ]] || echo "    WARNING: expected 200"
    fi
fi

echo "==> Done."
