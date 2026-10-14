# EdgeFirst Yocto — Ezurio Nitrogen SMARC

This branch of `EdgeFirstAI/yocto` holds one repo manifest, `edgefirst-ezurio-6.16.0.27.xml`: Ezurio's `nitrogen_6.16.0.27.xml` kept as published, plus meta-edgefirst, this repository's self-reference and an `edgefirst-setup` wrapper.

## Rules

- Update `README.md` and this file whenever setup, usage, or structure changes.
- meta-edgefirst is pinned to a commit on its `main` branch (`upstream="main"`); it handles every Yocto series conditionally and has no per-BSP branches.
- Keep Ezurio's projects and revisions as published. Ezurio's manifest defaults to the `SUMMIT-REL-<version>` tag for its own repositories and pins third-party layers by commit.
- `edgefirst-setup` must keep calling `setup-environment-nxp` rather than copying its templates, so the Ezurio flow and its `-r`/`-v`/`-a` behaviour stay theirs. It only adds meta-edgefirst to a new build directory.
- Vendor-specific changes that do not fit in this manifest go in a `meta-edgefirst-ezurio` layer, only if required. Vendor-neutral recipes go in meta-edgefirst.

## Updating

When meta-edgefirst changes, re-pin its `revision` here. When Ezurio publishes a new release, add a new branch named for it with their manifest re-copied and the EdgeFirst additions kept at the end of the file.
