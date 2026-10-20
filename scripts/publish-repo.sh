#!/usr/bin/env bash
#
# publish-repo.sh — Publish a built OSTree commit and/or TEZI (Toradex Easy
# Installer) image to an S3 + CloudFront-backed software repository, for
# self-hosted OTA updates and network installs.
#
# Fully parameterized: no bucket, region, CloudFront distribution, public
# URL, image name, or local staging path is hardcoded anywhere in this
# script. Every target-specific value is a required or optional environment
# variable (see the reference below), so the exact same script runs
# unmodified across projects, hosts, and CI systems — set the variables in
# a Jenkins `environment {}` block or a GitHub Actions `env:` block the same
# way the build itself sets MACHINE, and call this script as the publish
# step. No flags are required beyond selecting what to publish.
#
# Process:
#   1. Ensure a local OSTree staging repo exists and has history to diff
#      against. If one isn't already on disk (ephemeral CI runner, first run
#      on a new agent), restore it from the target bucket first rather than
#      initializing empty — `ostree static-delta generate` only produces a
#      real incremental delta when the ref's parent commit is present
#      locally; losing that history silently degrades every delta to a
#      full-content delta, which still works but defeats the point of OTA
#      deltas.
#   2. pull-local the build's OSTree commit into that staging repo
#   3. commit it onto a per-machine/channel branch with version metadata
#   4. generate a static delta (skipped on a branch's first-ever publish,
#      since there's no prior commit yet to delta against), update the
#      repo summary
#   5. sync the staging repo to the OSTree prefix of the target bucket
#      (default "ostree/", overridable via OSTREE_S3_PREFIX so more than one
#      OSTree repo can share a bucket, e.g. "ostree/torizon" alongside an
#      "ostree/imx" repo for a different BSP flavor) — additive: no --delete,
#      since ostree's object store is content-addressed and old objects are
#      still referenced by history/deltas
#   6. extract the TEZI tarball and publish it under the tezi/ prefix,
#      regenerating the shared image_list.json feed index by querying the
#      bucket for what's already published (never re-downloads prior
#      multi-hundred-MB tarballs just to list them) — feed format per
#      https://developer.toradex.com/easy-installer/toradex-easy-installer/toradex-easy-installer-configuration-files/
#   7. invalidate CloudFront for the paths that changed (skipped if no
#      distribution ID is configured)
#   8. (unless --skip-verify, and only if a public URL is configured) HEAD
#      the published URLs through the CDN — informational only: edge
#      propagation can lag a few seconds after invalidation, so this warns
#      rather than fails the run.
#
# Usage:
#   ./publish-repo.sh            # publish ostree + tezi
#   ./publish-repo.sh -n         # dry run
#   ./publish-repo.sh --ostree-only
#   ./publish-repo.sh --tezi-only
#   ./publish-repo.sh --sign-only  # sign every commit already in the staging
#                                  # repo, refresh the signed summary, sync
#
# Required environment variables:
#   MACHINE                     Target machine name (e.g. verdin-imx8mp)
#   IMAGE_NAME                  Image recipe base name (e.g. torizon-edgefirst)
#                                — used for the TEZI tarball name pattern and
#                                as the default OSTree branch/message prefix
#   IMAGES_DIR                  Path to the build's deploy/images/$MACHINE
#                                directory (or set BUILD_DIR and this
#                                derives as $BUILD_DIR/deploy/images/$MACHINE)
#   OSTREE_STAGING_REPO         Local path for the persistent/restored
#                                OSTree staging repo this script maintains
#   TEZI_STAGING_DIR            Local path to extract TEZI tarballs into
#                                before syncing
#   S3_BUCKET                   Target bucket name
#
# Optional environment variables:
#   BUILD_DIR                   Convenience for deriving IMAGES_DIR; unused
#                                if IMAGES_DIR is set directly
#   OSTREE_REPO                 default: $IMAGES_DIR/ostree_repo
#   OSTREE_S3_PREFIX            default: ostree (the key prefix under
#                                S3_BUCKET the repo is published to/restored
#                                from, e.g. "ostree/torizon")
#   OSTREE_REF                  default: auto-detected (must be the only ref
#                                under $OSTREE_REPO/refs/heads if unset)
#   S3_REGION                   default: unset (aws CLI resolves the region
#                                from its own configured default/profile)
#   CLOUDFRONT_DISTRIBUTION_ID  default: unset (CloudFront invalidation is
#                                skipped if not set)
#   PUBLIC_URL                  default: unset (post-publish HTTP
#                                verification is skipped if not set)
#   OSTREE_GPG_KEY              default: unset (commits and the summary are
#                                published unsigned). A GPG key ID or
#                                fingerprint: every new commit and the repo
#                                summary are signed with it, and the script
#                                stops if the key is not available
#   OSTREE_GPG_HOMEDIR          default: unset (gpg's own default). GPG home
#                                directory that holds OSTREE_GPG_KEY
#   OSTREE_SIGN_BIN             default: ostree. The ostree binary used for the
#                                signing steps; it must be built with gpgme
#                                when OSTREE_GPG_KEY is set, and with ed25519
#                                for OSTREE_ED25519_SECRET_FILE. Yocto's
#                                ostree-native has ed25519 (ed25519-openssl)
#                                and no gpgme; the host's /usr/bin/ostree has
#                                gpgme and may lack ed25519
#   OSTREE_ED25519_SECRET_FILE  default: unset. File holding the base64
#                                ed25519 secret key (64 bytes: seed followed by
#                                public key). Every new commit and the repo
#                                summary are signed with it; devices enforce
#                                this signature with sign-verify=ed25519.
#                                Mutually exclusive with OSTREE_GPG_KEY
#   OSTREE_ED25519_PUBLIC_FILE  default: unset. File holding the matching base64
#                                public key; each signed commit is verified
#                                against it before it is published
#   CHANNEL                     default: develop
#   OSTREE_PUBLISH_BRANCH       default: $IMAGE_NAME/$MACHINE/$CHANNEL
#   VERSION                     default: $(date +%Y.%m.%d)-$MACHINE
#   MESSAGE                     default: "$IMAGE_NAME $VERSION ($MACHINE)"
#
set -euo pipefail

