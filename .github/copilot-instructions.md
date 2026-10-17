# EdgeFirst Yocto — Torizon (agent instructions)

This is the `torizon` branch of `EdgeFirstAI/yocto`.
It is an orphan branch that holds the repo manifests for building Torizon OS (Toradex's OSTree-based, container-first distro) on Toradex Verdin SoMs with `meta-edgefirst` and `meta-edgefirst-torizon`.
The other branches of the repository (NXP, Phytec, Ezurio) are independent of this one and share no files, images or tooling with it.

## Rules

- Always update `README.md` and `.github/copilot-instructions.md` when making changes that affect the project setup, usage instructions, or structure. Documentation must **ALWAYS** be kept up-to-date.
- **We own everything.** "Bug exists in another repository" is **NEVER** an acceptable conclusion. Yocto gives us access to every repository in the build — meta-edgefirst, meta-edgefirst-torizon, the Torizon kernel, the NPU delegates — and we are totally responsible for addressing **ANY** and **ALL** performance limitations or bugs in any of them.
- Markdown files in this repo use no manual line wrapping — write each paragraph and list item as one continuous line and let the renderer soft-wrap it.
- Sign commits with `-s`.

## Repository Structure

```
EdgeFirstAI/yocto/ (torizon branch)
  .github/copilot-instructions.md   # This file
  edgefirst-torizon-walnascar.xml   # Standalone manifest (Torizon walnascar + EdgeFirst)
  scripts/
    setup-edgefirst                 # Sourced instead of setup-environment
    publish-repo.sh                 # Publishes an OSTree repo to S3
  README.md
  CHANGELOG.md
```

## How the Manifest Works

Users init with `repo init -u https://github.com/EdgeFirstAI/yocto.git -b torizon -m edgefirst-torizon-walnascar.xml`.
The manifest is standalone and defines every project directly:

1. **Torizon walnascar projects** — every project Toradex's `torizon-manifest` (walnascar branch) pins, at `path="layers/<name>"`. The layout is deliberate: `meta-toradex-torizon`'s `setup-environment` has a `bblayers.conf` template with `${OEROOT}/layers/...` hardcoded. Never move these off their walnascar revisions without re-validating the whole stack; walnascar is the only release train Toradex has released Torizon against, and NXP's newer trains (whinlatter, wrynose) are not compatible with the Toradex layers.
2. **`meta-edgefirst`** — pinned to a commit on its `main` branch. Its `LAYERSERIES_COMPAT` covers walnascar, and it selects walnascar-specific sources and patches itself.
3. **`meta-edgefirst-torizon`** — pinned to a commit on `main` of [EdgeFirstAI/meta-edgefirst-torizon](https://github.com/EdgeFirstAI/meta-edgefirst-torizon).
4. **`yocto`** — self-reference that checks out this branch at `layers/edgefirst-yocto/` and links `.github`, `README.md`, `setup-edgefirst` and `publish-repo.sh` into the top level.

To update the EdgeFirst layers, fetch the latest `main` of both repositories, build and verify both machines, then bump the two `revision` attributes in the manifest. Push layer commits before pinning them, since the manifest must only reference commits that exist on GitHub.

`meta-kinara` is intentionally absent because it needs a non-public Ara-2 runtime mirror. `meta-edgefirst-torizon/conf/layer.conf` removes the `ara2` package config that `meta-edgefirst` otherwise enables.

## Working Tree (after `repo sync`)

```
.github → layers/edgefirst-yocto/.github
README.md → layers/edgefirst-yocto/README.md
setup-environment → layers/meta-toradex-torizon/scripts/setup-environment
setup-edgefirst → layers/edgefirst-yocto/scripts/setup-edgefirst
layers/
  edgefirst-yocto/          # This branch of EdgeFirstAI/yocto
  meta-edgefirst/           # Generic EdgeFirst layer
  meta-edgefirst-torizon/   # Torizon vendor layer
  meta-toradex-torizon/     # Torizon distro layer
  openembedded-core/        # includes bitbake/
  ...                       # Other Toradex/OE walnascar layers
build-verdin-imx8mp/        # Per-MACHINE build directory
build-verdin-imx95/
```

## Build Configuration

- **Distro:** `torizon`
- **Images:** `torizon-minimal`, `torizon-docker`
- **Machines:** `verdin-imx8mp`, `verdin-imx95`
- **Setup script:** `setup-edgefirst`, which wraps Toradex's `setup-environment`.

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git -b torizon -m edgefirst-torizon-walnascar.xml
repo sync
MACHINE=verdin-imx8mp source setup-edgefirst build-verdin-imx8mp
bitbake torizon-minimal
```

Toradex's `bblayers.conf` template has an `EXTRALAYERS ?= ""` hook that cannot be set from outside, and its checksum logic regenerates the file whenever `MACHINE`, `DISTRO`, `EULA` or its own scripts change. `setup-edgefirst` therefore defaults `DISTRO=torizon` and `EULA=1`, runs `setup-environment`, and re-adds `meta-edgefirst` and `meta-edgefirst-torizon` with `bitbake-layers add-layer` on every run. It also appends a `BBMASK` block to `conf/local.conf`, because the Torizon `local.conf` template resets `BBMASK` and a layer cannot set it. Everything else the build needs lives in `meta-edgefirst-torizon/conf/layer.conf`, so a build directory needs no hand-edited configuration.

Point `DL_DIR` and `SSTATE_DIR` at shared locations in `conf/site.conf` to avoid refetching and rebuilding across build directories.

Avoid committing to a layer repository while a build is running. A change in git state invalidates the parse cache and can trip the basehash error described below.

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

### MANDATORY: pre-publish checklist for every OSTree commit

Run all of these against the committed ref before running `publish-repo.sh` or flashing, for both machines. A green build does not prove any of them, and the failures below recur on Torizon builds.

```bash
R=build-<machine>/deploy/images/<machine>/ostree_repo
OSTREE=build-<machine>/tmp/sysroots-components/x86_64/ostree-native/usr/bin/ostree
C=$(cat "$R/refs/heads/0/<machine>/torizon/edgefirst/testing")
"$OSTREE" --repo="$R" ls -R "$C" /usr/lib/modules | grep initramfs.img      # tens of MB, not ~1 KB
"$OSTREE" --repo="$R" cat "$C" /usr/lib/passwd | cut -d: -f1 | tr '\n' ' '   # full account list, including messagebus
"$OSTREE" --repo="$R" ls "$C" /usr/bin | grep -E 'docker$|edgefirst'         # docker, edgefirst-client, edgefirst-profiler
```

- `/usr/lib/passwd` must list the system accounts (`messagebus`, `systemd-resolve`, `sshd`, `avahi` and the rest), not just `torizon`. A reduced file breaks D-Bus, NetworkManager and networking on the target.
- Also confirm the delegate for the machine is in the image manifest and that the kernel tree carries the Neutron dma-buf commits on `verdin-imx95`.
- **Never retry a failed build in place.** A `do_image_ostreecommit` basehash or taskhash error leaves the rootfs already reduced, and the retry runs `do_image` a second time, which silently drops every account but `torizon`. After any failure at or after `do_image`, run `bitbake <image> -c cleansstate` and then a single `bitbake <image>`, and repeat the checklist.
- Avoid committing to layer repositories while a build runs, and clear `build-<machine>/tmp/cache/bb_cache.dat*` when layer git state has changed since the last parse.
- A stale `pseudo-rootfs/` directory in the image work dir makes `do_rootfs` fail with `chown: invalid user: 'root:root'`. `cleansstate` on the image removes it.
- Use absolute paths in build scripts. `setup-environment` changes into the build directory, so relative log paths fail silently.

### MANDATORY: verify the initramfs before every push or flash

A green build is not sufficient proof the image is bootable. Confirm the initramfs baked into the commit is full size (tens of MB), not ~1KB:

```bash
"$OSTREE" --repo="$REPO" ls -R "$COMMIT" /usr/lib/modules | grep initramfs.img
```

If it reports ~1084 bytes, do not push or flash it — the target kernel will panic early and U-Boot will silently roll back (`bootcount > bootlimit`, `rollback=1`), leaving the device on its old image with no obvious error on your end.

**Root cause of the empty-initramfs failure mode:** `ostree-kernel-initramfs`'s `do_install` copies the deploy-dir initramfs image into the committed `/usr/lib/modules/<kver>/initramfs.img`, and its task hash does not depend on that file's content. If the initramfs image recipe (`initramfs-ostree-torizon-image`) is rebuilt and ends up with a different (or momentarily tiny) output, `ostree-kernel-initramfs` can keep its cached copy, so the commit carries a stub of about 1 KB even though `deploy/` holds the full 25 MB cpio. When the committed `initramfs.img` is tiny, run `bitbake torizon-docker initramfs-ostree-torizon-image ostree-kernel-initramfs -c cleansstate`, then a single `bitbake torizon-docker`, and repeat the verification.

### MANDATORY: do not run do_image twice against the same rootfs

Torizon's `nss_altfiles_set_users_groups` (triggered by the `stateless-system` distro feature) snapshots the full account database from `/etc/passwd`/`group`/`shadow` into `/usr/lib/{passwd,group,shadow}` at `do_image` time, then reduces `/etc/*` to just the `torizon` user. **This is not idempotent.** If `do_image` runs a second time against a rootfs whose `/etc/passwd` has already been reduced, the second run re-snapshots the already-reduced (torizon-only) files, permanently losing every other account (`messagebus`, `systemd-resolve`, `avahi`, `sshd`, etc.) from the committed image. This has previously caused `dbus.service` to fail with `status=217/USER` on target (can't resolve the `messagebus` user), cascading to a broken `NetworkManager`/D-Bus stack and no networking. If you suspect this happened (e.g. after a basehash-recovery rebuild sequence that re-ran tasks unexpectedly), do a single clean `bitbake -c cleansstate torizon-minimal && bitbake torizon-minimal` pass and re-verify the account list directly from the OSTree commit (`ostree cat $COMMIT /usr/lib/passwd`) before trusting the build.

### Basehash "not deterministic" on do_image_ostreecommit

Changing git state (e.g. committing to a layer) under a stale parse cache can trip this — the build exits non-zero even though all individual tasks report success. Fix: `rm -f build-<machine>/tmp/cache/bb_cache.dat*`, then `bitbake <image> -c cleansstate` and a single `bitbake <image>`. Rebuilding in place after the failure runs `do_image` twice and drops the system accounts, as described above.

### Deploying to Torizon Cloud OTA

Pushing a built commit to OTA (via `torizoncore-builder`) does **not** target it to a device — that only makes the commit available; targeting/rollout to a specific device is a separate step in Torizon Cloud. On-device, the SOTA client is `aktualizr-torizon`, configured under `/var/sota/`, with its gateway URL at `/var/sota/import/gateway.url` (normally `https://dgw.torizon.io`).

## Scope: EdgeFirst Perception Foundation

Three tiers make up the EdgeFirst-on-i.MX stack:

- **NPU drivers and firmware** — kernel-level, unavoidably part of the OS.
- **EdgeFirst Perception Foundation** — `packagegroup-edgefirst` (HAL, VideoStream), `packagegroup-edgefirst-npu` (TensorFlow Lite and the VX or Neutron delegate) and `packagegroup-edgefirst-studio` (`edgefirst-client`, `edgefirst-profiler`), all from `meta-edgefirst` and composed by `packagegroup-edgefirst-torizon`. They are tightly coupled to the kernel driver, so they belong in the OS image. **This branch installs the driver and firmware plus this tier, and nothing above it.**
- **Everything above Foundation** — GStreamer and NNStreamer pipelines, Zenoh perception services and ROS 2 integration. These run as Docker containers under Torizon's normal deployment model, not in this image.

If you are asked to add a perception service, a GStreamer pipeline package or ROS 2 integration to the image, stop and check this section first. That almost certainly belongs in a container. Ask before adding anything beyond `packagegroup-edgefirst-torizon`.

## Our Layers

### [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst)

Generic and shared by every EdgeFirst platform. Anything that is not specific to Torizon or Toradex belongs there, not in the vendor layer.

### [meta-edgefirst-torizon](https://github.com/EdgeFirstAI/meta-edgefirst-torizon)

Everything specific to Torizon on Verdin:

- `packagegroup-edgefirst-torizon`, installed into `torizon-minimal` and `torizon-docker` by their bbappends.
- `linux-toradex-imx_%.bbappend`, which applies `meta-edgefirst`'s Neutron dma-buf patches to Toradex's kernel recipe (`meta-edgefirst`'s `linux-imx` bbappend never matches it). The patches are read from the `meta-edgefirst` checkout.
- `device-tree-overlays-imx_%.bbappend`, which builds `verdin-imx95_efpi-npu-dma-512m_overlay.dtbo` (the `/reserved-memory/npu-dma` Neutron pool, 128 MiB to 512 MiB) and appends it to `TEZI_EXTERNAL_KERNEL_DEVICETREE_BOOT` for `verdin-imx95`. After a reboot `/proc/device-tree/reserved-memory/npu-dma/size` reads `00 00 00 00 20 00 00 00`. The i.MX 8M Plus has no dedicated NPU pool; its VX NPU allocates from the shared `linux,cma` region.
- Bbappends that build `tensorflow-lite-vx-delegate` and `tensorflow-lite-neutron-delegate` from the rolling `edgefirst` branches of their forks. `meta-edgefirst` selects the frozen `edgefirst-1.2.3` branches on walnascar, and the Torizon layer's higher priority makes its overrides run last. `litert-vx-delegate` is not overridden because the newer branch needs the LiteRT 6.18 layout and no image installs it. Bump the `SRCREV` pins when the fork branches advance.
- Kernel revision pins that carry the Verdin device trees, the `tim-vx` and `aktualizr-torizon` build fixes, and the settings that remove dependencies on layers this build does not carry.

When porting a `meta-edgefirst` hardware patch to Torizon, check whether it targets `linux-imx`, which needs retargeting onto `linux-toradex-imx`. The NPU delegate recipes keep their upstream names on Torizon, so `meta-edgefirst`'s bbappends on them apply unchanged.

## Yocto Release Compatibility

`meta-edgefirst` declares `LAYERSERIES_COMPAT` for scarthgap, walnascar, whinlatter and wrynose. Do not bump the manifest to a `meta-edgefirst` commit that drops walnascar, and do not move the Torizon projects off their pinned revisions without re-validating the whole stack.

## Changelog Management

`CHANGELOG.md` records changes to this branch: manifest pins, setup tooling and publishing. It links to `meta-edgefirst/CHANGELOG.md` for per-package version tables, which in turn link to each package's own changelog.

## Signing the OSTree repository

Published commits and the repository summary are signed with the dedicated GPG key `EdgeFirst Torizon OSTree Signing 1` (RSA-4096, fingerprint `F84E000B6A60E73210BC588812662353529A4EFC`). The key and its GPG home live in `~/edgefirst-ca/torizon/private/gnupg`, and the public key is `~/edgefirst-ca/torizon/edgefirst-torizon-ostree.gpg`; neither is ever copied into a Yocto tree or committed.

Publish with `OSTREE_GPG_KEY` set to the fingerprint, `OSTREE_GPG_HOMEDIR` to that GPG home and `OSTREE_SIGN_BIN=/usr/bin/ostree`, because Yocto's `ostree-native` has no gpgme. Always pass `--ostree-only`: the TEZI step publishes to `s3://<bucket>/tezi/` and rewrites the shared `image_list.json`, which is outside the allowed `ostree/torizon` prefix.

After a publish, verify as a client would: add the public key with `ostree remote add --gpg-import=<key>` to a scratch repository and `ostree pull --depth=-1` each ref from `https://repo.edgefirst.ai/ostree/torizon`, then repeat with an unrelated key and expect "public key not found".
