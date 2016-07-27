#!/usr/bin/cmake -P

# Generate file with list of resource XMLs, from which R java files will be
# generated later by aapt tool.
#
# Arguments:
#   RES_DIR                       - path to Android resources directory, usually $project/res
#   PACKAGE_NAME_FILE             - path to file with package name, extracted from AndroidManifest.xml
#   RESOURCE_SOURCE_FILES_TARGET  - path where to gererate file with list of resource XMLs
#   RESOURCE_PACKAGE_FILES_TARGET - path where to generate target file for packaging


include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# read package name
file(READ "${PACKAGE_NAME_FILE}" _package_name)
string(REPLACE "." "/" _package_path "${_package_name}")


# create output directory
flat_create_file_directory("${RESOURCE_SOURCE_FILES_TARGET}")


# collect all directories
file(GLOB _dir_names RELATIVE "${RES_DIR}" "${RES_DIR}/*")


# load previous file with list of resource XMLs
set(_previous_resource_sources_target_found NO)
set(_previous_resource_sources)
if ( EXISTS "${RESOURCE_SOURCE_FILES_TARGET}" )
	set(_previous_resource_sources_target_found YES)
	file(READ "${RESOURCE_SOURCE_FILES_TARGET}" _previous_resource_sources)
endif()


# load previous resource package target
set(_previous_resource_package_target_found NO)
if ( EXISTS "${RESOURCE_PACKAGE_FILES_TARGET}" )
	set(_previous_resource_package_target_found YES)
endif()


# result
set(_found_resource_source_file_newer_than_target_file NO)
set(_found_resource_package_file_newer_than_target_file NO)
set(_found_resource_file_mismatched_with_previous_list NO)
set(_resource_sources)


# previous list iterator
list(LENGTH _previous_resource_sources _previous_resource_sources_count)
set(_previous_resource_sources_current_index 0)


macro ( _append_resource_files IS_SOURCE_FILE )
	set(_is_source_file "${IS_SOURCE_FILE}")

	foreach ( _source ${ARGN} )
		# Note:
		# If any of resource files found newer than package target file -
		# the whole package should be recreated. For that reason we updating
		# RESOURCE_PACKAGE_FILES_TARGET file timestamp.
		# If only data file (like bitmap) has been found newer - it is not
		# neccessary to update RESOURCE_SOURCE_FILES_TARGET, because data file
		# contents do not affect generated R.java identifiers, so we do not want
		# to trigger extra useless recompilation of R.java.
		if ( _is_source_file )
			if ( NOT _found_resource_source_file_newer_than_target_file AND "${_source}" IS_NEWER_THAN "${RESOURCE_SOURCE_FILES_TARGET}" )
				set(_found_resource_source_file_newer_than_target_file YES)
				set(_found_resource_package_file_newer_than_target_file YES)
			endif()
		else()
			if ( NOT _found_resource_package_file_newer_than_target_file AND "${_source}" IS_NEWER_THAN "${RESOURCE_PACKAGE_FILES_TARGET}" )
				set(_found_resource_package_file_newer_than_target_file YES)
			endif()
		endif()

		if ( NOT _found_resource_file_mismatched_with_previous_list )
			if ( "${_previous_resource_sources_current_index}" EQUAL "${_previous_resource_sources_count}" OR
					"${_previous_resource_sources_current_index}" GREATER "${_previous_resource_sources_count}" )
				set(_found_resource_file_mismatched_with_previous_list YES)
			else()
				list(GET _previous_resource_sources "${_previous_resource_sources_current_index}" _previous_resource_file_path)
				if ( NOT "${_source}" STREQUAL "${_previous_resource_file_path}" )
					set(_found_resource_file_mismatched_with_previous_list YES)
				endif()
			endif()
		endif()

		math(EXPR _previous_resource_sources_current_index "${_previous_resource_sources_current_index} + 1")
	endforeach()

	list(APPEND _resource_sources ${ARGN})
endmacro()


macro ( _append_resource_package_files )
	_append_resource_files(NO ${ARGN})
endmacro()


macro ( _append_resource_source_files )
	_append_resource_files(YES ${ARGN})
endmacro()