# --- Configuration (all set via environment; see the reference above) --------
MACHINE="${MACHINE:-}"
IMAGE_NAME="${IMAGE_NAME:-}"
BUILD_DIR="${BUILD_DIR:-}"
IMAGES_DIR="${IMAGES_DIR:-}"
OSTREE_STAGING_REPO="${OSTREE_STAGING_REPO:-}"
TEZI_STAGING_DIR="${TEZI_STAGING_DIR:-}"
S3_BUCKET="${S3_BUCKET:-}"

OSTREE_S3_PREFIX="${OSTREE_S3_PREFIX:-ostree}"
OSTREE_REF="${OSTREE_REF:-}"       # auto-detected from the build repo if empty
S3_REGION="${S3_REGION:-}"         # aws CLI's own default is used if empty
CLOUDFRONT_DISTRIBUTION_ID="${CLOUDFRONT_DISTRIBUTION_ID:-}"
PUBLIC_URL="${PUBLIC_URL:-}"
CHANNEL="${CHANNEL:-develop}"
OSTREE_GPG_KEY="${OSTREE_GPG_KEY:-}"
OSTREE_GPG_HOMEDIR="${OSTREE_GPG_HOMEDIR:-}"
OSTREE_SIGN_BIN="${OSTREE_SIGN_BIN:-ostree}"
OSTREE_ED25519_SECRET_FILE="${OSTREE_ED25519_SECRET_FILE:-}"
OSTREE_ED25519_PUBLIC_FILE="${OSTREE_ED25519_PUBLIC_FILE:-}"

DO_OSTREE=1
DO_TEZI=1
DO_VERIFY=1
DO_SIGN_ONLY=0
DRY_RUN=0
for arg in "$@"; do
    case "$arg" in
        -n|--dry-run) DRY_RUN=1 ;;
        --ostree-only) DO_TEZI=0 ;;
        --tezi-only) DO_OSTREE=0 ;;
        --skip-verify) DO_VERIFY=0 ;;
        --sign-only) DO_SIGN_ONLY=1; DO_TEZI=0 ;;
        -h|--help)
            SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
            sed -n '2,/^set -euo/p' "$SCRIPT_PATH" | sed '$d'
            exit 0
            ;;
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

