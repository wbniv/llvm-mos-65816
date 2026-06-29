// CORDIC Rotator SNES demo — #12 of the compiler stress-test demo battery.
//
// Renders a hand sweeping around a CORDIC-computed vector field:
//   • an outer RING + 12 SPOKES (unit vectors at 30° steps), each drawn by the demo's OWN CORDIC
//     (cordic16_sincos) into a static "face" buffer once, in force-blank.
//   • one ROTATING HAND (the only moving element), redrawn each frame with erase-correct face-restore.
//   • a 2-row HUD: the hand angle in degrees, and a live atan2()-recovered self-check of that angle
//     (exercising BOTH the rotation and the vectoring CORDIC paths on-screen).
//
// CORDIC is shift-add only — no multiply/divide — so the corpus slice (examples/snes/corpus/cordic_sim.c)
// that folds cordic_gate_crc() compiles to ZERO __mulsi3/__divsi3/variable-shift libcalls; dev/cordic.sh
// §3 asserts that (inverted vs every other demo). No far pointers → builds default-8-bit AND +mos-a16 AND
// +mos-xy16 → 5-way differential bar. See docs/plans/2026-06-28-12-snes-cordic-clock-rotator.md.
//
// NOTE: the radius→pixel scaling (RADIUS*cos>>14, a __mulsi3) and the angle→degrees conversion
// (mul+div) live ONLY here in the render path — never in cordic.h / the gate — so the probed gate object
// stays libcall-free.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "snesgfx/text_layer.h"
#include "font8.h"
#include "../65816/cordic.h"

// ---- Canvas geometry (a 128×128 2bpp tiled bitmap in bank-0 WRAM, same shape as BitmapCanvas) -------
#define ROT_TILES_W   16
#define ROT_TILES_H   16
#define ROT_W        (ROT_TILES_W * 8)        // 128
#define ROT_H        (ROT_TILES_H * 8)        // 128
#define ROT_NTILES   (ROT_TILES_W * ROT_TILES_H)  // 256
#define ROT_TILEBYTES 16                      // 2bpp: 8 rows × 2 planes
#define ROT_CX        64                      // canvas centre x
#define ROT_CY        64                      // canvas centre y
#define ROT_RING      60                      // ring / spoke radius (px)
#define ROT_HAND      58                      // hand length (px)

// BG3 VRAM layout (spigot convention): canvas tiles 0..255 + blank 256 + font 256.., tilemap at 0x4000.
#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8                         // 16-wide box centred in 32 cols
#define BOX_ROW     1                         // rows 1..16 (HUD lives on rows 26/27)
#define HUD_TOP_ROW 25
#define HUD_BOT_ROW 26      // row 27 (last 8px line) clips in 224-line overscan — keep the HUD off it

// BG3 2bpp palette (CGRAM 0..3): 0 black bg, 1 dim cyan (ring/spokes), 2 bright yellow (hand), 3 white.
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(0, 14, 16), SNES_RGB(31, 30, 6), SNES_RGB(31, 31, 31),
};

// ---- raw 2bpp buffer rasteriser (the BitmapCanvas plot/Bresenham idiom, on a plain uint8_t* chr) -----

// Set pixel (x,y) to colour (1..3; 0 transparent). OR-only. Out-of-range dropped (unsigned compare).
static inline void buf_plot(uint8_t *chr, int16_t x, int16_t y, uint8_t color) {
  if ((uint16_t)x >= ROT_W || (uint16_t)y >= ROT_H) return;
  uint16_t tile = (uint16_t)(((uint16_t)y >> 3) * ROT_TILES_W + ((uint16_t)x >> 3));
  uint8_t *t = &chr[tile * ROT_TILEBYTES + ((uint8_t)y & 7) * 2];
  uint8_t mask = (uint8_t)(0x80u >> ((uint8_t)x & 7));
  if (color & 1) t[0] |= mask;
  if (color & 2) t[1] |= mask;
}

