# Changelog — EdgeFirst Yocto for PHYTEC i.MX 8M Plus

All notable user-visible changes to this branch are documented here. For per-package versions, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

### Images

- The image carries the EdgeFirst capability sets for the NPU, graphics, video codecs, camera, EdgeFirst Studio and diagnostics, installed by default into `phytec-headless-image`. It no longer includes GStreamer: EdgeFirst reaches the camera through V4L2 and the video encoder and decoder through the V4L2 memory-to-memory API, with 103 fewer packages.

### NPU

- Compiling a model from several threads at the same time no longer fails on the Vivante NPU.

### Updates

- RAUC bundles are signed with an EdgeFirst CA instead of the PHYTEC development CA.
- A board keeps the same DHCP lease across A/B slot switches.

### Platform

- New branch for PHYTEC's PD26.1.y release (NXP 6.12.49-2.2.0, Yocto 5.2 walnascar) on `phyboard-pollux-imx8mp-3` and `imx8mp-phyflex-libra-rdk-2`. The README explains why i.MX 8M Plus and i.MX 95 use separate branches.
