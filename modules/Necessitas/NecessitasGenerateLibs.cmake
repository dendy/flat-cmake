#!/usr/bin/cmake -P


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


function(sort_libs VAR)
	find_program(_readelf_executable readelf)

	set(_lib_names)
	foreach ( _lib ${ARGN} )
		get_filename_component(_lib_name "${_lib}" NAME)
		list(APPEND _lib_names "${_lib_name}")
	endforeach()

	foreach ( _lib ${ARGN} )
		get_filename_component(_lib_name "${_lib}" NAME)
		string(REPLACE "." "_" _lib_id "${_lib_name}")

		set(_lib_deps_${_lib_id})

		execute_process(
			COMMAND "${_readelf_executable}" -d "${_lib}"
			RESULT_VARIABLE _result
			OUTPUT_VARIABLE _output
			ERROR_VARIABLE _error
		)

		if ( NOT ${_result} EQUAL 0 )
			message(FATAL_ERROR "Failed to read deps from: ${_lib}\n\n${_error}")
		endif()

		string(REPLACE "\n" ";" _output_lines "${_output}")
		foreach ( _output_line ${_output_lines} )
			if ( "${_output_line}" MATCHES "(NEEDED)" AND "${_output_line}" MATCHES "Shared library:" )
				string(FIND "${_output_line}" "[" _bracked_start REVERSE)
				string(FIND "${_output_line}" "]" _bracked_end REVERSE)
				math(EXPR _library_name_start "${_bracked_start} + 1")
				math(EXPR _library_name_length "${_bracked_end} - ${_bracked_start} - 1")
				string(SUBSTRING "${_output_line}" ${_library_name_start} ${_library_name_length} _library_name)

				list(FIND _lib_names "${_library_name}" _lib_index)
				if ( NOT ${_lib_index} EQUAL -1 )
					list(APPEND _lib_deps_${_lib_id} "${_library_name}")
				endif()
			endif()
		endforeach()
	endforeach()

	set(_sorted_lib_names)

	while ( 1 )
		list(LENGTH _lib_names _lib_count)
		if ( ${_lib_count} EQUAL 0 )
			break()
		endif()

		set(_found NO)
		foreach ( _lib_name ${_lib_names} )
			string(REPLACE "." "_" _lib_id "${_lib_name}")

			if ( NOT _lib_deps_${_lib_id} )
				set(_found YES)
				list(APPEND _sorted_lib_names "${_lib_name}")
				foreach ( _sub_lib_name ${_lib_names} )
					string(REPLACE "." "_" _sub_lib_id "${_sub_lib_name}")
					if ( _lib_deps_${_sub_lib_id} )
						list(REMOVE_ITEM _lib_deps_${_sub_lib_id} "${_lib_name}")
					endif()
				endforeach()
				list(REMOVE_ITEM _lib_names "${_lib_name}")
			endif()

			if ( _found )
				break()
			endif()
		endforeach()

		if ( NOT _found )
			set(_error_message "Circullar dependencies in libraries:\n")
			foreach ( _lib_name ${_lib_names} )
				string(REPLACE "." "_" _lib_id "${_lib_name}")
				set(_error_message "${_error_message}  ${_lib_name}:${_lib_deps_${_lib_id}}\n")
			endforeach()
			message(FATAL_ERROR "${_error_message}")
		endif()
	endwhile()

	set(_plain_lib_names)
	foreach ( _lib_name ${_sorted_lib_names} )
		string(LENGTH "${_lib_name}" _lib_name_length)
		math(EXPR _plain_lib_name_length "${_lib_name_length} - 6")
		string(SUBSTRING "${_lib_name}" 3 ${_plain_lib_name_length} _plain_lib_name)
		list(APPEND _plain_lib_names "${_plain_lib_name}")
	endforeach()

	set(${VAR} "${_plain_lib_names}" PARENT_SCOPE)
endfunction()


