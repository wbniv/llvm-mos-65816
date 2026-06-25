# CMake toolchain file — cross-compile the llvm-mos HOST tools (clang/lld/llvm-*)
# from x86-64 Linux to arm64 macOS, via osxcross. Used by dev/cross-toolchain.sh.
#
# REQUIRES osxcross built into the cross image (dev/Dockerfile.cross) against a
# user-supplied macOS SDK in dev/sdks/ — see dev/sdks/README.md. osxcross puts its
# arm64 wrapper compilers (oa64-clang / oa64-clang++) on PATH and sets the SDK sysroot
# internally, so this file only needs to name them. (Increment 3 of the cross-platform plan.)
set(CMAKE_SYSTEM_NAME Darwin)
set(CMAKE_SYSTEM_PROCESSOR arm64)
set(CMAKE_OSX_ARCHITECTURES arm64)

set(CMAKE_C_COMPILER   oa64-clang)
set(CMAKE_CXX_COMPILER oa64-clang++)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
