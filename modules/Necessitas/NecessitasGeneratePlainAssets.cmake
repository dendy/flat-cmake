#!/usr/bin/cmake -P


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


set(_need_update NO)
set(_force_update YES)


java_tools_create_file_directory("${TARGET_FILE}")


# source dirs
string(REPLACE ":" ";" _raw_src_dirs "${SRC_DIRS}")

set(_src_dirs)

foreach ( _src_dir ${_raw_src_dirs} )
	string(LENGTH "${_src_dir}" _src_dir_length)
	math(EXPR _src_dir_last_pos "${_src_dir_length} - 1")
	string(SUBSTRING "${_src_dir}" ${_src_dir_last_pos} 1 _src_dir_last)
	if ( "${_src_dir_last}" STREQUAL "/" )
		string(SUBSTRING "${_src_dir}" 0 ${_src_dir_last_pos} _src_dir)
	else()
		get_filename_component(_src_dir "${_src_dir}" DIRECTORY)
	endif()
	list(APPEND _src_dirs "${_src_dir}")
endforeach()


if ( NOT EXISTS "${SOURCE_FILES_TARGET_FILE}")
	message(FATAL_ERROR "Source files target file not exists: ${SOURCE_FILES_TARGET_FILE}")
endif()

file(READ "${SOURCE_FILES_TARGET_FILE}" _source_files)


file(GLOB_RECURSE _previous_target_files "${GEN_DIR}/*")


if ( NOT EXISTS "${TARGET_FILE}" )
	set(_need_update YES)
endif()


set(_list)

foreach ( _source_file ${_source_files} )
	java_tools_find_relative_dir(_dir _relative_path "${_source_file}" ${_src_dirs})
	if ( PLAIN )
		string(REPLACE "/" "_" _plain_relative_path "${_relative_path}")
	else()
		set(_plain_relative_path "${_relative_path}")
	endif()
	if ( NOT _plain_relative_path )
		get_filename_component(_plain_relative_path "${_source_file}" NAME)
	endif()
	if ( LIB_PREFIX )
		set(_plain_relative_path "lib${_plain_relative_path}")
	endif()
	set(_target_file "${GEN_DIR}/${_plain_relative_path}")

	list(APPEND _list "${_plain_relative_path}:${_relative_path}")
	list(REMOVE_ITEM _previous_target_files ${_target_file})

	#java_tools_debug_message("${_source_file} -> ${_target_file}")

	if ( "${_source_file}" IS_NEWER_THAN "${_target_file}" )
		set(_need_update YES)

		execute_process(
			COMMAND ${CMAKE_COMMAND} -E copy "${_source_file}" "${_target_file}"
			ERROR_VARIABLE _error
		)

		if ( NOT ${_error} EQUAL 0 )
			message(FATAL_ERROR "Failed to copy: ${_source_file} -> ${_target_file}")
		endif()
	endif()
endforeach()


if ( _previous_target_files )
	set(_need_update YES)
	file(REMOVE ${_previous_target_files})
endif()


if ( _need_update OR _force_update )
	file(WRITE "${TARGET_FILE}" "${_list}")
endif()
