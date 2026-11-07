# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Stephan Aiche, Chris Bielow $
# $Authors: Andreas Bertsch, Chris Bielow, Stephan Aiche $
# --------------------------------------------------------------------------

project("OpenMS_GUI")

set(CMAKE_AUTOUIC ON) # convert .ui files to ui_....h files using CMake + Qt's UIC
set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# --------------------------------------------------------------------------
# include custom macros for openms_gui lib
#include(qt_wrap_ui.cmake)
include(add_mac_bundle.cmake)

# --------------------------------------------------------------------------
# big include file for headers and cpp files
include (${PROJECT_SOURCE_DIR}/includes.cmake)

#------------------------------------------------------------------------------
# add the library: the GUI layer of the installed package (export set
# OpenMSGUITargets, install components library_gui and cmake_gui, headers in
# OpenMS_GUI_headers); it links the CLI layer of the installed OpenMS core,
# which links the core layer.
# Files that cannot share a unity-build translation unit (ENABLE_UNITYBUILD): each defines a
# file-local dummy object of the same name.
set_source_files_properties(
  source/VISUAL/ANNOTATION/Annotation1DPeakItem.cpp
  source/VISUAL/ANNOTATION/Annotation1DTextItem.cpp
  PROPERTIES SKIP_UNITY_BUILD_INCLUSION ON)

openms_add_library(TARGET_NAME OpenMS_GUI
                   SOURCE_FILES ${OpenMSVisual_sources}
                   HEADER_FILES ${OpenMSVisual_sources_h}
                   BASE_DIRS ${PROJECT_SOURCE_DIR}/include ${PROJECT_BINARY_DIR}/include
                   EXTERNAL_INCLUDES
                   LINK_LIBRARIES ${OpenMS_GUI_DEP_LIBRARIES}
                   # Qt is a PUBLIC dependency of the GUI layer only: <QString>, <QtWidgets/QDialog>
                   ALLOWED_PUBLIC_INCLUDES "Q[A-Za-z0-9_]*" "Qt[A-Za-z]+/.*"
                   DLL_EXPORT_PATH "OpenMS/VISUAL/"
                   EXPORT_SET ${OPENMS_GUI_EXPORT_SET})

# --------------------------------------------------------------------------
# additional linker flags required by openms_gui
if (MSVC)
  ## treat warning of unused function parameter as error, similar to -Werror=unused-variable on GCC
  target_compile_options(OpenMS_GUI PRIVATE "/we4100")
  ## treat warning of unused local variable as error, similar to -Werror=unused-variable on GCC
  target_compile_options(OpenMS_GUI PRIVATE "/we4189")

  set (GUI_lnk_flags "/FORCE:MULTIPLE /INCREMENTAL:NO /ignore:4006 /ignore:4088")
  set_property(TARGET OpenMS_GUI APPEND PROPERTY LINK_FLAGS ${GUI_lnk_flags}) ## allow multiple definitions of symbols (e.g. from template instanciations or STL-derived classes)
endif()


