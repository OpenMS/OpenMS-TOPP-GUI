# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Desktop integration on Linux (freedesktop.org), from share/OpenMS/DESKTOP:
#   <app>.desktop      -> share/applications   (menu entries)
#   <app>.appdata.xml  -> share/metainfo       (AppStream metadata, software centers)
#   icons/<size>/<app>.png -> share/icons/hicolor/<size>/apps/<app>.png
# The desktop entries name their icon by its theme name (Icon=TOPPView), which the icon
# theme resolves in hicolor. Installed with the GUI applications; the paths are relative
# to the install prefix (/usr for the Debian and RPM packages).
#------------------------------------------------------------------------------
if(NOT UNIX OR APPLE)
  return()
endif()

set(_desktop_dir "${OPENMS_HOST_DIRECTORY}/share/OpenMS/DESKTOP")
set(_desktop_build_dir "${OPENMS_HOST_BINARY_DIRECTORY}/share/applications")
file(GLOB _desktop_files "${_desktop_dir}/*.desktop")
## written when configuring: configure again when they change
set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS ${_desktop_files})
foreach(_desktop_file IN LISTS _desktop_files)
  get_filename_component(_app "${_desktop_file}" NAME_WE)
  file(READ "${_desktop_file}" _entry)
  ## the icon by its theme name, not by a path that nothing installs
  string(REGEX REPLACE "(^|\n)Icon=[^\n]*" "\\1Icon=${_app}" _entry "${_entry}")
  ## trailing white space is part of a value for the desktop entry parsers
  string(REGEX REPLACE "[ \t]+(\n|$)" "\\1" _entry "${_entry}")
  file(WRITE "${_desktop_build_dir}/${_app}.desktop" "${_entry}")
  install(FILES "${_desktop_build_dir}/${_app}.desktop"
          DESTINATION share/applications
          COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
endforeach()

file(GLOB _appdata_files "${_desktop_dir}/*.appdata.xml")
install(FILES ${_appdata_files}
        DESTINATION share/metainfo
        COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})

file(GLOB _icon_sizes LIST_DIRECTORIES true RELATIVE "${_desktop_dir}/icons" "${_desktop_dir}/icons/*x*")
foreach(_size IN LISTS _icon_sizes)
  file(GLOB _icons "${_desktop_dir}/icons/${_size}/*.png")
  install(FILES ${_icons}
          DESTINATION share/icons/hicolor/${_size}/apps
          COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
endforeach()

unset(_desktop_dir)
unset(_desktop_build_dir)
unset(_desktop_files)
unset(_appdata_files)
unset(_icon_sizes)
