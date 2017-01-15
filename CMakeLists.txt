
cmake_minimum_required(VERSION 3.3)

function(_flat_exec)
	get_filename_component(root_dir "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

	set(Flat_DIR "${CMAKE_CURRENT_SOURCE_DIR}/modules/Flat")

	set(modules Core Debug Utils Link Game)

	set(other_files)

	foreach (module ${modules})
		set(target Flat_${module})

		string(TOLOWER "${module}" module_lower)
		add_subdirectory("${root_dir}/${module_lower}/cmake" "${module_lower}")

		# collect other files
		file(GLOB_RECURSE other_interface_files LIST_DIRECTORIES false
			"${root_dir}/${module_lower}/include/Flat/${module}/*.h")
		if (other_interface_files)
			list(APPEND other_files ${other_interface_files})
		endif()

		get_property(other_target_files TARGET ${target} PROPERTY OTHER_FILES)
		if (other_target_files)
			list(APPEND other_files ${other_target_files})
		endif()
	endforeach()

	add_custom_target(Flat_OtherFiles SOURCES ${other_files})
endfunction()

_flat_exec()
