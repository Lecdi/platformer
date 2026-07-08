cmake_minimum_required(VERSION 3.23)


# Define options and cache variables

option(PLATFORMER_VERBOSE "Enable status messages from Platformer" ON)
set(PLATFORMER_PLATFORM_FILE "" CACHE PATH "Platform definition cmake file, overrides platform detection if set")
option(PLATFORMER_USE_DEFAULT_PLATFORMS "Use default platform definition if possible when no other found" ON)
set(PLATFORMER_PATHS "" CACHE STRING "Extra paths to search for platform definitions, semicolon-separated")
set(PLATFORMER_SYSTEM_NAME "" CACHE STRING "System name used to detect platform, defaults to CMAKE_SYSTEM_NAME")
option(PLATFORMER_GENERATE_BUILD_HPP "Generate platformer/build.hpp with build information" ON)
set(PLATFORMER_DEFAULT_PACKAGE_OUTPUT_PREFIX "${CMAKE_BINARY_DIR}/dist" CACHE STRING "")
option(PLATFORMER_ALLOW_UNRECOGNIZED_PLATFORM "" ON)


# Define constants and helper functions

include(CMakePackageConfigHelpers)

set(PLATFORMER_RESOURCES_DIR "${CMAKE_CURRENT_LIST_DIR}/resources" CACHE INTERNAL "" FORCE)

function(platformer_log)
    if(PLATFORMER_VERBOSE)
        message(STATUS "[PLATFORMER]  " ${ARGV})
    endif()
endfunction()

