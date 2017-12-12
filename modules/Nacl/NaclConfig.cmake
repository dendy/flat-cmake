
include(CMakeParseArguments)


function (nacl_create_package TARGET)
	find_package(Flat REQUIRED)

	cmake_parse_arguments(p "" "EXECUTABLE;DATA_DIR;OUTPUT_DIR" "" ${ARGN})

	set(build_dir "${CMAKE_CURRENT_BINARY_DIR}/pnacl_${TARGET}")

	set(binary_output_dir "${p_OUTPUT_DIR}/pnacl/Release")

	set(unstripped_binary "${build_dir}/unstripped.pexe")
	set(stripped_binary "${binary_output_dir}/module.pexe")
	set(nmf "${binary_output_dir}/module.nmf")

	nacl_pnacl_finalize("${p_EXECUTABLE}" "${unstripped_binary}")
	nacl_pnacl_strip("${unstripped_binary}" "${stripped_binary}")
	nacl_create_nmf("${nmf}" "${stripped_binary}")

	add_custom_target(${TARGET} DEPENDS "${nmf}")

	if (p_DATA_DIR)
		flat_add_sync_target(${TARGET}_Data "${p_OUTPUT_DIR}")
		flat_sync(${TARGET}_Data "${p_DATA_DIR}" ".")
		add_dependencies(${TARGET} ${TARGET}_Data)
	endif()
endfunction()


