
set(Glsl_FOUND NO)

include(CMakeParseArguments)

find_program(
	Glsl_Validator glslangValidator
	PATHS $ENV{VULKAN_SDK}/bin/
)

if (Glsl_FIND_REQUIRED_Validator AND NOT Glsl_Validator)
	message(FATAL_ERROR "glslangValidator not found")
endif()

function(glsl_compile_shader SOURCE_FILE SPV_FILE)
	set_source_files_properties(${SOURCE_FILE} PROPERTIES VS_TOOL_OVERRIDE "None")

	get_filename_component(ext ${SOURCE_FILE} EXT)
	if (ext STREQUAL ".comp")
		set(defines "-DSHADER_STAGE_COMP")
	elseif(ext STREQUAL ".rahit")
		set(defines "-DSHADER_STAGE_ACHIT")
	elseif(ext STREQUAL ".rmiss")
		set(defines "-DSHADER_STAGE_RMISS")
	elseif(ext STREQUAL ".rchit")
		set(defines "-DSHADER_STAGE_RCHIT")
	elseif(ext STREQUAL ".rgen")
		set(defines "-DSHADER_STAGE_RGEN")
	elseif(ext STREQUAL ".frag")
		set(defines "-DSHADER_STAGE_FRAG")
	elseif(ext STREQUAL ".vert")
		set(defines "-DSHADER_STAGE_VERT")
	else()
		message(FATAL_ERROR "Unknown shader extension: ${ext}")
	endif()

	get_filename_component(spv_dir "${SPV_FILE}" DIRECTORY)

	add_custom_command(
		OUTPUT ${SPV_FILE}
		COMMAND ${CMAKE_COMMAND} -E make_directory ${spv_dir}
		COMMAND "${Glsl_Validator}"
			--target-env vulkan1.1
			-DVKPT_SHADER
			-V
			${defines}
			"${SOURCE_FILE}"
			-o "${SPV_FILE}"
		DEPENDS "${SOURCE_FILE}"
	)
endfunction()

set(Glsl_FOUND YES)
