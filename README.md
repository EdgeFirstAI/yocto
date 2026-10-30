# EdgeFirst Yocto for Ezurio

EdgeFirst on Ezurio Nitrogen SMARC boards. The image is built from Ezurio's EZ BSP release 6.16.0.27 (tag `SUMMIT-REL-6.16.0.27`, NXP 6.12.49-2.2.0, Yocto 5.2 walnascar) with [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) and [meta-edgefirst-ezurio](https://github.com/EdgeFirstAI/meta-edgefirst-ezurio), and it installs and updates the way Ezurio's own images do: a `.wic.bz2` for flashing media and a signed `.swu` for `fw_update`.

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

## Relationship to Ezurio's EZ BSP

EdgeFirst Yocto for Ezurio is built on Ezurio's board support package, [EZ BSP](https://www.ezurio.com/software/ez-bsp), the Linux stack Ezurio ships on its SOMs. It is based on Ezurio's EZ BSP release 6.16.0.27, published in [Ezurio/EZ-BSP-Yocto-Release-Packages](https://github.com/Ezurio/EZ-BSP-Yocto-Release-Packages) as the tag `SUMMIT-REL-6.16.0.27`. Ezurio's tags, layers (`meta-summit-som`), distributions (`summitsom-wayland`) and the `-summit` kernel keep the Summit names, so those appear where this page names them; EdgeFirst's own names use EZ BSP.

Au-Zone Technologies provides this release as open source in support of the [EdgeFirst Model Zoo](https://huggingface.co/spaces/EdgeFirst/Models) and the [EdgeFirst Perception Index](https://www.au-zone.com/efpi-ezurio). It adds NPU and GPU enablement, backports, fixes and the EdgeFirst stack for the Nitrogen SMARC i.MX 8M Plus and i.MX 95. It is offered without support. Au-Zone offers commercial support through its Commercial Support and Professional Services.

### What is the same

| EZ BSP | EdgeFirst Yocto for Ezurio |
|---|---|
| Built on NXP's BSP | The same NXP 6.12.49-2.2.0 base, Yocto 5.2 walnascar and Ezurio kernel `6.12.49-summit` |
| Open source Yocto build assembled with `repo` | The same `repo` workflow, with one manifest branch on top of Ezurio's release tag |
| Ezurio's bootloader, partitioning and image classes | Used as released; the image inherits Ezurio's image, SD and SWU classes and builds through Ezurio's `setup-environment-nxp` |
| Read-only dm-verity root filesystem, A/B slots and a `/rw` overlay | The same layout |
| SWUpdate with `fw_update` and signed packages | The same engine and tool, which install the update on the device |
| Ezurio connectivity stack | Included: the Summit supplicant, NetworkManager, hostapd and Bluetooth packages |
| SBOM generation | Each image build writes an SPDX file |

### What is different

| Area | EZ BSP | EdgeFirst Yocto for Ezurio |
|---|---|---|
| Update trust | Ezurio's signing, with customer keys in the secure variants | Trusts only the EdgeFirst root. An Ezurio image does not accept an EdgeFirst `.swu`, and an EdgeFirst image does not accept an Ezurio one. |
| Secure boot | The `-secure` distributions add signed boot, OP-TEE and a read-only root without the overlay | Not used. The image is built on the `summitsom-wayland` distribution, so secure boot is not enabled. |
| Build systems | Yocto or Buildroot | Yocto only |
| Contents | A general-purpose Linux | The EdgeFirst edge AI runtime, with no GStreamer, Python or ONNX |
| Kernel | Ezurio's kernel as released | Ezurio's kernel plus device tree changes that enable the GPU and NPU, the Neutron mailbox handshake backport that the 3.2.x firmware needs, and a VGEM render node on the i.MX 95 for headless GPU use |
| Versioning | Ezurio's own releases, with security releases outside the normal cycle | `YYYY.MM.PATCH`, with the Ezurio BSP version shown beside it in `/etc/os-release` |
| Support | Provided by Ezurio | None with the open source release. Commercial support is available from Au-Zone. |
| Delivery | From Ezurio | Published at `https://repo.edgefirst.ai/ezurio/` |

An EdgeFirst release is a separate release line. Ezurio's packages and signing keys do not update it, and it does not take part in Ezurio's secure boot chain.

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

The boot console shows which bootloader started. An SD card image starts Ezurio's U-Boot 2025.10 and boots the image. A module that has never been programmed still carries Ezurio's stock U-Boot 2022.04 in its eMMC; it finds no partition table on the eMMC, and does not boot an SD card image. That means the boot mode switches are selecting the eMMC. A module that prints nothing at all is waiting in serial download mode.

An i.MX 8M Plus module on the Nitrogen95 evaluation kit carrier is not a combination Ezurio documents, but it works. On the unit tested, the module booted the SD card with switch 3 of the carrier boot mode switch block S1 on, and the documented Nitrogen95 and Nitrogen8M Plus switch tables did not agree with what the board did, so confirm the bootloader banner on the console rather than relying on the switch tables alone.

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

## Displays and Cameras

Ezurio enables displays, cameras, radios and other carrier hardware with device tree overlays that the `set-mode` tool chooses. The kernel boots the base device tree, so a board with no overlay chosen has no display and no camera, and Weston does not start without a display. Run `set-mode` with no arguments to list the overlays for your board, and `set-mode status` to show the ones in use. `set-mode <overlay> [<overlay> ...]` sets the exact list and reboots the board; the setting is kept in the bootloader environment.

```bash
set-mode dsi0-7
```

Ezurio documents the overlays in the First Boot Hardware Configuration section of the [EZ BSP User Guide](https://www.ezurio.com/documentation/user-guide-ez-bsp?product=nitrogen95), and the connectors for each carrier in the [Nitrogen95 SMARC](https://www.ezurio.com/documentation/user-guide-nitrogen95-smarc) and [Nitrogen8M Plus SMARC](https://www.ezurio.com/documentation/user-guide-nitrogen8m-plus-smarc-som) user guides.

| Board | Display | Overlay |
|---|---|---|
| Nitrogen95 evaluation kit | The 7 inch MIPI-DSI touch display from the kit | `dsi0-7` |
| Nitrogen8M Plus on the standard carrier | An HDMI monitor | `hdmi` |
| Nitrogen8M Plus module on the Nitrogen95 evaluation kit carrier | The 7 inch MIPI-DSI touch display from the kit | `dsi0-7` |

All three combinations were checked on hardware with this image: Weston starts on the display and uses the G2D renderer. Ezurio does not document the Nitrogen8M Plus module on the Nitrogen95 kit carrier, but its `dsi0-7` overlay drives the kit's display. Other panels use the `dsi0-10`, `lvds0-7`, `lvds0-10`, `lvds1-7` and `lvds1-10` overlays. On the Nitrogen95 module, LVDS0 is disabled unless 0 ohm resistors are moved, so check the user guide for your hardware before choosing an LVDS overlay.

Cameras use the `csi0-` and `csi1-` overlays for the port the camera is connected to: `ov5640`, `ov5645` or `pivariety`, which is the overlay for Arducam Pivariety cameras. The Arducam Pivariety driver is installed on both machines. Set the display and camera overlays in one command, because `set-mode` replaces the whole list:

```bash
set-mode dsi0-7 csi0-pivariety
```

The Arducam xISP camera was checked on `csi0-pivariety` on both machines. Each streams 1280x720 at 90 frames per second through `v4l2-ctl`.

| Board | Capture node | Notes |
|---|---|---|
| Nitrogen95 kit | `/dev/video0` | Also works through libcamera's `cam`; the NEO ISP path is not tested |
| Nitrogen8M Plus | `/dev/video3` | V4L2 only; the ISI capture node offers `YUYV`, `NV12`, `RGB3`, `BGR3` and other formats |

libcamera in this image has a pipeline for the i.MX 95 only. The i.MX 8M Plus camera is used through V4L2 until the Camera SDK, which supports both the V4L2 and libcamera APIs, is adopted, so applications that require libcamera, such as the `yolov8_live` example, do not run on the i.MX 8M Plus.

The xISP in the camera runs its own auto exposure and auto white balance, and the first 10 to 20 frames after streaming starts are dark and green. Discard them, or wait before capturing, rather than treating a green first frame as a colour format problem.

The i.MX 95 needs a kernel patch that is part of this image, which enables the device tree links of the CSI-2 receiver. Without it, enabling the sensor link returns `EBUSY` and streaming fails with `EPIPE`. The i.MX 8M Plus uses a different CSI-2 receiver and does not need it.

On the i.MX 95, the `yolov8_live` example from `tflite-rs` runs the YOLOv8n detection model from [EdgeFirst/yolov8-det](https://huggingface.co/EdgeFirst/yolov8-det) on the Neutron NPU with camera frames shared with the NPU through DMA-BUF, at about 74 frames per second end to end with about 13 ms of inference time.

The Arducam documentation for Ezurio boards is at [MIPI xISP Camera for Ezurio](https://docs.arducam.com/Ezurio-Camera/MIPI-xISP-Camera-for-Ezurio/); use `set-mode` rather than the U-Boot `fdt_file` step it describes.

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
EDGEFIRST_VERSION=2026.10.0 EDGEFIRST_CERT_PATH=<EdgeFirst CA directory> \
    MACHINE=imx95-nitrogen-smarc . edgefirst-setup -b build-imx95
bitbake image-edgefirst
```

`EDGEFIRST_VERSION` names the files and is recorded in `/etc/os-release` (`YYYY.MM.PATCH~rcN` is a release candidate, `-rcN` in file names). `EDGEFIRST_CERT_PATH` holds the CA material: the root certificate in `root/`, and in `ezurio/` the vendor CA certificate, the signing certificate and its private key. With it set the `.swu` is signed and the image trusts the EdgeFirst root. Both variables are read each time `edgefirst-setup` runs, so set them again when re-entering the build directory.

A release is named `YYYY.MM` and published quarterly, and each update to it is a new `PATCH`, so a board runs `YYYY.MM.PATCH`. The Ezurio BSP it is built on keeps its own version and is shown alongside:

```bash
$ grep -E '^(PRETTY_NAME|EDGEFIRST)' /etc/os-release
PRETTY_NAME="EdgeFirst Yocto 2026.10.0 for Ezurio EZ BSP 6.16.0.27"
EDGEFIRST_RELEASE="2026.10"
EDGEFIRST_VERSION="2026.10.0"
EDGEFIRST_BSP="ez-6.16.0.27"
```

[meta-edgefirst-ezurio](https://github.com/EdgeFirstAI/meta-edgefirst-ezurio) has `scripts/publish-release.sh` to upload a finished release to the repository.

## Other Notes

`edgefirst-profiler` is distributed under the EdgeFirst Profiler EULA, which the recipe records as its license.
