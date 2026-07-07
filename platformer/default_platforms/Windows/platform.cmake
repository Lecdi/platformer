cmake_minimum_required(VERSION 3.23)
set(PLATFORM "WINDOWS" CACHE INTERNAL "" FORCE)
set(PLATFORM_PACKAGE_NAME "Windows" CACHE INTERNAL "" FORCE)
set(PLATFORM_RESOURCES_DIR "${CMAKE_CURRENT_LIST_DIR}/resources" CACHE INTERNAL "" FORCE)

set(PLATFORM_NSIS_EXECUTABLE "" CACHE PATH "Optional path to directory containing NSIS executable")
if(PLATFORM_NSIS_EXECUTABLE)
    set(_platform_specified_nsis_executable "${PLATFORM_NSIS_EXECUTABLE}")
    platformer_normalize_paths(_platform_specified_nsis_executable "${CMAKE_SOURCE_DIR}")
    set(_platform_nsis_hints HINTS "${_platform_specified_nsis_executable}")
else()
    set(_platform_nsis_hints "")
endif()
find_program(MAKENSIS_EXECUTABLE NAMES "makensis" ${_platform_nsis_hints})
if(MAKENSIS_EXECUTABLE)
    platformer_log("Enabling application packaging with NSIS executable ${MAKENSIS_EXECUTABLE}")
    set(PLATFORM_ENABLE_APPLICATION_PACKAGING ON CACHE INTERNAL "" FORCE)
    set(PLATFORM_CPACK_CONFIG_NSIS_CODE "set(CPACK_NSIS_EXECUTABLE \"${MAKENSIS_EXECUTABLE}\")"
        CACHE INTERNAL "" FORCE
    )
else()
    platformer_log("No NSIS executable found so application packaging is disabled")
    set(PLATFORM_ENABLE_APPLICATION_PACKAGING OFF CACHE INTERNAL "" FORCE)
endif()

function(platform_get_icon out_var)
    foreach(candidate_icon IN LISTS ARGN)
        if("${candidate_icon}" MATCHES "\\.ico$")
            if(EXISTS "${candidate_icon}")
                set("${out_var}" "${candidate_icon}" PARENT_SCOPE)
                platformer_log("Using icon ${candidate_icon}")
                return()
            else()
                message(WARNING "Icon file ${candidate_icon} does not exist so is ignored")
            endif()
        endif()
    endforeach()
    set("${out_var}" "" PARENT_SCOPE)
    message(WARNING "No icon of correct format detected")
endfunction()

set(PLATFORM_EXECUTABLE_TARGET_PROPERTIES
    WINDOWS_NO_STANDARD_RESOURCES
    WINDOWS_DPI_AWARENESS
    WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP
    CACHE INTERNAL "" FORCE
)
function(platform_process_platform_settings_executable name)
    set(options
        WINDOWS_NO_STANDARD_RESOURCES
    )
    set(one_value_args
        WINDOWS_DPI_AWARENESS
        WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP
    )
    set(multi_value_args)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "${multi_value_args}")
    platformer_set_target_property("${name}" WINDOWS_NO_STANDARD_RESOURCES "${ARG_WINDOWS_NO_STANDARD_RESOURCES}")
    if(ARG_WINDOWS_DPI_AWARENESS)
        platformer_set_target_property("${name}" WINDOWS_DPI_AWARENESS "${ARG_WINDOWS_DPI_AWARENESS}")
    else()
        platformer_set_target_property("${name}" WINDOWS_DPI_AWARENESS "PerMonitorV2")
    endif()
    if(NOT ARG_WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP)
        set(ARG_WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP "NEVER")
    endif()
    if(ARG_WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP STREQUAL "NEVER")
        platformer_set_target_property("${name}" WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP OFF)
    elseif(ARG_WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP STREQUAL "ALWAYS")
        platformer_set_target_property("${name}" WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP ON)
    elseif(ARG_WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP STREQUAL "DEBUG_ONLY")
        if(_platformer_build_type STREQUAL "DEBUG")
            platformer_set_target_property("${name}" WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP ON)
        else()
            platformer_set_target_property("${name}" WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP OFF)
        endif()
    else()
        message(FATAL_ERROR
            "Unrecognized value for platform setting WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP, "
            "valid values are NEVER, ALWAYS or DEBUG_ONLY"
        )
    endif()
