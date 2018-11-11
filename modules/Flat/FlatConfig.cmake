
include(CMakeParseArguments)


get_filename_component(PythonCompiler_DIR "${CMAKE_CURRENT_LIST_DIR}/../PythonCompiler" ABSOLUTE)
find_package(PythonCompiler REQUIRED)


# scripts
set(Flat_ScriptsDir "${CMAKE_CURRENT_LIST_DIR}")
set(Flat_SyncScript "${CMAKE_CURRENT_LIST_DIR}/Sync.py")
set(Flat_RunWithEnvScriptIn "${CMAKE_CURRENT_LIST_DIR}/run-with-env.py.in")
set(Flat_GenerateGitTreeScript "${CMAKE_CURRENT_LIST_DIR}/generate-git-tree.py")
set(Flat_EraseCurrentDirScript "${CMAKE_CURRENT_LIST_DIR}/erase-current-dir.py")
set(Flat_CollectFilesScript "${CMAKE_CURRENT_LIST_DIR}/collect-files.py")
set(Flat_SyncDirectoryScript "${CMAKE_CURRENT_LIST_DIR}/sync-directory.py")
set(Flat_ReconfigureCMakeScript "${CMAKE_CURRENT_LIST_DIR}/reconfigure-cmake.py")
set(Flat_GenerateQrcScript "${CMAKE_CURRENT_LIST_DIR}/generate-qrc.py")
set(Flat_GenerateQmldirLoaderScript "${CMAKE_CURRENT_LIST_DIR}/generate-qmldir-loader.py")
set(Flat_CheckPchDepsScript "${CMAKE_CURRENT_LIST_DIR}/check-pch-deps.py")
set(Flat_GeneratePchFlagsScript "${CMAKE_CURRENT_LIST_DIR}/generate-pch-flags.py")
set(Flat_GeneratePchDepsScript "${CMAKE_CURRENT_LIST_DIR}/generate-pch-deps.py")
set(Flat_GeneratePchScript "${CMAKE_CURRENT_LIST_DIR}/generate-pch.py")


# utils
include("${Flat_ScriptsDir}/Utils.cmake")


# sources
set(Flat_DefaultSourceSuffixes h cpp)

set(_Flat_SourceLists)

function(flat_register_source_suffixes SUFFIXES LISTS)
	foreach ( suffix ${SUFFIXES} )
		set(lists_var _Flat_SourceSuffixLists_${suffix})
		list(APPEND ${lists_var} ${LISTS})
		list(REMOVE_DUPLICATES ${lists_var})
		set(${lists_var} ${${lists_var}} PARENT_SCOPE)
		list(APPEND _Flat_SourceLists ${LISTS})
		list(REMOVE_DUPLICATES _Flat_SourceLists)
		set(_Flat_SourceLists ${_Flat_SourceLists} PARENT_SCOPE)
	endforeach()
endfunction()

flat_register_source_suffixes("h;hpp;hxx" HEADERS)
flat_register_source_suffixes("c;cpp;cxx;mm;s" SOURCES)
flat_register_source_suffixes("c" C_SOURCES)
flat_register_source_suffixes("cpp;cxx" CPP_SOURCES)
flat_register_source_suffixes("ui" FORMS)
flat_register_source_suffixes("qrc" RESOURCES)
flat_register_source_suffixes("qml" QML)


function(flat_get_file_name_and_suffix FILE NAME_VAR SUFFIX_VAR)
	string(FIND "${FILE}" "." suffix_pos REVERSE)
	if ( ${suffix_pos} EQUAL -1 )
		set(${NAME_VAR} "${FILE}" PARENT_SCOPE)
		set(${SUFFIX_VAR} "" PARENT_SCOPE)
		return()
	endif()
	math(EXPR suffix_start_pos "${suffix_pos} + 1")
	string(SUBSTRING "${FILE}" 0 ${suffix_pos} name)
	string(SUBSTRING "${FILE}" ${suffix_start_pos} -1 suffix)
	set(${NAME_VAR} "${name}" PARENT_SCOPE)
	set(${SUFFIX_VAR} "${suffix}" PARENT_SCOPE)
endfunction()


# Locate source files with filename FILENAME and place them into
# appropriate lists with prefix PREFIX:
#
#   *.h         - ${PREFIX}_HEADERS and ${PREFIX}_H_HEADERS
#   *.hpp       - ${PREFIX}_HEADERS and ${PREFIX}_HPP_HEADERS
#   *.c         - ${PREFIX}_SOURCES and ${PREFIX}_C_SOURCES
#   *.cpp *.cxx - ${PREFIX}_SOURCES and ${PREFIX}_CPP_SOURCES
#   *.m *.mm    - ${PREFIX}_SOURCES and ${PREFIX}_OBJC_SOURCES
#   *.ui        - ${PREFIX}_FORMS
#   *.qrc       - ${PREFIX}_RESOURCES
#   *.qml       - ${PREFIX}_QML

function(flat_add_sources)
	set(state "listing-sources")
	set(prefix)
	set(dir "${CMAKE_CURRENT_SOURCE_DIR}")
	set(abs_dir "${dir}")
	set(arg_index 0)
	set(required_suffixes ${Flat_DefaultSourceSuffixes})

	foreach ( list ${_Flat_SourceLists} )
		set(list_${list})
	endforeach()

	foreach( arg ${ARGN} )
		math(EXPR arg_index "${arg_index} + 1")

		if (arg STREQUAL --)
			message("--")
			set(state listing-sources)
			continue()
		endif()

		if ( "${state}" STREQUAL "setting-prefix" )
			if ( prefix )
				message(FATAL_ERROR "Duplicated PREFIX")
			endif()
			set(prefix "${arg}")
			set(state "listing-sources")
			continue()
		endif()

		if ( "${state}" STREQUAL "setting-dir" )
			set(dir "${arg}")
			get_filename_component(abs_dir "${dir}" ABSOLUTE)
			set(state "listing-sources")
			continue()
		endif()

		if ( "${arg}" STREQUAL "PREFIX" )
			if ( NOT ${arg_index} EQUAL 1 )
				message(FATAL_ERROR "PREFIX must be first if present")
			endif()
			set(state "setting-prefix")
			continue()
		endif()

		if ( "${arg}" STREQUAL "DIR" )
			set(state "setting-dir")
			continue()
		endif()

		if (arg STREQUAL SUFFIXES)
			set(required_suffixes)
			set(state setting-suffixes)
			continue()
		endif()

		if (state STREQUAL setting-suffixes)
			if (NOT _Flat_SourceSuffixLists_${arg})
				message(FATAL_ERROR "Unknown suffix: ${arg}")
			endif()
			list(APPEND required_suffixes ${arg})
			continue()
		endif()

		flat_get_file_name_and_suffix("${arg}" file_name file_suffix)
		string(TOLOWER "${file_suffix}" file_suffix_lower)

		if (_Flat_SourceSuffixLists_${file_suffix_lower})
			set(suffixes "${file_suffix}")
		else()
			set(file_name "${arg}")
			set(suffixes ${required_suffixes})
		endif()

		foreach (suffix ${suffixes})
			set(f "${abs_dir}/${file_name}.${suffix}")

			if (NOT EXISTS "${f}")
				message(FATAL_ERROR "File not found: ${f}")
			endif()

			foreach (list ${_Flat_SourceSuffixLists_${suffix}})
				list(APPEND list_${list} "${f}")
			endforeach()
		endforeach()
	endforeach()

	if ( prefix )
		set(prefix ${prefix}_)
	endif()

	foreach ( list ${_Flat_SourceLists} )
		set(${prefix}${list} ${${prefix}${list}} ${list_${list}} PARENT_SCOPE)
	endforeach()
endfunction()


