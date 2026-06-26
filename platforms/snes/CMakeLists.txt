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
# call-near-from-far.s: the #320 far->near mixed-banking thunk (__call_near_from_far).
# call-indir-far.s: the #320 far function-pointer thunk (__call_indir_far + the
# __mos_far_target slot). Both live in their own sections so --gc-sections drops them
# from ROMs that make no far->near / far-indirect call (near-only ROMs stay
# byte-identical; each is pulled only when a JSL references it).
add_platform_object_file(snes-crt0-o crt0.o crt0.c header.s call-near-from-far.s call-indir-far.s)
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
set_source_files_properties(call-indir-far.s PROPERTIES COMPILE_OPTIONS "-mcpu=mosw65816")

# Pull in the common startup pieces (soft-stack init, .data copy, .bss clear,
# exit-as-infinite-loop — there is no OS to return to on a console).
add_platform_library(snes-crt0)
merge_libraries(snes-crt0
  common-copy-data
  common-init-stack
  common-zero-bss
  common-exit-loop
)

# #320 far runtime: __memset_far / __memcpy_far / __memmove_far (addrspace 2).
# Lives in the snes libc (libc.a) so it shadows common's — derived.cfg searches
# snes/lib before common/lib — and add_platform_library auto-merges common-c, so
# every existing near libc symbol still resolves from this one archive. mem-far.c
# is a separate archive member, so --gc-sections drops it from ROMs that make no
# far memop (near-only ROMs stay byte-identical; it is pulled only when the
# backend emits a __memset_far/__memcpy_far/__memmove_far call). Built for the
# 65816 (the far deref is indirect-long), +mos-a16 (a far pointer is a 32-bit
# value; the in-loop ptr++ only legalizes under a16), -fno-builtin (so the
# loop-idiom recognizer can't turn these very loops back into far
# llvm.memset/memcpy -> recursion into ourselves; generalizes common/c's
# -fno-builtin-memset), and -fno-lto (pins the far-store codegen at build time,
# mirroring crt0.c).
add_platform_library(snes-c mem-far.c)
set_source_files_properties(mem-far.c PROPERTIES COMPILE_OPTIONS
  "-fno-builtin;-mcpu=mosw65816;-fno-lto;-Xclang;-target-feature;-Xclang;+mos-a16")
