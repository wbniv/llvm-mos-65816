// qsort + Comparator-Callback Sort Visualizer — #46 of the compiler stress-test demo battery.
// Bars reshuffle, then re-sort under a rotating libc-qsort comparator (ascending / evens-first /
// descending), each comparator a function pointer qsort calls BACK into per comparison
// (examples/65816/qsortviz.h — the same qsort + comparators the host oracle tools/qsortviz-sim.c and
// the corpus slice run). No far pointers -> builds default-8-bit AND +mos-a16 AND +mos-xy16, the full
// 5-way bar.
//
// Codegen under test: libc qsort with a function-pointer comparator — the indirect-comparator ABI.
// THIS DEMO CAUGHT A REAL BACKEND BUG: the `(x>y)-(x<y)` comparator idiom emits G_SCMP, which the mos
// GlobalISel legalizer had no rule for ("unable to legalize G_SCMP" -> backend abort). Fixed by
// lowering G_SCMP/G_UCMP to icmp+select in MOSLegalizerInfo. See docs/plans/2026-06-30-46-snes-qsortviz.md.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/qsortviz.h"

#define CANVAS_CHR  0x0000
#define CANVAS_MAP  0x4000
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define VIS_N       32u              // bars shown (4 px wide each -> 128 px)
#define BARW        4u
#define EPOCH_FRAMES 80u             // idle frames between shuffle/sort epochs
#define MUTATIONS_PER_FRAME 6u       // show the latest real array after each batch of mutations

static const uint16_t bg3_pal[4] = {
  SNES_RGB(1, 2, 6), SNES_RGB(30, 12, 8), SNES_RGB(30, 26, 6), SNES_RGB(10, 28, 18),
};

typedef struct {
  Display      screen;
  BitmapCanvas canvas;
  TextLayer    text;
  int16_t      bar[VIS_N];
  uint16_t     epoch;
  uint8_t      phase;                // frame counter within an epoch
} App;

volatile uint16_t corpus_result;  // qsort-callback fold (read from WRAM by the gate)

// A vertical bar's colour by value bucket (0..3).
static uint8_t bar_color(int16_t v) {
  if (v >= 750) return 3u;
  if (v >= 500) return 2u;
  if (v >= 250) return 1u;
  return 1u;
}

static void draw_bars(App *a) {
  canvas_clear(&a->canvas);
  for (uint8_t c = 0; c < VIS_N; c++) {
    int16_t v = a->bar[c];
    uint8_t h = (uint8_t)(((int32_t)v * (CANVAS_H - 4)) / 1000);   // scale 0..1000 -> 0..124 px
    uint8_t col = bar_color(v);
    int16_t x0 = (int16_t)(c * BARW);
    for (int16_t y = (int16_t)(CANVAS_H - 1); y > (int16_t)(CANVAS_H - 1 - h); y--)
      for (uint8_t bxp = 0; bxp < BARW - 1u; bxp++)
        canvas_plot(&a->canvas, (int16_t)(x0 + bxp), y, col);
  }
}

// libc qsort deliberately exposes only its comparator, not a swap hook. For the visual pass, the
// comparator wrappers sample the REAL array at each callback. A mutation made by qsort after one
// comparison is therefore visible on the next comparison; the final mutation is drawn when qsort
// returns. The differential gate continues to use the untouched comparators in qsortviz.h.
static App *sort_anim_app;
static int16_t sort_anim_last[VIS_N];
static uint8_t sort_anim_pending;

#ifdef QSORTVIZ_PACING_PROBE
typedef struct {
  uint16_t callbacks;
  uint16_t mutations;
  uint16_t intermediate_frames;
  uint8_t max_batch;
  uint8_t final_frames;
} QsortvizPacingProbe;

volatile QsortvizPacingProbe qsortviz_pacing_probe;
#endif

static void sort_anim_snapshot(App *a) {
  for (uint8_t i = 0; i < VIS_N; i++) sort_anim_last[i] = a->bar[i];
}

