// Free-List Pool Allocator — #41 of the compiler stress-test demo battery.
// A particle fountain whose slots are recycled through a manual singly-linked LIFO free list threaded
// through the slots themselves (examples/65816/poolfx.h — the same header the host oracle
// tools/poolfx-sim.c and the corpus slice run). Particles are allocated on spawn (pop the free head)
// and freed on death (push back). No far pointers -> the program builds default-8-bit AND +mos-a16
// AND +mos-xy16, so it earns the full 5-way differential bar.
//
// Codegen under test: free-list pointer/index recycling — `head = slot[head].next` on alloc,
// `slot[i].next = head; head = i` on free — a struct-array-indexed linked-list chase the other demos
// never ran (#31's pool is append-only bump+reset; this one recycles individual slots every frame).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full-canvas clear+redraw fits ONE v-blank (4 KB; see #16)
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/poolfx.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4                // BG3 2bpp: bg + 3 spark colours

// BG3 2bpp palette (CGRAM 0..3): transparent, cool-blue ember, teal, hot amber-white.
static const uint16_t bg3_pal[NCOL] = {
  SNES_RGB(1, 2, 6), SNES_RGB(6, 12, 31), SNES_RGB(14, 30, 26), SNES_RGB(31, 28, 12),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  Pool         pool;
} App;

volatile uint16_t corpus_result;  // free-list fountain state fold (read from WRAM by the gate)

// Map a particle's remaining life to a spark colour: young=hot(3), cooling to cool-blue(1).
static inline uint8_t spark_color(int16_t life) {
  if (life >= 40) return 3u;
  if (life >= 20) return 2u;
  return 1u;
}

// Advance + draw the fountain one frame. noinline caps the a16/xy16 register pressure of the loop.
__attribute__((noinline))
static void field_step(App *a) {
  fountain_step(&a->pool);
  canvas_clear(&a->canvas);
  for (uint16_t i = 0; i < POOL_N; i++) {
    Particle *q = &a->pool.p[i];
    if (q->life <= 0) continue;                          // free slot
    int16_t px = (int16_t)(q->x >> PFX_FX);
    int16_t py = (int16_t)(q->y >> PFX_FX);
    uint8_t col = spark_color(q->life);
    canvas_plot(&a->canvas, px, py, col);                // the spark
    canvas_plot(&a->canvas, (int16_t)(px + 1), py, col); // 2x1 so it reads at 128px
  }
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  pool_init(&a->pool);
  pfx_rng = 0xACE1u;
  text_puts(&a->text, 0, 1, "FREE-LIST FOUNTAIN");
  text_puts(&a->text, 1, 0, "48-SLOT POOL  ALLOC POP  FREE PUSH");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "POOL FOUNTAIN", "FREE-LIST ALLOC");
  corpus_result = poolfx_gate_crc();            // self-verify the free-list math == host 0x2B9B
  title_end(&a.screen, &title, 110);
  pool_init(&a.pool);                            // fresh pool for the live visual
  pfx_rng = 0x1234u;
  for (;;) {
    field_step(&a);
    display_frame(&a.screen);
  }
}
