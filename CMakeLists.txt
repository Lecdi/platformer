cmake_minimum_required(VERSION 3.23)
project(platformer LANGUAGES NONE VERSION 0.0.0)

if(PROJECT_IS_TOP_LEVEL)
    set(PLATFORMER_TOP_LEVEL ON)
    set(PLATFORMER_NOT_TOP_LEVEL OFF)
else()
    set(PLATFORMER_TOP_LEVEL OFF)
    set(PLATFORMER_NOT_TOP_LEVEL ON)
endif()
option(PLATFORMER_PACKAGE_TARGET "Enable the platformer_package target" "${PLATFORMER_TOP_LEVEL}")
option(PLATFORMER_INCLUDE_AUTOMATICALLY "Automatically include platformer.cmake" "${PLATFORMER_NOT_TOP_LEVEL}")

if(PLATFORMER_INCLUDE_AUTOMATICALLY)
    include("${CMAKE_CURRENT_SOURCE_DIR}/platformer/platformer.cmake")
endif()

if(PLATFORMER_PACKAGE_TARGET)
    include(CMakePackageConfigHelpers)
    configure_package_config_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/platformerConfig.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/configured/platformerConfig.cmake"
        INSTALL_DESTINATION "lib/cmake/platformer"
    )
    install(
        FILES "${CMAKE_CURRENT_BINARY_DIR}/configured/platformerConfig.cmake"
        DESTINATION "lib/cmake/platformer"
        COMPONENT "platformer"
    )
    install(
        DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/platformer"
        DESTINATION "lib/cmake/platformer"
        COMPONENT "platformer"
    )
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/platformerPackageCPackConfig.cmake.in"
        "${CMAKE_CURRENT_BINARY_DIR}/configured/platformerPackageCPackConfig.cmake"
        @ONLY
    )
    add_custom_target(platformer_package
        COMMAND "${CMAKE_CPACK_COMMAND}" "--config"
        "${CMAKE_CURRENT_BINARY_DIR}/configured/platformerPackageCPackConfig.cmake"
    )
endif()
