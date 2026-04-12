# Changelog — EdgeFirst Yocto Manifests

All notable changes to the EdgeFirst Yocto manifest and build
infrastructure are documented here.

For per-package details, see the layer changelogs linked below.

## [Unreleased] — Changes since v1.1 (2026-03-02)

### Layer Updates

- **meta-edgefirst**: 43 commits — HAL 0.8.0 → 0.16.2, schemas 1.5.5 →
  2.2.1, gstreamer 0.1.1 → 0.2.0, Neutron DMA-BUF zero-copy, YOLOv8n
  segmentation binaries, shared PipelineProbes, and 11 additional
  package updates.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/main/CHANGELOG.md)
- **meta-kinara**: No changes (stable at `234cb76`).
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-kinara/blob/main/CHANGELOG.md)

### Build & Deployment

- Standardized test video: `853889-hd_1920_1080_25fps.mp4` published at
  `https://repo.edgefirst.ai/testdata/` — replaces ad-hoc Pexels downloads
- Removed stale `libedgefirst_hal.so.0` SONAME known issue from docs
  (fixed in HAL 0.16.2)
- `copilot-instructions.md` updated with benchmark video instructions
  and test methodology

### Manifest Pinning

13 manifest bumps tracking `meta-edgefirst` development. Current pins:

| Layer | Commit |
|-------|--------|
| meta-edgefirst | `fb7f1d3` |
| meta-kinara | `234cb76` |

## v1.1 — 2026-03-02

**Tag:** `imx-6.12.49-2.2.0-20260301`

Initial release on NXP i.MX BSP imx-6.12.49-2.2.0. Pre-built images
and SDKs published to `https://repo.edgefirst.ai/yocto/nxp/` for:

- imx8mp-lpddr4-frdm
- imx8mpevk
- imx95-15x15-lpddr4x-frdm
- imx95-19x19-lpddr5-evk
