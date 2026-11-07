# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

#------------------------------------------------------------------------------
# OpenMS-TOPP-GUI: the Qt GUI layer of OpenMS (the OpenMS_GUI library, TOPPView,
# TOPPAS, INIFileEditor and the Qt-based TOPP tools ExecutePipeline and
# ImageCreator), built against an installed OpenMS core of the same version.
#
#   cmake -S . -B build -DCMAKE_PREFIX_PATH="<OpenMS prefix or SDK>;<Qt prefix>"
#
# The OpenMS installation must provide the core and CLI layers (OpenMS::OpenMS,
# OpenMS::OpenMS_CLI), e.g. the OpenMS SDK of the matching release or nightly.
#------------------------------------------------------------------------------
cmake_minimum_required(VERSION 3.24 FATAL_ERROR)

## The version of this repository is the version of the OpenMS core it is built
## against (find_package(OpenMS ... EXACT) below). tools/update_version_numbers.sh
## bumps it together with the test data.
set(OPENMS_GUI_VERSION 3.7.0)

# The vcpkg toolchain must be selected before project(). The presets set it; a
# plain configure uses system packages and CMAKE_PREFIX_PATH.
option(OPENMS_USE_VCPKG "Use vcpkg manifest mode for the build dependencies (Boost)." OFF)
if(OPENMS_USE_VCPKG AND NOT CMAKE_TOOLCHAIN_FILE AND DEFINED ENV{VCPKG_ROOT})
  set(CMAKE_TOOLCHAIN_FILE "$ENV{VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake" CACHE FILEPATH "CMake toolchain file")
endif()

