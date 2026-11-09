# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Julianus Pfeuffer $
# --------------------------------------------------------------------------

## The install components of the GUI layer. The OpenMS core (libraries, TOPP tools, shared
## data) is not part of these packages: it is installed by the core's own package, which
## the GUI packages require.
##   library_gui         libOpenMS_GUI (cmake/install_macros.cmake)
##   GUIApplications     TOPPView, TOPPAS, INIFileEditor, ExecutePipeline, ImageCreator, the
##                       tool registry OpenMS-GUI.tsv, the style sheet and, on Linux, the
##                       desktop integration
##   Dependencies        Windows and macOS: Qt and its plugins, qt.conf, their licenses
##   doc_gui             the documentation of the GUI layer (if it was built)
##   OpenMS_GUI_headers, cmake_gui
##                       the headers and the CMake package, for programs that use the GUI
##                       library (the macOS package offers them, unselected by default)
cpack_add_install_type(recommended DISPLAY_NAME "Recommended")
cpack_add_install_type(full DISPLAY_NAME "Full")
cpack_add_install_type(minimal DISPLAY_NAME "Minimal")

set(_openms_gui_library_depends)
if(OPENMS_GUI_BUNDLES_QT)
  cpack_add_component(Dependencies
                  DISPLAY_NAME "Qt"
                  DESCRIPTION "The Qt libraries and plugins the GUI applications need."
                  REQUIRED
                  INSTALL_TYPES recommended full minimal
                  )
  set(_openms_gui_library_depends DEPENDS Dependencies)
endif()
cpack_add_component(library_gui
                DISPLAY_NAME "GUI library"
                DESCRIPTION "The GUI library (OpenMS_GUI), needed by TOPPView, TOPPAS and the other GUI applications."
                REQUIRED
                ${_openms_gui_library_depends}
                INSTALL_TYPES recommended full minimal
                )
## The macOS package hands pkgbuild a component plist for the app bundles, which keeps the
## installer from relocating them (cmake/generate_applications_component_plist.cmake).
set(_openms_applications_plist)
if(APPLICATIONS_COMPONENT_PLIST)
  set(_openms_applications_plist PLIST "${APPLICATIONS_COMPONENT_PLIST}")
endif()
cpack_add_component(${OPENMS_GUI_APPLICATIONS_COMPONENT}
                DISPLAY_NAME "OpenMS GUI applications"
                DESCRIPTION "TOPPView, TOPPAS, INIFileEditor and the TOPP tools that need the GUI library (ExecutePipeline, ImageCreator)."
                REQUIRED
                DEPENDS library_gui
                INSTALL_TYPES recommended full minimal
                ${_openms_applications_plist}
                )
cpack_add_component(doc_gui
                DISPLAY_NAME "Documentation"
                DESCRIPTION "Documentation of the GUI applications and the GUI library."
                INSTALL_TYPES recommended full
                )
cpack_add_component(OpenMS_GUI_headers
                DISPLAY_NAME "GUI library headers"
                DESCRIPTION "The headers of the GUI library, for programs that use it."
                DEPENDS library_gui
                DISABLED
                INSTALL_TYPES full
                )
cpack_add_component(cmake_gui
                DISPLAY_NAME "GUI library CMake package"
                DESCRIPTION "The CMake package of the GUI library (OpenMSGUIConfig.cmake), for programs that use it."
                DEPENDS OpenMS_GUI_headers
                DISABLED
                INSTALL_TYPES full
                )
unset(_openms_gui_library_depends)
unset(_openms_applications_plist)
