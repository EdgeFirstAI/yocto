# EdgeFirst Yocto Manifests

This repo (`EdgeFirstAI/yocto`) contains [repo](https://gerrit.googlesource.com/git-repo/) manifests for reproducing EdgeFirst Yocto builds on NXP i.MX platforms (and future i.MX-based vendor platforms).

## Rules

- Always update `README.md` and `.github/copilot-instructions.md` when making changes that affect the project setup, usage instructions, or structure. Documentation must **ALWAYS** be kept up-to-date.

## Repository Structure

```
EdgeFirstAI/yocto/
  .github/
    copilot-instructions.md       # This file (CLAUDE.md format)
    scripts/
      repo-deploy.sh              # Publish images/SDKs to S3
  base/
    imx-6.12.49-2.2.0.xml        # NXP base manifest (from nxp-imx/imx-manifest)
  templates/
    imx/
      bblayers.conf               # NXP layers + meta-edgefirst + meta-kinara
  edgefirst-imx-6.12.49-2.2.0.xml  # EdgeFirst overlay manifest
  edgefirst-setup                   # Build environment setup script
  README.md
```

## How the Manifest Works

Users init with `repo init -m edgefirst-imx-6.12.49-2.2.0.xml`. That manifest:

1. **`<include name="base/imx-6.12.49-2.2.0.xml">`** — pulls in all NXP projects and remotes
2. **`<extend-project name="meta-imx">`** — overrides NXP's `README.md` linkfile dest to `README-NXP.md`, and redirects `imx-setup-release.sh` to `.nxp-setup/`
3. **`<extend-project name="fsl-community-bsp-base">`** — redirects `setup-environment` to `.nxp-setup/`
4. **`<project name="meta-edgefirst">` / `<project name="meta-kinara">`** — our layers
5. **`<project name="yocto">`** — self-reference: checks out this repo at `.edgefirst/` and creates symlinks for `.github/`, `README.md`, and `edgefirst-setup`

The `extend-project` linkfile overrides work because a linkfile with a `dest` that already exists in the original project replaces the original (per repo manifest spec).

## Working Tree (after `repo sync`)

```
.edgefirst/              # This manifest repo (EdgeFirstAI/yocto)
.github → .edgefirst/.github
README.md → .edgefirst/README.md
edgefirst-setup → .edgefirst/edgefirst-setup
README-NXP.md → sources/meta-imx/README.md
.nxp-setup/
  setup-environment → sources/base/setup-environment      # NXP (redirected, unused)
  imx-setup-release.sh → sources/meta-imx/tools/imx-setup-release.sh  # NXP (redirected, unused)
sources/
  meta-edgefirst/        # EdgeFirst perception platform layer
  meta-kinara/           # Kinara Ara-2 NPU support layer
  meta-imx/              # NXP i.MX BSP (upstream)
  poky/                  # Yocto Project reference distribution
  ...                    # Other upstream layers
build/                   # Single build directory (created by edgefirst-setup)
```

## edgefirst-setup

`edgefirst-setup` replaces the NXP two-script flow (`setup-environment` + `imx-setup-release.sh`). It is sourced, not executed.

**First run** (`source edgefirst-setup -b build`):
1. Sources `sources/poky/oe-init-build-env` to create the build directory
2. Generates `local.conf`: sets `DISTRO=fsl-imx-wayland`, `PACKAGE_CLASSES=package_deb`, adds `package-management` to `EXTRA_IMAGE_FEATURES`, omits `MACHINE` (pass on command line)
3. Copies `templates/imx/bblayers.conf` with all NXP + EdgeFirst layers
4. Runs NXP's `machine_overrides`/`bbclass_overrides` (from `setup-utils.sh`) to remove upstream files that `meta-imx` layers override
5. Prompts for NXP EULA acceptance

**Re-entry** (`source edgefirst-setup -b build`):
1. Sources `oe-init-build-env` (sets up bitbake in PATH)
2. Checks EULA status

Optional: `MACHINE=imx8mp-lpddr4-frdm source edgefirst-setup -b build` bakes the machine into `local.conf`.

## Build Configuration

- **Distro:** `fsl-imx-wayland`
- **Image:** `imx-image-full`
- **Package format:** `package_deb` with `package-management` (apt on targets)
- **Single build dir:** `build/` — pass `MACHINE=` on the command line

### Supported Machines

| MACHINE                      | Board              |
|------------------------------|--------------------|
| imx8mp-lpddr4-frdm           | i.MX 8M Plus FRDM  |
| imx8mpevk                    | i.MX 8M Plus EVK   |
| imx95-15x15-lpddr4x-frdm    | i.MX 95 FRDM       |
| imx95-19x19-lpddr5-evk      | i.MX 95 EVK        |

### Setup

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b main -m edgefirst-imx-6.12.49-2.2.0.xml
repo sync
source edgefirst-setup -b build
```

### Building

```bash
MACHINE=imx8mp-lpddr4-frdm bitbake imx-image-full

# Build SDK
MACHINE=imx8mp-lpddr4-frdm bitbake imx-image-full -c populate_sdk

# Build a single recipe
MACHINE=imx8mp-lpddr4-frdm bitbake edgefirst-hal
```

### Re-entering the build environment

```bash
source edgefirst-setup -b build
```

## Publishing Images and SDKs

`.github/scripts/repo-deploy.sh` uploads built images and SDKs to S3 with CloudFront distribution.

- **S3 bucket:** `s3://edgefirst-repo/yocto/nxp/`
- **Public URL:** `https://repo.edgefirst.ai/yocto/nxp/`

```bash
.github/scripts/repo-deploy.sh --dry-run                         # Preview all
.github/scripts/repo-deploy.sh --machine imx8mp-lpddr4-frdm      # Deploy one machine
.github/scripts/repo-deploy.sh --force                            # Force re-upload
.github/scripts/repo-deploy.sh --version 1.2.3                   # Override version
```

The script auto-discovers machines from `build/tmp/deploy/images/*/` by looking for `{image}-*.rootfs.wic.zst`.

## Cross-Compilation SDK

SDKs install to `/opt/fsl-imx-wayland-{version}-{board}/`.

```bash
# Install
sudo build/tmp/deploy/sdk/fsl-imx-wayland-glibc-x86_64-imx-image-full-armv8a-imx8mp-lpddr4-frdm-toolchain-*.sh \
    -d /opt/fsl-imx-wayland-6.12.49-2.2.0-imx8mp-frdm -y

# Source environment
source /opt/fsl-imx-wayland-6.12.49-2.2.0-imx8mp-frdm/environment-setup-armv8a-poky-linux

# CMake
cmake -B build -DCMAKE_TOOLCHAIN_FILE=$OECORE_NATIVE_SYSROOT/usr/share/cmake/OEToolchainConfig.cmake
cmake --build build
```

## Our Layers

### meta-edgefirst

EdgeFirst perception platform: HAL, camera/sensor services, GStreamer ML pipelines, NNStreamer examples, Zenoh infrastructure, web UI.

### meta-kinara

Kinara Ara-2 NPU support: kernel module, firmware, userspace libraries. The Ara-2 runtime requires `KINARA_MIRROR` to be configured (NDA required). See [setup instructions](https://github.com/EdgeFirstAI/meta-kinara?tab=readme-ov-file#ara-2-runtime-nda-required). Builds succeed without it since the runtime is not included by default.

## Adding Vendor Manifests

To support a new i.MX-based vendor platform:

1. Add the vendor's base manifest to `base/` (e.g., `base/vendor-foobar.xml`)
2. Create `edgefirst-vendor-foobar.xml` — uses `<include>` for the base, `<extend-project>` for any overrides, and adds our layers and self-reference
3. Add a matching `templates/vendor/bblayers.conf` if the layer set differs
4. Users init with: `repo init -m edgefirst-vendor-foobar.xml`

## Skills Reference

| Domain | Skill | When to use |
|--------|-------|-------------|
| Yocto/BitBake | `linux-sdk:yocto` | Writing/modifying recipes, bbappends, layers, image configuration |
| GStreamer | `linux-sdk:gstreamer` | Building or debugging GStreamer/NNStreamer pipelines |
| GStreamer profiling | `linux-sdk:gstreamer-profiling` | Pipeline latency, FPS, element timing |
| NNStreamer | `linux-sdk:nnstreamer` | ML inference pipelines with tensor_filter |
| V4L2 | `linux-sdk:v4l2` | Camera capture, hardware video encode/decode |
| Linux perf | `linux-sdk:linux-perf` | CPU profiling, cache analysis, hardware counters |
| ftrace | `linux-sdk:ftrace` | Kernel function tracing, scheduler analysis |
| eBPF | `linux-sdk:ebpf-tracing` | Dynamic kernel/userspace tracing |
| Perfetto | `linux-sdk:perfetto` | Trace files for Perfetto UI |
| Tracy | `linux-sdk:tracy` | C/C++/Rust application profiling |
| Valgrind | `linux-sdk:valgrind` | Callgrind, Cachegrind, Massif |
| Block I/O | `linux-sdk:blktrace` | Storage latency and disk I/O |
| Tracing choice | `linux-sdk:tracing-decision-tree` | Choosing the right tracing tool |
| Zenoh | `linux-sdk:zenoh` | Pub/sub, shared memory, ROS 2 bridge |
| Rust | `dev-tools:rust` | Rust crate development, Cargo, cross-compilation |
| EdgeFirst format | `edgefirst:edgefirst-format` | EdgeFirst datasets and Arrow/Polars DataFrames |
| EdgeFirst Studio | `edgefirst:edgefirst-client` | CLI for dataset management, training |