// Bresenham line into a raw chr buffer. noinline keeps its live set out of the caller's a16/xy16 budget.
__attribute__((noinline))
static void buf_line(uint8_t *chr, int16_t x0, int16_t y0, int16_t x1, int16_t y1, uint8_t color) {
  int16_t dx = (int16_t)(x1 > x0 ? x1 - x0 : x0 - x1);
  int16_t dy = (int16_t)(y1 > y0 ? y1 - y0 : y0 - y1);
  int16_t sx = (int16_t)(x0 < x1 ? 1 : -1);
  int16_t sy = (int16_t)(y0 < y1 ? 1 : -1);
  int16_t err = (int16_t)(dx - dy);
  for (;;) {
    buf_plot(chr, x0, y0, color);
    if (x0 == x1 && y0 == y1) break;
    int16_t e2 = (int16_t)(err * 2);
    if (e2 > -dy) { err = (int16_t)(err - dy); x0 = (int16_t)(x0 + sx); }
    if (e2 <  dx) { err = (int16_t)(err + dx); y0 = (int16_t)(y0 + sy); }
  }
}

// Map a Q2.14 (cos,sin) at radius `rad` to canvas pixel coords (y inverted for screen-down).
static inline void unit_to_px(int16_t cos_q, int16_t sin_q, int16_t rad, int16_t *px, int16_t *py) {
  *px = (int16_t)(ROT_CX + (int16_t)(((int32_t)rad * cos_q) >> CORDIC16_FRAC));
  *py = (int16_t)(ROT_CY - (int16_t)(((int32_t)rad * sin_q) >> CORDIC16_FRAC));
}

// ---- Rotator drawable -------------------------------------------------------------------------------
// One 4 KB 2bpp chr buffer with a SPLIT-BITPLANE layout: the static face (ring + spokes + centre dot)
// lives in PLANE 0 (colour 1), the moving hand in PLANE 1 (colour 2). Erasing the hand is then just
// zeroing plane 1 over its old bbox — the face in plane 0 is untouched, so no second "face copy" buffer
// is needed (keeps .bss inside SNES low RAM). Where the hand crosses the face both planes are set →
// colour 3 (a bright highlight). Each frame: clear plane 1 over the PREVIOUS hand bbox, draw the new
// hand, DMA the union bbox row-by-row (a few hundred bytes — well under budget).
typedef struct {
  Drawable base;
  uint8_t  chr[ROT_NTILES * ROT_TILEBYTES];   // 4 KB live (plane 0 = face, plane 1 = hand)
  uint16_t chr_word, map_word;
  uint8_t  box_col, box_row;
  // dirty tile bbox (cols/rows, inclusive); empty when dx0 > dx1.
  uint8_t  dx0, dy0, dx1, dy1;
  // previous hand tile bbox (to restore the face under it next frame); empty when px0 > px1.
  uint8_t  px0, py0, px1, py1;
} Rotator;

#define _ROT_BASE_TILE(c)  ((uint16_t)((c)->chr_word >> 3))
#define _ROT_BLANK_TILE(c) ((uint16_t)(_ROT_BASE_TILE(c) + ROT_NTILES))

static void _rot_reserve(Drawable *d, VramAlloc *va) {
  (void)va;
  Rotator *c = (Rotator *)d;
  REG_BG3SC   = SNES_BGSC(c->map_word, 0);
  REG_BG34NBA = (uint8_t)((c->chr_word >> 12) & 0x0F);
  // Static tilemap: 16×16 canvas box at (box_col,box_row), blank tile elsewhere (force-blank: direct OK).
  uint16_t base = _ROT_BASE_TILE(c), blank = _ROT_BLANK_TILE(c);
  snes_vram_addr(c->map_word);
  for (uint8_t sy = 0; sy < 32; sy++)
    for (uint8_t sx = 0; sx < 32; sx++) {
      uint8_t inx = (uint8_t)(sx - c->box_col), iny = (uint8_t)(sy - c->box_row);
      uint16_t tile = (inx < ROT_TILES_W && iny < ROT_TILES_H)
                        ? (uint16_t)(base + iny * ROT_TILES_W + inx) : blank;
      REG_VMDATA = tile;
    }
  // Build the face into PLANE 0: ring + 12 spokes drawn by the demo's OWN CORDIC, plus a centre dot.
  for (uint16_t i = 0; i < ROT_NTILES * ROT_TILEBYTES; i++) c->chr[i] = 0;
  rotor o; rotor_init(&o);
  for (uint16_t k = 0; k < CORDIC_GATE_N; k++) {       // 96 steps = one revolution
    int16_t s, c1; rotor_sincos(&o, &s, &c1);
    int16_t rx, ry; unit_to_px(c1, s, ROT_RING, &rx, &ry);
    buf_plot(c->chr, rx, ry, 1);                       // ring point (dim, plane 0)
    if ((k % 8u) == 0u) {                              // every 30° → a spoke
      int16_t ex, ey; unit_to_px(c1, s, ROT_RING - 2, &ex, &ey);
      buf_line(c->chr, ROT_CX, ROT_CY, ex, ey, 1);
    }
  }
  buf_plot(c->chr, ROT_CX, ROT_CY, 1);                 // centre dot (plane 0 — survives hand-plane erase)
  // Upload the whole face to VRAM now (force-blank).
  snes_vram_addr(c->chr_word);
  for (uint16_t w = 0; w < (uint16_t)(ROT_NTILES * 8 + 8); w++) {
    // 2bpp: each tile = 8 words (plane0|plane1 interleaved) — emit straight from chr (blank tile = 0).
    uint16_t lo = (w < ROT_NTILES * 8)
                    ? (uint16_t)(c->chr[(w / 8) * 16 + (w % 8) * 2]
                                 | ((uint16_t)c->chr[(w / 8) * 16 + (w % 8) * 2 + 1] << 8))
                    : 0u;
    REG_VMDATA = lo;
  }
  c->dx0 = 1; c->dx1 = 0;   // dirty empty
  c->px0 = 1; c->px1 = 0;   // prev-hand empty
}

