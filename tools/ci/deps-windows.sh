#!/usr/bin/env bash
# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# The build tools of OpenMS-TOPP-GUI on Windows (Chocolatey). Qt comes from the
# Qt online installer or aqtinstall (CI: jurplel/install-qt-action), the OpenMS
# core from a source build or the OpenMS SDK (see README.md).

set -eu
set -o pipefail

SKIP_DOC_DEPS=false

while [[ $# -gt 0 ]]; do
  case $1 in
  --skip-doc-deps)
    SKIP_DOC_DEPS=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--skip-doc-deps]"
    exit 1
    ;;
  esac
done

# Code between the following doxygen markers are included in the
# public-facing installation instructions.

# [installation_documentation]
choco install -y --no-progress \
  cmake \
  ninja
# [installation_documentation]

# doxygen and ccache come from the packages of OpenMS/chocolatey-packages
# (SHA256-checked) rather than from the Chocolatey community feed, which fails
# too often.
work_dir=$(mktemp -d)
git clone https://github.com/OpenMS/chocolatey-packages.git "$work_dir/chocolatey-packages"
(cd "$work_dir/chocolatey-packages" && make)
packages=(ccache)
if [ "$SKIP_DOC_DEPS" = false ]; then
  packages+=(doxygen)
fi
(cd "$work_dir/chocolatey-packages/build" &&
  choco install -y --no-progress -s . "${packages[@]}")

# A custom NSIS, which provides 8-k string support and has UltraModernUI
# integrated already (for the installer, PACKAGE_TYPE=nsis):
curl --no-progress-meter --fail --retry 3 --retry-all-errors -L -o "$work_dir/NSIS.tar.gz" https://raw.githubusercontent.com/OpenMS/NSIS/main/NSIS.tar.gz
7z x -so "$work_dir/NSIS.tar.gz" | 7z x -si -ttar -aoa -o"C:/Program Files (x86)/NSIS/"
rm -rf "$work_dir"
