
set(Necessitas_FOUND NO)


find_package(Android REQUIRED)
find_package(JavaTools REQUIRED)


include(CMakeParseArguments)


set(Necessitas_ScriptsDir "${CMAKE_CURRENT_LIST_DIR}")

set(Necessitas_GenerateSourceFilesTargetScript "${Necessitas_ScriptsDir}/NecessitasGenerateSourceFilesTarget.cmake")
set(Necessitas_GeneratePlainAssetsScript "${Necessitas_ScriptsDir}/NecessitasGeneratePlainAssets.cmake")
set(Necessitas_GenerateLibsScript "${Necessitas_ScriptsDir}/NecessitasGenerateLibs.cmake")
set(Necessitas_DeployQtScript "${Necessitas_ScriptsDir}/NecessitasDeployQt.cmake")


set(Necessitas_FOUND YES)


function(necessitas_add_assets TARGET)
	message("necessitas_add_assets ${TARGET}")
	cmake_parse_arguments(_n "" "PLAIN;LIB_PREFIX;GEN_DIR;SOURCE_TARGET_FILE_VAR;ASSETS_TARGET_FILE_VAR" "SRC_DIRS;SRC_FILES;EXCLUDE;DEPENDS" ${ARGN})

	if ( NOT _n_GEN_DIR OR NOT _n_ASSETS_TARGET_FILE_VAR )
		message(FATAL_ERROR "Missing mandatory variables")
	endif()

	# target files
	set(_targets_dir "${CMAKE_CURRENT_BINARY_DIR}/targets")
	set(_source_files_target_file "${_targets_dir}/${TARGET}-source-files.target")
	set(_plain_assets_target_file "${_targets_dir}/${TARGET}-plain-assets.target")

	# absolute paths
	set(_src_dirs)
	foreach ( _src_dir ${_n_SRC_DIRS} )
		get_filename_component(_path "${_src_dir}" ABSOLUTE)
		list(APPEND _src_dirs "${_src_dir}")
	endforeach()
	string(REPLACE ";" ":" _src_dirs "${_src_dirs}")

	set(_src_files)
	foreach ( _src_file ${_n_SRC_FILES} )
		get_filename_component(_path "${_src_file}" ABSOLUTE)
		list(APPEND _src_files "${_src_file}")
	endforeach()
	string(REPLACE ";" ":" _src_files "${_src_files}")

	get_filename_component(_gen_dir "${_n_GEN_DIR}" ABSOLUTE)

	string(REPLACE ";" ":" _excludes "${_n_EXCLUDE}")

	# rule to collect source files
	add_custom_target(${TARGET}_SourceFiles
		COMMAND ${CMAKE_COMMAND}
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-D "SRC_DIRS=${_src_dirs}"
			-D "SRC_FILES=${_src_files}"
			-D "EXCLUDE=${_excludes}"
			-D "TARGET_FILE=${_source_files_target_file}"
			-P "${Necessitas_GenerateSourceFilesTargetScript}"
		BYPRODUCTS
			"${_source_files_target_file}"
		DEPENDS
			"${Necessitas_GenerateSourceFilesTargetScript}"
			${_n_DEPENDS}
	)

	# rule to copy assets
	add_custom_command(OUTPUT "${_plain_assets_target_file}"
		COMMAND ${CMAKE_COMMAND}
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-D "SOURCE_FILES_TARGET_FILE=${_source_files_target_file}"
			-D "SRC_DIRS=${_src_dirs}"
			-D "PLAIN=${_n_PLAIN}"
			-D "LIB_PREFIX=${_n_LIB_PREFIX}"
			-D "GEN_DIR=${_gen_dir}"
			-D "TARGET_FILE=${_plain_assets_target_file}"
			-P "${Necessitas_GeneratePlainAssetsScript}"
		DEPENDS
			"${_source_files_target_file}"
			"${Necessitas_GeneratePlainAssetsScript}"
	)

	# target
	add_custom_target(${TARGET} DEPENDS "${_plain_assets_target_file}")
	add_dependencies(${TARGET} ${TARGET}_SourceFiles)

	if ( _n_SOURCE_TARGET_FILE_VAR )
		set(${_n_SOURCE_TARGET_FILE_VAR} "${_source_files_target_file}" PARENT_SCOPE)
	endif()
	set(${_n_ASSETS_TARGET_FILE_VAR} "${_plain_assets_target_file}" PARENT_SCOPE)
