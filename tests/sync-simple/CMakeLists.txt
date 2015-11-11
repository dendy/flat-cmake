
set(_check_script "${CMAKE_CURRENT_SOURCE_DIR}/check.py")

set(_dest "${CMAKE_CURRENT_BINARY_DIR}/dest")
set(_source ${CMAKE_CURRENT_SOURCE_DIR})
set(_file_name "CMakeLists.txt")

flat_add_sync_target(foo "${_dest}")
flat_sync(foo "${_source}/${_file_name}")

add_custom_target(check ALL
	COMMAND "${PYTHON_EXECUTABLE}" "${_check_script}" --same "${_source}/${_file_name}" "${_dest}/${_file_name}"
	DEPENDS foo "${_check_script}"
)
