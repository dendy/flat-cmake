
#set(Android_SCRIPT_DEBUG YES)


include("${Flat_ScriptsDir}/Utils.cmake")




macro( android_debug_message MESSAGE )
	if ( Android_SCRIPT_DEBUG )
		message( "======== Android Debug: ${MESSAGE}" )
	endif()
endmacro()




macro( android_create_symlink SOURCE DESTINATION )
	execute_process( COMMAND "${CMAKE_COMMAND}" -E create_symlink "${SOURCE}" "${DESTINATION}" )
endmacro()




macro( android_calculate_md5sum FILEPATH MD5SUM )

	set( ${MD5SUM} )

	execute_process(
		COMMAND "${CMAKE_COMMAND}" -E md5sum "${FILEPATH}"
		RESULT_VARIABLE _md5sum_result
		OUTPUT_VARIABLE _md5sum_output
		ERROR_VARIABLE _md5sum_error
		ERROR_QUIET
		OUTPUT_STRIP_TRAILING_WHITESPACE
	)

	if ( _md5sum_result EQUAL 0 )
		set( ${MD5SUM} "${_md5sum_output}" )
	endif()

endmacro()




macro( android_touch_file FILEPATH )
	# FIXME: CMake -E touch does not set time stamp correctly in CMake 2.8.4.
	#        If file already exists it uses fopen() to change modification time.
	#        But that actually does not work, because fopen() truncates current time to seconds,
	#        while touch should preserve precise time, like utime() does:
	#            fopen(): 15:04:13.000000000
	#            utime(): 15:04:13.528446529

	set( Android_USE_CMAKE_TOUCH_WORKAROUND YES )
	if ( UNIX AND Android_USE_CMAKE_TOUCH_WORKAROUND )
		execute_process( COMMAND "touch" "${FILEPATH}" )
	else()
		execute_process( COMMAND "${CMAKE_COMMAND}" -E touch "${FILEPATH}" )
	endif()

endmacro()




macro( android_find_relative_dir DIR_VARIABLE RELATIVE_PATH_VARIABLE SOURCE )
	set( ${DIR_VARIABLE} )
	set( ${RELATIVE_PATH_VARIABLE} )
	set( _relative_path_found NO )
	foreach ( _dir ${ARGN} )
		if ( NOT _relative_path_found )
			file( RELATIVE_PATH _relative_path "${_dir}" "${SOURCE}" )
			string( REGEX MATCH "^../" _found_cd_up "${_relative_path}" )
			if ( NOT _found_cd_up )
				set( ${DIR_VARIABLE} "${_dir}" )
				set( ${RELATIVE_PATH_VARIABLE} "${_relative_path}" )
				set( _relative_path_found YES )
			endif()
		endif()
	endforeach()
endmacro()




macro( android_save_cache FILE )
	set( _contents )
	foreach( _arg ${ARGN} )
		set( _contents "${_contents}${_arg}:STRING=${${_arg}}\n" )
	endforeach()
	unset( _arg )

	flat_create_file_directory( "${FILE}" )
	file( WRITE "${FILE}" "${_contents}" )
	unset( _contents )
endmacro()




macro( android_save_variables FILE )
	set( _contents )
	foreach( _var ${ARGN} )
		set( _value "${${_var}}" )
		if ( "${_value}" STREQUAL "" )
			set( _value "${_var}-NOTFOUND" )
		endif()
		list( APPEND _contents "${_var}" "${_value}" )
	endforeach()
	unset( _var )
	unset( _value )

	flat_create_file_directory( "${FILE}" )
	file( WRITE "${FILE}" "${_contents}" )
	unset( _contents )
endmacro()




macro( android_load_variables FILE )
	file( READ "${FILE}" _contents )

	set( _awating_var_name YES )
	set( _var )

	foreach ( _arg ${_contents} )
		if ( _awating_var_name )
			set( _var "${_arg}" )
			set( _awating_var_name )
		else()
			set( ${_var} ${_arg} )
			set( _awating_var_name YES )
		endif()
	endforeach()

	if ( NOT _awating_var_name )
		message( FATAL_ERROR "Error reading variables from: ${FILE}" )
	endif()

	unset( _var )
	unset( _arg )
	unset( _awating_var_name )
	unset( _contents )
endmacro()




macro( android_add_apk_executable TARGET )
	add_library( ${TARGET} SHARED ${ARGN} "${Android_SCRIPT_DIR}/qandroidmain.cpp" )
endmacro()
