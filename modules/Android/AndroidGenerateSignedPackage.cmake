#!/usr/bin/cmake -P


include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# create output directory
flat_create_file_directory("${SIGNED_PACKAGE_TARGET}")


# verbose flags
set(_jarsigner_verbose_flags)
if ( CMAKE_VERBOSE_MAKEFILE )
	set(_jarsigner_verbose_flags "-verbose")
endif()


execute_process(
	COMMAND "${Android_JARSIGNER_COMMAND}"
		${_jarsigner_verbose_flags}
		-digestalg "SHA1"
		-keystore "${KEYSTORE_FILE}"
		-storepass "android"
		-keypass "android"
		-signedjar "${SIGNED_PACKAGE_FILE}"
		"${UNSIGNED_PACKAGE_FILE}"
		"androiddebugkey"
	RESULT_VARIABLE _result
	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)


# check for error
if ( NOT _result EQUAL 0 )
	message(FATAL_ERROR "\njarsigned failed (${_result}):\n${_error}")
endif()


# save target file
android_touch_file("${SIGNED_PACKAGE_TARGET}")
