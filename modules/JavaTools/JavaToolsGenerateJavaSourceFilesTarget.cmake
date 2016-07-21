#!/usr/bin/cmake -P


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


string(REPLACE ":" ";" _src_dirs "${SRC_DIRS}")


java_tools_generate_source_files_target("${JAVA_SOURCE_FILES_TARGET}"
	SOURCE_DIRS
		${_src_dirs}
	FILTERS
		"*.java"
)
