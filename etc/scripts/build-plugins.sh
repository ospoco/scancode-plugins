#!/bin/bash
#
# Copyright (c) nexB Inc. http://www.nexb.com/ - All rights reserved.
#

# This script builds wheels for all the plugins

set -e

# un-comment to trace execution
set -x


here="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
dist=$here/../../dist
mkdir -p "$dist"

plat_name="${SCANCODE_PLUGINS_PLAT_NAME:-}"
python_tag="${SCANCODE_PLUGINS_PYTHON_TAG:-py3}"

for root in builtins misc binary-analysis
  do
    for plugin in `ls $root`
      do 
        pushd $root/$plugin
        rm -rf dist build
        # build and copy up
        if [ -n "$plat_name" ]; then
          python setup.py clean --all bdist_wheel --plat-name "$plat_name" --python-tag "$python_tag"
        else
          python setup.py release
        fi
        mv dist/* "$dist"
        rm -rf build
        popd
      done
  done
