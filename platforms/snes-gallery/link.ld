/* 1 MiB LoROM: bank $00 code/header plus named asset banks $01..$1F. */

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
  rom10  : ORIGIN = 0x108000,   LENGTH = 0x8000
  rom11  : ORIGIN = 0x118000,   LENGTH = 0x8000
  rom12  : ORIGIN = 0x128000,   LENGTH = 0x8000
  rom13  : ORIGIN = 0x138000,   LENGTH = 0x8000
  rom14  : ORIGIN = 0x148000,   LENGTH = 0x8000
  rom15  : ORIGIN = 0x158000,   LENGTH = 0x8000
  rom16  : ORIGIN = 0x168000,   LENGTH = 0x8000
  rom17  : ORIGIN = 0x178000,   LENGTH = 0x8000
  rom18  : ORIGIN = 0x188000,   LENGTH = 0x8000
  rom19  : ORIGIN = 0x198000,   LENGTH = 0x8000
  rom1A  : ORIGIN = 0x1A8000,   LENGTH = 0x8000
  rom1B  : ORIGIN = 0x1B8000,   LENGTH = 0x8000
  rom1C  : ORIGIN = 0x1C8000,   LENGTH = 0x8000
  rom1D  : ORIGIN = 0x1D8000,   LENGTH = 0x8000
  rom1E  : ORIGIN = 0x1E8000,   LENGTH = 0x8000
  rom1F  : ORIGIN = 0x1F8000,   LENGTH = 0x8000
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
  .gallery_10 : { KEEP(*(.gallery_10)) } >rom10
  .gallery_11 : { KEEP(*(.gallery_11)) } >rom11
  .gallery_12 : { KEEP(*(.gallery_12)) } >rom12
  .gallery_13 : { KEEP(*(.gallery_13)) } >rom13
  .gallery_14 : { KEEP(*(.gallery_14)) } >rom14
  .gallery_15 : { KEEP(*(.gallery_15)) } >rom15
  .gallery_16 : { KEEP(*(.gallery_16)) } >rom16
  .gallery_17 : { KEEP(*(.gallery_17)) } >rom17
  .gallery_18 : { KEEP(*(.gallery_18)) } >rom18
  .gallery_19 : { KEEP(*(.gallery_19)) } >rom19
  .gallery_1A : { KEEP(*(.gallery_1A)) } >rom1A
  .gallery_1B : { KEEP(*(.gallery_1B)) } >rom1B
  .gallery_1C : { KEEP(*(.gallery_1C)) } >rom1C
  .gallery_1D : { KEEP(*(.gallery_1D)) } >rom1D
  .gallery_1E : { KEEP(*(.gallery_1E)) } >rom1E
  .gallery_1F : { KEEP(*(.gallery_1F)) } >rom1F

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
  FULL(rom10) FULL(rom11) FULL(rom12) FULL(rom13) FULL(rom14)
  FULL(rom15) FULL(rom16) FULL(rom17) FULL(rom18) FULL(rom19)
  FULL(rom1A) FULL(rom1B) FULL(rom1C) FULL(rom1D) FULL(rom1E) FULL(rom1F)
}
