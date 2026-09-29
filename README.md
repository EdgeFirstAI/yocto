# EdgeFirst Yocto — PHYTEC i.MX 8M Plus (PD26.1)

EdgeFirst on PHYTEC i.MX 8M Plus boards, built from PHYTEC's `BSP-Yocto-NXP-i.MX8MP-PD26.1.y` release line (NXP 6.12.49-2.2.0, Yocto walnascar) with [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) added.

This is the `edgefirst-phytec-imx8mp-PD26.1.y` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto). PHYTEC i.MX 95 boards use `edgefirst-phytec-imx95-PD26.1.y`, and the `main` branch lists every supported branch.

## Supported Machines

| MACHINE | Board |
|---|---|
| `phyboard-pollux-imx8mp-3` | phyBOARD-Pollux with phyCORE-i.MX 8M Plus |
| `imx8mp-phyflex-libra-rdk-2` | phyBOARD-Libra with phyFLEX-i.MX 8M Plus FPSC |
| `imx8mp-phyflex-phyvip-1` | phyFLEX-i.MX 8M Plus on phyVIP (listed by PHYTEC; not yet built with EdgeFirst) |

These boards stay on PHYTEC's i.MX 8M Plus release line. PHYTEC's newer i.MX 95 line (wrynose) still carries i.MX 8M Plus machines, but their kernel, U-Boot, and boot-image recipes have not been ported to it, and PHYTEC does not list them as supported there.

## Quick Start

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b edgefirst-phytec-imx8mp-PD26.1.y -m edgefirst-phytec-imx8mp-PD26.1.y.xml
repo sync
./tools/init                 # choose the machine; DISTRO ampliphy-vendor
source sources/poky/oe-init-build-env
bitbake phytec-headless-image
```

`tools/init` regenerates `build/conf/bblayers.conf` from the manifest, including meta-edgefirst, so do not add layers to it by hand. Its scripts run `python`; on hosts without one, put a `python` → `python3` link on `PATH` first, or it fails without reporting it. Set `ACCEPT_FSL_EULA = "1"` in `build/conf/local.conf` before building, and add EdgeFirst packages to the image there, for example:

```
IMAGE_INSTALL:append = " packagegroup-edgefirst"
```

Walnascar's pseudo cannot handle host `tar` 1.35 (Ubuntu 24.04), which uses `openat2()`; meta-edgefirst moves pseudo to 1.9.8 on walnascar, so no extra host-fix layer is needed.

PD26.1.y is PHYTEC's rolling maintenance line for this release; the manifest follows it and pins meta-edgefirst to a `main` commit. Flashing, boot switches, and board details follow PHYTEC's documentation: <https://phytec.github.io/doc-bsp-yocto/>.
