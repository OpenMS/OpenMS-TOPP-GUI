// Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
// SPDX-License-Identifier: BSD-3-Clause
//
// --------------------------------------------------------------------------
// $Maintainer: Timo Sachsenberg $
// $Authors: Timo Sachsenberg $
// --------------------------------------------------------------------------

#include <OpenMS/CONCEPT/ClassTest.h>

///////////////////////////

#include <OpenMS/VISUAL/APPLICATIONS/MISC/QApplicationTOPP.h>

///////////////////////////

using namespace OpenMS;
using namespace std;

START_TEST(QApplicationTOPP, "$Id$")

/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////

START_SECTION((QApplicationTOPP(int& argc, char** argv)))
{
  // The default style sheet is compiled into libOpenMS_GUI. Before, it was looked up in the
  // shared data of the OpenMS core, which does not hold it: the constructor threw
  // Exception::FileNotFound when the GUI applications ran from the build tree.
  char app_name[] = "QApplicationTOPP_test";
  char* argv[] = {app_name, nullptr};
  int argc = 1;
  QApplicationTOPP app(argc, argv);
  TEST_EQUAL(app.styleSheet().contains("::item:selected:!active"), true)
}
END_SECTION

/////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////
END_TEST
