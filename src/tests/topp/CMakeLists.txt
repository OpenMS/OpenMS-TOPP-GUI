# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Andreas Bertsch, Chris Bielow, Timo Sachsenberg $
# --------------------------------------------------------------------------

project("OpenMS_GUI_TOPP_tests")

#------------------------------------------------------------------------------
# Tests of the GUI TOPP tools (${TOPP_TOOLS}: ExecutePipeline, ImageCreator), declared
# like those of the TOPP tools in OpenMS' src/tests/topp/CMakeLists.txt.
#
# Naming scheme: TOPP_<tool>_<num>[_out<num>]; a test that checks the output of
# another one with FuzzyDiff DEPENDS on it.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# General settings
#------------------------------------------------------------------------------
set(DATA_DIR_TOPP ${PROJECT_SOURCE_DIR})
set(TESTS_TEMP_DIR "${PROJECT_BINARY_DIR}/tmp_path")
file(MAKE_DIRECTORY "${TESTS_TEMP_DIR}")
## FuzzyDiff of the OpenMS core (src/tests/CMakeLists.txt); empty if there is none
set(DIFF ${OPENMS_FUZZYDIFF} -test -ini ${DATA_DIR_TOPP}/FuzzyDiff.ini)

#------------------------------------------------------------------------------
# The generated tool registry of the GUI layer (OpenMS-GUI.tsv) has to be something
# ToolHandler can read, and carry every declared tool.
#------------------------------------------------------------------------------
add_test(NAME TOPP_tool_registry_is_readable
         COMMAND ${CMAKE_COMMAND}
         -DREGISTRY_FILE=${OPENMS_TOOL_REGISTRY_BUILD_FILE}
         "-DTOOLS=${TOPP_TOOLS}"
         -P "${DATA_DIR_TOPP}/check_tool_registry.cmake")

#------------------------------------------------------------------------------
# -write_ini and -write_ctd of each GUI TOPP tool
#------------------------------------------------------------------------------
set(_gui_tool_tests)
foreach(i ${TOPP_TOOLS})
  add_test(NAME "TOPPWRITEINI_${i}" COMMAND ${i} -test -write_ini "${TESTS_TEMP_DIR}/${i}.tmp.ini")
  add_test(NAME "TOPPWRITEINI_${i}_SectionName" COMMAND ${CMAKE_COMMAND} -test -DNAME=${i} -DFILE=${TESTS_TEMP_DIR}/${i}.tmp.ini -P "${DATA_DIR_TOPP}/check_ini.cmake")
  set_tests_properties("TOPPWRITEINI_${i}_SectionName" PROPERTIES DEPENDS "TOPPWRITEINI_${i}")
  add_test(NAME "TOPPWRITECTD_${i}" COMMAND ${i} -test -write_ctd "${TESTS_TEMP_DIR}/")
  list(APPEND _gui_tool_tests "TOPPWRITEINI_${i}" "TOPPWRITECTD_${i}")
endforeach()

#------------------------------------------------------------------------------
# ImageCreator (QImage/QPainter only, no window)
#------------------------------------------------------------------------------
add_test(NAME "TOPP_ImageCreator_1" COMMAND ImageCreator -test -in ${DATA_DIR_TOPP}/ImageCreator_1_input.mzML -out ${TESTS_TEMP_DIR}/ImageCreator1.bmp -width 20 -height 15)
# testing forced out_type
add_test(NAME "TOPP_ImageCreator_2" COMMAND ImageCreator -test -in ${DATA_DIR_TOPP}/ImageCreator_2_input.mzML -out ${TESTS_TEMP_DIR}/ImageCreator2.png -out_type bmp -width 20 -height 15 -precursors -precursor_size 3 -precursor_color green -log_intensity)
list(APPEND _gui_tool_tests "TOPP_ImageCreator_1" "TOPP_ImageCreator_2")
if(OPENMS_FUZZYDIFF)
  add_test(NAME "TOPP_ImageCreator_1_out1" COMMAND ${DIFF} -in1 ${TESTS_TEMP_DIR}/ImageCreator1.bmp -in2 ${DATA_DIR_TOPP}/ImageCreator_1_output.bmp)
  set_tests_properties("TOPP_ImageCreator_1_out1" PROPERTIES DEPENDS "TOPP_ImageCreator_1")
  add_test(NAME "TOPP_ImageCreator_2_out1" COMMAND ${DIFF} -in1 ${TESTS_TEMP_DIR}/ImageCreator2.png -in2 ${DATA_DIR_TOPP}/ImageCreator_2_output.bmp)
  set_tests_properties("TOPP_ImageCreator_2_out1" PROPERTIES DEPENDS "TOPP_ImageCreator_2")
else()
  message(STATUS "TOPP_ImageCreator_1_out1 and TOPP_ImageCreator_2_out1 are left out (no FuzzyDiff).")
endif()

openms_gui_test_environment(${_gui_tool_tests})
