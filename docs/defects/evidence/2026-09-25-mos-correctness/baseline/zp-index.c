typedef unsigned char __attribute__((address_space(1))) zp_byte;

unsigned char load_zp(unsigned char index) {
  return ((zp_byte *)17)[index];
}

void store_zp(unsigned char index, unsigned char value) {
  ((zp_byte *)17)[index] = value;
}
