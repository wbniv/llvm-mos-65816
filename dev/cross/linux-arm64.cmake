# CMake toolchain file — cross-compile the llvm-mos HOST tools (clang/lld/llvm-*)
# from x86-64 Linux to aarch64 Linux (gnu). Used by dev/cross-toolchain.sh.
#
# The Ubuntu g++-aarch64-linux-gnu package ships its own sysroot, so we only point
# CMake at the cross g++; restrict find-root so configure tests resolve against the
# target sysroot, not the build host's /usr.
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CMAKE_C_COMPILER   aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_ASM_COMPILER aarch64-linux-gnu-gcc)

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
