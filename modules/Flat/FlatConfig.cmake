
include(CMakeParseArguments)


get_filename_component(PythonCompiler_DIR "${CMAKE_CURRENT_LIST_DIR}/../PythonCompiler" ABSOLUTE)
find_package(PythonCompiler REQUIRED)


# scripts
set(Flat_SyncScript "${CMAKE_CURRENT_LIST_DIR}/Sync.py")
set(Flat_RunWithEnvScriptIn "${CMAKE_CURRENT_LIST_DIR}/run-with-env.py.in")
set(Flat_CheckGitRevisionScript "${CMAKE_CURRENT_LIST_DIR}/check-git-revision.py")
set(Flat_EraseCurrentDirScript "${CMAKE_CURRENT_LIST_DIR}/erase-current-dir.py")


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
flat_register_source_suffixes("c;cpp;cxx" SOURCES)
flat_register_source_suffixes("ui" FORMS)
flat_register_source_suffixes("qrc" RESOURCES)


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

function(flat_add_sources)
	set(state "listing-sources")
	set(prefix)
	set(dir "${CMAKE_CURRENT_SOURCE_DIR}")
	set(abs_dir "${dir}")
	set(arg_index 0)
	set(extra_suffixes)

	foreach ( list ${_Flat_SourceLists} )
		set(list_${list})
	endforeach()

	foreach( arg ${ARGN} )
		math(EXPR arg_index "${arg_index} + 1")

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

		flat_get_file_name_and_suffix("${arg}" file_name file_suffix)

		if ( _Flat_SourceSuffixLists_${file_suffix} )
			set(suffixes "${file_suffix}")
		else()
			set(suffixes ${extra_suffixes} ${Flat_DefaultSourceSuffixes})
			set(file_name "${arg}")
		endif()

		foreach ( suffix ${suffixes} )
			set(file "${abs_dir}/${file_name}.${suffix}")
			if ( NOT EXISTS "${file}" )
				message(FATAL_ERROR "File not exists: ${file}")
			endif()
			foreach ( list ${_Flat_SourceSuffixLists_${suffix}} )
				list(APPEND list_${list} "${file}")
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
					set_property(TARGET ${TARGET} APPEND_STRING PROPERTY LINK_FLAGS " -Wl,-rpath-link,${lib_dir}")
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

	if ( f_OUTPUT )
		get_filename_component(output_directory "${f_OUTPUT}" DIRECTORY)

		add_custom_command(
			OUTPUT "${f_OUTPUT}"
			${command}
			COMMAND ${CMAKE_COMMAND} -E make_directory "${output_directory}"
			COMMAND ${CMAKE_COMMAND} -E touch "${f_OUTPUT}"
			WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
			DEPENDS ${f_DEPENDS}
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
	cmake_parse_arguments(f "DELETE" "PATH" "DEPENDS" ${ARGN})

	if ( f_DELETE )
		set(f_DELETE YES)
	else()
		set(f_DELETE NO)
	endif()

	add_custom_target(${TARGET}
		COMMAND "${PYTHON_EXECUTABLE}"
			"${Flat_SyncScript}"
			"--destination-root=${DESTINATION}"
			"--source=${SOURCE}"
			"--destination=${f_PATH}"
			"--delete=${f_DELETE}"
			"--copy-symlinks=YES"
			"--excludes=NONE"
		WORKING_DIRECTORY
			"${CMAKE_CURRENT_BINARY_DIR}"
	)

	if ( f_DEPENDS )
		add_dependencies(${TARGET} ${f_DEPENDS})
	endif()
endfunction()


function(flat_sync TARGET SOURCE)
	set(exclude_sep "!!es!!")

	if ( NOT TARGET ${TARGET} )
		message(FATAL_ERROR "Create target ${TARGET} with flat_add_sync_target() first")
	endif()

	cmake_parse_arguments(sync "DELETE;COPY_SYMLINKS" "DESTINATION" "DEPENDS;EXCLUDE" ${ARGN})

	if ( NOT sync_DESTINATION )
		set(sync_DESTINATION "ROOT")
	endif()

	if ( sync_EXCLUDE )
		set(excludes "")
		foreach ( exclude ${sync_EXCLUDE} )
			if ( NOT "${excludes}" STREQUAL "" )
				set(excludes "${excludes}${exclude_sep}")
			endif()
			set(excludes "${excludes}${exclude}")
		endforeach()
	else()
		set(excludes "NONE")
	endif()

	if ( sync_DELETE )
		set(sync_DELETE YES)
	else()
		set(sync_DELETE NO)
	endif()

	if ( sync_COPY_SYMLINKS )
		set(sync_COPY_SYMLINKS YES)
	else()
		set(sync_COPY_SYMLINKS NO)
	endif()

	set_property(TARGET ${TARGET} APPEND PROPERTY SyncSourceList "${SOURCE}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncDestinationList "${sync_DESTINATION}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncDeleteList "${sync_DELETE}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncCopySymlinksList "${sync_COPY_SYMLINKS}")
	set_property(TARGET ${TARGET} APPEND PROPERTY SyncExcludesList "${excludes}")

	if ( sync_DEPENDS )
		add_dependencies(${TARGET} ${sync_DEPENDS})
	endif()

	get_target_property(sync_list ${TARGET} SyncList)

	# check conflicting DELETE destinations
	foreach ( var ${sync_list} )
		get_target_property(sync_destination   ${TARGET} SyncDestination_${var})
		get_target_property(sync_sources       ${TARGET} SyncSources_${var})
		get_target_property(sync_depends       ${TARGET} SyncDepends_${var})
		get_target_property(sync_delete        ${TARGET} SyncDelete_${var})
		get_target_property(sync_exclude       ${TARGET} SyncExclude_${var})
		get_target_property(sync_copy_symlinks ${TARGET} SyncCopySymlinks_${var})

		set(ok YES)

		if ( sync_DELETE )
			_flat_add_sync_check_conflict(${TARGET} "${sync_DESTINATION}" "${sync_destination}" ok)
		endif()

		if ( ok )
			if ( sync_delete )
				_flat_add_sync_check_conflict(${TARGET} "${sync_destination}" "${sync_DESTINATION}" ok)
			endif()
		endif()

		if ( NOT ok )
			message("Conflicting syncs:")
			message("    ${SOURCE} - > ${sync_DESTINATION} (delete=${sync_DELETE})")
			message("    ${sync_sources} -> ${sync_destination} (delete=${sync_delete})")
			message(FATAL_ERROR "Fix sync conclicts above")
		endif()
	endforeach()

	string(REPLACE ":" "_colon_" var "${sync_DESTINATION}")
	string(REPLACE "/" "_" var "${var}")
	string(REPLACE "\\" "_" var "${var}")

	if ( "${var}" STREQUAL "" )
		set(var "ROOT")
	endif()

	set(var ${var}_${sync_COPY_SYMLINKS})

	list(FIND sync_list ${var} var_index)
	if ( NOT ${var_index} EQUAL -1 )
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
	if ( sync_DEPENDS )
		list(APPEND sync_depends "${sync_DEPENDS}")
	endif()
	if ( sync_EXCLUDE )
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
	cmake_parse_arguments(f "DEBUG;RELEASE" "QMAKE;OUTPUT;DIR;RUNTIME_DIR;LIBRARY_DIR;QNX_TARGET" "MODULES;PLUGINS;QML;PLATFORMS;FONTS;SYSTEM_LIBS;DEPENDS" ${ARGN})

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
		set(runtime_dir "lib")
	endif()

	if ( "${qt5_system}" STREQUAL "Windows" )
		set(qt_libexec_var QT_INSTALL_LIBEXECS)
	else()
		set(qt_libexec_var QT_INSTALL_LIBS)
	endif()
	execute_process(COMMAND "${qmake_location}" "-query" "${qt_libexec_var}" OUTPUT_VARIABLE qt5_libexecs_dir)
	execute_process(COMMAND "${qmake_location}" "-query" "QT_INSTALL_PLUGINS" OUTPUT_VARIABLE qt5_plugins_dir)
	execute_process(COMMAND "${qmake_location}" "-query" "QT_INSTALL_QML" OUTPUT_VARIABLE qt5_qml_dir)
	string(STRIP "${qt5_libexecs_dir}" qt5_libexecs_dir)
	string(STRIP "${qt5_plugins_dir}" qt5_plugins_dir)
	string(STRIP "${qt5_qml_dir}" qt5_qml_dir)

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
			foreach ( lib "icuuc${icu_version}" "icuin${icu_version}" "icudt${icu_version}" "libgcc_s_dw2-1" "libwinpthread-1" "libstdc++-6" )
				list(APPEND runtime_libs "${qt5_libexecs_dir}/${lib}.dll")
			endforeach()
		else()
			foreach ( lib "libgcc_s_sjlj-1" "libwinpthread-1" "libstdc++-6" )
				list(APPEND runtime_libs "/usr/i686-w64-mingw32/sys-root/mingw/bin/${lib}.dll")
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
		flat_sync(${runtime_target} "${runtime_lib}" COPY_SYMLINKS DESTINATION "${runtime_dir}/")
	endforeach()

	# Qt5 libs
	foreach ( module ${f_MODULES} )
		flat_sync(${runtime_target} "${qt5_libexecs_dir}/${lib_prefix}Qt5${module}${build_type_suffix}${qt5_lib_suffix}" COPY_SYMLINKS DESTINATION "${runtime_dir}/")
	endforeach()

	# Qt5 plugins
	foreach ( plugin ${plugins} )
		string(REPLACE ":" ";" plugin_tuple "${plugin}")
		list(GET plugin_tuple 0 plugin_directory)
		list(GET plugin_tuple 1 plugin_name)
		flat_sync(${share_target} "${qt5_plugins_dir}/${plugin_directory}/${lib_prefix}${plugin_name}${build_type_suffix}${lib_suffix}" COPY_SYMLINKS DESTINATION "plugins/${plugin_directory}/")
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
		endforeach()
		flat_sync(${share_target} "${qt5_qml_dir}/${qml}/" DESTINATION "qml/${qml}/" EXCLUDE ${excludes})
	endforeach()

	if ( "${f_FONTS}" STREQUAL "ALL" )
		flat_sync("${share_target}" "${qt5_libexecs_dir}/fonts/" DESTINATION "lib/fonts/")
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
#   TARGET - phony target name
#   OUTPUT - output to be touched when git repository content changed,
#            this is a byproduct of TARGET

function(flat_check_git TARGET OUTPUT GIT)
	add_custom_target(${TARGET}
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_CheckGitRevisionScript}" "${GIT}" "${OUTPUT}"
		BYPRODUCTS "${OUTPUT}"
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
#   DEPENDS        - additional file dependencies

function(flat_configure_cmake_project TARGET)
	set(Python_ADDITIONAL_VERSIONS 3.5-32)
	find_package(PythonInterp 3.5 REQUIRED)

	cmake_parse_arguments(f "" "SOURCE_DIR;BUILD_DIR;GENERATOR;MAKE" "ENV;ENV_PATHS;ARGS;GIT_DIRS;DEPENDS" ${ARGN})

	# vars
	set(build_dir "${f_BUILD_DIR}")
	set(cmake_build_dir "${build_dir}/build")
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
		set(build_file "build.ninja")
		set(build_make "ninja")
	elseif ( "${generator}" STREQUAL "Unix Makefiles" )
		set(build_file "Makefile")
		set(build_make "make")
	elseif ( "${generator}" STREQUAL "MinGW Makefiles" )
		set(build_file "Makefile")
		set(build_make "mingw32-make")
	else()
		message(FATAL_ERROR "Unsupported generator: ${generator}")
	endif()

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
	add_custom_command(
		OUTPUT "${cmake_build_dir}/${build_file}"
		COMMAND "${PYTHON_EXECUTABLE}" "${Flat_EraseCurrentDirScript}"
		COMMAND "${PYTHON_EXECUTABLE}" "${run_script}" ${CMAKE_COMMAND}
			-G "${generator}"
			-D "CMAKE_MAKE_PROGRAM=${build_make}"
			${args}
			"${f_SOURCE_DIR}"
		WORKING_DIRECTORY "${cmake_build_dir}"
		DEPENDS "${build_dir_target}" "${run_script}" ${f_DEPENDS}
	)

	add_custom_target(${TARGET})

	set_target_properties(${TARGET} PROPERTIES
		GIT_TARGETS "${git_targets}"
		GIT_FILES "${git_files}"
		MAKE "${build_make}"
		BUILD_DIR "${build_dir}"
		CMAKE_BUILD_DIR "${cmake_build_dir}"
		TARGET_FILE "${cmake_build_dir}/${build_file}"
	)
endfunction()


# Create rule to build previously configured CMake project.
#
# Arguments:
#   JOBS           - make job count when invoking build command

function (flat_build_cmake_project TARGET CONFIGURE_TARGET MAKE_TARGET)
	cmake_parse_arguments(f "" "JOBS" "")

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
	get_target_property(configure_target_file ${CONFIGURE_TARGET} TARGET_FILE)
	set(build_target_file "${build_dir}/target-${MAKE_TARGET}")

	# rule to build project
	if ( git_targets )
		add_custom_command(
			OUTPUT "${build_target_file}"
			COMMAND ${build_make} ${make_opts} ${make_jobs} ${MAKE_TARGET}
			COMMAND ${CMAKE_COMMAND} -E touch "${build_target_file}"
			WORKING_DIRECTORY "${cmake_build_dir}"
			DEPENDS "${configure_target_file}" ${git_files}
		)

		add_custom_target(${TARGET}
			DEPENDS "${build_target_file}" ${git_targets}
		)
	else()
		add_custom_target(${TARGET}
			COMMAND ${build_make} ${make_opts} ${make_jobs} ${MAKE_TARGET}
			WORKING_DIRECTORY "${cmake_build_dir}"
			DEPENDS "${configure_target_file}"
		)
	endif()
endfunction()


# config
function(_flat_config_exec)
	get_filename_component(root_dir "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

	foreach ( component ${Flat_FIND_COMPONENTS} )
		set(target Flat_${component})
		if ( NOT TARGET ${target} )
			message(FATAL_ERROR "Module not found: ${component}")
		endif()
	endforeach()
endfunction()

_flat_config_exec()


set(Flat_FOUND YES)
