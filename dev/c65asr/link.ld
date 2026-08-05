/* Bare-metal 65CE02 image for MAME's c65 driver: CPU $E000-$FFFF. */
__rc0 = 0xe0;
INCLUDE imag-regs.ld
ASSERT(__rc31 == 0xff, "Inconsistent zero page map.")
MEMORY {
  zp  : ORIGIN = 0x00,   LENGTH = 0xe0
  ram : ORIGIN = 0x0500, LENGTH = 0xd000 - 0x0500
  rom : ORIGIN = 0xe000, LENGTH = 0x1ffa
}
PROVIDE(irq = _irq_default);
PROVIDE(nmi = _irq_default);
REGION_ALIAS("c_readonly", rom)
REGION_ALIAS("c_writeable", ram)
SECTIONS { INCLUDE c.ld }
__stack = ORIGIN(ram) + LENGTH(ram);
OUTPUT_FORMAT { FULL(rom) SHORT(nmi) SHORT(_start) SHORT(_irq_default) }