endfunction()


function(necessitas_add_libs TARGET LOCATION)
	cmake_parse_arguments(_n "" "" "QT_LIBS;FILES_ASSETS_TARGET_FILES;LIBS_SOURCE_TARGET_FILES;PLUGINS_ASSETS_TARGET_FILES;DEPENDS" ${ARGN})

	set(_files_assets_target_files)
	foreach ( _files_assets_target_file ${_n_FILES_ASSETS_TARGET_FILES} )
		get_filename_component(_path "${_files_assets_target_file}" ABSOLUTE)
		list(APPEND _files_assets_target_files "${_path}")
	endforeach()
	string(REPLACE ";" ":" _files_assets_target_files "${_files_assets_target_files}")

	set(_libs_source_target_files)
	foreach ( _libs_source_target_file ${_n_LIBS_SOURCE_TARGET_FILES} )
		get_filename_component(_path "${_libs_source_target_file}" ABSOLUTE)
		list(APPEND _libs_source_target_files "${_path}")
	endforeach()
	string(REPLACE ";" ":" _libs_source_target_files "${_libs_source_target_files}")

	set(_plugins_assets_target_files)
	foreach ( _plugins_assets_target_file ${_n_PLUGINS_ASSETS_TARGET_FILES} )
		get_filename_component(_path "${_plugins_assets_target_file}" ABSOLUTE)
		list(APPEND _plugins_assets_target_files "${_path}")
	endforeach()
	string(REPLACE ";" ":" _plugins_assets_target_files "${_plugins_assets_target_files}")

	string(REPLACE ";" ":" _qt_libs "${_n_QT_LIBS}")

	add_custom_target(${TARGET}
		COMMAND ${CMAKE_COMMAND}
			-D "Flat_ScriptsDir=${Flat_ScriptsDir}"
			-D "JavaTools_SCRIPT_DIR=${JavaTools_SCRIPT_DIR}"
			-D "Necessitas_ScriptsDir=${Necessitas_ScriptsDir}"
			-D "LOCATION=${LOCATION}"
			-D "FILES_ASSETS_TARGET_FILES=${_files_assets_target_files}"
			-D "LIBS_SOURCE_TARGET_FILES=${_libs_source_target_files}"
			-D "PLUGINS_ASSETS_TARGET_FILES=${_plugins_assets_target_files}"
			-D "QT_LIBS=${_qt_libs}"
			-P "${Necessitas_GenerateLibsScript}"
		BYPRODUCTS
			"${LOCATION}"
		DEPENDS
			${_n_FILES_ASSETS_TARGET_FILES}
			${_n_LIBS_SOURCE_TARGET_FILES}
			${_n_PLUGINS_ASSETS_TARGET_FILES}
			${_n_DEPENDS}
			"${Necessitas_GenerateLibsScript}"
			"${Necessitas_ScriptsDir}/libs.xml.in"
	)
endfunction()


function(necessitas_add_deploy_qt_target TARGET)
	cmake_parse_arguments(_n "" "MANIFEST_FILE" "" ${ARGN})

	get_target_property(_qmake_location Qt5::qmake IMPORTED_LOCATION)
	execute_process(COMMAND "${_qmake_location}" "-query" "QT_INSTALL_PREFIX" OUTPUT_VARIABLE _qt5_install_prefix)
	string(STRIP "${_qt5_install_prefix}" _qt5_install_prefix)

	if ( _n_MANIFEST_FILE )
		get_filename_component(_manifest_file "${_n_MANIFEST_FILE}" ABSOLUTE)
	else()
		set(_manifest_file)
	endif()

	add_custom_target(${TARGET}
		COMMAND ${CMAKE_COMMAND}
			-D "Qt5_INSTALL_PREFIX=${_qt5_install_prefix}"
			-D "TARGET_DIR=/data/local/tmp/qt"
			-D "Android_TOOLCHAIN_ROOT=${Android_TOOLCHAIN_ROOT}"
			-D "Android_PLATFORM_TOOLS_DIR=${Android_PLATFORM_TOOLS_DIR}"
			-D "MANIFEST_FILE=${_manifest_file}"
			-D "Java_JAVA_EXECUTABLE=${Java_JAVA_EXECUTABLE}"
			-D "Android_SAXON_PACKAGE=${Android_SAXON_PACKAGE}"
			-P "${Necessitas_DeployQtScript}"
		USES_TERMINAL
	)
endfunction()
