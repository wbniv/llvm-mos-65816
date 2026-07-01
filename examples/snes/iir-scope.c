// IIR Resonant-Filter Scope — #48 of the compiler stress-test demo battery.
//
// A bank of four 2-pole IIR resonators (examples/65816/iir_scope.h), arpeggiated by impulse
// "plucks", drawn as a live oscilloscope. The codegen corner is the RECURSIVE FEEDBACK dependency
// chain: y[n] = (a1*y[n-1] + a2*y[n-2]) >> Q + x[n] — each sample waits on the two previous
// outputs, so the loop can't be reordered/vectorized like #25's feed-forward FFT. A small runtime
// vibrato on a1 keeps the feedback multiply a genuine 32-bit __mulsi3 (real filters tune their
// coefficients) and makes the chord chorus-wobble.
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
// corpus_result = iir_scope_gate_crc() (400 samples), set once at startup.
// See docs/plans/2026-06-30-48-snes-iir-scope.md.
#include <snes.h>
#include "snesgfx/display.h"
// The scope clears + redraws the whole canvas every frame, so the entire 256-tile canvas must
// re-DMA each frame (the default 64-tile cap only refreshes the top 4 tile-rows → the centre trace
// never reaches VRAM). 256 tiles × 16 B = 4096 B, flushed under display_frame's force-blank; the
// demo does little else per frame, so this fits.
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/iir_scope.h"

#define CANVAS_CHR  0x0000      // BG3 char base (word)
#define CANVAS_MAP  0x4000      // BG3 tilemap base (word)
#define BOX_COL     8           // 16-tile canvas box at cols 8..23 (screen px 64..191)
#define BOX_ROW     5           // rows 5..20 (screen px 40..167)
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 24
#define SCOPE_MID   (CANVAS_H / 2)   // 64 — the zero line

// BG3 2bpp palette (CGRAM 0..3): 0 black, 1 white (HUD text), 2 dim (axis), 3 green (trace).
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(6, 10, 8), SNES_RGB(6, 31, 12),
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    iir_state    iir;
} App;

volatile uint16_t corpus_result;   // IIR feedback proof channel (read from WRAM by the gate)

// Draw the ring buffer as a connected oscilloscope trace, oldest sample at the left.
__attribute__((noinline))
static void draw_scope(App *a) {
    canvas_clear(&a->canvas);
    canvas_line(&a->canvas, 0, SCOPE_MID, (int16_t)(CANVAS_W - 1), SCOPE_MID, 2);  // zero axis
    int16_t px = 0, py = SCOPE_MID;
    for (uint16_t i = 0; i < SCOPE_W; i++) {
        int16_t v = a->iir.buf[(uint16_t)((a->iir.head + i) & (SCOPE_W - 1u))];
        int16_t y = (int16_t)(SCOPE_MID - (v >> 8));   // scale ~±35 px around the zero line
        if (y < 0) y = 0; else if (y > (int16_t)(CANVAS_H - 1)) y = (int16_t)(CANVAS_H - 1);
        if (i > 0) canvas_line(&a->canvas, px, py, (int16_t)i, y, 3);
        px = (int16_t)i; py = y;
    }
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00, (uint8_t)sizeof bg3_pal);
    iir_init(&a->iir);
    text_puts(&a->text, 0, 2, "IIR RESONANT SCOPE");
    text_puts(&a->text, 1, 0, "FEEDBACK Y[N] FROM Y[N-1] Y[N-2]");
}

int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin16(&a.screen, &title, "IIR RESONATOR", "FEEDBACK SCOPE");
    corpus_result = iir_scope_gate_crc();   // self-verify feedback math == host
    iir_init(&a.iir);                       // re-arm the live filter bank
    title_end(&a.screen, &title, 100);

    for (;;) {
        iir_frame(&a.iir);
        draw_scope(&a);
        display_frame(&a.screen);
    }
}