# Adds an ed25519 signature to one commit and, when the public key is known,
# verifies it. A no-op when no ed25519 key is configured.
sign_commit_ed25519() {
    local rev="$1"
    [[ -n "$ED25519_SECRET" ]] || return 0
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "    [dry-run] $OSTREE_SIGN_BIN --repo=$OSTREE_STAGING_REPO sign --sign-type=ed25519 $rev <secret>"
        return 0
    fi
    "$OSTREE_SIGN_BIN" --repo="$OSTREE_STAGING_REPO" sign --sign-type=ed25519 "$rev" "$ED25519_SECRET"
    if [[ -n "$OSTREE_ED25519_PUBLIC_FILE" ]]; then
        "$OSTREE_SIGN_BIN" --repo="$OSTREE_STAGING_REPO" sign --sign-type=ed25519 --verify "$rev" \
            "$(< "$OSTREE_ED25519_PUBLIC_FILE")" >/dev/null \
            || die "ed25519 signature on $rev does not verify against $OSTREE_ED25519_PUBLIC_FILE"
    fi
}

# Regenerates the repository summary with every configured signature.
update_summary() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "    [dry-run] $OSTREE_SIGN_BIN --repo=$OSTREE_STAGING_REPO summary -u ${GPG_ARGS[*]:-} ${ED25519_ARGS[*]:+--sign-type=ed25519 --sign=<secret>}"
        return 0
    fi
    "$OSTREE_SIGN_BIN" --repo="$OSTREE_STAGING_REPO" summary -u "${GPG_ARGS[@]}" "${ED25519_ARGS[@]}"
}

# --- Preflight ----------------------------------------------------------------
missing=()
[[ -n "$MACHINE" ]]              || missing+=("MACHINE")
[[ -n "$IMAGE_NAME" ]]           || missing+=("IMAGE_NAME")
[[ -n "$OSTREE_STAGING_REPO" ]]  || missing+=("OSTREE_STAGING_REPO")
[[ -n "$TEZI_STAGING_DIR" ]]     || missing+=("TEZI_STAGING_DIR")
[[ -n "$S3_BUCKET" ]]            || missing+=("S3_BUCKET")
if [[ -z "$IMAGES_DIR" ]]; then
    if [[ -n "$BUILD_DIR" && -n "$MACHINE" ]]; then
        IMAGES_DIR="${BUILD_DIR}/deploy/images/${MACHINE}"
    else
        missing+=("IMAGES_DIR (or BUILD_DIR)")
    fi
fi
if [[ "${#missing[@]}" -gt 0 ]]; then
    { echo "ERROR: required environment variables not set: ${missing[*]}"
      echo "Run with --help for the full parameter reference."; } >&2
    exit 2
fi

OSTREE_REPO="${OSTREE_REPO:-${IMAGES_DIR}/ostree_repo}"
OSTREE_PUBLISH_BRANCH="${OSTREE_PUBLISH_BRANCH:-${IMAGE_NAME}/${MACHINE}/${CHANNEL}}"

command -v aws    >/dev/null 2>&1 || die "aws CLI not found on PATH"
command -v ostree >/dev/null 2>&1 || die "ostree CLI not found on PATH"
command -v tar     >/dev/null 2>&1 || die "tar not found on PATH"
[[ -d "$IMAGES_DIR" ]] || die "image deploy dir not found: $IMAGES_DIR (build $IMAGE_NAME for $MACHINE first?)"

# Signing: the same key signs each commit and the summary. A configured key
# that gpg cannot find is an error, never a silent fall-back to unsigned.
GPG_ARGS=()
if [[ -n "$OSTREE_GPG_KEY" ]]; then
    command -v gpg >/dev/null 2>&1 || die "gpg not found on PATH but OSTREE_GPG_KEY is set"
    GPG_HOME_ARGS=()
    [[ -n "$OSTREE_GPG_HOMEDIR" ]] && GPG_HOME_ARGS=(--homedir "$OSTREE_GPG_HOMEDIR")
    gpg "${GPG_HOME_ARGS[@]}" --batch --list-secret-keys "$OSTREE_GPG_KEY" >/dev/null 2>&1 \
        || die "GPG secret key not found: $OSTREE_GPG_KEY"
    "$OSTREE_SIGN_BIN" gpg-sign --help >/dev/null 2>&1 \
        || die "$OSTREE_SIGN_BIN has no gpg-sign command (built without gpgme); set OSTREE_SIGN_BIN"
    GPG_ARGS=(--gpg-sign="$OSTREE_GPG_KEY")
    [[ -n "$OSTREE_GPG_HOMEDIR" ]] && GPG_ARGS+=(--gpg-homedir="$OSTREE_GPG_HOMEDIR")
