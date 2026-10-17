# Changelog — EdgeFirst Yocto Torizon

All notable changes to the `torizon` branch of EdgeFirstAI/yocto are documented here.
Package version tables live in the [meta-edgefirst changelog](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## Unreleased

### Branch

- The branch is now an independent history that holds only the Torizon manifest and its tooling, matching the other vendor branches of this repository.
  It no longer shares files with the NXP flavour.

### Manifest

- `meta-edgefirst` is tracked from `main` (`c9491ea`) instead of the `edgefirst-1.2.3` branch.
  This brings the Neutron NPU runtime to eIQ Neutron SDK 3.2.3, `edgefirst-client` 2.17.0, `edgefirst-profiler` 1.19.0 and edgefirst-hal 0.28.3.
- `meta-edgefirst-torizon` is tracked from `main` (`aeec65a`).
- The Torizon walnascar projects keep the revisions from Toradex's Torizon OS 7.0.0 walnascar manifest.

### Layers

- `meta-edgefirst-torizon` is rebased onto `meta-edgefirst` `main`.
  It reuses the Neutron dma-buf kernel patches from `meta-edgefirst` instead of carrying copies, and drops the pseudo 1.9.8 override and the `tensorflow-lite-neutron-delegate` bbappend, which `meta-edgefirst` now provides.
- `packagegroup-edgefirst-torizon` composes `packagegroup-edgefirst`, `packagegroup-edgefirst-npu` and `packagegroup-edgefirst-studio` and is installed into `torizon-minimal` and `torizon-docker`.
  The images no longer install `packagegroup-fsl-ml`, so `nnstreamer`, `tvm` and the other i.MX machine-learning packages are gone; the TensorFlow Lite delegates remain.
- The VX and Neutron TensorFlow Lite delegates build from the rolling `edgefirst` branches of `tflite-vx-delegate-imx` (`6f8189f`) and `tflite-neutron-delegate` (`dd81103`) instead of the frozen `edgefirst-1.2.3` branches that `meta-edgefirst` selects for walnascar.
  This brings in the galcore dma-buf leak fix and the camera adaptor changes.
- The Verdin i.MX 95 Neutron NPU `/reserved-memory/npu-dma` pool grows from 128 MiB to 512 MiB through the `verdin-imx95_efpi-npu-dma-512m_overlay.dtbo` devicetree overlay, which is built from the layer and listed in `overlays.txt`.
  The disabled kernel patch that targeted the same pool is removed.
- The kernel revision pins, the `ara2` removals, the profiler overrides and the `sota` image-install removals move from `local.conf` into `meta-edgefirst-torizon/conf/layer.conf`.

### Documentation

- The agent instructions carry a pre-publish checklist that covers the initramfs size, the account list in `/usr/lib/passwd`, the installed EdgeFirst packages and the rule against retrying a failed build in place.

### Tooling

- `setup-edgefirst` replaces the manual `setup-environment` invocation.
  It defaults `DISTRO` and `EULA`, adds the EdgeFirst layers to `bblayers.conf`, and writes the `BBMASK` entries `meta-edgefirst` needs, so a build directory needs no hand-edited configuration.
- `publish-repo.sh` honours `OSTREE_S3_PREFIX` (default `ostree`) as the S3 key prefix for the published repository.
