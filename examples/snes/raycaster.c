/* Raycaster maze on the snesgfx OOP library — #15 of the compiler stress-test demo battery.
 * Renders the verified, portable DDA raycaster (examples/65816/raycaster.h — the same header the host
 * oracle tools/raycaster-sim.c and the corpus slice run) into a NEAR 2bpp bitmap canvas (BG3), so the
 * program builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers → the full 5-way bar).
 *
 * A first-person camera auto-walks a 16×16 maze: each of 64 screen columns casts a ray by integer
 * DDA through the grid and the wall slice height is screen_h / perpendicular_distance — a per-column
 * DIVIDE (plus the two deltaDist reciprocals per column). Distance shades the wall (near→far cyan).
 *
 * Codegen under test: __udivsi3 (three divides/column) + Q8.8 fixed-point + the sin/cos camera basis.
 * corpus_result = rc_gate_crc() (64-column fan, fixed camera), set once at startup.                */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/raycaster.h"

#define CANVAS_CHR  0x0000      /* BG3 char base (word) — canvas tiles 0..255 + blank 256 + font 256.. */
#define CANVAS_MAP  0x4000      /* BG3 tilemap base (word) */
#define BOX_COL     8           /* 16-tile canvas box at cols 8..23 (screen px 64..191) */
#define BOX_ROW     6           /* rows 6..21 (screen px 48..175) */
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25

#define NCOL     64u            /* rays cast (each drawn 2 px wide → 128-px canvas) */
#define MOVE_STEP   20          /* forward step per advance (Q8.8 ≈ 0.078 cell) */
#define TURN_STEP    6          /* heading turn when blocked (uint8 turn units) */

/* BG3 2bpp palette (CGRAM 0..3): 0 = black (sky/floor), 1 = far wall (dim), 2 = mid, 3 = near (bright). */
static const uint16_t bg3_pal[4] = {
  SNES_RGB(0, 0, 0), SNES_RGB(4, 10, 13), SNES_RGB(8, 20, 24), SNES_RGB(14, 30, 31),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  rc_cam       cam;
} App;

volatile uint16_t corpus_result;   /* raycaster proof channel (read from WRAM by the gate) */

/* Wall colour from perpendicular distance (Q8.8 cells): near→3, mid→2, far→1. */
static inline uint8_t shade(int32_t dist) {
  if (dist < 384)  return 3u;   /* < 1.5 cells */
  if (dist < 1024) return 2u;   /* < 4 cells   */
  return 1u;
}

/* Cast all NCOL rays from the current camera and draw the wall slices into the canvas. noinline
 * bounds a16/xy16 register pressure (handoff §4). */
__attribute__((noinline))
static void render_view(App *a) {
  canvas_clear(&a->canvas);
  for (uint16_t j = 0; j < NCOL; j++) {
    int16_t camX = (int16_t)((int32_t)(2 * (int16_t)j - (int16_t)NCOL) * 256 / (int16_t)NCOL);
    int16_t rdx, rdy;
    rc_ray_dir(&a->cam, camX, &rdx, &rdy);
    rc_hit hit;
    rc_cast(a->cam.px, a->cam.py, rdx, rdy, &hit);
    int16_t h = rc_wall_height(hit.dist);          /* 0..RC_VIEWH */
    int16_t y0 = (int16_t)((RC_VIEWH - h) / 2);
    int16_t y1 = (int16_t)(y0 + h - 1);
    uint8_t col = shade(hit.dist);
    int16_t x = (int16_t)(j * 2u);
    canvas_line(&a->canvas, x,            y0, x,            y1, col);
    canvas_line(&a->canvas, (int16_t)(x + 1), y0, (int16_t)(x + 1), y1, col);
  }
}

/* Auto-walk: step forward if the cell ahead is open, else turn (a simple maze wander). */
static void advance_camera(App *a) {
  int16_t nx = (int16_t)(a->cam.px + (int16_t)(((int32_t)RC_COS(a->cam.ang) * MOVE_STEP) >> 8));
  int16_t ny = (int16_t)(a->cam.py + (int16_t)(((int32_t)RC_SIN(a->cam.ang) * MOVE_STEP) >> 8));
  if (!rc_wall((int16_t)(nx >> 8), (int16_t)(ny >> 8))) {
    a->cam.px = nx; a->cam.py = ny;
  } else {
    a->cam.ang = (uint8_t)(a->cam.ang + TURN_STEP);
  }
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  a->cam.px = (int16_t)((4 << 8) | 0x80);   /* (4.5, 11.5) in the long E-W corridor */
  a->cam.py = (int16_t)((11 << 8) | 0x80);
  a->cam.ang = 0u;                          /* facing east */
  text_puts(&a->text, 0, 1, "RAYCASTER  DDA GRID-CAST");
  text_puts(&a->text, 1, 0, "WALL = SCREEN H / DISTANCE");
}

int main(void) {
  static App a;
  app_init(&a);

  /* Title overlay (BG2), held while the gate-CRC computes, then torn down before the maze renders. */
  static TitleLayer title;
  title_begin16(&a.screen, &title, "RAYCASTER", "MAZE");

  corpus_result = rc_gate_crc();                  /* self-verify raycaster == host 0x724B */
  title_end(&a.screen, &title, 110);                   /* ~2 s title */

  for (;;) {
    render_view(&a);                              /* clear + cast 64 rays + draw slices */
    /* Drain the canvas DMA (capped 64 tiles/frame → ~4 v-blanks) before advancing, so each complete
       view is shown without tearing. */
    do { display_frame(&a.screen); } while (a.canvas.lo <= a.canvas.hi);
    advance_camera(&a);
  }
}
