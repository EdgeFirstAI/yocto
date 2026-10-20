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

## The EdgeFirst Yocto Family

This branch is one of a family of detached branches of `EdgeFirstAI/yocto`, one per platform and BSP, with no shared history. `main` is an index. The NXP branches are the reference integration; the full rollout procedure, the NXP BSP upgrade procedure and the table of owned patches live in `.github/copilot-instructions.md` on the `edgefirst-imx-6.18.20-2.0.0` branch, and apply to every branch.

The family exists so that every vendor platform gets the latest NPU, GPU, camera and vision-pipeline enablement the EdgeFirst stack needs, even when the vendor's BSP lags NXP, and so that every vendor platform gets the latest EdgeFirst stack integrated and tested on it. NXP publishes a BSP quarterly; we adopt it on the NXP FRDM/EVK branches first and then backport what each vendor BSP still needs.

Every release of every product is versioned `YYYY.MM.PATCH` (for example `2026.10.0`). A published release is never changed; a fix is the next `PATCH`. Product names follow "EdgeFirst Yocto for VENDOR"; Toradex is the exception because Torizon is the product users see ("Torizon with EdgeFirst", "Torizon for Maivin", "Torizon for ADIS").

| Branch | Platform | BSP | Use for |
|---|---|---|---|
| `edgefirst-imx-6.18.20-2.0.0` | NXP i.MX EVK/FRDM | NXP 6.18.20-2.0.0 (wrynose) | i.MX 95, and i.MX 8M Plus without Ara-2 |
| `edgefirst-imx-6.12.49-2.2.0` | NXP i.MX EVK/FRDM | NXP 6.12.49-2.2.0 (walnascar) | i.MX 8M Plus with the Ara-2 NPU |
| `torizon` | Toradex Verdin | Torizon OS (walnascar) | Verdin i.MX 8M Plus, Verdin i.MX 95 |
| `edgefirst-phytec-imx95-PD26.1.y` | PHYTEC phyBOARD-Libra | PHYTEC PD26.1.y on NXP 6.18.20 (wrynose) | phyFLEX-i.MX 95 |
| `edgefirst-phytec-imx8mp-PD26.1.y` | PHYTEC phyBOARD-Pollux/Libra (**this branch**) | PHYTEC PD26.1.y on NXP 6.12.49 (walnascar) | phyCORE/phyFLEX-i.MX 8M Plus |
| `edgefirst-ezurio-6.16.0.27` | Ezurio Nitrogen SMARC | Ezurio SUMMIT-REL-6.16.0.27 on NXP 6.12.49 (walnascar) | i.MX 8M Plus, i.MX 95 |

### Where things belong

- Anything portable across BSPs (EdgeFirst packages, HAL, services, NPU delegates and runtimes, packagegroups, kernel patches needed by any NXP-kernel BSP) lives in `meta-edgefirst` on `main`, gated by overrides so it applies only where it is needed.
- Anything specific to one vendor's BSP (image, update and signing integration, vendor kernel patches, device-tree overlays, workarounds) lives in `meta-edgefirst-<vendor>` on `main`.
- Which commits a BSP builds, the vendor's own project pins and the setup tooling live in the vendor's branch of `EdgeFirstAI/yocto`.
- The layers live only on `main`; there are no per-release layer branches.

### Backports

Vendors often omit NXP layers or ship them far out of date, so a backport must be self-contained: it never requires or depends on a recipe from an NXP layer, and it relies on version precedence rather than layer presence to win over NXP's copy. Backports go straight to `main` of the layer, with no pull request, and are then rolled out by re-pinning every branch. A patch shared by several kernels stays in `meta-edgefirst`; where a vendor kernel diverges the vendor layer carries its own copy with a recorded condition for dropping it. Coupled changes ship together: if a userspace bump needs a kernel change, every vendor branch that takes the bump needs the kernel change first.

### Rolling out a layer change

1. Land the change on `main` of the layer, and make sure a layer builds without any NXP layer the target BSP lacks (the Torizon for Maivin stack has no `meta-freescale-ml`).
2. Re-pin `meta-edgefirst` (and each changed vendor layer) in every branch's manifest to the new full SHA, keeping `upstream="main"`. Re-pin the two NXP branches and `meta-kinara` together.
3. Parse every machine of every branch in a synced workspace, build at least one machine per SoC family, and test on that vendor's hardware where runtime behaviour changed.
4. Commit each re-pin with a signed commit, and report per branch the old and new pin, what was parsed, built and booted, and what was not tested.

### Changelogs

A branch changelog records what a user of that BSP can see: package and runtime versions, supported boards and features, installation and update behaviour, and changes to the images. It does not record how Yocto is put together: pins, layer moves, recipe or packagegroup restructuring and build-system details belong in the commit messages and the layer changelogs. Ask before changing a changelog.
