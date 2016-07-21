#!/usr/bin/cmake -P


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")


string(REPLACE ":" ";" _src_dirs "${SRC_DIRS}")
string(REPLACE ":" ";" _src_files "${SRC_FILES}")
string(REPLACE ":" ";" _excludes "${EXCLUDE}")


java_tools_generate_source_files_target("${TARGET_FILE}"
	SOURCE_DIRS
		${_src_dirs}
	SOURCE_FILES
		${_src_files}
	EXCLUDES
		${_excludes}
)
