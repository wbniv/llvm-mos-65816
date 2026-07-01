// Protothread Critter Swarm — #51 of the compiler stress-test demo battery.
// A swarm of critters, each a RESUMABLE protothread (examples/65816/critters.h — the same critter_step
// the host oracle tools/critters-sim.c and the corpus slice run) that yields each frame and resumes its
// scripted box-patrol via a saved continuation index. No far pointers -> builds default-8-bit AND
// +mos-a16 AND +mos-xy16, the full 5-way bar.
//
// Codegen under test: resumable-function state preservation — an on-entry switch dispatch on the saved
// case index (lc) with case labels inside loops (mid-loop re-entry) and local state kept in the struct.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/critters.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25

static const uint16_t bg3_pal[4] = {
  SNES_RGB(2, 3, 8), SNES_RGB(30, 14, 10), SNES_RGB(12, 30, 14), SNES_RGB(28, 26, 30),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  Critter      cr[NCRIT];
} App;

volatile uint16_t corpus_result;  // protothread swarm fold (read from WRAM by the gate)

// Advance every critter's protothread one step and plot it. noinline caps a16/xy16 pressure.
__attribute__((noinline))
static void swarm_step(App *a) {
  canvas_clear(&a->canvas);
  for (uint8_t i = 0; i < NCRIT; i++) {
    critter_step(&a->cr[i]);                       // resume this protothread one step
    int16_t x = a->cr[i].x, y = a->cr[i].y;
    uint8_t col = a->cr[i].color;
    canvas_plot(&a->canvas, x, y, col);            // 2x2 critter dot
    canvas_plot(&a->canvas, (int16_t)(x + 1), y, col);
    canvas_plot(&a->canvas, x, (int16_t)(y + 1), col);
    canvas_plot(&a->canvas, (int16_t)(x + 1), (int16_t)(y + 1), col);
  }
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  critters_init(a->cr);
  text_puts(&a->text, 0, 1, "PROTOTHREAD CRITTERS");
  text_puts(&a->text, 1, 0, "RESUMABLE  SAVED CASE-INDEX YIELD");
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "CRITTERS", "PROTOTHREADS");
  corpus_result = critters_gate_crc();          // self-verify the protothread swarm == host 0xAD9F
  title_end(&a.screen, &title, 110);
  critters_init(a.cr);                           // fresh swarm for the live visual
  for (;;) {
    swarm_step(&a);
    display_frame(&a.screen);
  }
}
