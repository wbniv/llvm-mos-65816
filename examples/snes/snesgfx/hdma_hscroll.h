/* snesgfx — hdma_hscroll: a tiny per-scanline BG-scroll HDMA helper.
 *
 * Streams a write-twice BGnHOFS/BGnVOFS register ($210D..$2114) per scanline so different vertical
 * *bands* of ONE background get independent scroll. Two motivating uses, both in title_layer.h:
 *
 *   - horizontal: two text lines sharing one BG, each pixel-centred independently. Tilemap
 *     placement only centres to the 8 px tile grid, so an odd-width line sits 4 px off true centre,
 *     and two lines of different parity need different nudges — one shared BGnHOFS cannot give that.
 *   - vertical: each line gets a band exactly as tall as the line itself, so a line's *wrapped*
 *     copy (the tilemap is 256 px tall and scroll wraps mod 256) can never bleed into the other
 *     line's band. Scanlines that should show nothing get a scroll value aimed at blank tilemap.
 *
 * Transfer mode 2 (one register, write-twice) feeds the 16-bit scroll latch (low byte then high
 * byte) from the table. The table uses write-once-and-hold runs (count byte bit 7 = 0): the value is
 * latched on the first scanline of the run and held for the rest. A 0 count byte ends the table.
 *
 *   table = [ n0, lo0,hi0,  n1, lo1,hi1,  …,  0 ]
 *           |__ band 0: n0 lines __|  |__ band 1: n1 lines __|
 *
 * A run's count byte carries at most 127 lines (bit 7 selects repeat mode), so hscrolln_build splits
 * any longer band into consecutive runs of the same value — callers just describe logical bands.
 *
 * The table holds runtime-computed offsets, so it lives in WRAM. Low-WRAM bss ($0200-$1FFF) is
 * mirrored at bank 0 $0000-$1FFF, so arm with A-bus source bank 0 (as hud.h does for ROM tables).
 *
 * Header-only (static inline). Does NOT touch HDMAEN — the caller enables bit (1<<chan) when ready
 * and clears it when done (HDMAEN $420C is write-only, so it cannot be read-modify-written here). */
#ifndef SNESGFX_HDMA_HSCROLL_H
#define SNESGFX_HDMA_HSCROLL_H

#include <snes.h>
#include "upload.h"   /* HScrollDB publishes its pointer swap through the v-blank upload queue */

/* B-bus destination low bytes for the four BG horizontal-scroll latches (for hscrolln_arm `reg_lo`). */
#define HSCROLL_BG1HOFS  0x0Du
#define HSCROLL_BG2HOFS  0x0Fu
#define HSCROLL_BG3HOFS  0x11u
#define HSCROLL_BG4HOFS  0x13u

/* B-bus destination low bytes for the four BG vertical-scroll latches. */
#define VSCROLL_BG1VOFS  0x0Eu
#define VSCROLL_BG2VOFS  0x10u
#define VSCROLL_BG3VOFS  0x12u
#define VSCROLL_BG4VOFS  0x14u

/* Table capacity. title_layer.h's worst case is 6 runs (2 glyph bands + 4 blank chunks — only one
   blank region can ever exceed the 112-line chunk size, since two would need >224 scanlines);
   8 runs of 3 bytes + the terminator leaves headroom without costing meaningful WRAM. */
#define HSCROLL_MAX_RUNS   8u
#define HSCROLL_TAB_BYTES  (HSCROLL_MAX_RUNS * 3u + 1u)

typedef struct { uint8_t tab[HSCROLL_TAB_BYTES]; } HScrollN;

/* Streaming writer: bands are appended one at a time, so a caller computing bands on the fly needs
   no intermediate array (which on the 65816 would mean a stack-resident struct array — expensive).
   Usage:  HScrollW w; hscrollw_begin(&w, &tab); hscrollw_band(&w, n, val); …; hscrollw_end(&w); */
typedef struct { HScrollN *t; uint8_t w; } HScrollW;

static inline void hscrollw_begin(HScrollW *s, HScrollN *t) { s->t = t; s->w = 0; }

/* Append one band: `lines` consecutive scanlines all scrolled by `val` (10-bit scroll value; only
   the low 10 bits reach the latch, so −4 == shift content 4 px right == 0x3FC). Zero-length bands
   are ignored; bands longer than 127 lines become several same-value runs, since the count byte's
   bit 7 selects repeat mode. Silently stops at table capacity rather than overrunning. */
