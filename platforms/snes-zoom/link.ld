/* SNES LoROM, 256 KiB across EIGHT fixed banks ($00..$07) — the `snes` platform's 32 KiB layout
 * plus seven more ROM banks for the Mandelbrot ZOOM PYRAMID's per-level character data (#321 M2,
 * Phase 2). The 65816 boots in 6502-emulation mode; the DMA A-bus carries the source bank, so a
 * DMA can stream chr from any bank with no native-mode setup (proven: docs/plans/spikes/
 * 2026-06-25-321-mandel-zoom-phase2-bank-dma-probe.c). This mirrors platforms/snes-far/link.ld
 * (keep them in sync); the only differences are the rom_2..rom_7 regions, the per-level
 * .rodata_levelN sections, and the eight-region OUTPUT_FORMAT.
 *
 * Bank $00 ($8000-$FFFF): code + rodata (incl. pyramid LEVEL_0 + the MANDEL_PYR/_BANK/_HASH
 *   tables) + .data init image + header + vectors — the standard `snes` bank-0 layout.
 * Banks $01..$07 ($0N8000-$0NFFFF): one 128x128 pyramid level each, bank-aligned at $0N:8000
 *   (so its DMA addr16 is a constant $8000 and only the source bank varies). A 128x128 level is
 *   16 KiB, half a bank; the upper half is unused (the bank-aligned layout buys a constant addr16).
 */

/* Imaginary (zero page) registers occupy $00-$1F. */
__rc0 = 0x00;
INCLUDE imag-regs.ld
ASSERT(__rc31 == 0x1f, "Inconsistent zero page map.")

/* Soft-stack top: grows down from the top of low WRAM. */
__stack = 0x2000;

MEMORY {
  zp     : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)   /* $0020-$00FF */
  ram    : ORIGIN = 0x0200,     LENGTH = 0x1E00                 /* $0200-$1FFF */
  /* Near-code budget = $8000-$FFAF (0x7FB0 = 32688 B): bank $00 minus the fixed header+vectors
   * (kept in sync with platforms/snes/link.ld). Holds code + rodata (incl. LEVEL_0 + tables) +
   * the .data init image; an over-budget link fails loudly with "region 'rom' overflowed". */
  rom    : ORIGIN = 0x8000,     LENGTH = 0x7FB0                 /* $8000-$FFAF, near-code window (bank $00) */
  romhdr : ORIGIN = 0xFFB0,     LENGTH = 0x0050                 /* $FFB0-$FFFF, fixed header + vectors */
  rom_1  : ORIGIN = 0x018000,   LENGTH = 0x8000                 /* bank $01 — pyramid level 1 */
  rom_2  : ORIGIN = 0x028000,   LENGTH = 0x8000                 /* bank $02 — pyramid level 2 */
  rom_3  : ORIGIN = 0x038000,   LENGTH = 0x8000                 /* bank $03 — pyramid level 3 */
  rom_4  : ORIGIN = 0x048000,   LENGTH = 0x8000                 /* bank $04 — pyramid level 4 */
  rom_5  : ORIGIN = 0x058000,   LENGTH = 0x8000                 /* bank $05 — pyramid level 5 */
  rom_6  : ORIGIN = 0x068000,   LENGTH = 0x8000                 /* bank $06 — pyramid level 6 */
  rom_7  : ORIGIN = 0x078000,   LENGTH = 0x8000                 /* bank $07 — pyramid level 7 */
}

REGION_ALIAS("c_readonly", rom)
REGION_ALIAS("c_writeable", ram)

SECTIONS {
  /* Code + the .init/.call_main chain. _start (the reset entry) is the very start of .text. */
  .text : {
    INCLUDE text-sections.ld
  } >c_readonly

  /* .rodata (incl. pyramid LEVEL_0 + the MANDEL_PYR/_BANK/_HASH tables), .data (VMA RAM, init
   * image LMA in ROM), .zp, .bss, .noinit. */
  INCLUDE rodata.ld
  INCLUDE data.ld
  INCLUDE zp.ld
  INCLUDE bss.ld
  INCLUDE noinit.ld

  /* RAM-only scratch. */
  .ram (NOLOAD) : { *(.ram .ram.*) } >ram

  /* Per-level pyramid character data, one bank each (bank-aligned at $0N:8000). The bake tags
   * LEVEL_N (N>=1) with __attribute__((section(".rodata_levelN"))); LEVEL_0 stays in .rodata
   * (bank $00). Each level is the only thing in its bank's region, so it starts at $0N:8000 =>
   * a constant DMA addr16 of $8000, the source bank = N. */
  .rodata_level1 : { *(.rodata_level1 .rodata_level1.*) } >rom_1
  .rodata_level2 : { *(.rodata_level2 .rodata_level2.*) } >rom_2
  .rodata_level3 : { *(.rodata_level3 .rodata_level3.*) } >rom_3
  .rodata_level4 : { *(.rodata_level4 .rodata_level4.*) } >rom_4
  .rodata_level5 : { *(.rodata_level5 .rodata_level5.*) } >rom_5
  .rodata_level6 : { *(.rodata_level6 .rodata_level6.*) } >rom_6
  .rodata_level7 : { *(.rodata_level7 .rodata_level7.*) } >rom_7

  /* Cartridge header at the top of bank $00 ($FFB0-$FFDF). */
  .snes_header 0xFFB0 : {
    KEEP(*(.snes_header))
  } >romhdr

  /* Native-mode interrupt vectors ($FFE0-$FFEF). Unused in emulation mode; pointed at the stubs. */
  .snes_vectors_native 0xFFE0 : {
    SHORT(0x0000) SHORT(0x0000)   /* $FFE0,$FFE2 reserved   */
    SHORT(0x0000) SHORT(irq)      /* $FFE4 COP,  $FFE6 BRK  */
    SHORT(0x0000) SHORT(nmi)      /* $FFE8 ABORT,$FFEA NMI  */
    SHORT(0x0000) SHORT(irq)      /* $FFEC -,    $FFEE IRQ  */
  } >romhdr

  /* Emulation-mode interrupt vectors ($FFF0-$FFFF). RESET is the boot entry. */
  .snes_vectors_emu 0xFFF0 : {
    SHORT(0x0000) SHORT(0x0000)   /* $FFF0,$FFF2 reserved   */
    SHORT(0x0000) SHORT(0x0000)   /* $FFF4 COP,  $FFF6 -    */
    SHORT(0x0000) SHORT(nmi)      /* $FFF8 ABORT,$FFFA NMI  */
    SHORT(_start) SHORT(irq)      /* $FFFC RESET,$FFFE IRQ  */
  } >romhdr
}

/* Emit the raw 256 KiB ROM image (headerless .sfc): bank $00 (code/rodata/data then header+vectors)
 * then banks $01..$07. FULL() pads each region to its LENGTH; rom (0x7FB0) + romhdr (0x0050) =
 * 0x8000, so file $00000-$07FFF == bank $00 and file $0N0000-$0NFFFF == bank $0N — the LoROM
 * mapping, unchanged. 8 x 0x8000 = 0x40000 = 256 KiB. */
OUTPUT_FORMAT {
  FULL(rom)
  FULL(romhdr)
  FULL(rom_1)
  FULL(rom_2)
  FULL(rom_3)
  FULL(rom_4)
  FULL(rom_5)
  FULL(rom_6)
  FULL(rom_7)
}
