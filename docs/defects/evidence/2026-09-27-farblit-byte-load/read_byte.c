typedef unsigned char __attribute__((address_space(2))) far_byte;
unsigned char read_byte(void) { return *(volatile far_byte *)8355871UL; }
