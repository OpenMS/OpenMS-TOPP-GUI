# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Stephan Aiche, Chris Bielow $
# $Authors: Andreas Bertsch, Chris Bielow, Stephan Aiche $
# --------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Documentation of the GUI layer (doxygen html of the GUI library, the pages of
# the GUI tools, the TOPPAS tutorial) and the GUI code examples of the tutorials.
#
# Targets (only with ENABLE_DOCS=ON and doxygen found):
#   doc             the GUI documenters, then doxygen -> <build>/doc/html-gui
#   doc_class_only  doxygen only (reuses the output of earlier documenter runs)
#   doc_param_internal / doc_progs  the documenters / building them
# Target (ENABLE_TUTORIALS=ON): Tutorials_build
#
# The html is installed into ${INSTALL_DOC_DIR}/html-gui (component doc_gui),
# next to html/ of the OpenMS core when both are installed into one prefix.
#------------------------------------------------------------------------------

project("OpenMS_TOPP_GUI_doc")

#------------------------------------------------------------------------------
# helper macro
#------------------------------------------------------------------------------
macro(make_doxygen_path doxygen_style_list_var doc_path_list_var)
  set(${doxygen_style_list_var} "")
  foreach(_doc_path ${${doc_path_list_var}})
    set(${doxygen_style_list_var} "\"${_doc_path}\" ${${doxygen_style_list_var}}")
  endforeach()
endmacro()

if(ENABLE_DOCS AND NOT Doxygen_FOUND)
  message(STATUS "Doxygen not found. Disabling all documentation targets!")
