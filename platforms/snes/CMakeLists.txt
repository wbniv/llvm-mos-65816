platform(snes COMPLETE PARENT common)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

# Install the umbrella snes.h plus every subsystem header it pulls in (the umbrella
# #includes them, so installing snes.h alone would break <snes.h> for SDK consumers).
install(FILES
  snes.h
  snes_mmio.h
  snes_ppu.h
  snes_dma.h
  snes_cpu.h
  snes_joypad.h
  snes_apu.h
  snes_wram.h
  TYPE INCLUDE)

# crt0: SNES bring-up + cartridge header, relocatably linked into crt0.o.
# call-near-from-far.s: the #320 far->near mixed-banking thunk (__call_near_from_far),
# in its own section so --gc-sections drops it from ROMs that make no far->near call
# (near-only ROMs stay byte-identical; it is pulled only when a JSL references it).
add_platform_object_file(snes-crt0-o crt0.o crt0.c header.s call-near-from-far.s)
# crt0.c's native-mode preamble (XCE/REP/SEP/PHK/PLB + a 16-bit LDX) and the
# far->near thunk (PEA/RTL) use 65816-only instructions, so build them with
# -mcpu=mosw65816. crt0.c ALSO needs -fno-lto: its preamble is MODULE-LEVEL inline
# asm, and under the platform's -flto the W65816 subtarget feature is not propagated
# to the module-asm assembler ("instruction requires FeatureW65816"), so the
# mnemonics would not assemble. crt0 has no C body to optimize, so dropping LTO for
# it is free, and the bytes are identical to the old hand-encoded .byte form. The
# .s thunk is assembled directly (no LTO bitcode), so it only needs -mcpu.
set_source_files_properties(crt0.c PROPERTIES COMPILE_OPTIONS "-mcpu=mosw65816;-fno-lto")
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
