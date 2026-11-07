# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Stephan Aiche, Chris Bielow, Julianus Pfeuffer $
# --------------------------------------------------------------------------

# The 'targets' target lists the most important targets.
add_custom_target(targets
                  COMMAND ${CMAKE_COMMAND} -E echo ""
                  COMMAND ${CMAKE_COMMAND} -E echo "=========================================================================="
                  COMMAND ${CMAKE_COMMAND} -E echo ""
                  COMMAND ${CMAKE_COMMAND} -E echo "The following targets are available:"
                  COMMAND ${CMAKE_COMMAND} -E echo "    all/ALL_BUILD   builds the GUI library, the GUI tools and the tests"
                  COMMAND ${CMAKE_COMMAND} -E echo "    OpenMS_GUI      builds the GUI library"
                  COMMAND ${CMAKE_COMMAND} -E echo "    GUI             builds the GUI tools (TOPPView, TOPPAS, INIFileEditor, ExecutePipeline, ImageCreator)"
                  COMMAND ${CMAKE_COMMAND} -E echo "    test/RUN_TESTS  runs the tests (ctest)"
                  COMMAND ${CMAKE_COMMAND} -E echo "    Tutorials_build builds the GUI code examples of the tutorials"
                  COMMAND ${CMAKE_COMMAND} -E echo "    doc             builds the documentation of the GUI layer"
                  COMMAND ${CMAKE_COMMAND} -E echo "    dist            builds the installer (configure with -DPACKAGE_TYPE=...)"
                  COMMAND ${CMAKE_COMMAND} -E echo ""
                  COMMAND ${CMAKE_COMMAND} -E echo "=========================================================================="
                  COMMAND ${CMAKE_COMMAND} -E echo ""
                  COMMENT "The most important targets of OpenMS-TOPP-GUI"
                  VERBATIM)

message(STATUS "")
message(STATUS "-----------------------------------------------------------------")
message(STATUS "")
message(STATUS "You have successfully configured OpenMS-TOPP-GUI ${OPENMS_PACKAGE_VERSION}")
message(STATUS "against OpenMS ${OpenMS_VERSION} (${OpenMS_DIR}).")
message(STATUS "")
message(STATUS "For a list of the most important targets, build the target 'targets'.")
message(STATUS "")
message(STATUS "-----------------------------------------------------------------")
message(STATUS "")
