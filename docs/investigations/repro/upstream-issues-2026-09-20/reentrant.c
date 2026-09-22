__attribute__((reentrant, noinline)) unsigned force_frame(unsigned x) {
  volatile unsigned slots[2];
  slots[0] = x;
  slots[1] = x + 1;
  return slots[0] + slots[1];
}

__attribute__((noinline)) unsigned ordinary_frame(unsigned x) {
  volatile unsigned slots[2];
  slots[0] = x;
  slots[1] = x + 1;
  return slots[0] + slots[1];
}
