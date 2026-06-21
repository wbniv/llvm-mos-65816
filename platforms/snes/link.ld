/* SNES LoROM, 32 KiB single fixed bank ($00). The 65816 boots in 6502-emulation
 * mode, so this links plain mos (6502) code into a bootable .sfc image.
 *
 * Bank $00 memory map (emulation mode):
 *   $0000-$001F  imaginary (zero page) registers __rc0..__rc31
 *   $0020-$00FF  zero page (direct page)
 *   $0100-$01FF  hardware stack
 *   $0200-$1FFF  low WRAM (soft stack grows down from $2000; bss/heap up)
 *   $8000-$FFFF  cartridge ROM (LoROM) — code, rodata, header, vectors
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
  /* Near-code budget = $8000-$FFAF (0x7FB0 = 32688 B): the LoROM bank minus the
   * fixed cartridge header + vectors carved into `romhdr` below. Code + rodata +
   * the .data init-image LMA must fit here; an over-budget link fails loudly with
   * "region 'rom' overflowed by N bytes" (remediation: move code to .far_text /
   * data to bank $01 on the snes-far platform, or shrink). */
  rom    : ORIGIN = 0x8000,     LENGTH = 0x7FB0                 /* $8000-$FFAF, near-code window */
  romhdr : ORIGIN = 0xFFB0,     LENGTH = 0x0050                 /* $FFB0-$FFFF, fixed header + vectors */
}

REGION_ALIAS("c_readonly", rom)
REGION_ALIAS("c_writeable", ram)

SECTIONS {
  /* Code + the .init/.call_main chain. _start (the reset entry) is the very
   * start of .text. */
  .text : {
    INCLUDE text-sections.ld
  } >c_readonly

  /* .rodata, .data (VMA in RAM, init image LMA in ROM), .zp, .bss, .noinit. */
  INCLUDE rodata.ld
  INCLUDE data.ld
  INCLUDE zp.ld
  INCLUDE bss.ld
  INCLUDE noinit.ld

  /* RAM-only scratch. */
  .ram (NOLOAD) : { *(.ram .ram.*) } >ram

  /* Cartridge header at the top of the bank ($FFB0-$FFDF). */
  .snes_header 0xFFB0 : {
    KEEP(*(.snes_header))
  } >romhdr

  /* Native-mode interrupt vectors ($FFE0-$FFEF). Unused while in emulation
   * mode, but pointed at the stub handlers for safety. */
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

/* Emit the raw 32 KiB ROM image (headerless .sfc): the near-code window then the
 * fixed header+vectors. 0x7FB0 + 0x0050 = 0x8000, contiguous, so the bytes are
 * identical to a single FULL(rom) over the whole bank. */
OUTPUT_FORMAT {
  FULL(rom)
  FULL(romhdr)
}
