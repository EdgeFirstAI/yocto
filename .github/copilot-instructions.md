# EdgeFirst Yocto Manifests

This repo (`EdgeFirstAI/yocto`) contains [repo](https://gerrit.googlesource.com/git-repo/) manifests for reproducing EdgeFirst Yocto builds on NXP i.MX platforms (and future i.MX-based vendor platforms).

## Rules

- Always update `README.md` and `.github/copilot-instructions.md` when making changes that affect the project setup, usage instructions, or structure. Documentation must **ALWAYS** be kept up-to-date.
- **We own everything.** "Bug exists in another repository" is **NEVER** an acceptable conclusion. Yocto gives us access to every repository in the build — NNStreamer, edgefirst-gstreamer, edgefirst-hal, meta-edgefirst, meta-kinara, tflite-vx-delegate — and we are totally responsible for addressing **ANY** and **ALL** performance limitations or bugs in any of them. When you hit a limitation in one component (e.g., Ara-2 tensor_filter rejects DMA-BUF input), you investigate and fix that component. No shortcuts, no deference, no "that's upstream's problem."

## Repository Structure

```
EdgeFirstAI/yocto/
  .github/
    copilot-instructions.md       # This file (CLAUDE.md format)
    scripts/
      repo-deploy.sh              # Publish images/SDKs to S3
  templates/
    imx/
      bblayers.conf               # NXP layers + meta-edgefirst + meta-kinara
  edgefirst-imx-6.12.49-2.2.0.xml  # Standalone manifest (NXP BSP + EdgeFirst)
  edgefirst-setup                   # Build environment setup script
  README.md
```

## How the Manifest Works

Users init with `repo init -m edgefirst-imx-6.12.49-2.2.0.xml`. That manifest is a **standalone** manifest (not an overlay) that defines all projects directly:

1. **NXP i.MX BSP projects** — all NXP project definitions for the imx-6.12.49-2.2.0 release, with NXP root linkfiles removed (`setup-environment`, `imx-setup-release.sh`). NXP `README.md` is exposed as `README-NXP.md` for reference.
2. **`<project name="meta-edgefirst">` / `<project name="meta-kinara">`** — our layers
3. **`<project name="yocto">`** — self-reference: checks out this repo at `sources/edgefirst-yocto/` and creates symlinks for `.github/`, `README.md`, and `edgefirst-setup`

Users can either use this manifest directly, or add `meta-edgefirst` and `meta-kinara` to their own NXP manifest setup.

## Working Tree (after `repo sync`)

```
.github → sources/edgefirst-yocto/.github
README.md → sources/edgefirst-yocto/README.md
README-NXP.md → sources/meta-imx/README.md
edgefirst-setup → sources/edgefirst-yocto/edgefirst-setup
sources/
  edgefirst-yocto/       # This manifest repo (EdgeFirstAI/yocto)
  meta-edgefirst/        # EdgeFirst perception platform layer
  meta-kinara/           # Kinara Ara-2 NPU support layer
  meta-imx/              # NXP i.MX BSP (upstream)
  poky/                  # Yocto Project reference distribution
  ...                    # Other upstream layers
build-<machine>/         # Per-MACHINE build directory (created by edgefirst-setup)
```

## edgefirst-setup

`edgefirst-setup` replaces the NXP two-script flow (`setup-environment` + `imx-setup-release.sh`). It is sourced, not executed.

**MACHINE is required on first run** and is baked into `local.conf`. Use per-MACHINE build directories (e.g., `build-imx8mp-frdm`) to avoid deb package conflicts when building for multiple platforms. `downloads/` and `sstate/` are shared across build directories.

**First run** (`MACHINE=imx8mp-lpddr4-frdm source edgefirst-setup -b build-imx8mp-frdm`):
1. Sources `sources/poky/oe-init-build-env` to create the build directory
2. Generates `local.conf`: sets `DISTRO=fsl-imx-wayland`, `PACKAGE_CLASSES=package_deb`, `MACHINE`, adds `package-management` to `EXTRA_IMAGE_FEATURES`
3. Sets `DL_DIR` and `SSTATE_DIR` to shared locations (`${BSPDIR}/downloads/`, `${BSPDIR}/sstate/`)
4. Copies `templates/imx/bblayers.conf` with all NXP + EdgeFirst layers
5. Runs NXP's `machine_overrides`/`bbclass_overrides` (from `setup-utils.sh`) to remove upstream files that `meta-imx` layers override
6. Prompts for NXP EULA acceptance

**Re-entry** (`source edgefirst-setup -b build-imx8mp-frdm`):
1. Sources `oe-init-build-env` (sets up bitbake in PATH)
2. Checks EULA status
3. MACHINE is not required — already baked into local.conf

## Build Configuration

- **Distro:** `fsl-imx-wayland`
- **Image:** `imx-image-full`
- **Package format:** `package_deb` with `package-management` (apt on targets)
- **Per-MACHINE build dirs:** e.g., `build-imx8mp-frdm/` — MACHINE is baked into `local.conf`

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
MACHINE=imx8mp-lpddr4-frdm source edgefirst-setup -b build-imx8mp-frdm
```

### Building

```bash
# MACHINE is baked into local.conf — no need to prefix commands
bitbake imx-image-full

# Build SDK
bitbake imx-image-full -c populate_sdk

# Build a single recipe
bitbake edgefirst-hal
```

### Re-entering the build environment

```bash
source edgefirst-setup -b build-imx8mp-frdm
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

The script auto-discovers machines from `<build-dir>/tmp/deploy/images/*/` by looking for `{image}-*.rootfs.wic.zst`.

## Cross-Compilation SDK

SDKs install to `/opt/fsl-imx-wayland-{version}-{board}/`.

```bash
# Install
sudo build-imx8mp-frdm/tmp/deploy/sdk/fsl-imx-wayland-glibc-x86_64-imx-image-full-armv8a-imx8mp-lpddr4-frdm-toolchain-*.sh \
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

## Yocto Release Compatibility (Scarthgap + Walnascar)

meta-edgefirst **must** build on both **Scarthgap** (Yocto 5.0 LTS) and **Walnascar** (Yocto 5.2). Key differences between the two releases affect how recipes are written:

### UNPACKDIR / WORKDIR

Walnascar introduced `UNPACKDIR` (defaults to `${WORKDIR}/sources`) and added a `do_qa_unpack` check that **fatals** when a recipe contains the raw assignment `S = "${WORKDIR}"`. Scarthgap does not define `UNPACKDIR` at all.

**Rule:** Never write `S = "${WORKDIR}"` in any recipe. Use the inline Python expression:

```bitbake
S = "${@d.getVar('UNPACKDIR') or d.getVar('WORKDIR')}"
```

- **Walnascar:** `UNPACKDIR` is defined → resolves to `${WORKDIR}/sources` → QA check passes (no raw `${WORKDIR}` in S)
- **Scarthgap:** `UNPACKDIR` is `None` → `or` falls through → resolves to `${WORKDIR}` → no QA check exists → works

In `do_install` and other tasks, always reference files via `${S}` — never use `${WORKDIR}` or `${UNPACKDIR}` directly, and never use `if [ "${UNPACKDIR}" != "" ]` branching.

**Do NOT** use the anonymous `python()` shim approach (`d.setVar('S', unpackdir)`) — it runs too late and the QA check still sees the raw `S = "${WORKDIR}"` assignment.

### LAYERSERIES_COMPAT

`LAYERSERIES_COMPAT` in meta-edgefirst must include both `scarthgap` and `walnascar` (and any future release codenames as needed).

### LAYERDEPENDS

`LAYERDEPENDS` must **not** include `imx-machine-learning` — it doesn't exist in Torizon/Scarthgap builds.

## Iterative Development with devtool

`devtool` is the standard Yocto workflow for editing recipe sources, rebuilding, and deploying to a target without modifying the layer directly.

### Setup

**Always source the build environment first:**

```bash
cd /home/sebastien/edgefirst-yocto
source edgefirst-setup -b build-imx8mpevk
devtool modify nnstreamer
```

MACHINE is baked into `local.conf` on first run, so no `MACHINE=` prefix is needed on devtool/bitbake commands.

**Ask the user which MACHINE / build directory to use if you are unsure.** The machine determines the BSP, NPU delegate, and hardware-specific pipeline elements.

### Workflow

```bash
# 1. Extract source to workspace (creates build-<machine>/workspace/sources/<recipe>)
devtool modify <recipe>

# 2. Edit source files in build-<machine>/workspace/sources/<recipe>/
#    This is a full git repo — commit your changes here

# 3. Build
devtool build <recipe>

# 4. Deploy to target over SSH
devtool deploy-target <recipe> <target-host>

# 5. When done, finish the workspace (resets to layer recipe)
devtool finish <recipe> <layer-path>
```

### Important Notes

- **Every devtool/bitbake command needs the build env sourced first.** If you open a new shell, re-run `source edgefirst-setup -b build-<machine>`.
- **devtool creates a `devtool` branch** in `build-<machine>/workspace/sources/<recipe>/`. Commits on this branch are applied as patches by bitbake.
- **Pushing changes back upstream:** The workspace git repos have `origin` pointing to the upstream GitHub repo. Commit locally, then coordinate with the user on when/where to push (branch, PR, etc.).
- **deploy-target uses SSH.** Target hostnames are configured in the user's SSH config (e.g., `imx8mpevk-06`). Use `ssh <hostname>` to test connectivity — do not hardcode `root@`.
- **Rebuilding dependent recipes:** If you modify a library (e.g., nnstreamer), recipes that depend on it (e.g., imx-nnstreamer-examples) may need rebuilding too.

### Target Board SSH

Target boards are accessed via hostname defined in the user's SSH config. Always use `ssh <hostname>` (e.g., `ssh imx8mpevk-06`), never `ssh root@<hostname>` — the SSH config handles the user. No password is needed.

### Common Recipes

| Recipe | Repo | Description |
|--------|------|-------------|
| `nnstreamer` | `EdgeFirstAI/nnstreamer` | GStreamer ML pipeline framework |
| `imx-nnstreamer-examples` | `EdgeFirstAI/nxp-nnstreamer-examples` | YOLOv8n demo binaries |
| `edgefirst-hal` | — | EdgeFirst HAL (quantized NMS, model metadata) |
| `tflite-vx-delegate` | — | TFLite VeriSilicon NPU delegate |

### Known Issues

None currently tracked.

## Benchmarking on Target Boards

### One benchmark at a time per board

**NEVER run more than one benchmark concurrently on the same board.** NPU accelerators (Ara-2, VSI, Neutron) are shared resources — concurrent inference pipelines will contend for the NPU, DMA channels, memory bandwidth, and CPU, producing unreliable numbers. Always run benchmarks **sequentially** on a given board (chain with `&&` in a single SSH session).

**DO run benchmarks on different boards in parallel.** Each board has its own NPU and memory subsystem, so `ssh imx8mp-frdm "benchmark1" &` and `ssh imx95-frdm "benchmark2"` is fine and saves time.

The only exception is if the benchmark's explicit purpose is to measure resource contention (e.g., two pipelines sharing the NPU).

### Standard benchmark parameters

- Use `-H` (headless) and `-n 1800` for reproducible throughput numbers
- Use `-v /tmp/test_video.mp4` — the standard test video is `853889-hd_1920_1080_25fps.mp4` (H.264 High Profile 1920x1080 25fps, people visible). Download from `https://repo.edgefirst.ai/testdata/853889-hd_1920_1080_25fps.mp4` or copy from `~/models/` on the build host via `scp ~/models/853889-hd_1920_1080_25fps.mp4 <board>:/tmp/test_video.mp4`. This is on tmpfs and is wiped on reboot.
- Use full binary paths (`/opt/edgefirst/<binary>`) since they are not in `$PATH`
- Capture output with `| tee /tmp/<board>-<pipeline>-<model>.log` to preserve results
- For multi-model runs, chain sequentially: `ssh <board> "bench1 && echo '===SEPARATOR===' && bench2 && ..."`

### Ara-2 specifics

- `systemctl enable --now ara2` must be active before benchmarking
- If Ara-2 fails with `DV_MODEL_LOAD_FAILURE code=520`, full power cycle the board (multiple cycles may be needed)
- The `yolov8n_ara2` binary accepts any `.dvm` model via `-m`, not just YOLOv8n — the binary name is misleading
- The `yolov8n_ara2_reference` binary provides the NNStreamer reference pipeline with per-element timing breakdown

## Adding Vendor Manifests

To support a new i.MX-based vendor platform:

1. Create a standalone manifest (e.g., `edgefirst-vendor-foobar.xml`) with the vendor's projects and our layers + self-reference project
2. Add a matching `templates/vendor/bblayers.conf` if the layer set differs
3. Users init with: `repo init -m edgefirst-vendor-foobar.xml`

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
