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
