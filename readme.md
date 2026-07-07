# Platformer

Platformer is a pure CMake module which simplifies creating cross-platform C++ projects.

The goal is to reduce platform-specific CMake boilerplate without hiding CMake itself. Projects remain standard CMake projects, and you can opt out of or override Platformer's behaviour at any time.

Rather than replacing CMake, Platformer builds on top of it by providing sensible defaults for common cross-platform tasks such as application metadata, packaging and platform-specific resources.

### Overview

Platformer provides a platform-independent interface for defining executables, libraries and distributable packages. It handles the common, platform-independent parts automatically and delegates platform-specific behaviour to a platform definition.

A platform definition is a CMake file implementing a small set of functions that customise how targets and packages are created for a particular platform. Platformer selects one automatically based on `CMAKE_SYSTEM_NAME`, or you can override this and select one yourself.

Platformer ships with a Windows platform definition capable of creating CLI and GUI applications with appropriate metadata and generating simple NSIS installers.

At present, Windows is the only built-in platform definition. For other platforms, you can write your own platform definitions and pass them in via the `PLATFORMER_PATHS` cache variable. A generic fallback platform definition is used when no suitable platform definition is found.

Platformer does not provide any C++ libraries and does not replace your GUI framework.

### Features

- Platform-independent functions for defining executables, libraries and packages
- Automatic platform-specific metadata (icons, manifests, etc.)
- Application packaging using CPack
- CMake package generation for libraries
- Extensible platform definition system
- Optional generation of a `<platformer/build.hpp>` header containing compile-time constants such as the target platform and build type

### A simple example

This uses FetchContent so no need to install Platformer separately first.

```cmake
cmake_minimum_required(VERSION 3.21)
project(Example LANGUAGES CXX)

include(FetchContent)

FetchContent_Declare(platformer
    GIT_REPOSITORY "https://github.com/Lecdi/platformer.git"
    GIT_TAG "main"
)
FetchContent_MakeAvailable(platformer)

platformer_add_executable(my_app GUI
    DISPLAY_NAME "MyApp"
    VERSION "1.2.3"
    ICONS "resources/my_app.png" "resources/my_app.ico"
)
target_sources(my_app PRIVATE "src/main.cpp")

platformer_add_application_package(my_package
    TARGETS my_app
    DISPLAY_NAME "MyPackage"
    VERSION "1.2.3"
    ICONS "resources/my_package.png" "resources/my_package.ico"
)
```

This example creates a standard CMake executable target called `my_app` and a packaging target called `my_package_package`. The exact behaviour depends on the selected platform definition. Using the built-in Windows definition, `my_app` becomes a GUI application with the appropriate Windows resources and metadata, while building `my_package_package` produces an NSIS installer (provided `makensis` is available).