foreach ( _dir_name ${_dir_names} )
	set(_dir_path "${RES_DIR}/${_dir_name}")

	if ( IS_DIRECTORY "${_dir_path}" )
		set(_continue)

		# animations
		if ( NOT _continue )
			string(REGEX MATCH "^(anim|anim-[a-z]+)$" _result "${_dir_name}")
			if ( _result )
				set(_continue YES)
				file(GLOB _sources "${RES_DIR}/${_dir_name}/*.xml")
				_append_resource_source_files(${_sources})
			endif()
		endif()

		# colors
		if ( NOT _continue )
			string(REGEX MATCH "^(color|color-[a-z]+)$" _result "${_dir_name}")
			if ( _result )
				set(_continue YES)
				file(GLOB _sources "${RES_DIR}/${_dir_name}/*.xml")
				_append_resource_source_files(${_sources})
			endif()
		endif()

		# drawables
		if ( NOT _continue )
			string(REGEX MATCH "^(drawable|drawable-[a-z]+)$" _result "${_dir_name}")
			if ( _result )
				set(_continue YES)
				file(GLOB _png_bitmaps "${RES_DIR}/${_dir_name}/*.png")
				file(GLOB _jpg_bitmaps "${RES_DIR}/${_dir_name}/*.jpg")
				file(GLOB _gif_bitmaps "${RES_DIR}/${_dir_name}/*.gif")
				set(_bitmaps ${_png_bitmaps} ${_jpg_bitmaps} ${_gif_bitmaps})
				_append_resource_package_files(${_bitmaps})
				file(GLOB _sources "${RES_DIR}/${_dir_name}/*.xml")
				_append_resource_source_files(${_sources})
			endif()
		endif()

		# layouts
		if ( NOT _continue )
			string(REGEX MATCH "^(layout|layout-[a-z]+)$" _result "${_dir_name}")
			if ( _result )
				set(_continue YES)
				file(GLOB _sources "${RES_DIR}/${_dir_name}/*.xml")
				_append_resource_source_files(${_sources})
			endif()
		endif()

		# menus
		if ( NOT _continue )
			string(REGEX MATCH "^(menu|menu-[a-z]+)$" _result "${_dir_name}")
			if ( _result )
				set(_continue YES)
				file(GLOB _sources "${RES_DIR}/${_dir_name}/*.xml")
				_append_resource_source_files(${_sources})
			endif()
		endif()

		# values
		if ( NOT _continue )
			string(REGEX MATCH "^(values|values-[a-z]+)$" _result "${_dir_name}")
			if ( _result )
				set(_continue YES)
				file(GLOB _sources "${RES_DIR}/${_dir_name}/*.xml")
				_append_resource_source_files(${_sources})
			endif()
		endif()

	endif()
endforeach()


# check for mismatch
if ( NOT "${_previous_resource_sources_current_index}" EQUAL "${_previous_resource_sources_count}" )
	set(_found_resource_file_mismatched_with_previous_list YES)
endif()


# save source files target
android_debug_message("_previous_resource_sources_target_found = ${_previous_resource_sources_target_found}")
android_debug_message("_found_resource_source_file_newer_than_target_file = ${_found_resource_source_file_newer_than_target_file}")
android_debug_message("_found_resource_file_mismatched_with_previous_list = ${_found_resource_file_mismatched_with_previous_list}")

if ( NOT _previous_resource_sources_target_found OR
		_found_resource_source_file_newer_than_target_file OR
		_found_resource_file_mismatched_with_previous_list )
	message("Regenerating ${RESOURCE_SOURCE_FILES_TARGET}")
	file(WRITE "${RESOURCE_SOURCE_FILES_TARGET}" "${_resource_sources}")
endif()


# save package files target
android_debug_message("_previous_resource_package_target_found = ${_previous_resource_package_target_found}")
android_debug_message("_found_resource_package_file_newer_than_target_file = ${_found_resource_package_file_newer_than_target_file}")
android_debug_message("_found_resource_file_mismatched_with_previous_list = ${_found_resource_file_mismatched_with_previous_list}")

if ( NOT _previous_resource_package_target_found OR
		_found_resource_package_file_newer_than_target_file OR
		_found_resource_file_mismatched_with_previous_list )
	message("Regenerating ${RESOURCE_PACKAGE_FILES_TARGET}")
	android_touch_file("${RESOURCE_PACKAGE_FILES_TARGET}")
endif()
