# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Installed-consumer tests (OPENMS_TEST_INSTALLED_CONSUMER), included by
# src/tests/CMakeLists.txt. Each step is one plain cmake/ctest invocation, chained
# through CTest fixtures:
#
#  1. GUIConsumer: install this build (components library_gui, OpenMS_GUI_headers,
#     cmake_gui, GUIApplications) into a scratch prefix below the build tree, then
#     configure, build and run src/tests/external against it with
#     find_package(OpenMSGUI), CMAKE_PREFIX_PATH=<scratch prefix>;<core prefix>;<Qt prefix>.
#  2. GUIConsumerViaCore, only when the core's OpenMSConfig.cmake delegates its
#     component GUI to the OpenMSGUI package: the installation of 1 merged with the
#     core's prefix (links, the core's prefix is not written to), and the same project
#     with find_package(OpenMS COMPONENTS GUI) against that prefix alone.
#------------------------------------------------------------------------------

# Only the toolchain of this build is forwarded to the consumer, as a consumer building
# with the same compiler and dependency provider would pass it; everything about OpenMS
# comes from the installed packages. OpenMP_ROOT is part of it: an OpenMS built with
# Homebrew's keg-only libomp needs it in every consumer (find_dependency(OpenMP)).
set(_configure_args)
foreach(_var IN ITEMS
    CMAKE_TOOLCHAIN_FILE VCPKG_INSTALLED_DIR VCPKG_TARGET_TRIPLET VCPKG_HOST_TRIPLET
    CMAKE_CXX_COMPILER CMAKE_MAKE_PROGRAM CMAKE_CXX_COMPILER_LAUNCHER
    CMAKE_MSVC_RUNTIME_LIBRARY CMAKE_OSX_ARCHITECTURES CMAKE_OSX_DEPLOYMENT_TARGET
    CMAKE_OSX_SYSROOT OpenMP_ROOT)
  if(DEFINED ${_var} AND NOT "${${_var}}" STREQUAL "")
    string(REPLACE ";" "$<SEMICOLON>" _value "${${_var}}")
    list(APPEND _configure_args "-D${_var}=${_value}")
  endif()
endforeach()
list(APPEND _configure_args -DCMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY=ON)
if(CMAKE_GENERATOR_PLATFORM)
  list(APPEND _configure_args -A "${CMAKE_GENERATOR_PLATFORM}")
endif()
if(CMAKE_GENERATOR_TOOLSET)
  list(APPEND _configure_args -T "${CMAKE_GENERATOR_TOOLSET}")
endif()

## the prefixes of the core (OpenMS_DIR is <prefix>/lib/cmake/OpenMS, <prefix>/CMake on
## Windows) and of Qt (Qt6_DIR is <prefix>/lib/cmake/Qt6, <prefix>/lib/<arch>/cmake/Qt6
## on Debian, <prefix>/share/Qt6 with vcpkg)
if(WIN32)
  get_filename_component(_core_prefix "${OpenMS_DIR}/.." ABSOLUTE)
else()
  get_filename_component(_core_prefix "${OpenMS_DIR}/../../.." ABSOLUTE)
endif()
get_filename_component(_qt_prefix "${Qt6_DIR}" ABSOLUTE)
if(_qt_prefix MATCHES "^(.+)/(lib(64)?(/[^/]+)?/cmake|share)/Qt6$")
  set(_qt_prefix "${CMAKE_MATCH_1}")
else()
  get_filename_component(_qt_prefix "${Qt6_DIR}/../../.." ABSOLUTE)
endif()

set(_consumer_root "${CMAKE_BINARY_DIR}/installed-consumer")
set(_gui_prefix "${_consumer_root}/prefix")
set(_gui_components library_gui OpenMS_GUI_headers cmake_gui GUIApplications)

# _openms_gui_consumer_chain(<name> <prefix list> <consumer build dir> <fixture required>
#                            [CONFIGURE_ARGS ...])
# <name>_configure, <name>_build and <name>_run of src/tests/external.
function(_openms_gui_consumer_chain name prefix_path consumer fixture)
  cmake_parse_arguments(PARSE_ARGV 4 _chain "" "" "CONFIGURE_ARGS")
  string(REPLACE ";" "$<SEMICOLON>" _prefix_path "${prefix_path}")
  add_test(NAME ${name}_configure
    COMMAND ${CMAKE_COMMAND} -S "${CMAKE_CURRENT_SOURCE_DIR}/external" -B "${consumer}"
            -G "${CMAKE_GENERATOR}" "-DCMAKE_BUILD_TYPE=$<CONFIG>"
            "-DCMAKE_PREFIX_PATH=${_prefix_path}"
            ${_chain_CONFIGURE_ARGS} ${_configure_args})
  set_tests_properties(${name}_configure PROPERTIES
    FIXTURES_REQUIRED ${fixture}
    FIXTURES_SETUP ${name}_configured)
  add_test(NAME ${name}_build
    COMMAND ${CMAKE_COMMAND} --build "${consumer}" --config $<CONFIG>)
  set_tests_properties(${name}_build PROPERTIES
    FIXTURES_REQUIRED ${name}_configured
    FIXTURES_SETUP ${name}_built)
  add_test(NAME ${name}_run
    COMMAND ${CMAKE_CTEST_COMMAND} --test-dir "${consumer}" -C $<CONFIG>
            --output-on-failure --no-tests=error)
  set_tests_properties(${name}_run PROPERTIES FIXTURES_REQUIRED ${name}_built)
  set_tests_properties(${name}_configure ${name}_build ${name}_run PROPERTIES LABELS installed_consumer)
