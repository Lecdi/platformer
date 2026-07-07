cmake_minimum_required(VERSION 3.23)
set(PLATFORM "UNRECOGNIZED" CACHE INTERNAL "" FORCE)
set(PLATFORM_PACKAGE_NAME "${PLATFORMER_SYSTEM_NAME}" CACHE INTERNAL "" FORCE)

function(platform_generate_application_package name)
    message(WARNING "Unrecognized platform so ${name}_package not generated")
endfunction()
