# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Stephan Aiche, Chris Bielow, Timo Sachsenberg $
# --------------------------------------------------------------------------

project("OpenMS_GUI_tests")

#------------------------------------------------------------------------------
# The tests of the GUI layer (options in the top-level CMakeLists.txt):
#   class_tests  class tests of the GUI library        (ENABLE_CLASS_TESTING)
#   topp         tests of the GUI TOPP tools           (ENABLE_TOPP_TESTING)
#   toppas       TOPPAS pipelines via ExecutePipeline  (ENABLE_PIPELINE_TESTING)
#   external     installed-consumer test               (OPENMS_TEST_INSTALLED_CONSUMER)
#
# FuzzyDiff and the TOPP tools the pipelines run come from the OpenMS core
# (OPENMS_TOPP_BIN_DIR); tests that need what is not there are left out with a
# message. The example pipelines and data are those of the installed core
# (share/OpenMS/examples, install component 'examples').
#------------------------------------------------------------------------------

if(NOT "${PACKAGE_TYPE}" STREQUAL "none")
  message(WARNING "PACKAGE_TYPE specified along with enabled testing. Tests are only enabled when PACKAGE_TYPE is none. Ignoring tests.")
  return()
endif()

#------------------------------------------------------------------------------
# The run-time environment of every test that runs a GUI application or GUI TOPP
# tool of this build tree against the OpenMS core:
#  - OPENMS_TOOL_REGISTRY_PATH: the tool registry of the core does not list the GUI
#    TOPP tools, and TOPPBase refuses to start an unregistered tool. Not set when the
#    core's share/OpenMS/TOOLS already holds an OpenMS-GUI.tsv (a GUI layer installed
#    into that prefix): the tools would then be registered twice, which ToolHandler
#    rejects.
#  - QT_QPA_PLATFORM: no display is needed (ExecutePipeline creates a QApplication,
#    the GUI tests open windows); see OPENMS_TEST_QT_QPA_PLATFORM below.
#  - OPENMS_DATA_PATH: the last place libOpenMS looks for share/OpenMS, so it only
#    matters where the core is not at its compiled-in prefix (Windows, a relocated SDK).
#  - PATH: OPENMS_TOPP_BIN_DIR, where ExecutePipeline finds the TOPP tools of the
#    pipelines; on Windows also the DLLs of the core and Qt, and the Qt plugins.
#------------------------------------------------------------------------------
if(NOT "$ENV{QT_QPA_PLATFORM}" STREQUAL "")
  set(_qt_qpa_platform_default "")
else()
  set(_qt_qpa_platform_default "offscreen")
endif()
set(OPENMS_TEST_QT_QPA_PLATFORM "${_qt_qpa_platform_default}" CACHE STRING
    "Qt platform plugin the GUI tests run with (QT_QPA_PLATFORM). Empty: use the environment of ctest. Defaults to 'offscreen' unless QT_QPA_PLATFORM is set when configuring.")
unset(_qt_qpa_platform_default)

if(EXISTS "${OPENMS_DATA_DIR}/TOOLS/OpenMS-GUI.tsv")
  message(STATUS "The OpenMS installation already holds a GUI tool registry (${OPENMS_DATA_DIR}/TOOLS/OpenMS-GUI.tsv): "
                 "the tests run the GUI TOPP tools with that registry instead of the one of this build.")
  set(_openms_gui_test_registry "")
else()
  set(_openms_gui_test_registry "${OPENMS_TOOL_REGISTRY_BUILD_DIR}")
endif()
set(OPENMS_GUI_TEST_REGISTRY_PATH "${_openms_gui_test_registry}" CACHE INTERNAL "OPENMS_TOOL_REGISTRY_PATH of the tests")
unset(_openms_gui_test_registry)

