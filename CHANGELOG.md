# Changelog — EdgeFirst Yocto Manifests

All notable changes to the EdgeFirst Yocto manifest and build
infrastructure are documented here.

For per-package details, see the layer changelogs linked below.

## v1.2.3 — 2026-05-28

### Layer Updates

- **meta-edgefirst** v1.2.3: HAL 0.18.0 → 0.24.2 (green-tint swizzle fix
  in 0.24.2; schema-driven per-scale decoder), schemas 3.1.0 → 3.4.0
  (PyO3 wheel), gstreamer 0.4.0 + main (schema-driven `edgefirstoverlay`
  + per-tensor quant binding), videostream 2.5.1 → 2.5.2, tflite 0.5.0
  → 0.7.0, camera 2.6.0 → 2.7.0, model 2.8.0 → 2.9.0 (unified
  `rt/model/output`), recorder 1.7.1 → 1.8.0, replay 2.2.0 → 2.3.1,
  websrv 3.8.5 → 4.0.1, webui 3.8.0 → 4.1.1, zenoh 1.8.0 → 1.9.0.
  ConnMan removed from `imx-image-full` to stop the DNS race against
  systemd-resolved.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/v1.2.3/CHANGELOG.md)
- **meta-kinara** v1.2.3: edgefirst-ara2 0.5.0 → 0.11.2.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-kinara/blob/v1.2.3/CHANGELOG.md)

### Manifest Pinning

| Layer | Tag | Commit |
|-------|-----|--------|
| meta-edgefirst | v1.2.3 | `a774b98` |
| meta-kinara | v1.2.3 | `5620c08` |

## v1.2.2 — 2026-04-26

### Layer Updates

- **meta-edgefirst** v1.2.2: HAL 0.16.4 → 0.18.0, gstreamer 0.3.0 → 0.4.0,
  schemas 2.2.1 → 3.1.0, videostream 2.2.2 → 2.5.1, tflite 0.4.0 → 0.5.0.
  Unified `yolov8n` binary replaces 6 separate binaries. NNStreamer Ara-2
  dimension fix. edgefirstoverlay Vivante proto mask regression fixed.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/v1.2.2/CHANGELOG.md)
- **meta-kinara** v1.2.2: edgefirst-ara2 0.4.0 → 0.5.0.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-kinara/blob/v1.2.2/CHANGELOG.md)

### Manifest Pinning

| Layer | Tag | Commit |
|-------|-----|--------|
| meta-edgefirst | v1.2.2 | `e6a1358` |
| meta-kinara | v1.2.2 | `1bed484` |

## v1.2.1 — 2026-04-20

### Layer Updates

- **meta-edgefirst** v1.2.1: HAL 0.16.3 → 0.16.4, fixed
  `imx-nnstreamer-examples` `do_install` for devtool/Walnascar
  compatibility.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/v1.2.1/CHANGELOG.md)

### Build & Deployment

- Rebuilt all 4 target images and SDKs with bug fixes
- Updated SHA-256 checksums in documentation

### Manifest Pinning

| Layer | Tag | Commit |
|-------|-----|--------|
| meta-edgefirst | v1.2.1 | `a70aa31` |
| meta-kinara | v1.2.0 | `8f64409` |

## v1.2.0 — 2026-04-16

### Layer Updates

- **meta-edgefirst** v1.2.0: HAL 0.8.0 → 0.16.3, schemas 1.5.5 → 2.2.1,
  gstreamer 0.1.1 → 0.3.0, Neutron DMA-BUF zero-copy, YOLOv8n segmentation
  binaries with shared `PipelineProbes`, edgefirstoverlay NV12 plane offset
  fix and auto-letterbox, plus 11 additional package updates.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-edgefirst/blob/v1.2.0/CHANGELOG.md)
- **meta-kinara** v1.2.0: added `edgefirst-ara2` recipe (v0.4.0) for Python
  bindings to the Kinara Ara-2 Runtime.
  [CHANGELOG](https://github.com/EdgeFirstAI/meta-kinara/blob/v1.2.0/CHANGELOG.md)

### Build & Deployment

- Standardized test video: `853889-hd_1920_1080_25fps.mp4` published at
  `https://repo.edgefirst.ai/testdata/` — replaces ad-hoc Pexels downloads
- Removed stale `libedgefirst_hal.so.0` SONAME known issue from docs
  (fixed in HAL 0.16.2)
- `copilot-instructions.md` updated with benchmark video instructions
  and test methodology

### Manifest Pinning

| Layer | Tag | Commit |
|-------|-----|--------|
| meta-edgefirst | v1.2.0 | `99358b9` |
| meta-kinara | v1.2.0 | `8f64409` |

## v1.1 — 2026-03-02

**Tag:** `imx-6.12.49-2.2.0-20260301`

Initial release on NXP i.MX BSP imx-6.12.49-2.2.0. Pre-built images
and SDKs published to `https://repo.edgefirst.ai/yocto/nxp/` for:

- imx8mp-lpddr4-frdm
- imx8mpevk
- imx95-15x15-lpddr4x-frdm
- imx95-19x19-lpddr5-evk
