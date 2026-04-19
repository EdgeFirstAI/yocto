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

### Respect Upstream Project Instructions

When `devtool modify <recipe>` checks out a project that has its own `.github/copilot-instructions.md`, **read and follow it**. That project's rules about development practices, coding conventions, skills to load, test procedures, and commit message style apply — adapted to the context that you are building via `devtool build` instead of the project's native build system. For example, if the project says "run `cargo test` before committing," you still run the tests (via devtool or directly in the workspace), even though deployment happens through `devtool deploy-target`.

### Pre-Built Binary Projects (e.g., edgefirst-hal)

Some EdgeFirst packages publish pre-built binaries rather than building from source in Yocto. For these packages (edgefirst-hal, edgefirst-schemas), development and testing follows a different pattern:

1. **Local source checkout** — The user maintains a source checkout somewhere on the host (e.g., `~/hal/`, `~/software/hal/`). The location is per-user/per-machine — ask once per session or check memory, but do not hardcode paths in copilot-instructions.
2. **Build using the project's own toolchain** — Follow the project's `.github/copilot-instructions.md` for build and cross-compilation instructions. Do not try to build these through devtool.
3. **Deploy via scp for testing** — Copy the built binaries/libraries directly to the target board for testing:
   ```bash
   scp build/libedgefirst_hal.so <board>:/usr/lib/
   ssh <board> ldconfig
   ```
4. **Update the Yocto recipe** only after the upstream project publishes a new release (new tag, new tarball with checksums).

### Cross-Platform Testing with devtool

When testing changes across two boards (e.g., imx8mp-frdm and imx95-frdm), each board has its own build directory with its own devtool workspace:

- `build-imx8mp-frdm/workspace/sources/<recipe>/`
- `build-imx95-frdm/workspace/sources/<recipe>/`

**Do NOT cherry-pick** commits between the two workspaces. Instead, add each workspace as a git remote of the other and push/pull between them:

```bash
# In build-imx95-frdm workspace, add the imx8mp workspace as a remote
cd build-imx95-frdm/workspace/sources/<recipe>
git remote add imx8mp ../../../../build-imx8mp-frdm/workspace/sources/<recipe>
git fetch imx8mp
git merge imx8mp/devtool   # or git reset --hard imx8mp/devtool
```

Commits can be squashed before the final push to the real upstream remote. The goal is one clean history, not duplicated cherry-picks that diverge.

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

## Manual QA Validation

This section defines the QA process for validating the EdgeFirst for i.MX User Manual (`~/wp1/manual/02-quick-start.tex`) against actual hardware. The goal is to ensure every command in the manual can be copy-pasted by a user and succeed without modification.

### When to Run

Run manual QA validation:
- Before every software release (new Yocto image, HAL release, nnstreamer-examples update)
- After flashing new images to target boards
- When the user says "verify the manual" or "validate the manual" or similar

### Prerequisites

1. **Ask the user which boards are available** and their SSH hostnames (e.g., `imx95-frdm`, `imx8mp-frdm`). Do not assume board names.
2. **Ask the user if boards have been freshly flashed** — this determines whether models/video need re-downloading.
3. **Load skills:** `linux-sdk:yocto` and `linux-sdk:gstreamer` (for pipeline debugging if issues arise).
4. **Read the manual:** Read `~/wp1/manual/02-quick-start.tex` in full before starting any tests.

### Board Readiness Checks

Before running any tests, verify each board:

```bash
# Verify SSH access (no root@ — SSH config handles user)
ssh <board> "uname -a && cat /etc/os-release | head -5"

# Verify EdgeFirst binaries are installed
ssh <board> "ls -la /opt/edgefirst/"

# Verify Ara240 service (if board has Ara240)
ssh <board> "systemctl status ara2 --no-pager"

# If ara2 is not active:
ssh <board> "sudo systemctl enable --now ara2"
```

If `ara2.service` fails to start, inform the user — may need board reboot (sometimes 3–5 reboots). Do not attempt to debug this yourself.

### Test Execution Rules

