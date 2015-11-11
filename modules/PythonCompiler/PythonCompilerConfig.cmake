
find_package(PackageHandleStandardArgs)

set(Python_ADDITIONAL_VERSIONS 3.5-32)
find_package(PythonInterp 3 REQUIRED)

if ( "${PYTHON_VERSION_STRING}" VERSION_LESS "3.5" )
	message(FATAL_ERROR "Incompatible Python version: ${PYTHON_VERSION_STRING}. At least 3.5 is required.")
endif()


set(PythonCompiler_CompileScript "${CMAKE_CURRENT_LIST_DIR}/python-compiler.py")


function(python_compiler_add_files TARGET)
	set(_output_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}")

	set(_files)

	foreach ( _file ${ARGN} )
		if ( IS_ABSOLUTE "${_file}" )
			set(_abs_path "${_file}")
		else()
			set(_abs_path "${CMAKE_CURRENT_SOURCE_DIR}/${_file}")
		endif()

		get_filename_component(_file_dir "${_abs_path}" DIRECTORY)
		get_filename_component(_file_name "${_file}" NAME_WE)
		file(RELATIVE_PATH _rel_dir "${CMAKE_CURRENT_SOURCE_DIR}" "${_file_dir}")
		string(LENGTH "${_rel_dir}" _rel_dir_length)
		if ( ${_rel_dir_length} )
			string(REPLACE ".." "__" _normalized_rel_dir "${_rel_dir}")
		endif()

		set(_target_file "${_output_dir}/${_normalized_rel_dir}/${_file_name}.pyc")

		add_custom_command(
			OUTPUT "${_target_file}"
			COMMAND "${PYTHON_EXECUTABLE}" "${PythonCompiler_CompileScript}" -o "${_target_file}" "${_abs_path}"
			DEPENDS "${_abs_path}"
		)

		list(APPEND _files "${_target_file}")
	endforeach()

	add_custom_target(${TARGET} DEPENDS ${_files})
endfunction()


find_package_handle_standard_args(PythonCompiler REQUIRED_VARS PYTHON_EXECUTABLE)


set(PythonCompiler_FOUND YES)
