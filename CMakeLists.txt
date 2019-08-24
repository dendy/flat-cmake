
cmake_minimum_required(VERSION 3.3)

function(_flat_exec)
	get_filename_component(root_dir "${CMAKE_CURRENT_SOURCE_DIR}/.." ABSOLUTE)

	set(Flat_DIR "${CMAKE_CURRENT_SOURCE_DIR}/modules/Flat")

	set(Flat_Static NO CACHE BOOL "Build Flat libs statically")

	if (NOT Flat_Modules OR "${Flat_Modules}" STREQUAL ALL)
		set(modules Core Debug Utils Vulkan Link Game)
	elseif ("${Flat_Modules}" STREQUAL NONE)
		set(modules)
	else()
		set(modules ${Flat_Modules})
	endif()

	set(other_files)

	if (Flat_Static)
		set(flat_library_type STATIC)
	else()
		set(flat_library_type SHARED)
	endif()

	foreach (module ${modules})
		set(target Flat_${module})

		string(TOLOWER "${module}" module_lower)

		if (NOT IS_DIRECTORY "${root_dir}/${module_lower}")
			continue()
		endif()

		add_subdirectory("${root_dir}/${module_lower}/cmake" "${module_lower}")

		# collect other files
		file(GLOB_RECURSE other_interface_files LIST_DIRECTORIES false
			"${root_dir}/${module_lower}/include/Flat/${module}/*.h"
			"${root_dir}/${module_lower}/cpp/*.h")
		if (other_interface_files)
			list(APPEND other_files ${other_interface_files})
		endif()

		get_property(other_target_files TARGET ${target} PROPERTY OTHER_FILES)
		if (other_target_files)
			list(APPEND other_files ${other_target_files})
		endif()
	endforeach()

	file(GLOB other_scripts "${Flat_DIR}/*.py")

	add_custom_target(Flat_OtherFiles SOURCES ${other_files} ${other_scripts})
endfunction()

_flat_exec()
