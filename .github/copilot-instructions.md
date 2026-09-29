# EdgeFirst Yocto — PHYTEC i.MX 8M Plus

This branch of `EdgeFirstAI/yocto` holds one repo manifest, `edgefirst-phytec-imx8mp-PD26.1.y.xml`: PHYTEC's `BSP-Yocto-NXP-i.MX8MP-PD26.1.y` manifest kept as published, plus meta-edgefirst and this repository's self-reference.

## Rules

- Update `README.md` and this file whenever setup, usage, or structure changes.
- meta-edgefirst is pinned to a commit on its `main` branch (`upstream="main"`); it handles every Yocto series conditionally and has no per-BSP branches.
- Keep PHYTEC's projects and its `<phytec>` element as published. PHYTEC's `tools/init` reads only this file (not nested includes): the `<phytec supported_builds>` list drives its machine menu, and every `<project>` becomes a `BBLAYERS` entry unless it carries `<ignorebaselayer/>`, which the self-reference must keep.
- Never hand-edit `build/conf/bblayers.conf`; `tools/init` regenerates it from the manifest.
- `tools/init` needs a `python` binary; without one it silently leaves `BBLAYERS` empty and `MACHINE` unassigned.
- Walnascar builds rely on meta-edgefirst's walnascar-gated pseudo 1.9.8 bbappend; do not add a separate pseudo host-fix layer.

## Updating

When meta-edgefirst changes, re-pin its `revision` here. When PHYTEC publishes a new PD26.1.y manifest, re-copy their projects and keep the EdgeFirst additions at the end of the file.
