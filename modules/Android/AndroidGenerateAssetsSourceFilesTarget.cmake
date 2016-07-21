
include("${JavaTools_SCRIPT_DIR}/JavaToolsUtil.cmake")

string(REPLACE ":" ";" _assets_dirs "${ASSETS_DIRS}")

java_tools_generate_source_files_target("${TARGET_FILE}" SOURCE_DIRS ${_assets_dirs})
