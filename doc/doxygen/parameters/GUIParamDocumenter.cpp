// Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
// SPDX-License-Identifier: BSD-3-Clause
//
// --------------------------------------------------------------------------
// $Maintainer: $
// $Authors: Marc Sturm $
// --------------------------------------------------------------------------

// Writes the parameter tables (output/OpenMS_<class>.parameters) of the classes of the GUI
// library that are DefaultParamHandlers. The class documentation includes them with
// @htmlinclude. The parameters of the OpenMS core classes are documented by
// DefaultParamHandlerDocumenter of OpenMS.

#include <OpenMS/DATASTRUCTURES/Param.h>
#include <OpenMS/DATASTRUCTURES/StringUtils.h>

#include <OpenMS/VISUAL/APPLICATIONS/TOPPASBase.h>
#include <OpenMS/VISUAL/APPLICATIONS/TOPPViewBase.h>
#include <OpenMS/VISUAL/Plot1DCanvas.h>
#include <OpenMS/VISUAL/Plot2DCanvas.h>
#include <OpenMS/VISUAL/Plot3DCanvas.h>
#include <OpenMS/VISUAL/PlotCanvas.h>
#include <OpenMS/VISUAL/SpectraIDViewTab.h>

#include <QApplication>

#include <cstdlib>
#include <fstream>
#include <iostream>
#include <limits>
#include <vector>

using namespace std;
using namespace OpenMS;