function(flat_add_target_rpath TARGET)
	cmake_parse_arguments(arg "" "" "" ${ARGN})

	if ( ANDROID )
		return()
	endif()

	if ( "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows" )
		return()
	endif()

	if ( "${CMAKE_SYSTEM_NAME}" STREQUAL "QNX" )
		set_target_properties(${TARGET} PROPERTIES SKIP_BUILD_RPATH YES)
		return()
	endif()

	if ( NOT arg_UNPARSED_ARGUMENTS )
		message(FATAL_ERROR "Missing RPATH values")
	endif()

	if ( "${CMAKE_SYSTEM_NAME}" STREQUAL "Linux" )
		set(is_elf YES)
	else()
		set(is_elf NO)
	endif()

	set(relative_rpaths)
	foreach ( rpath ${arg_UNPARSED_ARGUMENTS} )
		if ( "${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin" )
			list(APPEND relative_rpaths "@loader_path/${rpath}")
		elseif ( is_elf )
			list(APPEND relative_rpaths "\$ORIGIN/${rpath}")
		endif()
	endforeach()
	string(REPLACE ";" ":" coloned_rpaths "${relative_rpaths}")

	if ( "${CMAKE_SYSTEM_NAME}" STREQUAL "Darwin" )
		set_property(TARGET ${TARGET} APPEND PROPERTY LINK_FLAGS "-Wl,-rpath,${coloned_rpaths}")
		return()
	endif()

	if ( is_elf )
		set_target_properties(${TARGET} PROPERTIES
			BUILD_WITH_INSTALL_RPATH YES
			INSTALL_RPATH "${coloned_rpaths}"
		)

		get_target_property(libs ${TARGET} LINK_LIBRARIES)
		foreach ( lib ${libs} )
			if ( TARGET ${lib} )
				get_target_property(lib_imported ${lib} IMPORTED)
				if ( lib_imported )
					get_target_property(lib_location ${lib} LOCATION)
					get_filename_component(lib_dir "${lib_location}" DIRECTORY)
					set_property(TARGET ${TARGET} APPEND_STRING PROPERTY
							LINK_FLAGS " -Wl,-rpath-link,${lib_dir}")
				endif()
			endif()
		endforeach()
		return()
	endif()
endfunction()


function(flat_add_library_export_macro TARGET EXPORT)
	get_target_property(type ${TARGET} TYPE)
	if ( "${type}" STREQUAL "SHARED_LIBRARY" )
		if ( "${CMAKE_SYSTEM_NAME}" STREQUAL "Windows" )
			set(build_macro "${EXPORT}=__declspec(dllexport)")
			set(import_macro "${EXPORT}=__declspec(dllimport)")
		else()
			set(build_macro "${EXPORT}=__attribute__((visibility(\"default\")))")
			set(import_macro "${EXPORT}=__attribute__((visibility(\"default\")))")
		endif()
	else()
		set(build_macro "${EXPORT}=")
		set(import_macro "${EXPORT}=")
	endif()
	set_property(TARGET ${TARGET} APPEND PROPERTY COMPILE_DEFINITIONS "${build_macro}")
	set_property(TARGET ${TARGET} APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS "${import_macro}")
endfunction()


# sync
function(_flat_add_sync_check_conflict TARGET DELETE_PATH CHECK_PATH OK)
	string(LENGTH "${DELETE_PATH}" delete_path_length)

	if ( ${delete_path_length} EQUAL 0 )
		set(${OK} NO PARENT_SCOPE)
		return()
	endif()

	math(EXPR delete_path_last_pos "${delete_path_length} - 1")
	string(SUBSTRING "${DELETE_PATH}" ${delete_path_last_pos} 1 delete_path_last_char)
	if ( "${delete_path_last_char}" STREQUAL "/" )
		string(SUBSTRING "${DELETE_PATH}" 0 ${delete_path_last_pos} delete_path_without_slash)
	else()
		set(delete_path_without_slash "${DELETE_PATH}")
	endif()

	if ( "${delete_path_without_slash}" STREQUAL "${CHECK_PATH}" )
		set(${OK} NO PARENT_SCOPE)
		return()
	endif()

	string(FIND "${CHECK_PATH}" "${delete_path_without_slash}/" pos)
	if ( pos EQUAL 0 )
		set(${OK} NO PARENT_SCOPE)
		return()
	endif()

	set(${OK} YES PARENT_SCOPE)
endfunction()


function(flat_add_sync_target TARGET DESTINATION)
	cmake_parse_arguments(f "" "OUTPUT" "DEPENDS" ${ARGN})

	set(file_sep "!!fs!!")

	set(command
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_SyncScript}"
			"--destination-root=$<TARGET_PROPERTY:${TARGET},DestinationRoot>"
			"--source=$<JOIN:$<TARGET_PROPERTY:${TARGET},SyncSourceList>,${file_sep}>"
			"--destination=$<JOIN:$<TARGET_PROPERTY:${TARGET},SyncDestinationList>,${file_sep}>"
			"--delete=$<JOIN:$<TARGET_PROPERTY:${TARGET},SyncDeleteList>,${file_sep}>"
			"--copy-symlinks=$<JOIN:$<TARGET_PROPERTY:${TARGET},SyncCopySymlinksList>,${file_sep}>"
			"--excludes=$<JOIN:$<TARGET_PROPERTY:${TARGET},SyncExcludesList>,${file_sep}>"
	)

	if (f_OUTPUT)
		get_filename_component(output_directory "${f_OUTPUT}" DIRECTORY)

		add_custom_command(
			OUTPUT "${f_OUTPUT}"
			${command}
			COMMAND ${CMAKE_COMMAND} -E make_directory "${output_directory}"
			COMMAND ${CMAKE_COMMAND} -E touch "${f_OUTPUT}"
			WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
			DEPENDS ${f_DEPENDS} "${Flat_SyncScript}"
		)

		add_custom_target(${TARGET} DEPENDS "${f_OUTPUT}")
	else()
		add_custom_target(${TARGET}
			${command}
			WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
			DEPENDS ${f_DEPENDS}
		)
	endif()

	set_target_properties(${TARGET} PROPERTIES
		SyncList ""
		DestinationRoot "${DESTINATION}"
	)
endfunction()


function(flat_sync_once TARGET SOURCE DESTINATION)
	set(exclude_sep "!!es!!")

	cmake_parse_arguments(f "KEEP" "PATH" "EXCLUDE;DEPENDS" ${ARGN})

	if (f_KEEP)
		set(f_DELETE NO)
	else()
		set(f_DELETE YES)
	endif()

	if (f_EXCLUDE)
		string(REPLACE ";" "${exclude_sep}" excludes "${f_EXCLUDE}")
	else()
		set(excludes "NONE")
	endif()

	if (f_DEPENDS)
		set(depends_args DEPENDS ${f_DEPENDS})
	else()
		set(depends_args)
	endif()

	add_custom_target(${TARGET}
		COMMAND "${PYTHON_EXECUTABLE}"
			"${Flat_SyncScript}"
			"--destination-root=${DESTINATION}"
			"--source=${SOURCE}"
			"--destination=${f_PATH}"
			"--delete=${f_DELETE}"
			"--copy-symlinks=YES"
			"--excludes=${excludes}"
		WORKING_DIRECTORY
			"${CMAKE_CURRENT_BINARY_DIR}"
		${depends_args}
	)
endfunction()


