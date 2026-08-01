// #320 packed-24 (addrspace 3) — Task A: realistic STATIC far-pointer TABLE shape.
//
// A link-time-initialized table of far pointers to 8 distinct constants in ROM bank
// $01 (.far_rodata -> rom_1 @ $018000), walked at runtime in a 16-bit-ambient loop and
// the derefs summed. This is the realistic "banked-asset / jump table" shape the whole
// packed-24 opt exists for.
//
// Why this fixture (beyond Increment B's packed24_e2e.c): Increment B proved the
// RUNTIME store/load/deref of a single packed slot + the UNinitialized table size
// (incA_storage.c). It did NOT prove a STATIC-INITIALIZED packed table — i.e. that the
// link-time 3-byte relocation writes each entry's bank byte ($01) correctly into the
// 24-bit (.rodata) slot. If a bank byte were dropped in the 3-byte packing, an entry
// would deref bank $00 (different bytes) -> the sum would not be 0xA5.
//
// Also the measurement fixture: compile with -DUSE_FAR for the 4-byte AS_Far table
// (32 B) vs the default packed AS_FarPacked table (24 B) — the apples-to-apples storage
// delta at N=8. See dev/measure-packed24.sh for the N-sweep + net/break-even.
//
//   mos-clang --config .../mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os packed24_table.c
// Built (64 KiB) + booted in MAME and bsnes-jg by dev/packed24_table.sh (dev/run.sh packed24_table).

#define FAR    __attribute__((address_space(2)))
#define PACKED __attribute__((address_space(3)))

#ifdef USE_FAR
#  define SLOT FAR        // 4-byte far pointers (the storage baseline)
#else
#  define SLOT PACKED     // 3-byte packed far pointers (under test)
#endif

// 8 distinct far constants in bank $01. volatile -> the far loads actually execute.
#define T(name, val) \
  volatile const FAR unsigned char name __attribute__((section(".far_rodata"))) = (val);
T(a0, 0x01) T(a1, 0x02) T(a2, 0x04) T(a3, 0x08)
T(a4, 0x10) T(a5, 0x20) T(a6, 0x40) T(a7, 0x80)

// The static far-pointer table under test. The explicit (SLOT*) cast is REQUIRED for
// the packed case (clang rejects an implicit AS2->AS3 narrowing in an initializer) and
// is a no-op for the far case. Each packed entry is a 3-byte link-time relocation that
// must carry the bank byte. `volatile` on the elements is the load-bearing detail: the
// targets are const with known initializers, so without it LTO constant-folds the whole
// walk away (main collapses to `corpus_result = 0xA5`) and never reads the table — the
// volatile element load keeps the pointer opaque so the far derefs actually execute (the
// only way the bank-byte fidelity point is exercised). Storage is unchanged (24 vs 32).
const SLOT unsigned char *const volatile table[8] = {
    (const SLOT unsigned char *)&a0, (const SLOT unsigned char *)&a1,
    (const SLOT unsigned char *)&a2, (const SLOT unsigned char *)&a3,
    (const SLOT unsigned char *)&a4, (const SLOT unsigned char *)&a5,
    (const SLOT unsigned char *)&a6, (const SLOT unsigned char *)&a7,
};

// Sampled by the harness from the $7E WRAM mirror. 0x01|..|0x80 = 0xFF; ^0x5A = 0xA5.
volatile FAR unsigned char corpus_result;

int main(void) {
  unsigned s = 0;
  for (unsigned i = 0; i < 8; i++)
    s += *(const FAR unsigned char *)table[i]; // load entry (3 or 4 B) -> p2 -> far deref bank $01
  corpus_result = (unsigned char)s ^ 0x5A;     // 0xFF ^ 0x5A = 0xA5
  for (;;) __asm__ volatile("wai");
}
