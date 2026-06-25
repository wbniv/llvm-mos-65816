/* SNES HiROM — banks $C0+ map the FULL 64 KiB ($C0:0000-$FFFF) of ROM contiguously,
 * so a single >32 KiB array fits (LoROM's 32 KiB $xx8000-$xxFFFF windows can't hold one).
 * This exists for libfixmath's ~200 KiB sin LUT (FIXMATH_SIN_LUT); see
 * docs/plans/2026-06-25-trig-accurate-sin-lut-hirom.md.
 *
 * Boot model — identical to platforms/snes(-far): reset sets PBR=$00, PC=<reset vec>.
 * In HiROM, $00:8000-$FFFF MIRRORS $C0:8000-$FFFF (ROM) and $00:FFE0-$FFFF mirrors the
 * vectors, so the unchanged crt0 (phk/plb -> DBR=0; near code+stack in bank $00) runs
 * exactly as on LoROM. NEAR code/rodata/data/header/vectors live at CPU $8000-$FFFF
 * (= $C0:8000-$FFFF). FAR rodata (.far_rodata) lives at $C10000+ (banks $C1..$C7),
 * reached only by 24-bit `lda [dp]` (R_MOS_ADDR24) — never via the bank-$00 mirror.
 *
 * Memory (CPU, emulation mode):
 *   $0000-$001F  imaginary (zero page) registers __rc0..__rc31
 *   $0020-$00FF  zero page (direct page)
 *   $0100-$01FF  hardware stack
 *   $0200-$1FFF  low WRAM (soft stack grows down from $2000; bss/heap up)
 *   $8000-$FFFF  near ROM  (= $C0:8000-$FFFF) — code, rodata, header, vectors
 *   $C10000-...  far ROM   (banks $C1..) — .far_rodata (the LUT), contiguous
 *
 * File image (HiROM): file offset = (bank-$C0)*0x10000 + (addr & 0xFFFF). So bank $C0
 * fills file $0000-$FFFF — its low half $C0:0000-$7FFF (file $0000-$7FFF) is an unused
 * pad, its high half $C0:8000-$FFFF (file $8000-$FFFF) holds near code + the header at
 * file $FFB0. Bank $C1 = file $10000-$1FFFF, etc. The map-mode byte ($FFD5) and the
 * header's file location ($FFB0, not LoROM's $7FB0) are owned/patched by
 * tools/snes-checksum.py --hirom.
 */

/* Imaginary (zero page) registers occupy $00-$1F. */
__rc0 = 0x00;
INCLUDE imag-regs.ld
ASSERT(__rc31 == 0x1f, "Inconsistent zero page map.")

/* Soft-stack top: grows down from the top of low WRAM. */
__stack = 0x2000;

MEMORY {
  zp       : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)   /* $0020-$00FF */
  ram      : ORIGIN = 0x0200,     LENGTH = 0x1E00                 /* $0200-$1FFF */
  /* $C0:0000-$7FFF — unused low half of bank $C0 (file $0000-$7FFF), padded so the
   * near window and header land at the HiROM file offsets. */
  rom_lopad : ORIGIN = 0xC00000,  LENGTH = 0x8000                 /* file $0000-$7FFF pad */
  /* Near-code window: CPU $8000-$FFAF (= $C0:8000), the bank-$00 ROM mirror. */
  rom      : ORIGIN = 0x8000,     LENGTH = 0x7FB0                 /* $8000-$FFAF near code */
  romhdr   : ORIGIN = 0xFFB0,     LENGTH = 0x0050                 /* $FFB0-$FFFF header+vectors */
  /* Far rodata across banks $C1..$C7 — contiguous (448 KiB), holds the LUT. */
  rom_far  : ORIGIN = 0xC10000,   LENGTH = 0x70000                /* $C10000-$C7FFFF far rodata */
}

REGION_ALIAS("c_readonly", rom)
REGION_ALIAS("c_writeable", ram)

SECTIONS {
  .text : { INCLUDE text-sections.ld } >c_readonly

  INCLUDE rodata.ld
  INCLUDE data.ld
  INCLUDE zp.ld
  INCLUDE bss.ld
  INCLUDE noinit.ld

  .ram (NOLOAD) : { *(.ram .ram.*) } >ram

  /* Far data in banks $C1+. A global tagged __attribute__((section(".far_rodata")))
   * and accessed through an address_space(2) pointer gets a $C1xxxx VMA, so its
   * R_MOS_ADDR24 relocation carries the bank byte and the far load is a true
   * cross-bank absolute-long / `lda [dp]`. */
  .far_rodata : { *(.far_rodata .far_rodata.*) } >rom_far

  /* Far CODE in bank $C1+ (parallels snes-far). */
  .far_text : { *(.far_text .far_text.*) } >rom_far

  /* Cartridge header + vectors at the top of bank $C0 ($FFB0-$FFFF == file $FFB0). */
  .snes_header 0xFFB0 : { KEEP(*(.snes_header)) } >romhdr

  .snes_vectors_native 0xFFE0 : {
    SHORT(0x0000) SHORT(0x0000)   /* $FFE0,$FFE2 reserved   */
    SHORT(0x0000) SHORT(irq)      /* $FFE4 COP,  $FFE6 BRK  */
    SHORT(0x0000) SHORT(nmi)      /* $FFE8 ABORT,$FFEA NMI  */
    SHORT(0x0000) SHORT(irq)      /* $FFEC -,    $FFEE IRQ  */
  } >romhdr

  .snes_vectors_emu 0xFFF0 : {
    SHORT(0x0000) SHORT(0x0000)   /* $FFF0,$FFF2 reserved   */
    SHORT(0x0000) SHORT(0x0000)   /* $FFF4 COP,  $FFF6 -    */
    SHORT(0x0000) SHORT(nmi)      /* $FFF8 ABORT,$FFFA NMI  */
    SHORT(_start) SHORT(irq)      /* $FFFC RESET,$FFFE IRQ  */
  } >romhdr
}

/* Raw HiROM image: $C0:0000-$7FFF pad, then near ($8000-$FFAF) + header ($FFB0-$FFFF)
 * filling the rest of bank $C0 (file $0000-$FFFF), then the far banks $C1.. */
OUTPUT_FORMAT {
  FULL(rom_lopad)
  FULL(rom)
  FULL(romhdr)
  FULL(rom_far)
}
