# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

cmake_minimum_required(VERSION 3.24 FATAL_ERROR)

### Builds one installation prefix out of several, the way installing the GUI layer into
### the prefix of the OpenMS core does, without writing into the core's prefix:
###
###   cmake -DDEST=<new prefix> "-DSOURCES=<prefix>;<prefix>..." [-DENTRIES=<name>;...] -P merge_prefixes.cmake
###
### A directory present in more than one source becomes a real directory and is merged
### recursively; every other entry is linked (symbolic link, or a copy where links cannot
### be created, e.g. on Windows without the privilege). A file present in more than one
### source is an error: the GUI layer must not install anything the core ships.
### ENTRIES restricts the top level to the given names (default: everything).

foreach(_required DEST SOURCES)
  if(NOT DEFINED ${_required})
    message(FATAL_ERROR "merge_prefixes.cmake: -D${_required}= is required")
  endif()
endforeach()

function(_link_entry source dest)
  file(CREATE_LINK "${source}" "${dest}" RESULT _result SYMBOLIC)
  if(NOT _result EQUAL 0)
    if(IS_DIRECTORY "${source}")
      file(COPY "${source}/" DESTINATION "${dest}")
    else()
      get_filename_component(_dest_dir "${dest}" DIRECTORY)
      file(COPY "${source}" DESTINATION "${_dest_dir}")
    endif()
  endif()
endfunction()

function(_merge dest sources names)
  file(MAKE_DIRECTORY "${dest}")
  foreach(_name IN LISTS names)
    set(_having)
    foreach(_source IN LISTS sources)
      if(EXISTS "${_source}/${_name}" OR IS_SYMLINK "${_source}/${_name}")
        list(APPEND _having "${_source}/${_name}")
      endif()
    endforeach()
    list(LENGTH _having _count)
    if(_count EQUAL 1)
      _link_entry("${_having}" "${dest}/${_name}")
    elseif(_count GREATER 1)
      set(_subsources)
      set(_subnames)
      foreach(_entry IN LISTS _having)
        if(NOT IS_DIRECTORY "${_entry}")
          string(REPLACE ";" ", " _list "${_having}")
          message(FATAL_ERROR "'${_name}' is a file in more than one prefix: ${_list}")
        endif()
        list(APPEND _subsources "${_entry}")
        file(GLOB _children RELATIVE "${_entry}" "${_entry}/*")
        list(APPEND _subnames ${_children})
      endforeach()
      list(REMOVE_DUPLICATES _subnames)
      _merge("${dest}/${_name}" "${_subsources}" "${_subnames}")
    endif()
  endforeach()
endfunction()

if(EXISTS "${DEST}")
  message(FATAL_ERROR "merge_prefixes.cmake: '${DEST}' exists already")
endif()

if(DEFINED ENTRIES)
  set(_names ${ENTRIES})
else()
  set(_names)
  foreach(_source IN LISTS SOURCES)
    file(GLOB _children RELATIVE "${_source}" "${_source}/*")
    list(APPEND _names ${_children})
  endforeach()
  list(REMOVE_DUPLICATES _names)
endif()
_merge("${DEST}" "${SOURCES}" "${_names}")
message(STATUS "Merged ${SOURCES} into ${DEST}")
