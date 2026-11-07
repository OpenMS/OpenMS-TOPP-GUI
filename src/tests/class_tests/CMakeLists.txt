# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Stephan Aiche $
# $Authors: Stephan Aiche $
# --------------------------------------------------------------------------

project("OpenMS_GUI_class_tests")

#------------------------------------------------------------------------------
# The libOpenMS half of the class-test setup (as in OpenMS): a fixed
# UniqueIdGenerator seed and an OpenMS exception translator, registered at static
# init (the source says what breaks without it). Every class test links this.
#
# An OBJECT library, not STATIC, and that is the point: this translation unit exports no
# name that anyone references, so as a static archive member the linker would drop it and
# the seed would silently never be set. An object library puts its objects into the
# consumer unconditionally.
add_library(OpenMSTestSupport OBJECT source/OpenMSTestSupport.cpp)
target_link_libraries(OpenMSTestSupport PUBLIC OpenMSTestFramework OpenMS::OpenMS)
openms_add_library_compiler_flags(OpenMSTestSupport)
# The class tests are built at -O0, which also drops the NDEBUG that
# CMAKE_CXX_FLAGS_RELEASE carries. This translation unit ends up in the same
# executables and includes the same headers, so it has to agree with them: otherwise
# an NDEBUG-guarded inline would differ between the two and be an ODR mismatch with
# no diagnostic. On MSVC, OPENMS_ASSERTIONS (config.h) is keyed on NDEBUG, and this
# file's OPENMS_ASSERTIONS branch decides whether precondition tests run at all.
# One quoted generator expression per flag: an unquoted one containing a space is split
# into two arguments.
if(CMAKE_COMPILER_IS_INTELCXX OR CMAKE_COMPILER_IS_GNUCXX OR CMAKE_COMPILER_IS_CLANG)
  target_compile_options(OpenMSTestSupport PRIVATE
    "$<$<CONFIG:Release>:-O0>" "$<$<CONFIG:Release>:-UNDEBUG>")
endif()

#------------------------------------------------------------------------------
# the class tests of the GUI library
add_subdirectory(openms_gui)