function(platformer_normalize_paths paths_variable)
    if(ARGC LESS 1 OR ARGC GREATER 2)
        message(FATAL_ERROR "Function platformer_normalize_paths accepts one or two arguments")
    endif()
    if(ARGC EQUAL 2)
        set(base_path "${ARGV1}")
    else()
        set(base_path "${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    set(new_paths "")
    foreach(path IN LISTS "${paths_variable}")
        cmake_path(ABSOLUTE_PATH path BASE_DIRECTORY "${base_path}")
        list(APPEND new_paths "${path}")
    endforeach()
    set("${paths_variable}" ${new_paths} PARENT_SCOPE)
endfunction()

function(platformer_run_optional_functions commands)
    foreach(command IN LISTS commands)
        if(COMMAND "${command}")
            cmake_language(CALL "${command}" ${ARGN})
        endif()
    endforeach()
endfunction()

function(platformer_process_version_string version_string_variable)
    if(NOT ARGC EQUAL 1)
        message(FATAL_ERROR "Function platformer_process_version_string accepts exactly one argument")
    endif()
    if(NOT "${${version_string_variable}}" MATCHES "^[0-9]+\\.[0-9]+\\.[0-9]+$")
        message(FATAL_ERROR "Invalid version string ${${version_string_variable}}")
    endif()
    string(REGEX MATCH "^([0-9]+)\\.([0-9]+)\\.([0-9]+)$" _ "${${version_string_variable}}")
    set("${version_string_variable}_MAJOR" "${CMAKE_MATCH_1}" PARENT_SCOPE)
    set("${version_string_variable}_MINOR" "${CMAKE_MATCH_2}" PARENT_SCOPE)
    set("${version_string_variable}_PATCH" "${CMAKE_MATCH_3}" PARENT_SCOPE)
endfunction()

function(platformer_add_universal_include_dirs target_name)
    if(NOT ARGC EQUAL 1)
        message(FATAL_ERROR "Function platformer_add_universal_include_dirs accepts exactly one argument")
    endif()
    if(NOT DEFINED PLATFORMER_UNIVERSAL_INCLUDE_DIRS)
        message(FATAL_ERROR "Cannot find universal include dirs")
    endif()
    if(PLATFORMER_UNIVERSAL_INCLUDE_DIRS)
        target_include_directories("${target_name}" PRIVATE ${PLATFORMER_UNIVERSAL_INCLUDE_DIRS})
    endif()
endfunction()

function(platformer_set_target_property target_name property_name property_value)
    if(NOT ARGC EQUAL 3)
        message(FATAL_ERROR "Function platformer_set_target_property requires exactly three arguments")
    endif()
    set_target_properties("${target_name}" PROPERTIES "PLATFORMER_${property_name}" "${property_value}")
endfunction()

function(platformer_get_target_properties target_name out_var_prefix)
    if(ARGC LESS 3)
        message(FATAL_ERROR
            "Function platformer_get_target_properties requires at least three arguments: "
            "target_name, out_var_prefix and at least one property name"
        )
    endif()
    foreach(property_name IN LISTS ARGN)
        get_target_property(property_value "${target_name}" "PLATFORMER_${property_name}")
        if(property_value MATCHES "-NOTFOUND$")
            set(property_value "")
        endif()
        set("${out_var_prefix}_${property_name}" "${property_value}" PARENT_SCOPE)
    endforeach()
endfunction()

function(platformer_set_package_property package_name property_name property_value)
    if(NOT ARGC EQUAL 3)
        message(FATAL_ERROR "Function platformer_set_package_property requires exactly three arguments")
    endif()
    set_property(GLOBAL PROPERTY "PLATFORMER_PACKAGE_${package_name}_${property_name}" "${property_value}")
endfunction()

function(platformer_get_package_properties package_name out_var_prefix)
    if(ARGC LESS 3)
        message(FATAL_ERROR
            "Function platformer_get_package_properties requires at least three arguments: "
            "package_name, out_var_prefix and at least one property name"
        )
    endif()
    foreach(property_name IN LISTS ARGN)
        get_property(property_value GLOBAL PROPERTY "PLATFORMER_PACKAGE_${package_name}_${property_name}")
        set("${out_var_prefix}_${property_name}" "${property_value}" PARENT_SCOPE)
    endforeach()
endfunction()


# Process options and cache variables, detect platform

if(PLATFORMER_PLATFORM_FILE)
    set(_platformer_platform_file "${PLATFORMER_PLATFORM_FILE}")
    platformer_normalize_paths(_platformer_platform_file "${CMAKE_SOURCE_DIR}")
    platformer_log("Using given platform file ${_platformer_platform_file}")
else()
    platformer_log("Detecting platform")
    if(PLATFORMER_SYSTEM_NAME)
        set(_platformer_system_name "${PLATFORMER_SYSTEM_NAME}")
        platformer_log("Using given system name ${_platformer_system_name}")
    else()
        set(_platformer_system_name "${CMAKE_SYSTEM_NAME}")
        platformer_log("Using detected system name ${_platformer_system_name}")
    endif()
    set(_platformer_paths ${PLATFORMER_PATHS})
    if(PLATFORMER_USE_DEFAULT_PLATFORMS)
        list(APPEND _platformer_paths "${CMAKE_CURRENT_LIST_DIR}/default_platforms")
    endif()
    platformer_normalize_paths(_platformer_paths "${CMAKE_SOURCE_DIR}")
    if(NOT _platformer_paths)
        message(FATAL_ERROR "No paths to search for platform definitions")
    else()
        platformer_log("Searching the following paths for platform definitions: ${_platformer_paths}")
    endif()
    foreach(path IN LISTS _platformer_paths)
        set(_platformer_platform_file_candidate "${path}/${_platformer_system_name}/platform.cmake")
        if(EXISTS "${_platformer_platform_file_candidate}")
            set(_platformer_platform_file "${_platformer_platform_file_candidate}")
            break()
        endif()
    endforeach()
    if(DEFINED _platformer_platform_file)
        platformer_log("Using detected platform file ${_platformer_platform_file}")
    else()
        if(PLATFORMER_ALLOW_UNRECOGNIZED_PLATFORM)
            set(_platformer_platform_file "${PLATFORMER_RESOURCES_DIR}/unrecognized_platform.cmake")
            message(WARNING "Could not detect platform, falling back on unrecognized platform")
        else()
            message(FATAL_ERROR "Could not find platform definition with system name ${_platformer_system_name}")
        endif()
    endif()
endif()

include("${_platformer_platform_file}")
if(NOT DEFINED PLATFORM)
    message(FATAL_ERROR "Malformed platform file does not define constant PLATFORM")
endif()
platformer_log("Platform is ${PLATFORM}")
if(NOT DEFINED PLATFORM_PACKAGE_NAME)
    set(PLATFORM_PACKAGE_NAME "${PLATFORMER_SYSTEM_NAME}" CACHE INTERNAL "" FORCE)
endif()

set(_platformer_universal_include_dirs "")
if(PLATFORMER_GENERATE_BUILD_HPP)
    string(TOUPPER CMAKE_BUILD_TYPE _platformer_build_type)
    set(_platformer_standard_build_types
        "DEBUG" "RELEASE" "RELWITHDEBINFO" "MINSIZEREL"
    )
    if(NOT _platformer_build_type IN_LIST _platformer_standard_build_types)
        set(_platformer_build_type "NONE_OR_OTHER")
    endif()
    configure_file(
        "${PLATFORMER_RESOURCES_DIR}/build.hpp.in"
        "${CMAKE_BINARY_DIR}/configured/include/platformer/build.hpp"
        @ONLY
    )
    list(APPEND _platformer_universal_include_dirs "${CMAKE_BINARY_DIR}/configured/include")
    platformer_log("Generated platformer/build.hpp")
endif()
set(PLATFORMER_UNIVERSAL_INCLUDE_DIRS "${_platformer_universal_include_dirs}" CACHE INTERNAL "" FORCE)


# Define main functions

set(PLATFORMER_EXECUTABLE_TARGET_PROPERTIES
    TARGET_TYPE
    EXECUTABLE_TYPE
    DISPLAY_NAME
    DESCRIPTION
    VERSION_STRING
    VERSION_MAJOR
    VERSION_MINOR
    VERSION_PATCH
    VENDOR
    ICONS
    CACHE INTERNAL "" FORCE
)
function(platformer_add_executable name type)
    if(ARGC LESS 2)
        message(FATAL_ERROR "Must specify name and type of executable")
    endif()
    set(options)
    set(one_value_args
        DISPLAY_NAME
        DESCRIPTION
        VERSION
        VENDOR
    )
    set(multi_value_args
        ICONS
        PLATFORM_SETTINGS
    )
    cmake_parse_arguments(PARSE_ARGV 2 ARG "${options}" "${one_value_args}" "${multi_value_args}")
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    add_executable("${name}")
    platformer_add_universal_include_dirs("${name}")
    if(NOT ARG_DISPLAY_NAME)
        set(ARG_DISPLAY_NAME "${name}")
    endif()
    platformer_normalize_paths(ARG_ICONS)
    platformer_process_version_string(ARG_VERSION)
    platformer_set_target_property("${name}" TARGET_TYPE "EXECUTABLE")
    platformer_set_target_property("${name}" EXECUTABLE_TYPE "${type}")
    platformer_set_target_property("${name}" DISPLAY_NAME "${ARG_DISPLAY_NAME}")
    platformer_set_target_property("${name}" DESCRIPTION "${ARG_DESCRIPTION}")
    platformer_set_target_property("${name}" VERSION_STRING "${ARG_VERSION}")
    platformer_set_target_property("${name}" VERSION_MAJOR "${ARG_VERSION_MAJOR}")
    platformer_set_target_property("${name}" VERSION_MINOR "${ARG_VERSION_MINOR}")
    platformer_set_target_property("${name}" VERSION_PATCH "${ARG_VERSION_PATCH}")
    platformer_set_target_property("${name}" VENDOR "${ARG_VENDOR}")
    platformer_set_target_property("${name}" ICONS "${ARG_ICONS}")
    set(platform_settings_functions
        platform_process_platform_settings_target
        platform_process_platform_settings_executable
    )
    platformer_run_optional_functions("${platform_settings_functions}" "${name}" ${ARG_PLATFORM_SETTINGS})
    set(config_functions
        platform_config_target
        platform_config_executable
    )
    platformer_run_optional_functions("${config_functions}" "${name}")
endfunction()

set(PLATFORMER_LIBRARY_TARGET_PROPERTIES
    TARGET_TYPE
    LIBRARY_TYPE
    PUBLIC_INCLUDE_DIRS
    OMIT_SHAREDLIB_API_HEADER
    SHAREDLIB_API_HEADER_DESTINATION
    SHAREDLIB_API_HEADER_NAME
    CACHE INTERNAL "" FORCE
)
function(platformer_add_library name type)
    if(ARGC LESS 2)
        message(FATAL_ERROR "Must specify name and type of library")
    endif()
    set(supported_library_types "STATIC" "SHARED" "INTERFACE")
    if(NOT type IN_LIST supported_library_types)
        message(FATAL_ERROR "Unsupported library type ${type}")
    endif()
    set(options
        OMIT_SHAREDLIB_API_HEADER
    )
    set(one_value_args
        PUBLIC_INCLUDE_DIRS
        SHAREDLIB_API_HEADER_DESTINATION
        SHAREDLIB_API_HEADER_NAME
    )
    set(multi_value_args
        PLATFORM_SETTINGS
    )
    cmake_parse_arguments(PARSE_ARGV 2 ARG "${options}" "${one_value_args}" "${multi_value_args}")
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    add_library("${name}" "${type}")
    if(type STREQUAL "SHARED")
        if(NOT ARG_OMIT_SHAREDLIB_API_HEADER)
            platformer_run_optional_functions(platform_get_sharedlib_export_import_code "${name}")
            platformer_get_target_properties("${name}" P SHAREDLIB_EXPORT_CODE SHAREDLIB_IMPORT_CODE)
            if(NOT P_SHAREDLIB_EXPORT_CODE)
                set(P_SHAREDLIB_EXPORT_CODE " ")
            endif()
            if(NOT P_SHAREDLIB_IMPORT_CODE)
                set(P_SHAREDLIB_IMPORT_CODE " ")
            endif()
            if(NOT ARG_SHAREDLIB_API_HEADER_DESTINATION)
                set(ARG_SHAREDLIB_API_HEADER_DESTINATION "${name}")
            endif()
            if(NOT ARG_SHAREDLIB_API_HEADER_NAME)
                set(ARG_SHAREDLIB_API_HEADER_NAME "api.hpp")
            endif()
            string(TOUPPER "${name}" name_upper)
            configure_file(
                "${PLATFORMER_RESOURCES_DIR}/shared_library/api.hpp.in"
                "${CMAKE_CURRENT_BINARY_DIR}/targets/${name}/include/${ARG_SHAREDLIB_API_HEADER_DESTINATION}/${ARG_SHAREDLIB_API_HEADER_NAME}"
                @ONLY
            )
            list(APPEND ARG_PUBLIC_INCLUDE_DIRS "${CMAKE_CURRENT_BINARY_DIR}/targets/${name}/include")
            target_compile_definitions("${name}" PRIVATE "${name_upper}_BUILD")
        endif()
    else()
        if(ARG_OMIT_SHAREDLIB_API_HEADER OR ARG_SHAREDLIB_API_HEADER_DESTINATION OR ARG_SHAREDLIB_API_HEADER_NAME)
            message(WARNING
                "Arguments pertaining to shared library were given but library ${name} is not shared "
                "so these are ignored"
            )
        endif()
    endif()
    if(NOT type STREQUAL "INTERFACE")
        platformer_add_universal_include_dirs("${name}")
    endif()
    platformer_normalize_paths(ARG_PUBLIC_INCLUDE_DIRS)
    platformer_set_target_property("${name}" TARGET_TYPE "LIBRARY")
    platformer_set_target_property("${name}" LIBRARY_TYPE "${type}")
    platformer_set_target_property("${name}" PUBLIC_INCLUDE_DIRS "${ARG_PUBLIC_INCLUDE_DIRS}")
    platformer_set_target_property("${name}" OMIT_SHAREDLIB_API_HEADER "${ARG_OMIT_SHAREDLIB_API_HEADER}")
    platformer_set_target_property("${name}" SHAREDLIB_API_HEADER_DESTINATION "${ARG_SHAREDLIB_API_HEADER_DESTINATION}")
    platformer_set_target_property("${name}" SHAREDLIB_API_HEADER_NAME "${ARG_SHAREDLIB_API_HEADER_NAME}")
    if(ARG_PUBLIC_INCLUDE_DIRS)
        set(public_include_dir_arguments "")
        foreach(dir IN LISTS ARG_PUBLIC_INCLUDE_DIRS)
            list(APPEND public_include_dir_arguments "$<BUILD_INTERFACE:${dir}>")
        endforeach()
        if(type STREQUAL "INTERFACE")
            set(include_directories_type "INTERFACE")
        else()
            set(include_directories_type "PUBLIC")
        endif()
        target_include_directories("${name}" "${include_directories_type}"
            ${public_include_dir_arguments} "$<INSTALL_INTERFACE:include>"
        )
    endif()
    set(platform_settings_functions
        platform_process_platform_settings_target
        platform_process_platform_settings_library
    )
    platformer_run_optional_functions("${platform_settings_functions}" "${name}" ${ARG_PLATFORM_SETTINGS})
    set(config_functions
        platform_config_target
        platform_config_library
    )
    platformer_run_optional_functions("${config_functions}" "${name}")
endfunction()

set(PLATFORMER_APPLICATION_PACKAGE_PROPERTIES
    OUTPUT_DIR
    PACKAGE_FILE_NAME
    DISPLAY_NAME
    DESCRIPTION
    VERSION_STRING
    VERSION_MAJOR
    VERSION_MINOR
    VERSION_PATCH
    VENDOR
    LICENSE
    ICONS
    TARGETS
    COMPONENT
    OMIT_TARGETS
    OMIT_RUNTIME_DEPENDENCIES
    CACHE INTERNAL "" FORCE
)
function(platformer_add_application_package name)
    if(ARGC LESS 1)
        message(FATAL_ERROR "Must specify name of application package")
    endif()
    set(options
        OMIT_TARGETS
        OMIT_RUNTIME_DEPENDENCIES
    )
    set(one_value_args
        DISPLAY_NAME
        DESCRIPTION
        VERSION
        VENDOR
        LICENSE
        OUTPUT_PREFIX
        OUTPUT_DIR
        PACKAGE_FILE_NAME
        USE_COMPONENT
    )
    set(multi_value_args
        TARGETS
        ICONS
        PLATFORM_SETTINGS
    )
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "${multi_value_args}")
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_OMIT_TARGETS AND NOT ARG_TARGETS)
        message(FATAL_ERROR "No targets given for application package ${name}")
    endif()
    if(NOT ARG_DISPLAY_NAME)
        set(ARG_DISPLAY_NAME "${name}")
    endif()
    platformer_normalize_paths(ARG_ICONS)
    platformer_normalize_paths(LICENSE)
    platformer_process_version_string(ARG_VERSION)
    if(NOT ARG_OUTPUT_PREFIX)
        set(ARG_OUTPUT_PREFIX "${PLATFORMER_DEFAULT_PACKAGE_OUTPUT_PREFIX}")
    endif()
    platformer_normalize_paths(ARG_OUTPUT_PREFIX "${CMAKE_CURRENT_BINARY_DIR}")
    if(NOT ARG_OUTPUT_DIR)
        set(ARG_OUTPUT_DIR "${name}")
    endif()
    set(output_dir "${ARG_OUTPUT_PREFIX}/${ARG_OUTPUT_DIR}")
    if(NOT ARG_PACKAGE_FILE_NAME)
        set(ARG_PACKAGE_FILE_NAME "${name}-${ARG_VERSION}-${PLATFORM_PACKAGE_NAME}")
    endif()
    if(NOT ARG_USE_COMPONENT)
        set(ARG_USE_COMPONENT "${name}")
    endif()
    platformer_set_package_property("${name}" OUTPUT_DIR "${output_dir}")
    platformer_set_package_property("${name}" PACKAGE_FILE_NAME "${ARG_PACKAGE_FILE_NAME}")
    platformer_set_package_property("${name}" DISPLAY_NAME "${ARG_DISPLAY_NAME}")
    platformer_set_package_property("${name}" DESCRIPTION "${ARG_DESCRIPTION}")
    platformer_set_package_property("${name}" VERSION_STRING "${ARG_VERSION}")
    platformer_set_package_property("${name}" VERSION_MAJOR "${ARG_VERSION_MAJOR}")
    platformer_set_package_property("${name}" VERSION_MINOR "${ARG_VERSION_MINOR}")
    platformer_set_package_property("${name}" VERSION_PATCH "${ARG_VERSION_PATCH}")
    platformer_set_package_property("${name}" VENDOR "${ARG_VENDOR}")
    platformer_set_package_property("${name}" LICENSE "${ARG_LICENSE}")
    platformer_set_package_property("${name}" ICONS "${ARG_ICONS}")
    platformer_set_package_property("${name}" TARGETS "${ARG_TARGETS}")
    platformer_set_package_property("${name}" COMPONENT "${ARG_USE_COMPONENT}")
    platformer_set_package_property("${name}" OMIT_TARGETS "${ARG_OMIT_TARGETS}")
    platformer_set_package_property("${name}" OMIT_RUNTIME_DEPENDENCIES "${ARG_OMIT_RUNTIME_DEPENDENCIES}")
    platformer_run_optional_functions(
        platform_process_platform_settings_application_package
        "${name}" ${ARG_PLATFORM_SETTINGS}
    )
    platform_generate_application_package("${name}")
