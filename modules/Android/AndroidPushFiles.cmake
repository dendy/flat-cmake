#!/usr/bin/cmake -P


include( "${Android_SCRIPT_DIR}/AndroidUtil.cmake" )


# create output directory
android_create_file_directory( "${PUSH_TARGET}" )


# signature
set( _signature_flag )
if ( _signature )
	set( _signature_flag -s "${_signature}" )
endif()


execute_process(
	COMMAND "${Android_ADB_COMMAND}" push ${_signature_flag} ${PUSH_SOURCE} ${PUSH_DESTINATION}
	RESULT_VARIABLE _result
)


if ( NOT _result EQUAL 0 )
	# do not abort whole build, just inform that push has failed
	message( WARNING "Pushing failed: ${PUSH_SOURCE} => ${PUSH_DESTINATION}" )
else()
	# save target file
	android_touch_file( "${PUSH_TARGET}" )
endif()
