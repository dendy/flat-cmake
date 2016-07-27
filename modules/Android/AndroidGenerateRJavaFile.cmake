#!/usr/bin/cmake -P


# Generate R java files from resource XMLs.
#
# Arguments:
#   RES_DIR                    - path to Android resources directory, usually $project/res
#   GEN_DIR                    - path where to generate R java files
#   PACKAGE_NAME_FILE          - path to file with package name, extracted from AndroidManifest.xml
#   RESOURCE_JAVA_FILES_TARGET -


include( "${Android_SCRIPT_DIR}/AndroidUtil.cmake" )


# read package name
file( READ "${PACKAGE_NAME_FILE}" _package_name )
string( REPLACE "." "/" _package_path "${_package_name}" )


# make output directory
file( MAKE_DIRECTORY "${GEN_DIR}" )


set( _aapt_verbose_flags )
if ( CMAKE_VERBOSE_MAKEFILE )
	set( _aapt_verbose_flags "-v" )
endif()


# generate R.java files
execute_process(
	COMMAND "${Android_AAPT_COMMAND}" package
		${_aapt_verbose_flags}
		-m -J "${GEN_DIR}"
		-M "${MANIFEST_FILE}"
		-S "${RES_DIR}"
		-I "${Android_PLATFORMS_DIR}/${TARGET_PLATFORM}/android.jar"
	RESULT_VARIABLE _result
	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)

if ( NOT _result EQUAL 0 )
	message( FATAL_ERROR "Error running aapt (${_result}):\n${_error};
		Command:\n${Android_AAPT_COMMAND} package ${_aapt_verbose_flags} -m -J ${GEN_DIR} -M ${MANIFEST_FILE} -S ${RES_DIR} -I ${Android_PLATFORMS_DIR}/${TARGET_PLATFORM}/android.jar" )
endif()


# locate R,java files
file( GLOB_RECURSE _r_java_files "${GEN_DIR}/${_package_path}/*.java" )


# generate target file
flat_create_file_directory( "${RESOURCE_JAVA_FILES_TARGET}" )
file( WRITE "${RESOURCE_JAVA_FILES_TARGET}" "${_r_java_files}" )
