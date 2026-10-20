# EdgeFirst Yocto — Torizon

Torizon OS for Toradex Verdin i.MX 8M Plus and i.MX 95 with the EdgeFirst Perception Foundation built in.
This is the `torizon` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto).
Each vendor branch in that repository is independent and carries only the repo manifests for its own builds, so nothing here is shared with the other branches.

This branch is **Torizon with EdgeFirst**, one of the EdgeFirst Yocto products. Releases are versioned `YYYY.MM.PATCH` (for example `2026.10.0`), and a published release is never changed; a fix is the next `PATCH`. All the branches share one set of NPU, GPU, camera and vision-pipeline enablement through [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst), which is kept current by re-pinning every branch together, and the NXP boards are the reference platform where each new NXP BSP is adopted first.

The manifest tracks Toradex's Torizon OS 7 on the walnascar (Yocto 5.2) release train and adds two layers:

- [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst), the generic EdgeFirst layer shared by every platform.
- [meta-edgefirst-torizon](https://github.com/EdgeFirstAI/meta-edgefirst-torizon), the Torizon-specific vendor layer.

## What is in the image

The Foundation tier, and nothing above it:

- NPU enablement: the Vivante VX stack on i.MX 8M Plus, and the eIQ Neutron driver and firmware on i.MX 95 (including the dma-buf kernel patches).
- The TensorFlow Lite delegates: `tensorflow-lite-vx-delegate` and `tensorflow-lite-neutron-delegate`.
- EdgeFirst HAL and VideoStream, `edgefirst-client` and `edgefirst-profiler`.

GStreamer pipelines, Zenoh services and ROS 2 integration run as containers on top of Torizon rather than inside the OS image.

## Prerequisites

- [repo tool](https://gerrit.googlesource.com/git-repo/)
- Host packages for Yocto (see the [Yocto Quick Start](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html))

## Quick Start

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git -b torizon -m edgefirst-torizon-walnascar.xml
repo sync

MACHINE=verdin-imx8mp source setup-edgefirst build-verdin-imx8mp
bitbake torizon-edgefirst
```

`setup-edgefirst` runs Toradex's `setup-environment` with `DISTRO=torizon` and `EULA=1`, then adds the two EdgeFirst layers to `conf/bblayers.conf`.
Source it again in any new shell to re-enter the build environment.

## Supported Machines

| MACHINE | Board |
|---------|-------|
| `verdin-imx8mp` | Verdin i.MX 8M Plus |
| `verdin-imx95` | Verdin i.MX 95 |

## Images

`torizon-edgefirst` is Toradex's `torizon-docker` plus `packagegroup-edgefirst-torizon`.
Set `EDGEFIRST_TORIZON_BASE = "minimal"` in `local.conf` to extend `torizon-minimal` instead.
Its OSTree branch is `0/<machine>/torizon/edgefirst/<develop|testing|release>`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
