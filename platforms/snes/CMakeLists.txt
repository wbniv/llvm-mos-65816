platform(snes COMPLETE PARENT common)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES snes.h TYPE INCLUDE)

# crt0: SNES bring-up + cartridge header, relocatably linked into crt0.o.
# call-near-from-far.s: the #320 far->near mixed-banking thunk (__call_near_from_far),
# in its own section so --gc-sections drops it from ROMs that make no far->near call
# (near-only ROMs stay byte-identical; it is pulled only when a JSL references it).
add_platform_object_file(snes-crt0-o crt0.o crt0.c header.s call-near-from-far.s)
# The far->near thunk uses 65816-only instructions (PEA/RTL). The platform builds
# crt0 objects without -mcpu=mosw65816 (crt0.c emits its own 65816 preamble as
# .byte), so assemble just this pure-asm stub for the 65816 — its bytes run on the
# SNES 5A22 like any other and are CPU-agnostic once linked.
set_source_files_properties(call-near-from-far.s PROPERTIES COMPILE_OPTIONS "-mcpu=mosw65816")

# Pull in the common startup pieces (soft-stack init, .data copy, .bss clear,
# exit-as-infinite-loop — there is no OS to return to on a console).
add_platform_library(snes-crt0)
merge_libraries(snes-crt0
  common-copy-data
  common-init-stack
  common-zero-bss
  common-exit-loop
)
