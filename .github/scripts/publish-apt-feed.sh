#!/bin/bash
# Stage, index, sign and optionally publish the apt feed for one release and BSP.
#
#   publish-apt-feed.sh [--upload] BUILD_DIR
#   publish-apt-feed.sh --announce [--upload] [--upgrade-from RELEASE/BSP]... BUILD_DIR
#
# BUILD_DIR is a build directory that has built edgefirst-apt-config. The
# release, BSP name and architecture directories come from the sources list
# inside that package, so the feed has exactly the layout the images were built
# to read:
#
#   nxp/<YYYY.MM>/<bsp>/<arch>/Packages{,.gz}  Release  InRelease  Release.gpg  *.deb
#
# Without --upload the signed feed is only staged under BUILD_DIR/apt-feed. A
# feed is the rolling channel of a quarterly release: publishing replaces the
# previous contents, and a board that runs apt update and apt full-upgrade
# follows its PATCH updates. -dbg, -src and -ptest packages are left out; set
# EDGEFIRST_FEED_EXCLUDE to change that.
#
# --announce adds the release and BSP of BUILD_DIR to the signed list of releases
# that edgefirst-release-upgrade reads (nxp/meta-release), once every machine's
# feed for it is published. Each --upgrade-from names a release and BSP, as
# 2026.10/imx-6.18.20-2.0.0, that boards may be moved to this one from.
#
# Signing uses the key in ~/edgefirst-ca/nxp; see the README there.
set -euo pipefail

UPLOAD=0
ANNOUNCE=0
UPGRADE_FROM=()
while [ $# -gt 1 ]; do
    case "$1" in
        --upload) UPLOAD=1 ;;
        --announce) ANNOUNCE=1 ;;
        --upgrade-from) shift; UPGRADE_FROM+=("${1:?--upgrade-from needs RELEASE/BSP}") ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
BUILD_DIR="${1:?usage: publish-apt-feed.sh [--announce] [--upload] BUILD_DIR}"

CA_DIR="${EDGEFIRST_CA_DIR:-$HOME/edgefirst-ca}/nxp"
GNUPGHOME="${EDGEFIRST_APT_GNUPGHOME:-$CA_DIR/private/gnupg}"
FPR="$(cat "$CA_DIR/private/apt-fingerprint.txt")"
EXCLUDE="${EDGEFIRST_FEED_EXCLUDE:--dbg -src -ptest}"
BUCKET="s3://edgefirst-repo/nxp"
DISTRIBUTION_ID="ENV44D23AY6RF"

DEB_DIR="$BUILD_DIR/tmp/deploy/deb"
CONFIG_DEB="$(ls -t "$DEB_DIR"/*/edgefirst-apt-config_*.deb 2>/dev/null | head -n1 || true)"
[ -n "$CONFIG_DEB" ] || { echo "edgefirst-apt-config has not been built in $BUILD_DIR" >&2; exit 1; }

SOURCES="$(dpkg-deb --fsys-tarfile "$CONFIG_DEB" | tar -xO ./etc/apt/sources.list.d/edgefirst.list)"
# deb [signed-by=...] https://repo.edgefirst.ai/nxp/<release>/<bsp>/<arch> ./
mapfile -t TARGETS < <(awk '{print $3}' <<<"$SOURCES" | sed 's#^.*/nxp/##')
[ "${#TARGETS[@]}" -gt 0 ] || { echo "no feed entries in $CONFIG_DEB" >&2; exit 1; }
RELEASE="${TARGETS[0]%%/*}"
BSP="${TARGETS[0]#*/}"; BSP="${BSP%%/*}"
RELEASE_DEB="$(ls -t "$DEB_DIR"/*/edgefirst-release_*.deb 2>/dev/null | head -n1 || true)"
[ -n "$RELEASE_DEB" ] || { echo "edgefirst-release has not been built in $BUILD_DIR" >&2; exit 1; }
VERSION="$(dpkg-deb -f "$RELEASE_DEB" Version | sed 's/-r[0-9][^-]*$//')"

STAGE="$BUILD_DIR/apt-feed"
mkdir -p "$STAGE"
export GNUPGHOME

gpg_sign() {
    gpg --batch --yes --pinentry-mode loopback --passphrase '' --local-user "$FPR" "$@"
}

