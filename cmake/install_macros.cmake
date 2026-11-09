# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Stephan Aiche, Julianus Pfeuffer $
# --------------------------------------------------------------------------

# a collection of wrapper for install functions that allows easier usage
# throughout the OpenMS build system

#------------------------------------------------------------------------------
# The installed OpenMS package is layered: the core (export set OpenMSTargets,
# components library/cmake), the CLI layer (OpenMSCLITargets, library_cli/cmake_cli),
# both installed by OpenMS, and the GUI layer built here:
#
#   layer  export set       libraries      cmake files   targets
#   GUI    OpenMSGUITargets library_gui    cmake_gui     OpenMS::OpenMS_GUI (links the CLI layer)
#
# The headers are in OpenMS_GUI_headers. The package of the GUI layer is OpenMSGUI
# (OpenMSGUIConfig.cmake, see cmake/export_macros.cmake).
set(OPENMS_GUI_EXPORT_SET "OpenMSGUITargets")
set(OPENMS_EXPORT_SETS ${OPENMS_GUI_EXPORT_SET})
set(${OPENMS_GUI_EXPORT_SET}_LIBRARY_COMPONENT library_gui)
set(${OPENMS_GUI_EXPORT_SET}_CMAKE_COMPONENT cmake_gui)

## The runtime dependency set of everything installed here. Packages install it
## (cmake/package_general.cmake) without what the OpenMS core ships itself.
set(OPENMS_GUI_DEPS OPENMS_GUI_DEPS)

