#!/usr/bin/cmake -P


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")
include( "${Android_SCRIPT_DIR}/AndroidUtil.cmake" )


string(REPLACE ":" ";" _lib_dirs "${LIB_DIRS}")


java_tools_generate_source_files_target("${TARGET_FILE}"
	SOURCE_DIRS
		${_lib_dirs}
	FILTERS
		"lib*.so"
)
