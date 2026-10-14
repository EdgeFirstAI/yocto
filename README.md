# EdgeFirst Yocto — PHYTEC i.MX 95 (PD26.1)

EdgeFirst on PHYTEC i.MX 95 boards, built from PHYTEC's `BSP-Yocto-NXP-i.MX95-PD26.1.y` release line (NXP 6.18.20-2.0.0, Yocto 6.0 wrynose) with [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) added.

This is the `edgefirst-phytec-imx95-PD26.1.y` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto). PHYTEC i.MX 8M Plus boards use `edgefirst-phytec-imx8mp-PD26.1.y`, and the `main` branch lists every supported branch.

## Supported Machines

| MACHINE | Board |
|---|---|
| `imx95-phyflex-libra-rdk-2` | phyBOARD-Libra with phyFLEX-i.MX 95 FPSC |

## Release lines — one branch per SoC

PHYTEC publishes the PD26.1.y release against **two different Yocto releases**, and the SoC decides which one applies:

| SoC | Yocto | PHYTEC manifest | Branch |
|---|---|---|---|
| i.MX 8M Plus | walnascar (5.2.4) | `BSP-Yocto-NXP-i.MX8MP-PD26.1.y` | [`edgefirst-phytec-imx8mp-PD26.1.y`](https://github.com/EdgeFirstAI/yocto/tree/edgefirst-phytec-imx8mp-PD26.1.y) |
| i.MX 95 | wrynose (6.0) | `BSP-Yocto-NXP-i.MX95-PD26.1.y` | [`edgefirst-phytec-imx95-PD26.1.y`](https://github.com/EdgeFirstAI/yocto/tree/edgefirst-phytec-imx95-PD26.1.y) |

There is no single Yocto version that tracks PD26.1.y — use the branch for your SoC. Because the two lines differ in directory layout (walnascar has a combined `poky`, wrynose splits `oe-core` and `meta-yocto`), **build each line in its own workspace** rather than switching one tree between branches.

Both lines ship all of PHYTEC's i.MX 8M Plus and i.MX 95 machine configs, but **a machine config existing is not a support claim.** wrynose carries the i.MX 8M Plus machines while their kernel, U-Boot, and boot-image recipes are unported, so those builds fail late — `perf`, `u-boot-phytec-imx:do_deploy`, and `imx-boot-phytec`.

**The split is temporary, with a specific end condition:** it holds because PHYTEC has not ported the i.MX 8M Plus kernel, U-Boot, and boot-image recipes to its wrynose line and does not list those machines as supported there. When PHYTEC ships them, the i.MX 8M Plus branch can move to wrynose and the two branches may merge. Until a PHYTEC release note says otherwise, assume the split still applies.

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
