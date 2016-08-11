
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
set(Android_ToolsDir "${Android_SDK_ROOT}/tools")
set(Android_PlatformToolsDir "${Android_SDK_ROOT}/platform-tools")
set(Android_BuildToolsDir "${Android_SDK_ROOT}/build-tools")
set(Android_PlatformsDir "${Android_SDK_ROOT}/platforms")

set(Android_CacheDir "${CMAKE_BINARY_DIR}/android-cache")


# tools
set(Android_SdklibJar "${Android_ToolsDir}/lib/sdklib.jar")


# platform tools
set(Android_ADB_COMMAND "${Android_PlatformToolsDir}/adb")
set(Android_AIDL_COMMAND "${Android_BUILD_TOOLS_DIR}/aidl" CACHE FILEPATH "" FORCE)
set(Android_DX_COMMAND "${Android_BUILD_TOOLS_DIR}/dx" CACHE FILEPATH "" FORCE)


# helper variables
set(Android_PythonCommand "${PYTHON_EXECUTABLE}" -B)
set(Android_VARIABLES_FILE_NAME "android-variables" CACHE STRING "" FORCE)
set(Android_JNI_LIBRARY_OUTPUT_DIRECTORY_NAME "jni-libs" CACHE STRING "" FORCE)
mark_as_advanced(Android_VARIABLES_FILE_NAME Android_JNI_LIBRARY_OUTPUT_DIRECTORY_NAME)


# helper scripts
function(__android_setup)
	get_filename_component(dir "${CMAKE_CURRENT_LIST_FILE}" PATH)

	set(Android_SCRIPT_DIR "${dir}" PARENT_SCOPE)
	set(Android_CollectCompileDependenciesScript "${dir}/collect-compile-dependencies.py" PARENT_SCOPE)
	set(Android_CollectPackagesScript "${dir}/collect-packages.py" PARENT_SCOPE)
	set(Android_SelectBuildToolsScript "${dir}/select-build-tools.py" PARENT_SCOPE)
	set(Android_ParseManifestScript "${dir}/parse-manifest.py" PARENT_SCOPE)
	set(Android_CollectResourceFilesScript "${dir}/collect-resource-files.py" PARENT_SCOPE)
	set(Android_GenerateRJavaFilesScript "${dir}/generate-r-java-files.py" PARENT_SCOPE)
	set(Android_GENERATE_IDL_SOURCE_FILES_TARGET_SCRIPT "${dir}/AndroidGenerateIdlSourceFilesTarget.cmake" PARENT_SCOPE)
	set(Android_GENERATE_JNI_LIBRARIES_TARGET_SCRIPT "${dir}/AndroidGenerateJniLibrariesTarget.cmake" PARENT_SCOPE)
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

	execute_process(
		COMMAND
			${Android_PythonCommand} "${dir}/parse-sdk.py"
			"--android-sdk-dir=${Android_SDK_ROOT}"
			"--output-dir=${Android_CacheDir}"
			"--depends=${dir}/parse-sdk.py"
		RESULT_VARIABLE result
		ERROR_VARIABLE error
	)

	if ( NOT ${result} EQUAL 0 )
		message(FATAL_ERROR "Error parsing Android SDK: ${error}")
	endif()
endfunction()

__android_setup()