endfunction()

function(platform_config_executable name)
    platformer_get_target_properties("${name}" P
        ${PLATFORM_EXECUTABLE_TARGET_PROPERTIES}
        ${PLATFORMER_EXECUTABLE_TARGET_PROPERTIES}
    )
    set(resources_in_prefix "${PLATFORM_RESOURCES_DIR}/application")
    set(resources_configured_prefix "${CMAKE_CURRENT_BINARY_DIR}/configured/targets/${name}/src")
    if(P_EXECUTABLE_TYPE STREQUAL "CLI")
        set(declare_manifest "")
    elseif(P_EXECUTABLE_TYPE STREQUAL "GUI")
        if(NOT P_WINDOWS_PROVIDE_CONSOLE_FOR_GUI_APP)
            set_target_properties("${name}" PROPERTIES WIN32_EXECUTABLE ON)
        endif()
        set(dpi_awareness_code "<dpiAwareness>${P_WINDOWS_DPI_AWARENESS}</dpiAwareness>")
        configure_file(
            "${resources_in_prefix}/app.manifest.in"
            "${resources_configured_prefix}/${name}.manifest"
            @ONLY
        )
        set(declare_manifest "1 RT_MANIFEST \"${name}.manifest\"")
    else()
        message(FATAL_ERROR "Unrecognized executable type ${P_EXECUTABLE_TYPE}")
    endif()
    if(P_WINDOWS_NO_STANDARD_RESOURCES)
        return()
    endif()
    platform_get_icon(icon P_ICONS)
    if(icon)
        set("define_idi_app_icon" "#define IDI_APP_ICON 101")
        set("declare_icon" "IDI_APP_ICON ICON \"${icon}\"")
    else()
        set("define_idi_app_icon" "")
        set("declare_icon" "")
    endif()
    if(P_DISPLAY_NAME)
        set(display_name_value "VALUE \"ProductName\", \"${P_DISPLAY_NAME}\"")
    else()
        set(display_name_value "")
    endif()
    if(P_VENDOR)
        set(vendor_value "VALUE \"CompanyName\", \"${P_VENDOR}\"")
    else()
        set(vendor_value "")
    endif()
    configure_file(
        "${resources_in_prefix}/app.rc.in"
        "${resources_configured_prefix}/${name}.rc"
        @ONLY
    )
    configure_file(
        "${resources_in_prefix}/resource.h.in"
        "${resources_configured_prefix}/resource.h"
        @ONLY
    )
    target_sources("${name}" PRIVATE
        "${resources_configured_prefix}/${name}.rc"
        "${resources_configured_prefix}/resource.h"
    )
endfunction()

function(platform_get_sharedlib_export_import_code name)
    platformer_set_target_property("${name}" SHAREDLIB_EXPORT_CODE "__declspec(dllexport)")
    platformer_set_target_property("${name}" SHAREDLIB_IMPORT_CODE "__declspec(dllimport)")
endfunction()

