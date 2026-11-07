#!/usr/bin/env bash
# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# The dependencies of OpenMS-TOPP-GUI on macOS (Homebrew). The OpenMS core is
# not installed here: build it from source or use the OpenMS SDK (see README.md).

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

# GitHub's macOS runners come with packages (e.g. Python) whose links brew would
# refuse to overwrite. This wrapper adds --overwrite to every brew install below.
function brew() {
  local action=$1
  shift

  # macOS' bash 3.2 rejects empty arrays under 'set -u', so the action is the
  # first element of the flags
  local -a flags=("$action")

  if [ "$action" = "install" ]; then
    flags+=("--overwrite")
  fi

  command brew "${flags[@]}" "$@"
}

# Code between the following doxygen markers are included in the
# public-facing installation instructions.

# [installation_documentation]
# Update the package index:
brew update

# Build tools and Qt:
brew install \
  ninja \
  qtbase \
  qtsvg

# libomp: the OpenMP runtime of an OpenMS built from source with Homebrew's libomp
# (the macOS presets point OpenMP_ROOT at /opt/homebrew/opt/libomp). The OpenMS SDK
# bundles its own and does not need it.
brew install libomp

# Optional documentation dependencies:
if [ "$SKIP_DOC_DEPS" = false ]; then
  brew install \
    doxygen
fi
# [installation_documentation]

# These are only needed in CI:
brew install \
  ccache
