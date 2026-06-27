// N-body orbits on the SNES — #13 of the compiler stress-test demo battery.
//
// Three bodies (Sun + Earth + Jupiter-like) orbit under Newtonian gravity via
// Symplectic Euler integration.  Codegen under test:
//   - 16×16→32 __mulsi3 (r² = dx*dx + dy*dy per body-pair, hot path)
//   - __udivsi3 (GRAV_K * mj / r² per body-pair — the 1/r² force, STRESS #2)
//   - 32-bit multiply (dx * inv_r2 directional force components, STRESS #3)
//
// Trail: bodies accumulate on a 128×128 2bpp BitmapCanvas.  CGRAM[3] (trail
// colour) dims each FADE_INTERVAL frames; after FADE_CYCLE frames canvas_clear()
// + ring-buffer redraw resets the scene and CGRAM restores to max brightness.
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16
// → full 5-way differential bar.
//
// See docs/plans/2026-06-27-13-snes-nbody-orbits.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/upload.h"
#include "../65816/nbody.h"

// ---------------------------------------------------------------------------
// VRAM layout
#define CANVAS_CHR   0x0000u   // BG3 chr base (word): tiles 0..255 canvas, 256 blank, 257+ font
#define CANVAS_MAP   0x4000u   // BG3 tilemap base (word)
#define BOX_COL      8u        // canvas box cols 8..23 (px 64..191, centred)
#define BOX_ROW      6u        // canvas box rows 6..21 (px 48..175)
#define HUD_TOP_ROW  23u       // text bar 0 — frame counter + mode
#define HUD_BOT_ROW  25u       // text bar 1 — body positions

// ---------------------------------------------------------------------------
// CGRAM: 4 colours for BG3 2bpp (shared by canvas trails and text).
//   0 = black background (constant)
//   1 = near-white text  (constant — never dimmed)
//   2 = dim orange trail (constant — ring-buffer re-draw colour)
//   3 = active cyan trail (dims each FADE_INTERVAL frames; reset after FADE_CYCLE)
static uint16_t bg3_pal[4] = {
    SNES_RGB( 0,  0,  0),    // 0: background
    SNES_RGB(24, 24, 24),    // 1: HUD text (near-white)
    SNES_RGB(16, 10,  0),    // 2: old trail ring-buffer (dim orange, constant)
    SNES_RGB( 0, 24, 28),    // 3: active trail (cyan — initial max brightness)
};

#define FADE_INTERVAL  3u    // frames between CGRAM[3] decrements
#define FADE_RATE      1u    // brightness subtracted per interval
#define FADE_MIN       2u    // minimum brightness (clamp here, near-black)
#define FADE_RESET    24u    // brightness after canvas_clear reset
#define FADE_CYCLE   120u    // frames per full cycle

// ---------------------------------------------------------------------------
// Trail ring buffer — 64 canvas-pixel positions per body (x,y in 0..127).
#define TRAIL_LEN     64u

typedef struct {
    int8_t  px[TRAIL_LEN];
    int8_t  py[TRAIL_LEN];
    uint8_t head;
} BodyTrail;

static void trail_push(BodyTrail *tr, int8_t px, int8_t py) {
    tr->head = (uint8_t)((tr->head + 1u) & (TRAIL_LEN - 1u));
    tr->px[tr->head] = px;
    tr->py[tr->head] = py;
}

// Re-draw the ring buffer after canvas_clear(): older half at colour 1 (dim),
// newer half at colour 2 (medium).  Called after canvas_clear() so OR-only is clean.
static void trail_redraw(BitmapCanvas *c, const BodyTrail *tr) {
    uint8_t i;
    for (i = 0; i < TRAIL_LEN; i++) {
        uint8_t age = (uint8_t)((tr->head - i + TRAIL_LEN) & (TRAIL_LEN - 1u));
        uint8_t col = (i < TRAIL_LEN / 2u) ? (uint8_t)2u : (uint8_t)1u;
        canvas_plot(c, (int16_t)(uint8_t)tr->px[age], (int16_t)(uint8_t)tr->py[age], col);
    }
}

// ---------------------------------------------------------------------------
// Decimal formatter: uint16_t → string, returns chars written.
static uint8_t fmt_u16(uint16_t v, char *buf) {
    uint8_t n = 0;
    if (v >= 10000u) { buf[n++] = (char)('0' + v / 10000u); v = (uint16_t)(v % 10000u); }
    if (n || v >= 1000u) { buf[n++] = (char)('0' + v / 1000u); v = (uint16_t)(v % 1000u); }
    if (n || v >= 100u)  { buf[n++] = (char)('0' + v / 100u);  v = (uint16_t)(v % 100u);  }
    if (n || v >= 10u)   { buf[n++] = (char)('0' + v / 10u);   v = (uint16_t)(v % 10u);   }
    buf[n++] = (char)('0' + v);
    buf[n] = 0;
    return n;
}

// ---------------------------------------------------------------------------
// Application state — static to avoid a large soft-stack frame.
typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    NBody        bodies[NBODY_N];
    BodyTrail    trail[NBODY_N];
    uint16_t     frame;
    uint8_t      fade_bright;  // current CGRAM[3] brightness (G channel)
    uint8_t      fade_timer;   // frames until next CGRAM dim
    uint8_t      cycle_timer;  // frames until next canvas_clear reset
    uint8_t      cgram_dirty;  // set when bg3_pal[3] changed; cleared after upload
} App;

volatile uint16_t corpus_result;  // gate proof channel (WRAM; read by gate script)

