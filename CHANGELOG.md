# Changelog — EdgeFirst Yocto for PHYTEC i.MX 95

All notable user-visible changes to this branch are documented here. For per-package versions, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

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
