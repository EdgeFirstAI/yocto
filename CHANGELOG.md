# Changelog — EdgeFirst Yocto for PHYTEC i.MX 95

All notable changes to this branch are documented here. For per-package details, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

- Document the i.MX 95 / i.MX 8M Plus release-line split in the README: PD26.1.y is published against two Yocto releases, so there is no single Yocto version that tracks it. Records the SoC-to-branch mapping, that each line needs its own workspace because wrynose and walnascar differ in core-layer layout, why the i.MX 8M Plus machine configs present here do not build, and the specific upstream condition under which the two branches could merge.
- New branch `edgefirst-phytec-imx95-PD26.1.y`: PHYTEC's `BSP-Yocto-NXP-i.MX95-PD26.1.y` manifest (NXP 6.18.20-2.0.0, wrynose) with meta-edgefirst added from `main`, for `imx95-phyflex-libra-rdk-2`.
