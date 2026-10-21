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
      publish-apt-feed.sh         # Sign and publish the apt feed
  templates/
    imx/
      bblayers.conf               # NXP layers + meta-edgefirst + meta-kinara
  edgefirst-imx-6.18.37-2.1.0.xml  # Standalone manifest (NXP BSP + EdgeFirst)
  edgefirst-setup                   # Build environment setup script
  README.md
```

## How the Manifest Works

Users init with `repo init -b edgefirst-imx-6.18.37-2.1.0 -m edgefirst-imx-6.18.37-2.1.0.xml`. That manifest is a **standalone** manifest (not an overlay) that defines all projects directly:

1. **NXP i.MX BSP projects** — all NXP project definitions for the imx-6.18.37-2.1.0 release (imx-linux-wrynose), with NXP root linkfiles removed (`setup-environment`, `imx-setup-release.sh`). NXP `README.md` is exposed as `README-NXP.md` for reference. Since whinlatter the Yocto Project ships as split `bitbake` / `openembedded-core` / `meta-yocto` repositories — there is no `sources/poky/`.
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
  bitbake/               # BitBake (split from poky since whinlatter)
  openembedded-core/     # OE-Core — provides oe-init-build-env
  meta-yocto/            # meta-poky distro layer
  ...                    # Other upstream layers
build-<machine>/         # Per-MACHINE build directory (created by edgefirst-setup)
```

## edgefirst-setup

`edgefirst-setup` replaces the NXP two-script flow (`setup-environment` + `imx-setup-release.sh`). It is sourced, not executed.

**MACHINE is required on first run** and is baked into `local.conf`. Use per-MACHINE build directories (e.g., `build-imx8mp-frdm`) to avoid deb package conflicts when building for multiple platforms. `downloads/` and `sstate/` are shared across build directories.

**First run** (`MACHINE=imx8mp-lpddr4-frdm source edgefirst-setup -b build-imx8mp-frdm`):
1. Sources `sources/openembedded-core/oe-init-build-env` to create the build directory (bitbake is found at the sibling `sources/bitbake`)
2. Generates `local.conf`: sets `DISTRO=fsl-imx-wayland`, `PACKAGE_CLASSES=package_deb`, `MACHINE`, adds `package-management` and root-SSH-login features to `EXTRA_IMAGE_FEATURES`. DISTRO and PACKAGE_CLASSES are *inserted* when absent — the openembedded-core template carries them only as comments
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
    -b edgefirst-imx-6.18.37-2.1.0 -m edgefirst-imx-6.18.37-2.1.0.xml
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

## Package Feed and Board Updates

### Opting in

