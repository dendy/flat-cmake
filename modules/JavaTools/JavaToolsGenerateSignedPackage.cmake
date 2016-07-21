#!/usr/bin/cmake -P


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


# create output directory
java_tools_create_file_directory("${SIGNED_PACKAGE_TARGET}")


# verbose flags
set( _jarsigner_verbose_flags )
if ( CMAKE_VERBOSE_MAKEFILE )
	set(_jarsigner_verbose_flags "-verbose")
endif()


execute_process(
	COMMAND "${JavaTools_JARSIGNER_COMMAND}"
		${_jarsigner_verbose_flags}
		-keystore "${KEYSTORE_FILE}"
		-storepass "${STOREPASS}"
		-keypass "${KEYPASS}"
		"${PACKAGE_FILE}"
		"${ALIAS}"
	RESULT_VARIABLE _result
	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)


# check for error
if ( NOT _result EQUAL 0 )
	message(FATAL_ERROR "jarsigned failed (${_result}): \n${_error}")
endif()


# save target file
java_tools_touch_file("${SIGNED_PACKAGE_TARGET}")
