
include(CMakeParseArguments)

get_filename_component(PythonCompiler_DIR "${CMAKE_CURRENT_LIST_DIR}/../PythonCompiler" ABSOLUTE)


find_package(PythonCompiler REQUIRED)
find_package(Flat REQUIRED)


set(BrightScript_MergeLibsScript "${CMAKE_CURRENT_LIST_DIR}/merge-libs.py")
set(BrightScript_MergeManifestsScript "${CMAKE_CURRENT_LIST_DIR}/merge-manifests.py")
set(BrightScript_CreateZipScript "${CMAKE_CURRENT_LIST_DIR}/create-zip.py")
set(BrightScript_SideloadScript "${CMAKE_CURRENT_LIST_DIR}/sideload.py")
set(BrightScript_MakeDepsOrderScript "${CMAKE_CURRENT_LIST_DIR}/make-deps-order.py")


function(brightscript_add_module NAME)
	cmake_parse_arguments(arg "" "SOURCE_DIR" "DEPENDS" ${ARGN})

	set(target BrightScript_Module_${NAME})

	add_custom_target(${target})

	set_target_properties(${target}
		PROPERTIES
			DEPENDS
				"${arg_DEPENDS}"
	)

	set(root_dir "${CMAKE_CURRENT_BINARY_DIR}")

	if (arg_SOURCE_DIR)
		set(done_file "${root_dir}/${NAME}.scan.done")
		set(scan_target BrightScript_Module_${NAME}_Scan)

		flat_collect_files(${scan_target} "${done_file}"
			DEPEND_ON_FILES
			RELATIVE "${arg_SOURCE_DIR}"
			PATHS "${arg_SOURCE_DIR}/**"
			EXCLUDE "${arg_SOURCE_DIR}/*"
		)

		set_target_properties(${target}
			PROPERTIES
				SOURCE_DIR
					"${arg_SOURCE_DIR}"
				UPDATE_DONE_FILE
					"${done_file}"
		)
	else()
		message(FATAL_ERROR)
	endif()
endfunction()


function(brightscript_add_package NAME)
	cmake_parse_arguments(arg "" "DEVICE" "" ${ARGN})

	set(modules ${NAME})
	set(remaining_modules ${NAME})
	set(module_needed_by_${NAME})

	while (remaining_modules)
		list(POP_FRONT remaining_modules module)
		get_target_property(depends BrightScript_Module_${module} DEPENDS)
		set(module_depends_on_${module} ${depends})
		foreach (dep_module ${depends})
			list(FIND modules ${dep_module} module_index)
			if (${module_index} EQUAL -1)
				list(APPEND modules ${dep_module})
				list(APPEND remaining_modules ${dep_module})
				set(module_needed_by_${dep_module})
			endif()
			list(APPEND module_needed_by_${dep_module} ${module})
		endforeach()
	endwhile()

	set(remaining_modules ${modules})
	set(modules)

	while (remaining_modules)
		set(module)
		foreach (it_module ${remaining_modules})
			if (NOT module_depends_on_${it_module})
				set(module ${it_module})
				break()
			endif()
		endforeach()
		if (NOT module)
			message(FATAL_ERROR)
		endif()

		list(REMOVE_ITEM remaining_modules ${module})
		foreach (needed_by_module ${module_needed_by_${module}})
			list(REMOVE_ITEM module_depends_on_${needed_by_module} ${module})
		endforeach()

		list(APPEND modules ${module})
	endwhile()

	message("ordered_modules=${modules};")

	set(root_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}")
	set(package_dir "${root_dir}/package")

	# collect module data
	set(source_dirs)
	set(scan_targets)
	set(update_done_files)

	foreach (module ${modules})
		get_target_property(source_dir BrightScript_Module_${module} SOURCE_DIR)
		get_target_property(done_file BrightScript_Module_${module} UPDATE_DONE_FILE)
		set(scan_target BrightScript_Module_${module}_Scan)

		list(APPEND source_dirs "${source_dir}")
		list(APPEND update_done_files "${done_file}")
		list(APPEND scan_targets ${scan_target})
	endforeach()

	# merge files
	set(package_merge_check_done_file "${root_dir}/package.merge.check.done")
	set(package_merge_update_done_file "${root_dir}/package.merge.update.done")

	add_custom_command(
		OUTPUT
			"${package_merge_check_done_file}"
		BYPRODUCTS
			"${package_merge_update_done_file}"
		COMMAND
			${PYTHON_EXECUTABLE} "${BrightScript_MergeLibsScript}"
				--output "${package_dir}"
				--libs ${source_dirs}
				--files ${update_done_files}
				--update-done-file "${package_merge_update_done_file}"
		COMMAND
			${CMAKE_COMMAND} -E touch "${package_merge_check_done_file}"
		DEPENDS
			"${BrightScript_MergeLibsScript}"
			${update_done_files}
	)

	# merge manifests
	set(package_manifest_file "${package_dir}/manifest")
	set(manifest_files)
	foreach (source_dir ${source_dirs})
		set(manifest_file "${source_dir}/manifest")
		list(APPEND manifest_files "${manifest_file}")
	endforeach()

	add_custom_command(
		OUTPUT
			"${package_manifest_file}"
		COMMAND
			${PYTHON_EXECUTABLE} "${BrightScript_MergeManifestsScript}"
				--output "${package_manifest_file}"
				--manifests ${manifest_files}
		DEPENDS
			"${BrightScript_MergeManifestsScript}"
			${manifest_files}
	)

	# compile brightscript sources
	set(package_compile_check_done_file "${root_dir}/package.compile.check.done")

	add_custom_command(
		OUTPUT
			"${package_compile_check_done_file}"
		COMMAND
			"$<TARGET_FILE:brightscript>"
				check
#				-all-source
				-platlib "${BrightScript_ProjectDir}/Scripts/LibCore"
				"${package_dir}"
		COMMAND
			${CMAKE_COMMAND} -E touch "${package_compile_check_done_file}"
		DEPENDS
			"${package_merge_update_done_file}"
			"${package_manifest_file}"
			"$<TARGET_FILE:brightscript>"
	)

	# create zip
	set(package_zip_file "${root_dir}/package.zip")

	add_custom_command(
		OUTPUT
			"${package_zip_file}"
		COMMAND
			${PYTHON_EXECUTABLE} "${BrightScript_CreateZipScript}"
				--output "${package_zip_file}"
				--package-dir "${package_dir}"
		DEPENDS
			"${BrightScript_CreateZipScript}"
			"${package_compile_check_done_file}"
	)

	# package target
	set(package_target ${NAME}_Package)

	add_custom_target(${package_target}
		DEPENDS
			"${package_merge_check_done_file}"
			"${package_manifest_file}"
			"${package_compile_check_done_file}"
			"${package_zip_file}"
	)

	add_dependencies(${package_target}
		${scan_targets}
		brightscript
	)

	# sideload
	set(sideload_target ${NAME}_Sideload)

	set(sideload_args)
	if (arg_DEVICE)
		list(APPEND sideload_args --device ${arg_DEVICE})
	endif()

	add_custom_target(${sideload_target}
		COMMAND
			${PYTHON_EXECUTABLE} "${BrightScript_SideloadScript}"
				--package "${package_zip_file}"
				${sideload_args}
		DEPENDS
			"${BrightScript_SideloadScript}"
			"${package_zip_file}"
	)

	add_dependencies(${sideload_target}
		${package_target}
	)
endfunction()


set(BrightScript_FOUND YES)