static inline void hscrollw_band(HScrollW *s, uint8_t lines, int16_t val) {
  uint16_t rem = lines;
  while (rem != 0u && (uint16_t)(s->w + 3u) < HSCROLL_TAB_BYTES) {
    uint8_t run = (rem > 127u) ? 127u : (uint8_t)rem;
    s->t->tab[s->w++] = run;                                  /* run length (bit 7 clear = hold) */
    s->t->tab[s->w++] = (uint8_t)(uint16_t)val;               /* scroll low  byte                */
    s->t->tab[s->w++] = (uint8_t)((uint16_t)val >> 8);        /* scroll high byte                */
    rem = (uint16_t)(rem - run);
  }
}

/* Terminate the table. The caller is responsible for the band lengths summing to 224 — a short
   table simply leaves the latch at its last value for the remaining scanlines, which is benign but
   usually unintended. */
static inline void hscrollw_end(HScrollW *s) { s->t->tab[s->w] = 0; }

/* Arm HDMA channel `chan` to stream `h->tab` into the write-twice scroll register whose B-bus low
   byte is `reg_lo` (one of the HSCROLL_/VSCROLL_ macros). The table must be in bank 0 (low WRAM).
   Caller then sets REG_HDMAEN |= (1<<chan) to start it and clears that bit to stop. */
static inline void hscrolln_arm(uint8_t chan, uint8_t reg_lo, const HScrollN *h) {
  volatile uint8_t *c = (volatile uint8_t *)(uintptr_t)(0x4300u + (uint16_t)chan * 0x10u);
  c[0] = 0x02;                              /* DMAPx: A->B, transfer mode 2 (1 reg, write twice) */
  c[1] = reg_lo;                            /* BBADx: B-bus destination low byte ($21xx)         */
  c[2] = (uint8_t)(uintptr_t)h->tab;        /* A1TxL: table address low                          */
  c[3] = (uint8_t)((uintptr_t)h->tab >> 8); /* A1TxH: table address high                         */
  c[4] = 0x00;                              /* A1Bx:  source bank 0 (low-WRAM mirror)            */
}

/* ── double buffering ─────────────────────────────────────────────────────────────────────────────
 * A table that is REBUILT EVERY FRAME cannot be written in place: drawables emit during active
 * display (Display runs scene_emit before waiting for v-blank, because emit touches WRAM only),
 * and the HDMA engine is walking the table at that exact moment. Rewriting it under the engine can
 * hand the rest of the frame a half-old/half-new run — a count byte from one layout paired with a
 * scroll value from another, which shows up as a band jumping to a wild position for one frame.
 *
 * HScrollDB removes the race instead of hoping the values are close enough: writes always land in
 * the half the engine is NOT reading, and the channel is re-pointed at the fresh half through the
 * UploadQueue, whose jobs run inside v-blank. The channel latches A1Tx into an internal counter at
 * HDMA-init (start of the next frame), so a v-blank pointer swap is atomic with respect to the
 * transfer. If the queue is full the flip is skipped and the engine simply re-runs the previous
 * frame's table — one stale frame, never a torn one. */
typedef struct { HScrollN buf[2]; uint8_t cur; } HScrollDB;

/* The half to build into this frame (never the one HDMA is reading). */
static inline HScrollN *hscrolldb_back(HScrollDB *d) { return &d->buf[d->cur ^ 1u]; }

/* Arm the channel on buffer 0 and make it live. Call once, before HDMAEN enables the channel. */
static inline void hscrolldb_arm(uint8_t chan, uint8_t reg_lo, HScrollDB *d) {
  d->cur = 0;
  hscrolln_arm(chan, reg_lo, &d->buf[0]);
}

/* Publish the half just built: queue the A1Tx pointer update for the v-blank window. Only advance
   `cur` if the write was actually queued, so a full queue costs a stale frame, not a torn table. */
static inline void hscrolldb_commit(HScrollDB *d, UploadQueue *q, uint8_t chan) {
  uint16_t a1t = (uint16_t)(0x4302u + (uint16_t)chan * 0x10u);   /* A1TxL / A1TxH */
  HScrollN *back = hscrolldb_back(d);
  if (upq_push_poke16(q, a1t, (uint16_t)(uintptr_t)back->tab)) d->cur ^= 1u;
}

#endif /* SNESGFX_HDMA_HSCROLL_H */
