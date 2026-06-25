# snes-hirom — a child of the `snes` platform that differs ONLY in its linker
# script: a HiROM layout (banks $C0+ map the FULL 64 KiB contiguously) so a single
# array larger than LoROM's 32 KiB bank window can live in far rodata. Used for
# libfixmath's ~200 KiB sin LUT (FIXMATH_SIN_LUT). crt0, cartridge header, and
# snes.h are inherited from `snes` via PARENT — bring-up is identical to the default
# platform (HiROM's $00:8000/$00:FFxx mirrors make the reset path the same); only
# `link.ld` (below) relocates far rodata to banks $C1+ and pads bank $C0's low half.
# See docs/plans/2026-06-25-trig-accurate-sin-lut-hirom.md.
#
# Mirrors snes-far's "same runtime, different link script" idiom; the `platform()`
# macro generates mos-snes-hirom.cfg (lib path + @mos-snes.cfg). The image needs
# tools/snes-checksum.py --hirom (map-mode $21, header at file $FFB0).
platform(snes-hirom COMPLETE PARENT snes)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES link.ld TYPE LIB)