# --------------------------------------------------------------------------
# some targets using OpenMS_GUI (e.g. in the GUI tests) need the ui_..h files, so add them to OpenMS_GUI's interface.
get_property(_isMultiConfig GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(_isMultiConfig)
  set(AUTOGEN_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/OpenMS_GUI_autogen/include_$<CONFIG>)
else()
  set(AUTOGEN_INCLUDE_DIR ${CMAKE_CURRENT_BINARY_DIR}/OpenMS_GUI_autogen/include)
endif()
# add include-directories for UIC'd files (CMake does not do that automatically)
target_include_directories(OpenMS_GUI INTERFACE $<BUILD_INTERFACE:${AUTOGEN_INCLUDE_DIR}>)


#------------------------------------------------------------------------------
# register relevant paths for the doxygen doc generation
openms_doc_path("${PROJECT_SOURCE_DIR}/include")
openms_doc_path("${PROJECT_SOURCE_DIR}/source/VISUAL/APPLICATIONS")

# --------------------------------------------------------------------------
# GUI tools
set(GUI_DIR source/VISUAL/APPLICATIONS/GUITOOLS)
include(${GUI_DIR}/executables.cmake)
foreach(i ${GUI_executables})
  set(resource_file ${PROJECT_SOURCE_DIR}/${GUI_DIR}/${i}.rc)
  set(resource_dir ${PROJECT_SOURCE_DIR}/${GUI_DIR}/${i}-resources/)
  ## add icons to TOPPView, INIFileEditor, etc.
  if (MSVC AND EXISTS ${resource_file})
    message(STATUS "Setting resource file ${resource_file} for ${i}")
    add_executable(${i} ${GUI_DIR}/${i}.cpp ${resource_file})
    install_tool(${i} COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
  elseif (APPLE AND EXISTS ${resource_dir})
    add_mac_app_bundle(${i})
  else()
    if (MSVC)
      message(STATUS "No resource file (${resource_file}) found for ${i}. No icon will be embedded.")
    elseif (APPLE)
      message(STATUS "No icon file (${i}.icns) found in ${resource_dir}. Will not build ${i} as app bundle.")
    endif()
    add_executable(${i} ${GUI_DIR}/${i}.cpp)
    install_tool(${i} COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
  endif()

  ## append visual lib as dependency for GUI tools
  target_link_libraries(${i} OpenMS_GUI)
endforeach(i)

# The TOPP tools that need the GUI library (TOPPBase-derived tools with a Qt front end).
# They are declared like the TOPP tools of the OpenMS core, so they reach the tool registry
# of the GUI layer (OpenMS-GUI.tsv, see src/CMakeLists.txt). One list drives both the
# declarations and the link below, so a tool cannot be built here without being registered.
# These are a subset of GUI_executables, which also holds the GUI applications that are not
# TOPP tools (TOPPView, TOPPAS, INIFileEditor).
set(GUI_TOPP_TOOLS ExecutePipeline ImageCreator)
foreach(_gui_topp_tool ${GUI_TOPP_TOOLS})
  target_link_libraries(${_gui_topp_tool} OpenMS::OpenMS_CLI)
  openms_topp_tool(${_gui_topp_tool} "Misc")
endforeach()

#------------------------------------------------------------------------------
# Qt plugins and qt.conf. Where Qt is bundled (Windows, the macOS package), the plugins the
# GUI needs at run time go to ${INSTALL_PLUGIN_DIR} (component Dependencies, with the
# libraries they need in the runtime dependency set), and bin/qt.conf points there:
# ExecutePipeline creates a QApplication, so it needs the platform plugin even without a
# window. The app bundles have a qt.conf of their own (add_mac_bundle.cmake).
#   platforms     the platform integration (required)
#   styles        the native widget style
#   imageformats  JPEG and GIF for "Save image", SVG for the icons of the GUI resources
#   iconengines   SVG icons
if(WIN32 OR (APPLE AND "${PACKAGE_TYPE}" STREQUAL "pkg"))
  if(WIN32)
    set(_qt_platform_plugin Qt6::QWindowsIntegrationPlugin)
    ## Qt 6.7 replaced the "windowsvista" style by "modernwindows"
    set(_qt_optional_plugins Qt6::QModernWindowsStylePlugin Qt6::QWindowsVistaStylePlugin)
  else()
    set(_qt_platform_plugin Qt6::QCocoaIntegrationPlugin)
    set(_qt_optional_plugins Qt6::QMacStylePlugin)
  endif()
  list(APPEND _qt_optional_plugins Qt6::QJpegPlugin Qt6::QGifPlugin Qt6::QSvgPlugin Qt6::QSvgIconPlugin)
  if(NOT TARGET ${_qt_platform_plugin})
    message(FATAL_ERROR "The Qt platform plugin ${_qt_platform_plugin} was not found; the GUI applications cannot start without it.")
  endif()
  foreach(_qt_plugin IN ITEMS ${_qt_platform_plugin} ${_qt_optional_plugins})
    if(NOT TARGET ${_qt_plugin})
      if(NOT _qt_plugin MATCHES "StylePlugin$")
        message(WARNING "The Qt plugin ${_qt_plugin} was not found, so it is not installed. Install the Qt module that provides it (qtsvg, qtimageformats).")
      endif()
      continue()
    endif()
    get_target_property(_qt_plugin_type ${_qt_plugin} QT_PLUGIN_TYPE)
    install(IMPORTED_RUNTIME_ARTIFACTS ${_qt_plugin}
            RUNTIME_DEPENDENCY_SET ${OPENMS_GUI_DEPS}
            DESTINATION "${INSTALL_PLUGIN_DIR}/${_qt_plugin_type}"
            COMPONENT Dependencies)
    if(APPLE)
      ## Homebrew links the plugins of its Qt formulae (qtbase, qtsvg) into a shared plugin
      ## folder, where they are symbolic links into the kegs; install() copies a link as a
      ## link. Replace it by the file it points to.
      install(CODE "
        set(_qt_plugin_file \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${INSTALL_PLUGIN_DIR}/${_qt_plugin_type}/$<TARGET_FILE_NAME:${_qt_plugin}>\")
        if(IS_SYMLINK \"\${_qt_plugin_file}\")
          file(REMOVE \"\${_qt_plugin_file}\")
          file(COPY_FILE \"$<TARGET_FILE:${_qt_plugin}>\" \"\${_qt_plugin_file}\")
          file(CHMOD \"\${_qt_plugin_file}\" PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
               GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
        endif()"
        COMPONENT Dependencies)
    endif()
  endforeach()
  ## relative to the folder of the executable (lib == bin on Windows: "plugins")
  file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/qt.conf"
    "[Paths]\nPlugins = ${QT_PLUGIN_PATH_REL_TO_BIN}\n")
  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/qt.conf"
    DESTINATION ${INSTALL_BIN_DIR}
    COMPONENT Dependencies)
endif()

add_custom_target(GUI)
add_dependencies(GUI ${GUI_executables})
