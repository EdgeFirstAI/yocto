# EdgeFirst Yocto

Yocto manifests for building EdgeFirst embedded Linux images. Currently supports NXP i.MX platforms, designed to extend to other vendors building i.MX-based platforms.

This is the `edgefirst-imx-6.18.20-2.0.0` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto). Each supported platform and BSP has its own branch; the `main` branch lists them all.

## Prerequisites

- [repo tool](https://gerrit.googlesource.com/git-repo/)
- Host packages for Yocto (see [Yocto Quick Start](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html))
- AWS CLI (for publishing images)

## Quick Start

```bash
# 1. Initialize and sync
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b edgefirst-imx-6.18.20-2.0.0 -m edgefirst-imx-6.18.20-2.0.0.xml
repo sync

# 2. Set up build environment (first time — prompts for NXP EULA)
MACHINE=imx8mp-lpddr4-frdm source edgefirst-setup -b build-imx8mp-frdm

# 3. Build an image
bitbake imx-image-full
```

## Choosing a BSP

`EdgeFirstAI/yocto` is a family of detached branches, one per platform and BSP, with no shared history; the `main` branch indexes them. Besides the NXP i.MX branches below there are branches for Toradex Torizon, PHYTEC (i.MX 95 and i.MX 8M Plus), and Ezurio Nitrogen SMARC. The vendor branches keep the vendor's projects as published and add [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) plus a `meta-edgefirst-<vendor>` layer; only the NXP branches use meta-kinara and the Ara-2 NPU. A change to meta-edgefirst reaches a branch only when that branch's manifest is re-pinned, so the branches are re-pinned together when it changes.

The NXP i.MX branches each track one NXP BSP, and both pin the latest meta-edgefirst and meta-kinara:

| Branch | Manifest | NXP BSP | Use for |
|---|---|---|---|
| `edgefirst-imx-6.18.20-2.0.0` | `edgefirst-imx-6.18.20-2.0.0.xml` | 6.18.20-2.0.0 (wrynose) | i.MX 95, and i.MX 8M Plus without Ara-2 |
| `edgefirst-imx-6.12.49-2.2.0` | `edgefirst-imx-6.12.49-2.2.0.xml` | 6.12.49-2.2.0 (walnascar) | i.MX 8M Plus with the Ara-2 NPU |

i.MX 8M Plus boards with an Ara-2 hang under Ara-2 inference load on the 6.18.20 BSP, while the same Ara-2 runtime, driver, and bindings run stably on 6.12.49. Use the `edgefirst-imx-6.12.49-2.2.0` branch for them until that is resolved:

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b edgefirst-imx-6.12.49-2.2.0 -m edgefirst-imx-6.12.49-2.2.0.xml
```

On that branch the Ara-2 runtime is the Kinara SDK packaging from meta-kinara (`ara2.service`, enable it with `systemctl enable --now ara2`), and the NNStreamer Ara-2 sub-plugin (`nnstreamer-ara2`) is built. Release tags such as `v1.2.3` are fixed snapshots and are not updated.

The setup script:

- Requires `MACHINE` on first run — bakes it into `local.conf`
- Defaults to `fsl-imx-wayland` distro and `package_deb` packaging
- Installs `bblayers.conf` with all NXP + EdgeFirst layers
- Shares `downloads/` and `sstate/` across build directories
- Prompts for NXP EULA acceptance (one time)

Use per-MACHINE build directories to avoid deb package conflicts between different platforms:

```bash
MACHINE=imx8mp-lpddr4-frdm source edgefirst-setup -b build-imx8mp-frdm
MACHINE=imx95-19x19-lpddr5-evk source edgefirst-setup -b build-imx95-evk
```

To re-enter the build environment in a new shell:

```bash
source edgefirst-setup -b build-imx8mp-frdm
```

## Supported Machines

| MACHINE | Board |
|---------|-------|
| `imx8mp-lpddr4-frdm` | i.MX 8M Plus FRDM |
| `imx8mpevk` | i.MX 8M Plus EVK |
| `imx95-15x15-lpddr4x-frdm` | i.MX 95 FRDM |
| `imx95-19x19-lpddr5-evk` | i.MX 95 EVK |

## Updating a Board

An EdgeFirst Yocto release is named `YYYY.MM` and published quarterly, and a release receives rolling `PATCH` updates, so a board runs `YYYY.MM.PATCH` such as 2026.10.1. The NXP BSP the release is built on keeps its own version, such as 6.18.20-2.0.0, and is never changed by EdgeFirst. Both are shown together:

```bash
$ grep -E '^(PRETTY_NAME|EDGEFIRST)' /etc/os-release
PRETTY_NAME="EdgeFirst Yocto 2026.10.1 for NXP i.MX BSP 6.18.20-2.0.0"
EDGEFIRST_RELEASE="2026.10"
EDGEFIRST_VERSION="2026.10.1"
EDGEFIRST_BSP="imx-6.18.20-2.0.0"
```

A board running an image from this branch updates itself over the network with `apt` from a signed package feed, `https://repo.edgefirst.ai/nxp/<release>/imx-6.18.20-2.0.0/`. This is meant to give developers a quick way to update the BSP, kernel included, and to add packages that are not in the base image, not to be an industrial update system.

### Updates within a release

```bash
apt update
apt full-upgrade
reboot
apt autoremove
```

`full-upgrade` is needed rather than `upgrade` because a new kernel arrives as new packages. The `edgefirst-release` package ties the operating system identification, kernel, device trees and modules together, so they always move as a set. Any package built for the BSP can be installed with `apt install <package>`, and `apt-cache search <text>` finds it.

The boot partition is mounted on `/boot`, so the kernel and device trees that `apt` installs are the files U-Boot loads. The running kernel is `/boot/Image`, and the one it replaced is `/boot/Image.prev`. The new kernel is installed beside the old one, whose modules stay installed until `apt autoremove`, so `Image.prev` is a working fallback until then: set `image=Image.prev` in U-Boot to boot it. The boot partition is 256 MB and each kernel needs about 35 MB, so run `apt autoremove` after you have checked the new kernel, or remove one yourself with `apt remove kernel-<version>`.

Every package comes from the feed, which is checked against the EdgeFirst package signing key. `apt` refuses a feed that is not signed by that key.

### Moving to the next release

A new quarterly release has its own feed and may be built on a newer NXP BSP. The release upgrade tool moves a board to it, in the spirit of Ubuntu's `do-release-upgrade`:

```bash
edgefirst-release-upgrade --check   # Is a newer release available?
edgefirst-release-upgrade           # Move to it
reboot
apt autoremove
```

It reads the signed list of releases, refuses unless the board is fully up to date and `/boot` has room, switches `apt` to the new release's feed and runs the upgrade. A run that stops part way is finished by running the tool again. It makes a best effort and is not a guarantee: a release that changes the boot firmware, the partition layout or the Ara-2 card firmware still needs a reflash, and the release notes say so.

## Publishing

Publish the package feed for a release and BSP from a build that has built `imx-image-full` with `.github/scripts/publish-apt-feed.sh`:

```bash
.github/scripts/publish-apt-feed.sh build-imx95-frdm            # Stage and sign under <build-dir>/apt-feed
.github/scripts/publish-apt-feed.sh --upload build-imx95-frdm   # Publish to https://repo.edgefirst.ai/nxp/
.github/scripts/publish-apt-feed.sh --announce --upload \
    --upgrade-from 2026.10/imx-6.18.20-2.0.0 build-imx95-frdm   # Let boards find a new quarterly release
```

The feed is signed with the key in `~/edgefirst-ca/nxp` (see the README there), and the release, BSP name and architecture directories come from the `edgefirst-apt-config` package in the build, so the feed has the layout the images were built to read. A feed is the rolling channel of its release: publishing replaces the previous contents, and boards that run `apt update` and `apt full-upgrade` follow it. Debug, source and test packages are left out. Run it once per machine; the packages shared between machines are published once. `--announce` is only for a new quarterly release, once every machine's feed for it is published; a PATCH update is announced by being in the feed.

Set the release a build belongs to with `EDGEFIRST_VERSION` in `conf/local.conf`, as `YYYY.MM.PATCH`. The default in `templates/imx/site.conf` is `~dev` ahead of the next release, so a release build sets it without the suffix, and a release candidate uses `~rcN`.

Upload built images and SDKs to S3 with `repo-deploy.sh`:

```bash
.github/scripts/repo-deploy.sh --dry-run                         # Preview
.github/scripts/repo-deploy.sh                                    # Deploy all discovered machines
.github/scripts/repo-deploy.sh --machine imx8mp-lpddr4-frdm      # Deploy one machine
.github/scripts/repo-deploy.sh --force                            # Force re-upload
```

Artifacts are published to `https://repo.edgefirst.ai/yocto/nxp/`.

The script auto-discovers built machines by scanning `<build-dir>/tmp/deploy/images/*/` for image files.

```
Usage: repo-deploy.sh [OPTIONS]

Options:
  --machine MACHINE   Deploy only this machine (default: all discovered)
  --image NAME        Image name (default: imx-image-full)
  --build-dir DIR     Build directory (default: build)
  --version VER       Override version (default: auto-detect)
  --dry-run           Show what would be deployed
  --force             Upload even if checksums match
  -h, --help          Show help
```

## SDK Installation

Build and install the cross-compilation SDK:

```bash
bitbake imx-image-full -c populate_sdk

sudo build-imx8mp-frdm/tmp/deploy/sdk/fsl-imx-wayland-glibc-x86_64-imx-image-full-armv8a-imx8mp-lpddr4-frdm-toolchain-*.sh \
    -d /opt/fsl-imx-wayland-6.18.20-2.0.0-imx8mp-frdm -y
```

Use it:

```bash
source /opt/fsl-imx-wayland-6.18.20-2.0.0-imx8mp-frdm/environment-setup-armv8a-poky-linux

# CMake
cmake -B build -DCMAKE_TOOLCHAIN_FILE=$OECORE_NATIVE_SYSROOT/usr/share/cmake/OEToolchainConfig.cmake
cmake --build build

# Cargo
cargo build --target aarch64-unknown-linux-gnu
```

## Adding Vendor Manifests

Each vendor platform and BSP gets its own branch, plus a `meta-edgefirst-<vendor>` layer for everything specific to that vendor (image, update mechanism, vendor kernel patches). Portable content stays in meta-edgefirst:

1. Create a branch named `edgefirst-<vendor>-<bsp-version>` with a standalone manifest of the same name (e.g., `edgefirst-vendor-foobar.xml`) holding the vendor's projects, our layers, and a self-reference to that branch
2. Users init with: `repo init -b <branch> -m <manifest>.xml`
3. Add the branch to the index in `main`'s README

## Our Layers

### [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst)

EdgeFirst perception platform: HAL, camera/sensor services, GStreamer ML pipelines, NNStreamer examples, Zenoh infrastructure, and web UI.

### [meta-kinara](https://github.com/EdgeFirstAI/meta-kinara)

Kinara Ara-2 NPU support: kernel module, firmware, and userspace libraries.

The Ara-2 runtime is `imx-nxp-ara2`. On the 6.18.20 BSP (this branch), NXP's packaging (`rt-sdk-ara2`, from meta-imx-ml) is used and needs no extra configuration. meta-kinara also packages the Kinara SDK under the same recipe name, so only one runtime is ever installed; that packaging is used on the 6.12.49 BSP (`edgefirst-imx-6.12.49-2.2.0`), on builds without meta-imx-ml, or when selected with `PREFERRED_VERSION_imx-nxp-ara2 = "1.2.1"`, and it requires `KINARA_MIRROR` (NDA required). The NNStreamer Ara-2 sub-plugin is built only with the Kinara SDK runtime. An Ara-2 card that has run NXP's runtime needs its boot firmware restored before the Kinara SDK runtime accepts it. See [Choosing an Ara-2 runtime](https://github.com/EdgeFirstAI/meta-kinara?tab=readme-ov-file#choosing-an-ara-2-runtime), [Ara-2 card boot firmware](https://github.com/EdgeFirstAI/meta-kinara?tab=readme-ov-file#ara-2-card-boot-firmware), and [Ara-2 Runtime setup instructions](https://github.com/EdgeFirstAI/meta-kinara?tab=readme-ov-file#ara-2-runtime-nda-required).

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.

Each EdgeFirst package ships its own CHANGELOG.md in its GitHub
repository. The layer changelogs
([meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md),
[meta-kinara](https://github.com/EdgeFirstAI/meta-kinara/blob/main/CHANGELOG.md))
list package version changes with links to the upstream per-package
changelogs at the pinned version tag, e.g.:

```
https://github.com/EdgeFirstAI/hal/blob/v0.16.2/CHANGELOG.md
```

When tagging a release:

1. Update each layer's `CHANGELOG.md` — collapse intermediate version
   bumps so only the final version appears (e.g., HAL 0.8.0 → 0.16.2,
   not the full 0.8 → 0.9 → 0.13 → 0.15 → 0.16 chain)
2. Link each package entry to its `CHANGELOG.md` at the version tag
3. Update this repo's `CHANGELOG.md` with the layer summary
4. Tag the manifest and layers
