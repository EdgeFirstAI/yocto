# EdgeFirst Yocto for Ezurio

EdgeFirst on Ezurio Nitrogen SMARC boards. The image is built from Ezurio's `SUMMIT-REL-6.16.0.27` release (NXP 6.12.49-2.2.0, Yocto 5.2 walnascar) with [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) and [meta-edgefirst-ezurio](https://github.com/EdgeFirstAI/meta-edgefirst-ezurio), and it installs and updates the way Ezurio's own images do: a `.wic.bz2` for flashing media and a signed `.swu` for `fw_update`.

This is the `edgefirst-ezurio-6.16.0.27` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto). The `main` branch lists every supported branch.

This branch is **EdgeFirst Yocto for Ezurio**, one of the EdgeFirst Yocto products. Releases are versioned `YYYY.MM.PATCH` (for example `2026.10.0`), and a published release is never changed; a fix is the next `PATCH`. All the branches share one set of NPU, GPU, camera and vision-pipeline enablement through [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst), which is kept current by re-pinning every branch together, and the NXP boards are the reference platform where each new NXP BSP is adopted first.

## Supported Machines

| MACHINE | Board | NPU |
|---|---|---|
| `imx8mp-nitrogen-smarc-4g` | Nitrogen SMARC with i.MX 8M Plus, 4 GB | Vivante, through the TFLite VX delegate |
| `imx95-nitrogen-smarc` | Nitrogen SMARC with i.MX 95 | eIQ Neutron, through the TFLite Neutron delegate |

## What Is in the Image

- TensorFlow Lite with the NPU delegate for the SoC, and the Neutron runtime on i.MX 95
- OpenGL ES and EGL, and the `libg2d` 2D blitter
- libcamera and V4L2 camera support, with Ezurio's camera setup and the Arducam Pivariety driver
- `edgefirst-client` and `edgefirst-profiler`
- `v4l-utils` and `devmem2` for bring-up

There is no GStreamer, NNStreamer, ONNX or Python. The root filesystem is a read-only, dm-verity protected squashfs that fits comfortably in Ezurio's 512 MiB slot.

## Releases

Releases are quarterly and numbered `YYYY.MM.PATCH`, for example `2026.10.0`. A published release is never changed; a fix is the next `PATCH`. Each is published at `https://repo.edgefirst.ai/ezurio/<machine>/<version>/`:

| File | Use |
|---|---|
| `edgefirst-yocto-ezurio-<machine>-<version>.swu` | SWUpdate package for `fw_update` |
| `edgefirst-yocto-ezurio-<machine>-<version>.wic.bz2` | Full image for an SD card |
| `edgefirst-yocto-ezurio-<machine>-<version>.wic.bmap` | Block map for `bmaptool` |
| `SHA256SUMS` | Checksums of the three files above |

`https://repo.edgefirst.ai/ezurio/<machine>/latest.json` points at the newest release and lists the URL and checksum of each file. It is the only file that changes after publication.

The `.swu` is signed through the EdgeFirst chain: EdgeFirst Root CA, then EdgeFirst EZURIO CA, then the signing certificate. An EdgeFirst release trusts the root (`https://repo.edgefirst.ai/ezurio/edgefirst-root.crt.pem`) and refuses a package that does not chain to it.

## Installing an Image

Installing writes the whole of the media, so it erases everything on it.

1. Download the `.wic.bz2`, the `.wic.bmap` and `SHA256SUMS` for your machine and check them:

   ```bash
   sha256sum --ignore-missing -c SHA256SUMS
   ```

2. Write the image to an SD card, replacing `/dev/sdX` with the card:

   ```bash
   sudo bmaptool copy --bmap <name>.wic.bmap <name>.wic.bz2 /dev/sdX
   ```