function(flat_sync TARGET SOURCE)
	set(exclude_sep "!!es!!")

	if (NOT TARGET ${TARGET})
		message(FATAL_ERROR "Create target ${TARGET} with flat_add_sync_target() first")
	endif()

	cmake_parse_arguments(sync "KEEP;COPY_SYMLINKS" "DESTINATION" "DEPENDS;EXCLUDE" ${ARGN})

	if (NOT sync_DESTINATION)
		set(sync_DESTINATION "ROOT")
	endif()

	if (sync_EXCLUDE)
		set(excludes "")
		foreach (exclude ${sync_EXCLUDE})
			if (NOT "${excludes}" STREQUAL "")
				set(excludes "${excludes}${exclude_sep}")
			endif()
			set(excludes "${excludes}${exclude}")
		endforeach()
	else()
		set(excludes "NONE")
	endif()

	if (sync_KEEP)
		set(sync_DELETE NO)
	else()
		set(sync_DELETE YES)
	endif()

	if (sync_COPY_SYMLINKS)
		set(sync_COPY_SYMLINKS YES)
	else()
		set(sync_COPY_SYMLINKS NO)
	endif()

	set_property(TARGET ${TARGET} APPEND PROPERTY SyncSourceList "${SOURCE}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncDestinationList "${sync_DESTINATION}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncDeleteList "${sync_DELETE}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncCopySymlinksList "${sync_COPY_SYMLINKS}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncExcludesList "${excludes}")

	if (sync_DEPENDS)
		add_dependencies(${TARGET} ${sync_DEPENDS})
	endif()

	get_target_property(sync_list ${TARGET} SyncList)

	# check conflicting DELETE destinations
	foreach (var ${sync_list})
		get_target_property(sync_destination   ${TARGET} SyncDestination_${var})
		get_target_property(sync_sources       ${TARGET} SyncSources_${var})
		get_target_property(sync_depends       ${TARGET} SyncDepends_${var})
		get_target_property(sync_delete        ${TARGET} SyncDelete_${var})
		get_target_property(sync_exclude       ${TARGET} SyncExclude_${var})
		get_target_property(sync_copy_symlinks ${TARGET} SyncCopySymlinks_${var})

		set(ok YES)

		if (sync_DELETE)
			_flat_add_sync_check_conflict(${TARGET} "${sync_DESTINATION}" "${sync_destination}" ok)
		endif()

		if (ok)
			if (sync_delete)
				_flat_add_sync_check_conflict(${TARGET} "${sync_destination}"
						"${sync_DESTINATION}" ok)
			endif()
		endif()

		if (NOT ok)
			message("Conflicting syncs:")
			message("    ${SOURCE} - > ${sync_DESTINATION} (delete=${sync_DELETE})")
			message("    ${sync_sources} -> ${sync_destination} (delete=${sync_delete})")
			message(FATAL_ERROR "Fix sync conclicts above")
		endif()
	endforeach()

	string(REPLACE ":" "_colon_" var "${sync_DESTINATION}")
	string(REPLACE "/" "_" var "${var}")
	string(REPLACE "\\" "_" var "${var}")

	if ("${var}" STREQUAL "")
		set(var "ROOT")
	endif()

	set(var ${var}_${sync_COPY_SYMLINKS})

	list(FIND sync_list ${var} var_index)
	if (NOT ${var_index} EQUAL -1)
		get_target_property(sync_destination   ${TARGET} SyncDestination_${var})
		get_target_property(sync_sources       ${TARGET} SyncSources_${var})
		get_target_property(sync_depends       ${TARGET} SyncDepends_${var})
		get_target_property(sync_delete        ${TARGET} SyncDelete_${var})
		get_target_property(sync_exclude       ${TARGET} SyncExclude_${var})
		get_target_property(sync_copy_symlinks ${TARGET} SyncCopySymlinks_${var})
	else()
		list(APPEND sync_list ${var})
	endif()

	set(sync_destination "${sync_DESTINATION}")
	list(APPEND sync_sources "${SOURCE}")
	set(sync_delete "${sync_DELETE}")
	set(sync_copy_symlinks "${sync_COPY_SYMLINKS}")
	if (sync_DEPENDS)
		list(APPEND sync_depends "${sync_DEPENDS}")
	endif()
	if (sync_EXCLUDE)
		list(APPEND sync_exclude "${sync_EXCLUDE}")
	endif()

	set_target_properties(${TARGET} PROPERTIES
		SyncList                "${sync_list}"
		SyncDestination_${var}  "${sync_destination}"
		SyncSources_${var}      "${sync_sources}"
		SyncDepends_${var}      "${sync_depends}"
		SyncDelete_${var}       "${sync_delete}"
		SyncExclude_${var}      "${sync_exclude}"
		SyncCopySymlinks_${var} "${sync_copy_symlinks}"
	)
endfunction()


# Arguments:
#     TARGET      - target name
#     OUTPUT      - output target file
#     MODULES     - list of Qt5 modules, example: MODULES Quick Network
#     PLUGINS     - list of Qt5 plugins, example: PLUGINS imageformats:qjpeg sqldrivers:qsqlite
#     QML         - list of QML packages, example: QML QtQuick/LocalStorage QtQuick/Controls
#     DIR         - directory where to copy
#     RUNTIME_DIR - directory where to copy executables. On Windows runtime libraries
#                    will be copied into this directory as well.
#     DEBUG       - deploy debug libraries
#     RELEASE     - deploy release libraries
#     PLATFORMS   - platform plugin, examples: PLATFORMS qwindows, PLATFORMS qxcb qwayland
#     FONTS       - fonts to install: <ALL,NONE>
#     SYSTEM_LIBS - system libraries to deploy

