# snes-far — a child of the `snes` platform that differs ONLY in its linker
# script: a 64 KiB LoROM (banks $00 + $01) so a far (24-bit) pointer read can
# cross a real ROM bank boundary (#320 Increment 2b). crt0, cartridge header,
# and snes.h are inherited from `snes` via PARENT, so the bring-up is identical
# to the default platform — only `link.ld` (below) adds bank $01.
#
# Mirrors the SDK's own "same runtime, different link script" idiom (see
# mos-platform/atari2600-4k: a COMPLETE child that overrides just link.ld).
platform(snes-far COMPLETE PARENT snes)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES link.ld TYPE LIB)
