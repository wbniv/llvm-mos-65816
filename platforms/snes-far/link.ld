/* SNES LoROM, 64 KiB across TWO fixed banks ($00 + $01) — the snes platform's
 * 32 KiB layout plus a second ROM bank for far (24-bit) data. The 65816 boots in
 * 6502-emulation mode; absolute-long addressing carries the bank byte and works
 * in emulation mode, so a far read can reach bank $01 with no native-mode setup.
 * #320 Increment 2b. This mirrors platforms/snes/link.ld (keep them in sync);
 * the only differences are the `rom_1` region, the `.far_rodata` section, and the
 * two-region OUTPUT_FORMAT.
 *
 * Bank $00 memory map (emulation mode):
 *   $0000-$001F  imaginary (zero page) registers __rc0..__rc31
 *   $0020-$00FF  zero page (direct page)
 *   $0100-$01FF  hardware stack
 *   $0200-$1FFF  low WRAM (soft stack grows down from $2000; bss/heap up)
 *   $8000-$FFFF  cartridge ROM (LoROM) — code, rodata, header, vectors
 * Bank $01:
 *   $018000-$01FFFF  cartridge ROM (LoROM) — far rodata (.far_rodata)
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
  /* Near-code budget = $8000-$FFAF (0x7FB0 = 32688 B): bank $00 minus the fixed
   * header+vectors carved into `romhdr` (kept in sync with platforms/snes/link.ld).
   * An over-budget link fails loudly with "region 'rom' overflowed by N bytes"
   * (remediation: move code to .far_text / data to .far_rodata in bank $01, or shrink). */
  rom    : ORIGIN = 0x8000,     LENGTH = 0x7FB0                 /* $8000-$FFAF, near-code window (bank $00) */
  romhdr : ORIGIN = 0xFFB0,     LENGTH = 0x0050                 /* $FFB0-$FFFF, fixed header + vectors */
  rom_1  : ORIGIN = 0x018000,   LENGTH = 0x8000                 /* $018000-$01FFFF, bank $01 (far) */
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

  /* Far data in bank $01. A global tagged __attribute__((section(".far_rodata")))
   * and accessed through an address_space(2) pointer gets VMA $018xxx, so its
   * R_MOS_ADDR24 relocation resolves with bank byte $01 and the far load is a
   * true cross-bank absolute-long ($018xxx — never zero-bank-relaxable). */
  .far_rodata : { *(.far_rodata .far_rodata.*) } >rom_1

  /* Far CODE in bank $01 (#320 Inc 4). A function tagged
   * __attribute__((section(".far_text"))) gets VMA $018xxx, so a call to it
   * relocates as R_MOS_ADDR24 and is emitted as JSL $018xxx (the compiler also
   * gives such a function an RTL return). It must be a leaf (or call only other
   * far functions): a near JSR out of bank $01 would not switch the program bank. */
  .far_text : { *(.far_text .far_text.*) } >rom_1

  /* Cartridge header at the top of bank $00 ($FFB0-$FFDF). */
  .snes_header 0xFFB0 : {
    KEEP(*(.snes_header))
  } >romhdr

  /* Native-mode interrupt vectors ($FFE0-$FFEF). Unused while in emulation
   * mode, but pointed at the stub handlers for safety. */
  .snes_vectors_native 0xFFE0 : {
    SHORT(0x0000) SHORT(0x0000)   /* $FFE0,$FFE2 reserved   */
    SHORT(cop)    SHORT(brk)      /* $FFE4 COP,  $FFE6 BRK  */
    SHORT(0x0000) SHORT(nmi)      /* $FFE8 ABORT,$FFEA NMI  */
    SHORT(0x0000) SHORT(irq)      /* $FFEC -,    $FFEE IRQ  */
  } >romhdr

  /* Emulation-mode interrupt vectors ($FFF0-$FFFF). RESET is the boot entry. */
  .snes_vectors_emu 0xFFF0 : {
    SHORT(0x0000) SHORT(0x0000)   /* $FFF0,$FFF2 reserved   */
    SHORT(cop)    SHORT(0x0000)   /* $FFF4 COP,  $FFF6 -    */
    SHORT(0x0000) SHORT(nmi)      /* $FFF8 ABORT,$FFFA NMI  */
    SHORT(_start) SHORT(irq)      /* $FFFC RESET,$FFFE IRQ  */
  } >romhdr
}

/* Emit the raw 64 KiB ROM image (headerless .sfc): bank $00 then bank $01.
 * FULL() pads each region to its full LENGTH; rom (0x7FB0) + romhdr (0x0050) =
 * 0x8000, so file 0x0000-0x7FFF == bank $00 (code/rodata/data then header+vectors)
 * and file 0x8000-0xFFFF == bank $01 (CPU $018000) — the LoROM mapping, unchanged. */
OUTPUT_FORMAT {
  FULL(rom)
  FULL(romhdr)
  FULL(rom_1)
}
