
include(CMakeParseArguments)


find_package(PythonInterp 3.5 REQUIRED)


set(collect_files_script "${CMAKE_CURRENT_LIST_DIR}/collect-files.py")
set(hash_files_script "${CMAKE_CURRENT_LIST_DIR}/hash-files.py")
set(sum_script "${CMAKE_CURRENT_LIST_DIR}/sum.py")
set(verify_script "${CMAKE_CURRENT_LIST_DIR}/verify.py")


function(refactor TARGET SUM)
	cmake_parse_arguments(x "" "DOC" "GIT_DIRS;PATHS" ${ARGN})

	list(LENGTH x_GIT_DIRS git_dirs_length)
	math(EXPR git_dirs_reminder "${git_dirs_length} % 3")
	if (NOT git_dirs_reminder EQUAL 0)
		message(FATAL_ERROR "GIT_DIRS should have x3 arguments")
	endif()

	set(dir)
	set(rev)
	set(gits)
	foreach (g ${x_GIT_DIRS})
		if (rev)
			list(APPEND gits "${dir}:${rev}:${g}")
			set(dir)
			set(rev)
		elseif (dir)
			set(rev "${g}")
		else()
			set(dir "${g}")
		endif()
	endforeach()

	set(dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}-refactor")

	set(dir_target "${dir}/dir.target")
	set(files_file "${dir}/files")
	set(hashes_file "${dir}/hashes")
	set(sum_file "${dir}/sum")
	set(verify_target "${dir}/verify.target")

	add_custom_command(
		OUTPUT "${dir_target}"
		COMMAND ${CMAKE_COMMAND} -E make_directory "${dir}"
		COMMAND ${CMAKE_COMMAND} -E touch "${dir_target}"
	)

	add_custom_target(${TARGET}_CollectFiles
		BYPRODUCTS "${files_file}"
		COMMAND "${PYTHON_EXECUTABLE}" "${collect_files_script}"
			--paths ${x_PATHS}
			--output "${files_file}"
		DEPENDS
			"${collect_files_script}"
			"${dir_target}"
		VERBATIM
	)

	add_custom_target(${TARGET}_HashFiles
		BYPRODUCTS "${hashes_file}"
		COMMAND "${PYTHON_EXECUTABLE}" "${hash_files_script}"
			--files "${files_file}"
			--hashes "${hashes_file}"
		DEPENDS
			"${hash_files_script}"
			"${files_file}"
		VERBATIM
	)
	add_dependencies(${TARGET}_HashFiles ${TARGET}_CollectFiles)

	add_custom_command(
		OUTPUT "${sum_file}"
		COMMAND "${PYTHON_EXECUTABLE}" "${sum_script}"
			--input "${hashes_file}"
			--output "${sum_file}"
		DEPENDS
			"${sum_script}"
			"${hashes_file}"
		VERBATIM
	)

	add_custom_command(
		OUTPUT "${verify_target}"
		COMMAND "${PYTHON_EXECUTABLE}" "${verify_script}"
			--file "${sum_file}"
			--sum "${SUM}"
			--target "${verify_target}"
			--name "${TARGET}"
			--doc "${x_DOC}"
			--gits ${gits}
			--files "${files_file}"
		DEPENDS
			"${verify_script}"
			"${sum_file}"
		VERBATIM
	)

	add_custom_target(${TARGET} DEPENDS "${verify_target}")
	add_dependencies(${TARGET} ${TARGET}_HashFiles)
endfunction()


set(Refactor_FOUND YES)
