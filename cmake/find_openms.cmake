# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Julianus Pfeuffer, Timo Sachsenberg $
# --------------------------------------------------------------------------

#------------------------------------------------------------------------------
# The dependencies of the GUI layer:
#   - the installed OpenMS core with its CLI layer (OpenMS::OpenMS, OpenMS::OpenMS_CLI),
#     of exactly the version of this repository: the GUI is compiled against its headers
#   - Qt 6
# Point CMAKE_PREFIX_PATH (or OpenMS_DIR) at the OpenMS installation, e.g. the OpenMS SDK.
#------------------------------------------------------------------------------

## An OpenMS whose prefix already holds an installed GUI layer would load its targets
## (OpenMS::OpenMS_GUI) as well; this build provides that target itself.
set(OpenMS_IGNORE_GUI_LAYER TRUE)
find_package(OpenMS ${OPENMS_PACKAGE_VERSION} EXACT CONFIG REQUIRED COMPONENTS CLI)

## A core from before the split may have been built with its own GUI library. Its
## imported OpenMS::OpenMS_GUI would clash with the library built here, and its installed
## headers would compete with those of this source tree.
if(TARGET OpenMS::OpenMS_GUI)
  message(FATAL_ERROR "The OpenMS installation in ${OpenMS_DIR} already includes a GUI library "
          "(OpenMS::OpenMS_GUI). Build OpenMS-TOPP-GUI against an OpenMS installation without it "
          "(an OpenMS built without WITH_GUI, or installed without the components library_gui and "
          "cmake_gui, e.g. the OpenMS SDK).")
endif()
## The same for a core whose tool registry lists the GUI TOPP tools (an OpenMS built with
## WITH_GUI=ON registers them in its OpenMS.tsv even when the GUI library is not installed).
## ToolHandler refuses to start any tool when a name is registered twice, so with the
## registry of this layer next to it every OpenMS tool would fail.
## The registry of this layer itself (OpenMS-GUI.tsv, there when the GUI layer is already
## installed into the core's prefix) lists them as well and is not checked.
file(GLOB _openms_core_registries "${OPENMS_DATA_DIR}/TOOLS/*.tsv")
list(FILTER _openms_core_registries EXCLUDE REGEX "/OpenMS-GUI\\.tsv$")
foreach(_registry IN LISTS _openms_core_registries)
  file(STRINGS "${_registry}" _gui_tools_in_core REGEX "^(ExecutePipeline|ImageCreator)\t")
  if(_gui_tools_in_core)
    message(FATAL_ERROR "The tool registry of the OpenMS installation, ${_registry}, already lists the "
            "GUI TOPP tools (ExecutePipeline, ImageCreator): that OpenMS was built with its own GUI "
            "(WITH_GUI=ON). Build OpenMS-TOPP-GUI against an OpenMS built without the GUI.")
  endif()
endforeach()

message(STATUS "Building against OpenMS ${OpenMS_VERSION} in ${OpenMS_DIR}")
message(STATUS "  shared data of that installation: ${OPENMS_DATA_DIR}")
message(STATUS "  executables of that installation: ${OPENMS_BIN_DIR}")

#------------------------------------------------------------------------------
# The full version string (e.g. 3.7.0-pre-nightly-2026-11-06). The packages are installed
# into the folder of the core installation, whose name carries this string, so the core's
# string is used whenever it is known: exported by its OpenMSConfig.cmake, or given with
# -DOPENMS_CORE_VERSION_FULLSTRING (CI takes it from the name of the core installer).
# Only otherwise is it derived from this repository's git state, as the core does.
set(OPENMS_CORE_VERSION_FULLSTRING "" CACHE STRING
    "Full version string of the OpenMS core installation (e.g. 3.7.0-pre-nightly-2026-11-06). Empty: take it from the core's CMake package, or derive it from git.")

include(GetGitRevisionDescription)
option(GIT_TRACKING "Embed git information (branch, revision) into the version strings of the packages." ON)
if(GIT_TRACKING)
  git_archival_info("${PROJECT_SOURCE_DIR}/.git_archival.txt"
    _gui_archival_describe OPENMS_GIT_SHORT_SHA1 OPENMS_GIT_LC_DATE OPENMS_GIT_ARCHIVAL_FOUND)
  if(OPENMS_GIT_ARCHIVAL_FOUND)
    if(_gui_archival_describe STREQUAL "v${OPENMS_PACKAGE_VERSION}")
      set(OPENMS_GIT_SHORT_REFSPEC "${_gui_archival_describe}")
    else()
      set(OPENMS_GIT_SHORT_REFSPEC "exported")
    endif()
    set(OPENMS_GIT_INFO_FOUND TRUE)
  else()
    git_short_info(OPENMS_GIT_SHORT_REFSPEC OPENMS_GIT_SHORT_SHA1 OPENMS_GIT_LC_DATE OPENMS_GIT_INFO_FOUND)
    if(OPENMS_GIT_INFO_FOUND AND OPENMS_GIT_SHORT_REFSPEC STREQUAL "HEAD")
      git_get_exact_tag(_gui_release_tag --tags --match "v${OPENMS_PACKAGE_VERSION}")
      if(_gui_release_tag STREQUAL "v${OPENMS_PACKAGE_VERSION}")
        set(OPENMS_GIT_SHORT_REFSPEC "${_gui_release_tag}")
      endif()
    endif()
  endif()
