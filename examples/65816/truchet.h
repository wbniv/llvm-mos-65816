// #29b SNES compiler stress-test — PACKED BITFIELD Truchet / "10 PRINT" maze kernel.
//
// SINGLE SOURCE OF TRUTH shared by the on-target program (examples/snes/truchet.c), the corpus slice
// (examples/snes/corpus/truchet_sim.c) and the host oracle (tools/truchet-sim.c).
//
// Why this demo exists: no Round-1 demo (nor #21/#22/#26/#29a) uses C BITFIELDS. This one packs every
// cell's state into a sub-word bitfield struct and reads/writes those fields thousands of times, so it
// exercises the bitfield INSERT / EXTRACT codegen — the mask/shift/merge sequences (`and`/`ora`/`asl`/
// `lsr`) the compiler emits to poke a few bits inside a word. A classic miscompile nest (wrong mask,
// off-by-one shift, sign-extension of an unsigned field, cross-field clobber).
//
// LAYOUT NOTE (load-bearing for the differential): C bitfield packing uses the declared type as the
// storage unit, and `unsigned` is 32-bit on the host but 16-bit on llvm-mos — different unit -> different
// struct bytes. We therefore declare the fields as **uint16_t : n**, a 16-bit unit on BOTH platforms, so
// the layout is identical and the bytes match. The gate then folds the **extracted field VALUES** (not
// raw memory), so a gate divergence means a real insert/extract miscompile — never a legal layout
// difference (which we would isolate + fix upstream, not work around).
#ifndef TRUCHET_H
#define TRUCHET_H

#include <stdint.h>

// Per-cell packed state. 16 bits total (uint16_t storage unit on host and target alike).
typedef struct {
  uint16_t orient : 1;   // diagonal: 0 = '\', 1 = '/'   (the Truchet tile)
  uint16_t style  : 1;   // 0 = straight diagonal, 1 = quarter-arc tile variant
  uint16_t hue    : 3;   // colour band 0..7
  uint16_t phase  : 2;   // colour-cycle phase 0..3
  uint16_t mark   : 1;   // wavefront flag
  uint16_t energy : 4;   // decaying wave energy 0..15  (a wide-ish sub-word field on purpose)
  uint16_t spare  : 4;
} Cell;

// xorshift16 PRNG (shared shape with the other demos).
static uint16_t tr_rng = 0xACE1u;
static inline uint16_t tr_rand(void) {
  tr_rng ^= (uint16_t)(tr_rng << 7);
  tr_rng ^= (uint16_t)(tr_rng >> 9);
  tr_rng ^= (uint16_t)(tr_rng << 8);
  return tr_rng;
}

// Build a cell by INSERTING six fields from a PRNG word — the bitfield-insert path.
static inline Cell tr_make(uint16_t r) {
  Cell c;
  c.orient = (uint16_t)(r & 1u);
  c.style  = (uint16_t)((r >> 1) & 1u);
  c.hue    = (uint16_t)((r >> 2) & 7u);
  c.phase  = (uint16_t)((r >> 5) & 3u);
  c.mark   = (uint16_t)((r >> 7) & 1u);
  c.energy = (uint16_t)((r >> 8) & 15u);
  c.spare  = 0u;
  return c;
}

#define TR_GW 16u    /* grid width  */
#define TR_GH 14u    /* grid height */

// One simulation step over a W*H grid of Cells: a decaying "wave" spreads. Each cell EXTRACTS its own
// and its four neighbours' `energy`/`mark` fields, computes a new energy (max of decayed neighbours),
// then INSERTS updated `energy`, `mark` and an advanced `phase`. Reads + writes are all through bitfields
// in the grid array -> sustained insert/extract. `orient`/`style`/`hue` are preserved (read-modify-write
// must not clobber the other fields — exactly the cross-field-clobber bug a bitfield codegen error makes).
static inline void tr_step(Cell *g, uint8_t w, uint8_t h) {
  for (uint8_t y = 0; y < h; y++) {
    for (uint8_t x = 0; x < w; x++) {
      uint16_t idx = (uint16_t)((uint16_t)y * w + x);
      uint8_t e = (uint8_t)g[idx].energy;                       // extract
      // neighbour max-decay (toroidal)
      uint8_t xl = (uint8_t)((x == 0) ? (w - 1) : (x - 1));
      uint8_t xr = (uint8_t)((x + 1u < w) ? (x + 1) : 0);
      uint8_t yu = (uint8_t)((y == 0) ? (h - 1) : (y - 1));
      uint8_t yd = (uint8_t)((y + 1u < h) ? (y + 1) : 0);
      uint8_t n0 = (uint8_t)g[(uint16_t)y * w + xl].energy;     // extract neighbours
      uint8_t n1 = (uint8_t)g[(uint16_t)y * w + xr].energy;
      uint8_t n2 = (uint8_t)g[(uint16_t)yu * w + x].energy;
      uint8_t n3 = (uint8_t)g[(uint16_t)yd * w + x].energy;
      uint8_t nmax = n0;
      if (n1 > nmax) nmax = n1;
      if (n2 > nmax) nmax = n2;
      if (n3 > nmax) nmax = n3;
      uint8_t spread = (uint8_t)((nmax > 0) ? (nmax - 1) : 0);  // neighbour energy decays by 1 as it spreads
      uint8_t ne = (uint8_t)((e > spread) ? (e - 1) : spread);  // own energy decays; else inherit spread
      if (ne > 15) ne = 15;
      g[idx].energy = (uint16_t)(ne & 15u);                     // INSERT (must not clobber orient/hue/...)
      g[idx].mark   = (uint16_t)((ne >= 8u) ? 1u : 0u);         // INSERT
      g[idx].phase  = (uint16_t)((g[idx].phase + 1u) & 3u);     // read-modify-write a 2-bit field
    }
  }
}

