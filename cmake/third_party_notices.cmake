# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

## share/OpenMS/THIRD-PARTY-NOTICES-GUI.txt holds the license, copyright and notice texts of the
## third-party software the GUI packages bundle, in one file. The GUI layer is installed into
## the folder of the OpenMS core, which has its own THIRD-PARTY-NOTICES.txt, hence the name.
## The file first lists the components, grouped by where they come from, each with the numbers
## of the texts that apply to it. The texts follow, each only once: components whose texts are
## identical share a number. The files the texts come from stay where they are installed, in
## share/OpenMS/LICENSES.
##
## cmake/third_party_licenses.cmake records the files it installs with
## openms_add_third_party_notice(). openms_install_third_party_notices(), which the top-level
## CMakeLists.txt calls last, writes the list of recorded files when configuring, and the
## notices from that list when installing. Nothing is recorded where the GUI bundles nothing
## (Linux, a plain installation), and then no notices file is installed.
##
## The Debian package installs the GUI's license, followed by the notices if there are any, as
## /usr/share/doc/openms-gui/copyright, the file Debian's policy asks every package to have.

## The functions below keep these policies wherever they are called from, also in the install
## script, which sets none. include() gives this file a policy scope of its own, so the setting
## does not leak into the including project.
cmake_policy(VERSION 3.24)

set(OPENMS_THIRD_PARTY_NOTICES_FILE "THIRD-PARTY-NOTICES-GUI.txt")

## openms_add_third_party_notice(<path> <file>)
##   Records that the installation contains <file> as share/OpenMS/<path>.
function(openms_add_third_party_notice path file)
  set_property(GLOBAL APPEND PROPERTY OPENMS_THIRD_PARTY_NOTICES "${path}|${file}")
endfunction()

