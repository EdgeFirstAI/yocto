# Changelog — EdgeFirst Yocto for PHYTEC i.MX 8M Plus

All notable user-visible changes to this branch are documented here. For per-package versions, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

- meta-kinara moves to the revision carrying the NXP Ara-2 proxy fix. The change applies to NXP's `rt-sdk-ara2` packaging only, which this line does not use, so the images are unaffected.

## [2026.10.0-rc4] - 2026-10-24

Kinara Ara-2 accelerator support.

- The Ara-2 runtime is on the image, in the Kinara SDK packaging (`imx-nxp-ara2` 1.2.1). `meta-kinara` is new to the manifest and also carries NXP's own 2.1.1 recipes, selected with `PREFERRED_VERSION_imx-nxp-ara2 = "2.1.1"` for a build without access to the Kinara SDK mirror.
- The runtime starts only when an accelerator is attached. A udev rule matching the PCIe vendor `0x1e58` and the USB vendor `318d` starts the proxy, so a board with no card fitted never runs it and a board with one needs no configuration.
- `edgefirst-ara2` provides the Python API, and works with either runtime packaging.

## [2026.10.0-rc3] - 2026-10-23

Camera and display support, so a board can run a camera and show graphics on the panel.

### Camera

- No camera is enabled out of the box, because which phyCAM module is fitted and which CSI port it is wired to differ per board. Enabling one is a line in `/boot/overlays.txt`; the layer README covers the format and points at PHYTEC's overlay and video documentation for the modules. An edit there is replaced by the next update, since the boot partition is part of the update.
- Cameras are reached through V4L2, with `v4l-utils`, `media-ctl` and `yavta` on the image. libcamera and ISP processing are i.MX 95 only; this SoC has no NEO ISP.

### Display

- The panel shows a boot splash.
- Wayland with the Weston compositor is on the image and drives the LVDS panel. Weston starts on demand when a client connects, so it is idle until something draws. Clients can render through DMA-BUF and EGL without a copy.

### Packages

- `edgefirst-client` 2.19.0, from 2.17.0.

## [2026.10.0-rc2] - 2026-10-23

First release candidate for PHYTEC i.MX 8M Plus. It carries the same EdgeFirst stack as the 2026.10.0-rc2 candidates for Torizon and Ezurio.

### Packages

- EdgeFirst Studio on the board: `edgefirst-client` 2.17.0 and `edgefirst-profiler` 1.19.0, on `edgefirst-hal` 0.28.3.
- NPU runtime: TensorFlow Lite 2.19.0 with the Vivante VX delegate.
- `videostream` 2.6.1 carries frames between components over DMA-BUF.

### Images

- The image carries the EdgeFirst capability sets for the NPU, graphics, video codecs, EdgeFirst Studio and diagnostics, installed by default into `phytec-headless-image`. It no longer includes GStreamer: EdgeFirst reaches the video encoder and decoder through the V4L2 memory-to-memory API, with 103 fewer packages.
- The i.MX 8M Plus line ships no EdgeFirst camera stack yet; the i.MX 95 line does. PHYTEC's own phyCAM kernel modules and camera tooling are present as before.
- `packagegroup-edgefirst-gstreamer` is the single opt-in switch for a GStreamer stack, and on this line it does not build: `edgefirst-gstreamer` 0.4.0 does not compile against `edgefirst-hal` 0.28.3. The switch is i.MX 95 only until that is fixed upstream.

### NPU

- Compiling a model from several threads at the same time no longer fails on the Vivante NPU.
- Whole-graph delegation to the Vivante NPU is verified on `imx8mp-phyflex-libra-rdk-2` at roughly 3.5 ms, against 44.7 ms on four CPU threads, for `mobilenet_v1_1.0_224_quant`. The first inference after a model loads takes about 3.3 s because the delegate compiles the graph.

### Updates

- RAUC bundles are signed with an EdgeFirst CA instead of the PHYTEC development CA.
- A board keeps the same DHCP lease across A/B slot switches.

### Platform

- New branch for PHYTEC's PD26.1.y release (NXP 6.12.49-2.2.0, Yocto 5.2 walnascar) on `phyboard-pollux-imx8mp-3` and `imx8mp-phyflex-libra-rdk-2`. The README explains why i.MX 8M Plus and i.MX 95 use separate branches.
