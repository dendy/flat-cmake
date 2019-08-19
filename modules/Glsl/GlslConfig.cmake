
set(Glsl_FOUND NO)

include(CMakeParseArguments)

find_program(
	Glsl_Validator glslangValidator
	PATHS $ENV{VULKAN_SDK}/bin/
)

if (Glsl_FIND_REQUIRED_Validator AND NOT Glsl_Validator)
	message(FATAL_ERROR "glslangValidator not found")
endif()

function(glsl_compile_shader)
	set(options "")
	set(oneValueArgs SOURCE_FILE OUTPUT_FILE_LIST)
	set(multiValueArgs "")
	cmake_parse_arguments(params "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

	if (NOT params_SOURCE_FILE)
		message(FATAL_ERROR "glsl_compile_shader: SOURCE_FILE argument missing")
	endif()

	if (NOT params_OUTPUT_FILE_LIST)
		message(FATAL_ERROR "glsl_compile_shader: OUTPUT_FILE_LIST argument missing")
	endif()

	set(src_file "${params_SOURCE_FILE}")
	get_filename_component(base_file_name ${src_file} NAME_WE)
	get_filename_component(file_extension ${src_file} EXT)

	if (file_extension STREQUAL ".comp")
		set(DEFINES "-DSHADER_STAGE_COMP")
	elseif(file_extension STREQUAL ".rahit")
		set(DEFINES "-DSHADER_STAGE_ACHIT")
	elseif(file_extension STREQUAL ".rmiss")
		set(DEFINES "-DSHADER_STAGE_RMISS")
	elseif(file_extension STREQUAL ".rchit")
		set(DEFINES "-DSHADER_STAGE_RCHIT")
	elseif(file_extension STREQUAL ".rgen")
		set(DEFINES "-DSHADER_STAGE_RGEN")
	elseif(file_extension STREQUAL ".frag")
		set(DEFINES "-DSHADER_STAGE_FRAG")
	elseif(file_extension STREQUAL ".vert")
		set(DEFINES "-DSHADER_STAGE_VERT")
	else()
		message(FATAL_ERROR "unknown extension in shader source file: ${file_extension}")
	endif()

	set_source_files_properties(${src_file} PROPERTIES VS_TOOL_OVERRIDE "None")

	set(out_dir "${CMAKE_CURRENT_BINARY_DIR}/shaders")
	set(out_file "${out_dir}/${base_file_name}.spv")

	set(command_line
		--target-env vulkan1.1
		-DVKPT_SHADER
		-V
		${DEFINES}
		"${src_file}"
		-o "${out_file}"
	)

	add_custom_command(
		OUTPUT ${out_file}
		DEPENDS ${src_file}
		COMMAND ${CMAKE_COMMAND} -E make_directory ${out_dir}
		COMMAND ${Glsl_Validator} ${command_line}
	)

	set(${params_OUTPUT_FILE_LIST} ${${params_OUTPUT_FILE_LIST}} ${out_file} PARENT_SCOPE)
endfunction()

set(Glsl_FOUND YES)
