#!/usr/bin/cmake -P


include( "${Android_SCRIPT_DIR}/AndroidUtil.cmake" )


# make output directories
flat_create_file_directory( "${RESOURCE_PACKAGE_FILE}" )
flat_create_file_directory( "${RESOURCE_PACKAGE_TARGET}" )


set( _aapt_verbose_flags )
if ( CMAKE_VERBOSE_MAKEFILE )
	set( _aapt_verbose_flags "-v" )
endif()


set( _aapt_debug_flags )
if ( "${CMAKE_BUILD_TYPE}" STREQUAL "Debug" )
	set( _aapt_debug_flags "--debug-mode" )
endif()


set( _aapt_assets_flags )
if ( EXISTS "${ASSETS_DIR}" )
	set( _aapt_assets_dir -A "${ASSETS_DIR}" )
endif()


# generate resource package
android_debug_message( "Touching ${RESOURCE_PACKAGE_FILE}" )
execute_process(
	COMMAND "${Android_AAPT_COMMAND}" package
		${_aapt_verbose_flags}
		${_aapt_debug_flags}
		-f
		-M "${MANIFEST_FILE}"
		-S "${RES_DIR}"
		${_aapt_assets_flags}
		-I "${Android_PLATFORMS_DIR}/${TARGET_PLATFORM}/android.jar"
		-F "${RESOURCE_PACKAGE_FILE}"
	RESULT_VARIABLE _result
	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)

if ( NOT _result EQUAL 0 )
	message( FATAL_ERROR "\n${_error}" )
endif()


# save target file
android_debug_message( "Touching ${RESOURCE_PACKAGE_TARGET}" )
android_touch_file( "${RESOURCE_PACKAGE_TARGET}" )