// CRC16-CCITT (XModem) — identical routine to the other demos.
static inline uint16_t tr_crc(const uint8_t *p, uint16_t len) {
  uint16_t crc = 0xFFFF;
  for (uint16_t k = 0; k < len; k++) {
    crc ^= (uint16_t)((uint16_t)p[k] << 8);
    for (uint8_t b = 0; b < 8; b++) {
      if (crc & 0x8000) crc = (uint16_t)((uint16_t)(crc << 1) ^ 0x1021);
      else              crc = (uint16_t)(crc << 1);
    }
  }
  return crc;
}

// Fiery/cool palette for a cell: hue (0..7) picks a base colour band, energy (0..15) brightens it.
// Shared so the on-console CGRAM matches.
static inline void tr_palette(uint8_t hue, uint8_t energy, uint8_t *r5, uint8_t *g5, uint8_t *b5) {
  uint8_t t = (uint8_t)((unsigned)energy * 31u / 15u);          // brightness 0..31
  switch (hue & 7u) {
    case 0:  *r5 = t; *g5 = (uint8_t)(t >> 1); *b5 = 0; break;          // amber
    case 1:  *r5 = 0; *g5 = t; *b5 = (uint8_t)(t >> 1); break;         // teal
    case 2:  *r5 = (uint8_t)(t >> 1); *g5 = 0; *b5 = t; break;         // violet
    case 3:  *r5 = t; *g5 = t; *b5 = 0; break;                        // yellow
    case 4:  *r5 = 0; *g5 = t; *b5 = t; break;                        // cyan
    case 5:  *r5 = t; *g5 = 0; *b5 = (uint8_t)(t >> 1); break;        // magenta-ish
    case 6:  *r5 = (uint8_t)(t >> 1); *g5 = t; *b5 = 0; break;        // lime
    default: *r5 = t; *g5 = t; *b5 = t; break;                        // white
  }
}

#define TR_GATE_STEPS 24u

// Differential anchor: seed a TR_GW x TR_GH grid from the PRNG (one tr_make per cell), light a few
// energy sources, run TR_GATE_STEPS of tr_step, then fold the EXTRACTED fields of every cell
// (orient/style/hue/phase/mark/energy packed back into a byte) through CRC16. Folding extracted values
// (not raw struct bytes) makes it a pure insert/extract test, robust to any legal packing detail. Far-
// pointer-free static grid -> full 5-way bar. Thousands of bitfield accesses, finishes well inside budget.
static inline uint16_t tr_gate_crc(void) {
  static Cell g[TR_GW * TR_GH];
  tr_rng = 0xACE1u;
  for (uint8_t y = 0; y < (uint8_t)TR_GH; y++)
    for (uint8_t x = 0; x < (uint8_t)TR_GW; x++)
      g[(uint16_t)y * TR_GW + x] = tr_make(tr_rand());
  // a few full-energy sources
  g[0].energy = 15u;
  g[(uint16_t)(TR_GH / 2) * TR_GW + TR_GW / 2].energy = 15u;
  g[(uint16_t)(TR_GH - 1) * TR_GW + (TR_GW - 1)].energy = 15u;

  uint16_t h = 0;
  for (uint8_t s = 0; s < (uint8_t)TR_GATE_STEPS; s++) {
    tr_step(g, (uint8_t)TR_GW, (uint8_t)TR_GH);
    for (uint16_t i = 0; i < (uint16_t)(TR_GW * TR_GH); i++) {
      // re-EXTRACT every field and pack into a byte stream the CRC folds
      uint8_t bytes[2];
      bytes[0] = (uint8_t)((g[i].orient) | (g[i].style << 1) | (g[i].hue << 2) | (g[i].mark << 5)
                           | (g[i].phase << 6));
      bytes[1] = (uint8_t)(g[i].energy);
      uint16_t c = tr_crc(bytes, 2);
      h = (uint16_t)((uint16_t)(((unsigned)h << 1) | ((unsigned)h >> 15)) ^ c);
    }
  }
  return h;
}

#endif /* TRUCHET_H */