1. **One benchmark at a time per board.** Never run concurrent benchmarks on the same board — NPU contention produces unreliable results.
2. **Different boards in parallel is fine.** Run imx95-frdm and imx8mp-frdm tests simultaneously.
3. **Use `-n 900 -H` for all benchmarked runs.** 900 frames at headless gives ~36 seconds of steady-state data, enough for the model to load and produce stable FPS numbers.
4. **Add `-I` for EdgeFirst pipelines** (`yolov8n_imx8mp`, `yolov8n_imx95`) to get timing output. The `yolov8n_reference`, `yolov8n_ara2`, `yolov8n_ara2_reference`, and `yolov8n_seg_ara2` binaries always print timing at exit.
5. **Capture ALL output to log files** using `2>&1 | tee /tmp/qa-<test>-<board>.log`. Never use `head`, `tail`, or `grep` to filter command output — always capture full output so it can be searched afterward.
6. **Camera tests will have few/no detections** unless someone is standing in front of the camera. This is expected — the test validates that the pipeline runs without errors, not detection accuracy.
7. **Video tests should produce detections** (the test video has people in it). Zero detections on video is a failure that must be investigated.

### Phase 1: Download Commands

Test every `wget` command from the manual on both boards. The manual uses BusyBox wget which does not support `-O` or `-N` flags — commands must be plain `wget <url>`.

```bash
# On each board, run every wget command from the manual exactly as written
# Verify each file downloads successfully and has non-zero size
ssh <board> "cd ~ && mkdir -p models && cd models && \
    wget https://repo.edgefirst.ai/models/yolov8/yolov8n_640x640.tflite && \
    wget https://repo.edgefirst.ai/models/yolov8/yolov8n_640x640.imx95.tflite && \
    wget https://repo.edgefirst.ai/models/yolov8/yolov8n_640x640.dvm && \
    ls -la"

ssh <board> "cd ~/models && \
    wget https://repo.edgefirst.ai/models/yolov8/yolov8n-seg_640x640.dvm && \
    wget https://repo.edgefirst.ai/models/yolov8/yolov8m-seg_640x640.dvm && \
    wget https://repo.edgefirst.ai/models/yolov8/yolov8n-seg_640x640.tflite && \
    wget https://repo.edgefirst.ai/models/yolov8/yolov8n-seg_640x640.imx95.tflite && \
    ls -la"

ssh <board> "cd ~ && \
    wget https://repo.edgefirst.ai/testdata/853889-hd_1920_1080_25fps.mp4 && \
    ls -la 853889-hd_1920_1080_25fps.mp4"
```

**Pass criteria:** Every URL returns HTTP 200, every file has non-zero size. Any 404 or download failure is a blocking issue.

### Phase 2: On-SoC NPU Detection (yolov8n_imx8mp / yolov8n_imx95)

Test the EdgeFirst detection pipeline on each platform. These use the on-SoC NPU (VX Delegate on imx8mp, Neutron on imx95).

For each board, run 4 tests — camera + video for both EdgeFirst and reference pipelines. **Copy the exact command from the manual** and append `-n 900 -H -I` for benchmarking:

```bash
# imx8mp — EdgeFirst camera
ssh <board> "/opt/edgefirst/yolov8n_imx8mp \
    -m models/yolov8n_640x640.tflite \
    -c /dev/video3 -n 900 -H -I" 2>&1 | tee /tmp/qa-det-imx8mp-cam.log

# imx8mp — EdgeFirst video
ssh <board> "/opt/edgefirst/yolov8n_imx8mp \
    -m models/yolov8n_640x640.tflite \
    -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H -I" 2>&1 | tee /tmp/qa-det-imx8mp-vid.log

# imx95 — EdgeFirst camera
ssh <board> "/opt/edgefirst/yolov8n_imx95 \
    -m models/yolov8n_640x640.imx95.tflite \
    -n 900 -H -I" 2>&1 | tee /tmp/qa-det-imx95-cam.log

# imx95 — EdgeFirst video
ssh <board> "/opt/edgefirst/yolov8n_imx95 \
    -m models/yolov8n_640x640.imx95.tflite \
    -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H -I" 2>&1 | tee /tmp/qa-det-imx95-vid.log
```

**Reference baseline** — same commands as manual but with `-n 900 -H`:

