# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Stephan Aiche, Chris Bielow, Julianus Pfeuffer $
# --------------------------------------------------------------------------

# required modules
include(CMakeParseArguments)
include(GenerateExportHeader)
include(CheckLibArchitecture)

#------------------------------------------------------------------------------
## export a single option indicating if libraries should be build as unity
## build
option(ENABLE_UNITYBUILD "Build the libraries as unity builds: batches of OPENMS_UNITY_BUILD_BATCH_SIZE source files are compiled as one translation unit (CMake UNITY_BUILD)." OFF)
set(OPENMS_UNITY_BUILD_BATCH_SIZE 8 CACHE STRING
    "With ENABLE_UNITYBUILD: number of source files combined into one translation unit (0: all of a library)")
option(OPENMS_VERIFY_INTERFACE_HEADER_SETS
  "Compile OpenMS public headers individually with the all_verify_interface_header_sets target" OFF)

#------------------------------------------------------------------------------
## Unity builds (ENABLE_UNITYBUILD)
##
## Most of the compile time of an OpenMS source file goes into parsing the headers it
## includes, and neighbouring files include mostly the same ones. Compiling batches of
## OPENMS_UNITY_BUILD_BATCH_SIZE files (in source list order, i.e. mostly from the same
## directory) as one translation unit parses those headers once per batch. A change to one
## file recompiles its batch, so small batches keep incremental builds and parallelism.
##
## Files cannot be combined if their file-local names (anonymous namespaces, static
## functions, macros) collide; such files are excluded with the source file property
## SKIP_UNITY_BUILD_INCLUSION in the library's CMakeLists.txt.

