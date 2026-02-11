ScanCode plugins
================

https://github.com/aboutcode-org/scancode-plugins

These are various scancode plugins, some are builtins and some are extras.
Several of them contain pre-built binaries.

Each plugin is under its own license and in particular plugins that merely
bundle pre-built binaries use the license of these binaries.

This repository itself is licensed under the Apache 2.0 license (but there is
not much in it beyond build scripts).

The src-* directories contain the source code of pre-built plugins that contain
native binaries.

See also:

 - https://github.com/aboutcode-org/scancode-toolkit
 - https://github.com/nexB/scancode-thirdparty-src (source for some plugins
   being transitioned)


To re-provision pre-built binaries, follow these instructions (only on Linux):

- install the system package for clamav, zstd and p7zip
- install the patchelf from sources (provided here in src/). This is done for
  you automatically below with a configure run. Older versions may be  buggy.

- then run::

    ./configure
    etc/scripts/fetch-plugins.sh
    clamscan -v *

In all cases, run clamscan or an up to date antivirus scanner before pushing
a new release.


To build the wheels for all the plugins::

    etc/scripts/build-plugins.sh

To override the platform tag (e.g., for Apple Silicon) set
``SCANCODE_PLUGINS_PLAT_NAME`` and optionally ``SCANCODE_PLUGINS_PYTHON_TAG``::

    SCANCODE_PLUGINS_PLAT_NAME=macosx_15_0_arm64 \
      SCANCODE_PLUGINS_PYTHON_TAG=py3 \
      etc/scripts/build-plugins.sh

The dirs/ directory will contain all the built wheels.

To build Linux manylinux2014 x86_64 wheels in Docker::

    docker build --platform linux/amd64 \
      -f etc/docker/scancode-linux-x86_64.Dockerfile \
      -t scancode-linux-x86_64:latest .

    docker run --rm --platform linux/amd64 \
      -v "$(pwd)":/work/scancode-plugins \
      -w /work/scancode-plugins \
      scancode-linux-x86_64:latest \
      bash -lc etc/scripts/build-linux-x86_64.sh

To collect the multi-arch wheel set for publishing (default: ModelMonster
packages on linux/x86_64, linux/aarch64, and macos/arm64)::

    etc/scripts/copy-wheels.sh --target /tmp/wheels

To prepare a GitHub Pages style tree (`dist/` under repo root)::

    etc/scripts/copy-wheels.sh \
      --layout repo \
      --target /tmp/scancode-plugins-pages \
      --base-url https://ospoco.github.io/scancode-plugins/dist/


ModelMonster wheel workflow (local dev)
---------------------------------------

This fork (`ospoco/scancode-plugins`) is used to produce and publish the
wheel set consumed by ModelMonster (`mm`) for Python 3.14:

- linux/x86_64 (`manylinux2014_x86_64`)
- linux/aarch64 (`manylinux2014_aarch64`)
- macOS/arm64 (`macosx_15_0_arm64`)

The default publish set is the 7 plugin packages used by `mm`:

- extractcode_7z
- extractcode_libarchive
- typecode_libmagic
- textcode_pdf2text
- scancode_ctags
- scancode_dwarfdump
- scancode_readelf

Recommended build order:

1. Build/update macOS arm64 plugin wheels on an Apple Silicon machine.
2. Build Linux x86_64 wheels with `etc/scripts/build-linux-x86_64.sh`.
3. Build Linux aarch64 wheels with `etc/scripts/build-linux-aarch64.sh`.
4. Assemble publishable artifacts:

   ::

      etc/scripts/copy-wheels.sh --target /tmp/wheels

5. For GitHub Pages publishing layout:

   ::

      etc/scripts/copy-wheels.sh \
        --layout repo \
        --target /tmp/scancode-plugins-pages \
        --base-url https://ospoco.github.io/scancode-plugins/dist/

Expected result for the default ModelMonster set:

- 21 wheels total (7 packages x 3 platform tags)
- `index.html` generated next to the wheels

The top-level `dist/` directory in this repo is a build output location and is
ignored by Git. Use `copy-wheels.sh` output as the publish artifact.