# openms_gui_test_environment(<test>...)
# Sets the environment above on the given tests. The tests must be added with
# add_test(NAME ...) in the calling directory (the generator expressions are evaluated
# for those only).
function(openms_gui_test_environment)
  set(_env "OPENMS_DATA_PATH=${OPENMS_DATA_DIR}")
  if(OPENMS_GUI_TEST_REGISTRY_PATH)
    list(APPEND _env "OPENMS_TOOL_REGISTRY_PATH=${OPENMS_GUI_TEST_REGISTRY_PATH}")
  endif()
  if(OPENMS_TEST_QT_QPA_PLATFORM)
    list(APPEND _env "QT_QPA_PLATFORM=${OPENMS_TEST_QT_QPA_PLATFORM}")
  endif()
  set(_path "PATH=path_list_prepend:${OPENMS_TOPP_BIN_DIR}")
  if(WIN32)
    ## no RPATH: the DLLs of the core and of Qt are found through PATH
    list(APPEND _path
      "PATH=path_list_prepend:${OPENMS_BIN_DIR}"
      "PATH=path_list_prepend:${OPENMS_LIB_DIR}"
      "PATH=path_list_prepend:$<TARGET_FILE_DIR:Qt6::Core>")
    ## the build tree has no qt.conf: point Qt to its plugins (<plugins>/platforms/qwindows.dll)
    if(TARGET Qt6::QWindowsIntegrationPlugin)
      list(APPEND _env "QT_PLUGIN_PATH=$<PATH:GET_PARENT_PATH,$<TARGET_FILE_DIR:Qt6::QWindowsIntegrationPlugin>>")
    endif()
  endif()
  set_property(TEST ${ARGN} APPEND PROPERTY ENVIRONMENT ${_env})
  set_property(TEST ${ARGN} APPEND PROPERTY ENVIRONMENT_MODIFICATION ${_path})
endfunction()

## FuzzyDiff of the core, used by the tests that compare output files
set(OPENMS_FUZZYDIFF "${OPENMS_TOPP_BIN_DIR}/FuzzyDiff${CMAKE_EXECUTABLE_SUFFIX}")
if(NOT EXISTS "${OPENMS_FUZZYDIFF}")
  set(OPENMS_FUZZYDIFF "")
  message(STATUS "FuzzyDiff not found in OPENMS_TOPP_BIN_DIR='${OPENMS_TOPP_BIN_DIR}': "
                 "the tests that compare output files are left out.")
endif()

## The TOPP tools run by the tests (FuzzyDiff, the tools of the pipelines) read the tool
## registry of their own installation plus OPENMS_TOOL_REGISTRY_PATH. If that installation
## is not the core this build uses and was built with its own GUI, it registers the GUI
## TOPP tools as well, and every tool started with the registry of this build fails on the
## duplicate names (cmake/find_openms.cmake checks the same for the core itself).
file(GLOB _topp_bin_registries "${OPENMS_TOPP_BIN_DIR}/../share/OpenMS/TOOLS/*.tsv")
foreach(_registry IN LISTS _topp_bin_registries)
  file(STRINGS "${_registry}" _gui_tools_in_registry REGEX "^(ExecutePipeline|ImageCreator)\t")
  if(_gui_tools_in_registry AND OPENMS_GUI_TEST_REGISTRY_PATH)
    message(WARNING "The tool registry of the TOPP tools in OPENMS_TOPP_BIN_DIR, ${_registry}, lists the GUI "
            "TOPP tools (an OpenMS built with its own GUI): the pipeline tests will fail. Point "
            "OPENMS_TOPP_BIN_DIR to the TOPP tools of an OpenMS built without the GUI.")
  endif()
endforeach()
unset(_topp_bin_registries)
unset(_gui_tools_in_registry)

#------------------------------------------------------------------------------
# Class tests
if(ENABLE_CLASS_TESTING)
  ## the class-test framework (not shipped by the OpenMS installation)
  add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../testframework ${CMAKE_CURRENT_BINARY_DIR}/testframework)
  add_subdirectory(class_tests)
endif()

#------------------------------------------------------------------------------
# Tests of the GUI TOPP tools
if(ENABLE_TOPP_TESTING)
  add_subdirectory(topp)
endif()

#------------------------------------------------------------------------------
# TOPPAS pipeline tests
if(ENABLE_PIPELINE_TESTING)
  add_subdirectory(toppas)
endif()

#------------------------------------------------------------------------------
# Installed-consumer tests (install this build into a scratch prefix, then build an
# external project against it)
if(OPENMS_TEST_INSTALLED_CONSUMER)
  include(${CMAKE_CURRENT_SOURCE_DIR}/external/installed_consumer.cmake)
endif()
