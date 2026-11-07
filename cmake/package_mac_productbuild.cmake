# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Julianus Pfeuffer $
# --------------------------------------------------------------------------

## The macOS installer of the GUI (productbuild). It installs into the folder of the OpenMS
## core package of the same version, /Applications/OpenMS-<full version>: the app bundles
## into its root (next to lib/), ExecutePipeline and ImageCreator into its bin/, the GUI
## library, Qt and its plugins into its lib/. The bundles are not self-contained: they load
## Qt and the OpenMS libraries from lib/.
##
## For info about this CPack generator and its capabilities, see the CMake documentation
## For info about productbuild and the flat package format see https://matthew-brett.github.io/docosx/flat_packages.html

## The folder of the core package: its name is "OpenMS-", not "${CPACK_PACKAGE_NAME}-".
set(CPACK_PACKAGING_INSTALL_PREFIX "/Applications/OpenMS-${OPENMS_PACKAGE_VERSION_FULLSTRING}")

## The component plist that keeps the installer from relocating the app bundles; it needs
## the install prefix (APPLICATIONS_COMPONENT_PLIST, used by package_components.cmake).
include(${PROJECT_SOURCE_DIR}/cmake/generate_applications_component_plist.cmake)

## The component packages are de.openms.gui.<component>, distinct from the core's
## de.openms.<component>.
set(CPACK_PRODUCTBUILD_IDENTIFIER "de.openms.gui")
set(CPACK_PRODUCTBUILD_RESOURCES_DIR ${PROJECT_SOURCE_DIR}/cmake/MacOSX)
set(CPACK_PRODUCTBUILD_BACKGROUND ${OPENMS_LOGOSMALL_NAME})
set(CPACK_PRODUCTBUILD_BACKGROUND_ALIGNMENT "bottomleft")
set(CPACK_PRODUCTBUILD_BACKGROUND_SCALING "none")

## Only the system domain (/Applications of the chosen volume): the GUI has to go where the
## core is, and the installation check of the Distribution file (below) can only look for it
## there; an installation into the user's home could end up next to no core at all.
set(CPACK_PRODUCTBUILD_DOMAINS TRUE)
set(CPACK_PRODUCTBUILD_DOMAINS_ANYWHERE TRUE)
set(CPACK_PRODUCTBUILD_DOMAINS_ROOT TRUE)
set(CPACK_PRODUCTBUILD_DOMAINS_USER FALSE)

## The Distribution file comes from cmake/Modules/CPack.distribution.dist.in: CPack looks for
## that template in CMAKE_MODULE_PATH before its own. Ours is CMake's plus a <volume-check>,
## whose script accepts a volume only if the core is installed there (lib/libOpenMS.dylib
## under the install prefix), and which holds the <allowed-os-versions>: the installer refuses
## a macOS older than the deployment target, which package builds set through
## MACOSX_DEPLOYMENT_TARGET. Only CPACK_* variables reach the template; CPack copies them into
## CPackConfig.cmake without escaping, so they contain no double quotes.
string(REGEX REPLACE "^/" "" _openms_core_library "${CPACK_PACKAGING_INSTALL_PREFIX}/${INSTALL_LIB_DIR}/libOpenMS.dylib")
## a JavaScript string literal in single quotes, in a CDATA section
string(REPLACE "\\" "\\\\" _openms_core_library "${_openms_core_library}")
string(REPLACE "'" "\\'" _openms_core_library "${_openms_core_library}")
string(REPLACE "]]>" "]]\\x3e" _openms_core_library "${_openms_core_library}")
set(CPACK_OPENMS_CORE_LIBRARY "${_openms_core_library}")
string(REGEX REPLACE "[^A-Za-z0-9._+~-]" "_" CPACK_OPENMS_VERSION "${OPENMS_PACKAGE_VERSION_FULLSTRING}")
if(CMAKE_OSX_DEPLOYMENT_TARGET)
  set(CPACK_OPENMS_ALLOWED_OS_VERSIONS
      "<allowed-os-versions><os-version min='${CMAKE_OSX_DEPLOYMENT_TARGET}'/></allowed-os-versions>")
else()
  set(CPACK_OPENMS_ALLOWED_OS_VERSIONS "")
  message(WARNING "CMAKE_OSX_DEPLOYMENT_TARGET is not set, so the installer will not check the macOS version. Set MACOSX_DEPLOYMENT_TARGET to the macOS the core package targets.")
endif()

if(NOT DEFINED CPACK_PRODUCTBUILD_IDENTITY_NAME)
  message(WARNING "CPACK_PRODUCTBUILD_IDENTITY_NAME not set. PKG will not be signed. Make sure to specify an identity with a Developer ID: Installer certificate (not Application certificate).")
endif()

set(MACOS_TARGET_ARCHS ${CMAKE_OSX_ARCHITECTURES})
if (NOT MACOS_TARGET_ARCHS)
  # Warning: if cmake is a subprocess of a process that is run under Rosetta, it will yield
  #  x86_64 (but probably also build for it. Therefore it should be fine.)
  set(MACOS_TARGET_ARCHS ${CMAKE_HOST_SYSTEM_PROCESSOR})
endif()
if (MACOS_TARGET_ARCHS STREQUAL "x86_64")
  set(ARCH_SUFFIX "Intel")
elseif (MACOS_TARGET_ARCHS STREQUAL "arm64")
  set(ARCH_SUFFIX "Silicon")
