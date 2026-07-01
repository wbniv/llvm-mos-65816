// Saturating Palette Comet Trails — #75 of the compiler stress-test demo battery.
// Renders a 16x16 tile glow field updated by saturating add/sub operations via the
// __builtin_elementwise_add_sat/sub_sat intrinsics on uint8_t and int16_t.
// Builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers -> full 5-way bar).
//
// Codegen corners: G_UADDSAT + G_USUBSAT (uint8 glow/decay) AND G_SADDSAT + G_SSUBSAT
// (int16 velocity kicks) all via .lower() at MOSLegalizerInfo.cpp:246 ->
// lowerAddSubSatToMinMax (branchless min/max clamp).
// Distinct from #44 hdr-bloom (G_UADDO = flag-test+branch, not sat clamp) and
// #70 dither (hand-written ternary = G_ICMP+G_SELECT, not the sat-intrinsic legalizer).
//
// Visual: 6 comets streak across the 128x128 BG3 2bpp canvas leaving glowing trails
// that additively saturate to white where they cross (no wrap-to-white flicker), then
// fade cleanly to black via saturating decay. TitleLayer intro while gate CRC runs.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256       // full 16x16 = 256 tiles flush in one v-blank
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/satcomet.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4

// BG3 2bpp palette: black -> dim cyan -> bright cyan -> saturated white.
// White tiles show where comets cross (UADD_SAT8 clamped to 255).
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB(0, 0, 0),            // 0: dark background
    SNES_RGB(4, 14, 18),          // 1: dim glow trail (dark cyan)
    SNES_RGB(8, 26, 28),          // 2: bright glow (saturated cyan)
    SNES_RGB(31, 31, 31),         // 3: white (fully saturated = crossing comets)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      glow[SC_GW][SC_GW];
    SCComet      comets[SC_NC];
    uint16_t     t;
} App;

volatile uint16_t corpus_result;

// Map uint8_t brightness to BG3 2bpp colour (0..3).
static inline uint8_t brightness_to_color(uint8_t b) {
    if (b >= (uint8_t)201u) return (uint8_t)3u;   // white: saturated cross
    if (b >= (uint8_t)121u) return (uint8_t)2u;   // bright cyan
    if (b >= (uint8_t)41u)  return (uint8_t)1u;   // dim trail
    return (uint8_t)0u;                             // dark background
}

// Fill an 8x8 tile at (cx,cy) with solid 2bpp colour.
static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *tp = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { tp[r * 2u] = p0; tp[r * 2u + 1u] = p1; }
}

// Redraw the full 16x16 glow field into the canvas from the glow array.
__attribute__((noinline))
static void redraw_field(App *a) {
    for (uint8_t y = (uint8_t)0u; y < (uint8_t)SC_GW; y++) {
        for (uint8_t x = (uint8_t)0u; x < (uint8_t)SC_GW; x++) {
            cell_fill(&a->canvas, x, y, brightness_to_color(a->glow[y][x]));
        }
    }
    a->canvas.lo = (uint16_t)0u;
    a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    sc_init(a->glow, a->comets);
    a->t = (uint16_t)0u;
    text_puts(&a->text, 0, 2, "SAT COMETS  UADD_SAT");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "SAT COMETS", "UADD/USUB/SADD/SSUB");
    corpus_result = satcomet_gate_crc();   // expected 0xC2AF
    title_end(&a.screen, &title, 90);
    for (;;) {
        sc_step(a.glow, a.comets, a.t);
        a.t++;
        redraw_field(&a);
        // Update HUD bottom: show comet count
        text_puts(&a.text, 1, 0, "G_UADDSAT G_SADDSAT SAT");
        display_frame(&a.screen);
    }
}
