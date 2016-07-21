
# helper scripts
get_filename_component(scripts_dir "${CMAKE_CURRENT_LIST_FILE}" PATH)

set(JavaTools_SCRIPT_DIR "${scripts_dir}" CACHE PATH "" FORCE)
set(JavaTools_GENERATE_JAVA_SOURCE_FILES_TARGET_SCRIPT "${scripts_dir}/JavaToolsGenerateJavaSourceFilesTarget.cmake" CACHE FILEPATH "" FORCE)
set(JavaTools_GENERATE_JAVA_CLASS_FILES_SCRIPT "${scripts_dir}/JavaToolsGenerateJavaClassFiles.cmake" CACHE FILEPATH "" FORCE)
set(JavaTools_GENERATE_JAR_PACKAGE_SCRIPT "${scripts_dir}/JavaToolsGenerateJarPackage.cmake" CACHE FILEPATH "" FORCE)
set(JavaTools_GENERATE_SIGNED_PACKAGE_SCRIPT "${scripts_dir}/JavaToolsGenerateSignedPackage.cmake" CACHE FILEPATH "" FORCE)

mark_as_advanced(
	JavaTools_SCRIPT_DIR
	JavaTools_GENERATE_JAVA_SOURCE_FILES_TARGET_SCRIPT
	JavaTools_GENERATE_JAVA_CLASS_FILES_SCRIPT
	JavaTools_GENERATE_JAR_PACKAGE_SCRIPT
	JavaTools_GENERATE_SIGNED_PACKAGE_SCRIPT
)


# utils
include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


# java
find_package(Java)
if ( NOT Java_JAVA_EXECUTABLE )
	message(FATAL_ERROR "Cannot find java")
endif()
set(JavaTools_JAVA_EXECUTABLE "${Java_JAVA_EXECUTABLE}" CACHE PATH "" FORCE)
mark_as_advanced(JavaTools_JAVA_EXECUTABLE)


# javac
find_program(JavaTools_JAVAC_EXECUTABLE
	NAMES javac
)
if ( NOT JavaTools_JAVAC_EXECUTABLE )
	message(FATAL_ERROR "Cannot find javac")
endif()


# jar
find_program(JavaTools_JAR_EXECUTABLE
	NAMES jar
)
if ( NOT JavaTools_JAR_EXECUTABLE )
	message(FATAL_ERROR "Cannot find jar")
endif()


# jarsigner
find_program(JavaTools_JARSIGNER_COMMAND jarsigner)
if ( NOT JavaTools_JARSIGNER_COMMAND )
	mark_as_advanced(CLEAR JavaTools_JARSIGNER_COMMAND)
	message(FATAL_ERROR "Cannot find jarsigner")
endif()




# Usage:
#   java_tools_compile_java(TARGET [options])
#
# Create target named TARGET to compile java sources into class files.
#
# Options:
#   SRC_DIRS        - Source directories to find java files. Also will be used as -sourcepath to javac.
#   CLASS_PATHS     - List of additional class paths for javac.
#   CLASSES_DIR     - Where class files will be generated.
#   DEPENDS         - Additional file dependencies
#   TARGET_FILE_VAR - Return target file rule location.

