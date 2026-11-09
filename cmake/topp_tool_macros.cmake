# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

# Declaration of TOPP tools, and generation of the tool registry from those declarations.
#
# openms_topp_tool(<Name> <Category>) is the single place a TOPP tool is declared. It says
# both that the tool exists (so the build produces it) and which category TOPPAS groups it
# under (so ToolHandler can list it). The registry of the GUI layer,
# share/OpenMS/TOOLS/OpenMS-GUI.tsv, is written from these declarations by
# openms_write_tool_registry() (see src/CMakeLists.txt). ToolHandler reads every *.tsv in
# that directory, so installed next to the core's OpenMS.tsv it adds the GUI TOPP tools.

#------------------------------------------------------------------------------
# Forget the tools of an earlier configure of this build directory.
#
# The declarations accumulate in cache variables so that they survive the directory scopes
# they are made in (src/openms_gui).
# Cache variables also survive a reconfigure, so without this every configure would append
# the whole list again.
function(openms_reset_topp_tools)
  set(TOPP_TOOLS "" CACHE INTERNAL "OpenMS' TOPP tools" FORCE)
  set(TOPP_TOOL_CATEGORIES "" CACHE INTERNAL "TOPPAS category of the entry of TOPP_TOOLS at the same index" FORCE)
endfunction()

#------------------------------------------------------------------------------
# openms_topp_tool(<Name> <Category>)
#
# @param Name     the tool, built from <Name>.cpp or from the subdirectory <Name>/
# @param Category the TOPPAS category, e.g. "Misc". Use one of the categories of the
#                 OpenMS core (doc/doxygen/public/TOPP.doxygen of OpenMS).
function(openms_topp_tool name category)
  if(ARGN)
    message(FATAL_ERROR "openms_topp_tool(${name}): unexpected arguments '${ARGN}'. Usage: openms_topp_tool(<Name> <Category>)")
  endif()
  if("${name}" STREQUAL "")
    message(FATAL_ERROR "openms_topp_tool(): the tool name may not be empty")
  endif()
  if("${category}" STREQUAL "")
    message(FATAL_ERROR "openms_topp_tool(${name}): a category is required; it is what TOPPAS groups the tool under")
  endif()
  if(name IN_LIST TOPP_TOOLS)
    message(FATAL_ERROR "openms_topp_tool(${name}): this tool is already declared. ToolHandler refuses to start any "
                        "tool when a name is registered twice, so the duplicate is rejected here instead.")
  endif()
  ## Some workflow systems read a slash in a category as a subcategory separator.
  if(category MATCHES "/")
    message(FATAL_ERROR "openms_topp_tool(${name}): the category '${category}' contains a '/', which some workflow "
                        "systems read as a subcategory separator. Use a plain category name.")
  endif()
  ## ';' would split the entry into two list elements and desynchronize it from TOPP_TOOLS.
  if(category MATCHES ";")
    message(FATAL_ERROR "openms_topp_tool(${name}): the category '${category}' contains a ';'.")
  endif()

  set(TOPP_TOOLS ${TOPP_TOOLS} "${name}"
      CACHE INTERNAL "OpenMS' TOPP tools" FORCE)
  set(TOPP_TOOL_CATEGORIES ${TOPP_TOOL_CATEGORIES} "${category}"
      CACHE INTERNAL "TOPPAS category of the entry of TOPP_TOOLS at the same index" FORCE)
endfunction()

#------------------------------------------------------------------------------
# openms_write_tool_registry(<out_file> [TOOLS <name>...])
#
# Write the registry of every tool declared so far. Call it once, after every
# add_subdirectory() that declares tools.
#
# TOOLS restricts the file to the given subset of the declared tools.
#
# Without any tool to list, no file is written and a file an earlier configure of this build
# directory left behind is removed: a build of the libraries alone registers nothing.
#
# The format is the tab-separated one the rest of share/OpenMS uses for tabular data, read
# back by ToolHandler through CsvFile:
#
#   # comment
#   <tool name>\t<TOPPAS category>[\t<type>;<type>...]
#
# The third column is the list of '-type' sub-modes a tool offers and is omitted by tools
# that have none, which is all of them today.
function(openms_write_tool_registry out_file)
  cmake_parse_arguments(PARSE_ARGV 1 _registry "" "" "TOOLS")
  if(_registry_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "openms_write_tool_registry(${out_file}): unexpected arguments '${_registry_UNPARSED_ARGUMENTS}'")
  endif()
  list(LENGTH TOPP_TOOLS _tool_count)
  list(LENGTH TOPP_TOOL_CATEGORIES _category_count)
  if(NOT _tool_count EQUAL _category_count)
    message(FATAL_ERROR "The TOPP tool declarations are inconsistent: ${_tool_count} tools but ${_category_count} "
                        "categories. Both lists are only ever appended to by openms_topp_tool().")
  endif()

  ## Ordered by tool name, so a reconfigure that declares the same tools produces a
  ## byte-identical file. Sorting the names themselves rather than "name<sep>category" pairs:
  ## any separator sorts somewhere among the letters and would order 'FooBar' before 'Foo'.
  set(_sorted_names ${TOPP_TOOLS})
  if("TOOLS" IN_LIST ARGN)
    foreach(_name IN LISTS _registry_TOOLS)
      if(NOT _name IN_LIST TOPP_TOOLS)
        message(FATAL_ERROR "openms_write_tool_registry(${out_file}): '${_name}' is not a declared tool")
      endif()
    endforeach()
    set(_sorted_names ${_registry_TOOLS})
  endif()
  list(LENGTH _sorted_names _tool_count)
  if(_tool_count EQUAL 0)
    file(REMOVE "${out_file}")
    message(STATUS "TOPP tool registry: no tools, ${out_file} not written")
    return()
  endif()
  list(SORT _sorted_names CASE INSENSITIVE)

  set(_content
"# GENERATED FILE, do not edit and do not commit.
#
# The TOPP tool registry of the GUI layer (OpenMS-TOPP-GUI): what ToolHandler lists, and the
# category TOPPAS groups each tool under. Written by openms_write_tool_registry()
# (cmake/topp_tool_macros.cmake) from the openms_topp_tool() declarations in
# src/openms_gui/CMakeLists.txt. The tools of the OpenMS core are in OpenMS.tsv next to it.
#
# A tool describes itself (parameters, formats, documentation) through its own binary, via
# -write_ctd, so the registry carries nothing but the name and the category. Tools built
# outside this repository register themselves by installing their own *.tsv alongside this
# one; a name may be registered only once across all of them.
#
# <tool name>\t<TOPPAS category>
")
  foreach(_name IN LISTS _sorted_names)
    ## openms_topp_tool() rejects a duplicate name, so this finds the one declaration.
    list(FIND TOPP_TOOLS "${_name}" _index)
    list(GET TOPP_TOOL_CATEGORIES ${_index} _category)
    string(APPEND _content "${_name}\t${_category}\n")
  endforeach()

  ## Only rewrite on a real change, so a reconfigure does not restamp the file.
  set(_previous "")
  if(EXISTS "${out_file}")
    file(READ "${out_file}" _previous)
  endif()
  if(NOT _previous STREQUAL _content)
    file(WRITE "${out_file}" "${_content}")
  endif()
  message(STATUS "TOPP tool registry: ${_tool_count} tools -> ${out_file}")
endfunction()
