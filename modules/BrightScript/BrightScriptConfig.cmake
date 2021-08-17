
include(CMakeParseArguments)

get_filename_component(PythonCompiler_DIR "${CMAKE_CURRENT_LIST_DIR}/../PythonCompiler" ABSOLUTE)


find_package(PythonCompiler REQUIRED)
find_package(Flat REQUIRED)


set(BrightScript_CreateUpdateFileScript "${CMAKE_CURRENT_LIST_DIR}/create-update-file.py")
set(BrightScript_MergeModulesScript "${CMAKE_CURRENT_LIST_DIR}/merge-modules.py")
set(BrightScript_MergeManifestsScript "${CMAKE_CURRENT_LIST_DIR}/merge-manifests.py")
set(BrightScript_CreateZipScript "${CMAKE_CURRENT_LIST_DIR}/create-zip.py")
set(BrightScript_SideloadScript "${CMAKE_CURRENT_LIST_DIR}/sideload.py")
set(BrightScript_PkgScript "${CMAKE_CURRENT_LIST_DIR}/pkg.py")
set(BrightScript_CreateAuthTokenScript "${CMAKE_CURRENT_LIST_DIR}/create-auth-token.py")


function(brightscript_add_module NAME)
	cmake_parse_arguments(arg "" "SOURCE_DIR;MANIFEST" "DIRS;DEPENDS;FILES" ${ARGN})

	set(target BrightScript_Module_${NAME})

	if (NOT arg_MANIFEST)
		set(manifest RAW)
	else()
		set(manifest "${arg_MANIFEST}")
	endif()

	set(root_dir "${CMAKE_CURRENT_BINARY_DIR}")

	if ("${arg_SOURCE_DIR}" STREQUAL NONE)
		add_custom_target(${target})
	else()
		set(scan_file "${root_dir}/${NAME}.scan.done")

		if (arg_FILES)
			add_custom_command(
				OUTPUT
					"${scan_file}"
				COMMAND
					${PYTHON_EXECUTABLE} "${BrightScript_CreateUpdateFileScript}"
						--output "${scan_file}"
						--source-dir "${arg_SOURCE_DIR}"
						--files ${arg_FILES}
				DEPENDS
					"${BrightScript_CreateUpdateFileScript}"
					${arg_FILES}
			)
		else()
			set(scan_target BrightScript_Module_${NAME}_Scan)

			set(paths)
			foreach (dir ${arg_DIRS})
				list(APPEND paths "${arg_SOURCE_DIR}/${dir}/**")
			endforeach()

			flat_collect_files(${scan_target} "${scan_file}"
				DEPEND_ON_FILES
				RELATIVE "${arg_SOURCE_DIR}"
				PATHS ${paths}
			)
		endif()

		add_custom_target(${target}
			DEPENDS
				"${scan_file}"
		)

		set_target_properties(${target}
			PROPERTIES
				BRS_SCAN_FILE
					"${scan_file}"
		)
	endif()

	set_target_properties(${target}
		PROPERTIES
			BRS_SOURCE_DIR
				"${arg_SOURCE_DIR}"
			BRS_DEPENDS
				"${arg_DEPENDS}"
			BRS_MANIFEST
				${manifest}
	)
endfunction()


function(brightscript_add_auth_token_module NAME)
	cmake_parse_arguments(arg "" "CHANNEL_ID;AUTH_TOKENS_FILE" "" ${ARGN})

	set(manifest_file "${CMAKE_CURRENT_BINARY_DIR}/auth-token-manifest-${NAME}.yaml")
	set(done_file "${CMAKE_CURRENT_BINARY_DIR}/auth-token-${NAME}.done")

	add_custom_command(
		OUTPUT
			"${done_file}"
		BYPRODUCTS
			"${manifest_file}"
		COMMAND
			${PYTHON_EXECUTABLE} "${BrightScript_CreateAuthTokenScript}"
				--done-file "${done_file}"
				--manifest-file "${manifest_file}"
				--auth-tokens-file "${arg_AUTH_TOKENS_FILE}"
				--channel-id "${arg_CHANNEL_ID}"
		DEPENDS
			"${BrightScript_CreateAuthTokenScript}"
			"${arg_AUTH_TOKENS_FILE}"
	)

	set(manifest_target BrightScript_Module_${NAME}_Manifest)

	add_custom_target(${manifest_target}
		DEPENDS
			"${done_file}"
	)

	brightscript_add_module(${NAME}
		SOURCE_DIR
			NONE
		MANIFEST
			"${manifest_file}"
	)