endif()
if(NOT GIT_TRACKING OR NOT OPENMS_GIT_INFO_FOUND)
  if(NOT DEFINED OPENMS_GIT_SHORT_SHA1)
    set(OPENMS_GIT_SHORT_SHA1 "exported")
  endif()
  if(NOT DEFINED OPENMS_GIT_SHORT_REFSPEC OR OPENMS_GIT_SHORT_REFSPEC STREQUAL "")
    set(OPENMS_GIT_SHORT_REFSPEC "exported")
  endif()
  if(NOT DEFINED OPENMS_GIT_LC_DATE)
    set(OPENMS_GIT_LC_DATE "1970-01-01")
  endif()
endif()

if(OPENMS_CORE_VERSION_FULLSTRING)
  set(OPENMS_PACKAGE_VERSION_FULLSTRING "${OPENMS_CORE_VERSION_FULLSTRING}")
  set(_gui_fullstring_source "OPENMS_CORE_VERSION_FULLSTRING")
elseif(DEFINED OpenMS_VERSION_FULLSTRING AND NOT OpenMS_VERSION_FULLSTRING STREQUAL "")
  set(OPENMS_PACKAGE_VERSION_FULLSTRING "${OpenMS_VERSION_FULLSTRING}")
  set(_gui_fullstring_source "the OpenMS CMake package")
else()
  ## derived from this repository's git state, exactly as the core does it
  if(OPENMS_GIT_SHORT_REFSPEC MATCHES "disabled" OR OPENMS_GIT_SHORT_REFSPEC MATCHES "exported")
    string(TIMESTAMP _gui_date "%Y%m%d")
    set(OPENMS_PACKAGE_VERSION_FULLSTRING "${OPENMS_PACKAGE_VERSION}-pre-${OPENMS_GIT_SHORT_REFSPEC}-${_gui_date}")
  elseif(OPENMS_GIT_SHORT_REFSPEC MATCHES "release*" OR OPENMS_GIT_SHORT_REFSPEC MATCHES "master"
         OR OPENMS_GIT_SHORT_REFSPEC STREQUAL "v${OPENMS_PACKAGE_VERSION}")
    set(OPENMS_PACKAGE_VERSION_FULLSTRING "${OPENMS_PACKAGE_VERSION}")
  else()
    string(REGEX REPLACE "[/_]" "-" _gui_refspec "${OPENMS_GIT_SHORT_REFSPEC}")
    string(REGEX REPLACE " .*$" "" _gui_lc_date "${OPENMS_GIT_LC_DATE}")
    set(OPENMS_PACKAGE_VERSION_FULLSTRING "${OPENMS_PACKAGE_VERSION}-pre-${_gui_refspec}-${_gui_lc_date}")
  endif()
  set(_gui_fullstring_source "the git state of this repository")
  if(NOT "${PACKAGE_TYPE}" STREQUAL "none")
    message(WARNING "The full version string of the OpenMS core is unknown (its CMake package does not "
            "export it), so the package takes '${OPENMS_PACKAGE_VERSION_FULLSTRING}' from ${_gui_fullstring_source}. "
            "The packages are installed into the folder of the core installation, whose name carries the "
            "core's string: pass -DOPENMS_CORE_VERSION_FULLSTRING=<string of the core installer>.")
  endif()
endif()
## the part after "<version>-pre-" (empty for a release)
string(REGEX REPLACE "^${OPENMS_PACKAGE_VERSION}(-pre-)?" "" OPENMS_PACKAGE_VERSION_PRERELEASE_IDENTIFIER
       "${OPENMS_PACKAGE_VERSION_FULLSTRING}")
message(STATUS "  full version string ${OPENMS_PACKAGE_VERSION_FULLSTRING} (from ${_gui_fullstring_source})")

#------------------------------------------------------------------------------
# Where the core's TOPP tools are (FuzzyDiff and the tools the TOPPAS pipelines run).
# The OpenMS SDK carries no executables; the tests that need them are then left out.
set(OPENMS_TOPP_BIN_DIR "${OPENMS_BIN_DIR}" CACHE PATH
    "Directory with the TOPP tools of the OpenMS core (FuzzyDiff, FileInfo, ...), used by the tests.")

#------------------------------------------------------------------------------
# Qt
include(${PROJECT_SOURCE_DIR}/cmake/cmake_findQt.cmake)
