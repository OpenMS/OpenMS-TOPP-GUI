// Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
// SPDX-License-Identifier: BSD-3-Clause
//
// --------------------------------------------------------------------------
// $Maintainer: Timo Sachsenberg $
// $Authors: Timo Sachsenberg $
// --------------------------------------------------------------------------

// Installed-consumer check of the GUI layer: compiled against the installed headers
// of OpenMS_GUI (which include Qt headers and those of the OpenMS core and CLI
// layers) and linked against OpenMS::OpenMS_GUI only, so the build succeeds only
// when the include directories and the link interface of the installed package
// resolve: Qt from OpenMSGUIConfig.cmake, the core through the GUI library's
// PUBLIC dependencies. Uses no QApplication, so it runs without a display.

#include <OpenMS/VISUAL/MultiGradient.h>
#include <OpenMS/KERNEL/MSExperiment.h>

#include <QtGui/QColor>

#include <iostream>

int main()
{
  // the core library, carried by OpenMS_GUI as a transitive dependency
  OpenMS::MSExperiment exp;
  exp.resize(3);
  if (exp.size() != 3)
  {
    std::cerr << "MSExperiment::resize() failed\n";
    return 1;
  }

  // the GUI library and Qt
  OpenMS::MultiGradient gradient;
  gradient.insert(0, Qt::red);
  gradient.insert(100, Qt::blue);
  const QColor middle = gradient.interpolatedColorAt(50);
  if (middle.red() <= 0 || middle.red() >= 255 || middle.green() != 0 || middle.blue() <= 0 || middle.blue() >= 255)
  {
    std::cerr << "MultiGradient::interpolatedColorAt(50) returned " << middle.name().toStdString() << '\n';
    return 1;
  }
  std::cout << "MultiGradient red-blue at 50: " << middle.name().toStdString() << '\n';
  return 0;
}
