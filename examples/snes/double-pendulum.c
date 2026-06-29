// Double Pendulum chaos demo — #14 of the compiler stress-test battery.
//
// Two double pendulums with nearly-identical initial conditions swing from a shared pivot.
// Mass-2's path traces accumulate in a BitmapCanvas over time; the trajectories diverge
// exponentially — the visual signature of chaos.  Self-running (no joypad).
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential.
// See docs/plans/2026-06-27-14-snes-double-pendulum.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/dpend.h"

// BG3 layout (canvas centered in 256×224):
//   canvas 128×128 = 16×16 tiles starting at column 8, row 3 (top-centered with some margin)
#define CANVAS_CHR  0x0000u   // BG3 char base (word)
#define CANVAS_MAP  0x4000u   // BG3 tilemap base (word)
#define BOX_COL     8         // canvas left tile (col 8 → pixel 64)
#define BOX_ROW     3         // canvas top tile (row 3 → pixel 24)

// Canvas-local pivot: upper-center of the 128×128 box
#define PIV_X       63        // pivot x within canvas
#define PIV_Y       12        // pivot y within canvas (near top)
#define ARM_LEN     40        // pendulum arm length in canvas pixels

// BG3 2bpp palette (CGRAM 0..3):
//   0 = black background  1 = white (pendulum A trace)
//   2 = cyan (pendulum B trace)  3 = dim (reserved / both overlap)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0),
    SNES_RGB(31, 31, 31),
    SNES_RGB(0, 20, 28),
    SNES_RGB(12, 12, 12),
};

// Proof channel: gate CRC set once at startup; read from WRAM by jgxcheck.
volatile uint16_t corpus_result;

// ── pendulum mass-2 screen position ──────────────────────────────────────────────────────────
// Returns (x,y) of mass 2 in canvas coordinates.
// x = piv_x + (sin(th1)+sin(th2)) * ARM / 256   [integer]
// y = piv_y + (cos(th1)+cos(th2)) * ARM / 256
__attribute__((noinline))
static void mass2_pos(const dp_state_t *s, int16_t *ox, int16_t *oy) {
    int16_t s1 = DPEND_SIN_LUT(s->th1);
    int16_t c1 = DPEND_COS_LUT(s->th1);
    int16_t s2 = DPEND_SIN_LUT(s->th2);
    int16_t c2 = DPEND_COS_LUT(s->th2);
    // mass1 = pivot + arm1*(sin th1, cos th1)
    // mass2 = mass1  + arm2*(sin th2, cos th2)
    *ox = (int16_t)(PIV_X + (int16_t)(((int32_t)(s1 + s2) * ARM_LEN) >> 8));
    *oy = (int16_t)(PIV_Y + (int16_t)(((int32_t)(c1 + c2) * ARM_LEN) >> 8));
}

// ── application ──────────────────────────────────────────────────────────────────────────────

typedef struct {
    Display       screen;
    BitmapCanvas  canvas;
    dp_state_t    pA;    // pendulum A: th2 = 50
    dp_state_t    pB;    // pendulum B: th2 = 51 (1 tick offset → diverges)
} App;

// Run N integration substeps for both pendulums; plot mass-2 traces each substep.
__attribute__((noinline))
static void integrate_and_plot(App *a, uint8_t n) {
    uint8_t k;
    for (k = 0; k < n; k++) {
        int16_t ax, ay, bx, by;
        dpend_step(&a->pA);
        dpend_step(&a->pB);
        mass2_pos(&a->pA, &ax, &ay);
        mass2_pos(&a->pB, &bx, &by);
        canvas_plot(&a->canvas, ax, ay, 1);   // pendulum A: white
        canvas_plot(&a->canvas, bx, by, 2);   // pendulum B: cyan
    }
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);

    // Load palette during force-blank (before display_frame releases blank).
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);

    // Pendulum A: th1=60, th2=50, both at rest.
    a->pA.th1 = 60; a->pA.th2 = 50; a->pA.om1 = 0; a->pA.om2 = 0;
    // Pendulum B: th2=51 (one LUT-tick difference → exponential divergence).
    a->pB.th1 = 60; a->pB.th2 = 51; a->pB.om1 = 0; a->pB.om2 = 0;
}

int main(void) {
    static App a;
    app_init(&a);

    // Title overlay (BG2), added after the demo layer; held during the gate CRC, then torn down
    // before the path traces. Gate-neutral (no DMA; corpus_result is the pre-loop hash).
    static TitleLayer title;
    title_begin(&a.screen, &title, "DOUBLE PENDULUM", "CHAOS");

    // Gate CRC: deterministic 256-step hash written to WRAM before display loop.
    corpus_result = dpend_gate_crc();
    title_end(&a.screen, &title, 110);                            // ~2 s title (gate hash is fast here)

    for (;;) {
        // 4 integration substeps per frame for smoother motion.
        integrate_and_plot(&a, 4);

        // Sync to V-blank: flush dirty canvas tiles via DMA (≤ 1 KB/frame).
        display_frame(&a.screen);
    }
}
