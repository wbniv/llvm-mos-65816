// crt0native — native-mode crt0 contract gate (functional half).
//
// A DEFAULT (8-bit) build on purpose: the global load/add/store below select to
// the DBR-relative `abs` / R_MOS_ADDR16 path (ldx/lda/sta abs), whose effective
// address is DBR:addr. All near data lives in bank-0 low WRAM ($0200-$1FFF), so
// these reach the right bytes only when DBR=0 — the invariant `.init.50`
// establishes explicitly via phk/plb. A nonzero DBR would send them to the wrong
// bank and corpus_result would not read back 0x2345.
//
// (The native +mos-a16 path uses DBR-independent `long`/R_MOS_ADDR24 and would NOT
// exercise this; that is exactly why the gate is a default build.)
//
// See docs/plans/2026-06-18-321-native-mode-crt0-xy16.md and dev/crt0native.sh.

volatile unsigned short seed = 0x1234;
volatile unsigned short corpus_result;

int main(void) {
  corpus_result = seed + 0x1111;  // 0x2345 via 8-bit abs (DBR-relative) global access
  for (;;) __asm__ volatile("wai");
}
