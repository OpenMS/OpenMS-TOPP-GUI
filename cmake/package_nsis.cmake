# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Julianus Pfeuffer, Chris Bielow $
# --------------------------------------------------------------------------

## The Windows installer of the GUI: an add-on to the installation of the OpenMS core of the
## same version. The script is cmake/Windows/NSIS.template.in (CPack finds it in the module
## path); it reads the folder of the core installation from the registry and installs into it.
##
## No MSVC runtime is installed (InstallRequiredSystemLibraries): the core installer ships
## it. Build the GUI with the toolset of the core (or an older one), so that the runtime of
## the core is new enough.

if (CMAKE_VS_PLATFORM_NAME MATCHES ".*Win32.*" OR CMAKE_GENERATOR MATCHES ".*Win32.*")
  message(FATAL_ERROR "There is no 32-bit OpenMS installer, so there is none of the GUI either.")
endif()

## Only CPACK_-prefixed variables reach CPackConfig.cmake and so the substitution of the
## @CPACK_...@ references in the template at packaging time.
set(CPACK_OPENMS_PROJECT_SOURCE_DIR "${PROJECT_SOURCE_DIR}")
## The version string of the core installation: the core installer writes it to the
## registry as DisplayVersion, and the GUI installer requires it there.
set(CPACK_OPENMS_VERSION "${OPENMS_PACKAGE_VERSION_FULLSTRING}")
set(CPACK_OPENMS_INSTALL_BIN_DIR "${INSTALL_BIN_DIR}")
set(CPACK_OPENMS_INSTALL_SHARE_DIR "${INSTALL_SHARE_DIR}")
set(CPACK_OPENMS_INSTALL_DOC_DIR "${INSTALL_DOC_DIR}")
set(CPACK_OPENMS_INSTALL_INCLUDE_DIR "${INSTALL_INCLUDE_DIR}")
set(CPACK_OPENMS_INSTALL_CMAKE_DIR "${INSTALL_CMAKE_DIR}")

## The template copies straight from the staging tree, which holds every component in the
## usual folders bin/, share/, ...
set(CPACK_COMPONENT_ALL_IN_ONE 1)
set(CPACK_COMPONENTS_ALL_GROUPS_IN_ONE_PACKAGE 1)
set(CPACK_MONOLITHIC_INSTALL 1)

## The core's file name with "OpenMS-" replaced by "OpenMS-GUI-"
if((DEFINED ENV{CPACK_PACKAGE_FILE_NAME}) AND (NOT "$ENV{CPACK_PACKAGE_FILE_NAME}" STREQUAL ""))
  set(CPACK_PACKAGE_FILE_NAME "$ENV{CPACK_PACKAGE_FILE_NAME}")
else()
  set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${OPENMS_PACKAGE_VERSION_FULLSTRING}-Win64")
endif()
set(CPACK_PACKAGE_ICON "${PROJECT_SOURCE_DIR}/cmake/Windows/OpenMS.ico")

## Create own target because you cannot "depend" on the internal target 'package'
add_custom_target(dist
  COMMAND cpack -G ${CPACK_GENERATOR}
  COMMENT "Building ${CPACK_GENERATOR} package"
)

## Signs the installer with a code signing certificate of the certificate store (the
## Windows release workflow does not sign yet).
if (DEFINED SIGNING_IDENTITY AND NOT "${SIGNING_IDENTITY}" STREQUAL "")
  add_custom_target(signed_dist
    COMMAND signtool sign /v /n "${SIGNING_IDENTITY}" /t http://timestamp.digicert.com ${CPACK_PACKAGE_FILE_NAME}.exe
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    COMMENT "Signing ${CPACK_PACKAGE_FILE_NAME}.exe with '${SIGNING_IDENTITY}'"
    DEPENDS dist
  )
endif()
