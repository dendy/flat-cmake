
include(CMakeParseArguments)




#set(JavaTools_SCRIPT_DEBUG YES)




function(java_tools_debug_message MESSAGE)
	if ( JavaTools_SCRIPT_DEBUG )
		message("======== JavaTools Debug: ${MESSAGE}")
	endif()
endfunction()




function( java_tools_create_file_directory FILE )
	get_filename_component(_dir "${FILE}" PATH)

	execute_process(
		COMMAND "${CMAKE_COMMAND}" -E make_directory "${_dir}"
		RESULT_VARIABLE _result
	)

	if ( NOT _result EQUAL 0 )
		message(FATAL_ERROR "Error creating directory: ${_dir}")
	endif()
endfunction()




function( java_tools_create_symlink SOURCE DESTINATION )
	execute_process(COMMAND "${CMAKE_COMMAND}" -E create_symlink "${SOURCE}" "${DESTINATION}")
endfunction()




function(java_tools_calculate_md5sum FILEPATH MD5SUM)
	execute_process(
		COMMAND "${CMAKE_COMMAND}" -E md5sum "${FILEPATH}"
		RESULT_VARIABLE _result
		OUTPUT_VARIABLE _output
		ERROR_VARIABLE _error
		ERROR_QUIET
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)

	if ( ${_result} EQUAL 0 )
		set(${MD5SUM} "${_output}" PARENT_SCOPE)
	else()
		set(${MD5SUM} "" PARENT_SCOPE)
	endif()
endfunction()




function(java_tools_touch_file FILEPATH)
	# FIXME: CMake -E touch does not set time stamp correctly in CMake 2.8.4.
	#        If file already exists it uses fopen() to change modification time.
	#        But that actually does not work, because fopen() truncates current time to seconds,
	#        while touch should preserve precise time, like utime() does:
	#            fopen(): 15:04:13.000000000
	#            utime(): 15:04:13.528446529
	set(JavaTools_USE_CMAKE_TOUCH_WORKAROUND YES)
	if ( UNIX AND JavaTools_USE_CMAKE_TOUCH_WORKAROUND )
		execute_process(COMMAND "touch" "${FILEPATH}")
	else()
		execute_process(COMMAND "${CMAKE_COMMAND}" -E touch "${FILEPATH}")
	endif()
endfunction()




function(java_tools_find_relative_dir DIR_VARIABLE RELATIVE_PATH_VARIABLE SOURCE)
	set(_dir)
	set(_relative_path)
	set(_relative_path_length 99999)

	foreach ( _new_dir ${ARGN} )
		file(RELATIVE_PATH _new_relative_path "${_new_dir}" "${SOURCE}")
		string(REGEX MATCH "^../" _found_cd_up "${_new_relative_path}")
		if ( NOT _found_cd_up )
			string(LENGTH "${_new_relative_path}" _new_relative_path_length)
			if ( ${_new_relative_path_length} LESS ${_relative_path_length} )
				set(_dir "${_new_dir}")
				set(_relative_path "${_new_relative_path}")
				set(_relative_path_length ${_new_relative_path_length})
			endif()
		endif()
	endforeach()

	set(${DIR_VARIABLE} "${_dir}" PARENT_SCOPE)
	set(${RELATIVE_PATH_VARIABLE} "${_relative_path}" PARENT_SCOPE)
endfunction()




