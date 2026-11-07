#!/usr/bin/env bash
# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# Set the version of OpenMS-TOPP-GUI. It is always the version of the OpenMS core
# the GUI layer is built against (find_package(OpenMS <version> EXACT)), so it is
# changed together with the version of OpenMS.

################################################################################
set -eu
set -o pipefail

################################################################################
usage() {
  cat <<EOF
Usage: $(basename "$0") [options] major minor patch

  -h      This message

Update the version number of OpenMS-TOPP-GUI (run from the top-level directory):
  - OPENMS_GUI_VERSION in CMakeLists.txt
  - the version item of the INI files of the tests (src/tests/topp/*.ini)
  - a new section in CHANGELOG

EOF
}

################################################################################
while getopts "h" o; do
  case "${o}" in
  h)
    usage
    exit
    ;;

  *)
    exit 1
    ;;
  esac
done

shift $((OPTIND - 1))

if [ $# -ne 3 ]; then
  echo >&2 "ERROR: please provide three numbers (use -h for more info)"
  exit 1
fi

for number in "$@"; do
  if ! [[ "$number" =~ ^[0-9]+$ ]]; then
    echo >&2 "ERROR: '$number' is not a number"
    exit 1
  fi
done

if [ ! -f CMakeLists.txt ] || ! grep -q '^set(OPENMS_GUI_VERSION ' CMakeLists.txt; then
  echo >&2 "ERROR: run this script from the top-level directory of OpenMS-TOPP-GUI"
  exit 1
fi

################################################################################
package_version="$1.$2.$3"

echo "Setting version $package_version"

################################################################################
# the version of the project (and of the OpenMS core it requires)
sed -i -e "s#^set(OPENMS_GUI_VERSION .*)#set(OPENMS_GUI_VERSION $package_version)#" CMakeLists.txt

# the INI files of the tests, which carry the version of the tool that wrote them
find ./src/tests/topp/ \
  -type f \
  -name '*.ini' \
  -exec grep -q "<ITEM name=\"version\" value=\".*\" type=\"string\"" {} \; \
  -exec sed -i -e "s#<ITEM name=\"version\" value=\"[^\"]*\" type=\"string\"#<ITEM name=\"version\" value=\"$package_version\" type=\"string\"#g" {} \;

# CITATION.cff, if it carries a version
if grep -q '^version:' CITATION.cff 2>/dev/null; then
  sed -i -e "s#^version:.*#version: \"$package_version\"#" CITATION.cff
fi

################################################################################
# A new section at the top of the CHANGELOG (above its first line of dashes),
# unless it has one for this version already. sed wants a backslash at the end of
# every line of the inserted text but the last.
if grep -qE "^----[[:space:]]+OpenMS-TOPP-GUI ${package_version//./\\.}[[:space:]]" CHANGELOG; then
  echo "CHANGELOG already has a section for $package_version"
else
  section_header=$(
    sed -Ee '$!s/$/\\/' <<<"
------------------------------------------------------------------------------------------
----                         OpenMS-TOPP-GUI ${package_version}     (under development)            ----
----                         requires OpenMS ${package_version}                                    ----
------------------------------------------------------------------------------------------

 " # NOTE: this line should start with a single blank space!
  )

  # the line number of the first line starting with more than 10 "-"
  line_num=$(
    grep \
      --extended-regexp \
      --line-number \
      --max-count=1 "^-{10,}" CHANGELOG |
      cut -d: -f1
  )

  sed -i \
    -e "${line_num}i $section_header" \
    CHANGELOG
fi

################################################################################
echo "done."
