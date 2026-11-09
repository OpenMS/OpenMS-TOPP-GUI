#!/usr/bin/env bash
# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------
#
# Find the OpenMS SDK and the OpenMS installer of one platform on the archive
# server, as published by the release workflow of OpenMS:
#
#   <base>/<channel>/<version>/OpenMS-SDK-<version>-<sdk platform>.<tar.gz|zip>
#   <base>/<channel>/<version>/OpenMS-<full version string>-<installer suffix>
#
# Usage: resolve-sdk.sh <nightly|release|rc<N>> <version|latest> <Linux|macOS|Windows> <X64|ARM64> [sdk]
#
#   version  nightly: YYYY.MM.DD (YYYY-MM-DD is accepted), otherwise X.Y.Z,
#            latest: the newest folder of the channel that has both files
#   sdk      'true' (default) or 'false': with false only the installer is
#            looked for (sdk_name and sdk_url are then empty)
#
# Prints shell assignments (version, sdk_name, sdk_url, installer_name,
# installer_url, version_fullstring), e.g. for >> "$GITHUB_OUTPUT".
# OPENMS_ARCHIVE_URL overrides the base URL. OPENMS_SDK_WAIT_MINUTES (default 0) waits for a
# given version (not latest) whose folder is not complete yet.
set -euo pipefail

if [[ $# -lt 4 || $# -gt 5 ]]; then
  echo >&2 "Usage: $0 <nightly|release|rc<N>> <version|latest> <Linux|macOS|Windows> <X64|ARM64> [sdk]"
  exit 2
fi

channel=$1
version=$2
os=$3
arch=$4
need_sdk=${5:-true}
base=${OPENMS_ARCHIVE_URL:-https://archive.openms.de/openms/OpenMSInstaller}

# nightly folders are dates; those of release and of the release candidates
# (rc1, rc2, ... as named by the version action) are versions
case "$channel" in
  nightly) folder_regex='^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$' ;;
  release|rc[0-9]*) folder_regex='^[0-9]+\.[0-9]+\.[0-9]+$' ;;
  *) echo >&2 "ERROR: unknown channel '$channel' (nightly, release or rc<N>)"; exit 2 ;;
esac

# the platform names of the SDK (tools/ci/package_sdk.sh of OpenMS) and of the
# installers (cmake/package_*.cmake of OpenMS)
case "$os-$arch" in
  Linux-X64)     sdk_suffix=Linux-x86_64.tar.gz;  installer_suffix=Debian-Linux-x86_64.deb ;;
  Linux-ARM64)   sdk_suffix=Linux-aarch64.tar.gz; installer_suffix=Debian-Linux-aarch64.deb ;;
  macOS-ARM64)   sdk_suffix=macOS-arm64.tar.gz;   installer_suffix=macOS-Silicon.pkg ;;
  macOS-X64)     sdk_suffix=macOS-x86_64.tar.gz;  installer_suffix=macOS-Intel.pkg ;;
  Windows-X64)   sdk_suffix=Windows-x64.zip;      installer_suffix=Win64.exe ;;
  *) echo >&2 "ERROR: no OpenMS packages for $os-$arch"; exit 2 ;;
esac

# file and folder names of a directory listing of the archive server
listing() {
  curl --fail --silent --show-error --location --retry 3 "$1/" |
    grep -oE 'href="[^"?/][^"]*"' | sed -e 's/^href="//' -e 's/"$//'
}

# the SDK and the installer in one folder; returns 1 if one of them is missing
find_in_folder() {
  local folder=$1 files sdk installer
  files=$(listing "$base/$channel/$folder") || return 1
  sdk=$(grep -xF "OpenMS-SDK-$folder-$sdk_suffix" <<<"$files" || true)
  # the installer carries the full version string, which need not contain the
  # folder name (a nightly is named after the date of its last commit)
  installer=$(grep -E "^OpenMS-[0-9]+\.[0-9]+\.[0-9]+[^/]*-${installer_suffix//./\\.}\$" <<<"$files" |
              grep -v '^OpenMS-SDK-' | grep -v '^OpenMS-GUI-' | sort -V | tail -n 1 || true)
  if [[ -z "$installer" ]] || [[ "$need_sdk" == true && -z "$sdk" ]]; then
    return 1
  fi
  local sdk_url=""
  if [[ "$need_sdk" == true ]]; then
    sdk_url="$base/$channel/$folder/$sdk"
  else
    sdk=""
  fi
  local fullstring=${installer#OpenMS-}
  fullstring=${fullstring%-"$installer_suffix"}
  printf 'version=%s\n' "$folder"
  printf 'sdk_name=%s\n' "$sdk"
  printf 'sdk_url=%s\n' "$sdk_url"
  printf 'installer_name=%s\n' "$installer"
  printf 'installer_url=%s\n' "$base/$channel/$folder/$installer"
  printf 'version_fullstring=%s\n' "$fullstring"
}

if [[ "$version" == latest ]]; then
  # newest first; a folder of a release or nightly that is still being uploaded,
  # or whose build failed on this platform, is passed over
  # (a read loop, not mapfile: macOS has bash 3.2; fd 3 keeps the loop's stdin free)
  while IFS= read -r folder <&3; do
    if find_in_folder "$folder"; then
      exit 0
    fi
    echo >&2 "note: $base/$channel/$folder has no complete set for $os-$arch, trying the one before"
  done 3< <(listing "$base/$channel" | sed 's#/$##' | grep -E "$folder_regex" | sort -rV | head -n 10)
  echo >&2 "ERROR: none of the newest folders of $base/$channel has the SDK ($sdk_suffix) and the installer ($installer_suffix)"
  exit 1
fi

if [[ "$channel" == nightly ]]; then
  version=${version//-/.}
fi
if ! grep -qE "$folder_regex" <<<"$version"; then
  echo >&2 "ERROR: '$version' is not a version of the $channel channel"
  exit 2
fi
# A given folder may still be uploading (the nightly of the GUI layer can start before
# OpenMS's nightly is published): wait up to OPENMS_SDK_WAIT_MINUTES for it.
wait_minutes=${OPENMS_SDK_WAIT_MINUTES:-0}
waited=0
until find_in_folder "$version"; do
  if (( waited >= wait_minutes )); then
    echo >&2 "ERROR: $base/$channel/$version has no SDK OpenMS-SDK-$version-$sdk_suffix and installer OpenMS-<version>-$installer_suffix"
    exit 1
  fi
  echo >&2 "note: $base/$channel/$version is not complete for $os-$arch yet, waiting ($waited of $wait_minutes minutes)"
  sleep 300
  waited=$((waited + 5))
done
