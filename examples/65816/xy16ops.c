// #321 xy16 DIRECT 16-BIT INDEX GATE — B2 legalizer: G_LOAD_ABS_IDX16 path.
//
// Verifies that an unmasked volatile unsigned short index (no compile-time 8-bit
// proof) triggers the B2 legalizer gate in tryAbsoluteIndexedAddressing, emitting
// G_LOAD_ABS_IDX16 and selecting LDXImag16 + LDAbsXIdx16.
//
// Array is 64 elements (byte offset 2*42=84 — KnownBits cannot prove ≤255 for a
// volatile load). Element arr[42] = 0x2A42 (low byte 0x42=index, high byte 0x2A=42).
//
// Expected corpus_result: 0x2A42 (host == default == +mos-xy16 on both emulators).
//
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 \
//     -Xclang -target-feature -Xclang +mos-xy16 -Os xy16ops.c
volatile unsigned short in_idx = 42;        // 0x002A — unmasked, B2 fires (volatile)
volatile unsigned short corpus_result;
unsigned short arr[64] = {
    [42] = 0x2A42,                          // index 42; 0x2A=42 in both bytes
};

int main(void) {
    corpus_result = arr[in_idx];            // G_LOAD_ABS_IDX16: rep#16/ldx/rep#32/lda arr,x
    for (;;) {
    }
}
