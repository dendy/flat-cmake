
cmake_minimum_required(VERSION 3.3)

function(_flat_exec)
	get_filename_component(root_dir "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

	set(Flat_DIR "${CMAKE_CURRENT_SOURCE_DIR}/modules/Flat")

	set(modules Core Debug Utils Link)

	foreach ( module ${modules} )
		string(TOLOWER "${module}" module_lower)
		add_subdirectory("${root_dir}/${module_lower}/cmake" "${module_lower}")
	endforeach()
endfunction()

_flat_exec()
