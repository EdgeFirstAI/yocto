# Changelog — EdgeFirst Yocto for PHYTEC i.MX 95

All notable user-visible changes to this branch are documented here. For per-package versions, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

### Images

- The image carries the EdgeFirst capability sets for the NPU, graphics, video codecs, camera, EdgeFirst Studio and diagnostics, installed by default into `phytec-headless-image`. It no longer includes GStreamer: EdgeFirst reaches the camera through V4L2 and the video encoder and decoder through the V4L2 memory-to-memory API, with 366 fewer packages and a smaller update bundle (369 MB to 329 MB).

### NPU

- The Neutron NPU runs eIQ Neutron SDK 3.2.3, which YOLO11 and YOLO26 models need for accuracy. The kernel gains the matching Neutron mailbox handshake, so the kernel and the 3.2.x firmware must be used together; they are installed together in the image.

### Updates

- RAUC bundles are signed with an EdgeFirst CA instead of the PHYTEC development CA.
- A board keeps the same DHCP lease across A/B slot switches.

### Platform

- New branch for PHYTEC's PD26.1.y release (NXP 6.18.20-2.0.0, Yocto 5.4 wrynose) on `imx95-phyflex-libra-rdk-2`. The README explains why i.MX 95 and i.MX 8M Plus use separate branches.
