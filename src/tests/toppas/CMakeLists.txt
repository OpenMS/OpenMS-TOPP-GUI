# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Chris Bielow $
# $Authors: Chris Bielow, Stephan Aiche $
# --------------------------------------------------------------------------

project("OpenMS_TOPPAS_tests")

################################## README ######################################
#
# Pipeline tests: ExecutePipeline (TOPPAS without the window) runs TOPPAS workflows.
#
# The TOPP tools of a workflow are those of the OpenMS core, which ExecutePipeline
# finds next to itself, in the bin/ of the OpenMS installation it was linked against,
# or on PATH (OPENMS_TOPP_BIN_DIR, see src/tests/CMakeLists.txt). A workflow whose
# tools are not all in OPENMS_TOPP_BIN_DIR is left out with a message.
#
# Naming scheme: TOPP_ExecutePipeline_<workflow>[_out<num>]. When a result file of a
# workflow is checked with FuzzyDiff, the check DEPENDS on the workflow test.
#
################################################################################

set(DATA_DIR_TOPPAS ${PROJECT_SOURCE_DIR})
set(DATA_DIR_TOPPAS_BIN ${PROJECT_BINARY_DIR})

## The example workflows of the OpenMS core (share/OpenMS/examples/TOPPAS, install
## component 'examples'). They refer to the data next to them and in the other examples,
## so the whole examples directory of an installation is needed.
set(OPENMS_EXAMPLES_DIR "${OPENMS_DATA_DIR}/examples" CACHE PATH
    "The examples directory of the OpenMS core (share/OpenMS/examples), whose TOPPAS workflows the pipeline tests run.")

# _openms_gui_missing_tools(<out_var> <workflow.toppas>)
# The TOPP tools of the workflow that are neither in OPENMS_TOPP_BIN_DIR nor built here.
function(_openms_gui_missing_tools out_var workflow)
  file(STRINGS "${workflow}" _tool_lines REGEX "<ITEM name=\"tool_name\" value=\"[^\"]+\"")
  set(_missing)
  foreach(_line IN LISTS _tool_lines)
    string(REGEX REPLACE ".*<ITEM name=\"tool_name\" value=\"([^\"]+)\".*" "\\1" _tool "${_line}")
    if(NOT TARGET ${_tool} AND NOT EXISTS "${OPENMS_TOPP_BIN_DIR}/${_tool}${CMAKE_EXECUTABLE_SUFFIX}")
      list(APPEND _missing ${_tool})
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _missing)
  set(${out_var} ${_missing} PARENT_SCOPE)
endfunction()

if(NOT HAS_XSERVER)
  message(STATUS "The TOPPAS pipeline tests are left out (HAS_XSERVER=OFF): ExecutePipeline needs a Qt platform plugin.")
  return()
endif()

set(_pipeline_tests)

#------------------------------------------------------------------------------
# configure resource files (for TOPPAS/ExecutePipeline) - there is no other
# way to specify the input
configure_file(${DATA_DIR_TOPPAS}/ExecutePipeline_1.trf.in ${DATA_DIR_TOPPAS_BIN}/ExecutePipeline_1.trf)
# ExecutePipeline tests (as substitute for TOPPAS) - the ResourceFiles are in
# binary tree, as they have been configured from a .in file (see above)!
_openms_gui_missing_tools(_missing "${DATA_DIR_TOPPAS}/ExecutePipeline_1.toppas")
if(_missing)
  list(JOIN _missing ", " _missing)
  message(STATUS "TOPP_ExecutePipeline_1 is left out: ${_missing} not found in OPENMS_TOPP_BIN_DIR='${OPENMS_TOPP_BIN_DIR}'.")
else()
  add_test(NAME "TOPP_ExecutePipeline_1" COMMAND ExecutePipeline -test -in ${DATA_DIR_TOPPAS}/ExecutePipeline_1.toppas -resource_file ${DATA_DIR_TOPPAS_BIN}/ExecutePipeline_1.trf -out_dir .)
  # do not test the output -- we just want the pipeline to run -- the tools
  # itself are tested separately
  list(APPEND _pipeline_tests "TOPP_ExecutePipeline_1")
endif()

#------------------------------------------------------------------------------
## Run the example workflows of the OpenMS core, to make sure they are up to date
file(GLOB TOPPAS_EXAMPLE_PIPELINES "${OPENMS_EXAMPLES_DIR}/TOPPAS/*.toppas")
if(NOT TOPPAS_EXAMPLE_PIPELINES)
  message(STATUS "The TOPPAS example pipeline tests are left out: no workflows in '${OPENMS_EXAMPLES_DIR}/TOPPAS' (the OpenMS installation has no examples; set OPENMS_EXAMPLES_DIR).")
endif()
foreach(I_PIPELINE_PATH ${TOPPAS_EXAMPLE_PIPELINES})
  get_filename_component(I_FILE "${I_PIPELINE_PATH}" NAME)
  _openms_gui_missing_tools(_missing "${I_PIPELINE_PATH}")
  if(_missing)
    list(JOIN _missing ", " _missing)
    message(STATUS "TOPP_ExecutePipeline_${I_FILE} is left out: ${_missing} not found in OPENMS_TOPP_BIN_DIR='${OPENMS_TOPP_BIN_DIR}'.")
    continue()
  endif()
  ## each workflow writes its results (TOPPAS_out/<node>-<tool>-...) into a directory
  ## of its own, so workflows run in parallel cannot overwrite each other's files
  set(_workflow_dir "${DATA_DIR_TOPPAS_BIN}/${I_FILE}.out")
  file(MAKE_DIRECTORY "${_workflow_dir}")
  add_test(NAME "TOPP_ExecutePipeline_${I_FILE}" COMMAND ExecutePipeline -test -in "${I_PIPELINE_PATH}" -out_dir . -num_jobs 4
           WORKING_DIRECTORY "${_workflow_dir}")
  ## allow failure if search engines (comet.exe etc) are not found
  set_tests_properties("TOPP_ExecutePipeline_${I_FILE}" PROPERTIES SKIP_RETURN_CODE 14) ## EXTERNAL_PROGRAM_NOTFOUND
  list(APPEND _pipeline_tests "TOPP_ExecutePipeline_${I_FILE}")
endforeach()

if(_pipeline_tests)
  openms_gui_test_environment(${_pipeline_tests})
endif()
