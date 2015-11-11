
cmake_minimum_required(VERSION 3.3)

get_filename_component(Flat_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../modules/Flat" ABSOLUTE)
find_package(Flat REQUIRED)

add_subdirectory("sync-simple")
