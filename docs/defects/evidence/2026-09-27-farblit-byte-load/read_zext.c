typedef unsigned char __attribute__((address_space(2))) far_byte;
unsigned int read_zext(void) { return *(volatile far_byte *)8355871UL; }
