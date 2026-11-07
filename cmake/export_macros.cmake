# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Stephan Aiche, Timo Sachsenberg $
# --------------------------------------------------------------------------

include(CMakePackageConfigHelpers)

#------------------------------------------------------------------------------
# The CMake package of the GUI layer, OpenMSGUI:
#   OpenMSGUIConfig.cmake         finds the OpenMS core (COMPONENTS CLI) and Qt, then
#                                 includes the targets below
#   OpenMSGUIConfigVersion.cmake
#   OpenMSGUITargets.cmake        OpenMS::OpenMS_GUI
# installed into ${INSTALL_CMAKE_DIR} (lib/cmake/OpenMSGUI, Windows: CMake) in
# component cmake_gui. The OpenMS core's own OpenMSConfig.cmake delegates its
# component GUI to this package, so find_package(OpenMS COMPONENTS GUI) works
# once the GUI layer is installed into the same prefix.

set(_OPENMS_GUI_EXPORT_FILE "${OPENMS_GUI_EXPORT_SET}.cmake")

# clear the lists before we refill them (one list of targets per export set)
foreach(_export_set IN LISTS OPENMS_EXPORT_SETS)
  set(_OPENMS_EXPORT_TARGETS_${_export_set} "" CACHE INTERNAL "Targets exported in ${_export_set}.")
endforeach()

# openms_register_export_target(<target> [<export set>])
# Records that the export set (OpenMSGUITargets when omitted) has targets.
macro(openms_register_export_target target_name)
  set(_export_set ${ARGN})
  if("${_export_set}" STREQUAL "")
    set(_export_set ${OPENMS_GUI_EXPORT_SET})
  endif()
  if(NOT "${_export_set}" IN_LIST OPENMS_EXPORT_SETS)
    message(FATAL_ERROR "openms_register_export_target(${target_name}): unknown export set '${_export_set}' (known: ${OPENMS_EXPORT_SETS})")
  endif()
  set(_OPENMS_EXPORT_TARGETS_${_export_set} ${_OPENMS_EXPORT_TARGETS_${_export_set}} ${target_name}
    CACHE INTERNAL "Targets exported in ${_export_set}.")
  unset(_export_set)
endmacro()

# Writes OpenMSGUIConfig.cmake and OpenMSGUIConfigVersion.cmake into the build tree and
# installs them. They refer to the installation layout, so the build tree itself is not
# usable as OpenMSGUI_DIR; install the GUI layer (next to the core) instead.
macro(openms_export_targets)
  ## the Qt modules OpenMS_GUI links publicly; a consumer must find the same ones
  set(OPENMS_GUI_PACKAGE_QT_MODULES Core ${OpenMS_GUI_QT_COMPONENTS} ${OpenMS_GUI_QT_FOUND_COMPONENTS_OPT})
  ## the OpenMS core the GUI layer is compiled against (find_openms.cmake: EXACT)
  set(OPENMS_GUI_CORE_VERSION "${OpenMS_VERSION}")

  configure_package_config_file(
    "${OPENMS_HOST_DIRECTORY}/cmake/OpenMSGUIConfig.cmake.in"
    "${PROJECT_BINARY_DIR}/OpenMSGUIConfig.cmake"
    INSTALL_DESTINATION ${INSTALL_CMAKE_DIR}
    PATH_VARS INSTALL_SHARE_DIR INSTALL_LIB_DIR INSTALL_BIN_DIR INSTALL_INCLUDE_DIR
  )

  ## a consumer may ask for the GUI layer of 3.7, like for the core; the core it needs is
  ## exactly the one it was built against, which OpenMSGUIConfig.cmake checks
  write_basic_package_version_file(
    "${PROJECT_BINARY_DIR}/OpenMSGUIConfigVersion.cmake"
    VERSION ${OPENMS_PACKAGE_VERSION}
    COMPATIBILITY SameMinorVersion
  )

  install_file(${PROJECT_BINARY_DIR}/OpenMSGUIConfig.cmake ${INSTALL_CMAKE_DIR} cmake_gui)
  install_file(${PROJECT_BINARY_DIR}/OpenMSGUIConfigVersion.cmake ${INSTALL_CMAKE_DIR} cmake_gui)
endmacro()