The mechanism is opt-in per build with `EDGEFIRST_APT_FEED = "1"` (default `0`, declared in meta-edgefirst's `conf/layer.conf`). The NXP i.MX branches turn it on in `templates/imx/site.conf`, which `edgefirst-setup` copies to each build directory's `conf/site.conf`, along with `EDGEFIRST_FEED_BSP`, `EDGEFIRST_VENDOR`, `EDGEFIRST_VERSION` and `CORE_IMAGE_EXTRA_INSTALL += "edgefirst-release"`; vendor branches (Torizon, PHYTEC, Ezurio) must leave it off. With the flag off: `edgefirst-apt-config` and `edgefirst-release` are skipped, `os-release` is not extended and keeps its stock revision, the kernel keeps the stock packaging (files in `/boot`, the stock scripts, the stock GPU-module conflict and revision), and the image does not mark kernel packages as automatically installed. `EDGEFIRST_VERSION` alone does not enable anything: other stacks set it for their own release naming. A build directory created before the flag existed has an old copy of `site.conf`; copy the template again. Check the effect with `bitbake -e linux-imx | grep ^PR=` (`r0.<digest>` when on, `r0` when off).

### Release identity

An EdgeFirst Yocto release is named `YYYY.MM` and published quarterly. Within a release the `PATCH` counts rolling updates: `EDGEFIRST_VERSION` is `YYYY.MM.PATCH` (`~dev` or `~rcN` ahead of the release it leads up to), set in `templates/imx/site.conf`. The vendor BSP version (`6.18.37-2.1.0`) is never altered: the kernel, `DISTRO_VERSION` and every NXP package keep their own versions. The EdgeFirst version is added next to it, and a release is always written as the pair "EdgeFirst Yocto 2026.10.1 for NXP i.MX BSP 6.18.37-2.1.0". `EDGEFIRST_FEED_BSP` (`imx-6.18.37-2.1.0`) and `EDGEFIRST_VENDOR` (`NXP i.MX`) in `site.conf` supply the BSP part; `conf/layer.conf` derives `EDGEFIRST_RELEASE` (`YYYY.MM`) and the BSP version from them.

| Where | What it shows |
|---|---|
| `/etc/os-release` | NXP's `NAME`, `VERSION` and `VERSION_ID` untouched; added `EDGEFIRST_RELEASE`, `EDGEFIRST_VERSION`, `EDGEFIRST_BSP`; `PRETTY_NAME` is "EdgeFirst Yocto <version> for <vendor> BSP <bsp version>". `os-release.bbappend` sets the package revision to `r0.<EDGEFIRST_VERSION>` so a rolling update replaces the file |
| `edgefirst-release` package | Version `EDGEFIRST_VERSION`; description names the BSP; `Provides: edgefirst-bsp-<bsp>` (the deb writer drops a version from a `Provides`, so the BSP version is in the name) |
| Feed `Release` file | `Origin: EdgeFirst`, `Suite: <bsp>`, `Codename: <YYYY.MM>`, `Version: <YYYY.MM.PATCH>` |
| Feed URL | `https://repo.edgefirst.ai/nxp/<YYYY.MM>/<bsp>/<package arch>/` |

### How an update works

Boards running these images update with `apt` from a signed deb feed. It is a developer convenience, not an industrial update system: there is no A/B, no automatic rollback and no transaction across the kernel and the root filesystem. The README has the user-facing description.

- **PATCH updates** are `apt update && apt full-upgrade`. The feed of a release is a rolling channel: publishing replaces its contents.
- **Quarterly release upgrades** are `edgefirst-release-upgrade` (installed by `edgefirst-apt-config`), in the spirit of Ubuntu's `do-release-upgrade`. It reads `nxp/meta-release`, a list of releases signed with the feed key (`meta-release` and detached `meta-release.asc`), picks the newest release whose `Upgrade-From` names the board's `RELEASE/BSP`, refuses unless the board is fully up to date and `/boot` is mounted with room, installs the new release's `edgefirst-apt-config` from the new feed's machine directory (which rewrites the feed list), then runs `apt full-upgrade`. A failure before the feed switch restores the old list; a failure after is finished by running the tool again. The new release may sit on a newer BSP, so this is also how a board changes BSP.

### How it fits together

| Piece | Where | What it does |
|---|---|---|
| `edgefirst-apt-config` | `meta-edgefirst` | Machine-specific package versioned `EDGEFIRST_VERSION`. Installs the signing key, one `sources.list.d` line per package architecture with `signed-by`, the pin, `/etc/edgefirst/feed.conf` and `edgefirst-release-upgrade`. Never use `PACKAGE_FEED_URIS`: oe-core writes `[trusted=yes]`, which turns signature checking off |
| `edgefirst-release` | `meta-edgefirst` | Constant-name package versioned `EDGEFIRST_VERSION` that depends on the exact kernel image, device tree, module and `os-release` packages of the build, resolved from package data at `do_package` |
| kernel boot scripts | `linux-imx_%.bbappend`, `files/kernel-*.sh` | Replace the stock `kernel-image-image` postinst and prerm and add one for `kernel-devicetree`. They find the partition labelled `boot` (mounting it briefly if the system has not), copy the image and device trees there atomically, keep `Image.prev`, and never touch the active image when an older kernel is removed |
| `edgefirst-apt-image` class | `meta-edgefirst`, inherited from `layer.conf` | Marks the image's `kernel-*` packages as automatically installed in `extended_states`, so `apt autoremove` retires an old kernel once `edgefirst-release` has moved on |
| `publish-apt-feed.sh` | `.github/scripts` | Stages, indexes and signs the feed with the key in `~/edgefirst-ca/nxp`; `--upload` publishes; `--announce` adds the release to `meta-release` |

### Constraints that are not obvious

- **U-Boot loads `Image` and the `.dtb` from the FAT partition** (`fatload mmc ${mmcdev}:${mmcpart} ... ${image}`), never from the root filesystem. The kernel packages install into `/boot` on the root filesystem and their scripts copy to the partition, so the partition must **not** be mounted on `/boot` (it would hide the packaged files, and dpkg would write to FAT, see below). Without the copy `apt` would update a kernel U-Boot never reads.
- **Kernel packages carry the kernel version in their names**, so `apt full-upgrade` can never replace them by name. `edgefirst-release` exists to pull them. Its dependencies must be written as exact versioned names; a bare `kernel-image` is satisfied by the kernel that is already installed.
- **Kernels must be co-installable.** meta-freescale makes each `kernel-<ver>` conflict with the GPU module that every kernel provides, so one kernel at a time. `apt full-upgrade` does not remove an installed package to make room for a new one (it holds the new kernel's modules back and removes `edgefirst-release` instead; `apt install edgefirst-release` works because it is protected as the request), so `linux-imx_%.bbappend` removes the conflict. The old kernel and its modules stay until `apt autoremove`, which also leaves the modules of the running kernel in place until after a reboot. The boot partition only ever holds `Image` and `Image.prev` (see the next point).
- **dpkg cannot manage files on the FAT boot partition.** To replace a file it first makes a hard link to the old one, which FAT does not support (`unable to make backup link ... Operation not permitted`), and the device trees already exist there from the wic image. No package may ship a file on the partition: the packages install under `/boot` on the root filesystem and the scripts copy. The wic image gets its boot files from the deploy directory, not from the packages.
- **Module packages of two kernels share their autoload `.conf` files** (`moal`, `uiodma`), so `edgefirst-apt-config` installs `Dpkg::Options { "--force-overwrite"; }`. dpkg keeps a shared file until the last package that lists it is removed.
- **Out-of-tree module packages** (`kernel-module-uiodma`, `kernel-module-nxp-wlan`, ...) keep their own version, so `edgefirst-module-version.bbclass` adds the release, PATCH and a digest of the kernel ABI version to their package revision. Without it a rebuilt module is invisible to apt and a board keeps the module built for its old kernel.
- **apt replaces a package only when its version string changes.** A patch or script change leaves the kernel version unchanged, so `linux-imx_%.bbappend` sets the revision to `r0.<YYYYMM>.<PATCH>.<digest>`, where the digest covers the local patches and scripts. The release and PATCH come first so that every revision sorts above the one it replaces: a digest alone can sort lower, and `apt` refuses an update it takes for a downgrade when run with `-y`. A rolling build with an unchanged PATCH (for example `~dev` builds) can still sort lower than an earlier one; such a board needs `--allow-downgrades`. Anything else rebuilt without a version change is invisible to `apt`; bump `PR` on the recipe, or use a PR service if this becomes a problem. `os-release` and `edgefirst-apt-config` follow `EDGEFIRST_VERSION` so they always update.
- **`edgefirst-release` has to be rebuilt after the kernel packages change**, and it is, because its `do_package` depends on the kernel's package data. A feed that mixes a new kernel with an old `edgefirst-release` is refused by `apt` rather than half-installed.
- **Files read with `open()` in an anonymous Python function must be passed to `bb.parse.mark_dependency`**, or editing them does not invalidate the parse cache and bitbake reports non-deterministic metadata.
- **The set of out-of-tree kernel modules is not covered** by `edgefirst-release`. Their packages are also named by kernel version, so a board that updates the kernel needs the matching builds of the modules it uses. They are in the feed from a full `imx-image-full` build; check that a rebuilt feed contains them before publishing.
- **Packages shared between machines (`all`, `armv8a`, ...) are published into the same directory by each machine's publish.** `os-release` embeds a per-build `BUILD_ID`, so the copy from the last machine published wins; the contents that matter are identical.
- **The feed key signs `Release`/`InRelease`/`Release.gpg` per architecture directory and `meta-release.asc`.** The CA directory README describes the key, rotation and verification.

### Releasing

Build `imx-image-full` for each machine with `EDGEFIRST_VERSION` set to the release (`YYYY.MM.PATCH`, no suffix), publish images with `repo-deploy.sh`, then publish each machine's feed with `publish-apt-feed.sh --upload`. When every machine of a new quarterly release is published, run `publish-apt-feed.sh --announce --upload --upgrade-from <old release>/<old bsp> <build dir>` for each BSP so that boards can find it. A PATCH update is the same build and publish with a higher `PATCH`; do not announce it. Check a published feed from a board with `apt update` and `apt list --upgradable`, and with a different key to confirm it is refused.

## Cross-Compilation SDK

SDKs install to `/opt/fsl-imx-wayland-{version}-{board}/`.

```bash
# Install
sudo build-imx8mp-frdm/tmp/deploy/sdk/fsl-imx-wayland-glibc-x86_64-imx-image-full-armv8a-imx8mp-lpddr4-frdm-toolchain-*.sh \
    -d /opt/fsl-imx-wayland-6.18.37-2.1.0-imx8mp-frdm -y

# Source environment
source /opt/fsl-imx-wayland-6.18.37-2.1.0-imx8mp-frdm/environment-setup-armv8a-poky-linux

# CMake
cmake -B build -DCMAKE_TOOLCHAIN_FILE=$OECORE_NATIVE_SYSROOT/usr/share/cmake/OEToolchainConfig.cmake
cmake --build build
```

## Our Layers

### meta-edgefirst

EdgeFirst perception platform: HAL, camera/sensor services, GStreamer ML pipelines, NNStreamer examples, Zenoh infrastructure, web UI.

### meta-kinara

Kinara Ara-2 NPU support: kernel module, firmware, userspace libraries. The runtime recipe is `imx-nxp-ara2`: NXP's 2.1.1 packaging (meta-imx-ml, `rt-sdk-ara2.service`) wins wherever meta-imx-ml ships it (wrynose onwards); meta-kinara's `imx-nxp-ara2_1.2.1.bb` packages the Kinara SDK (`ara2.service`) under the same name, so the two can never be co-installed. The Kinara SDK recipe is used on the 6.12 BSP, on builds without meta-imx-ml, or when `PREFERRED_VERSION_imx-nxp-ara2 = "1.2.1"` is set, and it requires `KINARA_MIRROR` (NDA required). meta-kinara sets the read-only `KINARA_ARA2_RUNTIME` (`nxp` or `kinara`); meta-edgefirst builds the NNStreamer Ara-2 sub-plugin (`nnstreamer-ara2`) only when it is `kinara`. An Ara-2 card flashed by NXP's runtime (firmware 65794 or newer) is rejected by the Kinara SDK proxy with `DV_ENDPOINT_FIRMWARE_BOOT_FAILURE` until its boot firmware is restored with `program_flash --version_check 0`. See [Choosing an Ara-2 runtime](https://github.com/EdgeFirstAI/meta-kinara?tab=readme-ov-file#choosing-an-ara-2-runtime) and [Ara-2 card boot firmware](https://github.com/EdgeFirstAI/meta-kinara?tab=readme-ov-file#ara-2-card-boot-firmware).

## Purpose, Cadence, and Releases

The Yocto integrations in this family of branches (Torizon included) exist for two reasons:

1. **Every vendor gets the latest NPU, GPU, camera, and vision-pipeline enablement** that the EdgeFirst stack needs on their platforms, even when the vendor's own BSP lags NXP.
2. **Every vendor platform gets the latest EdgeFirst stack** integrated and tested on it.

### Cadence

NXP publishes a Yocto BSP quarterly. We track that release on the NXP FRDM/EVK branches first, work out which of our owned changes are still needed (see Tracking NXP BSP Releases and Owned Patches), and then **backport whatever each vendor BSP requires** (NPU/Neutron/VX, GPU/`galcore`, camera/ISP, vision pipeline) as part of producing that vendor's EdgeFirst release. A vendor release is therefore: the vendor's own BSP release, plus the current `meta-edgefirst`, plus the backports that BSP's kernel and ML layers need.

### Products, naming, and versions

Every release of every product is versioned `YYYY.MM.PATCH` (for example `2026.10.0`). A published release is never changed; a fix is the next `PATCH`. Product names:

| Product name | Platform | Branch |
|---|---|---|
| EdgeFirst Yocto for NXP | NXP i.MX EVK/FRDM | `edgefirst-imx-*` |
| EdgeFirst Yocto for PHYTEC | PHYTEC phyBOARD/phyFLEX/phyCORE | `edgefirst-phytec-*` |
| EdgeFirst Yocto for Ezurio | Ezurio Nitrogen SMARC | `edgefirst-ezurio-*` |
| Torizon with EdgeFirst | Generic Toradex Verdin and Aquila boards | `torizon` |
| Torizon for Maivin | Our internal Maivin platform | Torizon-family branch |
| Torizon for ADIS | Customer-specific variant of Torizon for Maivin | Torizon-family branch |

"EdgeFirst Yocto for VENDOR" is the general pattern; Toradex is the deliberate exception, because Torizon is the product users see. Use these names in READMEs, CHANGELOGs, release notes, and artifact names, not ad hoc variants. Torizon for ADIS derives from Torizon for Maivin, so changes to Maivin must be considered for ADIS at rollout time. Where a branch for Maivin or ADIS is not in the table above, ask the user where it lives before assuming.

## Branches and BSP Selection

`EdgeFirstAI/yocto` is a family of **detached branches**. Every supported platform/BSP combination has its own branch holding its own manifest, setup tooling, README, copilot instructions, and CHANGELOG; `main` is an orphan branch holding only a README index. Branches never merge into each other and share no history, so a change to one is never implicitly a change to another. Release tags are frozen snapshots and are never updated.

| Branch | Platform | BSP | Use for |
|---|---|---|---|
| `edgefirst-imx-6.18.37-2.1.0` | NXP i.MX EVK/FRDM (**this branch**) | NXP 6.18.37-2.1.0 (wrynose) | i.MX 95, and i.MX 8M Plus without Ara-2 |
| `edgefirst-imx-6.12.49-2.2.0` | NXP i.MX EVK/FRDM | NXP 6.12.49-2.2.0 (walnascar) | i.MX 8M Plus with the Ara-2 NPU |
| `torizon` | Toradex Verdin | Torizon OS (walnascar) | Verdin i.MX 8M Plus, Verdin i.MX 95 |
| `edgefirst-phytec-imx95-PD26.1.y` | PHYTEC phyBOARD-Libra | PHYTEC PD26.1.y on NXP 6.18.20 (wrynose) | phyFLEX-i.MX 95 |
| `edgefirst-phytec-imx8mp-PD26.1.y` | PHYTEC phyBOARD-Pollux/Libra | PHYTEC PD26.1.y on NXP 6.12.49 (walnascar) | phyCORE/phyFLEX-i.MX 8M Plus |
| `edgefirst-ezurio-6.16.0.27` | Ezurio Nitrogen SMARC | Ezurio SUMMIT-REL-6.16.0.27 on NXP 6.12.49 (walnascar) | i.MX 8M Plus, i.MX 95 |

`main`'s README is the authoritative index; keep this table and that one in step.

i.MX 8M Plus boards hang under Ara-2 inference load on the 6.18.20 BSP; the same Kinara SDK runtime, uiodma driver, and edgefirst-ara2 bindings run stably on 6.12.49 (validated 2026-09-28 on imx8mp-frdm and imx8mp-frdm-2, about 124,000 det/seg inferences each).

### How the branches relate

- **NXP branches** (this one and the 6.12.49 one) are the reference integration. Each tracks one NXP BSP release verbatim, adds `meta-edgefirst` and `meta-kinara`, and is built and QA'd on our FRDM/EVK boards. Whatever EdgeFirst needs from the NXP BSP is proven here first.
- **Vendor branches** (Torizon, PHYTEC, Ezurio) keep the vendor's own projects as the vendor published them, add `meta-edgefirst`, and add one **vendor layer** named `meta-edgefirst-<vendor>`. They do not use `meta-kinara`; Ara-2 is only supported on the NXP branches. The vendor's kernel, bootloader, update mechanism (OSTree, RAUC, SWUpdate), image recipe, and release cadence are the vendor's, so those differences live in the vendor layer and the branch's own docs, not in `meta-edgefirst`.
- A vendor BSP is often a different NXP base than the NXP branch (6.12.49 walnascar vs 6.18.20 wrynose), so a vendor branch can lag the NXP reference by a whole Yocto release. That is expected; the shared layer supports all of them at once (see Yocto Release Compatibility).
- Every manifest pins `meta-edgefirst` and the vendor layer by commit SHA with `upstream="main"`, and has a self-reference project (`name="yocto"`) whose revision is its own branch. Vendor layers also live only on `main`.

### Where things belong

| Content | Home |
|---|---|
| Anything portable across all BSPs: recipes for EdgeFirst packages, HAL, services, NPU delegates/forks, packagegroups, NNStreamer, kernel patches that are needed by any NXP-kernel BSP | `meta-edgefirst` (`main`), gated with `LAYERSERIES_CORENAMES` or machine overrides, never a per-release branch |
| Anything that only makes sense on one vendor's BSP: image recipes, update/signing integration, vendor kernel bbappends and patches, vendor device-tree overlays, vendor workarounds | `meta-edgefirst-<vendor>` (`main`) |
| Which commits of which layers a given BSP builds, the vendor's own project pins, setup tooling, vendor docs | the vendor's branch of `EdgeFirstAI/yocto` |
| Ara-2 runtime and kernel driver packaging | `meta-kinara` (NXP branches only) |

If a vendor layer needs to copy something from `meta-edgefirst`, first ask whether it should be a gated recipe in `meta-edgefirst` instead. If portable conditionals in `meta-edgefirst` ever stop being workable, the fallback is to split the NXP-kernel pieces into a separate layer that gets version branches; `meta-edgefirst` itself stays portable on `main`.

## Rolling Out Updates Across All Branches

Because the branches are detached, **an update to `meta-edgefirst` or a vendor layer reaches a BSP only when that BSP's manifest is re-pinned.** Rolling out means landing the layer change on `main`, then updating, building, and testing every branch.

The user keeps a local checkout of each branch somewhere on the host and will tell you where when asking for a rollout; do not assume or hardcode locations. Each checkout is a `repo` workspace whose manifest repo (under `.repo/manifests`, also checked out as the self-referencing project) is on the branch in question. Check the branch actually checked out before editing anything.

Every branch tracks `meta-edgefirst` `main` and the rolling fork branches it pins; there are no per-series anchor branches (`edgefirst-1.2.3` and similar are obsolete and must not be referenced). When a series cannot build a rolling branch, make it build with a series-gated workaround in `meta-edgefirst` and tell the user; only a blocker with no workaround can justify leaving `main`, and that needs the user's explicit approval.

### Rollout procedure

1. **Land the layer change first.** Commit and push to `main` of `meta-edgefirst` (and the affected `meta-edgefirst-<vendor>` layers, `meta-kinara`) before touching any manifest. A manifest must only ever pin a SHA that exists on the remote.
2. **Get the list of checkouts from the user.** Confirm for each: which branch it is on, that its working tree is clean, and that nothing in it is unpushed. Do not proceed on a dirty or divergent checkout without asking.
3. **Fetch the manifest repo and the layers**, and fast-forward the branch. Local `repo` workspaces go stale easily; a workspace that has not been synced will show old pins and old layer content. Verify against the remote rather than trusting the workspace.
4. **Re-pin.** In each branch's manifest, set `meta-edgefirst` (and each vendor layer that changed) to the new full SHA, leaving `upstream="main"`. Change nothing else in the manifest unless the rollout calls for it. NXP branches also re-pin `meta-kinara`. Never pin a layer to a per-release branch.
5. **Check the vendor layers still apply.** Read the diff of `meta-edgefirst` since the old pin and ask, for each branch: does any changed recipe have a `bbappend` in the vendor layer (tim-vx, VX/Neutron delegate, NNStreamer, `linux-*` kernel bbappends, `neutron`, `imx-gpu-viv`, packagegroups, images)? A vendor layer that overrides `SRC_URI`, `S`, or a version that `meta-edgefirst` just changed will break silently or fail at parse. Also check that new `meta-edgefirst` features whose prerequisites are kernel- or BSP-specific (for example a Neutron SDK needing a particular kernel mailbox handshake) are satisfied on each vendor kernel before re-pinning.
6. **Parse test every machine** of every branch (`bitbake -p`, or `bitbake -e <image>` for a specific variable) in a synced workspace. This catches dangling bbappends, `LAYERSERIES_COMPAT` gaps, and QA fatals (`S`/`UNPACKDIR`) cheaply and is the minimum bar.
7. **Build the image** for at least one machine per SoC family per branch (it need not be every machine: the NPU backend differs by SoC, not by board). Prefer the vendor's own release image recipe, since that is what ships.
8. **Test on hardware** where the change touches runtime behaviour: NPU delegate or firmware changes, kernel patches, and camera/GPU changes require booting and running the `yolov8n` pipeline on that vendor's board. Pure packaging or service-version bumps may be satisfied with a build plus a boot smoke test. If a board is not available, say so in the result instead of reporting the branch as tested.
9. **Commit the re-pin per branch** with a signed commit, and update that branch's `CHANGELOG.md`, `README.md`, and `.github/copilot-instructions.md` if the change affects usage or structure. Ask the user to confirm CHANGELOG entries first. Pushes to EdgeFirstAI repos use the SSH remote URL; HTTPS pushes fail.
10. **Report per branch**: old pin to new pin, what was parsed/built/booted, what was not tested and why, and any vendor-layer follow-up needed.

Do not partially roll out silently. If one branch cannot take the update (for example a vendor kernel needs a backport first), land the fix in that vendor layer, re-pin it, and say which branches are on the new pin and which are not. Branches intentionally held back must say why in their CHANGELOG. A rollout that is part of a product release also bumps that product's `YYYY.MM.PATCH` version; the user decides when a release is ready to publish.

Re-pinning the NXP branches also includes `meta-kinara`, and the 6.12.49 and 6.18.37 branches must always be re-pinned together. A re-pin only reaches boards that update with `apt` once the BSP's package feed is rebuilt and published (see Package Feed and Board Updates).

## Tracking NXP BSP Releases and Owned Patches

The NXP FRDM/EVK branches are where new NXP BSP releases are adopted first. Upgrading one is also the moment to decide, patch by patch, what EdgeFirst still owns.

### What we own

EdgeFirst maintains changes in three places. At any moment each change should have exactly one owner and a recorded reason to exist:

1. **Fork repositories** carried by `meta-edgefirst` recipes, always as rolling branches of an `EdgeFirstAI/*` repository that contain the corresponding NXP branch plus our commits: `tim-vx-imx` (`edgefirst-dmabuf`), `tflite-vx-delegate-imx` (`edgefirst`), `tflite-neutron-delegate` (`edgefirst`), `nnstreamer` (`edgefirst`), `nxp-nnstreamer-examples` (`edgefirst-yolov8`), and the republished eIQ Neutron SDK target binaries (`neutron`, branch `eiq-neutron-sdk`, tagged per SDK version). Never push to `main` of the forked repositories.
2. **Kernel patches** against NXP's `linux-imx` (and vendor kernels derived from it): Neutron buffer export as dma-buf and its namespace import, the Neutron mailbox handshake rework required by Neutron SDK 3.2.x, Neutron probe/IRQ fixes, board device-tree additions (for example camera/NPU nodes and NPU DMA pool sizing).
3. **Recipe-level patches and workarounds** in `meta-edgefirst`, `meta-kinara`, and vendor layers (for example the walnascar `pseudo` openat2 fix, and `imx-gpu-viv`/`kernel-module-imx-gpu-viv` carry-overs in vendor layers whose BSP predates the one `meta-edgefirst` assumes). The walnascar (6.12) builds of the forks are workarounds of this kind: the LiteRT VX delegate is pointed at the walnascar LiteRT tag, and the i.MX GStreamer plugin gets a forwarding `gstphymemmeta.h`, a patch that builds `spdifdemux` only where `spdifparser.h` exists, `libinput` and no remote desktop tools. They exist because the rolling fork branches are rebased onto the wrynose baseline.

### When NXP releases a new BSP

Do this on the NXP branch, in a build directory for the new BSP, before any vendor branch changes:

1. **Fetch** every NXP project the manifest pins and compare the new tag to the old one, in particular the ML layer (`meta-imx-ml`), the kernel recipe, `imx-gpu-viv`/`kernel-module-imx-gpu-viv`, `neutron`, `tim-vx`, the VX/Neutron delegates, NNStreamer, and the Ara-2 runtime. NXP has moved release tags before, so also compare commit SHAs, not just tag names.
2. **For every item in the ownership list above, classify it**:
   - *Upstreamed*: NXP's new tree contains the change (search the kernel and delegate logs for the subject, not just the file). Drop our copy for that series, record the NXP commit in the bbappend comment, and gate any remaining older-series carry with `LAYERSERIES_CORENAMES`. Never port an upstreamed patch forward.
   - *Superseded*: NXP now offers a different mechanism that overlaps ours (for example NXP shipping its own NNStreamer Ara-2 sub-plugin and tensor_filter V2 API). Decide deliberately whether to converge on NXP's, keep ours, or adapt; record the decision.
   - *Still ours*: bring the fork up to the new NXP branch by merging the new `lf-*` branch into the fork's rolling branch (resolve conflicts there, not in the recipe), then update the SRCREV in `meta-edgefirst`. Check what NXP added that the fork lacks, not just whether the fork still builds.
   - *Obsolete*: the problem it fixed no longer exists. Remove it and say why in the commit.
3. **Check NXP-side ABI and version coupling**: the Neutron kernel driver, firmware, library, and compiler version must agree (the SDK we republish may be newer than NXP's own); the VX delegate, TIM-VX, and `galcore` must agree with the userspace GPU stack; litert/tensorflow-lite versions must match the delegates. Do not accept a bump that breaks one of these couplings on a BSP we still support.
4. **Update the NXP branch manifest** to the new BSP tag, re-pin the layers, build all four machines, and QA on the boards (see Manual QA Validation).
5. **Record the result** in the owned-patch table below and in the CHANGELOG.

### Backporting to vendor BSPs

Vendor BSPs run older or different kernels and ML layers than the NXP reference, so some patches the NXP branch no longer needs are still required there, and some NXP-branch fixes need adapting. For every patch still owned, decide where it applies:

- **Same patch file, kernel series matches the NXP series it was written for**: keep a single copy in `meta-edgefirst` and have the vendor layer reference it, as is done for the Neutron dma-buf export on kernels still on the 6.12 series. Do not duplicate it.
- **Vendor kernel diverges from `linux-imx`** (different base version, vendor fork, different patch queue and numbering): the vendor layer carries its own copy, rebased onto that kernel. The vendor bbappend must say what the patch is, which NXP commit it mirrors, which firmware or userspace version it is coupled to, and the condition for dropping it (for example "vendor kernel reaches 6.18.37"). Today the Neutron mailbox handshake rework is carried this way by every vendor layer that supports i.MX 95.
- **Scope the patch** to the SoC or machine that has the hardware (for example i.MX 95 only for Neutron) so the same recipe name on another SoC is unaffected.
- **Coupled changes ship together.** If a userspace bump in `meta-edgefirst` requires a kernel change (the Neutron SDK and its kernel handshake are the current example), every vendor branch that will take the bump needs the kernel change in its vendor layer *before* it is re-pinned. Check this at step 5 of the rollout procedure.
- **Make backports self-contained.** Vendors often omit NXP layers or ship them far out of date, so a backport never requires or depends on a recipe from an NXP layer (meta-freescale-ml, meta-imx-ml and so on): copy what it needs into our recipe and let version precedence win over NXP's copy. Check that every layer stack still parses without the NXP layers it lacks, in particular Torizon for Maivin, which has no `meta-freescale-ml`. Backports go straight to `main` of the layer with no pull request.
- **Retire carried patches** when the vendor's kernel moves past them. Record each carried patch and its condition for dropping in the vendor layer, so the list can be audited at every rollout.

### Owned items and where they apply (keep current)

As of 2026-10-21; update this table whenever a rollout or an NXP BSP upgrade changes it.

| Item | Owner | NXP wrynose 6.18 | NXP/vendor 6.12 walnascar | Notes |
|---|---|---|---|---|
| Neutron dma-buf export (kernel) | `meta-edgefirst` patch | in NXP tree since 6.18.20, do not port | `meta-edgefirst` patch reused by vendors | i.MX 95 only |
| Neutron namespace import (kernel) | `meta-edgefirst` patch | in NXP tree | `meta-edgefirst` patch | 6.12 syntax unquoted |
| Neutron mailbox handshake (kernel, for SDK 3.2.x) | `meta-edgefirst` patch for NXP `linux-imx`; each vendor layer for its own kernel | `meta-edgefirst` patch, applied below 6.18.37 (in NXP 6.18.37) | not needed (i.MX 8M Plus only); vendor layer copy where the kernel has a Neutron NPU | version lock with SDK 3.2.x firmware; may move to a future `meta-edgefirst-nxp` |
| Neutron SDK 3.2.3 target binaries | `EdgeFirstAI/neutron` fork via `meta-edgefirst` | all | all | NXP's own tree carries an older SDK |
| tim-vx dma-buf tensor API | `tim-vx-imx` fork | rebase on NXP branch each BSP | same | |
| VX delegate dma-buf + CameraAdaptor | `tflite-vx-delegate-imx` fork | rebase | same | i.MX 8M Plus |
| Neutron delegate dma-buf (per-delegate registry) | `tflite-neutron-delegate` fork | rebase; check NXP additions such as cross-process locking | same | i.MX 95 |
| NNStreamer dma-buf, tensor_filter V2, Ara-2 | `nnstreamer` fork | converge or keep; NXP now ships its own V2 series | NXP branch only for Ara-2 | |
| Pseudo openat2 fix | `meta-edgefirst`, walnascar-gated | n/a | yes | vendor layers must not duplicate it |
| imx95-19x19-evk camera DTB | `meta-edgefirst` kernel bbappend | NXP EVK only | n/a | |

## Yocto Release Compatibility (Scarthgap + Walnascar + Whinlatter + Wrynose)

meta-edgefirst **must** build on **Scarthgap** (Yocto 5.0 LTS), **Walnascar** (Yocto 5.2), **Whinlatter** (Yocto 5.3), and **Wrynose** (Yocto 5.4). Key differences between the releases affect how recipes are written:

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

### S for git-fetched recipes (Whinlatter)

Whinlatter's `do_qa_unpack` **fatals** on any unexpanded `S` containing the literal `${WORKDIR}`, including `S = "${WORKDIR}/git"` (the check inspects the *raw* value of `S`). More importantly, whinlatter sets `BB_GIT_DEFAULT_DESTSUFFIX = "${BP}"`, so git checkouts unpack to `${UNPACKDIR}/${BP}` — **not** `…/git` — and bitbake.conf's default `S = "${UNPACKDIR}/${BP}"` matches. Walnascar unpacks git to `${UNPACKDIR}/git`; kirkstone/scarthgap to `${WORKDIR}/git`.

**Rule:** for git-fetched recipes that must build on all supported releases use:

```bitbake
S = "${@(d.getVar('UNPACKDIR') + '/' + d.getVar('BB_GIT_DEFAULT_DESTSUFFIX')) if d.getVar('BB_GIT_DEFAULT_DESTSUFFIX') else ((d.getVar('UNPACKDIR') or d.getVar('WORKDIR')) + '/git')}"
```

For tarball recipes that need a custom S subdirectory, anchor it the same way (any raw `${WORKDIR}` in S is fatal on whinlatter):

```bitbake
UNPACK_BASE = "${@d.getVar('UNPACKDIR') or d.getVar('WORKDIR')}"
S = "${UNPACK_BASE}/my-source-dir"
```

### LAYERSERIES_COMPAT

`LAYERSERIES_COMPAT` in meta-edgefirst must include `scarthgap`, `walnascar`, `whinlatter`, and `wrynose` (and any future release codenames as needed).

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
| `edgefirst-gstreamer` | `EdgeFirstAI/gstreamer` | EdgeFirst GStreamer plugins (edgefirstoverlay, edgefirstcameraadaptor) |
| `imx-nnstreamer-examples` | `EdgeFirstAI/nxp-nnstreamer-examples` | YOLOv8n demo binaries |
| `edgefirst-hal` | — | EdgeFirst HAL (quantized NMS, model metadata) |
| `tflite-vx-delegate` | — | TFLite VeriSilicon NPU delegate |

### Installed Binaries

The `imx-nnstreamer-examples` recipe installs three binaries to `/opt/edgefirst/`:

| Binary | Description |
|--------|-------------|
| `yolov8n` | Unified EdgeFirst pipeline — detection + segmentation, TFLite (VX/Neutron) + Ara-2 backends |
| `yolov8n_reference` | NNStreamer reference detection pipeline (standard NXP approach, for benchmarking) |
| `yolov8n_ara2_reference` | NNStreamer reference detection pipeline with Ara-2 backend (for benchmarking; needs `nnstreamer-ara2`, built only with the Kinara SDK runtime) |

The unified `yolov8n` binary auto-detects:
- **Backend**: `.dvm` → Ara-2, `.tflite` on imx8mp → VX Delegate, `.tflite` on imx95 → Neutron
- **Model type**: detection vs. segmentation — auto-detected from tensor shapes by `edgefirstoverlay`
- **Camera source**: `v4l2src` on imx8mp, `libcamerasrc` on imx95

Key CLI flags: `-m <model>` (required), `-p <platform>` (required), `-v <video>`, `-c <camera>`, `-H` (headless), `-n <frames>`, `-D` (detection signal callback — prints boxes/masks to console).

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

- With NXP's runtime (default), `rt-sdk-ara2.service` starts itself from a udev rule when the device enumerates — never also enable `ara2.service`. With the Kinara SDK runtime, `systemctl enable --now ara2` must be active before benchmarking
- If Ara-2 fails with `DV_MODEL_LOAD_FAILURE code=520`, full power cycle the board (multiple cycles may be needed)
- The unified `yolov8n` binary auto-selects the Ara-2 backend when given a `.dvm` model — it handles detection and segmentation DVM models
- The `yolov8n_ara2_reference` binary provides the NNStreamer reference pipeline with per-element timing breakdown; it needs `nnstreamer-ara2`, which is built only with the Kinara SDK runtime (the 6.12 BSP branch)

## Remote Wayland Screenshot Setup

Target boards running weston 14+ require a one-time configuration change to allow SSH-based screenshots. This is required for remote QA visual verification.

### Problem

`weston-screenshooter` uses the `weston_capture_v1` Wayland protocol, which is a privileged interface. By default, only clients launched by the compositor itself (via Super+S keybinding on the physical keyboard) are authorized. Running `weston-screenshooter` from SSH always fails with "unauthorized".

The legacy `/dev/fb0` framebuffer approach also does not work — weston uses DRM/KMS planes directly (G2D renderer on i.MX), so fb0 is all zeros.

### Fix: Enable weston --debug

The `--debug` flag registers a `screenshot_allow_all()` authority that approves ALL capture requests, including from SSH sessions.

Create a systemd override on the target board:

```bash
ssh <board> 'mkdir -p /etc/systemd/system/weston.service.d && cat > /etc/systemd/system/weston.service.d/debug.conf << "EOF"
[Service]
ExecStart=
ExecStart=/usr/bin/weston --log=${XDG_RUNTIME_DIR}/weston.log --modules=systemd-notify.so --debug
EOF
systemctl daemon-reload && systemctl restart weston'
```

**Note:** The empty `ExecStart=` line is required to clear the default ExecStart before adding the new one (systemd override behavior).

### Helper Script

Install a `take-screenshot` helper on the board for convenient screenshot capture:

```bash
ssh <board> 'cat > /usr/local/bin/take-screenshot << "SCRIPT"
#!/bin/sh
export WAYLAND_DISPLAY=wayland-0
export XDG_RUNTIME_DIR=/run/user/0
weston-screenshooter
LATEST=$(ls -t /root/wayland-screenshot-*.png 2>/dev/null | head -1)
if [ -n "$LATEST" ] && [ -n "$1" ]; then
    mv "$LATEST" "/root/$1.png"
    echo "Screenshot saved: /root/$1.png"
else
    echo "Screenshot saved: $LATEST"
fi
SCRIPT
chmod +x /usr/local/bin/take-screenshot'
```

Usage from the build host:

```bash
# Take a screenshot and copy to build host
ssh <board> 'PATH=/usr/local/bin:$PATH take-screenshot mytest'
scp <board>:/root/mytest.png /tmp/mytest.png
```

### QA Screenshot Protocol

During QA testing, screenshots of video-input Wayland tests are saved to `~/wp1/screenshots/` on the build host for inclusion in the User Manual and test reports:

```bash
mkdir -p ~/wp1/screenshots

# Example: capture Ara-2 segmentation with video after ~15s stabilization
ssh <board> '/opt/edgefirst/yolov8n -m models/yolov8n-seg_640x640.dvm -p imx8mp -v 853889-hd_1920_1080_25fps.mp4' &
sleep 15
ssh <board> 'PATH=/usr/local/bin:$PATH take-screenshot ara2-seg-video'
scp <board>:/root/ara2-seg-video.png ~/wp1/screenshots/
kill %1  # stop the pipeline
```

**Screenshot naming convention:** `<backend>-<mode>-<input>-<platform>.png`
- Examples: `ara2-seg-video-imx8mp.png`, `vx-det-video-imx8mp.png`, `neutron-seg-video-imx95.png`

**Manual screenshots:** Only video-input screenshots are included in the User Manual (not camera), since camera scenes are inconsistent (e.g., pointed at ceiling). Video uses the standard test video with people visible, providing consistent expected results.

**Wait times before capturing:**
- Ara-2 backend: wait ~15 seconds (fast model load)
- VX Delegate: wait ~40 seconds (cold-start NPU compilation takes ~26s)
- Neutron: wait ~15 seconds

### Replicating on New Boards

When setting up a new board for QA testing, run both the debug.conf and take-screenshot setup commands above. This must be done once per board (persists across reboots but not reflashes).

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
4. **The unified `yolov8n` binary** replaces all platform/backend-specific binaries. Use `-m` to select the model and `-p` to select the platform. The `-D` flag enables detection signal output.
5. **Capture ALL output to log files** using `2>&1 | tee /tmp/qa-<test>-<board>.log`. Never use `head`, `tail`, or `grep` to filter command output — always capture full output so it can be searched afterward.
6. **Camera tests will have few/no detections** unless someone is standing in front of the camera. This is expected — the test validates that the pipeline runs without errors, not detection accuracy.
7. **Video tests should produce detections** (the test video has people in it). Zero detections on video is a failure that must be investigated.
8. **Capture Wayland screenshots** of video tests using `take-screenshot` and save to `~/wp1/screenshots/`. Only video screenshots go in the manual — camera scenes are inconsistent.

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

### Phase 2: On-SoC NPU Detection (yolov8n unified)

Test the EdgeFirst detection pipeline on each platform using the unified `yolov8n` binary. The binary auto-selects VX Delegate on imx8mp or Neutron on imx95 based on the `.tflite` model and `-p` flag.

For each board, run 4 tests — camera + video for both EdgeFirst and reference pipelines:

```bash
# imx8mp — EdgeFirst camera (VX Delegate)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n_640x640.tflite \
    -p imx8mp -c /dev/video3 -n 900 -H" 2>&1 | tee /tmp/qa-det-imx8mp-cam.log

# imx8mp — EdgeFirst video (VX Delegate)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n_640x640.tflite \
    -p imx8mp -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-det-imx8mp-vid.log

# imx95 — EdgeFirst camera (Neutron)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n_640x640.imx95.tflite \
    -p imx95 -n 900 -H" 2>&1 | tee /tmp/qa-det-imx95-cam.log

# imx95 — EdgeFirst video (Neutron)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n_640x640.imx95.tflite \
    -p imx95 -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-det-imx95-vid.log
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

### Phase 3: Ara240 Detection (yolov8n unified + yolov8n_ara2_reference)

Test the Ara240 NPU pipeline on both platforms using the unified binary with `.dvm` models:

```bash
# EdgeFirst Ara240 — camera (both platforms)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n_640x640.dvm \
    -p <platform> -n 900 -H" 2>&1 | tee /tmp/qa-ara2-<board>-cam.log

# EdgeFirst Ara240 — video (both platforms)
ssh <board> "/opt/edgefirst/yolov8n \
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

### Phase 4: Segmentation (yolov8n unified with segmentation models)

Test instance segmentation on both platforms with both Ara-2 and TFLite backends. The unified `yolov8n` binary auto-detects segmentation models from tensor shapes:

```bash
# Ara-2 YOLOv8n-seg — camera (both platforms)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n-seg_640x640.dvm \
    -p <platform> -n 900 -H" 2>&1 | tee /tmp/qa-seg-ara2-<board>-cam.log

# Ara-2 YOLOv8n-seg — video (both platforms)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n-seg_640x640.dvm \
    -p <platform> -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-seg-ara2-<board>-vid.log

# Ara-2 YOLOv8m-seg — video (higher accuracy, both platforms)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8m-seg_640x640.dvm \
    -p <platform> -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-segm-ara2-<board>-vid.log

# TFLite VX YOLOv8n-seg — video (imx8mp only)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n-seg_640x640.tflite \
    -p imx8mp -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-seg-vx-imx8mp-vid.log

# TFLite Neutron YOLOv8n-seg — video (imx95 only)
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n-seg_640x640.imx95.tflite \
    -p imx95 -v 853889-hd_1920_1080_25fps.mp4 -n 900 -H" 2>&1 | tee /tmp/qa-seg-neutron-imx95-vid.log
```

**Pass criteria:** Exit code 0, timing report printed (includes Preprocess, Inference, Draw Masks), video runs show detections. YOLOv8m-seg should be slower than YOLOv8n-seg (higher inference time) but still functional.

### Phase 4b: Detection Signal Callback (-D flag)

Test the detection signal output, which prints per-frame bounding boxes and mask info to the console:

```bash
# Detection signal with Ara-2 segmentation
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n-seg_640x640.dvm \
    -p <platform> -v 853889-hd_1920_1080_25fps.mp4 -D -H -n 300" 2>&1 | tee /tmp/qa-signal-<board>.log

# Detection signal with TFLite detection
ssh <board> "/opt/edgefirst/yolov8n \
    -m models/yolov8n_640x640.tflite \
    -p imx8mp -v 853889-hd_1920_1080_25fps.mp4 -D -H -n 300" 2>&1 | tee /tmp/qa-signal-vx-<board>.log
```

**Pass criteria:** Console output shows per-frame detection lines with normalized box coordinates (values between 0.0 and 1.0), class labels, confidence scores, and mask dimensions for segmentation models.

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

After completing all phases, compile a summary report at `~/wp1/EDGEFIRST_TEST_REPORT-<YYYY-MM-DD>.md` with:

1. **Test matrix** — table of all tests run, with PASS/FAIL status
2. **Timing comparison** — measured vs. expected values from the manual, flagging any >15% discrepancies
3. **Screenshots** — Wayland screenshots from video tests saved to `~/wp1/screenshots/`, referenced in the report. Only video screenshots (not camera) are used for the User Manual.
4. **Discovered issues** — any failures, crashes, or unexpected behavior, with:
   - Exact error message
   - Which board/platform/input combination
   - Log file location
   - Suggested fix if obvious, or "needs investigation" if not
5. **Manual corrections needed** — any commands that didn't work as written, any expected results that need updating
6. **Questions for the user** — anything ambiguous that needs human judgment (e.g., "detection count on imx8mp video is lower than imx95 — is this a known platform difference or a bug?")

**Do NOT silently fix commands that fail.** If a manual command doesn't work as-is, report it as a discrepancy. The manual must be corrected, not the test.

### Known Platform Differences

These are expected differences between platforms — do not flag as issues:

- **imx8mp camera uses `-c /dev/video3`** (v4l2src with VSI ISP); imx95 camera uses libcamerasrc (no `-c` flag needed)
- **imx8mp uses `.tflite` models**; imx95 uses `.imx95.tflite` models (Neutron-compiled). Both use `.dvm` for Ara240.
- **imx8mp video pipelines insert `imxvideoconvert_g2d`** (NV12→RGBA) automatically — this is a known workaround for Vivante NV12 unreliability. imx95 does not need this.
- **imx8mp FPS is generally lower than imx95** due to different SoC generation and GPU capability.
- **imx8mp Ara240 video may show fewer detections** than imx95 with the same video — this is due to NV12 preprocessing quality differences through the Vivante GPU path.
- **imx8mp camera is capped at 30 FPS** by the v4l2src/ISP; imx95 camera with Ara240 can exceed 30 FPS (up to ~60 FPS).
- **Mask offset varies by NPU speed.** Segmentation masks are rendered asynchronously — the overlay draws masks from the most recent inference result onto the current video frame. Faster NPUs (Ara-2 at ~14ms inference) produce masks that are only ~1 frame behind the video. Slower NPUs (VX Delegate at ~85ms inference) produce masks that lag several frames behind, resulting in a visible spatial offset between the mask and the person. This is expected and not a bug — it demonstrates the real-time pipeline operating without frame synchronization.

### Test Count

A complete QA run covers tests across 2 boards:

| Phase | Tests per board | Total |
|-------|----------------|-------|
| Downloads | 3 command groups | 6 |
| On-SoC detection (EdgeFirst + reference, camera + video) | 4 | 8 |
| Ara240 detection (EdgeFirst + reference, camera + video) | 4 | 8 |
| Segmentation (Ara-2 + TFLite, camera + video) | 5 | 10 |
| Detection signal (-D flag) | 2 | 4 |
| **Total** | | **36** |

If only one board is available, the count halves. All tests for one board can complete in ~30 minutes (tests run ~36 seconds each, plus model load overhead).

## Adding Vendor Manifests

To support a new i.MX-based vendor platform:

1. Create a vendor layer repository `meta-edgefirst-<vendor>` (its content only on `main`) holding the vendor-specific image recipe, update/signing integration, kernel bbappends/patches, and workarounds. Keep anything portable in `meta-edgefirst`.
2. Create a branch named `edgefirst-<vendor>-<bsp-version>` in `EdgeFirstAI/yocto` with a standalone manifest of the same name holding the vendor's projects as published, `meta-edgefirst` and the vendor layer pinned by SHA with `upstream="main"`, and a self-reference project pointing at that branch. Add the setup tooling, README, copilot instructions, and CHANGELOG the branch needs.
3. Users init with: `repo init -b <branch> -m <manifest>.xml`
4. Add the branch to the index in `main`'s README and to the table in this file.
5. Add the vendor to the rollout checklist: record how its image is built, where its test boards are, and which owned patches its kernel needs.

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

### What a branch changelog records

A branch `CHANGELOG.md` records what a user of that BSP can see: release versions, runtime and package versions, supported boards and features, installation and update behaviour, and image changes. It does not record how Yocto is put together: manifest pins, layer moves, recipe and packagegroup restructuring and other build-system details belong in commit messages and the layer changelogs. Ask the user before changing a changelog.

### Package changelog URL pattern

All EdgeFirstAI packages use the same URL pattern for their changelog at a specific version tag:

```
https://github.com/EdgeFirstAI/<repo>/blob/v<version>/CHANGELOG.md
```

Examples:
- `https://github.com/EdgeFirstAI/hal/blob/v0.16.2/CHANGELOG.md`
- `https://github.com/EdgeFirstAI/schemas/blob/v2.2.1/CHANGELOG.md`
- `https://github.com/EdgeFirstAI/gstreamer/blob/main/CHANGELOG.md` (use version tag once `v0.2.0` is tagged)
