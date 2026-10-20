#!/bin/sh
# Move an existing NXP i.MX image onto the EdgeFirst package feed.
#
#   edgefirst-adopt RELEASE BSP [--yes]
#
#   edgefirst-adopt 2026.10 imx-6.12.49-2.2.0
#
# Run as root on the board. It needs dpkg and apt, so an image built with rpm or
# ipk packages has to be reflashed instead. The board's packages are then
# replaced by the feed's builds of the same BSP, and its kernel and device trees
# are replaced with the ones in the feed, so keep the backup it makes of the boot
# partition until the new kernel has been shown to boot. This is a best effort
# for images that are close to ours; an image with a different package set or a
# customised root filesystem is better reflashed.
#
# The feed's signing key arrives in a package, so the first packages are fetched
# from the feed over HTTPS without checking its signature. Everything after that
# is checked against the key.
set -eu

FEED_URI="${EDGEFIRST_FEED_URI:-https://repo.edgefirst.ai/nxp}"
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
RELEASE="${1:?usage: edgefirst-adopt RELEASE BSP, for example 2026.10 imx-6.12.49-2.2.0}"
BSP="${2:?usage: edgefirst-adopt RELEASE BSP, for example 2026.10 imx-6.12.49-2.2.0}"

die() { echo "edgefirst-adopt: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "must be run as root"
command -v dpkg >/dev/null && command -v apt-get >/dev/null \
    || die "this image has no dpkg and apt (it uses another package format); reflash it with an EdgeFirst image"
[ "$(dpkg --print-architecture)" = arm64 ] || die "not an arm64 image"
if [ -r /etc/os-release ] && grep -q '^EDGEFIRST_RELEASE=' /etc/os-release; then
    die "this board already runs EdgeFirst Yocto; use apt update and apt full-upgrade"
fi

BOOT_DEV="$(blkid -L boot 2>/dev/null)" || die "no partition is labelled boot; this is not a layout the update mechanism supports"
MACHINE_ARCH="$(dpkg-query -W -f '${PackageArch}' base-files 2>/dev/null || true)"
[ -n "$MACHINE_ARCH" ] || die "cannot tell the machine from the installed packages"
ARCHS="$(dpkg-query -W -f '${PackageArch}\n' 2>/dev/null | sort -u | grep -v '^$' | tr '\n' ' ')"

echo "Machine package architecture: $MACHINE_ARCH"
echo "Feed: $FEED_URI/$RELEASE/$BSP"
echo "Boot partition: $BOOT_DEV"
if [ "$ASSUME_YES" -eq 0 ]; then
    printf 'Replace this board'"'"'s packages, kernel and device trees with EdgeFirst Yocto %s for %s? [y/N] ' "$RELEASE" "$BSP"
    read -r answer
    case "$answer" in y|Y|yes) ;; *) echo "cancelled"; exit 1 ;; esac
fi

BACKUP="/root/edgefirst-adopt-backup-$(date +%Y%m%d%H%M%S)"
mkdir -p "$BACKUP/boot"
if grep -q ' /boot ' /proc/mounts; then
    cp -a /boot/. "$BACKUP/boot/"
else
    mp="$(awk -v d="$BOOT_DEV" '$1 == d { print $2; exit }' /proc/mounts)"
    if [ -z "$mp" ]; then
        mkdir -p "$BACKUP/mnt" && mount -o ro "$BOOT_DEV" "$BACKUP/mnt" && mp="$BACKUP/mnt"
    fi
    cp -a "$mp"/. "$BACKUP/boot/"
    ! grep -q " $BACKUP/mnt " /proc/mounts || umount "$BACKUP/mnt"
fi
cp -a /etc/fstab "$BACKUP/fstab"
echo "Boot partition and fstab saved in $BACKUP"

LIST=/etc/apt/sources.list.d/edgefirst.list
[ ! -e "$LIST" ] || mv "$LIST" "$BACKUP/edgefirst.list"
for arch in all $ARCHS; do
    echo "deb [trusted=yes] $FEED_URI/$RELEASE/$BSP/$arch ./"
done | awk '!seen[$0]++' > "$LIST"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --allow-downgrades -o Dpkg::Options::=--force-confnew -o Dpkg::Options::=--force-confmiss \
    gnupg edgefirst-apt-config
# The package replaced the list with the signed one; from here the feed is checked.
apt-get update
apt-get install -y --allow-downgrades -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold edgefirst-release
apt-get full-upgrade -y --allow-downgrades -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold

# The kernel packages the image came with are now older than the feed's. Their
# stock removal script deletes /boot/Image whichever kernel it belongs to, so it
# is neutralised, and they are marked as automatically installed so that
# apt autoremove retires them like any other old kernel.
for script in /var/lib/dpkg/info/kernel-image-image-*.postrm; do
    if [ -e "$script" ] && grep -q 'rm -f boot/Image' "$script"; then
        printf '#!/bin/sh\nexit 0\n' > "$script"
    fi
done
apt-mark auto $(dpkg-query -W -f '${Package}\n' 'kernel-*') >/dev/null

. /etc/os-release
echo "Now on ${PRETTY_NAME:-EdgeFirst Yocto}. Reboot to run the new kernel, then run apt autoremove."
echo "If the board does not boot, the previous kernel is /boot/Image.prev (set image=Image.prev in U-Boot); the original boot partition is in $BACKUP/boot."