# utils
include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


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
	set(args_single
		ROOT_DIR
		MANIFEST_FILE
		RES_DIR
		BUILD_TOOLS
		PLATFORM API_LEVEL
		KEYSTORE_FILE
		APK_FILE_NAME
		EXCLUDE_FROM_ALL
	)

	set(args_multi
		SRC_DIRS
		ASSETS_DIRS
		NO_COMPRESS_ASSETS_DIRS
		LIB_DIRS
		LIB_TARGET_FILES
		CLASS_PATHS
		JAR_FILES
		DEPENDS
		RESOURCE_DEPENDS
		COMPILE_DEPENDENCIES
	)

	cmake_parse_arguments(a "" "${args_single}" "${args_multi}" ${ARGN})

	if ( NOT a_ROOT_DIR AND NOT a_MANIFEST_FILE )
		message(FATAL_ERROR "Either ROOT_DIR or MANIFEST_FILE is mandatory")
	endif()

	# resolve apk file name
	if ( a_APK_FILE_NAME )
		set(_apk_file_name "${a_APK_FILE_NAME}")
	else()
		set(_apk_file_name "${TARGET}")
	endif()

	# root dir
	get_filename_component(root_dir "${a_ROOT_DIR}" ABSOLUTE)

	# manifest file
	if ( a_MANIFEST_FILE )
		get_filename_component(manifest_file "${a_MANIFEST_FILE}" ABSOLUTE)
	else()
		set(manifest_file "${root_dir}/AndroidManifest.xml")
	endif()

	# class paths
	set(_class_paths)
	foreach ( _class_path ${a_CLASS_PATHS} )
		get_filename_component(_path "${_class_path}" ABSOLUTE)
		list(APPEND _class_paths "${_path}")
	endforeach()
	string(REPLACE ";" ":" _class_paths "${_class_paths}")

	# source dirs
	set(_src_dirs "${root_dir}/java")
	if ( a_SRC_DIRS )
		list(APPEND _src_dirs ${a_SRC_DIRS})
	endif()
	string(REPLACE ";" ":" _src_dirs "${_src_dirs}")

	if ( a_RES_DIR )
		set(res_dir "${a_RES_DIR}")
	else()
		set(res_dir "${root_dir}/res")
	endif()

	set(_assets_dir "${root_dir}/assets")

	# assets
	set(_assets_dirs)
	foreach ( _a_dir ${a_ASSETS_DIRS} )
		get_filename_component(_path "${_a_dir}" ABSOLUTE)
		list(APPEND _assets_dirs "${_path}")
	endforeach()
	string(REPLACE ";" ":" _assets_dirs "${_assets_dirs}")

	# no compress assets
	set(_no_compress_assets_dirs)
	foreach ( _dir ${a_NO_COMPRESS_ASSETS_DIRS} )
		get_filename_component(_path "${_dir}" ABSOLUTE)
		list(APPEND _no_compress_assets_dirs "${_path}")
	endforeach()
	string(REPLACE ";" ":" _no_compress_assets_dirs "${_no_compress_assets_dirs}")

	# libs
	set(_lib_dirs)
	foreach ( _lib_dir ${a_LIB_DIRS} )
		get_filename_component(_path "${_lib_dir}" ABSOLUTE)
		list(APPEND _lib_dirs "${_path}")
	endforeach()
	string(REPLACE ";" ":" _lib_dirs "${_lib_dirs}")

	# jars
	set(_jar_files)
	foreach ( _jar_file ${a_JAR_FILES} )
		get_filename_component(_path "${_jar_file}" ABSOLUTE)
		list(APPEND _jar_files "${_path}")
	endforeach()
	string(REPLACE ";" ":" _jar_files "${_jar_files}")

	# destination dirs
	set(_build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_AndroidFiles")
	set(_gen_dir "${_build_dir}/gen")
	set(_classes_dir "${_build_dir}/classes")
	set(_output_dir "${_build_dir}/output")
	set(cache_dir "${_build_dir}/cache")
	set(_target_dir "${_build_dir}/targets")
	set(_keystore_dir "${_build_dir}/keystore")
	set(_jni_libs_dir "${_build_dir}/libs")
	set(_apk_dir "${_build_dir}")

	# target files
	set(parse_manifest_target "${_target_dir}/parse-manifest")
	set(resource_source_files_target "${_target_dir}/resource-source-files")
	set(resource_package_files_target "${_target_dir}/resource-package-files")
	set(_idl_source_files_target "${_target_dir}/idl-source-files.target")
	set(r_java_files_target "${_target_dir}/r-java-files")
	set(_idl_java_files_target "${_target_dir}/idl-java-files.target")
	set(_java_class_files_target "${_target_dir}/java-class-files.target")
	set(_resource_package_target "${_target_dir}/resource-package.target")
	set(_jni_libraries_target "${_target_dir}/jni-libraries.target")
	set(_no_compress_assets_source_files_target "${_target_dir}/no-compress-assets-source-files.target")
	set(_no_compress_assets_jars_target "${_target_dir}/no-compress-assets-jars.target")
	set(_unsigned_package_target "${_target_dir}/unsigned-package.target")
	set(_signed_package_target "${_target_dir}/signed-package.target")

	# output files
	set(available_build_tools_file "${_output_dir}/available-build-tools")
	set(build_tools_file "${_output_dir}/build-tools")
	set(available_platforms_file "${_output_dir}/available-platforms")
	set(platform_file "${_output_dir}/platform")
	set(package_name_file "${_output_dir}/package-name")
	set(_dex_file "${_output_dir}/classes.dex")
	set(_resource_package_file "${_output_dir}/resources.zip")
	set(_unsigned_package_file "${_output_dir}/unsigned.apk")
	set(_package_file "${_apk_dir}/${_apk_file_name}.apk")

	# cached files
	set(compile_dependencies_file "${cache_dir}/compile-dependencies")

	# command to collect compile dependencies
	set(compile_dependencies_args)
	foreach ( compile_dependency ${a_COMPILE_DEPENDENCIES} )
		list(APPEND compile_dependencies_args "--compile-dependency=${compile_dependency}")
	endforeach()

	execute_process(
		COMMAND
			${Android_PythonCommand} "${Android_CollectCompileDependenciesScript}"
			"--android-sdk-dir=${Android_SDK_ROOT}"
			"--extras-file=${Android_CacheDir}/extras"
			${compile_dependencies_args}
			"--output=${compile_dependencies_file}"
			"--depends=${Android_CollectCompileDependenciesScript}"
			"--depends=${Android_CacheDir}/extras"
	)

	# rule to collect available build tools
	add_custom_target(${TARGET}_CollectAvailableBuildTools
		COMMAND
			${Android_PythonCommand} "${Android_CollectPackagesScript}"
			"--dir=${Android_BuildToolsDir}"
			"--output=${available_build_tools_file}"
		BYPRODUCTS
			"${available_build_tools_file}"
		DEPENDS
			"${Android_CollectPackagesScript}"
		VERBATIM
	)

	# rule to select build tools
	add_custom_command(
		OUTPUT
			"${build_tools_file}"
		COMMAND
			"${PYTHON_EXECUTABLE}" "${Android_SelectBuildToolsScript}"
			"--dir=${Android_BuildToolsDir}"
			"--available-build-tools-file=${available_build_tools_file}"
			"--version=${a_BUILD_TOOLS}"
			"--output=${build_tools_file}"
		DEPENDS
			"${Android_SelectBuildToolsScript}"
			"${available_build_tools_file}"
		VERBATIM
	)

	# rule to collect available platforms
	add_custom_target(${TARGET}_CollectAvailablePlatforms
		COMMAND
			${Android_PythonCommand} "${Android_CollectPackagesScript}"
			"--dir=${Android_PlatformsDir}"
			"--output=${available_platforms_file}"
		BYPRODUCTS
			"${available_platforms_file}"
		DEPENDS
			"${Android_CollectPackagesScript}"
		VERBATIM
	)

	# rule to parse manifest
	add_custom_command(
		OUTPUT
			"${parse_manifest_target}"
		COMMAND
			${Android_PythonCommand} "${Android_ParseManifestScript}"
			"--manifest=${manifest_file}"
			"--platforms-dir=${Android_PlatformsDir}"
			"--available-platforms-file=${available_platforms_file}"
			"--platform=${a_PLATFORM}"
			"--target=${parse_manifest_target}"
			"--platform-file=${platform_file}"
			"--package-name-file=${package_name_file}"
		BYPRODUCTS
			"${platform_file}"
			"${package_name_file}"
		DEPENDS
			"${Android_ParseManifestScript}"
			"${manifest_file}"
			"${available_platforms_file}"
		VERBATIM
	)

	add_custom_target(${TARGET}_ParseManifest
		DEPENDS
			${TARGET}_CollectAvailablePlatforms
			"${parse_manifest_target}"
	)

	# prebuild rule to collect list of resource files
	add_custom_target(${TARGET}_CollectResourceFiles
		COMMAND
			${Android_PythonCommand} "${Android_CollectResourceFilesScript}"
			"--res-dir=${res_dir}"
			"--source-files-target=${resource_source_files_target}"
			"--package-files-target=${resource_package_files_target}"
		BYPRODUCTS
			"${resource_source_files_target}"
			"${resource_package_files_target}"
		DEPENDS
			${a_DEPENDS}
			"${Android_CollectResourceFilesScript}"
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
			${a_DEPENDS}
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
			${a_LIB_TARGET_FILES}
			${a_DEPENDS}
	)

	# rule to generate R java files
	add_custom_command(
		OUTPUT
			"${r_java_files_target}"
		COMMAND
			${Android_PythonCommand} "${Android_GenerateRJavaFilesScript}"
			"--res-dir=${res_dir}"
			"--output-dir=${_gen_dir}"
			"--manifest-file=${manifest_file}"
			"--build-tools-dir=${Android_BuildToolsDir}"
			"--platforms-dir=${Android_PlatformsDir}"
			"--package-name-file=${package_name_file}"
			"--build-tools-file=${build_tools_file}"
			"--platform-file=${platform_file}"
			"--target-file=${r_java_files_target}"
		DEPENDS
			"${Android_GenerateRJavaFilesScript}"
			"${package_name_file}"
			"${build_tools_file}"
			"${platform_file}"
			"${manifest_file}"
			"${resource_source_files_target}"
		VERBATIM
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
			-D "TARGET_PLATFORM=${a_TARGET_PLATFORM}"
			-D "Android_SDK_ROOT=${Android_SDK_ROOT}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_PLATFORMS_DIR=${Android_PlatformsDir}"
			-D "Android_AIDL_COMMAND=${Android_AIDL_COMMAND}"
			-P "${Android_GENERATE_IDL_JAVA_FILES_SCRIPT}"
		COMMAND echo "Generating IDL java files DONE: ${TARGET}"
		DEPENDS
			"${Android_GENERATE_IDL_JAVA_FILES_SCRIPT}"
			"${package_name_file}"
			"${r_java_files_target}"
			"${_idl_source_files_target}"
	)

	java_tools_compile_java(${TARGET}_Java
		SRC_DIRS
			"${_src_dirs}"
			"${_gen_dir}"
		CLASS_PATHS
			"${Android_PlatformsDir}/${a_TARGET_PLATFORM}/android.jar"
			${_class_paths}
		CLASSES_DIR
			"${_classes_dir}"
		DEPENDS
			"${_idl_java_files_target}"
			${TARGET}_CollectAvailableBuildTools
			${TARGET}_CollectAvailablePlatforms
			${TARGET}_CollectResourceFiles
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
			${a_JAR_FILES}
	)

	# rule to generate keystore file
	if ( NOT a_KEYSTORE_FILE )
		set(a_KEYSTORE_FILE "${_keystore_dir}/debug.keystore")
		add_custom_command(
			OUTPUT "${a_KEYSTORE_FILE}"
			COMMAND "${CMAKE_COMMAND}" -E make_directory "${_keystore_dir}"
			COMMAND "${Android_KEYTOOL_COMMAND}" -genkey
				-alias "androiddebugkey"
				-keypass "android"
				-validity "100000"
				-keystore "${a_KEYSTORE_FILE}"
				-storepass "android"
				-dname "CN=Android Debug,O=Android,C=US"
		)
	endif()

	# rule to generate resources package
	add_custom_command(
		OUTPUT
			"${_resource_package_target}" "${_resource_package_file}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "RES_DIR=${res_dir}"
			-D "ASSETS_DIR=${_assets_dir}"
			-D "MANIFEST_FILE=${manifest_file}"
			-D "TARGET_PLATFORM=${a_TARGET_PLATFORM}"
			-D "RESOURCE_PACKAGE_FILE=${_resource_package_file}"
			-D "RESOURCE_PACKAGE_TARGET=${_resource_package_target}"
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "Android_SCRIPT_DIR=${Android_SCRIPT_DIR}"
			-D "Android_PLATFORMS_DIR=${Android_PlatformsDir}"
			-D "Android_BUILD_TOOLS_DIR=${Android_BuildToolsDir}"
			"--build-tools-file=${build_tools_file}"
			-P "${Android_GENERATE_RESOURCE_PACKAGE_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_RESOURCE_PACKAGE_SCRIPT}"
			"${resource_package_files_target}"
			"${manifest_file}"
			"${build_tools_file}"
			${a_DEPENDS}
			${a_RESOURCE_DEPENDS}
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
			-D "Android_SDKLIB_JAR=${Android_SdklibJar}"
			-P "${Android_GENERATE_APK_PACKAGE_SCRIPT}"
		DEPENDS
			"${Android_GENERATE_APK_PACKAGE_SCRIPT}"
			"${_resource_package_target}"
			"${_jni_libraries_target}"
			"${_no_compress_assets_target}"
			"${_dex_file}"
			${a_DEPENDS}
			${TARGET}_NoCompressAssetsSourceFiles
			"${_no_compress_assets_jars_target}"
	)

	# rule to sign generated package
	add_custom_command(OUTPUT "${_signed_package_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "KEYSTORE_FILE=${a_KEYSTORE_FILE}"
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
			"${a_KEYSTORE_FILE}"
	)

	# target
	set(_all_flag)
	if ( NOT a_EXCLUDE_FROM_ALL )
		set(_all_flag "ALL")
	endif()

	add_custom_target(${TARGET} ${_all_flag} DEPENDS "${_signed_package_target}" ${TARGET}_JniLibraries)

	add_dependencies(${TARGET} ${TARGET}_Java)

	# custom dependencies
	if ( a_JNI_TARGETS )
		add_dependencies(${TARGET} ${a_JNI_TARGETS})
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