# assets
string(REPLACE ":" ";" _files_assets_target_files "${FILES_ASSETS_TARGET_FILES}")

set(Necessitas_BundledAssets)

foreach ( _files_assets_target_file ${_files_assets_target_files} )
	file(READ "${_files_assets_target_file}" _entries)
	foreach ( _entry ${_entries} )
		list(APPEND Necessitas_BundledAssets "\t\t<item>${_entry}</item>")
	endforeach()
endforeach()

string(REPLACE ";" "\n" Necessitas_BundledAssets "${Necessitas_BundledAssets}")


# Qt libs
string(REPLACE ":" ";" _qt_libs "${QT_LIBS}")

set(Necessitas_QtLibs)

foreach ( _qt_lib ${_qt_libs} )
	list(APPEND Necessitas_QtLibs "\t\t<item>${_qt_lib}</item>")
endforeach()

string(REPLACE ";" "\n" Necessitas_QtLibs "${Necessitas_QtLibs}")


# libs
string(REPLACE ":" ";" _libs_source_target_files "${LIBS_SOURCE_TARGET_FILES}")

set(_libs)

foreach ( _libs_source_target_file ${_libs_source_target_files} )
	file(READ "${_libs_source_target_file}" _files)

	foreach ( _file ${_files} )
		get_filename_component(_file_name "${_file}" NAME)
		string(LENGTH "${_file_name}" _file_name_length)
		math(EXPR _file_name_suffix_pos "${_file_name_length} - 3")
		string(SUBSTRING "${_file_name}" 0 3 _file_prefix)
		string(SUBSTRING "${_file_name}" ${_file_name_suffix_pos} 3 _file_suffix)
		if ( NOT "${_file_prefix}" STREQUAL "lib" OR NOT "${_file_suffix}" STREQUAL ".so" )
			message(FATAL_ERROR "Library name should be in form: lib<NAME>.so")
		endif()
		math(EXPR _plain_file_name_length "${_file_name_length} - 6")
		string(SUBSTRING "${_file_name}" 3 ${_plain_file_name_length} _plain_file_name)
		list(FIND _qt_libs "${_plain_file_name}" _qt_lib_index)
		if ( ${_qt_lib_index} EQUAL -1 )
			list(APPEND _libs "${_file}")
		endif()
	endforeach()
endforeach()

sort_libs(_sorted_libs ${_libs})

set(Necessitas_BunbledLibs)
foreach ( _sorted_lib ${_sorted_libs} )
	list(APPEND Necessitas_BundledLibs "\t\t<item>${_sorted_lib}</item>")
endforeach()

string(REPLACE ";" "\n" Necessitas_BundledLibs "${Necessitas_BundledLibs}")


# plugins
string(REPLACE ":" ";" _plugins_assets_target_files "${PLUGINS_ASSETS_TARGET_FILES}")

set(Necessitas_BunbledPlugins)

foreach ( _plugins_assets_target_file ${_plugins_assets_target_files} )
	file(READ "${_plugins_assets_target_file}" _entries)
	foreach ( _entry ${_entries} )
		list(APPEND Necessitas_BundledPlugins "\t\t<item>${_entry}</item>")
	endforeach()
endforeach()

string(REPLACE ";" "\n" Necessitas_BundledPlugins "${Necessitas_BundledPlugins}")


set(_previous_libs_string)
if ( EXISTS "${LOCATION}" )
	file(READ "${LOCATION}" _previous_libs_string)
endif()

file(READ "${Necessitas_ScriptsDir}/libs.xml.in" _libs_in_string)
string(CONFIGURE "${_libs_in_string}" _current_libs_string @ONLY)

if ( NOT "${_current_libs_string}" STREQUAL "${_previous_libs_string}" )
	message("Regenerating: ${LOCATION}")
	file(WRITE "${LOCATION}" "${_current_libs_string}")
	java_tools_touch_file("${LOCATION}")
endif()
