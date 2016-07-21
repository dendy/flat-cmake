#!/usr/bin/cmake -P


# Generate IDL Java files from aidl-files.
#
# Arguments:


include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# read package name
file(READ "${PACKAGE_NAME_FILE}" _package_name)
string(REPLACE "." "/" _package_path "${_package_name}")


set(_include_flags)
string(REPLACE ":" ";" _include_dirs "${INCLUDE_DIRS}")
foreach ( _include_dir ${_include_dirs} )
	list(APPEND _include_flags "-I${_include_dir}")
endforeach()

string(REPLACE ":" ";" _src_dirs "${SRC_DIRS}")


file(READ "${IDL_SOURCE_FILES_TARGET}" _idl_source_files)


# make output directory
file(MAKE_DIRECTORY "${GEN_DIR}")


set(_idl_java_files)


function(find_closest_relative_path VAR FILE)
	set(path)
	foreach ( dir ${ARGN} )
		file(RELATIVE_PATH current_path "${dir}" "${FILE}")
		string(LENGTH "${path}" path_len)
		string(LENGTH "${current_path}" current_len)
		if ( ${path_len} EQUAL 0 OR ${current_len} LESS ${path_len} )
			set(path "${current_path}")
		endif()
	endforeach()

	set(${VAR} "${path}" PARENT_SCOPE)
endfunction()


foreach ( _idl_source_file ${_idl_source_files} )
	find_closest_relative_path(_relative_idl_source_file "${_idl_source_file}" ${_src_dirs})
	get_filename_component(_filepath "${_relative_idl_source_file}" PATH)
	get_filename_component(_filename_we "${_idl_source_file}" NAME_WE)
	set(_idl_java_file "${GEN_DIR}/${_filepath}/${_filename_we}.java")

	list(APPEND _idl_java_files "${_idl_java_file}")

	if ( "${_idl_source_file}" IS_NEWER_THAN "${_idl_java_file}" )
		message("Compiling: ${_idl_source_file} -> ${_idl_java_file}")

		execute_process(
			COMMAND "${Android_AIDL_COMMAND}"
				"-p${Android_PLATFORMS_DIR}/${TARGET_PLATFORM}/framework.aidl"
				${_include_flags}
				"${_idl_source_file}"
				"${_idl_java_file}"
			RESULT_VARIABLE _result
			OUTPUT_VARIABLE _output
			ERROR_VARIABLE _error
		)

		if ( NOT _result EQUAL 0 )
			message(FATAL_ERROR "\nError processing aidl on file: ${_idl_source_file}\n${_error}")
		endif()
	endif()
endforeach()


# generate target file
android_create_file_directory("${IDL_JAVA_FILES_TARGET}")
file(WRITE "${IDL_JAVA_FILES_TARGET}" "${_idl_java_files}")
