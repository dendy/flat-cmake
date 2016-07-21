#!/usr/bin/cmake -P

# Collect list of IDL files.
#
# Arguments:
#   SRC_DIRS                - column separated paths where to lookup for aidl files
#   IDL_SOURCE_FILES_TARGET - where to generate target file with list of found aidl files


include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")
include("${Android_SCRIPT_DIR}/AndroidUtil.cmake")


# read package name
file(READ "${PACKAGE_NAME_FILE}" _package_name)
string(REPLACE "." "/" _package_path "${_package_name}")


string(REPLACE ":" ";" _src_dirs "${SRC_DIRS}")


java_tools_generate_source_files_target("${IDL_SOURCE_FILES_TARGET}"
	SOURCE_DIRS
		${_src_dirs}
	FILTERS
		"*.aidl"
)
