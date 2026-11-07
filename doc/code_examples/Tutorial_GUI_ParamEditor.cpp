// Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
// SPDX-License-Identifier: BSD-3-Clause
//

#include <OpenMS/VISUAL/ParamEditor.h>
#include <OpenMS/DATASTRUCTURES/Param.h>
#include <OpenMS/FORMAT/ParamXMLFile.h>
#include <OpenMS/SYSTEM/File.h>

#include <iostream>
#include <QApplication>

using namespace OpenMS;
using namespace std;

Int main(int argc, const char** argv)
{
  // GUI_TUTORIAL_DATA_PATH: doc/code_examples/data of the source tree (set in CMakeLists.txt)
  std::string tutorial_data_path(GUI_TUTORIAL_DATA_PATH);

  QApplication app(argc, const_cast<char**>(argv));

  Param param;
  ParamXMLFile paramFile;

  paramFile.load(tutorial_data_path + "/Tutorial_ParamEditor.ini", param);

  ParamEditor editor(nullptr);
  editor.load(param);
  editor.show();

  app.exec();

  editor.store();
  paramFile.store("Tutorial_ParamEditor_out.ini", param);
} //end of main
