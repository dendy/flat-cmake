#!/usr/bin/cmake -P

set(_adb "${Android_PLATFORM_TOOLS_DIR}/adb")


set(_target_dir)

if ( MANIFEST_FILE )
	execute_process(
		COMMAND "${Java_JAVA_EXECUTABLE}" -cp "${Android_SAXON_PACKAGE}" net.sf.saxon.Query
			"-s:${MANIFEST_FILE}"
			"-qs:data(/manifest/@package)"
			"!omit-xml-declaration=yes"
		RESULT_VARIABLE _result
		OUTPUT_VARIABLE _output
		ERROR_VARIABLE _error
	)

	if ( NOT ${_result} EQUAL 0 )
		message(FATAL_ERROR "Failed to get package name.\n${_error}")
	endif()

	set(_target_dir "/data/data/${_output}")
else()
	if ( "${TARGET_DIR}" STREQUAL "" )
		message(FATAL_ERROR "TARGET_DIR is empty")
	endif()

	set(_target_dir "${TARGET_DIR}")

	# clear target dir first
	execute_process(COMMAND "${_adb}" shell rm -r "${_target_dir}/*")
endif()


# copy runtime
execute_process(COMMAND "${_adb}" push "${Android_TOOLCHAIN_ROOT}/arm-linux-androideabi/lib/libgnustl_shared.so" "${_target_dir}/lib/libgnustl_shared.so"
	RESULT_VARIABLE _result
	ERROR_VARIABLE _error
)

if ( NOT ${_result} EQUAL 0 )
	message(FATAL_ERROR "Failed to copy libgnustl_shared.so\n${_error}")
endif()


# copy files
set(_dirs "lib" "plugins" "qml")

set(_dir_filters_lib "*.so")


foreach ( _dir ${_dirs} )
	set(_filters "${_dir_filters_${_dir}}")
	if ( NOT _filters )
		set(_filters "*")
	endif()
	file(GLOB_RECURSE _dir_files_${_dir} RELATIVE "${Qt5_INSTALL_PREFIX}/${_dir}" "${Qt5_INSTALL_PREFIX}/${_dir}/${_filters}")
endforeach()

set(_count 0)
foreach ( _dir ${_dirs} )
	list(LENGTH _dir_files_${_dir} _c)
	math(EXPR _count "${_count} + ${_c}")
endforeach()
string(LENGTH "${_count}" _count_string_length)


set(_index 0)
foreach ( _dir ${_dirs} )
	foreach ( _file ${_dir_files_${_dir}} )
		math(EXPR _index "${_index} + 1")

		set(_index_string "${_index}")
		while ( 1 )
			string(LENGTH "${_index_string}" _index_string_length)
			if ( ${_index_string_length} EQUAL ${_count_string_length} )
				break()
			endif()
			set(_index_string "0${_index_string}")
		endwhile()

		get_filename_component(_relative_dir "${_file}" DIRECTORY)
		get_filename_component(_suffix "${_file}" EXT)

		message("[${_index_string}/${_count}] Copying: ${_dir}/${_file}")

		execute_process(COMMAND "${_adb}" shell mkdir -p "${_target_dir}/${_dir}/${_relative_dir}")

		execute_process(COMMAND "${_adb}" push "${Qt5_INSTALL_PREFIX}/${_dir}/${_file}" "${_target_dir}/${_dir}/${_file}"
			RESULT_VARIABLE _result
			ERROR_VARIABLE _error
		)

		if ( NOT ${_result} EQUAL 0 )
			message(FATAL_ERROR "Failed to copy: ${Qt5_INSTALL_PREFIX}/${_dir}/${_file}\n\n${_error}")
		endif()
	endforeach()
endforeach()