3. Put the board's boot mode switches in the SD card position, insert the card and power on. The switches and their positions are in the boot mode section of Ezurio's user guide for your module, for example the [Nitrogen8M Plus SMARC](https://www.ezurio.com/documentation/user-guide-nitrogen8m-plus-smarc-som) guide.

### Running From eMMC

A board running from the SD card can install the release onto its eMMC with the `.swu`. Booted from SD, `fw_update` uses the `complete` method, which **erases the entire eMMC**, including `/perm`, partitions it for the A/B layout and writes the bootloader and both root filesystem slots:

```bash
fw_update -v <name>.swu
```

When it reports success, power off, set the boot mode switches to eMMC and power on. Check `/etc/os-release` to confirm the release you expect is running.

## Upgrading

A board that already runs an EdgeFirst release from eMMC upgrades in place. `fw_update` writes the slot you are not running, makes it the boot slot and reboots:

```bash
# From a file copied to the device
scp <name>.swu root@<board>:/tmp/
ssh root@<board> fw_update -v /tmp/<name>.swu

# Or downloaded by the device
ssh root@<board> fw_update -v https://repo.edgefirst.ai/ezurio/<machine>/<version>/<name>.swu
```

What an update keeps and what it resets:

- `/perm` is kept.
- `/rw`, where the running system stores changes to the root filesystem, is reset for the new slot. That includes root's home directory, so `~/.ssh/authorized_keys` and other files in `/root` are gone after an update, and so are edits to `/etc`.
- The device has new SSH host keys, so SSH clients warn about a changed host key.

The previous release stays in the other slot. Ezurio's updater does not roll back automatically, and `fw_update -s a|b` selects the slot to write.

An EdgeFirst release only accepts `.swu` packages signed by the EdgeFirst chain. Development builds made without a signing key are unsigned and can only be installed from a `.wic`.

## Logging In

Ezurio's images ship with the `root` password `summit`:

```bash
ssh root@<board>
```

Change it with `passwd` on any board that is reachable from a network you do not control. A password changed this way, like a key added to `~/.ssh/authorized_keys`, lives in `/rw` and returns to the default when the board is updated. To keep it across updates, set the password hash in your own image (`PASSWD` in Ezurio's `image-summitsom-gen.bbclass`), or install the key again after each update, for example with `ssh-copy-id`.

## Building

Install [repo](https://gerrit.googlesource.com/git-repo) and the [Yocto host requirements](https://docs.yoctoproject.org/5.2/ref-manual/system-requirements.html), then:

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b edgefirst-ezurio-6.16.0.27 -m edgefirst-ezurio-6.16.0.27.xml
repo sync
MACHINE=imx95-nitrogen-smarc . edgefirst-setup -b build-imx95
bitbake image-edgefirst
```

`edgefirst-setup` runs Ezurio's own `setup-environment-nxp` and adds `meta-edgefirst` and `meta-edgefirst-ezurio` to the `bblayers.conf` of a new build directory. Everything else in the generated `local.conf` and `bblayers.conf` is Ezurio's. It asks for the NXP EULA the first time; set `EULA=1` to accept it in a script.

To build a release rather than the branch tip, use `-b refs/tags/ezurio-<version>` with the same manifest file name.

The output is in `tmp/deploy/images/<machine>/`: `image-edgefirst-<machine>-<version>.swu`, `.wic.bz2` and `.wic.bmap`.

### Release Builds

A build without a release version is a development build named by build time, with an unsigned `.swu`. A release is built with:

```bash
EDGEFIRST_RELEASE=2026.10.0 EDGEFIRST_CERT_PATH=<EdgeFirst CA directory> \
    MACHINE=imx95-nitrogen-smarc . edgefirst-setup -b build-imx95
bitbake image-edgefirst
```

`EDGEFIRST_RELEASE` names the files and sets the version in `/etc/os-release`. `EDGEFIRST_CERT_PATH` holds the CA material: the root certificate in `root/`, and in `ezurio/` the vendor CA certificate, the signing certificate and its private key. With it set the `.swu` is signed and the image trusts the EdgeFirst root. Both variables are read each time `edgefirst-setup` runs, so set them again when re-entering the build directory.

[meta-edgefirst-ezurio](https://github.com/EdgeFirstAI/meta-edgefirst-ezurio) has `scripts/publish-release.sh` to upload a finished release to the repository.

## Other Notes

`edgefirst-profiler` is distributed under the EdgeFirst Profiler EULA, which the recipe records as its license.
