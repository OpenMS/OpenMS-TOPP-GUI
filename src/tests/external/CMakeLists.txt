# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.24 FATAL_ERROR)

### Example CMakeLists.txt of a program using the OpenMS GUI library. It doubles as
### the installed-consumer test of OpenMS-TOPP-GUI (OPENMS_TEST_INSTALLED_CONSUMER,
### src/tests/external/installed_consumer.cmake), so it also checks what the package
### promises; a plain consumer project needs only find_package() and
### target_link_libraries().
project("OpenMS_GUI_ExternalCodeTest" LANGUAGES CXX)

include(CTest)

## OFF: find_package(OpenMSGUI), the package of the GUI layer itself.
## ON:  find_package(OpenMS COMPONENTS GUI), which the core's package delegates to OpenMSGUI
##      when the GUI layer is installed into the core's prefix.
option(OPENMS_GUI_VIA_CORE_PACKAGE "Find the GUI layer through find_package(OpenMS COMPONENTS GUI)." OFF)
## the directory the GUI package has to be found in (empty: not checked)
set(EXPECTED_OPENMSGUI_PREFIX "" CACHE PATH "Installation prefix the GUI layer must be found in.")

message(STATUS "Received CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

if(OPENMS_GUI_VIA_CORE_PACKAGE)
  find_package(OpenMS CONFIG REQUIRED COMPONENTS GUI)
  if(NOT OpenMS_GUI_FOUND OR NOT OpenMS_WITH_GUI)
    message(FATAL_ERROR "find_package(OpenMS COMPONENTS GUI) succeeded without setting OpenMS_GUI_FOUND and OpenMS_WITH_GUI")
  endif()
  if(NOT OpenMSGUI_FOUND)
    message(FATAL_ERROR "find_package(OpenMS COMPONENTS GUI) did not find the GUI layer through its package OpenMSGUI")
  endif()
else()
  find_package(OpenMSGUI CONFIG REQUIRED)
endif()
message(STATUS "Found OpenMSGUI ${OpenMSGUI_VERSION} at ${OpenMSGUI_DIR} (OpenMS ${OpenMS_VERSION} at ${OpenMS_DIR})")

#------------------------------------------------------------------------------
## Package contract

## the GUI layer belongs to the core of the same version
if(NOT OpenMSGUI_VERSION VERSION_EQUAL OpenMS_VERSION)
  message(FATAL_ERROR "OpenMSGUI ${OpenMSGUI_VERSION} was found with OpenMS ${OpenMS_VERSION}")
endif()
## ... it provides the namespaced imported target and the compatibility alias, and brings
## the core and CLI layers and the Qt modules of its link interface along
foreach(_target IN ITEMS OpenMS::OpenMS_GUI OpenMS_GUI OpenMS::OpenMS OpenMS::OpenMS_CLI Qt6::Core Qt6::Widgets)
  if(NOT TARGET ${_target})
    message(FATAL_ERROR "find_package(OpenMSGUI) did not provide the target ${_target}")
  endif()
endforeach()
get_target_property(_imported OpenMS::OpenMS_GUI IMPORTED)
if(NOT _imported)
  message(FATAL_ERROR "OpenMS::OpenMS_GUI is not an imported target")
endif()
if(NOT OpenMSGUI_QT_COMPONENTS)
  message(FATAL_ERROR "OpenMSGUI_QT_COMPONENTS is empty")
endif()
foreach(_module IN LISTS OpenMSGUI_QT_COMPONENTS)
  if(NOT TARGET Qt6::${_module})
    message(FATAL_ERROR "OpenMSGUI_QT_COMPONENTS lists ${_module}, but Qt6::${_module} was not found")
  endif()
endforeach()

## ... and the library is where the package says, in the expected installation
if(NOT IS_DIRECTORY "${OPENMS_GUI_LIB_DIR}")
  message(FATAL_ERROR "OPENMS_GUI_LIB_DIR='${OPENMS_GUI_LIB_DIR}' is not a directory")
endif()
get_filename_component(_gui_lib_dir "${OPENMS_GUI_LIB_DIR}" ABSOLUTE)
get_target_property(_configurations OpenMS::OpenMS_GUI IMPORTED_CONFIGURATIONS)
foreach(_configuration IN LISTS _configurations)
  get_target_property(_location OpenMS::OpenMS_GUI IMPORTED_LOCATION_${_configuration})
  get_filename_component(_location_dir "${_location}" DIRECTORY)
  if(NOT _location_dir STREQUAL _gui_lib_dir)
    message(FATAL_ERROR "OPENMS_GUI_LIB_DIR='${OPENMS_GUI_LIB_DIR}' but the ${_configuration} OpenMS_GUI library is ${_location}")
  endif()
endforeach()
if(EXPECTED_OPENMSGUI_PREFIX)
  get_filename_component(_expected "${EXPECTED_OPENMSGUI_PREFIX}" ABSOLUTE)
  string(FIND "${OpenMSGUI_DIR}/" "${_expected}/" _pos)
  if(NOT _pos EQUAL 0)
    message(FATAL_ERROR "OpenMSGUI was found at ${OpenMSGUI_DIR}, not in ${EXPECTED_OPENMSGUI_PREFIX}")
  endif()
endif()

#------------------------------------------------------------------------------
## a program using the GUI library (and through it the core and Qt)
add_executable(TestExternalCodeGUI TestExternalCodeGUI.cpp)
target_link_libraries(TestExternalCodeGUI PRIVATE OpenMS::OpenMS_GUI)
add_test(NAME TestExternalCodeGUI COMMAND TestExternalCodeGUI)
set_tests_properties(TestExternalCodeGUI PROPERTIES PASS_REGULAR_EXPRESSION "MultiGradient red-blue at 50")

## Windows has no RPATH: the DLLs of the GUI layer, the core and Qt are found through PATH
if(WIN32)
  set_property(TEST TestExternalCodeGUI APPEND PROPERTY ENVIRONMENT_MODIFICATION
    "PATH=path_list_prepend:${OPENMS_GUI_LIB_DIR}"
    "PATH=path_list_prepend:${OPENMS_LIB_DIR}"
    "PATH=path_list_prepend:$<TARGET_FILE_DIR:Qt6::Core>")
endif()
