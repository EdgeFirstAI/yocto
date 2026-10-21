#!/bin/sh
# Move an existing NXP i.MX image onto the EdgeFirst package feed.
#
#   edgefirst-adopt RELEASE BSP [--yes]
#
#   edgefirst-adopt 2026.10 imx-6.18.37-2.1.0
#
# Run as root on the board. It needs dpkg and apt, so an image built with rpm or
# ipk packages has to be reflashed instead. The board's packages are then
# replaced by the feed's builds of the same BSP, and its kernel and device trees
# are replaced with the ones in the feed, so keep the backup it makes of the boot
# partition until the new kernel has been shown to boot. This is a best effort
# for images that are close to ours; an image with a different package set or a
# customised root filesystem is better reflashed.
#
# EDGEFIRST_FEED_URI points the board at a mirror of the feed instead of
# https://repo.edgefirst.ai/nxp.
#
# The feed's signing key arrives in a package, so the first packages are fetched
# from the feed over HTTPS without checking its signature. Everything after that
# is checked against the key.
set -eu

DEFAULT_URI=https://repo.edgefirst.ai/nxp
FEED_URI="${EDGEFIRST_FEED_URI:-$DEFAULT_URI}"
ASSUME_YES=0
ARGS=""
for a in "$@"; do
    case "$a" in
        -y|--yes) ASSUME_YES=1 ;;
        -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) ARGS="$ARGS $a" ;;
    esac
done
# shellcheck disable=SC2086
set -- $ARGS
RELEASE="${1:?usage: edgefirst-adopt RELEASE BSP, for example 2026.10 imx-6.18.37-2.1.0}"
BSP="${2:?usage: edgefirst-adopt RELEASE BSP, for example 2026.10 imx-6.18.37-2.1.0}"

die() { echo "edgefirst-adopt: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must be run as root"
command -v dpkg >/dev/null && command -v apt-get >/dev/null \
    || die "this image has no dpkg and apt (it uses another package format); reflash it with an EdgeFirst image"
[ "$(dpkg --print-architecture)" = arm64 ] || die "not an arm64 image"
if [ "$(dpkg-query -W -f '${db:Status-Status}' edgefirst-release 2>/dev/null)" = installed ]; then
    die "this board already runs EdgeFirst Yocto; use apt update and apt full-upgrade"
fi

BOOT_DEV="$(blkid -L boot 2>/dev/null)" || die "no partition is labelled boot; this is not a layout the update mechanism supports"
MACHINE_ARCH="$(dpkg-query -W -f '${PackageArch}' base-files 2>/dev/null || true)"
[ -n "$MACHINE_ARCH" ] || die "cannot tell the machine from the installed packages"
# Package architectures are written with dashes in the package metadata, but the
# feed names the directory of the machine's own packages with underscores.
ARCHS="$(dpkg-query -W -f '${PackageArch}\n' 2>/dev/null | sort -u | grep -v '^$' \
    | sed "s/^$MACHINE_ARCH\$/$(echo "$MACHINE_ARCH" | tr - _)/" | tr '\n' ' ')"

echo "Machine package architecture: $MACHINE_ARCH"
echo "Feed directories: all $ARCHS"
echo "Feed: $FEED_URI/$RELEASE/$BSP"
echo "Boot partition: $BOOT_DEV"
if [ "$ASSUME_YES" -eq 0 ]; then
    printf 'Replace this board'"'"'s packages, kernel and device trees with EdgeFirst Yocto %s for %s? [y/N] ' "$RELEASE" "$BSP"
    read -r answer
    case "$answer" in y|Y|yes) ;; *) echo "cancelled"; exit 1 ;; esac
fi

BACKUP="/root/edgefirst-adopt-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP/boot"
mp="$(findmnt -rn -o TARGET -S "$BOOT_DEV" | head -n 1)"
if [ -z "$mp" ]; then
    mkdir -p "$BACKUP/mnt" && mount -o ro "$BOOT_DEV" "$BACKUP/mnt" && mp="$BACKUP/mnt"
fi
cp -a "$mp"/. "$BACKUP/boot/"
! grep -q " $BACKUP/mnt " /proc/mounts || umount "$BACKUP/mnt"
echo "Boot partition saved in $BACKUP"

LIST=/etc/apt/sources.list.d/edgefirst.list
[ ! -e "$LIST" ] || mv "$LIST" "$BACKUP/edgefirst.list"
# The key is not on the board yet on a first run, and without gpgv apt cannot
# check the signature at all; a second run finds both, and apt then needs the key.
KEYRING=/usr/share/keyrings/edgefirst-nxp-apt.gpg
if [ -e "$KEYRING" ] && command -v gpgv >/dev/null; then
    TRUST="signed-by=$KEYRING"
else
    TRUST="trusted=yes"
fi
for arch in all $ARCHS; do
    echo "deb [$TRUST] $FEED_URI/$RELEASE/$BSP/$arch ./"
done | awk '!seen[$0]++' > "$LIST"

export DEBIAN_FRONTEND=noninteractive
OVERWRITE="-o Dpkg::Options::=--force-overwrite"
# Without this apt carries on with the index files it already has when a feed
# cannot be read, which would install the wrong versions.
STRICT="-o APT::Update::Error-Mode=any"
apt-get update
# shellcheck disable=SC2086
apt-get install -y --allow-downgrades $OVERWRITE -o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confmiss \
    gnupg edgefirst-apt-config
# The package replaced the list with the signed one; from here the feed is checked.
if [ "$FEED_URI" != "$DEFAULT_URI" ]; then
    sed -i "s#$DEFAULT_URI#$FEED_URI#" "$LIST"
    host="$(echo "$FEED_URI" | cut -d/ -f3 | cut -d: -f1)"
    sed -i "s#^Pin: origin .*#Pin: origin $host#" /etc/apt/preferences.d/edgefirst
fi
apt-get update $STRICT
# shellcheck disable=SC2086
apt-get install -y --allow-downgrades $OVERWRITE -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold edgefirst-release
# shellcheck disable=SC2086
apt-get full-upgrade -y --allow-downgrades $OVERWRITE -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold

# The kernel packages the image came with are now older than the feed's. They are
# marked as automatically installed so that apt autoremove retires them like any
# other old kernel.
apt-mark auto $(dpkg-query -W -f '${Package}\n' 'kernel-*') >/dev/null

. /etc/os-release
echo "Now on ${PRETTY_NAME:-EdgeFirst Yocto}. Reboot to run the new kernel, then run apt autoremove."
echo "If the board does not boot, the previous kernel is Image.prev on the boot partition (set image=Image.prev in U-Boot); the original boot partition is in $BACKUP/boot."
