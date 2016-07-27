
function(flat_create_file_directory FILE)
	get_filename_component(dir "${FILE}" PATH)

	execute_process(
		COMMAND ${CMAKE_COMMAND} -E make_directory "${dir}"
		RESULT_VARIABLE result
	)

	if ( NOT ${result} EQUAL 0 )
		message(FATAL_ERROR "Error creating directory: ${dir}")
	endif()
endfunction()
