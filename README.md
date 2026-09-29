# EdgeFirst Yocto

Yocto manifests for building EdgeFirst embedded Linux images on i.MX-based platforms. Each supported platform and BSP lives on its own branch, with its own manifest, setup script, and documentation. This `main` branch only lists them.

## Supported Branches

| Branch | Platform | BSP | SoCs and notes |
|---|---|---|---|
| [`edgefirst-imx-6.18.20-2.0.0`](https://github.com/EdgeFirstAI/yocto/tree/edgefirst-imx-6.18.20-2.0.0) | NXP i.MX EVK and FRDM boards | NXP 6.18.20-2.0.0 (Yocto 5.4 wrynose) | i.MX 95; i.MX 8M Plus without the Ara-2 NPU |
| [`edgefirst-imx-6.12.49-2.2.0`](https://github.com/EdgeFirstAI/yocto/tree/edgefirst-imx-6.12.49-2.2.0) | NXP i.MX EVK and FRDM boards | NXP 6.12.49-2.2.0 (Yocto 5.2 walnascar) | i.MX 8M Plus with the Ara-2 NPU |
| [`torizon`](https://github.com/EdgeFirstAI/yocto/tree/torizon) | Toradex Verdin SoMs | Torizon OS (walnascar) | Verdin i.MX 8M Plus, Verdin i.MX 95 |
| [`edgefirst-phytec-imx95-PD26.1.y`](https://github.com/EdgeFirstAI/yocto/tree/edgefirst-phytec-imx95-PD26.1.y) | PHYTEC phyBOARD-Libra | PHYTEC PD26.1.y on NXP 6.18.20-2.0.0 (wrynose) | phyFLEX-i.MX 95 FPSC |
| [`edgefirst-phytec-imx8mp-PD26.1.y`](https://github.com/EdgeFirstAI/yocto/tree/edgefirst-phytec-imx8mp-PD26.1.y) | PHYTEC phyBOARD-Pollux, phyBOARD-Libra | PHYTEC PD26.1.y on NXP 6.12.49-2.2.0 (walnascar) | phyCORE-i.MX 8M Plus, phyFLEX-i.MX 8M Plus FPSC |

i.MX 8M Plus boards with the Ara-2 NPU hang under Ara-2 inference load on the 6.18.20 BSP, so they stay on the 6.12.49 branch for now. The NXP and PHYTEC branches pin [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) from its `main` branch, and the NXP branches also pin [meta-kinara](https://github.com/EdgeFirstAI/meta-kinara) for the Ara-2 NPU. PHYTEC's i.MX 8M Plus boards stay on PHYTEC's walnascar release line, since its wrynose line does not yet support them.

## Getting Started

Initialize with the branch and the manifest it names, then follow that branch's README:

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b edgefirst-imx-6.18.20-2.0.0 -m edgefirst-imx-6.18.20-2.0.0.xml
repo sync
```

`repo init` without `-b` uses this branch, which has no manifest.

## Branches and Tags

- New platforms and BSPs get a branch named `edgefirst-<vendor>-<bsp-version>` holding a manifest of the same name, and are added to the table above.
- Branches are maintained: they are re-pinned as meta-edgefirst and meta-kinara change, until the BSP is retired.
- Release tags (`v1.2.3`, ...) are fixed snapshots and are never updated.

## License

See the individual layers for licensing: [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst), [meta-kinara](https://github.com/EdgeFirstAI/meta-kinara).
