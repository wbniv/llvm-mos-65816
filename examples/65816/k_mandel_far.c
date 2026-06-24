// #321 Track 3a — fixed-point Mandelbrot computed into HIGH WRAM via far stores.
//
// The escape buffer lives at $7E2000 — high WRAM that the 65816 can reach ONLY through
// 24-bit (far / absolute-long) addressing; it is NOT in bank $00's $0000-$1FFF window.
// So filling it exercises the #320 far-STORE path on a real workload, and reading it
// back to CRC exercises the far-LOAD path. The CRC lands in corpus_result (a NEAR,
// low-WRAM global the harness samples), so a correct CRC proves the far store→load
// round-trip carried every byte. This is the motivating use case for far pointers: a
// framebuffer too big for low WRAM (Track 3b puts a 128×128 image here).
//
// Gate grid kept small (16×10, N=12) so the fill finishes inside the harness window —
// same grid + value as k_mandel.c, so the host reference is the SAME 0x820B.
//   mos-clang --config .../mos-snes.cfg -mcpu=mosw65816 [+mos-a16] -Os k_mandel_far.c
// Drive: dev/run.sh mandel-far.  See docs/plans/2026-06-24-snes-mandelbrot-beefy-demo.md (Track 3).
#include "mandel.h"

#define FAR __attribute__((address_space(2)))
#define GW 16
#define GH 10
#define GN 12

// Far buffer base: high WRAM $7E2000 (first free byte above the low-WRAM mirror).
static FAR uint8_t *const fb = (FAR uint8_t *)0x7E2000u;

volatile uint16_t corpus_result;     // near (low WRAM) — the harness reads this

int main(void) {
  int16_t dre = (int16_t)(MANDEL_REW / GW);
  int16_t dim = (int16_t)(MANDEL_IMW / GH);
  for (uint8_t j = 0; j < GH; j++) {
    int16_t ci = (int16_t)(MANDEL_IM0 + (int16_t)j * dim);
    for (uint8_t i = 0; i < GW; i++) {
      int16_t cr = (int16_t)(MANDEL_RE0 + (int16_t)i * dre);
      fb[(uint16_t)((uint16_t)j * GW + i)] = mandel_cell(cr, ci, GN);   // FAR STORE
    }
  }
  // CRC16-CCITT over the far buffer (far loads) — identical routine to mandel_crc,
  // inlined here because mandel_crc takes a near pointer.
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < (uint16_t)(GW * GH); k++) {
    crc ^= (uint16_t)((uint16_t)fb[k] << 8);                            // FAR LOAD
    for (uint8_t b = 0; b < 8; b++)
      crc = (crc & 0x8000) ? (uint16_t)((uint16_t)(crc << 1) ^ 0x1021)
                           : (uint16_t)(crc << 1);
  }
  corpus_result = crc;                 // == 0x820B (host reference, same grid as k_mandel)
  for (;;) {}
}