function (__nacl_setup_qt)
	if (NOT TARGET Qt5::qmake)
		return()
	endif()

	get_target_property(qmake_location Qt5::qmake IMPORTED_LOCATION)
	execute_process(COMMAND "${qmake_location}" -query QT_INSTALL_LIBS OUTPUT_VARIABLE qt_libs)
	string(STRIP "${qt_libs}" qt_libs)
	execute_process(COMMAND "${qmake_location}" -query QT_INSTALL_QML OUTPUT_VARIABLE qt_qml)
	string(STRIP "${qt_qml}" qt_qml)

	if (TARGET Qt5::Core)
		set_property(TARGET Qt5::Core APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES "${qt_libs}/libqtpcre2.a" nacl_io
		)
	endif()

	if (TARGET Qt5::Gui)
		set_property(TARGET Qt5::Gui APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES "${qt_libs}/libqtlibpng.a" "${qt_libs}/libqtharfbuzz.a"
		)

		add_library(Qt5::EventDispatcherSupport MODULE IMPORTED)
		set_target_properties(Qt5::EventDispatcherSupport PROPERTIES
			IMPORTED_LOCATION "${qt_libs}/libQt5EventDispatcherSupport.a"
		)

		add_library(Qt5::FontDatabaseSupport MODULE IMPORTED)
		set_target_properties(Qt5::FontDatabaseSupport PROPERTIES
			IMPORTED_LOCATION "${qt_libs}/libQt5FontDatabaseSupport.a"
		)
		set_property(TARGET Qt5::FontDatabaseSupport APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES "${qt_libs}/libqtfreetype.a"
		)

		set_property(TARGET Qt5::QPnaclIntegrationPlugin APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES ppapi ppapi_cpp ppapi_gles2
				Qt5::FontDatabaseSupport Qt5::EventDispatcherSupport Qt5::Gui
		)
	endif()

	if (TARGET Qt5::Quick)
		add_library(Qt5::Quick2QmlPlugin MODULE IMPORTED)
		set_target_properties(Qt5::Quick2QmlPlugin PROPERTIES
			IMPORTED_LOCATION "${qt_qml}/QtQuick.2/libqtquick2plugin.a"
		)
		set_property(TARGET Qt5::Quick2QmlPlugin APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES Qt5::Quick
		)

		if (TARGET Qt5::Multimedia)
			add_library(Qt5::MultimediaQuick MODULE IMPORTED)
			if (Qt5_VERSION VERSION_LESS "5.10")
				set_target_properties(Qt5::MultimediaQuick PROPERTIES
					IMPORTED_LOCATION "${qt_libs}/libQt5MultimediaQuick_p.a"
				)
			else()
				set_target_properties(Qt5::MultimediaQuick PROPERTIES
					IMPORTED_LOCATION "${qt_libs}/libQt5MultimediaQuick.a"
				)
			endif()
			set_property(TARGET Qt5::MultimediaQuick APPEND PROPERTY
				INTERFACE_LINK_LIBRARIES Qt5::Quick Qt5::Multimedia
			)

			add_library(Qt5::MultimediaQmlPlugin MODULE IMPORTED)
			set_target_properties(Qt5::MultimediaQmlPlugin PROPERTIES
				IMPORTED_LOCATION "${qt_qml}/QtMultimedia/libdeclarative_multimedia.a"
			)
			set_property(TARGET Qt5::MultimediaQmlPlugin APPEND PROPERTY
				INTERFACE_LINK_LIBRARIES Qt5::MultimediaQuick
			)
		endif()

		add_library(Qt5::GraphicalEffectsQmlPlugin MODULE IMPORTED)
		set_target_properties(Qt5::GraphicalEffectsQmlPlugin PROPERTIES
			IMPORTED_LOCATION "${qt_qml}/QtGraphicalEffects/libqtgraphicaleffectsplugin.a"
		)
		set_property(TARGET Qt5::GraphicalEffectsQmlPlugin APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES "${qt_qml}/QtGraphicalEffects/private/libqtgraphicaleffectsprivate.a"
		)

		add_library(Qt5::Window2QmlPlugin MODULE IMPORTED)
		set_target_properties(Qt5::Window2QmlPlugin PROPERTIES
			IMPORTED_LOCATION "${qt_qml}/QtQuick/Window.2/libwindowplugin.a"
		)

		if (TARGET Qt5::QuickControls2)
			add_library(Qt5::QuickTemplates2 MODULE IMPORTED)
			set_target_properties(Qt5::QuickTemplates2 PROPERTIES
				IMPORTED_LOCATION "${qt_libs}/libQt5QuickTemplates2.a"
			)
			set_property(TARGET Qt5::QuickTemplates2 APPEND PROPERTY
				INTERFACE_LINK_LIBRARIES Qt5::Gui
			)

			set_property(TARGET Qt5::QuickControls2 APPEND PROPERTY
				INTERFACE_LINK_LIBRARIES Qt5::QuickTemplates2
			)

			add_library(Qt5::Controls2QmlPlugin MODULE IMPORTED)
			set_target_properties(Qt5::Controls2QmlPlugin PROPERTIES
				IMPORTED_LOCATION "${qt_qml}/QtQuick/Controls.2/libqtquickcontrols2plugin.a"
			)
			set_property(TARGET Qt5::Controls2QmlPlugin APPEND PROPERTY
				INTERFACE_LINK_LIBRARIES Qt5::QuickControls2
			)

			add_library(Qt5::Templates2QmlPlugin MODULE IMPORTED)
			set_target_properties(Qt5::Templates2QmlPlugin PROPERTIES
				IMPORTED_LOCATION "${qt_qml}/QtQuick/Templates.2/libqtquicktemplates2plugin.a"
			)

			add_library(Qt5::Controls2MaterialQmlPlugin MODULE IMPORTED)
			set_target_properties(Qt5::Controls2MaterialQmlPlugin PROPERTIES
				IMPORTED_LOCATION "${qt_qml}/QtQuick/Controls.2/Material/libqtquickcontrols2materialstyleplugin.a"
			)
			set_property(TARGET Qt5::Controls2MaterialQmlPlugin APPEND PROPERTY
				INTERFACE_LINK_LIBRARIES Qt5::QuickControls2 Qt5::QuickTemplates2
			)
		endif()

		add_library(Qt5::LayoutsQmlPlugin MODULE IMPORTED)
		set_target_properties(Qt5::LayoutsQmlPlugin PROPERTIES
			IMPORTED_LOCATION "${qt_qml}/QtQuick/Layouts/libqquicklayoutsplugin.a"
		)

		add_library(Qt5::QuickParticles MODULE IMPORTED)
		set_target_properties(Qt5::QuickParticles PROPERTIES
			IMPORTED_LOCATION "${qt_libs}/libQt5QuickParticles.a"
		)
		set_property(TARGET Qt5::QuickParticles APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES Qt5::Quick
		)

		add_library(Qt5::Particles2QmlPlugin MODULE IMPORTED)
		set_target_properties(Qt5::Particles2QmlPlugin PROPERTIES
			IMPORTED_LOCATION "${qt_qml}/QtQuick/Particles.2/libparticlesplugin.a"
		)
		set_property(TARGET Qt5::Particles2QmlPlugin APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES Qt5::QuickParticles
		)
	endif()

	if (TARGET Qt5::Network)
		set_property(TARGET Qt5::Network APPEND PROPERTY
			INTERFACE_LINK_LIBRARIES ssl crypto
		)
	endif()
endfunction()

__nacl_setup_qt()


set(Nacl_FOUND YES)