```bash
# imx8mp reference — camera
ssh <board> "/opt/edgefirst/yolov8n_reference \
    -m models/yolov8n_640x640.tflite \
    -p imx8mp -c /dev/video3 -n 900 -H" 2>&1 | tee /tmp/qa-ref-imx8mp-cam.log

# imx8mp reference — video
ssh <board> "/opt/edgefirst/yolov8n_reference \
    -m models/yolov8n_640x640.tflite \
    -p imx8mp -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-ref-imx8mp-vid.log

# imx95 reference — camera
ssh <board> "/opt/edgefirst/yolov8n_reference \
    -m models/yolov8n_640x640.imx95.tflite \
    -p imx95 -n 900 -H" 2>&1 | tee /tmp/qa-ref-imx95-cam.log

# imx95 reference — video
ssh <board> "/opt/edgefirst/yolov8n_reference \
    -m models/yolov8n_640x640.imx95.tflite \
    -p imx95 -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-ref-imx95-vid.log
```

**Pass criteria:** Exit code 0, timing report printed, no GStreamer errors. Video runs should show detections (>0 det/frame average).

### Phase 3: Ara240 Detection (yolov8n_ara2 / yolov8n_ara2_reference)

Test the Ara240 NPU pipeline on both platforms:

```bash
# EdgeFirst Ara240 — camera (both platforms)
ssh <board> "/opt/edgefirst/yolov8n_ara2 \
    -m models/yolov8n_640x640.dvm \
    -p <platform> -n 900 -H" 2>&1 | tee /tmp/qa-ara2-<board>-cam.log

# EdgeFirst Ara240 — video (both platforms)
ssh <board> "/opt/edgefirst/yolov8n_ara2 \
    -m models/yolov8n_640x640.dvm \
    -p <platform> -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-ara2-<board>-vid.log

# Ara240 reference — camera (both platforms)
ssh <board> "/opt/edgefirst/yolov8n_ara2_reference \
    -m models/yolov8n_640x640.dvm \
    -p <platform> -n 900 -H" 2>&1 | tee /tmp/qa-ara2ref-<board>-cam.log

# Ara240 reference — video (both platforms)
ssh <board> "/opt/edgefirst/yolov8n_ara2_reference \
    -m models/yolov8n_640x640.dvm \
    -p <platform> -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-ara2ref-<board>-vid.log
```

Where `<platform>` is `imx95` or `imx8mp` matching the board.

**Pass criteria:** Same as Phase 2. Additionally, Ara240 EdgeFirst FPS should be significantly higher than reference (expect 2–3× for detection).

### Phase 4: Segmentation (yolov8n_seg_ara2)

Test instance segmentation on both platforms with both models:

```bash
# YOLOv8n-seg — camera (both platforms)
ssh <board> "/opt/edgefirst/yolov8n_seg_ara2 \
    -m models/yolov8n-seg_640x640.dvm \
    -p <platform> -n 900 -H" 2>&1 | tee /tmp/qa-seg-<board>-cam.log

# YOLOv8n-seg — video (both platforms)
ssh <board> "/opt/edgefirst/yolov8n_seg_ara2 \
    -m models/yolov8n-seg_640x640.dvm \
    -p <platform> -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-seg-<board>-vid.log

# YOLOv8m-seg — camera only (both platforms, higher accuracy model)
ssh <board> "/opt/edgefirst/yolov8n_seg_ara2 \
    -m models/yolov8m-seg_640x640.dvm \
    -p <platform> -n 900 -H" 2>&1 | tee /tmp/qa-segm-<board>-cam.log
```

**Pass criteria:** Exit code 0, timing report printed (includes Preprocess, Inference, Draw Masks), video runs show detections. YOLOv8m-seg should be slower than YOLOv8n-seg (higher inference time) but still functional.

### Phase 5: Timing Comparison

After all tests complete, extract timing data from log files and compare against the expected results tables in the manual. Use `grep` on the log files to find FPS, preprocessing, inference, and postprocess/draw times.

Key patterns to search for in logs:
- `FPS:` or `fps` — throughput
- `Preprocess` or `preproc` — preprocessing time
- `Inference` or `infer` — NPU inference time
- `Postprocess` or `post` — NMS / postprocessing time
- `Draw` or `draw_masks` — mask rendering time (segmentation only)
- `det/frame` or `detections` — average detections per frame

**Timing tolerance:** Measured FPS within ±15% of the manual's expected values is acceptable (thermal state, background processes, and Ara240 PCIe link variance cause natural variation). If a measurement is >15% off, flag it as a discrepancy for investigation.

### Phase 6: Report

After completing all phases, compile a summary report with:

