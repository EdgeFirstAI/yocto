# EdgeFirst Yocto — Torizon (agent instructions)

This is the `torizon` branch of `EdgeFirstAI/yocto`. It targets Torizon OS (Toradex's OSTree-based, container-first distro) on Toradex Verdin SoMs, with the EdgeFirst Perception Foundation layer integrated — see "Scope: EdgeFirst Perception Foundation" below for exactly what that means and why. The `main` branch covers the default NXP i.MX EVK/FRDM manifests for other platforms and is a separate, unrelated flow — this file, this branch's README.md, and its manifest do not carry over `main`'s NXP-specific content (different distro, different image recipe, different machines, different publishing/SDK tooling), and `main`'s copilot-instructions.md does not apply here.

## Rules

- Always update `README.md` and `.github/copilot-instructions.md` when making changes that affect the project setup, usage instructions, or structure. Documentation must **ALWAYS** be kept up-to-date.
- **We own everything.** "Bug exists in another repository" is **NEVER** an acceptable conclusion. Yocto gives us access to every repository in the build — meta-edgefirst, meta-edgefirst-torizon, nnstreamer, edgefirst-gstreamer, edgefirst-hal, tflite-vx-delegate, the Torizon kernel — and we are totally responsible for addressing **ANY** and **ALL** performance limitations or bugs in any of them. No shortcuts, no deference, no "that's upstream's problem."
- Markdown files in this repo use no manual line wrapping — write each paragraph and list item as one continuous line and let the renderer soft-wrap it.

## Repository Structure

```
EdgeFirstAI/yocto/ (torizon branch)
  .github/
    copilot-instructions.md         # This file
  edgefirst-torizon-walnascar.xml   # Standalone manifest (Torizon walnascar + EdgeFirst)
  README.md
```

`meta-edgefirst-torizon` (the Torizon-specific hardware-enablement layer) is its own standalone repo, [EdgeFirstAI/meta-edgefirst-torizon](https://github.com/EdgeFirstAI/meta-edgefirst-torizon) — not part of this repo's tree. See "Our Layers" below.

## How the Manifest Works

Users init with `repo init -u https://github.com/EdgeFirstAI/yocto.git -b torizon -m edgefirst-torizon-walnascar.xml`. That manifest is a **standalone** manifest (not an overlay) that defines all projects directly:

1. **Torizon walnascar projects** — every project Toradex's own `torizon-manifest` (walnascar branch) pins, captured via `repo manifest -r` against a known-working Torizon build, at `path="layers/<name>"` — the same convention `torizon-manifest` itself uses. This is deliberate, not incidental: `meta-toradex-torizon`'s own `setup-environment` script has a stock `bblayers.conf` template with `${OEROOT}/layers/...` hardcoded (not configurable), and its regeneration-skip checksum logic only works correctly when the tree actually matches that layout. An earlier version of this manifest used `sources/<name>` (matching the NXP-flavor manifests on `main`, which use EdgeFirst's own `edgefirst-setup` script instead) — that broke `setup-environment`'s auto-generation outright (every path resolution failed against a nonexistent `layers/` tree). Never bump these off their walnascar-pinned revisions without deliberately re-validating the whole stack — walnascar is the only OE-core/Yocto release train Toradex has released Torizon against; NXP's newer BSP trains (whinlatter, wrynose) are NOT compatible with these Toradex layers.
2. **`<project name="meta-edgefirst">`** — pinned to the `edgefirst-1.2.3` branch tip (a fixed point, a superset of the `v1.2.3` tag — see "Our Layers" below for why the tag itself isn't used), not floating `main`, so this manifest doesn't drift when meta-edgefirst's `main` branch gets bring-up work for other BSP trains.
3. **`<project name="meta-edgefirst-torizon">`** — pinned to a commit on `main` of its own repo, [EdgeFirstAI/meta-edgefirst-torizon](https://github.com/EdgeFirstAI/meta-edgefirst-torizon) — see "Our Layers" below.
4. **`<project name="yocto">`** — self-reference: checks out this repo at `layers/edgefirst-yocto/`, pinned to the `torizon` branch (not `main`), and creates symlinks for `.github/` and `README.md`.

`meta-kinara` (Kinara Ara-2 NPU support) is intentionally not in this manifest — see "meta-kinara" below.

## Working Tree (after `repo sync`)

```
.github → layers/edgefirst-yocto/.github
README.md → layers/edgefirst-yocto/README.md
layers/
  edgefirst-yocto/          # This manifest repo (EdgeFirstAI/yocto, torizon branch)
  meta-edgefirst/           # EdgeFirst perception platform layer
  meta-edgefirst-torizon/   # Torizon-specific hardware-enablement layer, its own repo
  meta-toradex-torizon/     # Torizon distro layer (provides setup-environment)
  meta-freescale/           # NXP i.MX BSP (Toradex's fork)
  openembedded-core/        # includes bitbake/
  ...                       # Other Toradex/OE walnascar layers
build-verdin-imx8mp/        # Per-MACHINE build directory
build-verdin-imx95/
```

## Build Configuration

- **Distro:** `torizon`
- **Image:** `torizon-minimal`
- **Machines:** `verdin-imx8mp`, `verdin-imx95`
- **Setup script:** `setup-environment`, provided by `meta-toradex-torizon` (linked at the top level via the manifest's linkfile) — NOT `edgefirst-setup`, which is the NXP-flavor's own script and does not apply here.

### Setup

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b torizon -m edgefirst-torizon-walnascar.xml
repo sync
DISTRO=torizon MACHINE=verdin-imx8mp EULA=1 source setup-environment build-verdin-imx8mp
```

**Always pass `EULA=1` explicitly.** The setup script checksums itself against `MACHINE`/`DISTRO`/`EULA` to decide whether to skip regenerating `bblayers.conf`. Omitting `EULA=1` defeats that check and silently regenerates `bblayers.conf` from the stock template on every re-source, wiping out `EXTRALAYERS` (`meta-edgefirst`, `meta-edgefirst-torizon`).

### Building

```bash
bitbake torizon-minimal
```

### Re-entering the build environment

```bash
source setup-environment build-verdin-imx8mp
```

## Working with OSTree

Torizon OS is OSTree-based: the built image is committed into a local OSTree repository, not just packaged as a flashable disk image. This is central to how Torizon updates (atomic, image-based, remotely deployable) and it changes how you inspect and validate a build.

### Repo layout

- BitBake commits the build into `build-<machine>/deploy/images/<machine>/ostree_repo`.
- Refs are named `refs/heads/0/<machine>/<distro>/<image>/<branch>`, e.g. `refs/heads/0/verdin-imx8mp/torizon/torizon-minimal/testing`.
- The `ostree` binary to use is the one BitBake builds, not any host-installed one: `build-<machine>/tmp/sysroots-components/x86_64/ostree-native/usr/bin/ostree`.

### Inspecting a commit without flashing anything

You can validate a build's actual content directly from the OSTree repo, before ever touching hardware:

```bash
REPO=build-verdin-imx8mp/deploy/images/verdin-imx8mp/ostree_repo
OSTREE=build-verdin-imx8mp/tmp/sysroots-components/x86_64/ostree-native/usr/bin/ostree
COMMIT=$(cat "$REPO/refs/heads/0/verdin-imx8mp/torizon/torizon-minimal/testing")
"$OSTREE" --repo="$REPO" ls -R "$COMMIT" /usr/lib/modules
"$OSTREE" --repo="$REPO" cat "$COMMIT" /usr/lib/passwd
```

### MANDATORY: verify the initramfs before every push or flash

A green build is not sufficient proof the image is bootable. Confirm the initramfs baked into the commit is full size (tens of MB), not ~1KB:

```bash
"$OSTREE" --repo="$REPO" ls -R "$COMMIT" /usr/lib/modules | grep initramfs.img
```

If it reports ~1084 bytes, do not push or flash it — the target kernel will panic early and U-Boot will silently roll back (`bootcount > bootlimit`, `rollback=1`), leaving the device on its old image with no obvious error on your end.

**Root cause of the empty-initramfs failure mode:** `ostree-kernel-initramfs`'s `do_install` copies the deploy-dir initramfs image into the committed `/usr/lib/modules/<kver>/initramfs.img`. If the initramfs image recipe (e.g. `initramfs-ostree-torizon-image`) gets `cleansstate`'d in the **same** `bitbake` invocation as `ostree-kernel-initramfs`, the copy can race and catch the deploy file while it is momentarily empty. Never `cleansstate` the initramfs image alongside `ostree-kernel-initramfs`; if you need to force a rebuild, keep the initramfs image stable and rebuild only its consumers, then re-run the verification above.

### MANDATORY: do not run do_image twice against the same rootfs

Torizon's `nss_altfiles_set_users_groups` (triggered by the `stateless-system` distro feature) snapshots the full account database from `/etc/passwd`/`group`/`shadow` into `/usr/lib/{passwd,group,shadow}` at `do_image` time, then reduces `/etc/*` to just the `torizon` user. **This is not idempotent.** If `do_image` runs a second time against a rootfs whose `/etc/passwd` has already been reduced, the second run re-snapshots the already-reduced (torizon-only) files, permanently losing every other account (`messagebus`, `systemd-resolve`, `avahi`, `sshd`, etc.) from the committed image. This has previously caused `dbus.service` to fail with `status=217/USER` on target (can't resolve the `messagebus` user), cascading to a broken `NetworkManager`/D-Bus stack and no networking. If you suspect this happened (e.g. after a basehash-recovery rebuild sequence that re-ran tasks unexpectedly), do a single clean `bitbake -c cleansstate torizon-minimal && bitbake torizon-minimal` pass and re-verify the account list directly from the OSTree commit (`ostree cat $COMMIT /usr/lib/passwd`) before trusting the build.

### Basehash "not deterministic" on do_image_ostreecommit

Changing git state (e.g. committing to a layer) under a stale parse cache can trip this — the build exits non-zero even though all individual tasks report success. Fix: `rm -f build-<machine>/tmp/cache/bb_cache.dat*`, then rebuild.

### Deploying to Torizon Cloud OTA

Pushing a built commit to OTA (via `torizoncore-builder`) does **not** target it to a device — that only makes the commit available; targeting/rollout to a specific device is a separate step in Torizon Cloud. On-device, the SOTA client is `aktualizr-torizon`, configured under `/var/sota/`, with its gateway URL at `/var/sota/import/gateway.url` (normally `https://dgw.torizon.io`).

## Scope: EdgeFirst Perception Foundation

Three tiers make up the EdgeFirst-on-i.MX stack:

- **NPU drivers and firmware** — kernel-level only, unavoidably part of the OS. This is what "minimal integration" means on its own.
- **EdgeFirst Perception Foundation** (`packagegroup-edgefirst`: `edgefirst-hal`, `videostream`, `videostream-cli`, plus the patched NPU delegates — `tim-vx`, `tflite-vx-delegate`, `tensorflow-lite-neutron-delegate`) — tightly coupled to the kernel driver, so it also belongs in the OS image. **This manifest installs driver/firmware plus this tier, and nothing above it** — `local.conf` does `IMAGE_INSTALL:append = " packagegroup-edgefirst"`. As of this manifest's pin, `packagegroup-edgefirst` is its own standalone recipe (not a base package with `-gstreamer`/`-zenoh`/`-python` PACKAGES of the same recipe — that older structure meant wanting Foundation alone still forced bitbake to build the other flavors' dependencies; see "Our Layers" below for the pin rationale) — installing it does not pull in gstreamer/zenoh/python at all.
- **Everything above Foundation** — GStreamer/NNStreamer ML pipelines (`packagegroup-edgefirst-gstreamer`, its own standalone recipe, includes the EdgeFirst `nnstreamer` fork), Zenoh perception microservices (`packagegroup-edgefirst-zenoh`, its own standalone recipe: `edgefirst-camera`, `edgefirst-model`, `edgefirst-fusion`, `edgefirst-imu`, `edgefirst-navsat`, `edgefirst-radarpub`, `edgefirst-lidarpub`, `edgefirst-recorder`, `edgefirst-replay`, `edgefirst-websrv`, `edgefirst-webui`), `packagegroup-edgefirst-python` (Python bindings), and future ROS 2 integration — designed to run as Dockerized application containers under Torizon's normal Docker Compose deployment model, not baked into this OS image, and none of them get built as a side effect of installing `packagegroup-edgefirst`.

**Why stop at Foundation:** the NPU driver/firmware is unavoidably OS-level (a kernel driver can't be containerized). Foundation is tightly coupled to that specific driver/kernel version, so it also belongs in the OS image for now. Everything above Foundation is meant to be containerized regardless of what this manifest does. Once Torizon Version 8 ships with native NPU driver/firmware integration, Dockerized EdgeFirst workloads should work out-of-the-box on stock Torizon without needing this manifest's Foundation layer at all — containers would bundle their own userspace and just need the host's native driver. Until then, this manifest provides driver/firmware plus Foundation so Dockerized perception workloads have something to build on today.

**If you're asked to add a perception service, a GStreamer/NNStreamer pipeline package, or ROS 2 integration to this image's `IMAGE_INSTALL`:** stop and check this section first — that almost certainly belongs in a container, not this manifest. Ask before adding anything beyond `packagegroup-edgefirst`'s base package and its transitive Foundation/delegate dependencies.

## Our Layers

### [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst)

EdgeFirst perception platform: HAL, camera/sensor services, GStreamer ML pipelines, NNStreamer examples, Zenoh infrastructure, web UI — the full upstream layer. This manifest only installs its Foundation tier; see "Scope" above.

Pinned here to `722b99402cce062f8f98f50cdc1f9f824c46b989` on the `edgefirst-1.2.3` branch — deliberately NOT the `v1.2.3` tag (`00ff79f1...`), even though it's a walnascar-compatible, confirmed-`LAYERSERIES_COMPAT` release. Two reasons, both fixed in this pin (a clean superset of the tag, 5 commits ahead, no divergence): the tag-era `packagegroup-edgefirst` was a single recipe with `-zenoh`/`-gstreamer`/`-python` as PACKAGES of that same recipe, so requesting Foundation alone still forced bitbake to build the other flavors' dependencies — the fix (`722b994`) splits them into standalone recipes; and the tag-era bbappends for `tflite-vx-delegate`/`tim-vx`/`imx-gst1.0-plugin`/`nnstreamer`/`litert-vx-delegate` pinned SRCREVs against rolling fork branches that were later force-pushed for other BSP-train work, orphaning those SRCREVs (`do_fetch` "Unable to find revision ... in branch") — fixed by `6bc71dc` repointing them at the forks' own `edgefirst-1.2.3` branches (SRCREVs unchanged). If you ever need to re-derive this pin, take the tip of `edgefirst-1.2.3`, not the `v1.2.3` tag.

### [meta-edgefirst-torizon](https://github.com/EdgeFirstAI/meta-edgefirst-torizon)

Torizon-specific hardware-enablement patches. Its own standalone public repo, same as `meta-edgefirst` above — referenced by this manifest as a `repo` project (`path="layers/meta-edgefirst-torizon"`), pinned to a commit on its `main` branch.

**Why it exists:** meta-edgefirst's own kernel bbappend (`recipes-kernel/linux/linux-imx_%.bbappend`) targets NXP's raw `linux-imx` recipe name. Torizon does not use that recipe — the actual kernel recipe here is `linux-toradex-imx` (Toradex's own downstream fork). A bbappend targeting the wrong recipe name is not an error, it just silently never applies. `meta-edgefirst-torizon`'s `linux-toradex-imx_%.bbappend` carries the same patches meta-edgefirst applies for the NXP flavor, retargeted onto the correct recipe name:

- `0001-npu-dma-512m.patch` — enlarges the Verdin i.MX95 Neutron NPU's CMA reserved-memory pool from 128 MiB to 512 MiB. **Currently disabled** (present in the layer, not referenced in `SRC_URI`) — the `torizon-kernel-meta` pin needed for `verdin-imx95`'s kernel-config feature file restructured how the Neutron NPU's memory-region is declared, and the `npu_dma` devicetree node this patch targets no longer exists; re-deriving it against the new `.dtso` overlay model is follow-up work.
- `0001-staging-neutron-export-buffers-as-dma-buf.patch` — Neutron NPU DMA-BUF export support (zero-copy V4L2/GStreamer/GPU sharing), copied byte-exact from meta-edgefirst's own patch file.

Both are scoped `SRC_URI:append:verdin-imx95` — i.MX8M Plus doesn't have the Neutron NPU or the DT node these patch, and `linux-toradex-imx` is shared across both machines' `COMPATIBLE_MACHINE`.

**When porting a future meta-edgefirst hardware patch to Torizon:** check whether it targets `linux-imx` (needs retargeting here) or one of the NPU delegate recipes (`tim-vx`, `tflite-vx-delegate`, `litert-vx-delegate`, `tensorflow-lite-neutron-delegate`, `nnstreamer`, `imx-gst1.0-plugin`) — those come from `meta-freescale-ml`/`meta-imx-ml` under their normal upstream names in this manifest too, so meta-edgefirst's bbappends onto them apply here with no retargeting needed. The kernel recipe name is the one Torizon-specific exception.

### meta-kinara

Not included in this manifest. `meta-kinara` (Kinara Ara-2 NPU support) requires a non-public Ara-2 runtime mirror (`KINARA_MIRROR`, NDA-gated) — a version that avoids this requirement is in progress. Until it's added back, `local.conf` must override the `ara2` PACKAGECONFIG that `meta-edgefirst` otherwise force-enables unconditionally for both `mx8mp-nxp-bsp` and `mx9-nxp-bsp` machine overrides (`nnstreamer_%.bbappend`'s `PACKAGECONFIG_SOC:*:append` and `packagegroup-imx-ml.bbappend`'s `ML_NNSTREAMER_PKGS:*:append`, both append `ara2`/`nnstreamer-ara2`), or the build fails looking for the missing `ara2` recipe:

```
PACKAGECONFIG_SOC:remove:mx8mp-nxp-bsp = "ara2"
PACKAGECONFIG_SOC:remove:mx9-nxp-bsp = "ara2"
ML_NNSTREAMER_PKGS:remove:mx8mp-nxp-bsp = "nnstreamer-ara2"
ML_NNSTREAMER_PKGS:remove:mx9-nxp-bsp = "nnstreamer-ara2"
```

## Yocto Release Compatibility

This manifest's meta-edgefirst pin declares `LAYERSERIES_COMPAT = "scarthgap walnascar"`. Do not bump this manifest's meta-edgefirst pin to a commit whose `LAYERSERIES_COMPAT` drops `walnascar`, and do not bump the Torizon walnascar projects off their pinned revisions without re-validating the whole stack — see "How the Manifest Works" above.

## Adding Vendor Manifests

This is itself a vendor manifest, following the pattern documented on `main`: a standalone manifest with the vendor's projects, our layers, and a self-reference project, with users doing `repo init -m <manifest>.xml`. If Torizon ever needs a second flavor (e.g. the full EdgeFirst Perception stack baked into the image, see README.md), it likely wants its own manifest file following this same pattern rather than branching logic into this one.

## Changelog Management

```
edgefirst-yocto/CHANGELOG.md          # Manifest-level: layer updates, build/deploy changes
  ↓ links to
meta-edgefirst/CHANGELOG.md           # Layer-level: package version table + layer changes
  ↓ links to
github.com/EdgeFirstAI/<pkg>/blob/v<ver>/CHANGELOG.md   # Package-level: detailed changes
```

`CHANGELOG.md` at the repo root is shared across both the `main` (NXP) and `torizon` branches — it's a genuinely cross-flavor release history, since layer version bumps apply regardless of which manifest consumes them. Don't fork it per-branch.
