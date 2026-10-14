# Changelog — EdgeFirst Yocto for PHYTEC i.MX 8M Plus

All notable changes to this branch are documented here. For per-package details, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

- Document the i.MX 8M Plus / i.MX 95 release-line split in the README: PD26.1.y is published against two Yocto releases, so there is no single Yocto version that tracks it. Records the SoC-to-branch mapping, that each line needs its own workspace because walnascar and wrynose differ in core-layer layout, that a machine config present in a line is not a support claim, and the specific upstream condition under which the two branches could merge.
- New branch `edgefirst-phytec-imx8mp-PD26.1.y`: PHYTEC's `BSP-Yocto-NXP-i.MX8MP-PD26.1.y` manifest (NXP 6.12.49-2.2.0, walnascar) with meta-edgefirst added from `main`, for `phyboard-pollux-imx8mp-3` and `imx8mp-phyflex-libra-rdk-2`. meta-edgefirst's walnascar pseudo 1.9.8 replaces the separate host-fix layer earlier PHYTEC builds needed.