endfunction()

set(PLATFORMER_CMAKE_PACKAGE_PROPERTIES
    OUTPUT_DIR
    PACKAGE_FILE_NAME
    DESCRIPTION
    NAMESPACE
    VERSION_STRING
    VERSION_MAJOR
    VERSION_MINOR
    VERSION_PATCH
    VERSION_COMPATIBILITY
    TARGETS
    COMPONENT
    EXPORT_NAME
    OMIT_TARGETS
    OMIT_CONFIG_FILES
    OMIT_FILE_SETS
    NO_ALIASES
    PACKAGE_CONFIG_IN_FILE
    CACHE INTERNAL "" FORCE
)
function(platformer_add_cmake_package name)
    if(ARGC LESS 1)
        message(FATAL_ERROR "Must specify name of CMake package ${name}")
    endif()
    set(options
        OMIT_TARGETS
        OMIT_CONFIG_FILES
        OMIT_FILE_SETS
        NO_ALIASES
    )
    set(one_value_args
        DESCRIPTION
        NAMESPACE
        VERSION
        VERSION_COMPATIBILITY
        OUTPUT_PREFIX
        OUTPUT_DIR
        PACKAGE_FILE_NAME
        USE_COMPONENT
        USE_EXPORT_NAME
        USE_PACKAGE_CONFIG_IN_FILE
    )
    set(multi_value_args
        TARGETS
        PLATFORM_SETTINGS
    )
    cmake_parse_arguments(PARSE_ARGV 1 ARG "${options}" "${one_value_args}" "${multi_value_args}")
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments ${ARG_UNPARSED_ARGUMENTS}")
    endif()
    if(NOT ARG_OMIT_TARGETS AND NOT ARG_TARGETS)
        message(FATAL_ERROR "No targets given for CMake package ${name}")
    endif()
    if(NOT ARG_NAMESPACE)
        set(ARG_NAMESPACE "${name}")
    endif()
    platformer_process_version_string(ARG_VERSION)
    if(NOT ARG_VERSION_COMPATIBILITY)
        set(ARG_VERSION_COMPATIBILITY "SameMajorVersion")
    endif()
    if(NOT ARG_OUTPUT_PREFIX)
        set(ARG_OUTPUT_PREFIX "${PLATFORMER_DEFAULT_PACKAGE_OUTPUT_PREFIX}")
    endif()
    platformer_normalize_paths(ARG_OUTPUT_PREFIX "${CMAKE_CURRENT_BINARY_DIR}")
    if(NOT ARG_OUTPUT_DIR)
        set(ARG_OUTPUT_DIR "${name}")
    endif()
    set(output_dir "${ARG_OUTPUT_PREFIX}/${ARG_OUTPUT_DIR}")
    if(NOT ARG_PACKAGE_FILE_NAME)
        set(ARG_PACKAGE_FILE_NAME "${name}-${ARG_VERSION}-${PLATFORM_PACKAGE_NAME}")
    endif()
    if(NOT ARG_USE_COMPONENT)
        set(ARG_USE_COMPONENT "${name}")
    endif()
    if(NOT ARG_USE_EXPORT_NAME)
        set(ARG_USE_EXPORT_NAME "${name}")
    endif()
    if(NOT ARG_USE_PACKAGE_CONFIG_IN_FILE)
        set(ARG_USE_PACKAGE_CONFIG_IN_FILE "${PLATFORMER_RESOURCES_DIR}/cmake_package/CMakePackageConfig.cmake.in")
    endif()
    platformer_set_package_property("${name}" OUTPUT_DIR "${output_dir}")
    platformer_set_package_property("${name}" PACKAGE_FILE_NAME "${ARG_PACKAGE_FILE_NAME}")
    platformer_set_package_property("${name}" DESCRIPTION "${ARG_DESCRIPTION}")
    platformer_set_package_property("${name}" NAMESPACE "${ARG_NAMESPACE}")
    platformer_set_package_property("${name}" VERSION_STRING "${ARG_VERSION}")
    platformer_set_package_property("${name}" VERSION_MAJOR "${ARG_VERSION_MAJOR}")
    platformer_set_package_property("${name}" VERSION_MINOR "${ARG_VERSION_MINOR}")
    platformer_set_package_property("${name}" VERSION_PATCH "${ARG_VERSION_PATCH}")
    platformer_set_package_property("${name}" VERSION_COMPATIBILITY "${ARG_VERSION_COMPATIBILITY}")
    platformer_set_package_property("${name}" TARGETS "${ARG_TARGETS}")
    platformer_set_package_property("${name}" COMPONENT "${ARG_USE_COMPONENT}")
    platformer_set_package_property("${name}" EXPORT_NAME "${ARG_USE_EXPORT_NAME}")
    platformer_set_package_property("${name}" OMIT_TARGETS "${ARG_OMIT_TARGETS}")
    platformer_set_package_property("${name}" OMIT_CONFIG_FILES "${ARG_OMIT_CONFIG_FILES}")
    platformer_set_package_property("${name}" OMIT_FILE_SETS "${ARG_OMIT_FILE_SETS}")
    platformer_set_package_property("${name}" NO_ALIASES "${ARG_NO_ALIASES}")
    platformer_set_package_property("${name}" PACKAGE_CONFIG_IN_FILE "${ARG_USE_PACKAGE_CONFIG_IN_FILE}")
    platformer_run_optional_functions(
        platform_process_platform_settings_cmake_package
        "${name}" ${ARG_PLATFORM_SETTINGS}
    )
    platformer_generate_cmake_package("${name}")
