# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Stephan Aiche, Julianus Pfeuffer $
# --------------------------------------------------------------------------

#------------------------------------------------------------------------------
# General definitions of the GUI packages (all package types).
#
# The packages of this repository are add-ons: they install the GUI layer into the
# installation of the OpenMS core of the same version (same prefix, same bin/, lib/ and
# share/OpenMS), because libOpenMS resolves the shared data, the tool registry and the
# TOPP executables relative to the executable. They must therefore never contain a
# file the core installs itself.
#------------------------------------------------------------------------------
set(CPACK_PACKAGE_NAME "OpenMS-GUI")
set(CPACK_PACKAGE_VENDOR "OpenMS.de")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "OpenMS GUI - TOPPView, TOPPAS and INIFileEditor for mass spectrometry")
set(CPACK_PACKAGE_VERSION "${OPENMS_PACKAGE_VERSION}")
set(CPACK_PACKAGE_VERSION_MAJOR "${OPENMS_PACKAGE_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${OPENMS_PACKAGE_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "${OPENMS_PACKAGE_VERSION_PATCH}")
## the folder of the core installation, which the packages install into
set(CPACK_PACKAGE_INSTALL_DIRECTORY "OpenMS-${OPENMS_PACKAGE_VERSION_FULLSTRING}")
set(CPACK_PACKAGE_DESCRIPTION_FILE ${PROJECT_SOURCE_DIR}/cmake/OpenMSPackageDescriptionFile.txt)
set(CPACK_RESOURCE_FILE_LICENSE ${PROJECT_SOURCE_DIR}/License.txt)
set(CPACK_RESOURCE_FILE_WELCOME ${PROJECT_SOURCE_DIR}/cmake/OpenMSPackageResourceWelcomeFile.txt)
set(CPACK_RESOURCE_FILE_README ${PROJECT_SOURCE_DIR}/cmake/OpenMSPackageResourceReadme.txt)
set(CPACK_STRIP_FILES TRUE) # to save some space in the installers

## The logo shown by the macOS installer
set(OPENMS_LOGOSMALL_NAME openms_logo_corner_small.png)

## Windows and macOS packages bundle Qt; the Linux packages depend on the Qt of the distribution.
if(WIN32 OR APPLE)
  set(OPENMS_GUI_BUNDLES_QT TRUE)
else()
  set(OPENMS_GUI_BUNDLES_QT FALSE)
endif()

## QtWebEngine needs its helper process (QtWebEngineProcess), resources and translations next
## to the libraries, which nothing here deploys. A runner that happens to have WebEngine must
## not produce a TOPPView that fails at startup.
if(OPENMS_GUI_BUNDLES_QT AND Qt6WebEngineWidgets_FOUND)
  message(FATAL_ERROR "Qt6WebEngineWidgets was found, but the ${PACKAGE_TYPE} package cannot deploy QtWebEngine. "
                      "Configure the package build with -DNO_WEBENGINE_WIDGETS=ON.")
endif()

#------------------------------------------------------------------------------
# Runtime dependencies (Qt and the libraries it needs)
#------------------------------------------------------------------------------
## Everything the OpenMS core ships is left out: its libraries (OpenMS, OpenMS_CLI,
## OpenSwathAlgo), the OpenMP runtime and every other file in the library and executable
## directories of the core installation this is built against (the libraries the core
## bundles). Otherwise the GUI package would overwrite them, a Debian package would
## conflict with the core's, and the Windows uninstaller of the GUI would delete them.
##
## PRE_EXCLUDE_REGEXES are matched against the names of the dependencies as the binaries
## record them (libOpenMS.so, @rpath/libOpenMS.dylib, openms.dll; on Windows in lower
## case), before CMake resolves them, so that their own dependencies are not followed.
## POST_EXCLUDE_REGEXES are matched against the resolved paths.
function(_openms_gui_regex_escape out_var text)
  string(REGEX REPLACE "([][+.*()^$?|\\\\{}])" "\\\\\\1" _escaped "${text}")
  set(${out_var} "${_escaped}" PARENT_SCOPE)
endfunction()

set(_core_pre_exclude
    ## the libraries of the core (OpenMS_GUI is built here and installed by library_gui)
    "(^|[/\\\\])(lib)?(openms|openms_cli|openswathalgo|openms_gui|OpenMS|OpenMS_CLI|OpenSwathAlgo|OpenMS_GUI)d?\\.(dll|dylib|so)"
    ## the OpenMP runtime of the core
    "(^|[/\\\\])(lib)?(omp|gomp|iomp5|vcomp[0-9]*d?)\\.")
set(_core_post_exclude "")
foreach(_core_dir IN ITEMS "${OPENMS_LIB_DIR}" "${OPENMS_BIN_DIR}")
  if(NOT IS_DIRECTORY "${_core_dir}")
    continue()
  endif()
  ## by path (also as the real path, in case the prefix is reached through a link) ...
  file(REAL_PATH "${_core_dir}" _core_dir_real)
  foreach(_dir IN ITEMS "${_core_dir}" "${_core_dir_real}")
    _openms_gui_regex_escape(_dir_regex "${_dir}")
    list(APPEND _core_post_exclude "^${_dir_regex}/")
  endforeach()
  ## ... and by name, so that a library of the same name found elsewhere (in the Qt or
  ## Homebrew prefix) is not shipped either: the installed core provides it.
  file(GLOB _core_files LIST_DIRECTORIES true RELATIVE "${_core_dir}"
       "${_core_dir}/*.dll" "${_core_dir}/*.dylib" "${_core_dir}/*.framework")
  foreach(_core_file IN LISTS _core_files)
    if(WIN32)
      string(TOLOWER "${_core_file}" _core_file)
    endif()
    _openms_gui_regex_escape(_name_regex "${_core_file}")
    if(_core_file MATCHES "\\.framework$")
      list(APPEND _core_pre_exclude "(^|/)${_name_regex}/")
    else()
      list(APPEND _core_pre_exclude "(^|[/\\\\])${_name_regex}$")
    endif()
  endforeach()
endforeach()
list(REMOVE_DUPLICATES _core_pre_exclude)
list(REMOVE_DUPLICATES _core_post_exclude)

if(WIN32)
  set(PRE_EXCLUDE
      ## system DLLs, direct dependencies of the GUI binaries
      "api-ms" "ext-ms"
      ## detected as dependencies, but cannot be resolved (CMake folds the names to lower case)
      "hvsi" "pdmutilities"
      ## the MSVC runtime, which the core installer ships (InstallRequiredSystemLibraries)
      "vcruntime" "msvcp" "concrt" "vccorlib" "ucrtbase")
  ## every DLL of C:\Windows\System32, however CMake spells the folder
  set(POST_EXCLUDE ".*[\\/][Ss][Yy][Ss][Tt][Ee][Mm]32[\\/].*")
elseif(APPLE)
  set(PRE_EXCLUDE "/usr/lib" "/System/")
  set(POST_EXCLUDE)
endif()
list(APPEND PRE_EXCLUDE ${_core_pre_exclude})
list(APPEND POST_EXCLUDE ${_core_post_exclude})
## the build tree of this project: OpenMS_GUI is installed by library_gui. Not on Windows:
## there the build copies the Qt DLLs next to the binaries (add_library_macros.cmake), and a
## DLL in the folder of the binary is resolved there first, so excluding the build tree
## would drop Qt from the package (OpenMS_GUI is excluded by name above). These copies are
## then also the first place searched for the dependencies of the Qt plugins (below):
## the same DLL found in two folders is a fatal conflict.
if(NOT WIN32)
  _openms_gui_regex_escape(_build_dir_regex "${PROJECT_BINARY_DIR}")
  list(APPEND POST_EXCLUDE "^${_build_dir_regex}/")
endif()

if(OPENMS_GUI_BUNDLES_QT)
  ## Where the dependencies are looked for: the prefixes of CMAKE_PREFIX_PATH and the Qt
  ## installation (on Windows, DLLs have no RPATH that would tell).
  list(TRANSFORM CMAKE_PREFIX_PATH APPEND "/bin" OUTPUT_VARIABLE _dep_bin_dirs)
  list(TRANSFORM CMAKE_PREFIX_PATH APPEND "/lib" OUTPUT_VARIABLE _dep_lib_dirs)
  set(RUNTIME_DEP_SEARCH_DIRS ${_dep_bin_dirs} ${_dep_lib_dirs})
  if(WIN32)
    list(PREPEND RUNTIME_DEP_SEARCH_DIRS "$<TARGET_FILE_DIR:OpenMS_GUI>")
  endif()
  if(QT6_INSTALL_PREFIX)
    list(APPEND RUNTIME_DEP_SEARCH_DIRS "${QT6_INSTALL_PREFIX}/bin" "${QT6_INSTALL_PREFIX}/lib")
  endif()

  ## The bundled libraries are writable by their owner only, like any installed library.
  ## The packaging steps that modify them (code signing on macOS) run as their owner.
  install(RUNTIME_DEPENDENCY_SET ${OPENMS_GUI_DEPS}
          DESTINATION ${INSTALL_LIB_DIR}
          PERMISSIONS
            OWNER_READ OWNER_WRITE OWNER_EXECUTE
            GROUP_READ GROUP_EXECUTE
            WORLD_READ WORLD_EXECUTE
          COMPONENT Dependencies
          PRE_EXCLUDE_REGEXES ${PRE_EXCLUDE}
          POST_EXCLUDE_REGEXES ${POST_EXCLUDE}
          DIRECTORIES ${RUNTIME_DEP_SEARCH_DIRS})
endif()

#------------------------------------------------------------------------------
# Third-party licenses of what the package bundles: Qt and, on macOS, the Homebrew
# formulae Qt comes from (cmake/third_party_licenses.cmake). They are listed in
# share/OpenMS/THIRD-PARTY-NOTICES-GUI.txt (cmake/third_party_notices.cmake), next to the
# THIRD-PARTY-NOTICES.txt of the core.
#------------------------------------------------------------------------------
if(OPENMS_GUI_BUNDLES_QT)
  set(_openms_homebrew_formulae "")
  set(_openms_homebrew_prefix "")
  if(APPLE)
    set(_openms_homebrew_paths)
    foreach(_openms_qt_component IN ITEMS Core ${OpenMS_GUI_QT_COMPONENTS})
      list(APPEND _openms_homebrew_paths "${Qt6${_openms_qt_component}_DIR}")
    endforeach()
    openms_homebrew_formulae_of(_openms_homebrew_formulae _openms_homebrew_prefix ${_openms_homebrew_paths})
  endif()
  openms_install_third_party_licenses(QT_VERSION "${Qt6Core_VERSION}"
                                      HOMEBREW_PREFIX "${_openms_homebrew_prefix}"
                                      HOMEBREW_FORMULAE ${_openms_homebrew_formulae})
endif()
