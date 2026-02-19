#!/bin/bash
set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
S3_BUCKET="s3://edgefirst-repo"
S3_PREFIX="yocto/nxp"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Deploy Yocto images and SDKs to S3.

Options:
  --machine MACHINE   Deploy only this machine (default: all discovered)
  --image NAME        Image name (default: imx-image-full)
  --build-dir DIR     Build directory (default: build)
  --version VER       Override version (default: auto-detect from manifest)
  --dry-run           Show what would be deployed
  --force             Upload even if checksums match
  -h, --help          Show help
EOF
    exit 0
}

# ── Version detection ──────────────────────────────────────────────────────────
detect_version() {
    local manifest="$ROOT_DIR/.repo/manifest.xml"
    if [[ ! -f "$manifest" ]]; then
        echo "Error: manifest not found at $manifest" >&2
        exit 1
    fi
    grep 'include name=' "$manifest" \
        | sed 's/.*include name=".*imx-\(.*\)\.xml".*/\1/' \
        | head -1
}

# ── Machine discovery ──────────────────────────────────────────────────────────
discover_machines() {
    local build_dir="$1"
    local image="$2"
    local deploy_dir="$ROOT_DIR/$build_dir/tmp/deploy/images"

    if [[ ! -d "$deploy_dir" ]]; then
        echo "Error: deploy directory not found: $deploy_dir" >&2
        return 1
    fi

    local machines=()
    for dir in "$deploy_dir"/*/; do
        local machine
        machine="$(basename "$dir")"
        if ls "$dir"/"$image"-*.rootfs.wic.zst &>/dev/null; then
            machines+=("$machine")
        fi
    done

    if [[ ${#machines[@]} -eq 0 ]]; then
        echo "Error: no machines found with $image images in $deploy_dir" >&2
        return 1
    fi

    printf '%s\n' "${machines[@]}"
}

# ── Checksum-aware upload ──────────────────────────────────────────────────────
deploy_artifact() {
    local local_path="$1"
    local s3_key="$2"
    local s3_url="$S3_BUCKET/$S3_PREFIX/$s3_key"

    if [[ ! -f "$local_path" ]]; then
        echo "  SKIP (not found): $local_path"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo "  DRY-RUN: $local_path → $s3_url"
        return 0
    fi

    local local_sha256
    local_sha256="$(sha256sum "$local_path" | awk '{print $1}')"

    if [[ "$FORCE" != true ]]; then
        local remote_sha256=""
        remote_sha256="$(aws s3api head-object \
            --bucket "${S3_BUCKET#s3://}" \
            --key "$S3_PREFIX/$s3_key" \
            --query 'Metadata.sha256' \
            --output text 2>/dev/null || true)"

        if [[ "$remote_sha256" == "$local_sha256" ]]; then
            echo "  SKIP (unchanged): $s3_key"
            return 0
        fi
    fi

    echo "  UPLOAD: $local_path → $s3_url"
    aws s3 cp "$local_path" "$s3_url" \
        --metadata sha256="$local_sha256"
}

# ── Deploy a single machine ───────────────────────────────────────────────────
deploy_machine() {
    local machine="$1"
    local image="$2"
    local build_dir="$3"

    echo "Deploying $machine (image=$image, version=$VERSION)"

    # Image
    local image_path="$ROOT_DIR/$build_dir/tmp/deploy/images/$machine/$image-$machine.rootfs.wic.zst"
    local image_key="$image-$VERSION-$machine.rootfs.wic.zst"
    deploy_artifact "$image_path" "$image_key"

    # SDK (local filename uses wildcard)
    local sdk_pattern="$ROOT_DIR/$build_dir/tmp/deploy/sdk/fsl-imx-wayland-glibc-x86_64-$image-armv8a-$machine-toolchain-*.sh"
    local sdk_key="fsl-imx-wayland-glibc-x86_64-$image-armv8a-$machine-toolchain-$VERSION.sh"
    local sdk_path
    sdk_path="$(ls $sdk_pattern 2>/dev/null | head -1 || true)"
    if [[ -z "$sdk_path" ]]; then
        echo "  SKIP (not found): SDK for $machine"
    else
        deploy_artifact "$sdk_path" "$sdk_key"
    fi
}

# ── Main ───────────────────────────────────────────────────────────────────────
DRY_RUN=false
FORCE=false
VERSION=""
IMAGE_NAME="imx-image-full"
BUILD_DIR="build"
FILTER_MACHINE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --machine)   FILTER_MACHINE="$2"; shift 2 ;;
        --image)     IMAGE_NAME="$2"; shift 2 ;;
        --build-dir) BUILD_DIR="$2"; shift 2 ;;
        --version)   VERSION="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=true; shift ;;
        --force)     FORCE=true; shift ;;
        -h|--help)   usage ;;
        *)           echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

if [[ -z "$VERSION" ]]; then
    VERSION="$(detect_version)"
fi
echo "Version: $VERSION"

# Discover or filter machines
if [[ -n "$FILTER_MACHINE" ]]; then
    MACHINES=("$FILTER_MACHINE")
else
    mapfile -t MACHINES < <(discover_machines "$BUILD_DIR" "$IMAGE_NAME")
fi

# Deploy
for machine in "${MACHINES[@]}"; do
    deploy_machine "$machine" "$IMAGE_NAME" "$BUILD_DIR"
done

echo "Done."
