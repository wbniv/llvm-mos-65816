// #321 Tier-1 realistic kernel — memcpy from a volatile source, in-place insertion
// sort of 8 x 16-bit values, then a rotate-xor checksum over the sorted array. The
// sort's inner loop compares and shuffles 16-bit array elements (native 16-bit
// compares + indirect loads/stores) with an 8-bit index; the hash threads a 16-bit
// value through rotates and XORs. Many 16-bit values live across the array.
// Differential: default == +mos-a16 == host on both emulators.
volatile unsigned short src[8] = {0x0050, 0x0010, 0x00F0, 0x0030, 0x0090, 0x0020, 0x00B0, 0x0001};
volatile unsigned short corpus_result;

int main(void) {
  unsigned short a[8];
  for (unsigned char i = 0; i < 8; i++)        // memcpy from volatile source
    a[i] = src[i];

  for (unsigned char i = 1; i < 8; i++) {       // insertion sort
    unsigned short key = a[i];
    unsigned char j = i;
    while (j > 0 && a[j - 1] > key) {
      a[j] = a[j - 1];
      j--;
    }
    a[j] = key;
  }

  unsigned short h = 0xACE1;                     // rotate-xor checksum of the sorted array
  for (unsigned char i = 0; i < 8; i++) {
    unsigned short rot = (unsigned short)(((unsigned)h << 5) | ((unsigned)h >> 11));
    h = (unsigned short)((unsigned)rot ^ (unsigned)a[i]);
  }
  corpus_result = h;
  for (;;) {}
}
