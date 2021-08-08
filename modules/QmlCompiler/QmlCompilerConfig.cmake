
include(CMakeParseArguments)


set(QmlCompiler_Executable "" CACHE FILEPATH "Path to compiler executable")


find_package(Flat REQUIRED)

set(Python_ADDITIONAL_VERSIONS 3.5-32)
find_package(PythonInterp 3.5 REQUIRED)


set(QmlCompiler_ScriptsDir "${CMAKE_CURRENT_LIST_DIR}")
set(QmlCompiler_LibraryProjectDir "${CMAKE_CURRENT_LIST_DIR}/library")
set(QmlCompiler_GenerateQmlLoaderScript "${QmlCompiler_ScriptsDir}/generate-qml-loader.py")
set(QmlCompiler_FixCppScript "${QmlCompiler_ScriptsDir}/fix-cpp.py")


function(qmlcompiler_add_library TARGET LOADER_VAR)
	cmake_parse_arguments(f "" "SOURCE_DIR;PREFIX" "ENV" ${ARGN})

	set(build_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}")
	set(qml_files_target "${build_dir}/qml-files.target")

	flat_collect_files(${TARGET}_CollectQml "${qml_files_target}" PATHS "${f_SOURCE_DIR}/**/*.qml")

	if ( f_PREFIX )
		set(prefix_args PREFIX "${f_PREFIX}")
	else()
		set(prefix_args)
	endif()

	if ( CMAKE_TOOLCHAIN_FILE )
		set(toolchain_args CMAKE_TOOLCHAIN_FILE "${CMAKE_TOOLCHAIN_FILE}")
	else()
		set(toolchain_args)
	endif()

	set(cmake_args)
	if ( CMAKE_AR )
		list(APPEND cmake_args CMAKE_AR "${CMAKE_AR}")
	endif()

	if ( QmlCompiler_Executable )
		set(qml_compiler_executable "${QmlCompiler_Executable}")
	else()
		set(qml_compiler_executable "${_qt5Core_install_prefix}/bin/qtquickcompiler")
	endif()

	get_target_property(rcc_executable ${Qt5Core_RCC_EXECUTABLE} IMPORTED_LOCATION)

	flat_configure_cmake_project(${TARGET}_Archive_Configure
		SOURCE_DIR "${QmlCompiler_LibraryProjectDir}"
		BUILD_DIR "${build_dir}"
		ENV ${f_ENV}
		ARGS
			Flat_DIR "${Flat_DIR}"
			Qt5_DIR "${Qt5_DIR}"
			QML_COMPILER_EXECUTABLE "${qml_compiler_executable}"
			RCC_EXECUTABLE "${rcc_executable}"
			${prefix_args}
			${toolchain_args}
			${cmake_args}
			QML_FILES_TARGET "${qml_files_target}"
			QML_SOURCE_DIR "${f_SOURCE_DIR}"
			GENERATE_QML_LOADER_SCRIPT "${QmlCompiler_GenerateQmlLoaderScript}"
			FIX_CPP_SCRIPT "${QmlCompiler_FixCppScript}"
		DEPENDS
			"${qml_files_target}"
	)

	get_target_property(library_build_dir ${TARGET}_Archive_Configure CMAKE_BUILD_DIR)
	set(library_output_file "${library_build_dir}/libarchive.a")
	set(library_loader_file "${library_build_dir}/loader.cpp")

	flat_build_cmake_project(${TARGET}_Archive_Build ${TARGET}_Archive_Configure
		TARGETS archive loader
		OUTPUTS "${library_output_file}" "${library_loader_file}"
	)
	add_dependencies(${TARGET}_Archive_Build ${TARGET}_CollectQml)

	add_library(${TARGET} STATIC IMPORTED)
	add_dependencies(${TARGET} ${TARGET}_Archive_Build)
	set_target_properties(${TARGET} PROPERTIES IMPORTED_LOCATION "${library_output_file}")
	set_target_properties(${TARGET} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${Qt5Qml_PRIVATE_INCLUDE_DIRS}")
	set_target_properties(${TARGET} PROPERTIES INTERFACE_LINK_LIBRARIES m)

	set(${LOADER_VAR} "${library_loader_file}" PARENT_SCOPE)
endfunction()


set(QmlCompiler_FOUND YES)
