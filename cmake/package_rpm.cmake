# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Julianus Pfeuffer $
# --------------------------------------------------------------------------

## The RPM package openms-gui. It installs into /usr (CPack's default prefix), like the
## package openms of the core, and requires exactly the openms of the same version.

set(CPACK_RPM_PACKAGE_NAME "openms-gui")
set(CPACK_RPM_PACKAGE_VENDOR "OpenMS Inc <info@openms.de>")
## The core's file name with "OpenMS-" replaced by "OpenMS-GUI-"
if((DEFINED ENV{CPACK_PACKAGE_FILE_NAME}) AND (NOT "$ENV{CPACK_PACKAGE_FILE_NAME}" STREQUAL ""))
  set(CPACK_PACKAGE_FILE_NAME "$ENV{CPACK_PACKAGE_FILE_NAME}")
else()
  set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${OPENMS_PACKAGE_VERSION_FULLSTRING}-RedHat-Linux-${CMAKE_SYSTEM_PROCESSOR}")
endif()

## Version and release as the core's RPM has them (CPack's defaults: the numeric version and
## release 1), so that the requirement below matches it.
set(CPACK_RPM_PACKAGE_REQUIRES "openms = ${CPACK_PACKAGE_VERSION}")
## Until 3.7.0 the package openms contained the GUI; these files now belong to openms-gui.
set(CPACK_RPM_PACKAGE_CONFLICTS "openms < 3.7.0")

set(CPACK_RPM_PACKAGE_DEBUG ON)

## One package with the GUI applications and the library; Qt comes from the distribution.
set(CPACK_COMPONENTS_ALL library_gui ${OPENMS_GUI_APPLICATIONS_COMPONENT})
if(ENABLE_DOCS)
  list(APPEND CPACK_COMPONENTS_ALL doc_gui)
endif()
set(CPACK_RPM_COMPONENT_INSTALL ON)
set(CPACK_COMPONENTS_GROUPING ALL_COMPONENTS_IN_ONE)

## The directories the package shares with the system and with the openms package are not
## owned by it.
list(APPEND CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
     /usr/share/OpenMS /usr/share/OpenMS/TOOLS /usr/share/doc
     /usr/share/applications /usr/share/metainfo /usr/share/icons /usr/share/icons/hicolor)
foreach(_size 16 32 48 64 128 256)
  list(APPEND CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION
       /usr/share/icons/hicolor/${_size}x${_size} /usr/share/icons/hicolor/${_size}x${_size}/apps)
endforeach()

set(CPACK_RPM_PACKAGE_LICENSE "BSD-3-Clause")
set(CPACK_RPM_PACKAGE_URL "https://www.openms.de")
set(CPACK_RPM_PACKAGE_AUTOREQPROV ON)
set(CPACK_RPM_COMPRESSION_TYPE xz)
set(CPACK_RPM_INSTALL_WITH_EXEC ON)
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "graphical applications of OpenMS for LC/MS data")
set(CPACK_RPM_PACKAGE_DESCRIPTION "OpenMS is a package for LC/MS data management and analysis.

This package contains the graphical applications of OpenMS: TOPPView, a viewer for mass
spectrometry data, TOPPAS, an editor and runner for pipelines of TOPP tools, INIFileEditor,
an editor for the parameter files of the TOPP tools, and the TOPP tools that need the GUI
library (ExecutePipeline, ImageCreator). The TOPP tools and the OpenMS library are in the
package openms.")

## Create own target because you cannot "depend" on the internal target 'package'
add_custom_target(dist
  COMMAND cpack -G ${CPACK_GENERATOR}
  COMMENT "Building ${CPACK_GENERATOR} package"
)
