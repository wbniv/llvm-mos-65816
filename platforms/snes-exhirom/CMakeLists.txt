# snes-exhirom — a child of the `snes` platform that differs ONLY in its linker
# script: a 48 Mbit (6 MiB) EXTENDED-map cartridge, official map mode $25.
#
# Ordinary LoROM and HiROM expose at most 4 MiB. ExHiROM splits the image in two:
# file $000000-$3FFFFF is reached through banks $C0-$FF, and file $400000 upward
# through banks $40-$7D. The header and the reset vector the CPU fetches from
# $00:FFFC therefore live at file $40FFB0/$40FFFC — in the SECOND region — and
# the near-code window $00:8000-$FFFF is file $408000-$40FFFF. crt0, the
# cartridge header and snes.h are inherited from `snes` via PARENT: bring-up is
# identical to the default platform, because crt0 only needs $00:8000-$FFFF to
# be ROM, which it is under every one of these mappings.
#
# link.ld is GENERATED from the authoritative address model — regenerate with
#   python3 tools/snes-cartcanary.py emit-platform \
#     --mapping exhirom --size 6M --name snes-exhirom --install <sdk-install>
# and test/snes/cartridge-maps/test_snes_cartcanary.py asserts the checked-in
# copy is byte-identical to what the model produces, so the platform and the
# generator cannot drift.
#
# The image needs tools/snes-checksum.py --mapping exhirom (map mode $25, header
# at file $40FFB0, ROM-size byte $0D for the 4+2 MiB mirrored logical 8 MiB, and
# the compound-size mirrored checksum).
#
# Mirrors snes-far/snes-hirom's "same runtime, different link script" idiom; the
# `platform()` macro generates mos-snes-exhirom.cfg (lib path + @mos-snes.cfg).
# Plan: docs/plans/2026-07-30-exhirom-video-boundary-test.md.
platform(snes-exhirom COMPLETE PARENT snes)

if(NOT CMAKE_CROSSCOMPILING)
  return()
endif()

install(FILES link.ld TYPE LIB)
