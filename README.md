# EdgeFirst Yocto

Yocto manifests for building EdgeFirst embedded Linux images. Currently supports NXP i.MX platforms, designed to extend to other vendors building i.MX-based platforms.

## Prerequisites

- [repo tool](https://gerrit.googlesource.com/git-repo/)
- Host packages for Yocto (see [Yocto Quick Start](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html))
- AWS CLI (for publishing images)

## Quick Start

```bash
# 1. Initialize and sync
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b main -m edgefirst-imx-6.12.49-2.2.0.xml
repo sync

# 2. Set up build environment (first time)
DISTRO=fsl-imx-wayland MACHINE=imx8mp-lpddr4-frdm source imx-setup-release.sh -b build
```

After initial setup, edit `build/conf/local.conf`:

- Remove the `MACHINE` line (pass it on the command line instead)
- Set `PACKAGE_CLASSES = "package_deb"`
- Add `package-management` to `EXTRA_IMAGE_FEATURES`

Add our layers to `build/conf/bblayers.conf`:

```
BBLAYERS += "${BSPDIR}/sources/meta-edgefirst"
BBLAYERS += "${BSPDIR}/sources/meta-kinara"
```

Then build:

```bash
# 3. Build an image
MACHINE=imx8mp-lpddr4-frdm bitbake imx-image-full

# 4. Re-enter environment in a new shell
source sources/poky/oe-init-build-env build
```

## Supported Machines

| MACHINE | Board |
|---------|-------|
| `imx8mp-lpddr4-frdm` | i.MX 8M Plus FRDM |
| `imx8mpevk` | i.MX 8M Plus EVK |
| `imx95-15x15-lpddr4x-frdm` | i.MX 95 FRDM |
| `imx95-19x19-lpddr5-evk` | i.MX 95 EVK |

## Publishing

Upload built images and SDKs to S3 with `repo-deploy.sh`:

```bash
.github/scripts/repo-deploy.sh --dry-run                         # Preview
.github/scripts/repo-deploy.sh                                    # Deploy all discovered machines
.github/scripts/repo-deploy.sh --machine imx8mp-lpddr4-frdm      # Deploy one machine
.github/scripts/repo-deploy.sh --force                            # Force re-upload
```

Artifacts are published to `https://repo.edgefirst.ai/yocto/nxp/`.

The script auto-discovers built machines by scanning `build/tmp/deploy/images/*/` for image files.

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
MACHINE=imx8mp-lpddr4-frdm bitbake imx-image-full -c populate_sdk

sudo build/tmp/deploy/sdk/fsl-imx-wayland-glibc-x86_64-imx-image-full-armv8a-imx8mp-lpddr4-frdm-toolchain-*.sh \
    -d /opt/fsl-imx-wayland-6.12.49-2.2.0-imx8mp-frdm -y
```

Use it:

```bash
source /opt/fsl-imx-wayland-6.12.49-2.2.0-imx8mp-frdm/environment-setup-armv8a-poky-linux

# CMake
cmake -B build -DCMAKE_TOOLCHAIN_FILE=$OECORE_NATIVE_SYSROOT/usr/share/cmake/OEToolchainConfig.cmake
cmake --build build

# Cargo
cargo build --target aarch64-unknown-linux-gnu
```

## Adding Vendor Manifests

The repo is designed to support multiple vendors:

1. Add the vendor's base manifest to `base/` (e.g., `base/vendor-foobar.xml`)
2. Create an EdgeFirst overlay manifest (e.g., `edgefirst-vendor-foobar.xml`) that `<include>`s the base and adds our layers
3. Users init with: `repo init -m edgefirst-vendor-foobar.xml`

## Our Layers

### [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst)

EdgeFirst perception platform: HAL, camera/sensor services, GStreamer ML pipelines, NNStreamer examples, Zenoh infrastructure, and web UI.

### [meta-kinara](https://github.com/EdgeFirstAI/meta-kinara)

Kinara Ara-2 NPU support: kernel module, firmware, and userspace libraries.