#------------------------------------------------------------------------------
# openms_add_library()
# Create an OpenMS library, install it, register for export of targets, and
# export all required variables for later usage in the build system.
#
# Signature:
# openms_add_library(TARGET_NAME  OpenMS
#                    SOURCE_FILES  <source files to build the library>
#                    HEADER_FILES  <header files associated to the library>
#                                  (will be installed with the library)
#                    BASE_DIRS <source and binary include roots of the public headers>
#                    PRIVATE_INCLUDES <list of include directories that will be used for compilation but that will not be exposed to other libraries>
#                    EXTERNAL_INCLUDES <list of external include directories for the library>
#                                      (will be added with -isystem if available)
#                    LINK_LIBRARIES <list of libraries used when linking the library>
#                    PRIVATE_LINK_LIBRARIES <list of internal libraries used when linking the library>
#                    ALLOWED_PUBLIC_INCLUDES <regular expressions for the headers of PUBLIC
#                                             dependencies that HEADER_FILES may include, on
#                                             top of OPENMS_PUBLIC_INCLUDE_ALLOWLIST
#                                             (see openms_validate_public_headers())>
#                    DLL_EXPORT_PATH <path to the dll export header>
#                    EXPORT_SET <export set of the library (see cmake/install_macros.cmake);
#                                OpenMSGUITargets when omitted>)
#
# Besides TARGET_NAME the library is available as OpenMS::TARGET_NAME, the name
# under which it is exported (install(EXPORT ... NAMESPACE OpenMS::)), so
# in-tree code and consumers of the installed package can link the same name.
# The library and its export go into the install components of EXPORT_SET; the
# headers always go into the component TARGET_NAME_headers.
#
# On Windows the DLLs the library needs at run time (the OpenMS core, Qt) are copied
# next to it into bin/, where all executables of this build (applications, tests,
# documenters) are, so they run from the build tree without changing PATH.
function(openms_add_library)
  #------------------------------------------------------------------------------
  # parse arguments to function
  set(options )
  set(oneValueArgs TARGET_NAME DLL_EXPORT_PATH EXPORT_SET)
  set(multiValueArgs BASE_DIRS PRIVATE_INCLUDES EXTERNAL_INCLUDES SOURCE_FILES HEADER_FILES LINK_LIBRARIES PRIVATE_LINK_LIBRARIES
                     ALLOWED_PUBLIC_INCLUDES)
  ## make above arguments available as variables, e.g. ${openms_add_library_PRIVATE_LINK_LIBRARIES}
  cmake_parse_arguments(openms_add_library "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

  #------------------------------------------------------------------------------
  # Status message for configure output
  message(STATUS "Adding library ${openms_add_library_TARGET_NAME}")

  #------------------------------------------------------------------------------
  # Preserve the include-directory cache consumed by class tests.
  set(${openms_add_library_TARGET_NAME}_INCLUDE_DIRECTORIES ${openms_add_library_BASE_DIRS}
                                                            ${openms_add_library_EXTERNAL_INCLUDES}
      CACHE INTERNAL "${openms_add_library_TARGET_NAME} include directories" FORCE)

  #------------------------------------------------------------------------------
  # Add the library
  add_library(${openms_add_library_TARGET_NAME} ${openms_add_library_SOURCE_FILES})
  add_library(OpenMS::${openms_add_library_TARGET_NAME} ALIAS ${openms_add_library_TARGET_NAME})

  if(ENABLE_UNITYBUILD)
    message(STATUS "Unity build for ${openms_add_library_TARGET_NAME} (batches of ${OPENMS_UNITY_BUILD_BATCH_SIZE} files)")
    set_target_properties(${openms_add_library_TARGET_NAME} PROPERTIES
      UNITY_BUILD ON
      UNITY_BUILD_MODE BATCH
      UNITY_BUILD_BATCH_SIZE ${OPENMS_UNITY_BUILD_BATCH_SIZE})
  endif()

  set_target_properties(${openms_add_library_TARGET_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
  set_target_properties(${openms_add_library_TARGET_NAME} PROPERTIES VISIBILITY_INLINES_HIDDEN 1)
  # AUTOMOC is chosen by the library's own CMakeLists.txt. Merely finding Qt
  # elsewhere must not enable Qt code generation for non-GUI libraries.

  #------------------------------------------------------------------------------
  # Include directories
  # Public include directories come from the header file set and its install destination.

  # TODO actually we shouldn't need to add these external includes. They should propagate through target_link_library if they are public
  target_include_directories(${openms_add_library_TARGET_NAME} SYSTEM PUBLIC 
                             "$<BUILD_INTERFACE:${openms_add_library_EXTERNAL_INCLUDES}>"
                             )
  target_include_directories(${openms_add_library_TARGET_NAME} SYSTEM PRIVATE ${openms_add_library_PRIVATE_INCLUDES})
  
  target_compile_features(${openms_add_library_TARGET_NAME} PUBLIC cxx_std_23)

  # Add compiler flags using the new helper function
  openms_add_library_compiler_flags(${openms_add_library_TARGET_NAME})

  if(ADDRESS_SANITIZER)
    add_asan_to_target(${openms_add_library_TARGET_NAME})
  endif()
  
  
  set_target_properties(${openms_add_library_TARGET_NAME} PROPERTIES CXX_VISIBILITY_PRESET hidden)
  set_target_properties(${openms_add_library_TARGET_NAME} PROPERTIES VISIBILITY_INLINES_HIDDEN 1)

  #------------------------------------------------------------------------------
  # Generate export header if requested
  if(openms_add_library_DLL_EXPORT_PATH)
    ## this snipped creates 'OpenMSConfig.h' in the build tree
    set(_CONFIG_H "include/${openms_add_library_DLL_EXPORT_PATH}${openms_add_library_TARGET_NAME}Config.h")
    string(TOUPPER ${openms_add_library_TARGET_NAME} _TARGET_UPPER_CASE)
    include(GenerateExportHeader)
    generate_export_header(${openms_add_library_TARGET_NAME}
                          EXPORT_MACRO_NAME ${_TARGET_UPPER_CASE}_DLLAPI
                          EXPORT_FILE_NAME ${_CONFIG_H})

    string(REGEX REPLACE "/" "\\\\" _fixed_path ${openms_add_library_DLL_EXPORT_PATH})

    # add generated header to visual studio
    source_group("Header Files\\${_fixed_path}" FILES ${_CONFIG_H})
    list(APPEND openms_add_library_HEADER_FILES "${CMAKE_CURRENT_BINARY_DIR}/${_CONFIG_H}")
  endif()

  # Both configured headers and generate_export_header() output belong to the
  # public interface. Listing them here also makes them visible to IDEs/AUTOMOC.
  list(REMOVE_DUPLICATES openms_add_library_HEADER_FILES)
  openms_validate_public_headers(${openms_add_library_HEADER_FILES}
                                 ALLOW ${openms_add_library_ALLOWED_PUBLIC_INCLUDES})
  target_sources(${openms_add_library_TARGET_NAME} PUBLIC FILE_SET HEADERS
    BASE_DIRS ${openms_add_library_BASE_DIRS}
    FILES ${openms_add_library_HEADER_FILES})
  if(OPENMS_VERIFY_INTERFACE_HEADER_SETS)
    set_target_properties(${openms_add_library_TARGET_NAME} PROPERTIES
      VERIFY_INTERFACE_HEADER_SETS ON)
  endif()

  #------------------------------------------------------------------------------
  # Link library against other libraries
  if(openms_add_library_LINK_LIBRARIES)
    ## check for consistent lib arch (e.g. all 64bit)?
    check_lib_architecture(openms_add_library_LINK_LIBRARIES)
    target_link_libraries(${openms_add_library_TARGET_NAME} PUBLIC ${openms_add_library_LINK_LIBRARIES})
    list(LENGTH openms_add_library_LINK_LIBRARIES _library_count)
  endif()

  if (openms_add_library_PRIVATE_LINK_LIBRARIES)
    ## check for consistent lib arch (e.g. all 64bit)?
    check_lib_architecture(openms_add_library_PRIVATE_LINK_LIBRARIES)
    target_link_libraries(${openms_add_library_TARGET_NAME} PRIVATE ${openms_add_library_PRIVATE_LINK_LIBRARIES})
    list(LENGTH openms_add_library_PRIVATE_LINK_LIBRARIES _private_library_count)
  endif()

  #------------------------------------------------------------------------------
  # Export libraries (self + dependencies)
  set(${openms_add_library_TARGET_NAME}_LIBRARIES
        ${openms_add_library_TARGET_NAME}
        ${openms_add_library_LINK_LIBRARIES}
        CACHE
        INTERNAL "${openms_add_library_TARGET_NAME} libraries" FORCE)

  #------------------------------------------------------------------------------
  # we also want to install the library (into the components of its export set)
  if(NOT openms_add_library_EXPORT_SET)
    set(openms_add_library_EXPORT_SET ${OPENMS_GUI_EXPORT_SET})
  endif()
  install_library(${openms_add_library_TARGET_NAME} HEADERS EXPORT_SET ${openms_add_library_EXPORT_SET})

  #------------------------------------------------------------------------------
  # register for the build-tree export of the same export set
  openms_register_export_target(${openms_add_library_TARGET_NAME} ${openms_add_library_EXPORT_SET})

  #------------------------------------------------------------------------------
  # On Windows copy the DLLs the library depends on (OpenMS core, Qt) next to it
  if(WIN32)
    ## never empty: the library always links the OpenMS core and Qt DLLs
    add_custom_command(TARGET ${openms_add_library_TARGET_NAME} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
                    $<TARGET_RUNTIME_DLLS:${openms_add_library_TARGET_NAME}>
                    $<TARGET_FILE_DIR:${openms_add_library_TARGET_NAME}>
            COMMAND_EXPAND_LISTS
            )
  endif()

  #------------------------------------------------------------------------------
  # Status message for configure output
  message(STATUS "Adding library ${openms_add_library_TARGET_NAME} - SUCCESS")
endfunction()