function(flat_deploy_qt5 TARGET)
	cmake_parse_arguments(f
		"DEBUG;RELEASE"
		"QMAKE;OUTPUT;DIR;RUNTIME_DIR;LIB_DIR;QML_PLUGINS_DIR;QNX_TARGET"
		"MODULES;PLUGINS;QML;PLATFORMS;FONTS;SYSTEM_LIBS;DEPENDS"
		${ARGN}
	)

	if ( NOT f_DIR )
		message(FATAL_ERROR "DIR is mandatory")
	endif()

	if ( NOT f_DEBUG AND NOT f_RELEASE )
		set(f_RELEASE YES)
	endif()

	if ( f_DEBUG AND f_RELEASE )
		message(FATAL_ERROR "DEBUG and RELEASE flags are mutually exclusive")
	endif()
	if ( f_DEBUG )
		set(build_type_release NO)
	elseif ( f_RELEASE )
		set(build_type_release YES)
	else()
		if ( "${CMAKE_BUILD_TYPE}" STREQUAL "Debug" )
			set(build_type_release NO)
		elseif ( "${CMAKE_BUILD_TYPE}" STREQUAL "Release" )
			set(build_type_release YES)
		else()
			set(build_type_release YES)
		endif()
	endif()

	# targets
	add_custom_target(${TARGET})

	set(share_target ${TARGET}_Share)
	set(output_args)
	if ( f_OUTPUT )
		set(output_args OUTPUT ${f_OUTPUT})
	endif()
	set(depends_args)
	if ( f_DEPENDS )
		set(depends_args DEPENDS ${f_DEPENDS})
	endif()
	flat_add_sync_target(${share_target} "${f_DIR}" ${output_args} ${depends_args})
	add_dependencies(${TARGET} ${share_target})

	# Qt5
	if ( f_QMAKE )
		set(qmake_location "${f_QMAKE}")
	else()
		find_package(Qt5 REQUIRED Core)
		get_target_property(qmake_location Qt5::qmake IMPORTED_LOCATION)
	endif()

	execute_process(COMMAND "${qmake_location}" "-query" "QMAKE_XSPEC" OUTPUT_VARIABLE qt5_xspec)
	string(FIND "${qt5_xspec}" "-" qt5_xspec_platform_end_pos)
	string(SUBSTRING "${qt5_xspec}" 0 ${qt5_xspec_platform_end_pos} qt5_os)

	if ( "${qt5_os}" STREQUAL "linux" )
		set(qt5_system "Linux")
	elseif ( "${qt5_os}" STREQUAL "android" )
		set(qt5_system "Android")
	elseif ( "${qt5_os}" STREQUAL "win32" )
		set(qt5_system "Windows")
	elseif ( "${qt5_os}" STREQUAL "qnx" )
		set(qt5_system "QNX")
	elseif ( "${qt5_os}" STREQUAL "macx" )
		set(qt5_system "Darwin")
	else()
		message(FATAL_ERROR "Unsupported xspec: ${qt5_xspec}")
	endif()

	if ( "${qt5_system}" STREQUAL "Windows" AND f_RUNTIME_DIR )
		set(runtime_target ${TARGET}_Runtime)
		flat_add_sync_target(${runtime_target} "${f_RUNTIME_DIR}")
		set(runtime_dir "")
		add_dependencies(${TARGET} ${runtime_target})
	else()
		set(runtime_target ${TARGET}_Share)
		if ( f_LIB_DIR )
			set(runtime_dir "${f_LIB_DIR}")
		else()
			set(runtime_dir "lib")
		endif()
	endif()

	if ( "${runtime_dir}" STREQUAL "" )
		set(runtime_destination "")
	else()
		set(runtime_destination "${runtime_dir}/")
	endif()

	if ( "${qt5_system}" STREQUAL "Windows" )
		set(qt_libexec_var QT_INSTALL_LIBEXECS)
	else()
		set(qt_libexec_var QT_INSTALL_LIBS)
	endif()
	execute_process(COMMAND "${qmake_location}" "-query" "${qt_libexec_var}"
			OUTPUT_VARIABLE qt5_libexecs_dir)
	execute_process(COMMAND "${qmake_location}" "-query" "QT_INSTALL_LIBS"
			OUTPUT_VARIABLE qt5_libs_dir)
	execute_process(COMMAND "${qmake_location}" "-query" "QT_INSTALL_PLUGINS"
			OUTPUT_VARIABLE qt5_plugins_dir)
	execute_process(COMMAND "${qmake_location}" "-query" "QT_INSTALL_QML"
			OUTPUT_VARIABLE qt5_qml_dir)
	string(STRIP "${qt5_libexecs_dir}" qt5_libexecs_dir)
	string(STRIP "${qt5_libs_dir}" qt5_libs_dir)
	string(STRIP "${qt5_plugins_dir}" qt5_plugins_dir)
	string(STRIP "${qt5_qml_dir}" qt5_qml_dir)

	if ( "${qt5_system}" STREQUAL "Windows" AND NOT "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows" )
		# cross building with MinGW
		execute_process(COMMAND "${CMAKE_CXX_COMPILER}" "-dumpmachine"
				OUTPUT_VARIABLE compiler_machine)
		string(STRIP "${compiler_machine}" compiler_machine)
	endif()

	if ( NOT EXISTS "${qt5_libexecs_dir}" )
		message(FATAL_ERROR "Cannot find Qt5 runtime libraries")
	endif()

	if ( NOT EXISTS "${qt5_plugins_dir}" )
		message(FATAL_ERROR "Cannot find Qt5 plugins")
	endif()

	if ( f_QML AND NOT EXISTS "${qt5_qml_dir}" )
		message(FATAL_ERROR "Cannot find Qt5 qml")
	endif()

	set(platforms)
	set(runtime_libs)

	if ( "${qt5_system}" STREQUAL "Windows" )
		set(lib_suffix ".dll")
		set(qt5_lib_suffix "${lib_suffix}")
		set(lib_prefix "")
		if ( NOT f_PLATFORMS )
			set(f_PLATFORMS qwindows)
		endif()

		if ( "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows" )
			if ( NOT "${Qt5_VERSION}" VERSION_LESS "5.5.0" )
				set(icu_version "54")
			elseif ( NOT "${Qt5_VERSION}" VERSION_LESS "5.4.0" )
				set(icu_version "53")
			else()
				set(icu_version "52")
			endif()
			foreach ( lib "icuuc${icu_version}" "icuin${icu_version}" "icudt${icu_version}"
						"libgcc_s_dw2-1" "libwinpthread-1" "libstdc++-6" )
				list(APPEND runtime_libs "${qt5_libexecs_dir}/${lib}.dll")
			endforeach()
		else()
			foreach ( lib "libgcc_s_sjlj-1" "libwinpthread-1" "libstdc++-6" )
				list(APPEND runtime_libs "/usr/${compiler_machine}/sys-root/mingw/bin/${lib}.dll")
			endforeach()
		endif()
		set(qt5_debug_suffix "d")
	elseif ( "${qt5_system}" STREQUAL "Darwin" )
		set(lib_suffix ".dylib")
		set(qt5_lib_suffix ".5${lib_suffix}")
		set(lib_prefix "lib")
		if ( NOT f_PLATFORMS )
			set(f_PLATFORMS qcocoa)
		endif()
		set(qt5_debug_suffix "_debug")
	elseif ( "${qt5_system}" STREQUAL "QNX" )
		set(lib_suffix ".so")
		set(qt5_lib_suffix "${lib_suffix}.5")
		set(lib_prefix "lib")
		if ( NOT "${f_QNX_TARGET}" STREQUAL "" )
			set(qnx_target "${f_QNX_TARGET}")
		else()
			set(qnx_target "${QNX_ENV_QNX_TARGET}")
		endif()
		foreach ( runtime_lib ${f_SYSTEM_LIBS} )
			set(runtime_lib_found NO)
			foreach ( runtime_subdir "lib" "usr/lib" )
				set(runtime_lib_path "${qnx_target}/armle-v7/${runtime_subdir}/${runtime_lib}")
				if ( EXISTS "${runtime_lib_path}")
					list(APPEND runtime_libs "${runtime_lib_path}")
					set(runtime_lib_found YES)
					break()
				endif()
			endforeach()
			if ( NOT runtime_lib_found )
				message(FATAL_ERROR "Cannot find runtime library: ${runtime_lib}")
			endif()
		endforeach()
		if ( NOT f_PLATFORMS )
			set(f_PLATFORMS qqnx)
		endif()
		set(qt5_debug_suffix "d")
	elseif ( "${qt5_system}" STREQUAL "Android" )
		set(lib_suffix ".so")
		set(qt5_lib_suffix "${lib_suffix}")
		set(lib_prefix "lib")
		if ( NOT f_PLATFORMS )
			set(f_PLATFORMS android/qtforandroid)
		endif()
		set(qt5_debug_suffix "d")
		find_library(cpp_runtime_library "gnustl_shared")
		if ( NOT cpp_runtime_library )
			message(FATAL_ERROR "Failed to find libgnustl_shared.so")
		endif()
		set(runtime_libs "${cpp_runtime_library}")
	else()
		set(lib_suffix ".so")
		set(qt5_lib_suffix "${lib_suffix}.5")
		set(lib_prefix "lib")
		if ( NOT f_PLATFORMS )
			set(f_PLATFORMS qxcb)
		endif()
		set(qt5_debug_suffix "d")
	endif()

	if ( build_type_release )
		set(build_type_suffix "")
		set(exclude_build_type_suffix "${qt5_debug_suffix}")
	else()
		set(build_type_suffix "${qt5_debug_suffix}")
		set(exclude_build_type_suffix "")
	endif()

	# plugins
	set(plugins ${f_PLUGINS})
	foreach ( platform ${f_PLATFORMS} )
		list(APPEND plugins "platforms:${platform}")
	endforeach()

	# runtime libs
	foreach ( runtime_lib ${runtime_libs} )
		flat_sync(${runtime_target} "${runtime_lib}"
				COPY_SYMLINKS DESTINATION "${runtime_destination}")
	endforeach()

	# Qt5 libs
	foreach ( module ${f_MODULES} )
		flat_sync(${runtime_target}
				"${qt5_libexecs_dir}/${lib_prefix}Qt5${module}${build_type_suffix}${qt5_lib_suffix}"
				COPY_SYMLINKS DESTINATION "${runtime_destination}")
	endforeach()

	# Qt5 plugins
	foreach ( plugin ${plugins} )
		string(REPLACE ":" ";" plugin_tuple "${plugin}")
		list(GET plugin_tuple 0 plugin_directory)
		list(GET plugin_tuple 1 plugin_path)
		get_filename_component(plugin_subdir "${plugin_path}" DIRECTORY)
		get_filename_component(plugin_name "${plugin_path}" NAME)
		if ( plugin_subdir )
			set(plugin_subdir "${plugin_subdir}/")
		endif()
		flat_sync(${share_target}
				"${qt5_plugins_dir}/${plugin_directory}/${plugin_subdir}${lib_prefix}${plugin_name}${build_type_suffix}${lib_suffix}"
				COPY_SYMLINKS DESTINATION "plugins/${plugin_directory}/${plugin_subdir}")
	endforeach()

	# qml
	function(_flat_find_qml_plugins QML_DIR PLUGINS_VAR)
		set(plugins)
		if ( NOT EXISTS "${QML_DIR}/qmldir" )
			message(FATAL_ERROR "QML module not exists at: ${QML_DIR}")
		endif()
		file(GLOB_RECURSE dirs RELATIVE "${QML_DIR}" "${QML_DIR}/*/qmldir")
		foreach ( dir "qmldir" ${dirs} )
			file(STRINGS "${QML_DIR}/${dir}" lines)
			foreach ( line ${lines} )
				string(FIND "${line}" " " line_space_pos)
				string(SUBSTRING "${line}" 0 ${line_space_pos} key)
				if ( "${key}" STREQUAL "plugin" )
					string(SUBSTRING "${line}" ${line_space_pos} -1 plugin)
					string(STRIP "${plugin}" plugin)
					get_filename_component(plugin_dir "${dir}" DIRECTORY)
					list(APPEND plugins "${plugin_dir}:${plugin}")
					break()
				endif()
			endforeach()
		endforeach()
		set(${PLUGINS_VAR} "${plugins}" PARENT_SCOPE)
	endfunction()

	foreach ( qml ${f_QML} )
		_flat_find_qml_plugins("${qt5_qml_dir}/${qml}" plugins)
		set(excludes)
		foreach ( plugin ${plugins} )
			string(REPLACE ":" ";" plugin_tuple "${plugin}")
			list(GET plugin_tuple 0 plugin_dir)
			list(GET plugin_tuple 1 plugin_name)
			if ( "${plugin_dir}" STREQUAL "" )
				set(exclude_prefix "")
			else()
				set(exclude_prefix "${plugin_dir}/")
			endif()
			list(APPEND excludes "${exclude_prefix}${lib_prefix}${plugin_name}${exclude_build_type_suffix}${lib_suffix}")
			if ( ANDROID AND f_QML_PLUGINS_DIR )
				set(qml_plugin_path "${exclude_prefix}${lib_prefix}${plugin_name}${build_type_suffix}${lib_suffix}")
				list(APPEND excludes "${qml_plugin_path}")
				flat_sync(${share_target} "${qt5_qml_dir}/${qml}/${qml_plugin_path}"
					DESTINATION "${f_QML_PLUGINS_DIR}/${qml}/${qml_plugin_path}")
			endif()
		endforeach()
		flat_sync(${share_target} "${qt5_qml_dir}/${qml}/" DESTINATION "qml/${qml}/" EXCLUDE ${excludes})
	endforeach()

	if ( "${f_FONTS}" STREQUAL "ALL" )
		if ( EXISTS "${qt5_libs_dir}/fonts" )
			flat_sync("${share_target}" "${qt5_libs_dir}/fonts/" DESTINATION "lib/fonts/")
		endif()
	endif()