endfunction()

function(platformer_generate_cmake_package name)
    platformer_get_package_properties("${name}" P
        ${PLATFORMER_CMAKE_PACKAGE_PROPERTIES}
    )
    if(NOT P_OMIT_TARGETS)
        install(
            TARGETS ${P_TARGETS}
            EXPORT "${P_EXPORT_NAME}"
            RUNTIME DESTINATION "bin"
            ARCHIVE DESTINATION "lib"
            LIBRARY DESTINATION "lib"
            COMPONENT "${P_COMPONENT}"
        )
    endif()
    set(package_config_configured_location "${CMAKE_CURRENT_BINARY_DIR}/configured/packages/${name}")
    set(package_config_install_location "lib/cmake/${name}")
    configure_package_config_file(
        "${P_PACKAGE_CONFIG_IN_FILE}"
        "${package_config_configured_location}/${name}Config.cmake"
        INSTALL_DESTINATION "${package_config_install_location}"
    )
    write_basic_package_version_file(
        "${package_config_configured_location}/${name}ConfigVersion.cmake"
        VERSION "${P_VERSION_STRING}" COMPATIBILITY "${P_VERSION_COMPATIBILITY}"
    )
    if(NOT P_OMIT_CONFIG_FILES)
        install(
            FILES
                "${package_config_configured_location}/${name}Config.cmake"
                "${package_config_configured_location}/${name}ConfigVersion.cmake"
            DESTINATION "${package_config_install_location}"
            COMPONENT "${P_COMPONENT}"
        )
        install(
            EXPORT "${P_EXPORT_NAME}"
            FILE "${name}Targets.cmake"
            NAMESPACE "${P_NAMESPACE}::"
            DESTINATION "${package_config_install_location}"
            COMPONENT "${P_COMPONENT}"
        )
    endif()
    foreach(target IN LISTS P_TARGETS)
        platformer_get_target_properties("${target}" TP
            TARGET_TYPE
            PUBLIC_INCLUDE_DIRS
        )
        if(TP_TARGET_TYPE STREQUAL "LIBRARY")
            foreach(dir IN LISTS TP_PUBLIC_INCLUDE_DIRS)
                install(
                    DIRECTORY "${dir}/"
                    DESTINATION "include"
                    COMPONENT "${P_COMPONENT}"
                )
            endforeach()
            if(NOT P_OMIT_FILE_SETS AND NOT P_OMIT_TARGETS)
                get_target_property(header_sets "${target}" INTERFACE_HEADER_SETS)
                if(NOT header_sets)
                    set(header_sets "")
                endif()
                get_target_property(module_sets "${target}" INTERFACE_CXX_MODULE_SETS)
                if(NOT module_sets)
                    set(module_sets "")
                endif()
                foreach(file_set IN LISTS header_sets module_sets)
                    install(TARGETS "${target}" FILE_SET "${file_set}" COMPONENT "${P_COMPONENT}")
                endforeach()
            endif()
            if(NOT P_NO_ALIASES)
                add_library("${P_NAMESPACE}::${target}" ALIAS "${target}")
            endif()
        endif()
    endforeach()
    set(cpack_install_code
        "set(CPACK_INSTALL_CMAKE_PROJECTS \"${CMAKE_CURRENT_BINARY_DIR};${PROJECT_NAME};ALL;/\")"
    )
    set(components_code "set(CPACK_COMPONENTS_ALL \"${P_COMPONENT}\")")
    set(cpack_config_in "${PLATFORMER_RESOURCES_DIR}/cmake_package/CPackConfig.cmake.in")
    set(cpack_config_configured "${CMAKE_CURRENT_BINARY_DIR}/configured/packages/${name}/CPackConfig.cmake")
    configure_file(
        "${cpack_config_in}"
        "${cpack_config_configured}"
        @ONLY
    )
    add_custom_target("${name}_package"
        COMMAND "${CMAKE_CPACK_COMMAND}" "--config" "${cpack_config_configured}"
    )
endfunction()
