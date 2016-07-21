#!/usr/bin/cmake -P


include( "${Android_SCRIPT_DIR}/AndroidUtil.cmake" )


# create output directory
android_create_file_directory( "${INSTALL_TARGET}" )


# signature
set( _signature_flag )
if ( _signature )
	set( _signature_flag -s "${_signature}" )
endif()


execute_process(
	COMMAND "${Android_ADB_COMMAND}" install ${_signature_flag} -r "${APK}"
	RESULT_VARIABLE _result
)


if ( NOT _result EQUAL 0 )
	# do not abort whole build, just inform that install has failed
	message( WARNING "Installing failed: ${APK}" )
else()
	# save target file
	android_touch_file( "${INSTALL_TARGET}" )
endif()