endfunction()


# Save environment variables into cache in form ENV_${varname}.
# Cached values will be initialized ONLY once with initial env var values.
# Subsequent calls of flat_cache_env_vars() with same arguments will NOT
# update cached values unless they are explicitly cleared first with unset().
#
# Example:
#   flat_cache_env_vars(FOO BAR)
#
# Above command will create entries in cache:
#   ENV_FOO=$ENV{FOO}
#   ENV_BAR=$ENV{BAR}

function(flat_cache_env)
	foreach ( var ${ARGN} )
		set(force_flag)
		if ( "${ENV_${var}}" STREQUAL "" )
			set(force_flag FORCE)
		endif()
		set(ENV_${var} "$ENV{${var}}" CACHE STRING "" ${force_flag})
	endforeach()
endfunction()


# Create and save launch script FILE with specified environment.
# If script with exactly same environment already present in FILE
# then it will not be overwritten. This make possible to add FILE as
# dependency for other build commands.
#
# flat_make_launch_script() implicitly calls flat_cache_env(${ENV}).
#
# Arguments:
#   ENV   - environment variable names, values will be taken from environment
#   VARS  - environment variable name/value pairs
#   PATHS - paths to be added to PATH environment variable

function(flat_make_launch_script FILE)
	set(Python_ADDITIONAL_VERSIONS 3.5-32)
	find_package(PythonInterp 3.5 REQUIRED)

	cmake_parse_arguments(f "" "" "ENV;VARS;PATHS" ${ARGN})

	flat_cache_env(${f_ENV})

	set(env_list)

	foreach ( var ${f_ENV} )
		list(APPEND env_list "${var}=\'${ENV_${var}}\'")
	endforeach()

	list(LENGTH f_VARS vars_length)
	math(EXPR vars_mod "${vars_length}%2")
	if ( NOT ${vars_mod} EQUAL 0 )
		message(FATAL_ERROR "VARS count should be even")
	endif()
	math(EXPR vars_count "${vars_length}/2")
	set(var_i 0)
	while ( ${var_i} LESS ${vars_count} )
		math(EXPR var_key_i "${var_i}*2")
		math(EXPR var_value_i "${var_key_i} + 1")
		math(EXPR var_i "${var_i} + 1")
		list(GET f_VARS ${var_key_i} var_key)
		list(GET f_VARS ${var_value_i} var_value)
		list(APPEND env_list "${var_key}=\'${var_value}\'")
	endwhile()

	set(paths ${f_PATHS})
	if ( paths )
		list(SORT paths)
	endif()
	set(PATH_LIST)
	foreach ( path ${paths} )
		if ( NOT "${PATH_LIST}" STREQUAL "" )
			set(PATH_LIST "${PATH_LIST}, ")
		endif()
		set(PATH_LIST "${PATH_LIST}\'${path}\'")
	endforeach()

	if ( env_list )
		list(SORT env_list)
	endif()
	set(ENV_LIST)
	foreach ( env ${env_list} )
		if ( NOT "${ENV_LIST}" STREQUAL "" )
			set(ENV_LIST "${ENV_LIST}, ")
		endif()
		set(ENV_LIST "${ENV_LIST}${env}")
	endforeach()

	if ( "${CMAKE_HOST_SYSTEM_NAME}" STREQUAL "Windows" )
		set(PATH_SEP ";")
		set(TO_NATIVE_SEPARATORS_COMMAND "paths = [x.replace('/', '\\') for x in paths]")
	else()
		set(PATH_SEP ":")
		set(TO_NATIVE_SEPARATORS_COMMAND "pass")
	endif()

	configure_file("${Flat_RunWithEnvScriptIn}" "${FILE}.orig" @ONLY)
	execute_process(COMMAND ${CMAKE_COMMAND} -E copy_if_different "${FILE}.orig" "${FILE}")
	execute_process(COMMAND ${CMAKE_COMMAND} -E remove "${FILE}.orig")
endfunction()


# Create target to check whether git repository revision has been updated.
#
# Arguments:
#   TARGET       - phony target name
#   OUTPUT       - output to be touched when git repository content changed,
#                  this is a byproduct of TARGET
#   NO_CHANGES   - ignore all local changes, look at HEAD^{tree} only
#   NO_UNTRACKED - respect changes in modified files, but ignore untracked files

function(flat_check_git TARGET OUTPUT GIT)
	cmake_parse_arguments(f "NO_CHANGES;NO_UNTRACKED" "" "" ${ARGN})

	if (f_NO_CHANGES)
		set(dirty_args "--no-dirty")
	else()
		set(dirty_args)
	endif()

	if (f_NO_UNTRACKED)
		set(untracked_args "--no-untracked")
	else()
		set(untracked_args)
	endif()

	add_custom_target(${TARGET}
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_GenerateGitTreeScript}"
			"--git-dir=${GIT}"
			"--output=${OUTPUT}.tree"
			${dirty_args}
			${untracked_args}
		COMMAND ${CMAKE_COMMAND} -E copy_if_different
			"${OUTPUT}.tree" "${OUTPUT}"
		BYPRODUCTS "${OUTPUT}"
		DEPENDS "${Flat_GenerateGitTreeScript}"
	)
endfunction()


function(flat_collect_args VAR PATTERN)
	cmake_parse_arguments(f "" "COUNT" "" ${ARGN})

	if ( "${f_COUNT}" STREQUAL "" )
		set(count 2)
	else()
		set(count ${f_COUNT})
	endif()

	set(args ${f_UNPARSED_ARGUMENTS})
	list(LENGTH args args_length)
	math(EXPR args_mod "${args_length}%${count}")
	if ( NOT ${args_mod} EQUAL 0 )
		message(FATAL_ERROR "Argument count should be even: ${args_length} ${args}")
	endif()
	math(EXPR args_count "${args_length}/${count}")

	set(vars)
	set(var "${PATTERN}")
	set(i 0)
	foreach ( arg ${args} )
		math(EXPR i "${i} + 1")
		string(REPLACE "@${i}@" "${arg}" var "${var}")
		if ( ${i} EQUAL ${count} )
			list(APPEND vars "${var}")
			set(var "${PATTERN}")
			set(i 0)
		endif()
	endforeach()
	
	set(${VAR} "${vars}" PARENT_SCOPE)
endfunction()


# Create rule to configure external CMake project.
#
# Arguments:
#   SOURCE_DIR     - path to sources directory with CMakeLists.txt
#   BUILD_DIR      - path to build dir in which to configure and build project
#   GENERATOR      - generator to use, default: ${CMAKE_GENERATOR}
#   ENV            - environment variables with which to configure the project
#   ENV_PATHS      - paths to add to PATH environment variable when configuring the project
#   ARGS           - CMake variables for configuring the project
#   GIT_DIRS       - git dirs to check revision update from, when any git dir is changed then
#                    invoke the build again and touch the BUILD_TARGET_FILE
#   DEPENDS        - dependencies to trigger reconfiguration
#   CLEAN_DEPENDS  - dependencies to trigger full clean build
#   ADD_OE_QMAKE_PATH_EXTERNAL_HOST_BINS -

