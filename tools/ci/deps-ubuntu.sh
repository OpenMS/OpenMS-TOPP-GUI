#!/usr/bin/env bash
# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# The dependencies of OpenMS-TOPP-GUI on Ubuntu (24.04: Qt 6.4).
# The OpenMS core is not installed here: build it from source or use the OpenMS
# SDK (see README.md).

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
# Add "universe" and update:
sudo add-apt-repository -y universe
sudo apt-get -qq update

# Build tools:
sudo apt-get -qq install -y \
  build-essential \
  cmake \
  git \
  ninja-build \
  pkg-config

# Qt (libqt6test6: QtTest, for the tests of the GUI):
sudo apt-get -qq install -y \
  qt6-base-dev \
  libqt6svg6-dev \
  libqt6opengl6-dev \
  libqt6openglwidgets6 \
  libqt6test6

# Optional documentation dependencies:
if [ "$SKIP_DOC_DEPS" = false ]; then
  sudo apt-get -qq install -y \
    doxygen
fi
# [installation_documentation]

# These are only needed in CI:
sudo apt-get -qq install -y \
  ccache
