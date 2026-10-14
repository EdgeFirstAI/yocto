# EdgeFirst Yocto — Ezurio Nitrogen SMARC

EdgeFirst on Ezurio Nitrogen SMARC boards, built from Ezurio's `SUMMIT-REL-6.16.0.27` release (NXP 6.12.49-2.2.0, Yocto 5.2 walnascar) with [meta-edgefirst](https://github.com/EdgeFirstAI/meta-edgefirst) added.

This is the `edgefirst-ezurio-6.16.0.27` branch of [EdgeFirstAI/yocto](https://github.com/EdgeFirstAI/yocto). The `main` branch lists every supported branch.

## Supported Machines

| MACHINE | Board |
|---|---|
| `imx8mp-nitrogen-smarc-4g` | Nitrogen SMARC with i.MX 8M Plus, 4 GB |
| `imx95-nitrogen-smarc` | Nitrogen SMARC with i.MX 95 |

Both SoCs use Ezurio's walnascar release line, so one branch and one workspace serve both. Ezurio's other Nitrogen and SOM8MP machines are in the layer but are not covered by this branch.

## Quick Start

```bash
repo init -u https://github.com/EdgeFirstAI/yocto.git \
    -b edgefirst-ezurio-6.16.0.27 -m edgefirst-ezurio-6.16.0.27.xml
repo sync
MACHINE=imx95-nitrogen-smarc . edgefirst-setup -b build-imx95
bitbake image-summitsom-weston
```

`edgefirst-setup` runs Ezurio's own `setup-environment-nxp` and then adds `meta-edgefirst` to `bblayers.conf` of a new build directory. Everything else in the generated `local.conf` and `bblayers.conf` is Ezurio's. `DISTRO` defaults to `summitsom-wayland`, which turns on the OpenGL ES and EGL userspace. The script prompts for the NXP EULA the first time; set `EULA=1` in the environment or `ACCEPT_FSL_EULA = "1"` in `local.conf` to skip the prompt.

Build products follow Ezurio's layout under `tmp/deploy/images/<machine>/`: the `.wic.bz2` (with `.wic.bmap`) for flashing media and the `.swu` for SWUpdate. Flashing, boot switches and `fw_update` follow Ezurio's documentation.

## EdgeFirst Packages

`meta-edgefirst` provides `edgefirst-client` and `edgefirst-profiler`, which are prebuilt aarch64 binaries that need only glibc. Add them to the image in `local.conf`:

```
IMAGE_INSTALL:append = " edgefirst-client edgefirst-profiler"
```

Ezurio's stock images still carry GStreamer through `packagegroup-summit-camera`; a trimmed EdgeFirst image definition is not part of this branch yet.

`edgefirst-profiler` is distributed under the EdgeFirst Profiler EULA, which the recipe records as its license. Model inference uses TFLite with the VX delegate on i.MX 8M Plus and the Neutron delegate on i.MX 95.
