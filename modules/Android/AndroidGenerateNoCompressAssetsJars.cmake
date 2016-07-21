
string(REPLACE ":" ";" _assets_dirs "${ASSETS_DIRS}")


set(_jar_index 0)
set(_jar_files)

foreach ( _assets_dir ${_assets_dirs} )
	set(_jar_file "${OUTPUT_DIR}/no-compress-assets-${_jar_index}.jar")

	execute_process(
		COMMAND "${JavaTools_JAR_EXECUTABLE}"
			c0f "${_jar_file}" -C "${_assets_dir}" "assets"
		RESULT_VARIABLE _result
		OUTPUT_VARIABLE _output
		ERROR_VARIABLE _error
	)

	if ( NOT ${_result} EQUAL 0 )
		message(FATAL_ERROR "Failed to create uncompressed JAR from assets.\nJAR: ${_jar_file}\nAssets dir: ${_assets_dir}\n\n${_output}\n\n${_error}")
	endif()

	list(APPEND _jar_files "${_jar_file}")

	math(EXPR _jar_index "${_jar_index} + 1")
endforeach()


file(WRITE "${TARGET_FILE}" "${_jar_files}")