elseif ("x86_64" IN_LIST MACOS_TARGET_ARCHS AND "arm64" IN_LIST MACOS_TARGET_ARCHS)
  set(ARCH_SUFFIX "Universal")
else ()
  set(ARCH_SUFFIX "Unknown")
  message(WARNING "Couldn't determine MACOS_TARGET_ARCHS.")
endif()

## The core's file name with "OpenMS-" replaced by "OpenMS-GUI-"
if((DEFINED ENV{CPACK_PACKAGE_FILE_NAME}) AND (NOT "$ENV{CPACK_PACKAGE_FILE_NAME}" STREQUAL ""))
  set(CPACK_PACKAGE_FILE_NAME "$ENV{CPACK_PACKAGE_FILE_NAME}")
else()
  set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${OPENMS_PACKAGE_VERSION_FULLSTRING}-macOS-${ARCH_SUFFIX}")
endif()

#------------------------------------------------------------------------------
# Fixing the load paths and signing
#------------------------------------------------------------------------------
## productbuild installs every component into a staging prefix of its own, so each
## component fixes and signs what it holds itself. Signing has to come after fixing, which
## invalidates signatures. The app bundles are fixed and signed in add_mac_bundle.cmake,
## when they are installed (their install rules run before the ones here).
## fix_dependencies.rb only rewrites the load paths to @rpath/<name> (-n -c): the runtime
## dependency set (package_general.cmake) has collected the libraries already.
set(_openms_fix "${OPENMS_HOST_DIRECTORY}/cmake/MacOSX/fix_dependencies.rb")
## A secure timestamp is only requested for a real identity ('-' signs ad hoc, without one)
if("${CPACK_BUNDLE_APPLE_CERT_APP}" STREQUAL "-")
  set(_openms_codesign_timestamp "")
else()
  set(_openms_codesign_timestamp "--timestamp")
endif()
## codesign every file under <dir> (no symbolic links) with the identifier <prefix>.<file name>
macro(_openms_gui_sign_files _dir _id_prefix _component)
  install(CODE "
    file(GLOB_RECURSE _sign_files LIST_DIRECTORIES false \"\${CMAKE_INSTALL_PREFIX}/${_dir}/*\")
    foreach(_sign_file IN LISTS _sign_files)
      if(IS_SYMLINK \"\${_sign_file}\")
        continue()
      endif()
      get_filename_component(_sign_name \"\${_sign_file}\" NAME)
      execute_process(COMMAND codesign --force --options runtime ${_openms_codesign_timestamp} -i ${_id_prefix}.\${_sign_name} --sign \"${CPACK_BUNDLE_APPLE_CERT_APP}\" \"\${_sign_file}\"
                      RESULT_VARIABLE _sign_result OUTPUT_VARIABLE _sign_out ERROR_VARIABLE _sign_out)
      message(STATUS \"\${_sign_out}\")
      if(NOT _sign_result EQUAL 0)
        message(FATAL_ERROR \"codesign failed for \${_sign_file} (\${_sign_result})\")
      endif()
    endforeach()"
    COMPONENT ${_component})
endmacro()
## fix_dependencies.rb <args>; fails the installation when the script fails (a function:
## the arguments refer to \${CMAKE_INSTALL_PREFIX}, which a macro would expand here)
function(_openms_gui_fix_dependencies _component)
  install(CODE "
    execute_process(COMMAND ${_openms_fix} ${ARGN} RESULT_VARIABLE _fix_result)
    if(NOT _fix_result EQUAL 0)
      message(FATAL_ERROR \"fix_dependencies.rb failed (\${_fix_result})\")
    endif()"
    COMPONENT ${_component})
endfunction()

## libOpenMS_GUI
_openms_gui_fix_dependencies(library_gui -l \${CMAKE_INSTALL_PREFIX}/${INSTALL_LIB_DIR}/ -e @rpath/ -n -c)
_openms_gui_sign_files(${INSTALL_LIB_DIR} de.openms.TOPP.libs library_gui)

## Qt and the libraries it needs, the Qt plugins
_openms_gui_fix_dependencies(Dependencies -l \${CMAKE_INSTALL_PREFIX}/${INSTALL_LIB_DIR}/ -p \${CMAKE_INSTALL_PREFIX}/${INSTALL_PLUGIN_DIR}/ -e @rpath/ -n -c)
_openms_gui_sign_files(${INSTALL_LIB_DIR} de.openms.TOPP.libs Dependencies)

## ExecutePipeline, ImageCreator
_openms_gui_fix_dependencies(${OPENMS_GUI_APPLICATIONS_COMPONENT} -b \${CMAKE_INSTALL_PREFIX}/${INSTALL_BIN_DIR}/ -e @rpath/ -n -c)
_openms_gui_sign_files(${INSTALL_BIN_DIR} de.openms.TOPP ${OPENMS_GUI_APPLICATIONS_COMPONENT})

## The components of the package (productbuild installs each listed component by name,
## EXCLUDE_FROM_ALL or not). The headers and the CMake package are offered unselected.
set(CPACK_COMPONENTS_ALL Dependencies library_gui ${OPENMS_GUI_APPLICATIONS_COMPONENT}
                         OpenMS_GUI_headers cmake_gui)
if(ENABLE_DOCS)
  list(APPEND CPACK_COMPONENTS_ALL doc_gui)
endif()

## Create own target because you cannot "depend" on the internal target 'package'
add_custom_target(dist
  COMMAND cpack -G ${CPACK_GENERATOR}
  COMMENT "Building ${CPACK_GENERATOR} package"
)