// Push tile rows [dy0..dy1] × cols [dx0..dx1] of the dirty bbox (≤ UPQ_MAX_JOBS rows).
static void _rot_emit(Drawable *d, UploadQueue *q) {
  Rotator *c = (Rotator *)d;
  if (c->dx0 > c->dx1) return;                          // nothing dirty
  uint8_t ncols = (uint8_t)(c->dx1 - c->dx0 + 1u);
  for (uint8_t ty = c->dy0; ty <= c->dy1 && q->n < UPQ_MAX_JOBS; ty++) {
    uint16_t tile0 = (uint16_t)(ty * ROT_TILES_W + c->dx0);
    upq_push_vram(q, (uint16_t)(c->chr_word + tile0 * 8),
                  &c->chr[tile0 * ROT_TILEBYTES], 0x00,
                  (uint16_t)(ncols * ROT_TILEBYTES), VMAIN_INC_HIGH_1);
  }
  c->dx0 = 1; c->dx1 = 0;                               // mark clean
}

static const DrawableVT ROT_VT = { _rot_reserve, _rot_emit };

static void rot_init(Rotator *c, uint16_t chr_word, uint16_t map_word, uint8_t box_col, uint8_t box_row) {
  c->base.vt = &ROT_VT;
  c->base.tm_bits = TM_BG3;
  c->chr_word = chr_word; c->map_word = map_word;
  c->box_col = box_col;   c->box_row = box_row;
  for (uint16_t i = 0; i < ROT_NTILES * ROT_TILEBYTES; i++) c->chr[i] = 0;
  c->dx0 = 1; c->dx1 = 0;
  c->px0 = 1; c->px1 = 0;
}

// Clamp a pixel coord to a tile index 0..15.
static inline uint8_t _tclamp(int16_t px) {
  if (px < 0) return 0;
  uint8_t t = (uint8_t)((uint16_t)px >> 3);
  return t > (ROT_TILES_W - 1) ? (ROT_TILES_W - 1) : t;
}

// Restore the face over the previous hand bbox, draw the new hand (centre→(hx,hy)), set the union dirty
// bbox, and remember the new hand bbox for next frame's restore.
static void rot_set_hand(Rotator *c, int16_t hx, int16_t hy) {
  // new hand tile bbox (centre is always inside).
  uint8_t nx0 = _tclamp(hx < ROT_CX ? hx : ROT_CX), nx1 = _tclamp(hx < ROT_CX ? ROT_CX : hx);
  uint8_t ny0 = _tclamp(hy < ROT_CY ? hy : ROT_CY), ny1 = _tclamp(hy < ROT_CY ? ROT_CY : hy);
  // 1. erase the previous hand: zero PLANE 1 over its bbox (the face in plane 0 is untouched).
  if (c->px0 <= c->px1)
    for (uint8_t ty = c->py0; ty <= c->py1; ty++)
      for (uint8_t tx = c->px0; tx <= c->px1; tx++) {
        uint16_t off = (uint16_t)((ty * ROT_TILES_W + tx) * ROT_TILEBYTES);
        for (uint8_t r = 0; r < 8; r++) c->chr[off + r * 2 + 1] = 0;   // plane 1 byte of each row
      }
  // 2. draw the new hand into PLANE 1 (colour 2).
  buf_line(c->chr, ROT_CX, ROT_CY, hx, hy, 2);
  // 3. dirty = union(prev, new) bbox.
  uint8_t ux0 = nx0, uy0 = ny0, ux1 = nx1, uy1 = ny1;
  if (c->px0 <= c->px1) {
    if (c->px0 < ux0) ux0 = c->px0;  if (c->py0 < uy0) uy0 = c->py0;
    if (c->px1 > ux1) ux1 = c->px1;  if (c->py1 > uy1) uy1 = c->py1;
  }
  c->dx0 = ux0; c->dy0 = uy0; c->dx1 = ux1; c->dy1 = uy1;
  // 4. remember the new hand bbox.
  c->px0 = nx0; c->py0 = ny0; c->px1 = nx1; c->py1 = ny1;
}

