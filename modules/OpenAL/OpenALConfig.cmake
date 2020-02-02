
set(OpenAL_FOUND NO)


if (TARGET OpenAL)
	# target already exist, use it as is
	set(OpenAL_FOUND YES)
	return()
endif()


find_path(OPENAL_INCLUDE_DIR al.h
	HINTS
		ENV OPENALDIR
	PATH_SUFFIXES
		include/AL
		include/OpenAL
		include AL OpenAL
	PATHS
		~/Library/Frameworks
		/Library/Frameworks
		/opt
		[HKEY_LOCAL_MACHINE\\SOFTWARE\\Creative\ Labs\\OpenAL\ 1.1\ Software\ Development\ Kit\\1.00.0000;InstallDir]
)

if(CMAKE_SIZEOF_VOID_P EQUAL 8)
	set(_OpenAL_ARCH_DIR libs/Win64)
else()
	set(_OpenAL_ARCH_DIR libs/Win32)
endif()

find_library(OPENAL_LIBRARY
	NAMES
		OpenAL
		al
		openal
		OpenAL32
	HINTS
		ENV OPENALDIR
	PATH_SUFFIXES
		libx32
		lib64
		lib
		libs64
		libs
		${_OpenAL_ARCH_DIR}
	PATHS
		~/Library/Frameworks
		/Library/Frameworks
		/opt
		[HKEY_LOCAL_MACHINE\\SOFTWARE\\Creative\ Labs\\OpenAL\ 1.1\ Software\ Development\ Kit\\1.00.0000;InstallDir]
)

unset(_OpenAL_ARCH_DIR)


include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(OpenAL DEFAULT_MSG OPENAL_LIBRARY OPENAL_INCLUDE_DIR)

mark_as_advanced(OPENAL_LIBRARY OPENAL_INCLUDE_DIR)


# wrap it into the imported library target
add_library(OpenAL UNKNOWN IMPORTED)
set_target_properties(OpenAL PROPERTIES
	IMPORTED_LOCATION "${OPENAL_LIBRARY}"
	INTERFACE_INCLUDE_DIRECTORIES "${OPENAL_INCLUDE_DIR}"
)