function(java_tools_compile_java TARGET)
	message("java_tools_compile_java ${TARGET}")
	cmake_parse_arguments(_jar "" "CLASSES_DIR;TARGET_FILE_VAR" "SRC_DIRS;CLASS_PATHS;DEPENDS" ${ARGN})

	# dirs
	set(_build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}")
	set(_classes_dir "${_jar_CLASSES_DIR}")
	set(_targets_dir "${_build_dir}/targets")

	# class paths
	set(_class_paths)
	foreach ( _class_path ${_jar_CLASS_PATHS} )
		get_filename_component(_path "${_class_path}" ABSOLUTE)
		list(APPEND _class_paths "${_path}")
	endforeach()
	string(REPLACE ";" ":" _class_paths "${_class_paths}")

	# source dirs
	set(_src_dirs)
	foreach ( _src_dir "${_jar_SRC_DIRS}")
		get_filename_component(_path "${_src_dir}" ABSOLUTE)
		list(APPEND _src_dirs "${_path}")
	endforeach()
	string(REPLACE ";" ":" _src_dirs "${_src_dirs}")

	# target files
	set(_java_source_files_target "${_targets_dir}/java-source-files.target")
	set(_java_class_files_target "${_targets_dir}/java-class-files.target")

	# rule to collect list of Java files
	add_custom_target(${TARGET}_SourceFiles
		COMMAND echo "Collecting sources: ${TARGET}"
		COMMAND "${CMAKE_COMMAND}"
			-D "SRC_DIRS=${_src_dirs}"
			-D "JAVA_SOURCE_FILES_TARGET=${_java_source_files_target}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-P "${JavaTools_GENERATE_JAVA_SOURCE_FILES_TARGET_SCRIPT}"
		BYPRODUCTS
			"${_java_source_files_target}"
		COMMAND echo "Collecting sources DONE: ${TARGET}"
		DEPENDS
			"${JavaTools_GENERATE_JAVA_SOURCE_FILES_TARGET_SCRIPT}"
			${_jar_DEPENDS}
	)

	# rule to compile Java classes
	add_custom_command(OUTPUT "${_java_class_files_target}"
		COMMAND echo "Compiling class files: ${TARGET}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "TARGET_FILES=${_java_source_files_target}"
			-D "SRC_DIRS=${_src_dirs}"
			-D "CLASSES_DIR=${_classes_dir}"
			-D "CLASS_PATHS=${_class_paths}"
			-D "JAVA_SOURCE_PATH=${_src_dirs}"
			-D "Java_JAVAC_EXECUTABLE=${JavaTools_JAVAC_EXECUTABLE}"
			-D "JAVA_CLASS_FILES_TARGET=${_java_class_files_target}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-P "${JavaTools_GENERATE_JAVA_CLASS_FILES_SCRIPT}"
		DEPENDS
			"${JavaTools_GENERATE_JAVA_CLASS_FILES_SCRIPT}"
			"${_java_source_files_target}"
	)

	add_custom_target(${TARGET} DEPENDS "${_java_class_files_target}")
	add_dependencies(${TARGET} ${TARGET}_SourceFiles)

	set(${_jar_TARGET_FILE_VAR} "${_java_class_files_target}" PARENT_SCOPE)
endfunction()




# Usage:
#   java_tools_add_package(TARGET [options])
#
# Create target named TARGET to build JAR package from ROOT_DIR source tree.
#
# Options:
#   ROOT_DIR <dir>          - Package source root dir. Default: CMAKE_CURRENT_SOURCE_DIR.
#   CLASS_PATHS             - List of additional class path for Java.
#   PACKAGE_NAME <name>     - Name of jar-file to generate. If absent, TARGET will be used.
#   KEYSTORE_FILE <file>    - Use the given file to sign the package. If not specified final
#                             JAR is unsigned.
#   JNI_TARGETS             - JNI project targets to include.
#   EXCLUDE_FROM_ALL        - If set, generated target will be skipped from 'all' target.

