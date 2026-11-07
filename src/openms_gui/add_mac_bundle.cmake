# Copyright (c) 2002-present, OpenMS Inc. -- EKU Tuebingen, ETH Zurich, and FU Berlin
# SPDX-License-Identifier: BSD-3-Clause
#
# --------------------------------------------------------------------------
# $Maintainer: Julianus Pfeuffer $
# $Authors: Stephan Aiche, Julianus Pfeuffer $
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# add_mac_app_bundle(<name>)
# Adds the GUI application <name> as a macOS app bundle and installs it.
#
# In the macOS package (PACKAGE_TYPE pkg) the bundle goes into the root of the OpenMS
# folder, next to its lib/ and bin/. It is not self-contained: it loads the OpenMS
# libraries and Qt from lib/ and the Qt plugins from lib/plugins (its qt.conf points
# there; the plugins are installed by src/openms_gui/CMakeLists.txt). A plain installation
# puts the bundle into ${INSTALL_BIN_DIR}.
macro(add_mac_app_bundle _name)
	# the icon file
	set(ICON_FILE_PATH      "${PROJECT_SOURCE_DIR}/source/VISUAL/APPLICATIONS/GUITOOLS/${_name}-resources/${_name}.icns")
	set(INFO_PLIST_TEMPLATE "${PROJECT_SOURCE_DIR}/source/VISUAL/APPLICATIONS/GUITOOLS/${_name}-resources/${_name}.plist.in")
	get_filename_component(ICON_FILE_NAME "${ICON_FILE_PATH}" NAME)

	# LSMinimumSystemVersion in the Info.plist template: the macOS the build targets. Package
	# builds set it through MACOSX_DEPLOYMENT_TARGET. A build without a target runs on the
	# macOS it was built on, so it keeps the permissive 12.0 the templates used to hardcode.
	if(CMAKE_OSX_DEPLOYMENT_TARGET)
		set(OPENMS_BUNDLE_MINIMUM_SYSTEM_VERSION "${CMAKE_OSX_DEPLOYMENT_TARGET}")
	else()
		set(OPENMS_BUNDLE_MINIMUM_SYSTEM_VERSION "12.0")
	endif()

	add_executable(
		${_name}
		MACOSX_BUNDLE
		${GUI_DIR}/${_name}.cpp
		${ICON_FILE_PATH})

	## <bundle>/Contents/MacOS/<name>: three levels up is the folder that holds the bundle
	if("${PACKAGE_TYPE}" STREQUAL "pkg")
		set(_bundle_lib_rpath "@executable_path/../../../${INSTALL_LIB_DIR}")
	else()
		set(_bundle_lib_rpath "@executable_path/../../../${INSTALL_LIB_PATH_REL_TO_BIN}")
	endif()
	set_target_properties(${_name} PROPERTIES INSTALL_RPATH "${_bundle_lib_rpath}")

	string(TIMESTAMP MY_YEAR "%Y")

	set_target_properties(${_name} PROPERTIES
		# we want our own info.plist template
		MACOSX_BUNDLE_INFO_PLIST "${INFO_PLIST_TEMPLATE}"
		MACOSX_BUNDLE_INFO_STRING "${PROJECT_NAME} Version ${OPENMS_PACKAGE_VERSION}, Copyright ${MY_YEAR} The OpenMS Team."
		MACOSX_BUNDLE_ICON_FILE ${ICON_FILE_NAME}
		MACOSX_BUNDLE_GUI_IDENTIFIER "de.openms.${_name}"
		MACOSX_BUNDLE_LONG_VERSION_STRING "${PROJECT_NAME} Version ${OPENMS_PACKAGE_VERSION}"
		MACOSX_BUNDLE_BUNDLE_NAME ${_name}
		MACOSX_BUNDLE_SHORT_VERSION_STRING "${OPENMS_PACKAGE_VERSION}"
		MACOSX_BUNDLE_BUNDLE_VERSION "${OPENMS_PACKAGE_VERSION}"
		MACOSX_BUNDLE_COPYRIGHT "Copyright ${MY_YEAR}, The OpenMS Team. All Rights Reserved."
	)

	set_source_files_properties(${ICON_FILE_PATH} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

	if("${PACKAGE_TYPE}" STREQUAL "pkg")
		## into the root of the OpenMS folder
		install(TARGETS ${_name} BUNDLE
						DESTINATION .
						COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
		## Listed in the component plist of the pkg (cmake/generate_applications_component_plist.cmake)
		set_property(GLOBAL APPEND PROPERTY OPENMS_APP_BUNDLES ${_name})

		## The Qt plugins in lib/plugins, relative to <bundle>/Contents
		file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/macappqt.conf"
				 "[Paths]\nPlugins = ../../${INSTALL_PLUGIN_DIR}\n")
		install(FILES "${CMAKE_CURRENT_BINARY_DIR}/macappqt.conf"
						DESTINATION "${_name}.app/Contents/Resources/"
						RENAME "qt.conf"
						COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})

		## Load Qt through @rpath, i.e. from lib/ (the runtime dependency set of
		## cmake/package_general.cmake has put it there); then sign the bundle, which the fix-up
		## would invalidate afterwards.
		install(CODE "
execute_process(COMMAND ${OPENMS_HOST_DIRECTORY}/cmake/MacOSX/fix_dependencies.rb -b \${CMAKE_INSTALL_PREFIX}/${_name}.app/Contents/MacOS/ -e @rpath/ -n -c RESULT_VARIABLE fix_result)
if(NOT fix_result EQUAL 0)
  message(FATAL_ERROR \"fix_dependencies.rb failed for ${_name}.app (\${fix_result})\")
endif()" COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
		## The identity is CPACK_BUNDLE_APPLE_CERT_APP (the top-level CMakeLists.txt; '-' signs ad hoc).
		## It has to be unique and present in an unlocked keychain of the search list. A secure
		## timestamp is only requested for a real identity (ad hoc signatures cannot have one).
		if("${CPACK_BUNDLE_APPLE_CERT_APP}" STREQUAL "-")
			set(_codesign_timestamp "")
		else()
			set(_codesign_timestamp "--timestamp")
		endif()
		install(CODE "
execute_process(COMMAND codesign --deep --force --options runtime ${_codesign_timestamp} --sign \"${CPACK_BUNDLE_APPLE_CERT_APP}\" -i de.openms.${_name} \${CMAKE_INSTALL_PREFIX}/${_name}.app RESULT_VARIABLE sign_result OUTPUT_VARIABLE sign_out ERROR_VARIABLE sign_out)
message(STATUS \"\${sign_out}\")
if(NOT sign_result EQUAL 0)
  message(FATAL_ERROR \"codesign failed for ${_name}.app (\${sign_result})\")
endif()
execute_process(COMMAND codesign -dv \${CMAKE_INSTALL_PREFIX}/${_name}.app OUTPUT_VARIABLE sign_check_out ERROR_VARIABLE sign_check_out)
message(STATUS \"\${sign_check_out}\")" COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT})
		unset(_codesign_timestamp)
	else()
		## A plain installation: the bundle finds the libraries through its install RPATH. A
		## runtime dependency set takes at most one bundle executable, hence one per bundle
		## (nothing installs them).
		install(TARGETS ${_name} RUNTIME_DEPENDENCY_SET ${_name}_DEPS
						RUNTIME DESTINATION ${INSTALL_BIN_DIR} COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT}
						BUNDLE DESTINATION ${INSTALL_BIN_DIR} COMPONENT ${OPENMS_GUI_APPLICATIONS_COMPONENT}
						)
	endif()
endmacro()
