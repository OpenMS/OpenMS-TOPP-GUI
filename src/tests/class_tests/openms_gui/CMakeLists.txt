# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Stephan Aiche $
# $Authors: Stephan Aiche $
# --------------------------------------------------------------------------

project("OpenMS_GUI_class_tests_openms_gui")

set(visual_executables_list
  Annotation1DPeakItem_test
  AxisTickCalculator_test
  FileWatcher_test
  GUIHelpers_test
  MultiGradient_test
  SpectraTreeTab_test
)

set(CMAKE_AUTOMOC ON)
set(CMAKE_INCLUDE_CURRENT_DIR ON)

#------------------------------------------------------------------------------
# disable optimization for tests for gcc like compilers (as OpenMSTestSupport does)
if(CMAKE_COMPILER_IS_INTELCXX OR CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANG)
  set(CMAKE_CXX_FLAGS_RELEASE "-O0")
endif()

#------------------------------------------------------------------------------
# VISUAL
add_custom_target(VISUAL_TEST)
add_dependencies(VISUAL_TEST ${visual_executables_list})

foreach(_class_test ${visual_executables_list})
  add_executable(${_class_test} source/${_class_test}.cpp)
  target_link_libraries(${_class_test} PRIVATE OpenMSTestSupport OpenMS_GUI)
  openms_add_executable_compiler_flags(${_class_test})
  add_test(NAME ${_class_test} COMMAND ${_class_test})
endforeach()
openms_gui_test_environment(${visual_executables_list})

#------------------------------------------------------------------------------
# GUI tests (QtTest): they open windows, so they need a display or a display-less
# platform plugin (QT_QPA_PLATFORM=offscreen, see src/tests/CMakeLists.txt).
# The ui_*.h headers of the dialogs (TSGDialog_test) come with the build-tree
# interface of OpenMS_GUI.
#------------------------------------------------------------------------------
if(HAS_XSERVER)
  find_package(Qt6 REQUIRED COMPONENTS Test)

  set(GUI_executables_list
    TOPPView_test
    TSGDialog_test
  )

  foreach(_gui_test ${GUI_executables_list})
    # the header is listed as a source file too, so automoc sees its Q_OBJECT
    add_executable(${_gui_test} source/GUI/${_gui_test}.cpp ${CMAKE_CURRENT_SOURCE_DIR}/include/GUI/${_gui_test}.h)
    target_include_directories(${_gui_test} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include/GUI)
    target_link_libraries(${_gui_test} PRIVATE OpenMSTestSupport OpenMS_GUI Qt6::Test)
    openms_add_executable_compiler_flags(${_gui_test})
  endforeach()

  add_custom_target(GUI_TEST)
  add_dependencies(GUI_TEST ${GUI_executables_list})

  ## TOPPView_test opens examples/peakpicker_tutorial_1.mzML from the shared data of
  ## the OpenMS core (install component 'examples', not part of the OpenMS SDK)
  set(_toppview_example "${OPENMS_DATA_DIR}/examples/peakpicker_tutorial_1.mzML")
  set(_gui_tests TSGDialog_test)
  if(EXISTS "${_toppview_example}")
    list(APPEND _gui_tests TOPPView_test)
  else()
    message(STATUS "TOPPView_test is left out: ${_toppview_example} does not exist (the OpenMS installation has no examples).")
  endif()
  foreach(_gui_test ${_gui_tests})
    add_test(NAME ${_gui_test} COMMAND ${_gui_test})
  endforeach()
  openms_gui_test_environment(${_gui_tests})
endif()