1. **Test matrix** — table of all tests run, with PASS/FAIL status
2. **Timing comparison** — measured vs. expected values from the manual, flagging any >15% discrepancies
3. **Discovered issues** — any failures, crashes, or unexpected behavior, with:
   - Exact error message
   - Which board/platform/input combination
   - Log file location
   - Suggested fix if obvious, or "needs investigation" if not
4. **Manual corrections needed** — any commands that didn't work as written, any expected results that need updating
5. **Questions for the user** — anything ambiguous that needs human judgment (e.g., "detection count on imx8mp video is lower than imx95 — is this a known platform difference or a bug?")

**Do NOT silently fix commands that fail.** If a manual command doesn't work as-is, report it as a discrepancy. The manual must be corrected, not the test.

### Known Platform Differences

These are expected differences between platforms — do not flag as issues:

- **imx8mp camera uses `-c /dev/video3`** (v4l2src with VSI ISP); imx95 camera uses libcamerasrc (no `-c` flag needed)
- **imx8mp uses `.tflite` models**; imx95 uses `.imx95.tflite` models (Neutron-compiled). Both use `.dvm` for Ara240.
- **imx8mp video pipelines insert `imxvideoconvert_g2d`** (NV12→RGBA) automatically — this is a known workaround for Vivante NV12 unreliability. imx95 does not need this.
- **imx8mp FPS is generally lower than imx95** due to different SoC generation and GPU capability.
- **imx8mp Ara240 video may show fewer detections** than imx95 with the same video — this is due to NV12 preprocessing quality differences through the Vivante GPU path.
- **imx8mp camera is capped at 30 FPS** by the v4l2src/ISP; imx95 camera with Ara240 can exceed 30 FPS (up to ~60 FPS).

### Test Count

A complete QA run covers **22 tests** across 2 boards:

| Phase | Tests per board | Total |
|-------|----------------|-------|
| Downloads | 3 command groups | 6 |
| On-SoC detection (EdgeFirst + reference, camera + video) | 4 | 8 |
| Ara240 detection (EdgeFirst + reference, camera + video) | 4 | 8 |
| Segmentation (n-seg camera + video, m-seg camera) | 3 | 6 |
| **Total** | | **28** |

If only one board is available, the count halves. All tests for one board can complete in ~30 minutes (tests run ~36 seconds each, plus model load overhead).

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

## Changelog Management

The project uses a layered changelog structure:

```
edgefirst-yocto/CHANGELOG.md          # Manifest-level: layer updates, build/deploy changes
  ↓ links to
meta-edgefirst/CHANGELOG.md           # Layer-level: package version table + layer changes
  ↓ links to
github.com/EdgeFirstAI/<pkg>/blob/v<ver>/CHANGELOG.md   # Package-level: detailed changes
```

### When bumping a package version in meta-edgefirst

1. Rename the recipe `.bb` file to the new version
2. Update checksums
3. Add/update the entry in `meta-edgefirst/CHANGELOG.md` under `[Unreleased]`:
   - Update the package row in the version table (old → new, with link)
   - Link format: `[CHANGELOG](https://github.com/EdgeFirstAI/<repo>/blob/v<version>/CHANGELOG.md)`
4. If there are recipe-level changes beyond the version bump (e.g., SONAME fixes, new install steps), note them under "Layer Changes"

### When preparing a release tag

1. In each layer's `CHANGELOG.md`, move `[Unreleased]` entries under a versioned heading (e.g., `## v1.2 — 2026-04-XX`)
2. Collapse intermediate version bumps — only show the final version (e.g., HAL 0.8.0 → 0.16.2, not the full chain)
3. Update `edgefirst-yocto/CHANGELOG.md` with the layer summaries and links
4. Commit the changelogs, then tag

### Package changelog URL pattern

All EdgeFirstAI packages use the same URL pattern for their changelog at a specific version tag:

```
https://github.com/EdgeFirstAI/<repo>/blob/v<version>/CHANGELOG.md
```

Examples:
- `https://github.com/EdgeFirstAI/hal/blob/v0.16.2/CHANGELOG.md`
- `https://github.com/EdgeFirstAI/schemas/blob/v2.2.1/CHANGELOG.md`
- `https://github.com/EdgeFirstAI/gstreamer/blob/main/CHANGELOG.md` (use version tag once `v0.2.0` is tagged)