endfunction()


function(brightscript_add_package NAME)
	cmake_parse_arguments(arg "" "DEVICE" "" ${ARGN})

	set(modules ${NAME})
	set(remaining_modules ${NAME})
	set(module_needed_by_${NAME})

	while (remaining_modules)
		list(POP_FRONT remaining_modules module)
		get_target_property(depends BrightScript_Module_${module} BRS_DEPENDS)
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

	set(root_dir "${CMAKE_CURRENT_BINARY_DIR}/${NAME}")
	set(package_dir "${root_dir}/package")

	# collect module data
	set(source_dirs)
	set(scan_targets)
	set(scan_files)

	foreach (module ${modules})
		get_target_property(source_dir BrightScript_Module_${module} BRS_SOURCE_DIR)
		if (NOT "${source_dir}" STREQUAL NONE)
			get_target_property(scan_file BrightScript_Module_${module} BRS_SCAN_FILE)
			set(scan_target BrightScript_Module_${module}_Scan)

			list(APPEND source_dirs "${source_dir}")
			list(APPEND scan_files "${scan_file}")
			if (TARGET ${scan_target})
				list(APPEND scan_targets ${scan_target})
			endif()
		endif()
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
			${PYTHON_EXECUTABLE} "${BrightScript_MergeModulesScript}"
				--output "${package_dir}"
				--source-dirs ${source_dirs}
				--files ${scan_files}
				--update-done-file "${package_merge_update_done_file}"
		COMMAND
			${CMAKE_COMMAND} -E touch "${package_merge_check_done_file}"
		DEPENDS
			"${BrightScript_MergeModulesScript}"
			${scan_files}
	)

	# merge manifests
	set(manifest_targets)
	set(package_manifest_file "${package_dir}/manifest")
	set(manifest_files)
	foreach (module ${modules})
		get_target_property(manifest BrightScript_Module_${module} BRS_MANIFEST)
		if (NOT "${manifest}" STREQUAL NONE)
			get_target_property(source_dir BrightScript_Module_${module} BRS_SOURCE_DIR)
			if ("${manifest}" STREQUAL RAW)
				set(manifest_file "${source_dir}/manifest")
			elseif ("${manifest}" STREQUAL YAML)
				set(manifest_file "${source_dir}/manifest.yaml")
			else()
				set(manifest_file "${manifest}")
			endif()
			list(APPEND manifest_files "${manifest_file}")

			set(manifest_target BrightScript_Module_${module}_Scan)
			if (TARGET ${manifest_target})
				list(APPEND manifest_targets ${manifest_target})
			endif()
		endif()
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
		${manifest_targets}
		brightscript
	)

	set(device_args)
	if (arg_DEVICE)
		list(APPEND device_args --device ${arg_DEVICE})
	endif()

	# sideload
	set(sideload_target ${NAME}_Sideload)

	add_custom_target(${sideload_target}
		COMMAND
			${PYTHON_EXECUTABLE} -B "${BrightScript_SideloadScript}"
				--package "${package_zip_file}"
				${device_args}
		DEPENDS
			"${BrightScript_SideloadScript}"
			"${package_zip_file}"
	)

	add_dependencies(${sideload_target}
		${package_target}
	)

	# pkg
	set(pkg_target ${NAME}_Pkg)
	set(pkg_file "${root_dir}/package.pkg")

	add_custom_target(${pkg_target}
		COMMAND
			${PYTHON_EXECUTABLE} -B "${BrightScript_PkgScript}"
				--output "${pkg_file}"
				${device_args}
		DEPENDS
			"${BrightScript_PkgScript}"
	)

	add_dependencies(${pkg_target}
		${sideload_target}
	)
endfunction()


set(BrightScript_FOUND YES)
