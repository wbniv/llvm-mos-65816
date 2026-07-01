// Minimal repro: backend legalization crash under +mos-a16 / +mos-xy16 (OK on default 8-bit).
//   fatal error: unable to legalize instruction: G_ANYEXT (s32) = G_ANYEXT (s24)   [MIN]
//   (in the fuller Diffie-Hellman gate it manifests as: G_UNMERGE_VALUES (s64) -> 4x(s16))
// Trigger needs ALL of: a 32-bit multiply by a large constant, a & 0xFFFFF (20-bit) mask, a widen
// to uint64, and a 64-bit VARIABLE-shift loop consuming it. Removing any one compiles cleanly.
#include <stdint.h>
volatile uint16_t out;
volatile uint32_t vi;
int main(void){
  uint64_t e = (uint64_t)((vi * 2654435761u) & 0xFFFFFu);   // u32 mul + 20-bit mask, widened to u64
  uint16_t h = 0;
  while (e) { h ^= (uint16_t)e; e >>= 1; }                  // 64-bit variable-shift loop
  out = h;
  for (;;) {}
}
