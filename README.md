# EdgeFirst Yocto — PHYTEC i.MX 95 (PD26.1)

EdgeFirst on PHYTEC i.MX 95 boards, built from PHYTEC's `BSP-Yocto-NXP-i.MX95-PD26.1.y` release line (NXP 6.18.20-2.0.0, Yocto wrynose) with [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) added.

This is the `edgefirst-phytec-imx95-PD26.1.y` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto). PHYTEC i.MX 8M Plus boards use `edgefirst-phytec-imx8mp-PD26.1.y`, and the `main` branch lists every supported branch.

## Supported Machines

| MACHINE | Board |
|---|---|
| `imx95-phyflex-libra-rdk-2` | phyBOARD-Libra with phyFLEX-i.MX 95 FPSC |

## Quick Start

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b edgefirst-phytec-imx95-PD26.1.y -m edgefirst-phytec-imx95-PD26.1.y.xml
repo sync
./tools/init                 # choose the machine; DISTRO ampliphy-vendor
source sources/oe-core/oe-init-build-env
bitbake phytec-headless-image
```

`tools/init` regenerates `build/conf/bblayers.conf` from the manifest, including meta-edgefirst, so do not add layers to it by hand. Its scripts run `python`; on hosts without one, put a `python` → `python3` link on `PATH` first, or it fails without reporting it. Set `ACCEPT_FSL_EULA = "1"` in `build/conf/local.conf` before building, and add EdgeFirst packages to the image there, for example:

```
IMAGE_INSTALL:append = " packagegroup-edgefirst"
```

PD26.1.y is PHYTEC's rolling maintenance line for this release; the manifest follows it and pins meta-edgefirst to a `main` commit. Flashing, boot switches, and board details follow PHYTEC's documentation: <https://phytec.github.io/doc-bsp-yocto/>.
