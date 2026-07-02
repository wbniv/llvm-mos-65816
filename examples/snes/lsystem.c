// #23 — L-System Plant on the SNES.
//
// Grows an L-system by STRING REWRITING (examples/65816/lsystem.h) — each generation rewrites a char
// buffer IN PLACE with memmove (overlapping tail shift) + memcpy (write the production) + strlen (its
// length), the string-libcall corner no other demo runs — then a turtle interprets the final string into
// a fractal plant on a NEAR 2bpp bitmap canvas (BG3). The turtle's `[`/`]` save/restore is a bracket
// push/pop stack, the second new corner.
//
// The picture IS the proof: a correct rewrite + interpreter grows a coherent fractal plant; a memcpy/
// strlen miscompile or a botched stack frame scrambles the string/path and the gate CRC freezes. No far
// pointers (buffers/stack/turtle in bank-0 WRAM) so the corpus slice (lsystem_sim.c) is a full 5-way
// differential: corpus_result = lsystem_gate_crc() == the host oracle (tools/lsystem-sim.c) == 0x79C3,
// bit-for-bit, across default / +mos-a16 / +mos-xy16.
//
// The plant draws and the gate CRC come from the SAME interpretation pass: lsystem_interp folds the CRC
// AND calls our emit callback per segment, so the on-screen path and corpus_result can never disagree.
//
// PROGRESSIVE GROWTH + FAR-POINTER COVERAGE: the startup interp pass RECORDS every F-segment into a far
// buffer at $7E2000 (the +mos-a16 far-pointer STORE path), then the main loop replays them a few per
// frame (far LOAD) so the plant grows stroke by stroke. The corpus slice stays far-pointer-free (5-way);
// the ROM adds the high-WRAM store/load codegen path the low-WRAM-only version never exercised.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/title_layer.h"
#include "../65816/lsystem.h"

#define CANVAS_CHR  0x0000      // BG3 char base (word) — canvas tiles 0..255
#define CANVAS_MAP  0x4000      // BG3 tilemap base (word)
#define BOX_COL     8           // 16-tile (128 px) canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW     6           // rows 6..21 (screen px 48..175)

volatile uint16_t corpus_result;   // differential proof channel (read from WRAM by the gate)

// BG3 2bpp palette (CGRAM 0..3): 0 = black bg, then trunk + two greens (selected by branch depth).
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(20, 11, 2), SNES_RGB(7, 26, 5), SNES_RGB(16, 31, 9),
};

// Progressive-reveal animation backed by a FAR (high-WRAM) segment buffer.
//
// At startup the canonical lsystem_interp() runs ONCE: its emit callback RECORDS every F-segment
// (5 bytes: x0,y0,x1,y1,col) into a far buffer at $7E2000 — exercising the +mos-a16 FAR-POINTER
// STORE path — while the same pass folds the gate CRC into corpus_result (== host == 0xA555,
// unchanged, since the CRC is independent of what emit does). CRC = 0x8073 at gen 6. Then each frame the loop replays the
// next chunk of segments by READING them back from far memory (the FAR-POINTER LOAD path) and
// drawing them — a cheap O(1)-per-segment reveal, so the plant grows smoothly stroke by stroke.
//
// This upgrades the demo's coverage: the corpus slice (lsystem_sim.c) stays a 5-way differential
// (string-libcall corner, no far pointers), while the on-console ROM now ALSO stresses far-pointer
// store+load against the 128 KiB WRAM — the high-memory codegen path the low-WRAM-only version never
// touched. The far buffer makes the ROM +mos-a16-only (a16 ↔ bsnes-jg bar), like julia/buddhabrot.
#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const seg = (FAR uint8_t *)0x7E2000u;   // far segment record (≤ 567×5 = 2835 B)

#define SEG_MAX        700u    // far-buffer capacity in segments (3500 B; the plant has ~567)
#define SEGS_PER_FRAME 3u      // segments revealed per frame (~567 total → ~189 frames ≈ 3.2 s)
#define HOLD_FRAMES    150u    // frames to hold the finished plant before regrowing

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
} App;

// Record callback: append one segment (5 bytes) to the far buffer. ctx is the running count.
static void rec_seg(void *ctx, uint8_t x0, uint8_t y0, uint8_t x1, uint8_t y1, uint8_t col) {
  uint16_t *pn = (uint16_t *)ctx;
  uint16_t k = *pn;
  if (k >= (uint16_t)SEG_MAX) return;            // overflow guard (won't trip: ~401 < 512)
  uint16_t o = (uint16_t)(k * 5u);
  seg[o + 0u] = x0; seg[o + 1u] = y0;            // far STORE
  seg[o + 2u] = x1; seg[o + 3u] = y1;
  seg[o + 4u] = col;
  *pn = (uint16_t)(k + 1u);
}

// Draw recorded segments [lo, hi) by reading them back from the far buffer.
static void replay_segs(BitmapCanvas *cv, uint16_t lo, uint16_t hi) {
  for (uint16_t k = lo; k < hi; k++) {
    uint16_t o = (uint16_t)(k * 5u);
    uint8_t x0 = seg[o + 0u], y0 = seg[o + 1u];  // far LOAD
    uint8_t x1 = seg[o + 2u], y1 = seg[o + 3u];
    uint8_t col = seg[o + 4u];
    canvas_line(cv, (int16_t)x0, (int16_t)y0, (int16_t)x1, (int16_t)y1, col);
  }
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);                    // reserve BG3 (force-blank)
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
}

int main(void) {
  static App a;
  app_init(&a);

  // Title card (BG2). Behind it: rewrite the L-system, then interpret it ONCE with rec_seg, which
  // RECORDS every F-segment into the far buffer (far STORE) and returns the path CRC -> corpus_result
  // (== host == 0x79C3 — the CRC is independent of the emit callback). No drawing happens here; the
  // plant is revealed progressively from the far buffer in the loop below.
  static TitleLayer title;
  title_begin16(&a.screen, &title, "L-SYSTEM", "PLANT");
  uint16_t len;
  const char *s = lsystem_build(&len);
  uint16_t nseg = 0;
  corpus_result = lsystem_interp(s, len, rec_seg, &nseg);            // record to far + fold CRC
  title_end(&a.screen, &title, 110);
  a.screen.bright = INIDISP_ON; a.screen.btgt = INIDISP_ON;          // full brightness from frame 1
  upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal); // reset backdrop: title rainbow left CGRAM[0] at its last hue

  // Progressive reveal: each frame replay the next SEGS_PER_FRAME recorded segments from the far
  // buffer (far LOAD) into the canvas — cheap O(1)/segment, so the plant grows smoothly. Once fully
  // grown, hold, then clear and regrow from the trunk.
  uint16_t drawn = 0, hold = 0;
  for (;;) {
    if (drawn < nseg) {
      uint16_t hi = (uint16_t)(drawn + SEGS_PER_FRAME);
      if (hi > nseg) hi = nseg;
      replay_segs(&a.canvas, drawn, hi);
      drawn = hi;
    } else {
      if (++hold >= (uint16_t)HOLD_FRAMES) { canvas_clear(&a.canvas); drawn = 0; hold = 0; }
    }
    display_frame(&a.screen);
  }
}