fi

# ed25519 signing: the secret key is read once and handed to ostree as the
# KEY-ID argument, which is how `ostree sign` takes it. It is never echoed,
# not even in --dry-run.
ED25519_SECRET=""
ED25519_ARGS=()
if [[ -n "$OSTREE_ED25519_SECRET_FILE" ]]; then
    [[ -z "$OSTREE_GPG_KEY" ]] || die "OSTREE_GPG_KEY and OSTREE_ED25519_SECRET_FILE are mutually exclusive: no single ostree binary signs with both"
    [[ -r "$OSTREE_ED25519_SECRET_FILE" ]] || die "cannot read OSTREE_ED25519_SECRET_FILE: $OSTREE_ED25519_SECRET_FILE"
    ED25519_SECRET="$(< "$OSTREE_ED25519_SECRET_FILE")"
    [[ "$(printf '%s' "$ED25519_SECRET" | base64 -d 2>/dev/null | wc -c)" -eq 64 ]] \
        || die "OSTREE_ED25519_SECRET_FILE is not a base64 64-byte ed25519 secret key"
    if [[ -n "$OSTREE_ED25519_PUBLIC_FILE" ]]; then
        [[ -r "$OSTREE_ED25519_PUBLIC_FILE" ]] || die "cannot read OSTREE_ED25519_PUBLIC_FILE: $OSTREE_ED25519_PUBLIC_FILE"
    fi
    "$OSTREE_SIGN_BIN" sign --help >/dev/null 2>&1 \
        || die "$OSTREE_SIGN_BIN has no sign command; set OSTREE_SIGN_BIN"
    probe="$(mktemp -d)"
    "$OSTREE_SIGN_BIN" --repo="$probe/r" init --mode=archive >/dev/null 2>&1
    "$OSTREE_SIGN_BIN" --repo="$probe/r" sign --sign-type=ed25519 0000000000000000000000000000000000000000000000000000000000000000 "$ED25519_SECRET" 2>&1 \
        | grep -q "not implemented" && { rm -rf "$probe"; die "$OSTREE_SIGN_BIN is built without ed25519 support; set OSTREE_SIGN_BIN"; }
    rm -rf "$probe"
    ED25519_ARGS=(--sign-type=ed25519 "--sign=${ED25519_SECRET}")
fi
if [[ "$DO_SIGN_ONLY" -eq 1 && "${#GPG_ARGS[@]}" -eq 0 && "${#ED25519_ARGS[@]}" -eq 0 ]]; then
    die "--sign-only needs OSTREE_GPG_KEY or OSTREE_ED25519_SECRET_FILE"
fi

# aws CLI accepts --region on every call; omit it entirely when S3_REGION is
# unset so the CLI's own configured default/profile region applies instead
# of this script silently assuming one.
AWS_REGION_ARGS=()
[[ -n "$S3_REGION" ]] && AWS_REGION_ARGS=(--region "$S3_REGION")

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
    local message="${MESSAGE:-${IMAGE_NAME} ${version} (${MACHINE})}"

    cat <<EOF
==> Publishing OSTree commit
    machine  : ${MACHINE}
    ref      : ${OSTREE_REF}
    revision : ${rev}
    branch   : ${OSTREE_PUBLISH_BRANCH}
    version  : ${version}
    staging  : ${OSTREE_STAGING_REPO}
    target   : s3://${S3_BUCKET}/${OSTREE_S3_PREFIX}
