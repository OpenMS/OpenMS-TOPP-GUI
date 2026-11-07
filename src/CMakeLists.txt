# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Stephan Aiche, Timo Sachsenberg $
# --------------------------------------------------------------------------

project("OpenMS_TOPP_GUI_src")

#------------------------------------------------------------------------------
# The GUI library, the GUI applications and the GUI TOPP tools
#------------------------------------------------------------------------------
# Declarations accumulate in the cache, so drop what an earlier configure of this build
# directory left behind before any tool is declared.
openms_reset_topp_tools()
add_subdirectory(openms_gui)

#------------------------------------------------------------------------------
# The tool registry of the GUI layer, OpenMS-GUI.tsv, generated from the
# openms_topp_tool() declarations of src/openms_gui. It is installed into
# share/OpenMS/TOOLS next to the registry of the OpenMS core (OpenMS.tsv);
# ToolHandler reads every *.tsv it finds there. That directory holds registry
# files and nothing else.
#------------------------------------------------------------------------------
openms_write_tool_registry("${OPENMS_TOOL_REGISTRY_BUILD_FILE}")
install(FILES "${OPENMS_TOOL_REGISTRY_BUILD_FILE}"
  DESTINATION ${INSTALL_SHARE_DIR}/TOOLS
  COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT}
  PERMISSIONS OWNER_WRITE OWNER_READ GROUP_READ WORLD_READ
)

#------------------------------------------------------------------------------
# Shared data of the GUI layer, installed into the share/OpenMS of the OpenMS core:
# the style sheet of the GUI applications (read through File::find("GUISTYLE/...")).
#------------------------------------------------------------------------------
install_directory(${OPENMS_HOST_DIRECTORY}/share/OpenMS/GUISTYLE ${INSTALL_SHARE_DIR} ${OPENMS_GUI_APPLICATIONS_COMPONENT})

#------------------------------------------------------------------------------
# Tests (class tests of the GUI library, tests of the GUI TOPP tools, TOPPAS
# pipeline tests, installed-consumer test)
#------------------------------------------------------------------------------
enable_testing()
if(ENABLE_CLASS_TESTING OR ENABLE_TOPP_TESTING OR ENABLE_PIPELINE_TESTING OR OPENMS_TEST_INSTALLED_CONSUMER)
  add_subdirectory(tests)
endif()
