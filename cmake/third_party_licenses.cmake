# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Timo Sachsenberg $
# $Authors: Timo Sachsenberg $
# --------------------------------------------------------------------------

## The Windows and macOS packages of the GUI bundle Qt, and the licenses of Qt require their
## texts to accompany the binaries. openms_install_third_party_licenses(), called by
## cmake/package_general.cmake, installs them under share/OpenMS/LICENSES in the component
## Dependencies, which holds the bundled libraries:
## - Qt/: the GUI uses Qt under the LGPL version 3, which requires its text, the text of the
##   GPL version 3 that it supplements, and a note on where to get the source code of the
##   bundled Qt. The Linux packages depend on the distribution's Qt and install none of this.
## - homebrew/<formula>/: on macOS, Qt and the libraries it needs (glib, ICU, freetype, ...)
##   come from Homebrew. Homebrew installs the license files of a formula into its keg, and
##   these are installed for the given formulae and every installed formula they depend on.
##
## Each installed file is recorded for share/OpenMS/THIRD-PARTY-NOTICES-GUI.txt, which gathers
## the texts in one file (cmake/third_party_notices.cmake).

## Sets <formulae_var> to the Homebrew formulae whose kegs hold the given paths, and
## <prefix_var> to the prefix of the Homebrew installation they belong to.
function(openms_homebrew_formulae_of formulae_var prefix_var)
  set(_formulae)
  set(_prefixes)
  foreach(_path IN LISTS ARGN)
    if(NOT EXISTS "${_path}")
      continue()
    endif()
    ## <prefix>/opt/<formula> and the files linked into <prefix>/lib resolve to the keg,
    ## <prefix>/Cellar/<formula>/<version>.
    file(REAL_PATH "${_path}" _real)
    if(_real MATCHES "^(.*)/Cellar/([^/]+)/[^/]+(/|$)")
      list(APPEND _prefixes "${CMAKE_MATCH_1}")
      list(APPEND _formulae "${CMAKE_MATCH_2}")
    endif()
  endforeach()
  list(REMOVE_DUPLICATES _formulae)
  list(REMOVE_DUPLICATES _prefixes)
  list(LENGTH _prefixes _count)
  if(_count GREATER 1)
    ## A Mac can have two Homebrew installations, /opt/homebrew and /usr/local.
    message(FATAL_ERROR "The paths ${ARGN} belong to more than one Homebrew installation: "
                        "${_prefixes}")
  endif()
  set(${formulae_var} "${_formulae}" PARENT_SCOPE)
  set(${prefix_var} "${_prefixes}" PARENT_SCOPE)
endfunction()

