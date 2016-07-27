#!/usr/bin/cmake -P


include( "${Android_SCRIPT_DIR}/AndroidUtil.cmake" )


android_debug_message( "Reconfiguring JNI project..." )
android_debug_message( "PROPERTIES = ${PROPERTIES}" )


get_filename_component( _source_dir "${SOURCE_CMAKELISTS_FILE}" PATH )
get_filename_component( _target_dir "${TARGET_CMAKECACHE_FILE}" PATH )


# make output directory
flat_create_file_directory( "${TARGET_CMAKECACHE_FILE}" )


# resolve variables
set( Android_ARCH "${ARCH}" )
set( Android_NEON "${NEON}" )
set( Android_LIBRARY_OUTPUT_PATH "${LIBRARY_OUTPUT_PATH}" )


# collect property arguments
set( _property_arguments )
string( REPLACE ":" ";" _properties "${PROPERTIES}" )
set( _awating_property_name YES )
set( _property_name )
foreach ( _property ${_properties} )
	if ( _awating_property_name )
		set( _property_name "${_property}" )
		set( _awating_property_name )
	else()
		list( APPEND _property_arguments "-D${_property_name}:STRING=${_property}" )
		set( _awating_property_name YES )
	endif()
endforeach()

if ( NOT _awating_property_name )
	message( FATAL_ERROR "Internal Error: Invalid property arguments" )
endif()


# save cache for toolchain file
set( _toolchain_cache_file "${_target_dir}/${Android_VARIABLES_FILE_NAME}" )
android_save_variables( "${_toolchain_cache_file}"
	Android_SCRIPT_DIR
	Android_SDK_ROOT
	Android_TOOLCHAIN_ROOT
	Android_ARCH
	Android_NEON
	Android_LIBRARY_OUTPUT_PATH
)


# configure JNI project
execute_process(
	COMMAND "${CMAKE_COMMAND}" -E chdir "${_target_dir}" "${CMAKE_COMMAND}"
		-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
		${_property_arguments}
		-D "CMAKE_TOOLCHAIN_FILE=${Android_SCRIPT_DIR}/AndroidToolchain.cmake"
		"${_source_dir}"
	RESULT_VARIABLE _result
#	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)

if ( NOT _result EQUAL 0 )
	file( REMOVE "${TARGET_CMAKECACHE_FILE}" )
	message( FATAL_ERROR "\n${_error}" )
endif()


# touch CMaheCache.txt and Makefile
android_touch_file( "${TARGET_CMAKECACHE_FILE}" )
android_touch_file( "${_target_dir}/Makefile" )
