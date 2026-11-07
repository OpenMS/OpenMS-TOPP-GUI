# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

project("OpenMSTestFramework")
cmake_minimum_required(VERSION 3.24 FATAL_ERROR)

#------------------------------------------------------------------------------
# The class-test framework of OpenMS (ClassTest.h macros, FuzzyStringComparator,
# MacrosTest.h), a copy of OpenMS' src/testframework: the OpenMS installation does
# not ship it. A STATIC library of the standard library only, used by the class tests
# of this repository and never installed (so no install rules). The libOpenMS part of
# the test setup is the OpenMSTestSupport target of src/tests/class_tests.
#
# The headers keep their OpenMS location (OpenMS/CONCEPT/ClassTest.h), so the tests
# copied from OpenMS compile unchanged. An installed OpenMS does not carry these
# headers, so they cannot be shadowed by those of the core.

set(OpenMSTestFramework_sources
  source/CONCEPT/ClassTest.cpp
  source/CONCEPT/FuzzyStringComparator.cpp
)

set(OpenMSTestFramework_sources_h
  include/OpenMS/CONCEPT/ClassTest.h
  include/OpenMS/CONCEPT/ClassTestUtils.h
  include/OpenMS/CONCEPT/FuzzyStringComparator.h
  include/OpenMS/CONCEPT/MacrosTest.h
)

source_group("Source Files\\CONCEPT" FILES ${OpenMSTestFramework_sources})
source_group("Header Files\\OpenMS\\CONCEPT" FILES ${OpenMSTestFramework_sources_h})

add_library(OpenMSTestFramework STATIC ${OpenMSTestFramework_sources})
target_sources(OpenMSTestFramework PUBLIC FILE_SET HEADERS
  BASE_DIRS "${PROJECT_SOURCE_DIR}/include"
  FILES ${OpenMSTestFramework_sources_h})
target_compile_features(OpenMSTestFramework PUBLIC cxx_std_23)

## the warning and sanitizer flags of this build (cmake/compiler_flags.cmake), when there is one
if(COMMAND openms_add_library_compiler_flags)
  openms_add_library_compiler_flags(OpenMSTestFramework)
endif()
