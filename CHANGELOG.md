# Changelog — EdgeFirst Yocto for Ezurio Nitrogen SMARC

All notable user-visible changes to this branch are documented here. For per-package versions, see the [meta-edgefirst CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md).

## [Unreleased]

### NPU

- Compiling a model from several threads at the same time no longer fails on the Vivante NPU.

### Platform

- New branch for Ezurio's SUMMIT-REL-6.16.0.27 release (NXP 6.12.49-2.2.0, Yocto 5.2 walnascar) on `imx8mp-nitrogen-smarc-4g` and `imx95-nitrogen-smarc`, with the Neutron NPU on eIQ Neutron SDK 3.2.3 on the i.MX 95.
