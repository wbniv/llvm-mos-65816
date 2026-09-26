unsigned char trunc_imag8_i1(unsigned char a, unsigned char x) {
  unsigned _BitInt(1) bit = x;
  if (bit)
    return a - x;
  return a;
}
