#!/usr/bin/cmake -P


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


# verbose flags
set(_jar_verbose_flags)
if ( CMAKE_VERBOSE_MAKEFILE )
	set(_jar_verbose_flags "v")
endif()


# collect input
string( REPLACE ":" ";" _inputs "${INPUTS}" )

set(_input_var)

set(_dir)
foreach ( _input ${_inputs} )
	if ( NOT _dir )
		set(_dir "${_input}")
	else()
		list(APPEND _input_var -C "${_dir}" "${_input}")
		set(_dir)
	endif()
endforeach()

if ( _dir )
	message(FATAL_ERROR "Odd number of INPUT list: ${INPUT}")
endif()


# entry point
set(_entry_point_flag)
set(_entry_point_value)
if ( ENTRY_POINT )
	set(_entry_point_flag "e")
	set(_entry_point_value "${ENTRY_POINT}")
endif()



# remove previous package
file(REMOVE "${PACKAGE_FILE}")

# generate new one
# FIXME: Find JAR executable properly.
execute_process(
	COMMAND "${JavaTools_JAR_EXECUTABLE}" "cf${_jar_verbose_flags}${_entry_point_flag}"
		"${PACKAGE_FILE}"
		${_entry_point_value}
		${_input_var}
	RESULT_VARIABLE _result
	OUTPUT_VARIABLE _output
	ERROR_VARIABLE _error
)


if ( NOT _result EQUAL 0 )
	message( FATAL_ERROR "Error running jar (${_result}):\n${_error}" )
endif()


# save target file
java_tools_touch_file( "${PACKAGE_TARGET}" )
