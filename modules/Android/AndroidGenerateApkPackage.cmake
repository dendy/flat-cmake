#!/usr/bin/cmake -P


include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# verbose flags
set(_apkbuilder_verbose_flags)
if ( CMAKE_VERBOSE_MAKEFILE )
	set(_apkbuilder_verbose_flags "-v")
endif()


# debug flags
set(_apkbuilder_debug_flags)
if ( "${CMAKE_BUILD_TYPE}" STREQUAL "Debug" )
	set(_apkbuilder_debug_flags "-d")
endif()


# lib flags
string(REPLACE ":" ";" _lib_dirs "${LIB_DIRS}")

set(_apkbuilder_lib_flags)

foreach ( _lib_dir ${_lib_dirs} )
	set(_apkbuilder_lib_flags ${_apkbuilder_lib_flags} -nf "${_lib_dir}")
endforeach()


# assets
string(REPLACE ":" ";" _assets_dirs "${ASSETS_DIRS}")
set(_apkbuilder_assets_flags)
foreach ( _assets_dir ${_assets_dirs} )
	set(_apkbuilder_assets_flags ${_apkbuilder_assets_flags} -rf "${_assets_dir}")
endforeach()


# jars
set(_apkbuilder_jar_flags)

string(REPLACE ":" ";" _jar_files "${JAR_FILES}")

string(REPLACE ":" ";" _jars_target_files "${JARS_TARGET_FILES}")
foreach ( _jars_target_file ${_jars_target_files} )
	file(READ "${_jars_target_file}" _target_jar_files)
	list(APPEND _jar_files ${_target_jar_files})
endforeach()

foreach ( _jar_file ${_jar_files} )
	set(_apkbuilder_jar_flags ${_apkbuilder_jar_flags} -rj "${_jar_file}")
endforeach()


# remove previous package
file(REMOVE "${PACKAGE_FILE}")

# generate new one
execute_process(
	COMMAND ${Java_JAVA_EXECUTABLE} -cp "${Android_SDKLIB_JAR}" com.android.sdklib.build.ApkBuilderMain
		"${PACKAGE_FILE}"
		${_apkbuilder_verbose_flags}
		${_apkbuilder_debug_flags}
		-u
		-z "${RESOURCE_PACKAGE_FILE}"
		-f "${DEX_FILE}"
		${_apkbuilder_assets_flags}
		${_apkbuilder_jar_flags}
		${_apkbuilder_lib_flags}
	RESULT_VARIABLE _result
	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)


if ( NOT _result EQUAL 0 )
	message(FATAL_ERROR "Error running apkbuilder (${_result}):\n${_error}")
endif()


# save target file
android_touch_file("${PACKAGE_TARGET}")
