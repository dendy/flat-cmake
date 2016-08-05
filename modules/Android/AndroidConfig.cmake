
set( Android_FOUND NO )


find_package(Flat REQUIRED)
find_package(JavaTools REQUIRED)


include(CMakeParseArguments)


if ( NOT Android_TOOLCHAIN_ROOT )
	set(_android_toolchain_root "$ENV{ANDROID_TOOLCHAIN_ROOT}")
	if ( NOT _android_toolchain_root )
		message(FATAL_ERROR "Standalone Android toolchain not found. Specify it with either Android_TOOLCHAIN_ROOT CMake variable or ANDROID_TOOLCHAIN_ROOT environment variable.")
	endif()
	set(Android_TOOLCHAIN_ROOT "${_android_toolchain_root}" CACHE PATH "" FORCE)
endif()
mark_as_advanced(Android_TOOLCHAIN_ROOT)


# keytool
find_program(Android_KEYTOOL_COMMAND keytool)
if ( NOT Android_KEYTOOL_COMMAND )
	mark_as_advanced(CLEAR Android_KEYTOOL_COMMAND)
	message(FATAL_ERROR "Cannot find keytool")
endif()
mark_as_advanced(FORCE Android_KEYTOOL_COMMAND)


# SDK
if ( NOT Android_SDK_ROOT )
	set(_android_sdk_root "$ENV{ANDROID_SDK_ROOT}")
	if ( NOT _android_sdk_root )
		message(FATAL_ERROR "Android_SDK_ROOT not specified")
	endif()
	set(Android_SDK_ROOT "${_android_sdk_root}" CACHE PATH "" FORCE)
endif()
mark_as_advanced(FORCE Android_SDK_ROOT)


# lookup 'android' tool
find_program(Android_ANDROID_COMMAND "android"
	HINTS "${Android_SDK_ROOT}/tools"
	NO_SYSTEM_ENVIRONMENT_PATH
	NO_CMAKE_SYSTEM_PATH
)


# test 'android' tool
execute_process(
	COMMAND "${Android_ANDROID_COMMAND}" "list"
	RESULT_VARIABLE _android_android_list_result
	OUTPUT_VARIABLE _android_android_list_output
	ERROR_VARIABLE _android_android_list_error
)

if ( NOT _android_android_list_result EQUAL 0 )
	set(Android_ANDROID_COMMAND "" CACHE FILEPATH "" FORCE)
	mark_as_advanced(CLEAR Android_SDK_ROOT)
	message(FATAL_ERROR "Android SDK directory not found. Specify it using the either Android_SDK_ROOT cmake variable or ANDROID_SDK_ROOT environment variable.")
endif()


# paths
set(Android_PLATFORMS_DIR "${Android_SDK_ROOT}/platforms" CACHE PATH "" FORCE)
set(Android_TOOLS_DIR "${Android_SDK_ROOT}/tools" CACHE PATH "" FORCE)
set(Android_PLATFORM_TOOLS_DIR "${Android_SDK_ROOT}/platform-tools" CACHE PATH "" FORCE)
# FIXME: Resolve build tools dir properly.
set(Android_BUILD_TOOLS_DIR "${Android_SDK_ROOT}/build-tools/23.0.3" CACHE PATH "" FORCE)
mark_as_advanced(Android_PLATFORMS_DIR Android_TOOLS_DIR Android_PLATFORM_TOOLS_DIR Android_BUILD_TOOLS_DIR)


# tools
set(Android_SDKLIB_JAR "${Android_TOOLS_DIR}/lib/sdklib.jar" CACHE FILEPATH "" FORCE)
mark_as_advanced(Android_SDKLIB_JAR)


# platform tools
set(Android_ADB_COMMAND "${Android_PLATFORM_TOOLS_DIR}/adb" CACHE FILEPATH "" FORCE)
set(Android_AAPT_COMMAND "${Android_BUILD_TOOLS_DIR}/aapt" CACHE FILEPATH "" FORCE)
set(Android_AIDL_COMMAND "${Android_BUILD_TOOLS_DIR}/aidl" CACHE FILEPATH "" FORCE)
set(Android_DX_COMMAND "${Android_BUILD_TOOLS_DIR}/dx" CACHE FILEPATH "" FORCE)
mark_as_advanced(Android_ADB_COMMAND Android_AAPT_COMMAND Android_AIDL_COMMAND Android_DX_COMMAND)