EOF

    if [[ ! -f "${OSTREE_STAGING_REPO}/config" ]]; then
        run mkdir -p "$OSTREE_STAGING_REPO"
        # Restore from the bucket first if a repo is already published there,
        # so static-delta generate sees real ancestor history even on a
        # fresh agent (ephemeral CI runner, or a persistent one whose cache
        # was evicted) instead of silently degrading every delta to full
        # content.
        if aws s3api head-object --bucket "$S3_BUCKET" --key "${OSTREE_S3_PREFIX}/config" "${AWS_REGION_ARGS[@]}" >/dev/null 2>&1; then
            echo "==> No local staging repo — restoring from s3://${S3_BUCKET}/${OSTREE_S3_PREFIX}"
            run aws s3 sync "s3://${S3_BUCKET}/${OSTREE_S3_PREFIX}" "$OSTREE_STAGING_REPO" "${AWS_REGION_ARGS[@]}"
        else
            echo "==> No local staging repo and nothing published yet — initializing new repo"
            run ostree --repo="$OSTREE_STAGING_REPO" init --mode=archive
        fi
    fi

    # static-delta generate needs a prior commit on this branch to diff
    # against; capture whether one exists before we add ours, so a branch's
    # first-ever publish doesn't fail on "commit has no parent".
    local had_prior_commit=1
    ostree --repo="$OSTREE_STAGING_REPO" rev-parse "$OSTREE_PUBLISH_BRANCH" >/dev/null 2>&1 || had_prior_commit=0

    run ostree --repo="$OSTREE_STAGING_REPO" pull-local "$OSTREE_REPO" "$rev"
    run ostree --repo="$OSTREE_STAGING_REPO" commit \
        -b "$OSTREE_PUBLISH_BRANCH" \
        -s "$message" \
        --add-metadata-string=version="$version" \
        --tree=ref="$rev"
    local new_rev
    new_rev="$(ostree --repo="$OSTREE_STAGING_REPO" rev-parse "$OSTREE_PUBLISH_BRANCH")"
    if [[ "${#GPG_ARGS[@]}" -gt 0 ]]; then
        run "$OSTREE_SIGN_BIN" --repo="$OSTREE_STAGING_REPO" gpg-sign \
            ${OSTREE_GPG_HOMEDIR:+--gpg-homedir="$OSTREE_GPG_HOMEDIR"} "$new_rev" "$OSTREE_GPG_KEY"
    fi
    sign_commit_ed25519 "$new_rev"
    if [[ "$had_prior_commit" -eq 1 ]]; then
        run ostree --repo="$OSTREE_STAGING_REPO" static-delta generate "$OSTREE_PUBLISH_BRANCH"
    else
        echo "==> First publish on branch ${OSTREE_PUBLISH_BRANCH} — no prior commit to delta against, skipping static-delta generate"
    fi
    update_summary

    run aws s3 sync "$OSTREE_STAGING_REPO" "s3://${S3_BUCKET}/${OSTREE_S3_PREFIX}" "${AWS_REGION_ARGS[@]}"
    publish_public_key

    OSTREE_PUBLISHED=1
}

# --- Public signing key -----------------------------------------------------
# The verification key is public by design; publish it next to the repository
# so users can inspect and import it.
publish_public_key() {
    [[ -n "$OSTREE_ED25519_PUBLIC_FILE" ]] || return 0
    run aws s3 cp "$OSTREE_ED25519_PUBLIC_FILE" \
        "s3://${S3_BUCKET}/${OSTREE_S3_PREFIX}/$(basename "$OSTREE_ED25519_PUBLIC_FILE")" \
        --content-type text/plain "${AWS_REGION_ARGS[@]}"
}

# --- Sign existing commits --------------------------------------------------
# Adds a detached signature to every commit reachable from every ref in the
# staging repo, then regenerates the signed summary and syncs. Commit
# checksums do not change; signatures live in separate .commitmeta objects.
sign_existing() {
    [[ -f "${OSTREE_STAGING_REPO}/config" ]] || die "no staging repo at: $OSTREE_STAGING_REPO"
    echo "==> Signing existing commits in ${OSTREE_STAGING_REPO}"
    local ref commit
    while read -r ref; do
        while read -r commit; do
            echo "    ${ref} ${commit:0:12}"
            if [[ "${#GPG_ARGS[@]}" -gt 0 ]]; then
                run "$OSTREE_SIGN_BIN" --repo="$OSTREE_STAGING_REPO" gpg-sign \
                    ${OSTREE_GPG_HOMEDIR:+--gpg-homedir="$OSTREE_GPG_HOMEDIR"} "$commit" "$OSTREE_GPG_KEY"
            fi
            sign_commit_ed25519 "$commit"
        done < <(ostree --repo="$OSTREE_STAGING_REPO" log "$ref" | awk '/^commit /{print $2}')
    done < <(ostree --repo="$OSTREE_STAGING_REPO" refs)
    update_summary
    run aws s3 sync "$OSTREE_STAGING_REPO" "s3://${S3_BUCKET}/${OSTREE_S3_PREFIX}" "${AWS_REGION_ARGS[@]}"
    publish_public_key
    OSTREE_PUBLISHED=1
}