set(PLATFORM_APPLICATION_PACKAGE_PROPERTIES
    USE_CUSTOM_NSIS_SCRIPT
    CUSTOM_NSIS_SCRIPT_PATH
    CUSTOM_NSIS_SCRIPT_ARGS
    CUSTOM_NSIS_SCRIPT_PRE_INSTALL_COMMANDS
    CACHE INTERNAL "" FORCE
)
function(platform_process_platform_settings_application_package name)
    set(options
        WINDOWS_NSIS_SCRIPT_NO_STANDARD_ARGS
        WINDOWS_NSIS_SCRIPT_NO_PRE_INSTALL
    )
    set(one_value_args
        WINDOWS_NSIS_SCRIPT
        WINDOWS_NSIS_SCRIPT_PRE_INSTALL_DIR
    )
    set(multi_value_args
        WINDOWS_NSIS_SCRIPT_ARGS
    )
    set(nsis_script_conditional_args
        WINDOWS_NSIS_SCRIPT_PRE_INSTALL_DIR
        WINDOWS_NSIS_SCRIPT_ARGS
    )
    set(nsis_script_conditional_options
        WINDOWS_NSIS_SCRIPT_NO_STANDARD_ARGS
        WINDOWS_NSIS_SCRIPT_NO_PRE_INSTALL
    )
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "${multi_value_args}")
    if(ARG_WINDOWS_NSIS_SCRIPT)
        set(custom_nsis_script_pre_install_commands "")
        if(NOT ARG_WINDOWS_NSIS_SCRIPT_NO_PRE_INSTALL)
            if(ARG_WINDOWS_NSIS_SCRIPT_PRE_INSTALL_DIR)
                set(staging_dir "${ARG_WINDOWS_NSIS_SCRIPT_PRE_INSTALL_DIR}/__temp__")
                platformer_normalize_paths(staging_dir "${CMAKE_CURRENT_BINARY_DIR}")
            else()
                set(staging_dir "${CMAKE_CURRENT_BINARY_DIR}/temp/install_staging/${name}/__temp__")
            endif()
            list(APPEND custom_nsis_script_pre_install_commands
                COMMAND "${CMAKE_COMMAND}" "-E" "remove_directory" "${staging_dir}"
                COMMAND "${CMAKE_COMMAND}" "-E" "make_directory" "${staging_dir}"
            )
            platformer_get_package_properties("${name}" P COMPONENT)
            list(APPEND custom_nsis_script_pre_install_commands
                COMMAND "${CMAKE_COMMAND}" "--install" "${CMAKE_BINARY_DIR}"
                "--component" "${P_COMPONENT}" "--prefix" "${staging_dir}"
            )
        endif()
        set(custom_nsis_script_args ${ARG_WINDOWS_NSIS_SCRIPT_ARGS})
        if(NOT ARG_WINDOWS_NSIS_SCRIPT_NO_STANDARD_ARGS)
            foreach(prop IN LISTS PLATFORMER_APPLICATION_PACKAGE_PROPERTIES)
                platformer_get_package_properties("${name}" P "${prop}")
                list(APPEND custom_nsis_script_args "/D${prop}=\"${P_${prop}}\"")
            endforeach()
            set(other_standard_args
                CMAKE_SOURCE_DIR
                CMAKE_CURRENT_SOURCE_DIR
                CMAKE_BINARY_DIR
                CMAKE_CURRENT_BINARY_DIR
            )
            foreach(arg IN LISTS other_standard_args)
                list(APPEND custom_nsis_script_args "/D${arg}=\"${${arg}}\"")
            endforeach()
            if(NOT ARG_WINDOWS_NSIS_SCRIPT_NO_PRE_INSTALL)
                list(APPEND custom_nsis_script_args "/DINSTALL_STAGING_DIR=\"${staging_dir}\"")
            endif()
        endif()
        platformer_normalize_paths(ARG_WINDOWS_NSIS_SCRIPT)
        platformer_set_package_property("${name}" USE_CUSTOM_NSIS_SCRIPT ON)
        platformer_set_package_property("${name}" CUSTOM_NSIS_SCRIPT_PATH "${ARG_WINDOWS_NSIS_SCRIPT}")
        platformer_set_package_property("${name}" CUSTOM_NSIS_SCRIPT_ARGS "${custom_nsis_script_args}")
        platformer_set_package_property("${name}"
            CUSTOM_NSIS_SCRIPT_PRE_INSTALL_COMMANDS
            "${custom_nsis_script_pre_install_commands}"
        )
    else()
        set(nsis_settings_warning
            "Settings pertaining to a custom NSIS script were given but a custom NSIS script was not specified so these are ignored"
        )
        foreach(arg IN LISTS nsis_script_conditional_args)
            if(NOT "${ARG_${arg}}" STREQUAL "")
                message(WARNING "${nsis_settings_warning}")
            endif()
        endforeach()
        foreach(arg IN LISTS nsis_script_conditional_options)
            if("${ARG_${arg}}")
                message(WARNING "${nsis_settings_warning}")
            endif()
        endforeach()
        platformer_set_package_property("${name}" USE_CUSTOM_NSIS_SCRIPT OFF)
    endif()