function(flat_configure_cmake_project TARGET)
	set(Python_ADDITIONAL_VERSIONS 3.5-32)
	find_package(PythonInterp 3.5 REQUIRED)

	cmake_parse_arguments(f "" "SOURCE_DIR;BUILD_DIR;GENERATOR;MAKE"
			"ENV;ENV_PATHS;ARGS;GIT_DIRS;DEPENDS;CLEAN_DEPENDS" ${ARGN})

	# vars
	set(build_dir "${f_BUILD_DIR}")
	set(cmake_build_dir "${build_dir}/build")
	set(reconfigure_target "${build_dir}/reconfigure")
	set(build_dir_target "${build_dir}/build-dir")

	# launch
	set(run_script "${build_dir}/run.py")

	flat_make_launch_script("${run_script}"
		VARS ${f_ENV}
		PATHS ${f_ENV_PATHS}
	)

	# args
	flat_collect_args(args "-D@1@=@2@" ${f_ARGS})

	if ( f_GENERATOR )
		set(generator "${f_GENERATOR}")
	else()
		set(generator "${CMAKE_GENERATOR}")
	endif()
	
	set(build_make "${CMAKE_MAKE_PROGRAM}")

	# generator
	if ( "${generator}" STREQUAL "Ninja" )
		set(build_file_name "build.ninja")
		set(build_make "ninja")
	elseif ( "${generator}" STREQUAL "Unix Makefiles" )
		set(build_file_name "Makefile")
		set(build_make "make")
	elseif ( "${generator}" STREQUAL "MinGW Makefiles" )
		set(build_file_name "Makefile")
		set(build_make "mingw32-make")
	else()
		message(FATAL_ERROR "Unsupported generator: ${generator}")
	endif()

	set(build_file "${cmake_build_dir}/${build_file_name}")

	if ( f_MAKE )
		set(build_make "${f_MAKE}")
	endif()

	# git
	set(git_targets)
	set(git_files)
	set(git_dir_keys)

	foreach ( git_dir ${f_GIT_DIRS} )
		# generate unique target name
		get_filename_component(git_dir_name "${git_dir}" NAME)
		get_filename_component(git_dir_path "${git_dir}" DIRECTORY)
		get_filename_component(git_dir_name2 "${git_dir_path}" NAME)
		set(git_dir_suffix)
		while ( TRUE )
			set(git_dir_key "${git_dir_name2}_${git_dir_name}")
			if ( git_dir_suffix )
				set(git_dir_key "${git_dir_key}_${git_dir_suffix}")
			endif()
			list(FIND git_dir_keys "${git_dir_key}" git_dir_key_index)
			if ( ${git_dir_key_index} EQUAL -1 )
				break()
			endif()
			if ( NOT git_dir_suffix )
				set(git_dir_suffix "2")
			else()
				math(EXPR git_dir_suffix "${git_dir_suffix} + 1")
			endif()
		endwhile()

		set(git_target ${TARGET}_Git_${git_dir_key})
		set(git_file "${build_dir}/git-${git_dir_key}")

		flat_check_git(${git_target} "${git_file}" "${git_dir}")

		list(APPEND git_targets ${git_target})
		list(APPEND git_files "${git_file}")
	endforeach()

	# rule to create build dir
	add_custom_command(
		OUTPUT "${build_dir_target}"
		COMMAND ${CMAKE_COMMAND} -E make_directory "${cmake_build_dir}"
		COMMAND ${CMAKE_COMMAND} -E touch "${build_dir_target}"
	)

	# rule to configure project
	if (f_ADD_OE_QMAKE_PATH_EXTERNAL_HOST_BINS)
		set(oe_args -D "OE_QMAKE_PATH_EXTERNAL_HOST_BINS=${OE_QMAKE_PATH_EXTERNAL_HOST_BINS}")
	else()
		set(oe_args)
	endif()

	add_custom_command(
		OUTPUT "${build_file}"
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_EraseCurrentDirScript}"
		COMMAND "${PYTHON_EXECUTABLE}" "${run_script}" ${CMAKE_COMMAND}
			-G "${generator}"
			-D "CMAKE_MAKE_PROGRAM=${build_make}"
			-D "PYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}"
			${or_args}
			${args}
			"${f_SOURCE_DIR}"
		WORKING_DIRECTORY "${cmake_build_dir}"
		DEPENDS "${build_dir_target}" "${run_script}" ${f_CLEAN_DEPENDS}
	)

	add_custom_command(
		OUTPUT "${reconfigure_target}"
		COMMAND "${PYTHON_EXECUTABLE}" "${run_script}" "${PYTHON_EXECUTABLE}"
			"${Flat_ReconfigureCMakeScript}" "${cmake_build_dir}" "${build_file_name}"
			"${reconfigure_target}" --cmake "${CMAKE_COMMAND}" --deps ${f_DEPENDS}
		DEPENDS "${build_file}" ${f_DEPENDS}
	)

	add_custom_target(${TARGET})

	set_target_properties(${TARGET} PROPERTIES
		GIT_TARGETS "${git_targets}"
		GIT_FILES "${git_files}"
		MAKE "${build_make}"
		BUILD_DIR "${build_dir}"
		CMAKE_BUILD_DIR "${cmake_build_dir}"
		RECONFIGURE_TARGET_FILE "${reconfigure_target}"
	)
endfunction()


# Create rule to build previously configured CMake project.
#
# Arguments:
#   JOBS           - make job count when invoking build command
#   OUTPUTS        - make target output files
#   TARGETS        - targets to build
#   DEPENDS        - additional file dependencies

function (flat_build_cmake_project TARGET CONFIGURE_TARGET)
	cmake_parse_arguments(f "" "JOBS" "TARGETS;OUTPUTS;DEPENDS" ${ARGN})

	get_target_property(build_make ${CONFIGURE_TARGET} MAKE)
	set(make_opts)
	get_filename_component(make_filename "${build_make}" NAME)
	if ( "${make_filename}" STREQUAL "emake" )
		set(make_opts "SHELL=")
	endif()

	set(make_jobs)
	if ( f_JOBS )
		set(make_jobs -j${f_JOBS})
	endif()

	get_target_property(build_dir ${CONFIGURE_TARGET} BUILD_DIR)
	get_target_property(cmake_build_dir ${CONFIGURE_TARGET} CMAKE_BUILD_DIR)
	get_target_property(git_targets ${CONFIGURE_TARGET} GIT_TARGETS)
	get_target_property(git_files ${CONFIGURE_TARGET} GIT_FILES)
	get_target_property(reconfigure_target ${CONFIGURE_TARGET} RECONFIGURE_TARGET_FILE)
	set(build_target_file "${build_dir}/target-${TARGET}")

	# rule to build project
	if ( git_targets )
		add_custom_command(
			OUTPUT "${build_target_file}"
			COMMAND ${build_make} ${make_opts} ${make_jobs} ${f_TARGETS}
			COMMAND ${CMAKE_COMMAND} -E touch "${build_target_file}"
			BYPRODUCTS ${f_OUTPUTS}
			WORKING_DIRECTORY "${cmake_build_dir}"
			DEPENDS "${reconfigure_target}" ${git_files} ${f_DEPENDS}
		)

		add_custom_target(${TARGET}
			DEPENDS "${build_target_file}" ${git_targets}
		)
	else()
		add_custom_target(${TARGET}
			COMMAND ${build_make} ${make_opts} ${make_jobs} ${f_TARGETS}
			BYPRODUCTS ${f_OUTPUTS}
			WORKING_DIRECTORY "${cmake_build_dir}"
			DEPENDS "${reconfigure_target}" ${f_DEPENDS}
		)
	endif()
endfunction()


function(flat_collect_files TARGET OUTPUT)
	cmake_parse_arguments(f "DEPEND_ON_FILES" "RELATIVE" "PREPEND_DIR" ${ARGN})

	set(args)
	if (f_DEPEND_ON_FILES)
		list(APPEND args --depend-on-files)
	endif()
	if (f_RELATIVE)
		list(APPEND args "--relative=${f_RELATIVE}")
	endif()
	if (f_PREPEND_DIR)
		list(APPEND args --prepend-dir)
	endif()

	add_custom_target(${TARGET}
		COMMAND
			${PYTHON_EXECUTABLE} "${Flat_CollectFilesScript}" "${OUTPUT}" ${args} --paths ${ARGN}
		BYPRODUCTS
			"${OUTPUT}"
		DEPENDS
			"${Flat_CollectFilesScript}"
		VERBATIM
	)