#------------------------------------------------------------------------------
# Installs the library lib_target_name into the library component of its export
# set and adds it to that export set.
#
# install_library(<target> [HEADERS] [EXPORT_SET <set>])
#
# @param lib_target_name The target name of the library that should be installed
# @param EXPORT_SET      One of ${OPENMS_EXPORT_SETS}; OpenMSGUITargets when omitted
# @param HEADERS         Install the public HEADERS file set in <target>_headers
function(install_library lib_target_name)
    cmake_parse_arguments(_install_library "HEADERS" "EXPORT_SET" "" ${ARGN})
    if(_install_library_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "install_library(${lib_target_name}): unexpected arguments ${_install_library_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT _install_library_EXPORT_SET)
      set(_install_library_EXPORT_SET ${OPENMS_GUI_EXPORT_SET})
    endif()
    if(NOT _install_library_EXPORT_SET IN_LIST OPENMS_EXPORT_SETS)
      message(FATAL_ERROR "install_library(${lib_target_name}): unknown export set '${_install_library_EXPORT_SET}' (known: ${OPENMS_EXPORT_SETS})")
    endif()
    set(_component ${${_install_library_EXPORT_SET}_LIBRARY_COMPONENT})
    set(_header_install_args)
    if(_install_library_HEADERS)
      set(_header_install_args FILE_SET HEADERS DESTINATION ${INSTALL_INCLUDE_DIR}
        COMPONENT ${lib_target_name}_headers)
    endif()
    install(TARGETS ${lib_target_name}
      RUNTIME_DEPENDENCY_SET ${OPENMS_GUI_DEPS}
      EXPORT ${_install_library_EXPORT_SET}
      LIBRARY DESTINATION ${INSTALL_LIB_DIR} COMPONENT ${_component}
      ARCHIVE DESTINATION ${INSTALL_LIB_DIR} COMPONENT ${_component}
      RUNTIME DESTINATION ${INSTALL_LIB_DIR} COMPONENT ${_component}
      ${_header_install_args}
      )
    # MSVC writes the debug information of a DLL to a .pdb file next to it (in a Debug
    # or RelWithDebInfo build; a Release build has none, hence OPTIONAL).
    # TARGET_PDB_FILE is only defined for shared libraries and executables.
    get_target_property(_type ${lib_target_name} TYPE)
    if(MSVC AND _type STREQUAL "SHARED_LIBRARY")
      install(FILES $<TARGET_PDB_FILE:${lib_target_name}>
        DESTINATION ${INSTALL_LIB_DIR} COMPONENT ${_component} OPTIONAL)
    endif()
endfunction()

#------------------------------------------------------------------------------
# What every installed header may include, as regular expressions matched against the
# whole include name. A library adds the headers of its own PUBLIC dependencies with
# openms_add_library(... ALLOWED_PUBLIC_INCLUDES ...), e.g. Qt for the GUI layer.
set(OPENMS_PUBLIC_INCLUDE_ALLOWLIST
  "OpenMS/.*"                             # OpenMS' own headers
  "[a-z_]+"                               # the C++ standard library: <vector>, <string_view>, ...
  "sys/.*" "windows\\.h" "winternl\\.h"   # operating-system headers
  "omp\\.h")                              # OpenMP, a PUBLIC dependency of libOpenMS

#------------------------------------------------------------------------------
# Reject every include of an installed header that is not on the allowlist above.
# openms_validate_public_headers(<header>... [ALLOW <regex>...])
#
# All dependencies of OpenMS are installed into one prefix, so an include of a PRIVATE
# dependency resolves through a sibling package's include directory on the machine that
# builds OpenMS, and the compiler header checks pass. It only fails downstream, where the
# package is missing. An allowlist rather than a list of known private dependencies means
# that a dependency added later is rejected too, without anyone having to list it.
# Keep this configure-time guard independent of the header installation method.
function(openms_validate_public_headers)
  cmake_parse_arguments(PARSE_ARGV 0 _validate "" "" "ALLOW")
  set(_allowed ${OPENMS_PUBLIC_INCLUDE_ALLOWLIST} ${_validate_ALLOW})
  list(JOIN _allowed "|" _allowed_regex)
  set(_allowed_regex "^(${_allowed_regex})$")
  foreach(_header IN LISTS _validate_UNPARSED_ARGUMENTS)
    # Header lists are relative to the calling source directory.
    # Generated headers in the build tree may not exist yet at this point; they come from OpenMS'
    # own templates, so only what is already on disk is scanned.
    set(_header_to_scan "${_header}")
    if (NOT IS_ABSOLUTE "${_header_to_scan}")
      set(_header_to_scan "${CMAKE_CURRENT_SOURCE_DIR}/${_header_to_scan}")
    endif()
    if (EXISTS "${_header_to_scan}" AND NOT IS_DIRECTORY "${_header_to_scan}")
      file(STRINGS "${_header_to_scan}" _include_lines REGEX "^[ \t]*#[ \t]*include[ \t]*[<\"]")
      set(_rejected)
      foreach(_line IN LISTS _include_lines)
        string(REGEX REPLACE "^[ \t]*#[ \t]*include[ \t]*[<\"]([^>\"]*)[>\"].*$" "\\1" _include "${_line}")
        if (NOT _include MATCHES "${_allowed_regex}")
          list(APPEND _rejected "${_include}")
        endif()
      endforeach()
      if (_rejected)
        list(JOIN _rejected ", " _rejected)
        message(FATAL_ERROR "Installed header ${_header} includes ${_rejected}, which downstream "
                            "builds cannot rely on. For a PRIVATE dependency, keep the include in the .cpp file "
                            "or expose OpenMS types instead. For a PUBLIC one, which OpenMSGUIConfig.cmake "
                            "finds for consumers, allow its headers with "
                            "openms_add_library(... ALLOWED_PUBLIC_INCLUDES <regex>).")
      endif()
    endif()
  endforeach()
endfunction()

#------------------------------------------------------------------------------
# Installs the tool tool_target_name
#
# install_tool(<target> [COMPONENT <component>])
#
# @param tool_target_name The target name of the tool that should be installed
# @param COMPONENT        The install component; ${OPENMS_GUI_APPLICATIONS_COMPONENT}
#                         (see the top-level CMakeLists.txt) when omitted.
function(install_tool tool_target_name)
    cmake_parse_arguments(_install_tool "" "COMPONENT" "" ${ARGN})
    if(_install_tool_UNPARSED_ARGUMENTS)
      message(FATAL_ERROR "install_tool(${tool_target_name}): unexpected arguments ${_install_tool_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT _install_tool_COMPONENT)
      set(_install_tool_COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
    endif()
    install(TARGETS ${tool_target_name} RUNTIME_DEPENDENCY_SET ${OPENMS_GUI_DEPS}
      RUNTIME DESTINATION ${INSTALL_BIN_DIR} COMPONENT ${_install_tool_COMPONENT}
      BUNDLE DESTINATION ${INSTALL_BIN_DIR} COMPONENT ${_install_tool_COMPONENT}
      )
endfunction()

#------------------------------------------------------------------------------
# Installs a given directory
# @param directory The directory to install
# @param destination The destination (relative to the prefix) where it should be installed
# @param component The component to which to the directory belongs
macro(install_directory directory destination component)
    install(DIRECTORY ${directory}
      DESTINATION ${destination}
      COMPONENT ${component}
      FILE_PERMISSIONS      OWNER_WRITE OWNER_READ
                            GROUP_READ
                            WORLD_READ
      DIRECTORY_PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
                            GROUP_EXECUTE GROUP_READ
                            WORLD_EXECUTE WORLD_READ
      REGEX "^\\..*" EXCLUDE ## Exclude hidden files (svn, git, DSStore)
      REGEX ".*\\/\\..*" EXCLUDE ## Exclude hidden files in subdirectories
        )
endmacro()

#------------------------------------------------------------------------------
# Installs a given file
# @param directory The file to install
# @param destination The destination (relative to the prefix) where it should be installed
# @param component The component to which to the file belongs
macro(install_file file destination component)
    install(FILES ${file}
      DESTINATION ${destination}
      COMPONENT ${component})
endmacro()

#------------------------------------------------------------------------------
# Execute the given code while executing the install target
# @param code_snippet The code to execute
# @param component The component to which the code will be associated
macro(install_code code_snippet component)
    install(CODE ${code_snippet}
            COMPONENT ${component})
endmacro()

#------------------------------------------------------------------------------
# Installs the exported targets of the GUI layer, OpenMSGUITargets.cmake, in
# component cmake_gui. Consumers see the library as OpenMS::OpenMS_GUI; it refers
# to the core and CLI layers as OpenMS::OpenMS and OpenMS::OpenMS_CLI, which
# OpenMSGUIConfig.cmake finds first.
macro(install_export_targets )
    foreach(_export_set IN LISTS OPENMS_EXPORT_SETS)
      if(_OPENMS_EXPORT_TARGETS_${_export_set})
        install(EXPORT ${_export_set}
                NAMESPACE OpenMS::
                DESTINATION ${INSTALL_CMAKE_DIR}
                COMPONENT ${${_export_set}_CMAKE_COMPONENT})
      endif()
    endforeach()
endmacro()
