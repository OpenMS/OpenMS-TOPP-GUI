# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Julianus Pfeuffer $
# --------------------------------------------------------------------------

## The Debian package openms-gui. It installs into /usr (CPack's default prefix), like the
## package openms of the core, and depends on exactly the openms of the same version.

set(CPACK_DEBIAN_PACKAGE_NAME "openms-gui")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "OpenMS Inc <info@openms.de>")
## The core's file name with "OpenMS-" replaced by "OpenMS-GUI-"
if((DEFINED ENV{CPACK_PACKAGE_FILE_NAME}) AND (NOT "$ENV{CPACK_PACKAGE_FILE_NAME}" STREQUAL ""))
  set(CPACK_PACKAGE_FILE_NAME "$ENV{CPACK_PACKAGE_FILE_NAME}")
else()
  set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${OPENMS_PACKAGE_VERSION_FULLSTRING}-Debian-Linux-${CMAKE_SYSTEM_PROCESSOR}")
endif()

## The control version as the core's package has it: a package built from anything but a
## release (a nightly, a branch) carries its prerelease identifier after a '~', e.g.
## 3.7.0~nightly.2026.11.07. dpkg sorts '~' before everything, so it sorts below the release.
## Without a Debian revision the version may not contain '-', so every character outside
## [A-Za-z0-9.+~] becomes '.'.
set(CPACK_DEBIAN_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}")
if(OPENMS_PACKAGE_VERSION_PRERELEASE_IDENTIFIER)
  string(REGEX REPLACE "[^A-Za-z0-9.+~]" "." _openms_deb_prerelease "${OPENMS_PACKAGE_VERSION_PRERELEASE_IDENTIFIER}")
  set(CPACK_DEBIAN_PACKAGE_VERSION "${CPACK_PACKAGE_VERSION}~${_openms_deb_prerelease}")
endif()

## The GUI is built against the headers of exactly this core and installed into its prefix,
## so it needs the openms package of the same version. CPack adds what dpkg-shlibdeps derives
## (the distribution's Qt) to this.
set(CPACK_DEBIAN_PACKAGE_DEPENDS "openms (= ${CPACK_DEBIAN_PACKAGE_VERSION})")
## Until 3.7.0 the package openms contained the GUI (/usr/bin/TOPPView, libOpenMS_GUI.so,
## share/OpenMS/GUISTYLE, ...); the GUI files now belong to openms-gui.
set(CPACK_DEBIAN_PACKAGE_REPLACES "openms (<< 3.7.0~)")
set(CPACK_DEBIAN_PACKAGE_BREAKS "openms (<< 3.7.0~)")

set(CPACK_DEBIAN_ARCHIVE_TYPE "gnutar")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_SECTION "science")
set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "https://www.openms.de")

## Derive the dependencies from the built binaries. libOpenMS and libOpenMS_CLI come from the
## package openms, which records no shlibs information for them; with the core's library
## directory (the SDK's, or /usr/lib for the installed package) as a private directory,
## dpkg-shlibdeps accepts them without a package; the Depends above covers them.
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS_PRIVATE_DIRS "${OPENMS_LIB_DIR}")
set(CPACK_DEBIAN_PACKAGE_DEBUG ON)

## Some libraries reach the staging tree with empty RUNPATH entries, which the loader reads
## as the current working directory (the release workflow builds with PACKAGE_TYPE=none and
## packages after reconfiguring; the script explains how). The script removes them.
list(APPEND CPACK_PRE_BUILD_SCRIPTS "${CMAKE_CURRENT_LIST_DIR}/cpack_clean_runpath.cmake")
## dpkg-shlibdeps names the packages of the build host, which in Ubuntu 24.04 carry the t64
## suffix of the 64-bit time_t transition (libqt6gui6t64). The script adds the old names as
## alternatives, for the releases that do not have the t64 packages (see the script).
list(APPEND CPACK_POST_BUILD_SCRIPTS "${CMAKE_CURRENT_LIST_DIR}/cpack_deb_t64_dependencies.cmake")

## One package with the GUI applications and the library; Qt comes from the distribution.
## The headers and the CMake package are not packaged, as in the core's package.
set(CPACK_COMPONENTS_ALL library_gui ${OPENMS_GUI_APPLICATIONS_COMPONENT})
if(ENABLE_DOCS)
  list(APPEND CPACK_COMPONENTS_ALL doc_gui)
endif()
## Without component packaging, CPack installs everything into one package: the list above
## only takes effect with CPACK_DEB_COMPONENT_INSTALL and an all-in-one package.
set(CPACK_DEB_COMPONENT_INSTALL ON)
set(CPACK_COMPONENTS_GROUPING ALL_COMPONENTS_IN_ONE)

set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "graphical applications of OpenMS for LC/MS data")
## CPack indents the lines and turns empty ones into " ."
set(CPACK_PACKAGE_DESCRIPTION "OpenMS is a package for LC/MS data management and analysis.

This package contains the graphical applications of OpenMS: TOPPView, a viewer
for mass spectrometry data, TOPPAS, an editor and runner for pipelines of TOPP
tools, INIFileEditor, an editor for the parameter files of the TOPP tools, and
the TOPP tools that need the GUI library (ExecutePipeline, ImageCreator). The
TOPP tools and the OpenMS library are in the package openms.")

## Create own target because you cannot "depend" on the internal target 'package'
add_custom_target(dist
  COMMAND cpack -G ${CPACK_GENERATOR}
  COMMENT "Building ${CPACK_GENERATOR} package"
)