// ---------------------------------------------------------------------------
// Reset cycle: clear canvas, re-draw old trail at low colours, restore CGRAM.
static void do_reset(App *a) {
    uint8_t i;
    canvas_clear(&a->canvas);
    for (i = 0; i < NBODY_N; i++)
        trail_redraw(&a->canvas, &a->trail[i]);
    // Current positions plotted at colour 3 (appears bright after CGRAM restore below)
    for (i = 0; i < NBODY_N; i++) {
        canvas_plot(&a->canvas,
                    (int16_t)(a->bodies[i].x >> 8),
                    (int16_t)(a->bodies[i].y >> 8), 3);
    }
    a->fade_bright  = FADE_RESET;
    a->cycle_timer  = 0;
    a->fade_timer   = 0;
    bg3_pal[3] = SNES_RGB(0u, a->fade_bright,
                          (uint8_t)(a->fade_bright + 4u <= 31u ? a->fade_bright + 4u : 31u));
    a->cgram_dirty = 1;
}

// ---------------------------------------------------------------------------
// Init.
static void app_init(App *a) {
    uint8_t i;
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);

    // Palette: uploaded in force-blank during first display_frame (via the queue).
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint16_t)sizeof bg3_pal);

    nbody_init(a->bodies);
    for (i = 0; i < NBODY_N; i++) {
        uint8_t j;
        int8_t  px = (int8_t)(a->bodies[i].x >> 8);
        int8_t  py = (int8_t)(a->bodies[i].y >> 8);
        for (j = 0; j < TRAIL_LEN; j++) {
            a->trail[i].px[j] = px;
            a->trail[i].py[j] = py;
        }
        a->trail[i].head = 0;
    }
    a->frame       = 0;
    a->fade_bright = FADE_RESET;
    a->fade_timer  = 0;
    a->cycle_timer = 0;
    a->cgram_dirty = 0;

    text_puts(&a->text, 0, 0, "NBODY N=3  FRAME:");
    text_puts(&a->text, 1, 0, "SUN X=  Y=   E X=  Y=   J X=  Y=  ");
}

// ---------------------------------------------------------------------------
// HUD text update (called every 4 frames).
static void hud_update(App *a) {
    char buf[6];

    // Row 0: frame counter at col 17
    fmt_u16(a->frame, buf);
    text_puts(&a->text, 0, 17, "     ");  // clear 5 chars
    text_puts(&a->text, 0, 17, buf);

    // Row 1: body positions (Sun X/Y, Earth X/Y, Jupiter X/Y)
    // "SUN X=XX Y=XX   E X=XX Y=XX   J X=XX Y=XX"
    fmt_u16((uint16_t)((uint8_t)(a->bodies[0].x >> 8)), buf);
    text_puts(&a->text, 1,  6, "  "); text_puts(&a->text, 1,  6, buf);
    fmt_u16((uint16_t)((uint8_t)(a->bodies[0].y >> 8)), buf);
    text_puts(&a->text, 1,  9, "  "); text_puts(&a->text, 1,  9, buf);
    fmt_u16((uint16_t)((uint8_t)(a->bodies[1].x >> 8)), buf);
    text_puts(&a->text, 1, 17, "  "); text_puts(&a->text, 1, 17, buf);
    fmt_u16((uint16_t)((uint8_t)(a->bodies[1].y >> 8)), buf);
    text_puts(&a->text, 1, 20, "  "); text_puts(&a->text, 1, 20, buf);
    fmt_u16((uint16_t)((uint8_t)(a->bodies[2].x >> 8)), buf);
    text_puts(&a->text, 1, 28, "  "); text_puts(&a->text, 1, 28, buf);
    fmt_u16((uint16_t)((uint8_t)(a->bodies[2].y >> 8)), buf);
    text_puts(&a->text, 1, 31, buf[0] ? buf : "  ");
}

// ---------------------------------------------------------------------------
// Main entry point.
int main(void) {
    static App a;
    uint8_t i;

    app_init(&a);

    // Compute the gate CRC before entering the display loop.
    // nbody_gate_crc() uses its own local NBody array, so the running sim is unaffected.
    corpus_result = nbody_gate_crc();

    for (;;) {
        // 1. Physics: one Symplectic Euler step.
        nbody_step(a.bodies);
        a.frame++;
        a.cycle_timer++;
        a.fade_timer++;

        // 2. Plot current body positions (colour 3 = active trail).
        for (i = 0; i < NBODY_N; i++) {
            int16_t px = a.bodies[i].x >> 8;
            int16_t py = a.bodies[i].y >> 8;
            canvas_plot(&a.canvas, px, py, 3);
            trail_push(&a.trail[i], (int8_t)(uint8_t)(px & 0x7F),
                                    (int8_t)(uint8_t)(py & 0x7F));
        }

        // 3. CGRAM fade: dim colour 3 every FADE_INTERVAL frames.
        if (a.fade_timer >= FADE_INTERVAL) {
            a.fade_timer = 0;
            if (a.fade_bright > FADE_MIN)
                a.fade_bright = (uint8_t)(a.fade_bright - FADE_RATE);
            uint8_t b = (uint8_t)(a.fade_bright + 4u <= 31u ? a.fade_bright + 4u : 31u);
            bg3_pal[3] = SNES_RGB(0u, a.fade_bright, b);
            a.cgram_dirty = 1;
        }

        // 4. Full reset after FADE_CYCLE frames.
        if (a.cycle_timer >= FADE_CYCLE)
            do_reset(&a);

        // 5. Upload changed CGRAM palette.
        if (a.cgram_dirty) {
            upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00u, (uint16_t)sizeof bg3_pal);
            a.cgram_dirty = 0;
        }

        // 6. HUD refresh every 4 frames (frame counter + body coords).
        if ((a.frame & 3u) == 0u)
            hud_update(&a);

        // 7. V-blank: emit dirty tiles + text rows, then DMA-flush everything.
        display_frame(&a.screen);
    }
}