endfunction()

function(platform_generate_application_package name)
    if(NOT PLATFORM_ENABLE_APPLICATION_PACKAGING)
        message(WARNING "Application packaging not enabled so ${name}_package not generated")
        return()
    endif()
    platformer_get_package_properties("${name}" P
        ${PLATFORM_APPLICATION_PACKAGE_PROPERTIES}
        ${PLATFORMER_APPLICATION_PACKAGE_PROPERTIES}
    )
    if(NOT P_OMIT_TARGETS)
        if(P_OMIT_RUNTIME_DEPENDENCIES)
            install(
                TARGETS ${P_TARGETS}
                RUNTIME DESTINATION "bin"
                ARCHIVE DESTINATION "lib"
                LIBRARY DESTINATION "lib"
                COMPONENT "${P_COMPONENT}"
            )
        else()
            install(
                TARGETS ${P_TARGETS}
                RUNTIME DESTINATION "bin"
                ARCHIVE DESTINATION "lib"
                LIBRARY DESTINATION "lib"
                COMPONENT "${P_COMPONENT}"
                RUNTIME_DEPENDENCIES
                PRE_EXCLUDE_REGEXES "api-ms-" "ext-ms-"
                POST_EXCLUDE_REGEXES ".*system32.*"
            )
        endif()
    endif()
    if(P_USE_CUSTOM_NSIS_SCRIPT)
        add_custom_target("${name}_package"
            ${P_CUSTOM_NSIS_SCRIPT_PRE_INSTALL_COMMANDS}
            COMMAND "${MAKENSIS_EXECUTABLE}" "${P_CUSTOM_NSIS_SCRIPT_PATH}" ${P_CUSTOM_NSIS_SCRIPT_ARGS}
        )
    else()
        set(cpack_install_code
            "set(CPACK_INSTALL_CMAKE_PROJECTS \"${CMAKE_CURRENT_BINARY_DIR};${PROJECT_NAME};ALL;/\")"
        )
        set(components_code "set(CPACK_COMPONENTS_ALL \"${P_COMPONENT}\")")
        if(P_LICENSE)
            set(license_code "set(CPACK_RESOURCE_FILE_LICENSE \"${LICENSE}\")")
        else()
            set(license_code "")
        endif()
        platform_get_icon(icon ${P_ICONS})
        if(icon)
            set(mui_icon_code "set(CPACK_NSIS_MUI_ICON \"${icon}\")")
            set(mui_unicon_code "set(CPACK_NSIS_MUI_UNICON \"${icon}\")")
            set(installed_icon_code "set(CPACK_NSIS_INSTALLED_ICON_NAME \"${icon}\")")
        else()
            set(mui_icon_code "")
            set(mui_unicon_code "")
            set(installed_icon_code "")
        endif()
        if(P_VENDOR)
            set(vendor_code "set(CPACK_PACKAGE_VENDOR \"${P_VENDOR}\")")
        else()
            set(vendor_code "")
        endif()
        set(cpack_config_in "${PLATFORM_RESOURCES_DIR}/application_package/CPackConfig.cmake.in")
        set(cpack_config_configured "${CMAKE_CURRENT_BINARY_DIR}/configured/packages/${name}/CPackConfig.cmake")
        configure_file(
            "${cpack_config_in}"
            "${cpack_config_configured}"
            @ONLY
        )
        add_custom_target("${name}_package"
            COMMAND "${CMAKE_CPACK_COMMAND}" "--config" "${cpack_config_configured}"
        )
    endif()
endfunction()
