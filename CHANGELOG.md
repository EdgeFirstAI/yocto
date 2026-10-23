# Changelog — EdgeFirst Yocto for PHYTEC i.MX 95

All notable user-visible changes to this branch are documented here. For per-package versions, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

### Kinara Ara-2

- The Kinara Ara-2 accelerator runtime is on the image, NXP's `rt-sdk-ara2` 2.1.1 from meta-imx-ml, which is the packaging running on EdgeFirst i.MX 95 reference hardware. `meta-kinara` is new to the manifest and supplies the fixes NXP's recipe needs: the `libaraclient.so.1` soname and the legacy `dvapi.h` headers that the EdgeFirst bindings resolve but the runtime does not ship.
- The runtime's GStreamer plugin is packaged separately, so installing the runtime does not pull a GStreamer stack into the image.
- The runtime starts only when an accelerator is attached, through the udev rules NXP ships with it, so a board with no card fitted never runs it.
- `edgefirst-ara2` provides the Python API, and works with either runtime packaging.
- Not tested on PHYTEC hardware: no Ara240 is fitted to either EdgeFirst PHYTEC board. Detection and service activation are verified on the EdgeFirst NXP reference boards, which do have one.

## [2026.10.0-rc3] - 2026-10-23

Camera and display support, so a board can run the camera and show graphics on the panel.

### Camera

- The camera runs through the NEO ISP. libcamera offers processed frames — NV12, NV21, NV16, YUYV, UYVY, RGB888 and BGR888 at 1920x1200 — and loads the tuning file for the sensor behind the module, where previously it delivered raw Bayer from the sensor interface with the ISP bypassed.
- No camera is enabled out of the box, because which phyCAM module is fitted and which CSI port it is wired to differ per board. Enabling one is a line in `/boot/overlays.txt`; the layer README covers the format and points at PHYTEC's overlay and video documentation for the other modules. An edit there is replaced by the next update, since the boot partition is part of the update.
- Verified on a phyFLEX-i.MX 95 Libra with a VM-020 phyCAM-L on CSI1 through the FPD-Link deserializer, capturing 1920x1200 continuously.
- V4L2 capture tooling is on the image: `v4l-utils`, `media-ctl`, `yavta`.

### Display

- The panel shows a boot splash.
- Wayland with the Weston compositor is on the image and drives the LVDS panel. Weston starts on demand when a client connects, so it is idle until something draws. Clients can render through DMA-BUF and EGL without a copy.

### Packages

- `edgefirst-client` 2.19.0, from 2.17.0.

## [2026.10.0-rc2] - 2026-10-23

First release candidate for PHYTEC i.MX 95. It carries the same EdgeFirst stack as the 2026.10.0-rc2 candidates for Torizon and Ezurio.

### Packages

- EdgeFirst Studio on the board: `edgefirst-client` 2.17.0 and `edgefirst-profiler` 1.19.0, on `edgefirst-hal` 0.28.3.
- NPU runtime: TensorFlow Lite 2.19.0 with the Neutron delegate, against eIQ Neutron SDK 3.2.3.
- Camera: `libcamera` 0.7.1.imx with the NEO ISP IPA, PHYTEC's phyCAM tooling and the dewarp configuration for the phyCAM modules this board family accepts.
- `videostream` 2.6.1 carries frames between components over DMA-BUF.

### Images

- The image carries the EdgeFirst capability sets for the NPU, graphics, video codecs, camera, EdgeFirst Studio and diagnostics, installed by default into `phytec-headless-image`. It no longer includes GStreamer: EdgeFirst reaches the camera through V4L2 and libcamera and the video encoder and decoder through the V4L2 memory-to-memory API, with 366 fewer packages and a smaller update bundle (369 MB to 329 MB).
- `packagegroup-edgefirst-gstreamer` is the single opt-in switch for anyone who does want a GStreamer stack.

### NPU

- The Neutron NPU runs eIQ Neutron SDK 3.2.3, which YOLO11 and YOLO26 models need for accuracy. The kernel gains the matching Neutron mailbox handshake, so the kernel and the 3.2.x firmware must be used together; they are installed together in the image and share a RAUC slot, so they roll back together.
- The 3.2.3 driver, firmware and compiler have to come from one SDK version or the firmware reports a microcode version mismatch. The compiler side lives in EdgeFirst Studio, which selects a version to match the target.

### Updates

- RAUC bundles are signed with an EdgeFirst CA instead of the PHYTEC development CA.
- A board keeps the same DHCP lease across A/B slot switches.
- Installing a bundle does not use RAUC's adaptive block-hash-index on this board, because reading the target slot while writing it wedges the eMMC controller. A full slot write is used instead.

### Platform

- New branch for PHYTEC's PD26.1.y release (NXP 6.18.20-2.0.0, Yocto 5.4 wrynose) on `imx95-phyflex-libra-rdk-2`. The README explains why i.MX 95 and i.MX 8M Plus use separate branches.