## openms_install_third_party_licenses([QT_VERSION <version>]
##                                     [HOMEBREW_PREFIX <prefix> HOMEBREW_FORMULAE <formula>...])
##   QT_VERSION         the version of the Qt the package bundles; empty if it bundles none
##   HOMEBREW_PREFIX    the prefix of the Homebrew installation the formulae come from
##   HOMEBREW_FORMULAE  the Homebrew formulae the package bundles libraries of; their
##                      dependencies are added
function(openms_install_third_party_licenses)
  cmake_parse_arguments(PARSE_ARGV 0 arg "" "QT_VERSION;HOMEBREW_PREFIX" "HOMEBREW_FORMULAE")
  set(_licenses_dir "${INSTALL_SHARE_DIR}/LICENSES")

  if(arg_QT_VERSION)
    set(_qt_licenses "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/third_party_licenses/Qt")
    ## The variables README.txt.in refers to.
    set(QT_LICENSE_VERSION "${arg_QT_VERSION}")
    string(REGEX MATCH "^[0-9]+\\.[0-9]+" QT_LICENSE_MAJOR_MINOR "${arg_QT_VERSION}")
    set(QT_LICENSE_HOMEBREW_NOTE "")
    if(arg_HOMEBREW_FORMULAE)
      string(CONCAT QT_LICENSE_HOMEBREW_NOTE
             "\nOn macOS, Qt comes from Homebrew. The Homebrew formulae, including any patches\n"
             "Homebrew applies to Qt, are at https://github.com/Homebrew/homebrew-core; ../homebrew\n"
             "holds the license files of the formulae whose libraries this package bundles.\n")
    endif()
    configure_file("${_qt_licenses}/README.txt.in"
                   "${PROJECT_BINARY_DIR}/third_party_licenses/Qt/README.txt" @ONLY)
    set(_qt_files "${_qt_licenses}/LGPL-3.0-only.txt"
                  "${_qt_licenses}/GPL-3.0-only.txt"
                  "${PROJECT_BINARY_DIR}/third_party_licenses/Qt/README.txt")
    install(FILES ${_qt_files}
            DESTINATION "${_licenses_dir}/Qt"
            COMPONENT Dependencies)
    foreach(_file IN LISTS _qt_files)
      get_filename_component(_name "${_file}" NAME)
      openms_add_third_party_notice("LICENSES/Qt/${_name}" "${_file}")
    endforeach()
    message(STATUS "Packaging the Qt ${arg_QT_VERSION} licenses")
  endif()

  if(arg_HOMEBREW_FORMULAE)
    ## The package bundles libraries of these formulae and their dependencies, so configuring
    ## fails rather than leave their license files out. The brew of the installation the
    ## formulae come from is used, not the one on the PATH: a brew answers for its own
    ## installation only, and a Mac can have two.
    set(_brew "${arg_HOMEBREW_PREFIX}/bin/brew")
    if(NOT arg_HOMEBREW_PREFIX OR NOT EXISTS "${_brew}")
      message(FATAL_ERROR "The package bundles libraries of the Homebrew formulae "
                          "${arg_HOMEBREW_FORMULAE}, but '${_brew}', which is needed to collect "
                          "their license files, does not exist.")
    endif()
    ## --union: the dependencies of any of the formulae, not only those they all share.
    ## Both the dependencies recorded in the installed kegs (--installed) and those the
    ## formulae declare are collected. The recorded ones alone miss formulae: in the Release
    ## run of 2026-10-08, 'brew deps --installed' left out exactly the dependencies that
    ## 'brew install qtbase' had upgraded in the same run (glib, harfbuzz, pcre2, libpng,
    ## cairo, ...), although the package bundles their libraries. homebrew-core's CI checks
    ## that a formula declares every formula it links against, so the declared ones cover
    ## what is bundled.
    set(_dependencies)
    foreach(_installed_only "--installed" "")
      execute_process(COMMAND "${_brew}" deps ${_installed_only} --union ${arg_HOMEBREW_FORMULAE}
                      OUTPUT_VARIABLE _deps
                      RESULT_VARIABLE _result
                      ERROR_VARIABLE _error
                      OUTPUT_STRIP_TRAILING_WHITESPACE
                      ERROR_STRIP_TRAILING_WHITESPACE)
      if(NOT _result EQUAL 0)
        message(FATAL_ERROR "'brew deps ${_installed_only} --union' failed (${_error}), so the "
                            "license files of the dependencies of the Homebrew formulae "
                            "${arg_HOMEBREW_FORMULAE}, whose libraries the package bundles, "
                            "cannot be collected.")
      endif()
      string(REGEX REPLACE "[ \t\r\n]+" ";" _deps "${_deps}")
      list(APPEND _dependencies ${_deps})
    endforeach()
    set(_formulae ${arg_HOMEBREW_FORMULAE} ${_dependencies})
    list(REMOVE_DUPLICATES _formulae)
    list(SORT _formulae)

    set(_without_license)
    set(_not_installed)
    foreach(_formula IN LISTS _formulae)
      execute_process(COMMAND "${_brew}" --prefix "${_formula}"
                      OUTPUT_VARIABLE _prefix
                      RESULT_VARIABLE _result
                      ERROR_QUIET
                      OUTPUT_STRIP_TRAILING_WHITESPACE)
      ## 'brew --prefix' names the opt link of a formula whether or not it is installed. A
      ## declared dependency that is not installed (an optional one, or one the formula
      ## gained after it was installed) cannot have a library in the package.
      if(NOT _result EQUAL 0 OR NOT IS_DIRECTORY "${_prefix}")
        list(APPEND _not_installed "${_formula}")
        continue()
      endif()
      file(REAL_PATH "${_prefix}" _keg)
      ## Homebrew copies a formula's top-level license files (COPYING, LICENSE.md, ...)
      ## into the root of its keg; some formulae install them to share/doc/<formula> or
      ## share/licenses/<formula> instead. The first of these folders that has any is used,
      ## as tools/ci/collect_wheel_licenses.py does for the wheels.
      set(_license_files)
      foreach(_folder "${_keg}" "${_keg}/share/doc/${_formula}" "${_keg}/share/licenses/${_formula}")
        file(GLOB _keg_files LIST_DIRECTORIES false "${_folder}/*")
        foreach(_file IN LISTS _keg_files)
          get_filename_component(_name "${_file}" NAME)
          string(TOUPPER "${_name}" _name)
          if(_name MATCHES "^(COPYING|COPYRIGHT|LICENSE|LICENCE|NOTICE)")
            list(APPEND _license_files "${_file}")
          endif()
        endforeach()
        if(_license_files)
          break()
        endif()
      endforeach()
      if(_license_files)
        install(FILES ${_license_files}
                DESTINATION "${_licenses_dir}/homebrew/${_formula}"
                COMPONENT Dependencies)
        foreach(_file IN LISTS _license_files)
          get_filename_component(_name "${_file}" NAME)
          openms_add_third_party_notice("LICENSES/homebrew/${_formula}/${_name}" "${_file}")
        endforeach()
      else()
        list(APPEND _without_license "${_formula}")
      endif()
    endforeach()
    list(LENGTH _formulae _count)
    list(LENGTH _not_installed _count_not_installed)
    math(EXPR _count "${_count} - ${_count_not_installed}")
    message(STATUS "Packaging the license files of ${_count} Homebrew formulae")
    if(_not_installed)
      message(STATUS "Declared Homebrew dependencies that are not installed: ${_not_installed}")
    endif()
    if(_without_license)
      ## Expected for Qt's own formulae, whose keg holds its licenses only in a LICENSES
      ## directory; the Qt licenses are installed above.
      message(STATUS "No license file in the Homebrew kegs of: ${_without_license}")
    endif()
  endif()
endfunction()
