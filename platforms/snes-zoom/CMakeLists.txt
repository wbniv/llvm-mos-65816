# snes-zoom — a child of the `snes` platform that differs ONLY in its linker script: a 256 KiB
# LoROM (banks $00..$07) so the Mandelbrot zoom pyramid can stash one 128x128 level per bank and
# DMA the current level on a level-swap (#321 M2, Phase 2). crt0, cartridge header, and snes.h are
# inherited from `snes` via PARENT, so the bring-up is identical to the default platform — only
# `link.ld` (below) adds banks $01..$07.
#
# Mirrors platforms/snes-far (the 2-bank child) and the SDK's "same runtime, different link script"
# idiom (mos-platform/atari2600-4k).
platform(snes-zoom COMPLETE PARENT snes)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES link.ld TYPE LIB)
