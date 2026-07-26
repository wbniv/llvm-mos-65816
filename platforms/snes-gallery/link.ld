/* 512 KiB LoROM: bank $00 code/header plus named asset banks $01..$0A.
 * Banks $0B..$0F are retained as explicit padding so the cartridge is a valid
 * power-of-two image and its header/checksum describe the complete 512 KiB ROM. */

__rc0 = 0x00;
INCLUDE imag-regs.ld
ASSERT(__rc31 == 0x1f, "Inconsistent zero page map.")
__stack = 0x2000;

MEMORY {
  zp     : ORIGIN = __rc31 + 1, LENGTH = 0x100 - (__rc31 + 1)
  ram    : ORIGIN = 0x0200,     LENGTH = 0x1E00
  rom    : ORIGIN = 0x008000,   LENGTH = 0x7FB0
  romhdr : ORIGIN = 0x00FFB0,   LENGTH = 0x0050
  rom01  : ORIGIN = 0x018000,   LENGTH = 0x8000
  rom02  : ORIGIN = 0x028000,   LENGTH = 0x8000
  rom03  : ORIGIN = 0x038000,   LENGTH = 0x8000
  rom04  : ORIGIN = 0x048000,   LENGTH = 0x8000
  rom05  : ORIGIN = 0x058000,   LENGTH = 0x8000
  rom06  : ORIGIN = 0x068000,   LENGTH = 0x8000
  rom07  : ORIGIN = 0x078000,   LENGTH = 0x8000
  rom08  : ORIGIN = 0x088000,   LENGTH = 0x8000
  rom09  : ORIGIN = 0x098000,   LENGTH = 0x8000
  rom0A  : ORIGIN = 0x0A8000,   LENGTH = 0x8000
  rom0B  : ORIGIN = 0x0B8000,   LENGTH = 0x8000
  rom0C  : ORIGIN = 0x0C8000,   LENGTH = 0x8000
  rom0D  : ORIGIN = 0x0D8000,   LENGTH = 0x8000
  rom0E  : ORIGIN = 0x0E8000,   LENGTH = 0x8000
  rom0F  : ORIGIN = 0x0F8000,   LENGTH = 0x8000
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

  .gallery_01 : { KEEP(*(.gallery_01)) } >rom01
  .gallery_02 : { KEEP(*(.gallery_02)) } >rom02
  .gallery_03 : { KEEP(*(.gallery_03)) } >rom03
  .gallery_04 : { KEEP(*(.gallery_04)) } >rom04
  .gallery_05 : { KEEP(*(.gallery_05)) } >rom05
  .gallery_06 : { KEEP(*(.gallery_06)) } >rom06
  .gallery_07 : { KEEP(*(.gallery_07)) } >rom07
  .gallery_08 : { KEEP(*(.gallery_08)) } >rom08
  .gallery_09 : { KEEP(*(.gallery_09)) } >rom09
  .gallery_0A : { KEEP(*(.gallery_0A)) } >rom0A
  .gallery_0B : { KEEP(*(.gallery_0B)) } >rom0B
  .gallery_0C : { KEEP(*(.gallery_0C)) } >rom0C
  .gallery_0D : { KEEP(*(.gallery_0D)) } >rom0D
  .gallery_0E : { KEEP(*(.gallery_0E)) } >rom0E
  .gallery_0F : { KEEP(*(.gallery_0F)) } >rom0F

  .snes_header 0x00FFB0 : { KEEP(*(.snes_header)) } >romhdr
  .snes_vectors_native 0x00FFE0 : {
    SHORT(0) SHORT(0) SHORT(0) SHORT(irq) SHORT(0) SHORT(nmi) SHORT(0) SHORT(irq)
  } >romhdr
  .snes_vectors_emu 0x00FFF0 : {
    SHORT(0) SHORT(0) SHORT(0) SHORT(0) SHORT(0) SHORT(nmi) SHORT(_start) SHORT(irq)
  } >romhdr
}

OUTPUT_FORMAT {
  FULL(rom) FULL(romhdr)
  FULL(rom01) FULL(rom02) FULL(rom03) FULL(rom04) FULL(rom05)
  FULL(rom06) FULL(rom07) FULL(rom08) FULL(rom09) FULL(rom0A)
  FULL(rom0B) FULL(rom0C) FULL(rom0D) FULL(rom0E) FULL(rom0F)
}