endfunction()

#------------------------------------------------------------------------------
# 1. The GUI layer in a prefix of its own, next to the core's
#
# The prefix is emptied first because `cmake --install --component` only ever adds
# files: files of an earlier run would otherwise stay behind.
add_test(NAME GUIConsumer_clean
  COMMAND ${CMAKE_COMMAND} -E rm -rf "${_gui_prefix}" "${_consumer_root}/prefix-via-core"
          "${_consumer_root}/build" "${_consumer_root}/build-via-core")
set_tests_properties(GUIConsumer_clean PROPERTIES FIXTURES_SETUP GUIConsumer_cleaned)
set(_install_tests)
foreach(_component IN LISTS _gui_components)
  add_test(NAME GUIConsumer_install_${_component}
    COMMAND ${CMAKE_COMMAND} --install "${CMAKE_BINARY_DIR}" --config $<CONFIG>
            --prefix "${_gui_prefix}" --component ${_component})
  list(APPEND _install_tests GUIConsumer_install_${_component})
endforeach()
# each `cmake --install --component <c>` writes install_manifest_<c>.txt of this build tree
set_tests_properties(${_install_tests} PROPERTIES
  FIXTURES_REQUIRED GUIConsumer_cleaned
  FIXTURES_SETUP GUIConsumer_installed
  RESOURCE_LOCK openms_gui_installed_consumer_install)
set_tests_properties(GUIConsumer_clean ${_install_tests} PROPERTIES LABELS installed_consumer)

_openms_gui_consumer_chain(GUIConsumer
  "${_gui_prefix};${_core_prefix};${_qt_prefix};${CMAKE_PREFIX_PATH}"
  "${_consumer_root}/build"
  GUIConsumer_installed
  CONFIGURE_ARGS "-DEXPECTED_OPENMSGUI_PREFIX=${_gui_prefix}")

#------------------------------------------------------------------------------
# 2. The GUI layer installed into the core's prefix, found through the core's package
file(STRINGS "${OpenMS_DIR}/OpenMSConfig.cmake" _core_delegates_gui
     REGEX "(find_package|find_dependency)[ \t]*\\([ \t]*OpenMSGUI[ \t)]")
if(_core_delegates_gui)
  set(_merged_prefix "${_consumer_root}/prefix-via-core")
  ## only what a CMake consumer of the libraries reads from the core's prefix
  add_test(NAME GUIConsumerViaCore_merge
    COMMAND ${CMAKE_COMMAND} "-DDEST=${_merged_prefix}"
            "-DSOURCES=${_gui_prefix}$<SEMICOLON>${_core_prefix}"
            "-DENTRIES=bin$<SEMICOLON>lib$<SEMICOLON>include$<SEMICOLON>CMake"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/external/merge_prefixes.cmake")
  set_tests_properties(GUIConsumerViaCore_merge PROPERTIES
    FIXTURES_REQUIRED GUIConsumer_installed
    FIXTURES_SETUP GUIConsumerViaCore_merged
    LABELS installed_consumer)
  _openms_gui_consumer_chain(GUIConsumerViaCore
    "${_merged_prefix};${_qt_prefix};${CMAKE_PREFIX_PATH}"
    "${_consumer_root}/build-via-core"
    GUIConsumerViaCore_merged
    CONFIGURE_ARGS "-DOPENMS_GUI_VIA_CORE_PACKAGE=ON" "-DEXPECTED_OPENMSGUI_PREFIX=${_merged_prefix}")
else()
  message(STATUS "GUIConsumerViaCore is left out: ${OpenMS_DIR}/OpenMSConfig.cmake does not delegate "
                 "the component GUI to the OpenMSGUI package (an OpenMS from before the split).")
endif()

unset(_configure_args)
unset(_core_prefix)
unset(_qt_prefix)
unset(_consumer_root)
unset(_gui_prefix)
unset(_gui_components)
unset(_install_tests)
unset(_merged_prefix)
unset(_core_delegates_gui)
