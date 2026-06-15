// #321 Tier-1 realistic kernel — CRC16-CCITT (XModem: poly 0x1021, init 0xFFFF, no
// reflection) over "123456789". Holds a 16-bit CRC accumulator live across nested
// loops while the loop counters are 8-bit (the 8/16 interleave that pressures the
// accumulator). Differential: default == +mos-a16 == host on both emulators.
// CRC16-CCITT("123456789") == 0x29B1 (the canonical check value).
volatile unsigned char data[9] = {'1', '2', '3', '4', '5', '6', '7', '8', '9'};
volatile unsigned short corpus_result;

int main(void) {
  unsigned short crc = 0xFFFF;
  for (unsigned char i = 0; i < 9; i++) {
    crc ^= (unsigned short)((unsigned short)data[i] << 8);
    for (unsigned char b = 0; b < 8; b++) {
      if (crc & 0x8000)
        crc = (unsigned short)((unsigned short)(crc << 1) ^ 0x1021);
      else
        crc = (unsigned short)(crc << 1);
    }
  }
  corpus_result = crc;     // 0x29B1
  for (;;) {}
}
