// #321 xy16 CROSS-CALL BOUNDARY GATE — a genuinely-16-bit index value held LIVE across a
// clobbering noinline call, then used as an index again AFTER the call.
//
// This is the one xy16 call-boundary case no prior test covers: xy16basic/ops/indiry index
// WITHIN a function; xy16spillr is recursive but the cross-call live value is Ac16, not an
// index. Here a 16-bit index (0x0102) must survive a JSR. The ABI narrows X to 8-bit at the
// call (MOSInsertREPSEP requiredXWidth -> XW_X8 for isCall; the inserted `sep #$10` ZEROES
// X's high byte — the seed-247/445 bug class). So the value must be spilled (RA, while X is
// still 16-bit) before that sep and restored after — X16/Y16 are caller-saved
// (MOS_CSR_RegMask clobbers them). If that chain is wrong, the post-call indexed read uses a
// zeroed high byte (idx 0x0102 -> 0x0002) and reads the WRONG element -> the 4-way
// differential (host == default == +mos-a16 == +mos-xy16, both emulators) catches it.
//
// LTO-narrowing defeat (the crux): `idx` is read from table[].next, a NON-volatile global
// whose initializer holds 0x0102 (>255). KnownBits cannot prove idx <= 255 (table[0].next is
// 0x0102), so it stays a genuine 16-bit index (G_LOAD_ABS_IDX16 -> Xc16) and does NOT narrow
// to 8-bit X under --config LTO. The volatile `in_start` seed prevents the whole chase from
// constant-folding to a compile-time index. (Contrast xy16ops.c's volatile in_idx=42, which
// LTO CAN prove fits a byte.) A pre-call indexed use forces idx into the 16-bit-index path
// BEFORE the call so the value is genuinely live across it; the post-call use is the one the
// differential asserts. The two reads are XOR'd so both the pre- and post-call indexings are
// observable: 0x1234 ^ 0x6C6E = 0x7E5A.
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 \
//     -Xclang -target-feature -Xclang +mos-xy16 -Os xy16call.c
struct Node { unsigned short next; unsigned short pad; };

// table[0].next = 0x0102 (>255 -> idx is genuinely 16-bit, survives LTO). The rest are 0, so
// the optimizer sees idx in {0x0102, 0} -> max 0x0102, cannot narrow to 8-bit.
struct Node table[0x140] = { [0] = { .next = 0x0102 } };

// The two indexed arrays. pre_arr/post_arr[0x0102] are the load-bearing elements; element
// 0x0002 (where a high-byte-zeroed index would land) is left 0 so a truncation mismatches.
unsigned short pre_arr[0x140]  = { [0x0102] = 0x1234 };
unsigned short post_arr[0x140] = { [0x0102] = 0x6C6E };

volatile unsigned short in_start = 0;     // runtime seed -> defeats const-fold of the chase
volatile unsigned short corpus_result;

// noinline call between the index's first and second use. The JSR alone narrows X to 8-bit at
// the boundary (the hazard); touching a volatile keeps the call from being optimized away.
__attribute__((noinline)) static void clobber(void) {
  static volatile unsigned char sink;
  sink = (unsigned char)(sink + 1);
}

int main(void) {
  unsigned short idx = table[in_start & 0x13F].next;   // genuine 16-bit index = 0x0102
  unsigned short a = pre_arr[idx];                      // indexed use BEFORE call (idx -> Xc16)
  clobber();                                            // call: X narrowed to 8; idx must survive
  unsigned short b = post_arr[idx];                     // indexed use AFTER call (idx -> Xc16)
  corpus_result = (unsigned short)((unsigned)a ^ (unsigned)b);  // 0x1234 ^ 0x6C6E = 0x7E5A
  for (;;) __asm__ volatile("wai");
}
