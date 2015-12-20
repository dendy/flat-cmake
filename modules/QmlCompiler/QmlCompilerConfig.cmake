
include(CMakeParseArguments)


find_package(Flat REQUIRED)


function(qmlcompiler_add_library TARGET)
	cmake_parse_arguments(_qml "" "SOURCE_DIR;TARGET" "" ${ARGN})

	get_target_property(_rcc ${Qt5Core_RCC_EXECUTABLE} IMPORTED_LOCATION)

	set(_qml_include_flags)
	foreach ( _qml_include_dir ${Qt5Qml_PRIVATE_INCLUDE_DIRS} )
		set(_qml_include_flags "${_qml_include_flags} -I${_qml_include_dir}")
	endforeach()

	set(_build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}")
	set(_qml_files_target "${_build_dir}/qml-files.target")
	set(_archive_file "${_build_dir}/libarchive.a")
	set(_loader_file "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}/loader.cpp")

	pasa_find_build_generator(_build_file_name _build_command)

	add_custom_target(${TARGET}_CollectQml
		COMMAND
			${CMAKE_COMMAND}
			-D "QML_SOURCE_DIR=${_qml_SOURCE_DIR}"
			-D "QML_FILES_TARGET=${_qml_files_target}"
			-D "Pasa_SCRIPT_DIR=${Pasa_SCRIPT_DIR}"
			-P "${Pasa_CollectQmlFilesScript}"
		BYPRODUCTS
			"${_qml_files_target}"
		DEPENDS
			"${Pasa_CollectQmlFilesScript}"
	)

	add_custom_command(OUTPUT "${_build_dir}/${_build_file_name}"
		COMMAND
			${CMAKE_COMMAND} -E make_directory "${_build_dir}"
		COMMAND
			${CMAKE_COMMAND}
			-G "${CMAKE_GENERATOR}"
			-D "QML_FILES_TARGET=${_qml_files_target}"
			-D "QML_COMPILER=${_qt5Core_install_prefix}/bin/qtquickcompiler"
			-D "RCC=${_rcc}"
			-D "CXX_FLAGS=${CMAKE_CXX_FLAGS} ${_qml_include_flags}"
			-D "Qt5_DIR=${Qt5_DIR}"
			-D "QML_SOURCE_DIR=${_qml_SOURCE_DIR}"
			-D "LOADER_FILE=${_loader_file}"
			-D "Pasa_SCRIPT_DIR=${Pasa_SCRIPT_DIR}"
			-D "Pasa_GenerateQmlLoaderScript=${Pasa_GenerateQmlLoaderScript}"
			"${Pasa_SCRIPT_DIR}/qml-compiler-project"
		WORKING_DIRECTORY
			"${_build_dir}"
		DEPENDS
			"${_qml_files_target}"
			"${Pasa_SCRIPT_DIR}/qml-compiler-project"
			"${Pasa_GenerateQmlLoaderScript}"
	)

	add_custom_command(OUTPUT "${_archive_file}" "${_loader_file}"
		COMMAND ${CMAKE_COMMAND} .
		COMMAND "${_build_command}"
		WORKING_DIRECTORY
			"${_build_dir}"
		DEPENDS
			"${_build_dir}/${_build_file_name}"
	)

	add_custom_target(${TARGET}_Archive DEPENDS "${_archive_file}")
	add_dependencies(${TARGET}_Archive ${TARGET}_CollectQml)

	add_library(${TARGET} STATIC IMPORTED)
	add_dependencies(${TARGET} ${TARGET}_Archive)
	set_target_properties(${TARGET} PROPERTIES IMPORTED_LOCATION "${_archive_file}")
endfunction()


set(QmlCompiler_FOUND YES)
