
#!/usr/bin/cmake -P

# Compile Java sources into class files.
#
# Arguments:
#   JAVA_SOURCE_PATH        - list of column separated paths to Java source paths,
#                             suitable to path to javac as -sourcepath <JAVA_SOURCE_PATH> option
#   TARGET_FILES            - list of column separated paths to target files, in which this script lookups for
#                             the list of source Java files: sources, R and IDL
#   CLASSES_DIR             - path where to generate classes
#   JAVA_CLASS_FILES_TARGET - path to target file that will be generated
#   JAVAC_OPTIONS           - extra options to javac


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


# turn string into list by replacing ':' to ';'
string(REPLACE ":" ";" _target_files "${TARGET_FILES}")
string(REPLACE ":" ";" _src_dirs "${SRC_DIRS}")
string(REPLACE ":" ";" _javac_options "${JAVAC_OPTIONS}")


# create output directory
file(MAKE_DIRECTORY "${CLASSES_DIR}")


# locate all class files first
file(GLOB_RECURSE _all_class_files "${CLASSES_DIR}/*.class")


foreach ( _target_file ${_target_files} )
	file(READ "${_target_file}" _java_files)

	foreach ( _java_file ${_java_files} )
		java_tools_find_relative_dir(_src_dir _src_relative_path "${_java_file}" ${_src_dirs})
		get_filename_component(_filepath "${_src_relative_path}" PATH)
		get_filename_component(_filename_we "${_java_file}" NAME_WE)

		# find existing class files to remove
		set(_class_file_prefix "${CLASSES_DIR}/${_filepath}/${_filename_we}")
		set(_class_file "${_class_file_prefix}.class")
		file(GLOB _existing_class_files "${_class_file_prefix}$*.class")
		list(APPEND _existing_class_files "${_class_file}")
		list(REMOVE_ITEM _all_class_files ${_existing_class_files})

		if ( "${_java_file}" IS_NEWER_THAN "${_class_file}" )
			file(REMOVE ${_existing_class_files})

			java_tools_debug_message("Compiling Java file: ${_java_file}: ${_class_file}")

			# FIXME: Move user control over options.
			execute_process(
				COMMAND "${Java_JAVAC_EXECUTABLE}"
					-J-Xmx512M ${_javac_options} -Xmaxerrs 9999999 -encoding UTF-8 -g
					-classpath "${CLASS_PATHS}"
					-sourcepath "${JAVA_SOURCE_PATH}"
					"${_java_file}"
					-d "${CLASSES_DIR}"
				RESULT_VARIABLE _result
				OUTPUT_VARIABLE _output
				ERROR_VARIABLE _error
			)

			if ( NOT _result EQUAL 0 )
				string(REPLACE ";" "<<semicolon>>" _semicoloned_error "${_error}")
				string(REPLACE "\n" ";" _listed_semicoloned_error "${_semicoloned_error}")

				foreach ( _semicoloned_error_line ${_listed_semicoloned_error} )
					string(REPLACE "<<semicolon>>" ";" _error_line "${_semicoloned_error_line}")
					message("${_error_line}")
				endforeach()

				message(FATAL_ERROR "\nError compiling java file (${_result}): ${_java_file}")
			endif()
		endif()
	endforeach()
endforeach()


# remove hanging class files
if ( _all_class_files )
	file(REMOVE ${_all_class_files})
endif()


java_tools_touch_file("${JAVA_CLASS_FILES_TARGET}")
