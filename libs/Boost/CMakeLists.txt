
set(Boost_Shared YES CACHE BOOL "")
set(Boost_Modules ALL CACHE STRING "")

include(CMakeParseArguments)

add_library(Boost_If INTERFACE)

# FIXME: Not needed?
#target_compile_definitions(Boost_If INTERFACE BOOST_NO_MEMBER_TEMPLATES)


add_library(Boost_Global INTERFACE)
target_compile_features(Boost_Global INTERFACE cxx_std_17)
target_compile_definitions(Boost_Global INTERFACE BOOST_ALL_NO_LIB)
if (CMAKE_CXX_COMPILER_ID STREQUAL GNU OR CMAKE_CXX_COMPILER_ID MATCHES Clang)
	target_compile_options(Boost_Global INTERFACE
		-Wno-deprecated-declarations
	)
endif()

if (Boost_Shared)
	set(lib_type SHARED)
else()
	set(lib_type STATIC)
endif()


# libs
set(all_libs)

function (lib NAME )
	string(REPLACE "/" "__" name "${NAME}")

	cmake_parse_arguments(lib "" "" "DEPENDS;CPP;LINK" ${ARGN})

	set(lib_${name}_exists  YES            PARENT_SCOPE)
	set(lib_${name}_path    ${NAME}        PARENT_SCOPE)
	set(lib_${name}_depends ${lib_DEPENDS} PARENT_SCOPE)
	set(lib_${name}_cpp     ${lib_CPP}     PARENT_SCOPE)
	set(lib_${name}_link    ${lib_LINK}    PARENT_SCOPE)

#	foreach (dep ${lib_DEPENDS})
#		set(parents lib_${dep}_parents)
#		if (NOT ${name} IN_LIST parents)
#			list(APPEND parents ${name})
#			set(lib_${dep}_parents ${parents} PARENT_SCOPE)
#		endif()
#	endforeach()

	set(all_libs ${all_libs} ${name} PARENT_SCOPE)
endfunction()


lib(predef)
lib(lexical_cast DEPENDS range numeric__conversion integer array container math)
lib(chrono DEPENDS ratio)
lib(utility)
lib(concept_check)
lib(atomic)
lib(detail)
lib(bind)
lib(core DEPENDS predef)
lib(assert)
lib(static_assert)
lib(move DEPENDS static_assert)
lib(iterator DEPENDS static_assert detail)
lib(exception)
lib(throw_exception DEPENDS assert)
lib(smart_ptr DEPENDS throw_exception)
lib(range DEPENDS iterator concept_check utility tuple)
lib(config)
lib(integer)
lib(preprocessor)
lib(mpl DEPENDS preprocessor)
lib(type_traits DEPENDS mpl)
lib(functional DEPENDS integer assert type_traits detail static_assert)
lib(ratio DEPENDS integer)
lib(io)
lib(any)
lib(tuple)
lib(type_index)
lib(optional DEPENDS move)
lib(numeric/conversion)
lib(multiprecision DEPENDS math lexical_cast rational)
lib(array DEPENDS config assert core throw_exception functional)
lib(math DEPENDS format)
lib(container)
lib(format)
lib(function)
lib(tokenizer)
lib(algorithm DEPENDS function)
lib(rational)
lib(uuid DEPENDS random)
lib(fusion)
lib(spirit DEPENDS phoenix variant foreach regex function_types)
lib(phoenix DEPENDS proto)
lib(proto DEPENDS typeof)
lib(typeof)
lib(variant)
lib(foreach)
lib(regex)
lib(function_types)
lib(crc DEPENDS array integer)
lib(interprocess DEPENDS intrusive)
lib(intrusive)
lib(random)
lib(align)
lib(container_hash)
lib(move)
lib(dynamic_bitset DEPENDS move)
if (CMAKE_SYSTEM_NAME STREQUAL Windows)
	lib(winapi)
endif()

if (CMAKE_SYSTEM_NAME STREQUAL Windows)
	set(system_deps winapi)
endif()

lib(system
	DEPENDS
		core config assert ${system_deps}
	CPP
		error_code
)

lib(filesystem
	DEPENDS
		system config detail type_traits assert iterator smart_ptr io functional range container_hash
	CPP
		codecvt_error_category
		operations
		path
		path_traits
		portability
		unique_path
		utf8_codecvt_facet
		windows_file_codecvt
)

lib(iostreams
	DEPENDS
		core config exception throw_exception assert static_assert type_traits integer smart_ptr
		range utility
	CPP
		bzip2
		file_descriptor
		gzip
		mapped_file
		zlib
	LINK
		bz2 z
)

lib(date_time
	DEPENDS
		config throw_exception mpl type_traits smart_ptr core utility lexical_cast tokenizer
	CPP
		gregorian/greg_month
)

lib(thread
	DEPENDS
		system range config type_traits move bind date_time atomic chrono io functional
		exception tuple optional function algorithm
	CPP
		pthread/once_atomic
		pthread/thread
)


if (Boost_Modules STREQUAL ALL)
	set(requested_libs ${all_libs})
else()
	set(requested_libs)
	foreach (path_name ${Boost_Modules})
		string(REPLACE "/" "__" name "${path_name}")
		list(APPEND requested_libs ${name})
	endforeach()
endif()


set(required_libs)

set(remaining_libs ${requested_libs})
while (YES)
	list(LENGTH remaining_libs length)
	if (length EQUAL 0)
		break()
	endif()

	list(GET remaining_libs 0 name)
	list(REMOVE_AT remaining_libs 0)

	if (NOT ${lib_${name}_exists})
		message(FATAL_ERROR "Invalid Boost module: ${name}")
	endif()

	if (${name} IN_LIST required_libs)
		continue()
	endif()

	list(APPEND required_libs ${name})

	list(APPEND remaining_libs ${lib_${name}_depends})
endwhile()


foreach (name ${required_libs})
	set(path ${lib_${name}_path})

	if (NOT lib_${name}_cpp)
		add_library(Boost_${name} INTERFACE)
		target_include_directories(Boost_${name} INTERFACE "${BoostDir}/libs/${path}/include")
	else()
		set(cpps)
		foreach (f ${lib_${name}_cpp})
			list(APPEND cpps "${BoostDir}/libs/${path}/src/${f}.cpp")
		endforeach()
		add_library(Boost_${name} ${lib_type} ${cpps})
		target_include_directories(Boost_${name} PUBLIC "${BoostDir}/libs/${path}/include")
	endif()

	foreach (d ${lib_${name}_depends})
		if (NOT lib_${name}_cpp)
			target_link_libraries(Boost_${name} INTERFACE Boost_${d})
		else()
			target_link_libraries(Boost_${name} PUBLIC Boost_${d})
		endif()
	endforeach()

	if (lib_${name}_link)
		target_link_libraries(Boost_${name} PRIVATE ${lib_${name}_link})
	endif()

	target_link_libraries(Boost_${name} INTERFACE Boost_Global)
endforeach()
