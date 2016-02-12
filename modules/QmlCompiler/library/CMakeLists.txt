
cmake_minimum_required(VERSION 3.3)

set(Python_ADDITIONAL_VERSIONS 3.5-32)
find_package(PythonInterp 3.5 REQUIRED)

find_package(Flat REQUIRED)
find_package(Qt5 REQUIRED Quick)


set(cpp_dir "${CMAKE_CURRENT_BINARY_DIR}/cpp")
set(qrc_file "${CMAKE_CURRENT_BINARY_DIR}/qml.qrc")
set(loader_cpp_file "${CMAKE_CURRENT_BINARY_DIR}/loader.cpp")


file(STRINGS "${QML_FILES_TARGET}" qml_files)


# generate QRC
set(qrc_entries)
foreach ( qml_file ${qml_files} )
	file(RELATIVE_PATH relative_qml_file "${QML_SOURCE_DIR}" "${qml_file}")
	set(qrc_entries "${qrc_entries}\t\t<file alias=\"${relative_qml_file}\">${qml_file}</file>\n")
endforeach()

set(prefix)
if ( PREFIX )
	set(prefix " prefix=\"${PREFIX}\"")
endif()

flat_create_file_directory("${qrc_file}")
file(WRITE "${qrc_file}" "<RCC>\n\t<qresource${prefix}>\n${qrc_entries}\t</qresource>\n</RCC>")


# rules to create C++ from QML
set(cpp_files)

set(QML_SOURCE_DIR "" CACHE PATH "")
set(FIX_CPP_SCRIPT "" CACHE FILEPATH "")

foreach ( qml_file ${qml_files} )
	file(RELATIVE_PATH relative_qml_file "${QML_SOURCE_DIR}" "${qml_file}")
	get_filename_component(filepath "${relative_qml_file}" PATH)
	if ( filepath )
		set(filepathdir "${filepath}/")
	else()
		set(filepathdir "")
	endif()
	get_filename_component(filename_we "${qml_file}" NAME_WE)
	set(cpp_file "${cpp_dir}/${filepathdir}${filename_we}.cpp")
	set(unfixed_cpp_file "${cpp_dir}/${filepathdir}${filename_we}.unfixed.cpp")

	list(APPEND cpp_files "${cpp_file}")

	add_custom_command(OUTPUT "${cpp_file}"
		COMMAND ${CMAKE_COMMAND} -E make_directory "${cpp_dir}/${filepath}"
		COMMAND "${QML_COMPILER_EXECUTABLE}"
			"--resource=${qrc_file}"
			"${qml_file}"
			"${unfixed_cpp_file}"
		COMMAND "${PYTHON_EXECUTABLE}" "${FIX_CPP_SCRIPT}"
			--input "${unfixed_cpp_file}"
			--output "${cpp_file}"
			--version "${Qt5_VERSION}"
		DEPENDS
			"${qml_file}"
			"${FIX_CPP_SCRIPT}"
	)
endforeach()


# rule to create loader C++
add_custom_command(
	OUTPUT
		"${loader_cpp_file}"
	COMMAND "${PYTHON_EXECUTABLE}" "${GENERATE_QML_LOADER_SCRIPT}"
		--qml-compiler "${QML_COMPILER_EXECUTABLE}"
		--rcc "${RCC_EXECUTABLE}"
		--output "${loader_cpp_file}"
		--qrc "${qrc_file}"
		--version "${Qt5_VERSION}"
	DEPENDS
		"${GENERATE_QML_LOADER_SCRIPT}"
		"${qrc_file}"
)

add_custom_target(loader DEPENDS "${loader_cpp_file}")


# library
add_library(archive STATIC ${cpp_files} "${CMAKE_CURRENT_SOURCE_DIR}/empty.cpp")

target_include_directories(archive PRIVATE ${Qt5Qml_PRIVATE_INCLUDE_DIRS})

target_link_libraries(archive Qt5::Quick)