# --- TEZI publish ----------------------------------------------------------
publish_tezi() {
    local symlink="${IMAGES_DIR}/${IMAGE_NAME}-${MACHINE}-Tezi.tar"
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
    target   : s3://${S3_BUCKET}/tezi/${imgdir}/
EOF

    run mkdir -p "$TEZI_STAGING_DIR"
    if [[ "$DRY_RUN" -eq 0 ]]; then
        rm -rf "${TEZI_STAGING_DIR:?}/${imgdir}"
        tar -C "$TEZI_STAGING_DIR" -xf "$tarball"
    else
        echo "    [dry-run] extract ${tarball} into ${TEZI_STAGING_DIR}/${imgdir}"
    fi

    run aws s3 sync "${TEZI_STAGING_DIR}/${imgdir}" "s3://${S3_BUCKET}/tezi/${imgdir}" "${AWS_REGION_ARGS[@]}"

    # image_list.json must list every currently-published image (not just
    # this one) - query the bucket directly rather than round-tripping every
    # TEZI tarball (hundreds of MB each) through this host on every publish.
    echo "==> Rebuilding image_list.json from published images in the bucket"
    local existing
    existing="$(aws s3api list-objects-v2 --bucket "$S3_BUCKET" --prefix "tezi/" --query "Contents[?ends_with(Key, 'image.json')].Key" --output text "${AWS_REGION_ARGS[@]}" 2>/dev/null || true)"
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
        aws s3 cp "${TEZI_STAGING_DIR}/image_list.json" "s3://${S3_BUCKET}/tezi/image_list.json" "${AWS_REGION_ARGS[@]}"
    fi

    TEZI_PUBLISHED=1
}

if [[ "$DO_SIGN_ONLY" -eq 1 ]]; then
    sign_existing
elif [[ "$DO_OSTREE" -eq 1 ]]; then
    publish_ostree
fi
[[ "$DO_TEZI" -eq 1 ]] && publish_tezi

# --- CloudFront invalidation -------------------------------------------------
paths=()
[[ "$OSTREE_PUBLISHED" -eq 1 ]] && paths+=("/${OSTREE_S3_PREFIX}/*")
[[ "$TEZI_PUBLISHED" -eq 1 ]] && paths+=("/tezi/*")

if [[ "${#paths[@]}" -gt 0 ]]; then
    if [[ -n "$CLOUDFRONT_DISTRIBUTION_ID" ]]; then
        echo "==> Invalidating CloudFront (${CLOUDFRONT_DISTRIBUTION_ID}): ${paths[*]}"
        run aws cloudfront create-invalidation \
            --distribution-id "$CLOUDFRONT_DISTRIBUTION_ID" \
            --paths "${paths[@]}"
    else
        echo "==> CLOUDFRONT_DISTRIBUTION_ID not set — skipping CDN invalidation"
    fi
fi

# --- Verify -------------------------------------------------------------------
if [[ "$DO_VERIFY" -eq 1 && "$DRY_RUN" -eq 0 ]]; then
    if [[ -z "$PUBLIC_URL" ]]; then
        echo "==> PUBLIC_URL not set — skipping post-publish verification"
    else
        echo "==> Verifying published URLs (informational — edge caches can lag briefly)"
        if [[ "$OSTREE_PUBLISHED" -eq 1 ]]; then
            code="$(curl -s -o /dev/null -w '%{http_code}' "${PUBLIC_URL}/${OSTREE_S3_PREFIX}/summary" || echo 000)"
            echo "    ${PUBLIC_URL}/${OSTREE_S3_PREFIX}/summary -> HTTP ${code}"
            [[ "$code" == "200" ]] || echo "    WARNING: expected 200"
        fi
        if [[ "$TEZI_PUBLISHED" -eq 1 ]]; then
            code="$(curl -s -o /dev/null -w '%{http_code}' "${PUBLIC_URL}/tezi/image_list.json" || echo 000)"
            echo "    ${PUBLIC_URL}/tezi/image_list.json -> HTTP ${code}"
            [[ "$code" == "200" ]] || echo "    WARNING: expected 200"
        fi
    fi
fi

echo "==> Done."
