// 3-D Wireframe Solid on the snesgfx OOP library — #16 of the compiler stress-test demo battery.
// Renders the verified, portable 3-D math (examples/65816/wire3d.h — the same header the host oracle
// tools/wire3d-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so the program
// builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> the full 5-way bar).
//
// Each frame: build a 3x3 rotation matrix from a sin/cos LUT (mat3_from_euler), transform + PERSPECTIVE-
// PROJECT each model vertex (project — the per-vertex divide), and Bresenham-line the solid's edges. A
// spinning polyhedron (tetra / cube / octa / icosa, A/Y cycles). The joypad drives the live controls
// (the interactive state machine examples/snes/wireframe.h); a tiled BG3 HUD shows solid / spin / dist.
//
// Codegen under test: a 3x3 MATRIX MULTIPLY (mat3_mul, __mulsi3) + a per-vertex PERSPECTIVE DIVIDE
// (project, __divsi3 — the divide-bound corner) on the HOT path, plus integer line rasterization.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // crisp full-canvas clear+redraw fits ONE v-blank (4 KB; see plan R1)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/controller.h"
#include "wireframe.h"

#define CANVAS_CHR  0x0000      // BG3 char base (word) — canvas tiles 0..255 + blank tile 256 + font 256..
#define CANVAS_MAP  0x4000      // BG3 tilemap base (word)
#define BOX_COL     8           // 16-tile canvas box at cols 8..23  (screen px 64..191)
#define BOX_ROW     6           // rows 6..21 (screen px 48..175)
#define HUD_TOP_ROW 1           // value bar  (above the box)
#define HUD_BOT_ROW 25          // legend bar (below the box)
#define CXc        (CANVAS_W / 2)
#define CYc        (CANVAS_H / 2)

// BG3 2bpp palette (CGRAM 0..3): 0 = black bg, 1 = white (HUD text), 2 = dim (spare), 3 = wireframe ink.
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(10, 10, 14), SNES_RGB(8, 28, 31),
};
// X-cycled wireframe ink colours (CGRAM[3]); display-only (the pal index is folded into the ctrl CRC).
static const uint16_t WIRE_INK[WIRE3_NPAL] = {
  SNES_RGB(8, 28, 31), SNES_RGB(10, 31, 12), SNES_RGB(31, 28, 8), SNES_RGB(31, 10, 28),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  Controller   pad;
  wire3d_view  view;
  int16_t      px[12], py[12];   // projected screen coords (max 12 verts = icosa)
  uint8_t      last_solid, last_pal;
  uint16_t     crc;              // controller proof CRC (verified separately via the corpus slice)
} App;

volatile uint16_t corpus_result;  // projected-vertex proof channel (read from WRAM by the gate)

// Build the top HUD line "<SOLID> S<spd> D<dist> <MODE>". font is uppercase-only; the displayed spin is
// the |dax| magnitude (the live tumble rate). NUL-terminated.
static void fmt_hud(const wire3d_view *v, char *buf) {
  uint8_t n = 0;
  const char *s = WIRE3_SOLID_NAME[v->solid];
  for (uint8_t i = 0; i < 5 && s[i]; i++) buf[n++] = s[i];
  buf[n++] = ' '; buf[n++] = 'S'; n += wire3d_fmt_u8(wire3d_spin_abs(v->dax), buf + n);
  buf[n++] = ' '; buf[n++] = 'D'; n += wire3d_fmt_u8(v->dist, buf + n);
  buf[n++] = ' ';
  const char *m = v->trail ? "TRAIL" : "SPIN ";
  for (uint8_t i = 0; i < 5 && m[i]; i++) buf[n++] = m[i];
  buf[n] = 0;
}

static void hud_update(App *a) {
  char line[24];
  fmt_hud(&a->view, line);
  text_clear_bar(&a->text, 0);
  text_puts(&a->text, 0, 1, line);
}

// Transform + project the current solid's vertices, then Bresenham-line its edges. noinline bounds the
// a16/xy16 register pressure of the matrix + divide kernels (handoff §4; the plan's WIRE3_FN reasoning).
__attribute__((noinline))
static void draw_frame(App *a) {
  const wire3d_view *v = &a->view;
  mat3 R;
  mat3_from_euler(v->ax, v->ay, v->az, &R);
  uint8_t voff = WIRE3_VOFF[v->solid], nv = WIRE3_NV[v->solid];
  for (uint8_t i = 0; i < nv; i++) {
    int16_t sx, sy;
    project(&R, WIRE3_V[voff + i], (int16_t)v->dist, &sx, &sy);
    a->px[i] = (int16_t)(CXc + sx);
    a->py[i] = (int16_t)(CYc - sy);
  }
  uint8_t eoff = WIRE3_EOFF[v->solid], ne = WIRE3_NE[v->solid];
  for (uint8_t e = 0; e < ne; e++) {
    uint8_t i0 = WIRE3_E[eoff + e][0], i1 = WIRE3_E[eoff + e][1];
    canvas_line(&a->canvas, a->px[i0], a->py[i0], a->px[i1], a->py[i1], 3);
  }
}

static void app_init(App *a) {
  display_init(&a->screen);                                   // boot bracket: force-blank, BGMODE_1
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);            // reserve BG3 (tilemap + clear, force-blank)
  display_add(&a->screen, (Drawable *)&a->text);              // reserve: load font (force-blank)
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  controller_init(&a->pad);
  wire3d_view_reset(&a->view);
  a->last_solid = a->view.solid; a->last_pal = a->view.pal;
  a->crc = 0xFFFF;
  hud_update(a);
  text_puts(&a->text, 1, 0, "DPAD SPIN  LR DIST  AY SOLID SEL TRL");
}

int main(void) {
  static App a;
  app_init(&a);
  /* Title overlay (BG2), added after the demo layers; held while the gate-CRC computes, then torn down
     before the solid spins. Gate-neutral (no DMA; corpus_result is the pre-loop hash). */
  static TitleLayer title;
  title_begin(&a.screen, &title, "3D WIREFRAME", "SPINNING SOLID");
  corpus_result = wire3d_gate_crc();                          // self-verify the 3-D math == host 0xE737
  title_end(&a.screen, &title, 110);
  for (;;) {
    controller_poll(&a.pad);
    wire3d_view_step(&a.view, controller_held(&a.pad));
    if (!a.view.trail) canvas_clear(&a.canvas);               // crisp spin: erase last frame (Rung 1)
    else if (a.view.dirty) canvas_clear(&a.canvas);           // trail mode: clear only on solid switch
    draw_frame(&a);
    if (a.view.solid != a.last_solid || a.view.trail) { hud_update(&a); a.last_solid = a.view.solid; }
    if (a.view.pal != a.last_pal) {                           // X-cycle the wireframe ink (display only)
      upq_push_cgram(&a.screen.q, 3, &WIRE_INK[a.view.pal], 0x00, 2);
      a.last_pal = a.view.pal;
    }
    a.crc = wire3d_view_fold(a.crc, &a.view);
    display_frame(&a.screen);                                 // flush dirty canvas tiles + HUD; release blank
  }
}