static uint8_t sort_anim_changed(App *a) {
  for (uint8_t i = 0; i < VIS_N; i++)
    if (sort_anim_last[i] != a->bar[i]) return 1u;
  return 0u;
}

static void sort_anim_tick(void) {
  App *a = sort_anim_app;
#ifdef QSORTVIZ_PACING_PROBE
  qsortviz_pacing_probe.callbacks++;
#endif
  if (!a || !sort_anim_changed(a)) return;

  sort_anim_snapshot(a);
#ifdef QSORTVIZ_PACING_PROBE
  qsortviz_pacing_probe.mutations++;
#endif
  if (++sort_anim_pending < MUTATIONS_PER_FRAME) return;

#ifdef QSORTVIZ_PACING_PROBE
  qsortviz_pacing_probe.intermediate_frames++;
  if (sort_anim_pending > qsortviz_pacing_probe.max_batch)
    qsortviz_pacing_probe.max_batch = sort_anim_pending;
#endif
  sort_anim_pending = 0u;
  draw_bars(a);
  display_frame(&a->screen);
}

static int qs_anim_cmp_asc(const void *x, const void *y) {
  sort_anim_tick();
  return qs_cmp_asc(x, y);
}

static int qs_anim_cmp_parity(const void *x, const void *y) {
  sort_anim_tick();
  return qs_cmp_parity(x, y);
}

static int qs_anim_cmp_desc(const void *x, const void *y) {
  sort_anim_tick();
  return qs_cmp_desc(x, y);
}

// Advance one epoch: even epochs reshuffle, odd epochs qsort by the next rotating comparator.
static void step_epoch(App *a) {
  static const qs_cmp_fn cmps[3] = { qs_anim_cmp_asc, qs_anim_cmp_parity, qs_anim_cmp_desc };
  static const char *names[3] = { "QSORT ASCENDING", "QSORT EVENS FIRST", "QSORT DESCENDING" };
  a->epoch++;
  if (a->epoch & 1u) {
    uint8_t ci = (uint8_t)((a->epoch >> 1) % 3u);
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 1, names[ci]);
    sort_anim_snapshot(a);
    sort_anim_pending = 0u;
#ifdef QSORTVIZ_PACING_PROBE
    qsortviz_pacing_probe.callbacks = 0u;
    qsortviz_pacing_probe.mutations = 0u;
    qsortviz_pacing_probe.intermediate_frames = 0u;
    qsortviz_pacing_probe.max_batch = 0u;
    qsortviz_pacing_probe.final_frames = 0u;
#endif
    sort_anim_app = a;
    qsort(a->bar, VIS_N, sizeof a->bar[0], cmps[ci]);   // library calls back into our comparator
    sort_anim_app = 0;
#ifdef QSORTVIZ_PACING_PROBE
    qsortviz_pacing_probe.final_frames = 1u;
#endif
  } else {
    qs_fill(a->bar, VIS_N, (uint16_t)(0x1000u + a->epoch));
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 1, "SHUFFLE");
  }
  // Also presents qsort's last mutation, which can occur after its final comparator callback.
  draw_bars(a);
}

static void app_init(App *a) {
  display_init(&a->screen);
  canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
  text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
  display_add(&a->screen, (Drawable *)&a->canvas);
  display_add(&a->screen, (Drawable *)&a->text);
  upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
  qs_fill(a->bar, VIS_N, 0x1000u);
  a->epoch = 0u;
  a->phase = 0u;
  text_puts(&a->text, 0, 1, "SHUFFLE");
  text_puts(&a->text, 1, 0, "LIBC QSORT  FN-PTR COMPARATOR CB");
  draw_bars(a);
}

int main(void) {
  static App a;
  app_init(&a);
  static TitleLayer title;
  title_begin16(&a.screen, &title, "QSORT VISUALIZER", "COMPARATOR CB");
  corpus_result = qsortviz_gate_crc();          // self-verify the qsort-callback math == host 0x8EA5
  title_end(&a.screen, &title, 110);
  for (;;) {
    if (++a.phase >= EPOCH_FRAMES) { a.phase = 0u; step_epoch(&a); }
    display_frame(&a.screen);
  }
}