// ---- number formatting + HUD ------------------------------------------------------------------------

// uint16 → decimal string (NUL-terminated, buf >= 6). Returns length.
static uint8_t u16_to_dec(char *buf, uint16_t v) {
  char tmp[6]; uint8_t n = 0;
  if (!v) { buf[0] = '0'; buf[1] = 0; return 1; }
  while (v) { tmp[n++] = (char)('0' + (uint8_t)(v % 10u)); v /= 10u; }
  for (uint8_t i = 0; i < n; i++) buf[i] = tmp[n - 1u - i];
  buf[n] = 0;
  return n;
}

// Degrees (0..359) of a rotor angle: qd*90 + r*90/HALFPI (mul+div — RENDER path only, not the gate).
static inline uint16_t rotor_deg(const rotor *o) {
  uint16_t in_quad = (uint16_t)(((int32_t)o->r * 90) / CORDIC16_HALFPI);
  return (uint16_t)((uint16_t)(o->qd & 3u) * 90u + in_quad);   // qd grows unbounded; fold to 0..3
}

typedef struct {
  Display   screen;
  Rotator   rot;
  TextLayer hud;
  rotor     hand;      // display rotor
} App;

volatile uint16_t corpus_result;   // proof channel (read from WRAM by the gate; cordic rotator CRC)

// HUD bar 0: "ANGLE nnn DEG"; bar 1: "ATAN2 nnn OK/ERR" (vectoring self-check).
__attribute__((noinline))
static void hud_update(App *a, const rotor *cur) {
  uint16_t deg = rotor_deg(cur);
  // atan2 round-trip of the base vector recovers the in-quadrant residual; rebuild the full angle.
  int16_t bs, bc; cordic16_sincos(cur->r, &bs, &bc);
  int16_t arec = cordic16_atan2(bs, bc);
  uint16_t adeg = (uint16_t)((uint16_t)(cur->qd & 3u) * 90u
                  + (uint16_t)(((int32_t)arec * 90) / CORDIC16_HALFPI));
  uint16_t diff = (uint16_t)(adeg > deg ? adeg - deg : deg - adeg);

  char num[6];
  text_clear_bar(&a->hud, 0);
  text_puts(&a->hud, 0, 0, "ANGLE ");
  u16_to_dec(num, deg); text_puts(&a->hud, 0, 6, num);
  text_puts(&a->hud, 0, 10, "DEG");

  text_clear_bar(&a->hud, 1);
  text_puts(&a->hud, 1, 0, "ATAN2 ");
  u16_to_dec(num, adeg); text_puts(&a->hud, 1, 6, num);
  text_puts(&a->hud, 1, 10, diff <= 2u ? "OK" : "ERR");
}

static void app_init(App *a) {
  display_init(&a->screen);
  rot_init(&a->rot, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->hud, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->rot);   // reserve BG3 + tilemap + upload face (force-blank)
  display_add(&a->screen, (Drawable *)&a->hud);   // reserve: load font (force-blank)
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
  rotor_init(&a->hand);
}

int main(void) {
  static App a;
  app_init(&a);

  // Self-verify: the on-console CRC the gate reads back from WRAM (independent of the display rotor).
  corpus_result = cordic_gate_crc();

  for (;;) {
    rotor cur = a.hand;                              // snapshot angle for the hand + HUD
    int16_t s, c; rotor_sincos(&a.hand, &s, &c);     // (s,c) at `cur`; advances a.hand by one step
    int16_t hx, hy; unit_to_px(c, s, ROT_HAND, &hx, &hy);
    rot_set_hand(&a.rot, hx, hy);                    // erase old hand → draw new → mark dirty bbox
    hud_update(&a, &cur);
    display_frame(&a.screen);                        // wait v-blank → emit() → DMA flush
  }
}
