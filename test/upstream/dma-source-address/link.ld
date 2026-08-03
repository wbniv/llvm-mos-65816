MEMORY {
  zp  (rw) : ORIGIN = 0x0020, LENGTH = 0x00e0
  ram (rw) : ORIGIN = 0x0200, LENGTH = 0x0200
  rom (rx) : ORIGIN = 0x8000, LENGTH = 0x8000
}
SECTIONS {
  .text : { *(.text .text.*) } > rom
  .linked_object 0x91a5 : { KEEP(*(.linked_object)) } > rom
  .rodata : { *(.rodata .rodata.*) } > rom
  .bss (NOLOAD) : { *(.bss .bss.*) } > ram
  __rc0 = 0x20; __rc1 = 0x21; __rc2 = 0x22; __rc3 = 0x23;
  __rc16 = 0x30; __rc20 = 0x34;
  __do_zero_bss = 0; __do_init_stack = 0;
}
