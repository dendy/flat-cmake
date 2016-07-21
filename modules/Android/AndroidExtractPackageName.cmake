#!/usr/bin/cmake -P

# Extracts package name from AndroidManifest.xml into file.
#
# Arguments:
#   MANIFEST_FILE     - path to AndroidManifest.xml
#   PACKAGE_NAME_FILE - path to file name, where package name will be stored


set(UseSaxon YES)


include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# make output directory
android_create_file_directory("${PACKAGE_NAME_FILE}")


if ( UseSaxon )
	execute_process(
		COMMAND "${Java_JAVA_EXECUTABLE}" -cp "${Android_SAXON_PACKAGE}" net.sf.saxon.Query
			"-s:${MANIFEST_FILE}"
			"-qs:data(/manifest/@package)"
			"!omit-xml-declaration=yes"
		RESULT_VARIABLE _result
		OUTPUT_VARIABLE _output
		ERROR_VARIABLE _error
	)
else()
	execute_process(
		COMMAND "/home/dendy/projects/builds/extract-android-package-name/extract-android-package-name"
			"${MANIFEST_FILE}"
		RESULT_VARIABLE _result
		OUTPUT_VARIABLE _output
		ERROR_VARIABLE _error
	)
endif()


if ( NOT ${_result} EQUAL 0 )
	message(FATAL_ERROR "Failed to get package name.\n${_error}")
endif()


file(WRITE "${PACKAGE_NAME_FILE}" "${_output}")
