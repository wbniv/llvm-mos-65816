// Diffie-Hellman Colour-Mixer — #61 of the compiler stress-test demo battery.
// Renders the verified, portable modular exponentiation (examples/65816/dhmix.h — the same header the
// host oracle tools/dhmix-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so it
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Two parties pick secrets a, b; publish A = g^a mod p and B = g^b mod p; then BOTH compute the shared
// secret s = B^a mod p == A^b mod p == g^(a*b) mod p. The three colour bands (Alice public / shared /
// Bob public) shift as the secrets animate, but Alice's and Bob's shared-secret bands are ALWAYS the
// same colour — the visual proof they converge. The hot op is 64-bit modulo (__umoddi3) inside a
// square-and-multiply modpow — a codegen corner none of the first 60 demos run.
//
// **This demo found + fixed a real backend bug** (see docs/investigations/2026-06-30-a16-s64-unmerge-
// anyext-legalize-crash.md): the 64-bit modexp crashed the +mos-a16/+mos-xy16 legalizer
// (G_UNMERGE_VALUES s64->s16 / G_ANYEXT s24) until patch 0017 added the s64<->s16 (un)merge glue.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/dhmix.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCELL       16
#define NCOL        4

// BG3 2bpp palette (CGRAM 0..3): four mixable hues.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(28, 6, 10), SNES_RGB(6, 24, 12), SNES_RGB(8, 12, 30), SNES_RGB(30, 28, 8),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  uint16_t     frame;
  uint16_t     step;      // advances the secrets
  uint8_t      cA, cSh, cB;   // last drawn colours (avoid redundant redraw)
} App;

volatile uint16_t corpus_result;  // DH gate CRC (read from WRAM by the differential gate)

static void band_fill(BitmapCanvas *cv, uint8_t y0, uint8_t y1, uint8_t color) {
  for (uint8_t cy = y0; cy < y1; cy++)
    for (uint8_t cx = 0; cx < NCELL; cx++) {
      uint16_t tile = (uint16_t)((uint16_t)cy * CANVAS_TILES_W + cx);
      uint8_t *t = &cv->chr[tile * CANVAS_TILEBYTES];
      uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
      uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
      for (uint8_t r = 0; r < 8; r++) { t[r * 2] = p0; t[r * 2 + 1] = p1; }
    }
}

// Run one Diffie-Hellman exchange for the current step; recolour the three bands. noinline caps RA.
__attribute__((noinline))
static void dh_step(App *a) {
  uint64_t sa = (uint64_t)((a->step * 2654435761u + 1u) & 0x3FFFFu);   // Alice secret (< 2^18)
  uint64_t sb = (uint64_t)((a->step * 40503u + 12345u) & 0x3FFFFu);    // Bob secret
  uint64_t A = dh_modpow(DH_G, sa, DH_P);          // public A = g^a
  uint64_t B = dh_modpow(DH_G, sb, DH_P);          // public B = g^b
  uint64_t shared = dh_modpow(B, sa, DH_P);        // shared = B^a  (== A^b, both agree)
  uint8_t cA = dh_color(A, NCOL), cSh = dh_color(shared, NCOL), cB = dh_color(B, NCOL);
  if (cA == a->cA && cSh == a->cSh && cB == a->cB) return;
  a->cA = cA; a->cSh = cSh; a->cB = cB;
  band_fill(&a->canvas, 0, 5, cA);                 // Alice public
  band_fill(&a->canvas, 5, 11, cSh);               // shared secret (the mix)
  band_fill(&a->canvas, 11, NCELL, cB);            // Bob public
  a->canvas.lo = 0; a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->frame = 0u; a->step = 0u;
  a->cA = a->cSh = a->cB = 0xFFu;
  text_puts(&a->text, 0, 1, "DIFFIE-HELLMAN");
  text_puts(&a->text, 1, 0, "g^a MOD p   SHARED SECRET (64BIT)");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "DIFFIE-HELLMAN", "64-BIT MODEXP");
  corpus_result = dhmix_gate_crc();             // self-verify the modexp math == host 0xB7C4
  title_end(&a.screen, &title, 110);
  dh_step(&a);
  for (;;) {
    a.frame++;
    if ((a.frame % 40u) == 0u) { a.step++; dh_step(&a); }   // new exchange every 40 frames
    display_frame(&a.screen);
  }
}