function(java_tools_add_package TARGET)
	message("java_tools_add_package ${TARGET}")
	cmake_parse_arguments(_jar ""
		"ROOT_DIR;PACKAGE_NAME;ENTRY_POINT;KEYSTORE_FILE;EXCLUDE_FROM_ALL"
		"CLASS_PATHS;JNI_TARGETS" ${ARGN}
	)

	if ( NOT _jar_ROOT_DIR )
		set(_jar_ROOT_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
	endif()

	# resolve JAR file name
	if ( NOT _jar_PACKAGE_NAME )
		set(_jar_PACKAGE_NAME "${TARGET}")
	endif()

	# class paths
	set(_class_paths)
	foreach ( _class_path ${_jar_CLASS_PATHS} )
		get_filename_component(_path "${_class_path}" ABSOLUTE)
		list(APPEND _class_paths "${_path}")
	endforeach()
	string(REPLACE ";" ":" _class_paths "${_class_paths}")

	# entry point
	set(_entry_point)
	if ( _jar_ENTRY_POINT )
		string(REPLACE "." "/" _entry_point "${_jar_ENTRY_POINT}")
		set(_entry_point "${_entry_point}")
	endif()

	# source dirs
	set(_src_dir "${_jar_ROOT_DIR}")

	# destination dirs
	set(_build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_JarFiles")
	set(_classes_dir "${_build_dir}/classes")
	set(_output_dir "${_build_dir}/output")
	set(_target_dir "${_build_dir}/targets")
	set(_keystore_dir "${_build_dir}/keystore")
	set(_jni_libs_dir "${_build_dir}/libs")
	set(_jar_dir "${_build_dir}")

	# prebuild files
	set(_java_source_files_prebuild "${_target_dir}/java-source-files.prebuild")
	set(_jni_libraries_prebuild "${_target_dir}/jni-libraries.prebuild")

	# target files
	set(_java_source_files_target "${_target_dir}/java-source-files.target")
	set(_java_class_files_target "${_target_dir}/java-class-files.target")
	set(_jni_libraries_target "${_target_dir}/jni-libraries.target")
	set(_package_target "${_target_dir}/package.target")
	set(_signed_package_target "${_target_dir}/signed-package.target")

	# output files
	set(_package_file "${_jar_dir}/${_jar_PACKAGE_NAME}.jar")

	# prebuild rule to collect list of Java files
	add_custom_target(${TARGET}_SourceFiles
		#OUTPUT "${_java_source_files_target}.timestamp"
		COMMAND "${CMAKE_COMMAND}"
			-D "SRC_DIRS=${_src_dir}"
			-D "JAVA_SOURCE_FILES_TARGET=${_java_source_files_target}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-P "${JavaTools_GENERATE_JAVA_SOURCE_FILES_TARGET_SCRIPT}"
		BYPRODUCTS "${_java_source_files_target}"
		#COMMAND "${CMAKE_COMMAND}" -E touch "${_java_source_files_target}.timestamp"
		DEPENDS
			"${JavaTools_GENERATE_JAVA_SOURCE_FILES_TARGET_SCRIPT}"
			#"${_java_source_files_prebuild}"
	)

	# rule to compile Java classes
	add_custom_command(OUTPUT "${_java_class_files_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "TARGET_FILES=${_java_source_files_target}"
			-D "SRC_DIRS=${_src_dir}"
			-D "CLASSES_DIR=${_classes_dir}"
			-D "CLASS_PATHS=${_class_paths}"
			-D "JAVA_SOURCE_PATH=${_src_dir}"
			-D "Java_JAVAC_EXECUTABLE=${JavaTools_JAVAC_EXECUTABLE}"
			-D "JAVA_CLASS_FILES_TARGET=${_java_class_files_target}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-P "${JavaTools_GENERATE_JAVA_CLASS_FILES_SCRIPT}"
		DEPENDS
			"${JavaTools_GENERATE_JAVA_CLASS_FILES_SCRIPT}"
			"${_java_source_files_target}"
	)

	# rule to generate JAR package
	add_custom_command(OUTPUT "${_package_target}"
		COMMAND "${CMAKE_COMMAND}"
			-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
			-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
			-D "INPUTS=${_build_dir}/classes:."
			-D "PACKAGE_FILE=${_package_file}"
			-D "ENTRY_POINT=${_entry_point}"
			-D "PACKAGE_TARGET=${_package_target}"
			-D "Java_JAVA_EXECUTABLE=${Java_JAVA_EXECUTABLE}"
			-D "JavaTools_JAR_EXECUTABLE=${JavaTools_JAR_EXECUTABLE}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-P "${JavaTools_GENERATE_JAR_PACKAGE_SCRIPT}"
		DEPENDS
			"${JavaTools_GENERATE_JAR_PACKAGE_SCRIPT}"
			"${_java_class_files_target}"
	)

	if ( _jar_KEYSTORE_FILE )
		set(_final_package_target "${_signed_package_target}")

		# rule to sign generated package
		# FIXME: Allow user to specify signing options.
		add_custom_command(OUTPUT "${_signed_package_target}"
			COMMAND "${CMAKE_COMMAND}"
				-D "CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}"
				-D "CMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE}"
				-D "KEYSTORE_FILE=${_jar_KEYSTORE_FILE}"
				-D "PACKAGE_FILE=${_package_file}"
				-D "STOREPASS=?"
				-D "KEYPASS=?"
				-D "ALIAS=?"
				-D "SIGNED_PACKAGE_TARGET=${_signed_package_target}"
				-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
				-D "JavaTools_JARSIGNER_COMMAND=${JavaTools_JARSIGNER_COMMAND}"
				-P "${JavaTools_GENERATE_SIGNED_PACKAGE_SCRIPT}"
			DEPENDS
				"${JavaTools_GENERATE_SIGNED_PACKAGE_SCRIPT}"
				"${_package_target}"
				"${_jar_KEYSTORE_FILE}"
		)
	else()
		set(_final_package_target "${_package_target}")
	endif()

	# target
	set(_all_flag)
	if ( NOT _jar_EXCLUDE_FROM_ALL )
		set(_all_flag "ALL")
	endif()
	add_custom_target(${TARGET} ${_all_flag} DEPENDS "${_final_package_target}")

	# prebuild
#	add_custom_target(${TARGET}_JarPrebuild)
#	add_dependencies(${TARGET} ${TARGET}_JarPrebuild)

#	add_custom_command(TARGET ${TARGET}_JarPrebuild
#		COMMAND "${CMAKE_COMMAND}" -E make_directory "${_target_dir}"
#		COMMAND "${CMAKE_COMMAND}" -E touch "${_java_source_files_prebuild}"
#	)

	# custom dependencies
	if ( _jar_JNI_TARGETS )
		add_dependencies(${TARGET} ${_jar_JNI_TARGETS})
	endif()

	# target properties
	set_target_properties(${TARGET} PROPERTIES
		CLASS_PATHS "${_jar_CLASS_PATHS}"
		JAR_PACKAGE "${_package_file}"
	)
endfunction()




set(JavaTools_FOUND YES)
