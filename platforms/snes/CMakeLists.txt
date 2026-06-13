platform(snes COMPLETE PARENT common)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES snes.h TYPE INCLUDE)

# crt0: SNES bring-up + cartridge header, relocatably linked into crt0.o.
add_platform_object_file(snes-crt0-o crt0.o crt0.c header.s)

# Pull in the common startup pieces (soft-stack init, .data copy, .bss clear,
# exit-as-infinite-loop — there is no OS to return to on a console).
add_platform_library(snes-crt0)
merge_libraries(snes-crt0
  common-copy-data
  common-init-stack
  common-zero-bss
  common-exit-loop
)
