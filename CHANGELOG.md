# Changelog — EdgeFirst Yocto for PHYTEC i.MX 95

All notable changes to this branch are documented here. For per-package details, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

- Add `meta-edgefirst-phytec` and advance `meta-edgefirst` to `635d4be`: the PHYTEC-specific RAUC wiring — the device keyring bbappend, the bundle signing include, the two bundle bbappends and the CA and publish scripts — now lives in a PHYTEC vendor layer alongside `meta-edgefirst-ezurio` and `meta-edgefirst-torizon`, leaving `meta-edgefirst` vendor-neutral. RAUC is a PHYTEC-only update mechanism, so the keyring bbappend's `update` override matched no other vendor's distro. The new layer also carries the `ClientIdentifier=mac` drop-in that holds a DHCP lease stable across A/B slot activations. Both projects move in a single commit: adding the layer without bumping the pin duplicates every bbappend, and bumping the pin without adding the layer drops the RAUC wiring.
- Document the i.MX 95 / i.MX 8M Plus release-line split in the README: PD26.1.y is published against two Yocto releases, so there is no single Yocto version that tracks it. Records the SoC-to-branch mapping, that each line needs its own workspace because wrynose and walnascar differ in core-layer layout, why the i.MX 8M Plus machine configs present here do not build, and the specific upstream condition under which the two branches could merge.
- New branch `edgefirst-phytec-imx95-PD26.1.y`: PHYTEC's `BSP-Yocto-NXP-i.MX95-PD26.1.y` manifest (NXP 6.18.20-2.0.0, wrynose) with meta-edgefirst added from `main`, for `imx95-phyflex-libra-rdk-2`.