# helper variables
set(Android_VARIABLES_FILE_NAME "android-variables" CACHE STRING "" FORCE)
set(Android_JNI_LIBRARY_OUTPUT_DIRECTORY_NAME "jni-libs" CACHE STRING "" FORCE)
mark_as_advanced(Android_VARIABLES_FILE_NAME Android_JNI_LIBRARY_OUTPUT_DIRECTORY_NAME)


# helper scripts
function(__android_setup)
	get_filename_component(dir "${CMAKE_CURRENT_LIST_FILE}" PATH)

	set(Android_SCRIPT_DIR "${dir}" PARENT_SCOPE)
	set(Android_ParseManifestScript "${dir}/parse-manifest.py" PARENT_SCOPE)
	set(Android_GENERATE_RESOURCE_SOURCE_FILES_TARGET_SCRIPT "${dir}/AndroidGenerateResourceSourceFilesTarget.cmake" PARENT_SCOPE)
	set(Android_GENERATE_IDL_SOURCE_FILES_TARGET_SCRIPT "${dir}/AndroidGenerateIdlSourceFilesTarget.cmake" PARENT_SCOPE)
	set(Android_GENERATE_JNI_LIBRARIES_TARGET_SCRIPT "${dir}/AndroidGenerateJniLibrariesTarget.cmake" PARENT_SCOPE)
	set(Android_GENERATE_R_JAVA_FILE_SCRIPT "${dir}/AndroidGenerateRJavaFile.cmake" PARENT_SCOPE)
	set(Android_GENERATE_IDL_JAVA_FILES_SCRIPT "${dir}/AndroidGenerateIdlJavaFiles.cmake" PARENT_SCOPE)
	set(Android_GENERATE_RESOURCE_PACKAGE_SCRIPT "${dir}/AndroidGenerateResourcePackage.cmake" PARENT_SCOPE)
	set(Android_GENERATE_DEX_FILES_SCRIPT "${dir}/AndroidGenerateDexFiles.cmake" PARENT_SCOPE)
	set(Android_GENERATE_APK_PACKAGE_SCRIPT "${dir}/AndroidGenerateApkPackage.cmake" PARENT_SCOPE)
	set(Android_GENERATE_SIGNED_PACKAGE_SCRIPT "${dir}/AndroidGenerateSignedPackage.cmake" PARENT_SCOPE)
	set(Android_GENERATE_ASSETS_SOURCE_FILES_TARGET "${dir}/AndroidGenerateAssetsSourceFilesTarget.cmake" PARENT_SCOPE)
	set(Android_GENERATE_NO_COMPRESS_ASSETS_JARS_SCRIPT "${dir}/AndroidGenerateNoCompressAssetsJars.cmake" PARENT_SCOPE)
	set(Android_CONFIGURE_JNI_PROJECT_SCRIPT "${dir}/AndroidConfigureJniProject.cmake" PARENT_SCOPE)
	set(Android_PUSH_FILES_SCRIPT "${dir}/AndroidPushFiles.cmake" PARENT_SCOPE)
	set(Android_INSTALL_FILES_SCRIPT "${dir}/AndroidInstallFiles.cmake" PARENT_SCOPE)
	set(Android_TOOLCHAIN_FILE "${dir}/AndroidToolchain.cmake" PARENT_SCOPE)
endfunction()

__android_setup()


# utils
include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# locate target platforms
file(GLOB _android_platforms_entries RELATIVE "${Android_PLATFORMS_DIR}" "${Android_PLATFORMS_DIR}/*")
set(_android_target_platforms)
foreach ( _platforms_entry ${_android_platforms_entries} )
	if ( EXISTS "${Android_PLATFORMS_DIR}/${_platforms_entry}/android.jar" )
		list(APPEND _android_target_platforms "${_platforms_entry}")
	endif()
endforeach()
set(Android_TARGET_PLATFORMS ${_android_target_platforms} CACHE INTERNAL "" FORCE)
mark_as_advanced(Android_TARGET_PLATFORMS)


message(STATUS "Found Android SDK in: ${Android_SDK_ROOT}")
message(STATUS "Available target platforms: ${Android_TARGET_PLATFORMS}")

set(Android_FOUND YES)




