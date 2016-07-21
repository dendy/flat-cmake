#!/usr/bin/cmake


include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# make output directory
android_create_file_directory("${DEX_FILE}")


set(_dx_debug_flags)
if ( "${CMAKE_BUILD_TYPE}" STREQUAL "Debug" )
	set(_dx_debug_flags "--debug")
endif()


set(_dx_verbose_flags)
if ( CMAKE_VERBOSE_MAKEFILE )
	set(_dc_verbose_flags "--verbose")
endif()


# jars
string(REPLACE ":" ";" _jar_files "${JAR_FILES}")
set(_input ${CLASSES_DIR} ${_jar_files})
string(REPLACE ";" "\n" _input "${_input}")
file(WRITE "${DEX_FILE}.input" "${_input}\n")

execute_process(
	COMMAND "${Android_DX_COMMAND}" --dex
		${_dx_debug_flags}
		${_dx_verbose_flags}
		"--input-list=${DEX_FILE}.input"
		"--output=${DEX_FILE}"
	RESULT_VARIABLE _result
	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)

file(REMOVE "${DEX_FILE}.input")

if ( NOT _result EQUAL 0 )
	message(FATAL_ERROR "Error running dx (${_result}):\n${_error}")
endif()
