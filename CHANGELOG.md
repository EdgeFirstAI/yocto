# Changelog — EdgeFirst Yocto Torizon

All notable changes to the `torizon` branch of EdgeFirstAI/yocto are documented here.
Package version tables live in the [meta-edgefirst changelog](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## Unreleased

### Branch

- The branch is now an independent history that holds only the Torizon manifest and its tooling, matching the other vendor branches of this repository.
  It no longer shares files with the NXP flavour.

### Manifest

- `meta-edgefirst` is tracked from `main` (`4ef7c73`) instead of the `edgefirst-1.2.3` branch.
  This brings the Neutron NPU runtime to eIQ Neutron SDK 3.2.3, `edgefirst-client` 2.17.0, `edgefirst-profiler` 1.19.0 and edgefirst-hal 0.28.3.
- `meta-edgefirst-torizon` is tracked from `main` (`0e23d0e`).
- The Torizon walnascar projects keep the revisions from Toradex's Torizon OS 7.0.0 walnascar manifest.

### Layers

- `meta-edgefirst-torizon` is rebased onto `meta-edgefirst` `main`.
  It reuses the Neutron dma-buf kernel patches from `meta-edgefirst` instead of carrying copies, and drops the pseudo 1.9.8 override and the `tensorflow-lite-neutron-delegate` bbappend, which `meta-edgefirst` now provides.
- `packagegroup-edgefirst-torizon` composes `packagegroup-edgefirst`, `packagegroup-edgefirst-npu` and `packagegroup-edgefirst-studio` and is installed into the new `torizon-edgefirst` image.
  The images no longer install `packagegroup-fsl-ml`, so `nnstreamer`, `tvm` and the other i.MX machine-learning packages are gone; the TensorFlow Lite delegates remain.
- The VX and Neutron TensorFlow Lite delegates build from the rolling `edgefirst` branches of `tflite-vx-delegate-imx` (`6f8189f`) and `tflite-neutron-delegate` (`dd81103`) on every Yocto series, selected by `meta-edgefirst` itself.
  This brings in the galcore dma-buf leak fix and the camera adaptor changes.
- `torizon-edgefirst` is the EdgeFirst image.
  It requires Toradex's `torizon-docker` recipe, or `torizon-minimal` when `EDGEFIRST_TORIZON_BASE = "minimal"` is set in `local.conf`, and publishes the OSTree branch `0/<machine>/torizon/edgefirst/<purpose>` with `develop`, `testing` or `release` as the purpose.
  The stock `torizon-docker` and `torizon-minimal` images are no longer modified.
  The TEZI and deploy artifacts are named `torizon-edgefirst-<machine>`.
- The Verdin i.MX 8M Plus VSI NPU stack is NXP's Vivante 6.4.11.p4.2 release (`imx-gpu-viv`, `libnn-imx`, `libopenvx-imx`, `imx-gpu-g2d` and the `galcore` module) instead of the p3.2 release that `meta-freescale` provides.
  The layer carries the recipes from `meta-imx-bsp` and registers the NXP Software License v63 checksum they need.
- The Verdin i.MX 95 Neutron kernel driver is brought level with NXP's L6.12.49-2.2.0 and eIQ Neutron SDK 3.2.x: interrupt-driven inference, the `send_reset` mutex, removal of the SRC register read-back, the 3.2.x mailbox handshake and a fix for a boot-time remoteproc lookup race.
  Without the handshake the 3.2.x firmware reply `0xA1` made every inference take the failed-reset path.
- The Verdin i.MX 95 Neutron NPU `/reserved-memory/npu-dma` pool grows from 128 MiB to 512 MiB through the `verdin-imx95_efpi-npu-dma-512m_overlay.dtbo` devicetree overlay, which is built from the layer and listed in `overlays.txt`.
  The disabled kernel patch that targeted the same pool is removed.
- The kernel revision pins, the `ara2` removals, the profiler overrides and the `sota` image-install removals move from `local.conf` into `meta-edgefirst-torizon/conf/layer.conf`.

### Documentation

- The agent instructions carry a pre-publish checklist that covers the initramfs size, the account list in `/usr/lib/passwd`, the installed EdgeFirst packages and the rule against retrying a failed build in place.

### Tooling

- `setup-edgefirst` replaces the manual `setup-environment` invocation.
  It defaults `DISTRO` and `EULA`, adds the EdgeFirst layers to `bblayers.conf`, and writes the `BBMASK` entries `meta-edgefirst` needs, so a build directory needs no hand-edited configuration.
- `publish-repo.sh` signs published OSTree commits and the repository summary with a GPG key when `OSTREE_GPG_KEY` is set (with `OSTREE_GPG_HOMEDIR` and `OSTREE_SIGN_BIN` for the key location and a gpgme-enabled `ostree`), and `--sign-only` signs every commit already in the staging repository.
  Yocto's `ostree-native` is built without gpgme, so the signing steps run through the host `ostree`.
- `publish-repo.sh` honours `OSTREE_S3_PREFIX` (default `ostree`) as the S3 key prefix for the published repository.