elseif(ENABLE_DOCS)
  message(STATUS "Documentation is built (-D ENABLE_DOCS=On).")

  ## doxygen links @ref TOPP_<tool> and the classes of the OpenMS core through the tag file of
  ## the core documentation (OpenMS.tag, installed into share/doc of an OpenMS installation).
  ## Without it these references stay plain text and doxygen warns about them.
  set(_core_tagfile "${OPENMS_DOC_DIR}/OpenMS.tag")
  if(OPENMS_PACKAGE_VERSION_FULLSTRING STREQUAL OPENMS_PACKAGE_VERSION)
    set(_core_doc_url "https://archive.openms.de/openms/Documentation/release/${OPENMS_PACKAGE_VERSION}/html")
  else()
    set(_core_doc_url "https://archive.openms.de/openms/Documentation/nightly/latest/html")
  endif()
  if(OPENMS_DOC_DIR AND EXISTS "${_core_tagfile}")
    set(_default_tagfile "${_core_tagfile}=${_core_doc_url}")
  else()
    set(_default_tagfile "")
  endif()
  set(OPENMS_DOXYGEN_TAGFILE "${_default_tagfile}" CACHE STRING
      "Doxygen tag file of the OpenMS core documentation, as <file>=<html location>, e.g. <OpenMS prefix>/share/doc/OpenMS.tag=${_core_doc_url}. Empty: no links into the core documentation.")
  if(OPENMS_DOXYGEN_TAGFILE)
    message(STATUS "  linking the OpenMS documentation through ${OPENMS_DOXYGEN_TAGFILE}")
  else()
    message(STATUS "  no tag file of the OpenMS documentation (OPENMS_DOXYGEN_TAGFILE): references to TOPP tools and core classes are not linked")
  endif()

  #------------------------------------------------------------------------------
  # doc programs: they write the generated parts of the pages to doxygen/parameters/output
  #   GUIToolDocumenter:  TOPP_<tool>.cli / .html of the GUI tools (runs the tools)
  #   GUIParamDocumenter: OpenMS_<class>.parameters of the GUI classes with parameters
  #------------------------------------------------------------------------------
  set(OpenMS_doc_executables)
  include(doxygen/parameters/executables.cmake)

  foreach(i ${OpenMS_doc_executables})
    add_executable(${i} EXCLUDE_FROM_ALL doxygen/parameters/${i}.cpp)
    set_target_properties(${i} PROPERTIES RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/doxygen/parameters")
  endforeach()
  target_link_libraries(GUIToolDocumenter OpenMS::OpenMS_CLI)
  target_link_libraries(GUIParamDocumenter OpenMS_GUI)

  # collection target; the tool documenter runs the GUI tools
  add_custom_target(doc_progs)
  add_dependencies(doc_progs ${OpenMS_doc_executables} GUI)

  #------------------------------------------------------------------------------
  # Initialize variables needed for a proper doxygen configuration
  #------------------------------------------------------------------------------
  set(CF_OPENMS_BIN_PATH ${PROJECT_BINARY_DIR})
  set(CF_OPENMS_SRC_PATH ${OPENMS_HOST_DIRECTORY})
  set(CF_OPENMS_PACKAGE_VERSION ${OPENMS_PACKAGE_VERSION_FULLSTRING})
  set(CF_OPENMS_DOXYGEN_TAGFILE "${OPENMS_DOXYGEN_TAGFILE}")
  if(CF_OPENMS_DOXYGEN_TAGFILE)
    set(CF_OPENMS_DOXYGEN_TAGFILE "\"${CF_OPENMS_DOXYGEN_TAGFILE}\"")
  endif()

  # make it a doxygen conform list
  make_doxygen_path(CF_OPENMS_DOCUMENTATION_DIRECTORIES OPENMS_DOCUMENTATION_DIRECTORIES)
  make_doxygen_path(CF_OPENMS_DOCUMENTATION_STRIP_INCLUDES OPENMS_DOCUMENTATION_DIRECTORIES)
  make_doxygen_path(CF_STRIP_PATH OPENMS_DOCUMENTATION_DIRECTORIES)

  ## DOT (Graphviz) is not used (HAVE_DOT = NO); its path is only filled in when present, to
  ## avoid a warning about a missing dot tool.
  if (TARGET Doxygen::dot)
    get_target_property(CF_DOXYGEN_DOT_EXECUTABLE Doxygen::dot IMPORTED_LOCATION)
  else()
    set(CF_DOXYGEN_DOT_EXECUTABLE "")
  endif()

  configure_file(${PROJECT_SOURCE_DIR}/doxygen/Doxyfile.in ${PROJECT_BINARY_DIR}/doxygen/Doxyfile)

  #------------------------------------------------------------------------------
  # Run time environment of the documenters, as for the tests (src/tests/CMakeLists.txt):
  # the GUI library needs a QApplication (offscreen without a display), the GUI TOPP
  # tools need the tool registry of this build, libOpenMS the share/OpenMS of the core
  # (OPENMS_DATA_PATH, its last resort, e.g. for a moved SDK), and on Windows the DLLs
  # of this build, the OpenMS core and Qt, and the Qt plugins must be found.
  #------------------------------------------------------------------------------
  list(TRANSFORM CMAKE_PREFIX_PATH APPEND "/bin" OUTPUT_VARIABLE DEP_BIN_DIRS)
  list(TRANSFORM CMAKE_PREFIX_PATH APPEND "/lib" OUTPUT_VARIABLE DEP_LIB_DIRS)
  set(_doc_path_dirs "$<TARGET_FILE_DIR:OpenMS_GUI>" ${OPENMS_BIN_DIR} ${OPENMS_LIB_DIR}
                     "$<TARGET_FILE_DIR:Qt6::Core>" ${DEP_BIN_DIRS} ${DEP_LIB_DIRS})
  if(WIN32)
    string(REPLACE ";" "\\;" _doc_path "${_doc_path_dirs};$ENV{PATH}")
  else()
    string(REPLACE ";" ":" _doc_path "${_doc_path_dirs}:$ENV{PATH}")
  endif()
  if(DEFINED ENV{QT_QPA_PLATFORM})
    set(_doc_qpa "$ENV{QT_QPA_PLATFORM}")
  else()
    set(_doc_qpa "offscreen")
  endif()
  set(_doc_env ${CMAKE_COMMAND} -E env
               "PATH=${_doc_path}"
               "QT_QPA_PLATFORM=${_doc_qpa}"
               "OPENMS_TOOL_REGISTRY_PATH=${OPENMS_TOOL_REGISTRY_BUILD_DIR}"
               "OPENMS_DATA_PATH=${OPENMS_DATA_DIR}")
  ## the build tree has no qt.conf: point Qt to its plugins (<plugins>/platforms/qwindows.dll)
  if(WIN32 AND TARGET Qt6::QWindowsIntegrationPlugin)
    list(APPEND _doc_env "QT_PLUGIN_PATH=$<PATH:GET_PARENT_PATH,$<TARGET_FILE_DIR:Qt6::QWindowsIntegrationPlugin>>")
  endif()

  # where the GUI tools are (with multi-config generators, in a subdirectory per configuration)
  set(_gui_bin_dir "$<TARGET_FILE_DIR:ExecutePipeline>")

  add_custom_target(doc_param_internal
                    COMMAND ${CMAKE_COMMAND} -E make_directory doxygen/parameters/output/
                    COMMAND ${CMAKE_COMMAND} -E echo "Writing the parameter documentation of the GUI classes"
                    COMMAND ${CMAKE_COMMAND} -E chdir doxygen/parameters/ ${_doc_env} $<TARGET_FILE:GUIParamDocumenter>
                    COMMAND ${CMAKE_COMMAND} -E echo "Writing the command line and INI documentation of the GUI tools"
                    COMMAND ${CMAKE_COMMAND} -E chdir doxygen/parameters/ ${_doc_env} $<TARGET_FILE:GUIToolDocumenter> ${_gui_bin_dir}
                    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
                    COMMENT "Build the parameter documentation of the GUI layer"
                    VERBATIM)
  add_dependencies(doc_param_internal doc_progs)

  #------------------------------------------------------------------------------
  # doxygen
  #------------------------------------------------------------------------------
  set(_DOC_HTML_CODE
    COMMAND ${CMAKE_COMMAND} -E remove_directory html-gui
    COMMAND ${CMAKE_COMMAND} -E chdir ${PROJECT_BINARY_DIR} $<TARGET_FILE:Doxygen::doxygen> doxygen/Doxyfile
    COMMAND ${CMAKE_COMMAND} -E echo "The documentation has been created: ${PROJECT_BINARY_DIR}/html-gui/index.html"
    COMMAND ${CMAKE_COMMAND} -E echo "Doxygen warnings are in ${PROJECT_BINARY_DIR}/doxygen/doxygen-error.log"
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
    COMMENT "Build the doxygen documentation of the GUI layer"
  )

  # full documentation: documenters, then doxygen
  add_custom_target(doc ${_DOC_HTML_CODE} VERBATIM)
  add_dependencies(doc doc_param_internal)

  # doxygen only, e.g. when editing the documentation
  add_custom_target(doc_class_only
                    ${_DOC_HTML_CODE}
                    COMMAND ${CMAKE_COMMAND} -E echo "NOTE: the generated tool and parameter documentation was not updated (target 'doc' does that)."
                    VERBATIM)

  #------------------------------------------------------------------------------
  # Install documentation (if it was built)
  install(DIRECTORY ${PROJECT_BINARY_DIR}/html-gui
    DESTINATION ${INSTALL_DOC_DIR}
    COMPONENT doc_gui
    OPTIONAL
    FILE_PERMISSIONS      OWNER_WRITE OWNER_READ
                          GROUP_READ
                          WORLD_READ
    DIRECTORY_PERMISSIONS OWNER_EXECUTE OWNER_WRITE OWNER_READ
                          GROUP_EXECUTE GROUP_READ
                          WORLD_EXECUTE WORLD_READ
    REGEX "^\\..*" EXCLUDE ## Exclude hidden files (svn, git, DSStore)
    REGEX ".*\\/\\..*" EXCLUDE ## Exclude hidden files in subdirectories
    REGEX ".*\\.map\$" EXCLUDE ## Exclude temporary map files
    REGEX ".*\\.md5\$" EXCLUDE ## Exclude temporary md5 files
  )
else()
  message(STATUS "Documentation is not built (-D ENABLE_DOCS=Off).")
endif()

#------------------------------------------------------------------------------
# Code examples of the tutorials that use the GUI library
#------------------------------------------------------------------------------
if(ENABLE_TUTORIALS AND "${PACKAGE_TYPE}" STREQUAL "none")
  add_subdirectory(code_examples)
  message(STATUS "GUI code examples are built (target Tutorials_build, -D ENABLE_TUTORIALS=On).")
elseif(ENABLE_TUTORIALS)
  message(STATUS "GUI code examples are not built (PACKAGE_TYPE=${PACKAGE_TYPE}, must be 'none').")
endif()