# Handle default build type
get_property(_openms_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _openms_multi_config AND NOT DEFINED CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build.")
endif()

project("OpenMS_TOPP_GUI" VERSION ${OPENMS_GUI_VERSION} LANGUAGES CXX)

## AutoMoc does not need the compiler's predefined macros (and collecting them is slow)
set(CMAKE_AUTOMOC_COMPILER_PREDEFINES OFF)

#------------------------------------------------------------------------------
# Module path
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/Modules")
## CMake looks for the NSIS script template in the module path.
list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/cmake/Windows")

if (MINGW OR MSYS)
  message(FATAL_ERROR "MSYS and/or MinGW are not supported! Please use a Visual Studio environment!")
endif()

#------------------------------------------------------------------------------
# Options
#------------------------------------------------------------------------------
option(ENABLE_CLASS_TESTING "Build the class tests of the GUI library." ON)
option(ENABLE_TOPP_TESTING "Add the tests of the GUI TOPP tools (ExecutePipeline, ImageCreator)." ON)
option(ENABLE_PIPELINE_TESTING "Add the TOPPAS pipeline tests (ExecutePipeline on the example workflows)." ON)
option(HAS_XSERVER "Indicates if a display is available (or QT_QPA_PLATFORM=offscreen is used). If OFF, the tests that open windows are disabled." ON)
option(ENABLE_DOCS "Add the documentation targets (doc, doc_gui_tools, ...)." ON)
option(ENABLE_TUTORIALS "Build the GUI code examples of the tutorials." ON)
option(NO_WEBENGINE_WIDGETS "Do not use QtWebEngineWidgets. Disables the JavaScript views in TOPPView." OFF)
option(OPENMS_TEST_INSTALLED_CONSUMER "Add a test that installs the GUI layer next to the OpenMS core and builds an external project against it." OFF)

#------------------------------------------------------------------------------
# Version information
#------------------------------------------------------------------------------
set(OPENMS_PACKAGE_VERSION_MAJOR "${PROJECT_VERSION_MAJOR}")
set(OPENMS_PACKAGE_VERSION_MINOR "${PROJECT_VERSION_MINOR}")
set(OPENMS_PACKAGE_VERSION_PATCH "${PROJECT_VERSION_PATCH}")
set(OPENMS_PACKAGE_VERSION "${PROJECT_VERSION}")
message(STATUS "Building OpenMS-TOPP-GUI ${OPENMS_PACKAGE_VERSION}")

#------------------------------------------------------------------------------
# Host directories (the names of the OpenMS build system, used by the moved code)
set(OPENMS_HOST_DIRECTORY "${PROJECT_SOURCE_DIR}")
set(OPENMS_HOST_BINARY_DIRECTORY "${PROJECT_BINARY_DIR}")

#------------------------------------------------------------------------------
# Compiler checks and flags
#------------------------------------------------------------------------------
include(cmake/min_compiler_versions.cmake)
include(cmake/compiler_flags.cmake)

if (NOT CMAKE_CXX_VISIBILITY_PRESET)
  set(CMAKE_CXX_VISIBILITY_PRESET "hidden")
endif()
set(CMAKE_VISIBILITY_INLINES_HIDDEN 1)

option(ENABLE_IPO "Enable interprocedural optimizations (LTO)" OFF)
if(ENABLE_IPO)
  include(CheckIPOSupported)
  check_ipo_supported(RESULT _ipo_supported OUTPUT _ipo_output)
  if(_ipo_supported)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
  else()
    message(SEND_ERROR "IPO/LTO is not supported: ${_ipo_output}")
  endif()
endif()

option(ADDRESS_SANITIZER "Enable AddressSanitizer mode (quite slow)." OFF)
include(${PROJECT_SOURCE_DIR}/cmake/AddressSanitizer.cmake)

# we build shared libraries
set(BUILD_SHARED_LIBS true)

#------------------------------------------------------------------------------
# CMake utilities
#------------------------------------------------------------------------------
include(${PROJECT_SOURCE_DIR}/cmake/build_system_macros.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/install_macros.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/doc_macros.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/add_library_macros.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/export_macros.cmake)
include(${PROJECT_SOURCE_DIR}/cmake/topp_tool_macros.cmake)

#------------------------------------------------------------------------------
# Package type
set(VALID_PACKAGE_TYPES "none" # make/make install
                        "deb"  # Debian package, installed on top of the openms package
                        "rpm"  # RPM package, installed on top of the openms package
                        "pkg"  # macOS productbuild installer, installed into the OpenMS folder
                        "dmg"  # macOS drag&drop image with self-contained app bundles
                        "nsis") # Windows installer, installed into the OpenMS installation
set(PACKAGE_TYPE "none" CACHE STRING "Package type: ${VALID_PACKAGE_TYPES}")
message(STATUS "Package type is '${PACKAGE_TYPE}'")
is_valid_package(${PACKAGE_TYPE})

## The install component of the GUI applications (and everything else that
## belongs to them at run time: the tool registry entry, the style sheet, ...).
set(OPENMS_GUI_APPLICATIONS_COMPONENT GUIApplications)

## macOS code signing and notarization configuration
##   SIGNING_IDENTITY - Developer ID Application certificate identity
##   SIGNING_EMAIL - Apple ID email for notarization
##   CPACK_PRODUCTBUILD_IDENTITY_NAME - Developer ID Installer certificate identity (for .pkg)
##   APPLE_APP_SPECIFIC_NOTARIZATION_PASSWORD environment variable - app-specific password
if("${PACKAGE_TYPE}" STREQUAL "dmg" OR "${PACKAGE_TYPE}" STREQUAL "pkg")
  if (NOT DEFINED SIGNING_IDENTITY OR "${SIGNING_IDENTITY}" STREQUAL "" OR "${SIGNING_IDENTITY}" STREQUAL "-")
    message(WARNING "Trying to create a macOS package without SIGNING_IDENTITY being set. "
                    "Using the ad hoc identity. The package will NOT be notarized.")
    set(CPACK_BUNDLE_APPLE_CERT_APP "-")
  else()
    set(CPACK_BUNDLE_APPLE_CERT_APP "${SIGNING_IDENTITY}")
    message(STATUS "Code signing identity: ${SIGNING_IDENTITY}")
  endif()
  if (NOT DEFINED SIGNING_EMAIL OR "${SIGNING_EMAIL}" STREQUAL "")
    message(STATUS "SIGNING_EMAIL not set. Notarization will be skipped.")
  endif()
endif()

#------------------------------------------------------------------------------
# Output directories. Everything that runs goes to bin/ (GUI applications, GUI
# TOPP tools, tests, documenters), so on Windows the DLLs only need to be
# copied there once.
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/bin")
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/lib")
set(OPENMS_BINARY_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
set(OPENMS_SHARE_DIR "${PROJECT_SOURCE_DIR}/share/OpenMS")

## The registry of the GUI TOPP tools, OpenMS-GUI.tsv. ToolHandler reads every *.tsv
## of share/OpenMS/TOOLS, so installed next to the core's OpenMS.tsv it adds these tools.
set(OPENMS_TOOL_REGISTRY_BUILD_DIR "${PROJECT_BINARY_DIR}/share/OpenMS/TOOLS")
set(OPENMS_TOOL_REGISTRY_BUILD_FILE "${OPENMS_TOOL_REGISTRY_BUILD_DIR}/OpenMS-GUI.tsv")

#------------------------------------------------------------------------------
# Installation directories. They must equal those of the OpenMS core: the GUI
# layer is installed into the core's prefix (libOpenMS resolves the share
# directory, the tool registry and the TOPP executables relative to the
# executable).
set(INSTALL_BIN_DIR bin CACHE PATH "Installation directory for executables")
set(INSTALL_SHARE_DIR share/OpenMS CACHE PATH "Installation directory for shared data")
set(INSTALL_DOC_DIR share/doc CACHE PATH "Installation directory for documentation")
set(INSTALL_INCLUDE_DIR include CACHE PATH "Installation directory for header files")
if(WIN32)
  set(DEF_INSTALL_CMAKE_DIR CMake)
  set(DEF_INSTALL_LIB_DIR bin)
else()
  set(DEF_INSTALL_CMAKE_DIR lib/cmake/OpenMSGUI)
  set(DEF_INSTALL_LIB_DIR lib)
endif()
set(INSTALL_CMAKE_DIR ${DEF_INSTALL_CMAKE_DIR} CACHE PATH "Installation directory for the CMake package of the GUI library")
set(INSTALL_LIB_DIR ${DEF_INSTALL_LIB_DIR} CACHE PATH "Installation directory for libraries")
set(INSTALL_PLUGIN_SUBDIR plugins CACHE PATH "Installation subdirectory under the lib dir for Qt plugins")
set(INSTALL_PLUGIN_DIR ${INSTALL_LIB_DIR}/${INSTALL_PLUGIN_SUBDIR})
file(RELATIVE_PATH INSTALL_LIB_PATH_REL_TO_BIN /${INSTALL_BIN_DIR} /${INSTALL_LIB_DIR})
if(INSTALL_LIB_PATH_REL_TO_BIN STREQUAL "")
  ## lib == bin (Windows): the plugins are next to the executables
  set(QT_PLUGIN_PATH_REL_TO_BIN ${INSTALL_PLUGIN_SUBDIR})
else()
  set(QT_PLUGIN_PATH_REL_TO_BIN ${INSTALL_LIB_PATH_REL_TO_BIN}/${INSTALL_PLUGIN_SUBDIR})
endif()

#------------------------------------------------------------------------------
# RPATH (as in the OpenMS core)
if(UNIX)
  if(NOT DEFINED CMAKE_SKIP_BUILD_RPATH)
    set(CMAKE_SKIP_BUILD_RPATH FALSE)
  endif()
  if(NOT DEFINED CMAKE_MACOSX_RPATH)
    set(CMAKE_MACOSX_RPATH TRUE)
  endif()
  if(NOT DEFINED CMAKE_BUILD_WITH_INSTALL_RPATH)
    set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
    set(CMAKE_BUILD_WITH_INSTALL_NAME_DIR FALSE)
  endif()

  # A plain installation finds the libraries it was linked against (the OpenMS
  # core, Qt) through their directories in the install RPATH. Packages are
  # installed into the core's prefix and use the relative RPATH below instead.
  if (NOT DEFINED CMAKE_INSTALL_RPATH_USE_LINK_PATH)
    if (APPLE)
      if (NOT "${PACKAGE_TYPE}" STREQUAL "pkg")
        set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
      endif()
    elseif ("${PACKAGE_TYPE}" STREQUAL "none")
      set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)
    endif()
  endif()

  if(NOT DEFINED CMAKE_INSTALL_RPATH)
    if (APPLE)
      if(NOT "${PACKAGE_TYPE}" STREQUAL "pkg")
        set(CMAKE_INSTALL_RPATH "@executable_path/${INSTALL_LIB_PATH_REL_TO_BIN}/;@loader_path/;${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
      else()
        set(CMAKE_INSTALL_RPATH "@executable_path/${INSTALL_LIB_PATH_REL_TO_BIN}/")
      endif()
    else()
      set(CMAKE_INSTALL_RPATH "$ORIGIN/${INSTALL_LIB_PATH_REL_TO_BIN}/")
    endif()
  endif()
endif()

if (MSVC)
  ## OpenMS_GUId.dll etc. in debug mode, like the core
  if(NOT DEFINED CMAKE_DEBUG_POSTFIX)
    set(CMAKE_DEBUG_POSTFIX "d")
  endif()
endif()

#------------------------------------------------------------------------------
# Dependencies: the installed OpenMS core, Boost and Qt
#------------------------------------------------------------------------------
include(cmake/third_party_notices.cmake)
include(cmake/find_openms.cmake)

if(ENABLE_DOCS)
  find_package(Doxygen)
endif()

#------------------------------------------------------------------------------
# The code
#------------------------------------------------------------------------------
add_subdirectory(src)

#------------------------------------------------------------------------------
# Documentation
#------------------------------------------------------------------------------
if(ENABLE_DOCS OR ENABLE_TUTORIALS)
  add_subdirectory(doc)
endif()

#------------------------------------------------------------------------------
# CMake package of the GUI library (OpenMSGUIConfig.cmake)
#------------------------------------------------------------------------------
openms_export_targets()
install_export_targets()

#------------------------------------------------------------------------------
# Installation and packaging
#------------------------------------------------------------------------------
include(cmake/third_party_licenses.cmake)

if(NOT "${PACKAGE_TYPE}" STREQUAL "none")
  include(cmake/package_general.cmake)
  if("${PACKAGE_TYPE}" STREQUAL "dmg")
    set(CPACK_GENERATOR "DragNDrop")
    include(cmake/package_dragndrop_dmg.cmake)
  elseif("${PACKAGE_TYPE}" STREQUAL "pkg")
    set(CPACK_GENERATOR "productbuild")
    include(cmake/package_mac_productbuild.cmake)
  elseif("${PACKAGE_TYPE}" STREQUAL "rpm")
    set(CPACK_GENERATOR "RPM")
    include(cmake/package_rpm.cmake)
  elseif("${PACKAGE_TYPE}" STREQUAL "deb")
    set(CPACK_GENERATOR "DEB")
    include(cmake/package_deb.cmake)
  elseif("${PACKAGE_TYPE}" STREQUAL "nsis")
    set(CPACK_GENERATOR "NSIS")
    include(cmake/package_nsis.cmake)
  endif()
  include(CPack)
  include(cmake/package_components.cmake)
endif()

## share/OpenMS/THIRD-PARTY-NOTICES-GUI.txt from the license files recorded above
openms_install_third_party_notices()

#------------------------------------------------------------------------------
# Final messages
#------------------------------------------------------------------------------
include(cmake/messages.cmake)