if [ "$ANNOUNCE" -eq 1 ]; then
    META="$STAGE/meta-release"
    # The published list is the record; this release replaces its own stanza.
    curl -fsS "https://repo.edgefirst.ai/nxp/meta-release" -o "$META.live" 2>/dev/null || : > "$META.live"
    awk -v rel="$RELEASE" -v bsp="$BSP" '
        BEGIN { RS = ""; ORS = "\n\n" }
        { if ($0 !~ ("(^|\n)Release: " rel "\n") || $0 !~ ("\nBSP: " bsp "(\n|$)")) print }
    ' "$META.live" > "$META"
    {
        echo "Release: $RELEASE"
        echo "BSP: $BSP"
        echo "Supported: yes"
        echo "Upgrade-From: ${UPGRADE_FROM[*]:-}"
        echo
    } >> "$META"
    rm -f "$META.live"
    gpg_sign --armor --detach-sign --output "$META.asc" "$META"
    echo "==> release list staged in $STAGE"
    cat "$META"
    [ "$UPLOAD" -eq 1 ] || { echo "(not uploaded; pass --upload to publish)"; exit 0; }
    aws s3 cp "$META" "$BUCKET/meta-release" --cache-control "public, max-age=60" --only-show-errors
    aws s3 cp "$META.asc" "$BUCKET/meta-release.asc" --cache-control "public, max-age=60" --only-show-errors
    aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/nxp/meta-release*" >/dev/null
    echo "==> published to https://repo.edgefirst.ai/nxp/meta-release"
    exit 0
fi

rm -rf "$STAGE/$RELEASE"

echo "==> EdgeFirst Yocto $VERSION, $BSP: ${#TARGETS[@]} architecture directories"
for target in "${TARGETS[@]}"; do
    arch="${target##*/}"
    out="$STAGE/$target"
    mkdir -p "$out"

    if [ -d "$DEB_DIR/$arch" ]; then
        for deb in "$DEB_DIR/$arch"/*.deb; do
            skip=0
            for suffix in $EXCLUDE; do
                case "$deb" in *"$suffix"_*.deb) skip=1 ;; esac
            done
            [ "$skip" -eq 1 ] || ln "$deb" "$out/" 2>/dev/null || cp "$deb" "$out/"
        done
    fi

    (
        cd "$out"
        apt-ftparchive packages . > Packages
        gzip -9nk Packages
        apt-ftparchive \
            -o APT::FTPArchive::Release::Origin="EdgeFirst" \
            -o APT::FTPArchive::Release::Label="EdgeFirst Yocto for NXP" \
            -o APT::FTPArchive::Release::Suite="$BSP" \
            -o APT::FTPArchive::Release::Codename="$RELEASE" \
            -o APT::FTPArchive::Release::Version="$VERSION" \
            -o APT::FTPArchive::Release::Architectures="arm64 all" \
            release . > Release
        gpg_sign --clearsign --output InRelease Release
        gpg_sign --armor --detach-sign --output Release.gpg Release
    )
    printf '    %-34s %5s packages  %s\n' "$arch" "$(grep -c '^Package:' "$out/Packages")" "$(du -sh "$out" | cut -f1)"
done

echo "==> staged and signed in $STAGE"
[ "$UPLOAD" -eq 1 ] || { echo "(not uploaded; pass --upload to publish)"; exit 0; }

for target in "${TARGETS[@]}"; do
    # Packages first, then the index that makes them visible.
    aws s3 sync "$STAGE/$target/" "$BUCKET/$target/" --delete --exclude 'Packages*' --exclude Release \
        --exclude InRelease --exclude Release.gpg --cache-control "public, max-age=300" --only-show-errors
    aws s3 sync "$STAGE/$target/" "$BUCKET/$target/" --exclude '*' --include 'Packages*' --include Release \
        --include InRelease --include Release.gpg --cache-control "public, max-age=60" --only-show-errors
done
aws cloudfront create-invalidation --distribution-id "$DISTRIBUTION_ID" --paths "/nxp/$RELEASE/$BSP/*" >/dev/null
echo "==> published to https://repo.edgefirst.ai/nxp/$RELEASE/$BSP/"