## openms_install_third_party_notices()
##   Installs share/OpenMS/THIRD-PARTY-NOTICES-GUI.txt, made from the files recorded so far, in
##   the component Dependencies (with the libraries it is about), and for a Debian package the
##   copyright file in the component of the GUI applications.
function(openms_install_third_party_notices)
  set(_dir "${PROJECT_BINARY_DIR}/third_party_notices")
  get_property(_notices GLOBAL PROPERTY OPENMS_THIRD_PARTY_NOTICES)
  list(JOIN _notices "\n" _list)
  file(WRITE "${_dir}/files.txt" "${_list}\n")
  set(_debian_copyright "")
  ## PACKAGE_TYPE, not CPACK_GENERATOR: include(CPack) resets the latter to its defaults.
  if("${PACKAGE_TYPE}" STREQUAL "deb")
    set(_debian_copyright "LICENSE \"${OPENMS_HOST_DIRECTORY}/License.txt\" LICENSE_OUTPUT \"${_dir}/copyright\"")
  endif()
  list(LENGTH _notices _count)
  if(_count GREATER 0)
    install(CODE "
      include(\"${CMAKE_CURRENT_FUNCTION_LIST_FILE}\")
      openms_write_third_party_notices(OUTPUT \"${_dir}/${OPENMS_THIRD_PARTY_NOTICES_FILE}\"
                                       FILE_LIST \"${_dir}/files.txt\")"
      COMPONENT Dependencies)
    install(FILES "${_dir}/${OPENMS_THIRD_PARTY_NOTICES_FILE}"
            DESTINATION "${INSTALL_SHARE_DIR}"
            COMPONENT Dependencies)
    message(STATUS "${OPENMS_THIRD_PARTY_NOTICES_FILE}: ${_count} license, copyright and notice files")
  endif()
  if(_debian_copyright)
    install(CODE "
      include(\"${CMAKE_CURRENT_FUNCTION_LIST_FILE}\")
      openms_write_third_party_notices(FILE_LIST \"${_dir}/files.txt\" ${_debian_copyright})"
      COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
    ## Debian policy 12.5: /usr/share/doc/<package>/copyright, neither compressed nor a
    ## symbolic link.
    install(FILES "${_dir}/copyright"
            DESTINATION "share/doc/${CPACK_DEBIAN_PACKAGE_NAME}"
            COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
  endif()
endfunction()

## Sets <text_var> to the content of <file> with Unix line ends and without trailing
## whitespace, and <binary_var> to TRUE if <file> is not a text file, i.e. has a NUL byte in
## its first 8 KiB. file(READ) drops carriage returns, so the length of what it reads says
## nothing.
function(_openms_third_party_notice_text text_var binary_var file)
  file(READ "${file}" _head LIMIT 8192 HEX)
  ## " <byte> <byte> ...", so that " 00" can only match a whole byte.
  string(REGEX REPLACE "(..)" " \\1" _head "${_head}")
  string(FIND "${_head}" " 00" _nul)
  if(NOT _nul EQUAL -1)
    set(${binary_var} TRUE PARENT_SCOPE)
    set(${text_var} "" PARENT_SCOPE)
    return()
  endif()
  file(READ "${file}" _text)
  string(REPLACE "\r" "" _text "${_text}")
  string(REGEX REPLACE "[ \t\n]+$" "" _text "${_text}")
  set(${binary_var} FALSE PARENT_SCOPE)
  set(${text_var} "${_text}" PARENT_SCOPE)
endfunction()

## Sets <group_var> to the number of the group <path> belongs to (the order of the groups in
## the notices) and <component_var> to the name of its component.
function(_openms_third_party_notice_component group_var component_var path)
  get_filename_component(_name "${path}" NAME)
  if(path MATCHES "^LICENSES/Qt/")
    set(_group 1)
    set(_component "Qt")
  elseif(path MATCHES "^LICENSES/homebrew/(.+)$")
    set(_group 2)
    get_filename_component(_component "${CMAKE_MATCH_1}" DIRECTORY)
  else()
    set(_group 3)
    set(_component "${path}")
  endif()
  set(${group_var} "${_group}" PARENT_SCOPE)
  set(${component_var} "${_component}" PARENT_SCOPE)
endfunction()

## openms_write_third_party_notices([OUTPUT <output>] FILE_LIST <list>
##                                  [LICENSE <license> LICENSE_OUTPUT <output>])
##   Writes the notices for the files named in <list> (lines "<path>|<file>", as
##   openms_install_third_party_notices() writes them) to <output>. With LICENSE, also writes
##   LICENSE_OUTPUT: <license>, followed by the notices if there are any.
function(openms_write_third_party_notices)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "OUTPUT;FILE_LIST;LICENSE;LICENSE_OUTPUT" "")
  set(_entries)
  file(STRINGS "${arg_FILE_LIST}" _entries ENCODING UTF-8)

  ## Order: by group, then by path; "<group>|<path>|<file>".
  set(_sorted)
  foreach(_entry IN LISTS _entries)
    string(REPLACE "|" ";" _entry "${_entry}")
    list(GET _entry 0 _path)
    list(GET _entry 1 _file)
    if(NOT EXISTS "${_file}")
      message(FATAL_ERROR "${OPENMS_THIRD_PARTY_NOTICES_FILE}: ${_file} (installed as ${_path}) does not exist")
    endif()
    _openms_third_party_notice_component(_group _component "${_path}")
    list(APPEND _sorted "${_group}|${_path}|${_file}")
  endforeach()
  list(REMOVE_DUPLICATES _sorted)
  list(SORT _sorted)

  set(_notices_text "")
  if(_sorted)
    ## Numbers the distinct texts and collects, per component, the numbers of its texts.
    set(_hashes)        ## hash of each numbered text; its number is its index + 1
    set(_text_files)    ## the file each numbered text is read from
    set(_text_paths)    ## and where it is installed
    set(_components)    ## "<group>|<component>", in order
    foreach(_entry IN LISTS _sorted)
      string(REPLACE "|" ";" _entry "${_entry}")
      list(GET _entry 1 _path)
      list(GET _entry 2 _file)
      _openms_third_party_notice_component(_group _component "${_path}")
      set(_key "${_group}|${_component}")
      string(MD5 _refs "${_key}")
      set(_refs "_refs_${_refs}")
      if(NOT _key IN_LIST _components)
        list(APPEND _components "${_key}")
        set(${_refs} "")
      endif()
      _openms_third_party_notice_text(_text _binary "${_file}")
      if(_binary)
        string(APPEND ${_refs} " ${_path} (not a text file)")
        continue()
      endif()
      ## Texts that differ only in white space (line breaks, indentation) are the same text.
      string(REGEX REPLACE "[ \t\n]+" " " _hash "${_text}")
      string(SHA256 _hash "${_hash}")
      list(FIND _hashes "${_hash}" _index)
      if(_index EQUAL -1)
        list(APPEND _hashes "${_hash}")
        list(APPEND _text_files "${_file}")
        list(APPEND _text_paths "${_path}")
        list(LENGTH _hashes _number)
      else()
        math(EXPR _number "${_index} + 1")
      endif()
      if(NOT "${${_refs}}" MATCHES " \\[${_number}\\]( |$)")
        string(APPEND ${_refs} " [${_number}]")
      endif()
    endforeach()

    set(_titles "Qt" "Libraries from Homebrew" "Other")
    set(_rule "==========================================================================================")
    string(CONCAT _notices_text
      "THIRD-PARTY SOFTWARE NOTICES OF THE OPENMS GUI\n"
      "\n"
      "This installation of the OpenMS GUI (TOPPView, TOPPAS, INIFileEditor and the TOPP tools that\n"
      "need the GUI library) contains the third-party software listed below. Each component is\n"
      "followed by the numbers of the license, copyright and notice texts that apply to it. The\n"
      "texts come after the list, each only once: components whose texts are identical share a\n"
      "number. Paths are relative to share/OpenMS, the folder in which the installation keeps the\n"
      "same files as their projects distribute them. THIRD-PARTY-NOTICES.txt next to this file\n"
      "lists the third-party software of the OpenMS core.\n")
    set(_current_group "")
    foreach(_key IN LISTS _components)
      string(REPLACE "|" ";" _parts "${_key}")
      list(GET _parts 0 _group)
      list(GET _parts 1 _component)
      if(NOT _group STREQUAL _current_group)
        math(EXPR _title_index "${_group} - 1")
        list(GET _titles ${_title_index} _title)
        string(APPEND _notices_text "\n${_title}\n")
        set(_current_group "${_group}")
      endif()
      string(MD5 _refs "${_key}")
      set(_refs "_refs_${_refs}")
      string(LENGTH "${_component}" _length)
      set(_padding " ")
      if(_length LESS 44)
        math(EXPR _pad "44 - ${_length}")
        string(REPEAT " " ${_pad} _padding)
      endif()
      string(APPEND _notices_text "  ${_component}${_padding}${${_refs}}\n")
    endforeach()

    set(_number 0)
    foreach(_file IN LISTS _text_files)
      list(GET _text_paths ${_number} _path)
      math(EXPR _number "${_number} + 1")
      _openms_third_party_notice_text(_text _binary "${_file}")
      string(APPEND _notices_text "\n\n${_rule}\n[${_number}] ${_path}\n${_rule}\n\n${_text}\n")
    endforeach()
    list(LENGTH _components _component_count)
    list(LENGTH _text_files _text_count)
  endif()

  if(arg_OUTPUT)
    file(WRITE "${arg_OUTPUT}.tmp" "${_notices_text}")
    file(RENAME "${arg_OUTPUT}.tmp" "${arg_OUTPUT}")
    message(STATUS "Wrote ${arg_OUTPUT}: ${_component_count} components, ${_text_count} texts")
  endif()
  if(arg_LICENSE)
    file(READ "${arg_LICENSE}" _license)
    if(_notices_text)
      set(_license "${_license}\n\n${_rule}\n\n${_notices_text}")
    endif()
    file(WRITE "${arg_LICENSE_OUTPUT}" "${_license}")
  endif()
endfunction()