endfunction()


function(flat_sync_directory_files SOURCE DESTINATION DIR)
	add_custom_command(
		OUTPUT "${DESTINATION}"
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_SyncDirectoryScript}"
			"--source=${SOURCE}"
			"--destination=${DESTINATION}"
			"--dir=${DIR}"
		DEPENDS "${SOURCE}" "${Flat_SyncDirectoryScript}"
	)
endfunction()


function(flat_sync_directory TARGET OUTPUT SOURCE_DIR DESTINATION_DIR)
	flat_collect_files(${TARGET}_CollectFiles "${OUTPUT}-collect-files"
		RELATIVE "${SOURCE_DIR}" PREPEND_DIR
		${ARGN}
	)

	flat_sync_directory_files("${OUTPUT}-collect-files" "${OUTPUT}" "${DESTINATION_DIR}")

	add_custom_target(${TARGET} DEPENDS "${OUTPUT}")
	add_dependencies(${TARGET} ${TARGET}_CollectFiles)
endfunction()


function(flat_add_qmldir_loader QMLDIR_FILE PREFIX LOADER_VAR)
	cmake_parse_arguments(f "" "" "INCLUDE;EXCLUDE" ${ARGN})

	file(RELATIVE_PATH loader_file "${CMAKE_CURRENT_SOURCE_DIR}" "${QMLDIR_FILE}")
	string(REPLACE ":" "_" loader_file "${loader_file}")
	string(REPLACE ".." "__" loader_file "${loader_file}")
	set(loader_file "${CMAKE_CURRENT_BINARY_DIR}/${loader_file}.cpp")
	get_filename_component(loader_file_dir "${loader_file}" DIRECTORY)

	add_custom_command(
		OUTPUT "${loader_file}"
		COMMAND ${CMAKE_COMMAND} -E make_directory "${loader_file_dir}"
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_GenerateQmldirLoaderScript}"
			--prefix "${PREFIX}"
			--qmldir "${QMLDIR_FILE}"
			--loader "${loader_file}"
			--include ${f_INCLUDE}
			--exclude ${f_EXCLUDE}
		DEPENDS
			"${Flat_GenerateQmldirLoaderScript}"
			"${QMLDIR_FILE}"
		VERBATIM
	)

	set(${LOADER_VAR} "${loader_file}" PARENT_SCOPE)
endfunction()


function(flat_generate_qrc TARGET PATH PREFIX QRC_FILE_VAR)
	set(files_file "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_files")
	set(qrc_file "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.qrc")

	flat_collect_files(${TARGET} "${files_file}" DEPEND_ON_FILES ${ARGN})

	add_custom_command(
		OUTPUT "${qrc_file}"
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_GenerateQrcScript}"
			"${qrc_file}" "${files_file}" "${PATH}" "${PREFIX}"
		DEPENDS "${files_file}" "${Flat_GenerateQrcScript}"
		VERBATIM
	)

	add_custom_target(${TARGET}_qrc DEPENDS "${qrc_file}")
	add_dependencies(${TARGET}_qrc ${TARGET})

	set(${QRC_FILE_VAR} "${qrc_file}" PARENT_SCOPE)
endfunction()


function(flat_add_qrc TARGET CPP_FILE_VAR PATH PREFIX)
	cmake_parse_arguments(f "" "QRC_FILE_VAR" "" ${ARGN})

	flat_generate_qrc(${TARGET} "${PATH}" "${PREFIX}" qrc_file ${f_UNPARSED_ARGUMENTS})

	set(cpp_file "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}.cpp")

	add_custom_command(
		OUTPUT ${cpp_file}
		COMMAND ${Qt5Core_RCC_EXECUTABLE} --name ${TARGET} --output ${cpp_file} ${qrc_file}
		DEPENDS "${qrc_file}"
		VERBATIM
	)

	set(${CPP_FILE_VAR} "${cpp_file}" PARENT_SCOPE)

	if (f_QRC_FILE_VAR)
		set(${f_QRC_FILE_VAR} "${qrc_file}" PARENT_SCOPE)
	endif()
endfunction()