function(java_tools_generate_source_files_target TARGET_FILE)
	cmake_parse_arguments(_jt "" "" "SOURCE_DIRS;SOURCE_FILES;EXCLUDES;FILTERS" ${ARGN})

	java_tools_create_file_directory("${TARGET_FILE}")

	# load previous target file
	set(_previous_target_file_found NO)
	set(_previous_sources)
	if ( EXISTS "${TARGET_FILE}" )
		set(_previous_target_file_found YES)
		file(READ "${TARGET_FILE}" _previous_sources)
	endif()

	# result
	set(_found_source_file_newer_than_target_file NO)
	set(_found_source_file_mismatched_with_previous_list NO)

	# previous list iterator
	list(LENGTH _previous_sources _previous_sources_count)
	set(_previous_sources_current_index 0)

	# excludes
	set(_wild_excludes)
	set(_file_excludes)
	foreach ( _raw_exclude ${_jt_EXCLUDES} )
		get_filename_component(_exclude "${_raw_exclude}" ABSOLUTE)
		if ( NOT "${_exclude}" STREQUAL "${_raw_exclude}" )
			message(FATAL_ERROR "Excludes should be absolute: ${_raw_exclude} -> ${_exclude}")
		endif()

		string(LENGTH "${_exclude}" _exclude_length)
		math(EXPR _exclude_last_pos "${_exclude_length} - 1")
		string(SUBSTRING "${_exclude}" ${_exclude_last_pos} 1 _exclude_last)

		if ( "${_exclude_last}" STREQUAL "*" )
			string(SUBSTRING "${_exclude}" 0 ${_exclude_last_pos} _wild_exclude)
			list(APPEND _wild_excludes "${_wild_exclude}")
		else()
			list(APPEND _file_excludes "${_exclude}")
		endif()
	endforeach()

	# all sources
	set(_all_source_files ${_jt_SOURCE_FILES})
	foreach ( _src_dir ${_jt_SOURCE_DIRS} )
		string(LENGTH "${_src_dir}" _src_dir_length)
		math(EXPR _src_dir_last_pos "${_src_dir_length} - 1")
		string(SUBSTRING "${_src_dir}" ${_src_dir_last_pos} 1 _src_dir_last)
		if ( "${_src_dir_last}" STREQUAL "/" )
			string(SUBSTRING "${_src_dir}" 0 ${_src_dir_last_pos} _src_dir)
		endif()
		set(_files)
		if ( NOT _jt_FILTERS )
			file(GLOB_RECURSE _files "${_src_dir}/*")
		else()
			foreach ( _filter ${_jt_FILTERS} )
				file(GLOB_RECURSE _filtered_files "${_src_dir}/${_filter}")
				list(APPEND _files ${_filtered_files})
			endforeach()
		endif()
		list(APPEND _all_source_files ${_files})
	endforeach()

	# collect source files
	set(_source_files)

	foreach ( _source_file ${_all_source_files} )
		set(_skip NO)

		if ( NOT _skip )
			foreach ( _file_exclude ${_file_excludes} )
				if ( "${_source_file}" STREQUAL "${_file_exclude}" )
					set(_skip YES)
					break()
				endif()
			endforeach()
		endif()

		if ( NOT _skip )
			string(LENGTH "${_source_file}" _source_file_length)
			foreach ( _wild_exclude ${_wild_excludes} )
				string(LENGTH "${_wild_exclude}" _wild_exclude_length)
				if ( NOT ${_source_file_length} LESS ${_wild_exclude_length} )
					string(SUBSTRING "${_source_file}" 0 ${_wild_exclude_length} _source_file_wild_exclude)
					if ( "${_source_file_wild_exclude}" STREQUAL "${_wild_exclude}" )
						set(_skip YES)
						break()
					endif()
				endif()
			endforeach()
		endif()

		if ( NOT _skip )
			list(APPEND _source_files "${_source_file}")

			if ( NOT _found_source_file_newer_than_target_file )
				if ( "${_source_file}" IS_NEWER_THAN "${TARGET_FILE}" )
					set(_found_source_file_newer_than_target_file YES)
				endif()
			endif()

			if ( NOT _found_source_file_mismatched_with_previous_list )
				if ( NOT ${_previous_sources_current_index} LESS ${_previous_sources_count} )
					set(_found_source_file_mismatched_with_previous_list YES)
				endif()
			endif()

			if ( NOT _found_source_file_mismatched_with_previous_list )
				list(GET _previous_sources ${_previous_sources_current_index} _previous_source_file)
				if ( NOT "${_source_file}" STREQUAL "${_previous_source_file}" )
					set(_found_source_file_mismatched_with_previous_list YES)
				endif()
			endif()

			if ( NOT _found_source_file_mismatched_with_previous_list )
				math(EXPR _previous_sources_current_index "${_previous_sources_current_index} + 1")
			endif()
		endif()
	endforeach()

	# check for mismatch
	if ( NOT ${_previous_sources_current_index} EQUAL ${_previous_sources_count} )
		set(_found_source_file_mismatched_with_previous_list YES)
	endif()

	# save target file
	if ( NOT _previous_target_file_found OR
			_found_source_file_newer_than_target_file OR
			_found_source_file_mismatched_with_previous_list )
		message("Regenerating: ${TARGET_FILE}")
		file(WRITE "${TARGET_FILE}" "${_source_files}")
	endif()
endfunction()
