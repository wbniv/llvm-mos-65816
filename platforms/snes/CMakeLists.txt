platform(snes COMPLETE PARENT common)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES snes.h TYPE INCLUDE)

# crt0: SNES bring-up + cartridge header, relocatably linked into crt0.o.
# #320 far-call runtime stubs, each in its own section so --gc-sections drops it
# from ROMs that don't reference it (near-only ROMs stay byte-identical):
#   call-near-from-far.s — (b) far->near mixed-banking thunk (__call_near_from_far)
#   call-indir-far.s      — (a) far indirect-call thunk     (__call_indir_far)
add_platform_object_file(snes-crt0-o crt0.o crt0.c header.s call-near-from-far.s call-indir-far.s)
# These thunks use 65816-only instructions (PEA/RTL/JML-long). The platform builds
# crt0 objects without -mcpu=mosw65816 (crt0.c emits its own 65816 preamble as
# .byte), so assemble just these pure-asm stubs for the 65816 — their bytes run on
# the SNES 5A22 like any other and are CPU-agnostic once linked.
set_source_files_properties(call-near-from-far.s call-indir-far.s
  PROPERTIES COMPILE_OPTIONS "-mcpu=mosw65816")

# Pull in the common startup pieces (soft-stack init, .data copy, .bss clear,
# exit-as-infinite-loop — there is no OS to return to on a console).
add_platform_library(snes-crt0)
merge_libraries(snes-crt0
  common-copy-data
  common-init-stack
  common-zero-bss
  common-exit-loop
)