function(_flat_get_target_output_directories TARGET INTERFACE_DIRECTORY RUNTIME_DIRECTORY)
	get_target_property(target_type ${TARGET} TYPE)

	if ("${target_type}" STREQUAL STATIC_LIBRARY)
		get_target_property(target_interface_output_dir ${TARGET} ARCHIVE_OUTPUT_DIRECTORY)
		if (NOT target_interface_output_dir)
			set(target_interface_output_dir "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
		endif()

		set(${INTERFACE_DIRECTORY} "${target_interface_output_dir}" PARENT_SCOPE)
		set(${RUNTIME_DIRECTORY} "" PARENT_SCOPE)
	elseif ("${target_type}" STREQUAL SHARED_LIBRARY OR "${target_type}" STREQUAL EXECUTABLE)
		if ( WN32)
			get_target_property(target_runtime_output_dir ${TARGET} RUNTIME_OUTPUT_DIRECTORY)
			if (NOT target_runtime_output_dir)
				set(target_runtime_output_dir "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
			endif()
			if (NOT target_runtime_output_dir)
				set(target_runtime_output_dir "${CMAKE_CURRENT_BINARY_DIR}")
			endif()

			get_target_property(target_interface_output_dir ${TARGET} ARCHIVE_OUTPUT_DIRECTORY)
			if (NOT target_interface_output_dir)
				set(target_interface_output_dir "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
			endif()
			if (NOT target_interface_output_dir)
				set(target_interface_output_dir "${CMAKE_CURRENT_BINARY_DIR}")
			endif()
		else ()
			get_target_property(target_runtime_output_dir ${TARGET} LIBRARY_OUTPUT_DIRECTORY)
			if (NOT target_runtime_output_dir)
				set(target_runtime_output_dir "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
			endif()

			set(target_interface_output_dir "${target_runtime_output_dir}")
		endif()

		set(${INTERFACE_DIRECTORY} "${target_interface_output_dir}" PARENT_SCOPE)
		set(${RUNTIME_DIRECTORY} "${target_runtime_output_dir}" PARENT_SCOPE)
	else()
		message(FATAL_ERROR "Resolving output directories allowed only for static, shared libraries and executables")
	endif()
endfunction()


# Add precompiled headers support to the target.
#
# Usage:
#   flat_precompile_headers(TARGET PRECOMPILED_HEADER [source1 source2 ...])
#
# Arguments:
#   TARGET             - target to add precompiled headers support to
#   PRECOMPILED_HEADER - path to header to precompile
#
# Example:
#   add_executable(myapp ...)
#   flat_precompile_headers(myapp precompiled_headers.h)

function(flat_precompile_headers TARGET PRECOMPILED_HEADER)
	if (CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
		# FIXME: Implement PCH for MSVC
		return()
	endif()

	if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
		set(is_clang YES)
	else()
		set(is_clang NO)
	endif()

	set(extra_flags)

	# build type as suffix to cmake variables
	string(TOUPPER "${CMAKE_BUILD_TYPE}" build_type)
	# build type flags
	if (CMAKE_CXX_FLAGS)
		set(extra_flags_separated ${CMAKE_CXX_FLAGS})
		separate_arguments(extra_flags_separated)
		list(APPEND extra_flags ${extra_flags_separated})
	endif()
	if (build_type AND CMAKE_CXX_FLAGS_${build_type})
		set(extra_flags_separated ${CMAKE_CXX_FLAGS_${build_type}})
		separate_arguments(extra_flags_separated)
		list(APPEND extra_flags ${extra_flags_separated})
	endif()

	get_filename_component(pch_name "${PRECOMPILED_HEADER}" NAME)
	get_filename_component(pch_file "${PRECOMPILED_HEADER}" ABSOLUTE)

	# file names
	get_filename_component(pch_file_dir "${CMAKE_CURRENT_BINARY_DIR}/${TARGET}_pch" ABSOLUTE)

	if (MSVC OR is_clang)
		set(pch_output_dir "${pch_file_dir}")
		set(pch_include "${pch_output_dir}/precompiled.pch")
		set(pch_file_path "${pch_include}")
	endif()
	if (CMAKE_COMPILER_IS_GNUCXX)
		set(pch_output_dir "${pch_file_dir}")
		set(pch_include "${pch_name}")
		set(pch_file_path "${pch_output_dir}/${pch_include}.gch")
		file(GENERATE OUTPUT "${pch_output_dir}/${pch_include}"
				CONTENT "#error \"PCH is not used\"\n")
	endif()

	set(pch_flags_file "${pch_file_dir}/flags")
	set(pch_deps_file "${pch_file_dir}/deps")
	set(pch_deps_target "${pch_file_dir}/deps.target")

	# MSVC requires additional object file
	if (MSVC)
		set(pch_object_file_path "${pch_file_dir}/precompiled.obj")
	endif()

	if (APPLE)
		# add min deployment version
		if (CMAKE_OSX_DEPLOYMENT_TARGET)
			list(APPEND extra_flags -mmacosx-version-min=${CMAKE_OSX_DEPLOYMENT_TARGET})
		endif()

		# add architectures
		get_target_property(archs ${TARGET} OSX_ARCHITECTURES)
		foreach (arch ${_archs})
			list(APPEND extra_flags -arch ${arch})
		endforeach()

		# add sysroot
		if (CMAKE_OSX_SYSROOT)
			list(APPEND extra_flags -isysroot "${CMAKE_OSX_SYSROOT}")
		endif()
	endif()

	# generate precompiled header
	if (MSVC)
		#HACK: Don't know how to obtain target's pdb file.
		get_target_property(target_location ${TARGET} ${build_type}_LOCATION)
		get_filename_component(target_filename "${target_location}" NAME)
		get_filename_component(target_filename_we "${target_filename}" NAME_WE)

		_flat_get_target_output_directories(${TARGET} interface_directory runtime_directory)

		get_target_property(target_type ${TARGET} TYPE)
		if (target_type STREQUAL EXECUTABLE)
			set(target_pdb_directory "${runtime_directory}")
		elseif (target_type STREQUAL STATIC_LIBRARY)
			set(target_pdb_directory "${interface_directory}")
		else()
			set(target_pdb_directory "${runtime_directory}")
		endif()

		set(target_pdb "${target_pdb_directory}/${target_filename_we}.pdb")

		#TODO: Use VERBATIM?
#		add_custom_command(
#			OUTPUT "${pch_object_file_path}"
#			COMMAND "${CMAKE_COMMAND}" -E remove -f "${pch_object_file_path}"
#			COMMAND "${CMAKE_COMMAND}" -E remove -f "${target_pdb}"
#			COMMAND "${CMAKE_COMMAND}" -E remove -f "${pch_file_path}"
#			COMMAND "${CMAKE_COMMAND}" -E make_directory "${pch_file_dir}"
#			COMMAND "${CMAKE_CXX_COMPILER}" ${include_flags} ${compile_flags} ${definition_flags}
#				${extra_flags} -c /Yc /Fp${pch_file_path} /Fo${pch_object_file_path}
#				/Fd${target_pdb} /TP "${ph_absolute_path}"
#			IMPLICIT_DEPENDS CXX "${pch_absolute_path}"
#			VERBATIM
#		)
#		target_link_libraries( ${TARGET} "${_pch_object_file_path}" )
	elseif (CMAKE_COMPILER_IS_GNUCXX OR is_clang)
		add_custom_target(${TARGET}_CheckPchDeps
			COMMAND "${CMAKE_COMMAND}" -E make_directory "${pch_output_dir}"
			COMMAND "${PYTHON_EXECUTABLE}" "${Flat_CheckPchDepsScript}"
				"--deps=${pch_deps_file}"
				"--pch=${pch_file}"
				"--target=${pch_deps_target}"
			BYPRODUCTS "${pch_deps_target}"
			DEPENDS "${pch_file}" "${Flat_CheckPchDepsScript}"
			VERBATIM
		)
		add_dependencies(${TARGET} ${TARGET}_CheckPchDeps)

		add_custom_command(
			OUTPUT "${pch_flags_file}"
			COMMAND "${PYTHON_EXECUTABLE}" "${Flat_GeneratePchFlagsScript}"
				"--compiler-id=${CMAKE_CXX_COMPILER_ID}"
				"--include-dirs=$<TARGET_PROPERTY:${TARGET},INCLUDE_DIRECTORIES>"
				"--compile-features=$<TARGET_PROPERTY:${TARGET},COMPILE_FEATURES>"
				"--compile-options=$<TARGET_PROPERTY:${TARGET},COMPILE_OPTIONS>"
				"--compile-flags=$<TARGET_PROPERTY:${TARGET},COMPILE_FLAGS>"
				"--compile-definitions=$<TARGET_PROPERTY:${TARGET},COMPILE_DEFINITIONS>"
				"--pic=$<BOOL:$<TARGET_PROPERTY:${TARGET},POSITION_INDEPENDENT_CODE>>"
				"--type=$<TARGET_PROPERTY:${TARGET},TYPE>"
				"--pic-flags=${CMAKE_CXX_COMPILE_OPTIONS_PIC}"
				"--pie-flags=${CMAKE_CXX_COMPILE_OPTIONS_PIE}"
				"--extra-flags=${extra_flags}"
				"--pch=${pch_file}"
				"--output=${pch_flags_file}"
			DEPENDS "${Flat_GeneratePchFlagsScript}"
			VERBATIM
		)

		add_custom_command(
			OUTPUT "${pch_deps_file}"
			COMMAND "${PYTHON_EXECUTABLE}" "${Flat_GeneratePchDepsScript}"
				"--output=${pch_deps_file}"
				"--compiler=${CMAKE_CXX_COMPILER}"
				"--flags-file=${pch_flags_file}"
				"--pch-file=${pch_file}"
				"--compile-cli=${CMAKE_CXX_COMPILE_OBJECT}"
			DEPENDS "${pch_deps_target}" "${pch_flags_file}" "${Flat_GeneratePchDepsScript}"
			VERBATIM
		)

		add_custom_command(
			OUTPUT "${pch_file_path}"
			COMMAND "${PYTHON_EXECUTABLE}" "${Flat_GeneratePchScript}"
				"--compiler=${CMAKE_CXX_COMPILER}"
				"--compiler-id=${CMAKE_CXX_COMPILER_ID}"
				"--flags-file=${pch_flags_file}"
				"--pch=${pch_file}"
				"--compile-cli=${CMAKE_CXX_COMPILE_OBJECT}"
				"--output=${pch_file_path}"
			DEPENDS "${pch_deps_file}" "${Flat_GeneratePchScript}"
			VERBATIM
		)
	endif()

	# adding global compile flags to the target
	# if no sources was given than PrecompiledHeader file will not be created,
	# so we should skip dependency
	set(cpp_sources)
	get_property(sources TARGET ${TARGET} PROPERTY SOURCES)
	foreach(source ${sources})
		if (source MATCHES "\\.\(cc|cxx|cpp|c\)$")
			list(APPEND cpp_sources "${source}")
		endif()
	endforeach()

	foreach (source_file ${cpp_sources})
		get_source_file_property(language "${source_file}" LANGUAGE)

		if (NOT language STREQUAL CXX)
			continue()
		endif()

		get_source_file_property(compile_flags "${source_file}" COMPILE_FLAGS)

		if (NOT compile_flags)
			set(compile_flags)
		endif()

		if (MSVC)
			set_source_files_properties("${source_file}" PROPERTIES
				COMPILE_FLAGS "${compile_flags} -FI${PRECOMPILED_HEADER} -Yu${PRECOMPILED_HEADER}
						-Fp${pch_file_path}"
				OBJECT_DEPENDS "${pch_object_file_path}"
			)
		elseif (CMAKE_COMPILER_IS_GNUCXX)
			set_source_files_properties("${source_file}" PROPERTIES
				COMPILE_FLAGS "${compile_flags} -Winvalid-pch -I${pch_output_dir} -include ${pch_include}"
				OBJECT_DEPENDS "${pch_file_path}"
			)
		elseif (is_clang)
			set_source_files_properties("${source_file}" PROPERTIES
				COMPILE_FLAGS "${compile_flags} -include-pch ${pch_file_path}"
				OBJECT_DEPENDS "${pch_file_path}"
			)
		endif()
	endforeach()
endfunction()


# config
function(_flat_config_exec)
	#TODO: Import existing components.
endfunction()

_flat_config_exec()


set(Flat_FOUND YES)