# Usage:
#   android_add_package( TARGET [options] )
#
# Create target named TARGET to build Android package from ROOT_DIR source tree.
#
# Possible options:
#   ROOT_DIR <dir>             - Package source root dir. Default: CMAKE_CURRENT_SOURCE_DIR.
#   MANIFEST_FILE <file>       - Path to AndroidManifest.xml. Default: ${ROOT_DIR}/AndroidManifest.xml
#   RES_DIR <dir>              - Path to 'res'. Default: ${ROOT_DIR}/res
#   JAR_FILES <files>          - Additional JAR files to link.
#   TARGET_PLATFORM <platform> - Build using specified Android platform, e.g. android-9.
#                                To see all available platforms run 'android list target'.
#   KEYSTORE_FILE <file>       - Use the given file to sign the package. If not specified,
#                                package will be signed with debug keystore file.
#   CLASS_PATHS                - List of additional class path for Java.
#   APK_FILE_NAME <name>       - Name of apk-file to generate. If absent, TARGET will be used.
#   EXCLUDE_FROM_ALL           - If set, generated target will be skipped from 'all' target.

function(android_add_package TARGET)
	cmake_parse_arguments(_android ""
		"ROOT_DIR;MANIFEST_FILE;RES_DIR;TARGET_PLATFORM;KEYSTORE_FILE;APK_FILE_NAME;EXCLUDE_FROM_ALL"
		"SRC_DIRS;ASSETS_DIRS;NO_COMPRESS_ASSETS_DIRS;LIB_DIRS;LIB_TARGET_FILES;CLASS_PATHS;JAR_FILES;DEPENDS;RESOURCE_DEPENDS" ${ARGN}
	)

	if ( NOT _android_ROOT_DIR )
		set(_android_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
	endif()

	if ( NOT _android_TARGET_PLATFORM )
		message(FATAL_ERROR "No Android target platform specified. Use TARGET_PLATFORM token to specify target. Available target platforms: ${Android_TARGET_PLATFORMS}")
	endif()

	list(FIND Android_TARGET_PLATFORMS "${_android_TARGET_PLATFORM}" _target_platform_index)
	if ( _target_platform_index EQUAL -1 )
		message(FATAL_ERROR "Invalid target platform: ${_android_TARGET_PLATFORM}. Available target platforms: ${Android_TARGET_PLATFORMS}")
	endif()

	# resolve apk file name
	if ( NOT _android_APK_FILE_NAME )
		set(_apk_file_name "${TARGET}")
	else()
		set(_apk_file_name "${_android_APK_FILE_NAME}")
	endif()

	# root dir
	get_filename_component(_root_dir "${_android_ROOT_DIR}" ABSOLUTE)

	# manifest file
	if ( _android_MANIFEST_FILE )
		get_filename_component(_manifest_file "${_android_MANIFEST_FILE}" ABSOLUTE)
	else()
		set(_manifest_file "${_root_dir}/AndroidManifest.xml")
	endif()

	# class paths
	set(_class_paths)
	foreach ( _class_path ${_android_CLASS_PATHS} )
		get_filename_component(_path "${_class_path}" ABSOLUTE)
		list(APPEND _class_paths "${_path}")
	endforeach()
	string(REPLACE ";" ":" _class_paths "${_class_paths}")

	# source dirs
	set(_src_dirs "${_root_dir}/java")
	if ( _android_SRC_DIRS )
		list(APPEND _src_dirs ${_android_SRC_DIRS})
	endif()
	string(REPLACE ";" ":" _src_dirs "${_src_dirs}")

	if ( _android_RES_DIR )
		set(_res_dir "${_android_RES_DIR}")
	else()
		set(_res_dir "${_root_dir}/res")
	endif()

	set(_assets_dir "${_root_dir}/assets")

	# assets
	set(_assets_dirs)
	foreach ( _a_dir ${_android_ASSETS_DIRS} )
		get_filename_component(_path "${_a_dir}" ABSOLUTE)
		list(APPEND _assets_dirs "${_path}")
	endforeach()
	string(REPLACE ";" ":" _assets_dirs "${_assets_dirs}")

	# no compress assets
	set(_no_compress_assets_dirs)
	foreach ( _dir ${_android_NO_COMPRESS_ASSETS_DIRS} )
		get_filename_component(_path "${_dir}" ABSOLUTE)
		list(APPEND _no_compress_assets_dirs "${_path}")
	endforeach()
	string(REPLACE ";" ":" _no_compress_assets_dirs "${_no_compress_assets_dirs}")

	# libs
	set(_lib_dirs)
	foreach ( _lib_dir ${_android_LIB_DIRS} )
		get_filename_component(_path "${_lib_dir}" ABSOLUTE)
		list(APPEND _lib_dirs "${_path}")
	endforeach()
	string(REPLACE ";" ":" _lib_dirs "${_lib_dirs}")

	# jars
	set(_jar_files)
	foreach ( _jar_file ${_android_JAR_FILES} )
		get_filename_component(_path "${_jar_file}" ABSOLUTE)
		list(APPEND _jar_files "${_path}")
	endforeach()
	string(REPLACE ";" ":" _jar_files "${_jar_files}")

	# destination dirs
	set(_build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_AndroidFiles")
	set(_gen_dir "${_build_dir}/gen")
	set(_classes_dir "${_build_dir}/classes")
	set(_output_dir "${_build_dir}/output")
	set(_target_dir "${_build_dir}/targets")
	set(_keystore_dir "${_build_dir}/keystore")
	set(_jni_libs_dir "${_build_dir}/libs")
	set(_apk_dir "${_build_dir}")

	# target files
	set(parse_manifest_target "${_target_dir}/parse-manifest")
	set(_resource_source_files_target "${_target_dir}/resource-source-files.target")
	set(_resource_package_files_target "${_target_dir}/resource-package-files.target")
	set(_idl_source_files_target "${_target_dir}/idl-source-files.target")
	set(_resource_java_files_target "${_target_dir}/resource-java-files.target")
	set(_idl_java_files_target "${_target_dir}/idl-java-files.target")
	set(_java_class_files_target "${_target_dir}/java-class-files.target")
	set(_resource_package_target "${_target_dir}/resource-package.target")
	set(_jni_libraries_target "${_target_dir}/jni-libraries.target")
	set(_no_compress_assets_source_files_target "${_target_dir}/no-compress-assets-source-files.target")
	set(_no_compress_assets_jars_target "${_target_dir}/no-compress-assets-jars.target")
	set(_unsigned_package_target "${_target_dir}/unsigned-package.target")
	set(_signed_package_target "${_target_dir}/signed-package.target")

	# output files
	set(target_api_level_file "${_output_dir}/target-api-level")
	set(package_name_file "${_output_dir}/package-name")
	set(_dex_file "${_output_dir}/classes.dex")
	set(_resource_package_file "${_output_dir}/resources.zip")
	set(_unsigned_package_file "${_output_dir}/unsigned.apk")
	set(_package_file "${_apk_dir}/${_apk_file_name}.apk")

	# rule to parse manifest
	add_custom_command(
		OUTPUT
			"${parse_manifest_target}"
		COMMAND
			"${PYTHON_EXECUTABLE}" "${Android_ParseManifestScript}"
			"--manifest=${_manifest_file}"
			"--target=${parse_manifest_target}"
			"--target-api-level-file=${target_api_level_file}"
			"--package-name-file=${package_name_file}"
		BYPRODUCTS
			"${target_api_level_file}"
			"${package_name_file}"
		DEPENDS
			"${Android_ParseManifestScript}"
			"${_manifest_file}"
	)

	add_custom_target(${TARGET}_ParseManifest DEPENDS "${parse_manifest_target}")

	# prebuild rule to collect list of resource XMLs
	add_custom_target(${TARGET}_ResourceSourceFiles
		COMMAND "${CMAKE_COMMAND}"
			-D "RES_DIR=${_res_dir}"
			-D "PACKAGE_NAME_FILE=${package_name_file}"
			-D "RESOURCE_SOURCE_FILES_TARGET=${_resource_source_files_target}"
			-D "RESOURCE_PACKAGE_FILES_TARGET=${_resource_package_files_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-P "${Android_GENERATE_RESOURCE_SOURCE_FILES_TARGET_SCRIPT}"
		BYPRODUCTS
			"${_resource_source_files_target}"
			"${_resource_package_files_target}"
		DEPENDS
			${_android_DEPENDS}
			${TARGET}_ParseManifest
	)

	# prebuild rule to collect list of IDL files
	add_custom_target(${TARGET}_IdlSourceFiles
		COMMAND echo "Collecting IDL: ${TARGET}"
		COMMAND "${CMAKE_COMMAND}"
			-D "SRC_DIRS=${_src_dirs}"
			-D "PACKAGE_NAME_FILE=${package_name_file}"
			-D "IDL_SOURCE_FILES_TARGET=${_idl_source_files_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-P "${Android_GENERATE_IDL_SOURCE_FILES_TARGET_SCRIPT}"
		BYPRODUCTS
			"${_idl_source_files_target}"
		DEPENDS
			${_android_DEPENDS}
			${TARGET}_ParseManifest
	)

	# prebuild rule to collect list of JNI libraries
	add_custom_target(${TARGET}_JniLibraries
		COMMAND "${CMAKE_COMMAND}"
			-D "LIB_DIRS=${_lib_dirs}"
			-D "TARGET_FILE=${_jni_libraries_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-P "${Android_GENERATE_JNI_LIBRARIES_TARGET_SCRIPT}"
		BYPRODUCTS
			"${_jni_libraries_target}"
		DEPENDS
			"${Android_GENERATE_JNI_LIBRARIES_TARGET_SCRIPT}"
			${_android_LIB_TARGET_FILES}
			${_android_DEPENDS}
	)

	# rule to generate R java files
	add_custom_command(
		OUTPUT
			"${_resource_java_files_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "RES_DIR=${_res_dir}"
			-D "GEN_DIR=${_gen_dir}"
			-D "PACKAGE_NAME_FILE=${package_name_file}"
			-D "MANIFEST_FILE=${_manifest_file}"
			-D "RESOURCE_JAVA_FILES_TARGET=${_resource_java_files_target}"
			-D "TARGET_PLATFORM=${_android_TARGET_PLATFORM}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_PLATFORMS_DIR=${Android_PLATFORMS_DIR}"
			-D "Android_AAPT_COMMAND=${Android_AAPT_COMMAND}"
			-P "${Android_GENERATE_R_JAVA_FILE_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_R_JAVA_FILE_SCRIPT}"
			"${package_name_file}"
			"${_resource_source_files_target}"
	)

	# rule to generate IDL Java files
	add_custom_command(OUTPUT "${_idl_java_files_target}"
		COMMAND echo "Generating IDL java files: ${TARGET}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "SRC_DIRS=${_src_dirs}"
			-D "INCLUDE_DIRS=${_gen_dir}:${_src_dirs}"
			-D "GEN_DIR=${_gen_dir}"
			-D "PACKAGE_NAME_FILE=${package_name_file}"
			-D "IDL_SOURCE_FILES_TARGET=${_idl_source_files_target}"
			-D "IDL_JAVA_FILES_TARGET=${_idl_java_files_target}"
			-D "TARGET_PLATFORM=${_android_TARGET_PLATFORM}"
			-D "Android_SDK_ROOT=${Android_SDK_ROOT}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_PLATFORMS_DIR=${Android_PLATFORMS_DIR}"
			-D "Android_AIDL_COMMAND=${Android_AIDL_COMMAND}"
			-P "${Android_GENERATE_IDL_JAVA_FILES_SCRIPT}"
		COMMAND echo "Generating IDL java files DONE: ${TARGET}"
		DEPENDS
			"${Android_GENERATE_IDL_JAVA_FILES_SCRIPT}"
			"${package_name_file}"
			"${_resource_java_files_target}"
			"${_idl_source_files_target}"
	)

	java_tools_compile_java(${TARGET}_Java
		SRC_DIRS
			"${_src_dirs}"
			"${_gen_dir}"
		CLASS_PATHS
			"${Android_PLATFORMS_DIR}/${_android_TARGET_PLATFORM}/android.jar"
			${_class_paths}
		CLASSES_DIR
			"${_classes_dir}"
		DEPENDS
			"${_idl_java_files_target}"
			${TARGET}_ResourceSourceFiles
			${TARGET}_IdlSourceFiles
		TARGET_FILE_VAR
			_java_classes_target
	)

	# rule to generate dex file from class files
	add_custom_command(OUTPUT "${_dex_file}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "CLASSES_DIR=${_classes_dir}"
			-D "JAR_FILES=${_jar_files}"
			-D "DEX_FILE=${_dex_file}"
			-D "Android_DX_COMMAND=${Android_DX_COMMAND}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-P "${Android_GENERATE_DEX_FILES_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_DEX_FILES_SCRIPT}"
			"${_java_classes_target}"
			${_android_JAR_FILES}
	)

	# rule to generate keystore file
	if ( NOT _android_KEYSTORE_FILE )
		set(_android_KEYSTORE_FILE "${_keystore_dir}/debug.keystore")
		add_custom_command(
			OUTPUT "${_android_KEYSTORE_FILE}"
			COMMAND "${CMAKE_COMMAND}" -E make_directory "${_keystore_dir}"
			COMMAND "${Android_KEYTOOL_COMMAND}" -genkey
				-alias "androiddebugkey"
				-keypass "android"
				-validity "100000"
				-keystore "${_android_KEYSTORE_FILE}"
				-storepass "android"
				-dname "CN=Android Debug,O=Android,C=US"
		)
	endif()

	# rule to generate resources package
	add_custom_command(OUTPUT "${_resource_package_target}" "${_resource_package_file}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "RES_DIR=${_res_dir}"
			-D "ASSETS_DIR=${_assets_dir}"
			-D "MANIFEST_FILE=${_manifest_file}"
			-D "TARGET_PLATFORM=${_android_TARGET_PLATFORM}"
			-D "RESOURCE_PACKAGE_FILE=${_resource_package_file}"
			-D "RESOURCE_PACKAGE_TARGET=${_resource_package_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_PLATFORMS_DIR=${Android_PLATFORMS_DIR}"
			-D "Android_AAPT_COMMAND=${Android_AAPT_COMMAND}"
			-P "${Android_GENERATE_RESOURCE_PACKAGE_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_RESOURCE_PACKAGE_SCRIPT}"
			"${_resource_package_files_target}"
			"${_manifest_file}"
			${_android_DEPENDS}
			${_android_RESOURCE_DEPENDS}
	)

	# prebuild rule to collect list no compressed asset files
	add_custom_target(${TARGET}_NoCompressAssetsSourceFiles
		COMMAND "${CMAKE_COMMAND}"
			-D "ASSETS_DIRS=${_no_compress_assets_dirs}"
			-D "TARGET_FILE=${_no_compress_assets_source_files_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-P "${Android_GENERATE_ASSETS_SOURCE_FILES_TARGET}"
		BYPRODUCTS
			"${_no_compress_assets_source_files_target}"
		DEPENDS
			"${Android_GENERATE_ASSETS_SOURCE_FILES_TARGET}"
	)

	# rule to generate uncompressed assets
	add_custom_command(OUTPUT "${_no_compress_assets_jars_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "ASSETS_DIRS=${_no_compress_assets_dirs}"
			-D "TARGET_FILE=${_no_compress_assets_jars_target}"
			-D "OUTPUT_DIR=${_output_dir}"
			-D "JavaTools_JAR_EXECUTABLE=${JavaTools_JAR_EXECUTABLE}"
			-P "${Android_GENERATE_NO_COMPRESS_ASSETS_JARS_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_NO_COMPRESS_ASSETS_JARS_SCRIPT}"
			"${_no_compress_assets_source_files_target}"
	)

	# rule to generate apk package
	add_custom_command(OUTPUT "${_unsigned_package_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "DEX_FILE=${_dex_file}"
			-D "RESOURCE_PACKAGE_FILE=${_resource_package_file}"
			-D "ASSETS_DIRS=${_assets_dirs}"
			-D "JARS_TARGET_FILES=${_no_compress_assets_jars_target}"
			-D "LIB_DIRS=${_lib_dirs}"
			-D "PACKAGE_FILE=${_unsigned_package_file}"
			-D "PACKAGE_TARGET=${_unsigned_package_target}"
			-D "Java_JAVA_EXECUTABLE=${JavaTools_JAVA_EXECUTABLE}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_SDKLIB_JAR=${Android_SDKLIB_JAR}"
			-P "${Android_GENERATE_APK_PACKAGE_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_APK_PACKAGE_SCRIPT}"
			"${_resource_package_target}"
			"${_jni_libraries_target}"
			"${_no_compress_assets_target}"
			"${_dex_file}"
			${_android_DEPENDS}
			${TARGET}_NoCompressAssetsSourceFiles
			"${_no_compress_assets_jars_target}"
	)

	# rule to sign generated package
	add_custom_command(OUTPUT "${_signed_package_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "KEYSTORE_FILE=${_android_KEYSTORE_FILE}"
			-D "UNSIGNED_PACKAGE_FILE=${_unsigned_package_file}"
			-D "SIGNED_PACKAGE_FILE=${_package_file}"
			-D "SIGNED_PACKAGE_TARGET=${_signed_package_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_JARSIGNER_COMMAND=${JavaTools_JARSIGNER_COMMAND}"
			-P "${Android_GENERATE_SIGNED_PACKAGE_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_SIGNED_PACKAGE_SCRIPT}"
			"${_unsigned_package_target}"
			"${_android_KEYSTORE_FILE}"
	)

	# target
	set(_all_flag)
	if ( NOT _android_EXCLUDE_FROM_ALL )
		set(_all_flag "ALL")
	endif()

	add_custom_target(${TARGET} ${_all_flag} DEPENDS "${_signed_package_target}" ${TARGET}_JniLibraries)

	add_dependencies(${TARGET} ${TARGET}_Java)

	# custom dependencies
	if ( _android_JNI_TARGETS )
		add_dependencies(${TARGET} ${_android_JNI_TARGETS})
	endif()

	# target properties
	set_target_properties(${TARGET} PROPERTIES
		ANDROID_APK "${_package_file}"
	)
endfunction()




macro( android_add_jni_project TARGET PROJECT_PATH )

	set(_exclude_from_all)
	set(_arch)
	set(_neon NO)
	set(_properties)

	set(_awating_arch)
	set(_awating_property_name)
	set(_awating_property_value)

	foreach ( _arg ${ARGN} )

		set(_continue YES)

		if ( _awating_arch )
			set(_arch "${_arg}")
			set(_awating_arch)
		elseif ( _awating_property_name )
			list(APPEND _properties "${_arg}")
			set(_awating_property_name)
			set(_awating_property_value YES)
		elseif ( _awating_property_value )
			list(APPEND _properties "${_arg}")
			set(_awating_property_value)
		else()
			set(_continue)
		endif()

		if ( NOT _continue )
			if ( "${_arg}" STREQUAL "EXCLUDE_FROM_ALL" )
				set(_exclude_from_all YES)
			elseif ( "${_arg}" STREQUAL "ARCH" )
				set(_awating_arch YES)
			elseif ( "${_arg}" STREQUAL "NEON" )
				set(_neon YES)
			elseif ( "${_arg}" STREQUAL "PROPERTY" )
				set(_awating_property_name YES)
			else()
				message(FATAL_ERROR "Unknown token: ${_arg}")
			endif()
		endif()
	endforeach()

	if ( _awating_arch OR _awating_property_name OR _awating_property_value )
		message(FATAL_ERROR "Invalid usage")
	endif()

	# resolve arch
	if ( NOT _arch )
		set(_arch "armeabi")
	endif()

	# check for valid arch
	set(_available_archs "armeabi" "armeabi-v7a")
	list(FIND _available_archs "${_arch}" _arch_index)
	if ( _arch_index EQUAL -1 )
		message(FATAL_ERROR "Invalid arch: ${_arch}. Available archs: ${_available_archs}")
	endif()

	string(REPLACE ";" ":" _columned_properties "${_properties}")

	# dirs
	if ( IS_ABSOLUTE "${PROJECT_PATH}" )
		set(_source_dir "${PROJECT_PATH}")
	else()
		set(_source_dir "${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_PATH}")
	endif()
	set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}")

	# files
	set(_source_cmakelists_file "${_source_dir}/CMakeLists.txt")
	set(_target_cmakecache_file "${_target_dir}/CMakeCache.txt")
	set(_target_makefile_file "${_target_dir}/Makefile")

	add_custom_command(OUTPUT "${_target_cmakecache_file}" "${_target_makefile_file}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "ARCH=${_arch}"
			-D "NEON=${_neon}"
			-D "LIBRARY_OUTPUT_PATH=${_target_dir}/${Android_JNI_LIBRARY_OUTPUT_DIRECTORY_NAME}"
			-D "SOURCE_CMAKELISTS_FILE=${_source_cmakelists_file}"
			-D "TARGET_CMAKECACHE_FILE=${_target_cmakecache_file}"
			-D "PROPERTIES=${_columned_properties}"
			-D "Android_SDK_ROOT=${Android_SDK_ROOT}"
			-D "Android_TOOLCHAIN_ROOT=${Android_TOOLCHAIN_ROOT}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_VARIABLES_FILE_NAME=${Android_VARIABLES_FILE_NAME}"
			-P "${Android_CONFIGURE_JNI_PROJECT_SCRIPT}"
		DEPENDS
			"${Android_CONFIGURE_JNI_PROJECT_SCRIPT}"
			"${Android_TOOLCHAIN_FILE}"
			"${_source_cmakelists_file}"
	)

	# target
	set(_all_flag)
	if ( NOT _exclude_from_all )
		set(_all_flag "ALL")
	endif()

	add_custom_target(${TARGET} ${_all_flag}
		COMMAND
			"${CMAKE_COMMAND}" -E chdir "${_target_dir}" "${CMAKE_BUILD_TOOL}"
		DEPENDS
			"${_source_cmakelists_file}"
			"${_target_cmakecache_file}"
			"${_target_makefile_file}"
	)

endmacro()




macro( android_add_push TARGET )

	# paths
	set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/push-targets")

	set(_exclude_from_all)
	set(_serial_number)
	set(_source)
	set(_destination)

	set(_awating_serial_number)
	set(_awating_source)
	set(_awating_destination)

	set(_targets)

	foreach ( _arg ${ARGN} )
		set(_continue YES)

		if ( _awating_serial_number )
			set(_serial_number "${_arg}")
			set(_awating_serial_number)
		elseif ( _awating_source )
			set(_source "${_arg}")
			set(_awating_source)
			set(_awating_destination YES)
		elseif ( _awating_destination )
			set(_destination "${_arg}")

			# command
			set(_target "${_target_dir}${_destination}.target")

			add_custom_command(OUTPUT "${_target}"
				COMMAND "${CMAKE_COMMAND}"
					-D "SERIAL_NUMBER=${_serial_number}"
					-D "PUSH_SOURCE=${_source}"
					-D "PUSH_DESTINATION=${_destination}"
					-D "PUSH_TARGET=${_target}"
					-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
					-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
					-D "Android_ADB_COMMAND=${Android_ADB_COMMAND}"
					-P "${Android_PUSH_FILES_SCRIPT}"
				DEPENDS
					"${_source}"
					"${Android_PUSH_FILES_SCRIPT}"
			)

			list(APPEND _targets "${_target}")

			set(_awating_destination)
			set(_source)
			set(_destination)
		else()
			set(_continue)
		endif()

		if ( NOT _continue )
			if ( "${_arg}" STREQUAL "EXCLUDE_FROM_ALL" )
				set(_exclude_from_all YES)
			elseif ( "${_arg}" STREQUAL "SERIAL_NUMBER" )
				set(_awating_serial_number YES)
			elseif ( "${_arg}" STREQUAL "FILES" )
				set(_awating_source YES)
			else()
				message(FATAL_ERROR "Unknown token: ${_arg}")
			endif()
		endif()
	endforeach()

	# check for error
	if ( _awating_serial_number OR _awating_source OR _awating_destination )
		message(FATAL_ERROR "Invalid usage")
	endif()

	# target
	set(_all_flag)
	if ( NOT _exclude_from_all )
		set(_all_flag "ALL")
	endif()

	add_custom_target(${TARGET} ${_all_flag} DEPENDS ${_targets})

endmacro()




macro( android_add_install TARGET APK )

	# paths
	set(_target_dir "${CMAKE_CURRENT_BINARY_DIR}/install-targets")

	set(_exclude_from_all)
	set(_serial_number)

	set(_awating_serial_number)

	foreach ( _arg ${ARGN} )
		set(_continue YES)

		if ( _awating_serial_number )
			set(_serial_number "${_arg}")
		else()
			set(_continue)
		endif()

		if ( NOT _continue )
			if ( "${_arg}" STREQUAL "EXCLUDE_FROM_ALL" )
				set(_exclude_from_all YES)
			elseif ( "${_arg}" STREQUAL "SERIAL_NUMBER" )
				set(_awating_serial_number YES)
			else()
				message(FATAL_ERROR "Invalid token: ${_arg}")
			endif()
		endif()
	endforeach()

	# check for error
	if ( _awating_serial_number )
		message(FATAL_ERROR "Invalid usage")
	endif()

	# command
	set(_target "${_target_dir}${APK}.target")

	add_custom_command(OUTPUT "${_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "SERIAL_NUMBER=${_serial_number}"
			-D "APK=${APK}"
			-D "INSTALL_TARGET=${_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_ADB_COMMAND=${Android_ADB_COMMAND}"
			-P "${Android_INSTALL_FILES_SCRIPT}"
		DEPENDS
			"${Android_INSTALL_FILES_SCRIPT}"
			"${APK}"
	)

	# target
	set(_all_flag)
	if ( NOT _exclude_from_all )
		set(_all_flag "ALL")
	endif()

	add_custom_target(${TARGET} ${_all_flags} DEPENDS "${_target}")

endmacro()
