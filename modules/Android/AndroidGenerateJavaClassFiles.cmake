
#!/usr/bin/cmake -P

# Compile Java sources into class files.
#
# Arguments:
#   JAVA_SOURCE_PATH        - list of column separated paths to Java source paths,
#                              suitable to path to javac as -sourcepath <JAVA_SOURCE_PATH> option
#   TARGET_FILES            - list of column separated paths to target files, in which this script lookups for
#                             the list of source Java files: sources, R and IDL
#   CLASSES_DIR             - path where to generate classes
#   JAVA_CLASS_FILES_TARGET - path to target file that will be generated
#   JAVAC_OPTIONS           - extra options to javac


include( "${Android_SCRIPT_DIR}/AndroidUtil.cmake" )


# turn string into list by replacing ':' to ';'
string(REPLACE ":" ";" _target_files "${TARGET_FILES}")
string(REPLACE ":" ";" _src_dirs "${SRC_DIRS}")
string(REPLACE ":" ";" _javac_options "${JAVAC_OPTIONS}")


# create output directory
file( MAKE_DIRECTORY "${CLASSES_DIR}" )


set( _class_files )


foreach ( _target_file ${_target_files} )
	file( READ "${_target_file}" _java_files )

	foreach ( _java_file ${_java_files} )
		android_find_relative_dir( _src_dir _src_relative_path "${_java_file}" ${_src_dirs} )
		get_filename_component( _filepath "${_src_relative_path}" PATH )
		get_filename_component( _filename_we "${_java_file}" NAME_WE )
		set( _class_file "${CLASSES_DIR}/${_filepath}/${_filename_we}.class" )

		if ( "${_java_file}" IS_NEWER_THAN "${_class_file}" )
			android_debug_message( "Compiling Java file: ${_java_file}: ${_class_file}" )
			message( "Compiling: ${_java_file}" )

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
				message( FATAL_ERROR "\nError compiling java file: ${_java_file}\n${_error}" )
			endif()
		endif()
	endforeach()
endforeach()


file( WRITE "${JAVA_CLASS_FILES_TARGET}" "${_class_files}" )
