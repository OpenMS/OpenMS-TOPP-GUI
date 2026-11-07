# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Stephan Aiche $
# $Authors: Stephan Aiche $
# --------------------------------------------------------------------------

# CMake sub-project for the code examples of the GUI library

project("OpenMS_TOPP_GUI_code_examples")

set(GUI_EXAMPLES_executables)

# get the actual code examples
include(${CMAKE_CURRENT_LIST_DIR}/executables.cmake)

# add the targets (no tests: they open windows and wait for the user)
foreach(i ${GUI_EXAMPLES_executables})
  add_executable(${i} ${CMAKE_CURRENT_LIST_DIR}/${i}.cpp)
  target_link_libraries(${i} OpenMS_GUI)
  # the data the examples load, from this directory (not from the OpenMS core)
  target_compile_definitions(${i} PRIVATE GUI_TUTORIAL_DATA_PATH="${CMAKE_CURRENT_SOURCE_DIR}/data")
endforeach(i)

# add collection target
add_custom_target(Tutorials_build)
add_dependencies(Tutorials_build ${GUI_EXAMPLES_executables})
