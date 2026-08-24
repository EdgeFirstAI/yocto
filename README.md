# EdgeFirst Yocto — Torizon

Torizon with EdgeFirst for Toradex SOMs: Toradex's Torizon OS (OSTree-based, container-first, walnascar release train) with the EdgeFirst Perception Foundation layer integrated — NPU driver/firmware enablement plus the low-level HAL/video-I/O/NPU-delegate stack — for the Verdin i.MX8M Plus and Verdin i.MX95 SoMs.

This is the `torizon` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto). The `main` branch covers the default NXP i.MX EVK/FRDM manifests for other platforms — this branch targets Torizon on Toradex SOMs specifically; the two don't share machines, images, or build tooling.

Three tiers make up the EdgeFirst-on-i.MX stack:

- **NPU drivers and firmware** — kernel-level only, unavoidably part of the OS.
- **EdgeFirst Perception Foundation** (`packagegroup-edgefirst`, a standalone recipe: `edgefirst-hal`, `videostream`, `videostream-cli`, plus the patched NPU delegates — `tim-vx`, `tflite-vx-delegate`, `tensorflow-lite-neutron-delegate`) — tightly coupled to the kernel driver, so it also belongs in the OS image. **This manifest installs driver/firmware plus this tier, and nothing above it** — `packagegroup-edgefirst-gstreamer`/`-zenoh`/`-python` are separate standalone recipes too, so installing Foundation doesn't build them.
- **Everything above Foundation** — GStreamer/NNStreamer ML pipelines (`packagegroup-edgefirst-gstreamer`, includes the EdgeFirst `nnstreamer` fork), Zenoh perception microservices (`packagegroup-edgefirst-zenoh`: `edgefirst-camera`, `edgefirst-model`, `edgefirst-fusion`, `edgefirst-imu`, `edgefirst-navsat`, `edgefirst-radarpub`, `edgefirst-lidarpub`, `edgefirst-recorder`, `edgefirst-replay`, `edgefirst-websrv`, `edgefirst-webui`), and future ROS 2 integration — designed to run as **Dockerized** application containers under Torizon's normal Docker Compose deployment model, not baked into this OS image.

Once Torizon Version 8 ships with native NPU driver/firmware integration, Dockerized EdgeFirst workloads should work out-of-the-box on stock Torizon without needing this manifest's Foundation layer at all — containers would bundle their own userspace and just need the host's native driver. Until then, this manifest provides driver/firmware plus Foundation so Dockerized perception workloads have something to build on today.

## Prerequisites

- [repo tool](https://gerrit.googlesource.com/git-repo/)
- Host packages for Yocto (see [Yocto Quick Start](https://docs.yoctoproject.org/brief-yoctoprojectqs/index.html))

## Quick Start

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b torizon -m edgefirst-torizon-walnascar.xml
repo sync

DISTRO=torizon MACHINE=verdin-imx8mp EULA=1 source setup-environment build-verdin-imx8mp
bitbake torizon-minimal
```

To re-enter the build environment in a new shell:

```bash
source setup-environment build-verdin-imx8mp
```

## Supported Machines

| MACHINE | Board |
|---------|-------|
| `verdin-imx8mp` | Verdin i.MX 8M Plus |
| `verdin-imx95` | Verdin i.MX 95 |

## Our Layers

### [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst)

EdgeFirst perception platform: HAL, camera/sensor services, GStreamer ML pipelines, NNStreamer examples, Zenoh infrastructure, and web UI. Pinned here to the `edgefirst-1.2.3` branch tip (walnascar-compatible; a superset of the `v1.2.3` tag that fixes a fetch-breaking SRCREV issue and splits `packagegroup-edgefirst` into standalone per-flavor recipes, so installing Foundation alone doesn't build the others).

### [meta-edgefirst-torizon](https://github.com/EdgeFirstAI/meta-edgefirst-torizon)

Torizon-specific hardware-enablement patches: retargets the Neutron NPU DMA-BUF kernel patch meta-edgefirst carries against NXP's raw `linux-imx` recipe onto Torizon's own `linux-toradex-imx` kernel fork, plus the Verdin i.MX95 NPU DMA reserved-memory pool size fix.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for release history.