//**********************************************************************************
//Helper method - use this method to generate the actual parameter documentation
//**********************************************************************************
void writeParameters(const std::string& class_name, const Param& param, bool table_only = false)
{
  const std::string filename = std::string("output/OpenMS_") + class_name + ".parameters";
  ofstream f(filename.c_str());

  if (!f)
  {
    std::cerr << "Cannot open file '" << filename << "'. Check for invalid characters in filename and permissions.\n";
    exit(1);
  }
    
  if (!table_only)
  {
    f << "<B>Parameters of this class are:</B><BR><BR>\n";
  }
  f << R"(<table class="doxtable" border="1" width="100%" cellpadding="4">)" << endl;
  f << "<tr><th>Name</th><th>Type</th><th>Default</th><th>Restrictions</th><th>Description</th></tr>" << endl;
  std::string type, description, restrictions;
  for (Param::ParamIterator it = param.begin(); it != param.end(); ++it)
  {
    restrictions = "";
    if (it->value.valueType() == ParamValue::INT_VALUE || it->value.valueType() == ParamValue::INT_LIST)
    {
      type = "int";
      if (it->value.valueType() == ParamValue::INT_LIST)
      {
        type += " list";
      }

      //restrictions
      bool first = true;
      if (it->min_int != -(numeric_limits<Int>::max)())
      {
        restrictions += "min: " + StringUtils::toStr(it->min_int);
        first = false;
      }
      if (it->max_int != (numeric_limits<Int>::max)())
      {
        if (!first)
        {
          restrictions += ' ';
        }
        restrictions += "max: " + StringUtils::toStr(it->max_int);
      }
    }
    else if (it->value.valueType() == ParamValue::DOUBLE_VALUE || it->value.valueType() == ParamValue::DOUBLE_LIST)
    {
      type = "float";
      if (it->value.valueType() == ParamValue::DOUBLE_LIST)
        type += " list";

      //restrictions
      bool first = true;
      if (it->min_float != -(numeric_limits<double>::max)())
      {
        restrictions += "min: " + StringUtils::toStr(it->min_float);
        first = false;
      }
      if (it->max_float != (numeric_limits<double>::max)())
      {
        if (!first)
          restrictions += ' ';
        restrictions += "max: " + StringUtils::toStr(it->max_float);
      }
    }
    else if (it->value.valueType() == ParamValue::STRING_VALUE || it->value.valueType() == ParamValue::STRING_LIST)
    {
      type = "string";
      if (it->value.valueType() == ParamValue::STRING_LIST)
        type += " list";

      //restrictions
      if (!it->valid_strings.empty())
      {
        std::string valid_strings = StringUtils::concatenate(it->valid_strings, ", ");
        restrictions += valid_strings;
      }
    }
    if (restrictions == "")
    {
      restrictions = "&nbsp;";
    }
    //replace #, @ and newline in description
    description = param.getDescription(it.getName());
    StringUtils::substitute(description, "@", "XXnot_containedXX");
    StringUtils::substitute(description, "XXnot_containedXX", "@@");
    StringUtils::substitute(description, "#", "XXnot_containedXX");
    StringUtils::substitute(description, "XXnot_containedXX", "@#");
    StringUtils::substitute(description, "\n", "<BR>");

    //create tooltips for sections if they are documented
    std::string name = it.getName();
    vector<std::string> parts;
    StringUtils::split(name, ':', parts);
    std::string prefix;
    for (Size i = 0; i + 1 < parts.size(); ++i)
    {
      if (i == 0)
      {
        prefix = parts[i];
      }
      else
      {
        prefix = prefix + ":" + parts[i];
      }
      std::string docu = param.getSectionDescription(prefix);
      if (docu != "")
      {
        parts[i] = std::string("<span title=\"") + docu + "\">" + parts[i] + "</span>";
      }
    }
    if (parts.size() != 0)
    {
      name = StringUtils::concatenate(parts, ":");
    }

    //replace # and @ in values
    std::string value = it->value.toString(true);
    StringUtils::substitute(value, "@", "XXnot_containedXX");
    StringUtils::substitute(value, "XXnot_containedXX", "@@");
    StringUtils::substitute(value, "#", "XXnot_containedXX");
    StringUtils::substitute(value, "XXnot_containedXX", "@#");

    //make the advanced parameters cursive, the normal ones bold
    std::string style = "b";
    if (it->tags.count("advanced") == 1)
      style = "i";

    //final output
    f << "<tr>\n"
      << "  <td style=\"vertical-align:top\"><" << style << ">" << name << "</" << style << "></td>\n"
      << "  <td style=\"vertical-align:top\">" << type << "</td><td style=\"vertical-align:top\">" << value <<  "</td>\n"
      << "  <td style=\"vertical-align:top\">" << restrictions << "</td><td style=\"vertical-align:top\">" << description <<  "</td>\n"
      << "</tr>\n";
  }
  f << "</table>" << "\n";
  if (!table_only)
  {
    f << "<br>" << "\n"
      << "<b>Note:</b>" << "\n"
      << "<UL style=\"margin-top:0px;\">" << "\n"
      << "  <LI> If a section name is documented, the documentation is displayed as tooltip." << "\n"
      << "  <LI> Advanced parameter names are italic." << "\n"
      << "</UL>" << "\n";
  }
  f.close();
}

//**********************************************************************************
//Helper macros that can be used for easy classes
//**********************************************************************************

// For classes that have a default-constructor, simply use this macro with the
// class name
#define DOCME(class_name) \
  writeParameters("" # class_name, class_name().getDefaults());

// For class templates and classes without default constructor use this macro
// with (1.) the class name and (2.) a class instance.
#define DOCME2(class_template_name, instantiation) \
  writeParameters("" # class_template_name, (instantiation).getDefaults());

//**********************************************************************************
//Main method - add your class here
//**********************************************************************************
int main(int argc, char** argv)
{
  // the widgets require a QApplication (use QT_QPA_PLATFORM=offscreen without a display)
  QApplication app(argc, argv);

  DOCME(TOPPASBase);
  DOCME2(TOPPViewBase, TOPPViewBase(TOPPViewBase::TOOL_SCAN::SKIP_SCAN));
  DOCME2(PlotCanvas, Plot1DCanvas(Param())); // PlotCanvas is abstract, its parameters are those of the subclasses
  DOCME2(Plot1DCanvas, Plot1DCanvas(Param()));
  DOCME2(Plot2DCanvas, Plot2DCanvas(Param()));
  DOCME2(Plot3DCanvas, Plot3DCanvas(Param()));
  DOCME2(SpectraIDViewTab, SpectraIDViewTab(Param()));

  return 0;
}
