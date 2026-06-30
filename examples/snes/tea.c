// TEA cipher avalanche — demo #30 of the compiler stress-test battery.
//
// Standard 32-round TEA (Tiny Encryption Algorithm) paints a 16×16 tile grid on a
// 128×128 BitmapCanvas: each tile is coloured solid-black or solid-orange based on
// bit 0 of tea_encipher({tile_index, key_variant}, key).
//
// The hot loop stresses 32-bit constant-shift + add + XOR with NO multiply and NO divide:
//   v0 += ((v1<<4) + k[0]) ^ (v1+sum) ^ ((v1>>5) + k[1])
//   v1 += ((v0<<4) + k[2]) ^ (v0+sum) ^ ((v0>>5) + k[3])
// Under +mos-a16 this exercises: rep/sep bracketed 16-bit arithmetic for 32-bit add/XOR,
// and either __ashlsi3/__lshrsi3 libcalls (at -Os for code size) or inline ASL+ROL chains
// for the constant-shift steps — both corners are novel vs the multiply/divide battery.
//
// Avalanche effect: each of 16 key variants differs by 1 bit from the previous. Correct TEA
// produces a completely different-looking tile pattern for each variant; a miscompile shows
// structured patterns or wrong correlation — the differential immediately catches it.
//
// No far pointers → 5-way differential bar (host==default==+mos-a16==+mos-xy16==bsnes-jg).
// See docs/plans/2026-06-30-30-snes-tea-cipher.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "../65816/tea.h"

// BG3 layout
#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 2
#define HUD_BOT_ROW 25

// Number of 1-bit-flip key variants to cycle through
#define KEY_VARIANTS 16u
// Tiles painted per frame (TEA calls)
#define TILES_PER_FRAME 4u
// Hold time (frames) once canvas is fully painted
#define N_HOLD 80u

// BG3 2bpp palette (CGRAM[0..3]):
//   0=black(bg/bit0)  1=near-white(text)  2=orange(bit1)  3=amber(accent)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(24, 24, 24),
    SNES_RGB(28, 14, 0), SNES_RGB(31, 20, 0),
};

// -------------------------------------------------------------------------
// HUD formatting
// -------------------------------------------------------------------------

static inline void fmt2(char *buf, uint8_t v) {
    buf[0] = (char)('0' + (uint8_t)(v / 10u));
    buf[1] = (char)('0' + (uint8_t)(v % 10u));
}

// -------------------------------------------------------------------------
// Tile painting (direct write into BitmapCanvas chr shadow)
// -------------------------------------------------------------------------

// Paint an 8×8 tile at (tx, ty) solid with 2bpp color (0..3).
static void paint_tile_solid(BitmapCanvas *c, uint8_t tx, uint8_t ty, uint8_t color) {
    uint16_t tidx = (uint16_t)((uint16_t)ty * (uint16_t)CANVAS_TILES_W + (uint16_t)tx);
    uint8_t *t = &c->chr[tidx * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (color & 1u) ? 0xFFu : 0x00u;
    uint8_t p1 = (color & 2u) ? 0xFFu : 0x00u;
    for (uint8_t row = 0; row < 8u; row++) {
        t[(uint8_t)(row * 2u)    ] = p0;
        t[(uint8_t)(row * 2u + 1u)] = p1;
    }
    if (tidx < c->lo) c->lo = tidx;
    if (tidx > c->hi) c->hi = tidx;
}

// -------------------------------------------------------------------------
// Application state
// -------------------------------------------------------------------------

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      key_var;    // current key variant (0..KEY_VARIANTS-1)
    uint16_t     tile;       // next tile index to paint (0..255)
    uint16_t     hold;       // hold-phase countdown
} App;

volatile uint16_t corpus_result;

// -------------------------------------------------------------------------
// Key construction: key_var flips bit key_var of TEA_KEY[0]
// -------------------------------------------------------------------------

static void make_key(uint8_t var, uint32_t k[4]) {
    k[0] = TEA_KEY[0] ^ ((uint32_t)1u << (uint8_t)(var & 31u));
    k[1] = TEA_KEY[1];
    k[2] = TEA_KEY[2];
    k[3] = TEA_KEY[3];
}

// -------------------------------------------------------------------------
// Draw TILES_PER_FRAME tiles using TEA  (noinline: bounds RA pressure)
// -------------------------------------------------------------------------

__attribute__((noinline))
static void paint_tiles(App *a, uint16_t n) {
    uint32_t k[4];
    make_key(a->key_var, k);
    for (uint16_t c = 0; c < n && a->tile < (uint16_t)CANVAS_NTILES; c++, a->tile++) {
        uint8_t tx = (uint8_t)(a->tile & 0x0Fu);
        uint8_t ty = (uint8_t)(a->tile >> 4);
        uint32_t v[2] = { (uint32_t)a->tile, (uint32_t)a->key_var };
        tea_encipher(v, k);
        uint8_t color = (v[0] & 1u) ? 2u : 0u;
        paint_tile_solid(&a->canvas, tx, ty, color);
    }
}

// -------------------------------------------------------------------------
// HUD
// -------------------------------------------------------------------------

static void hud_top(App *a) {
    char line[32] = "#30 TEA CIPHER    KEY:  ";
    fmt2(line + 22, a->key_var);
    text_clear_bar(&a->text, 0);
    text_puts(&a->text, 0, 0, line);
}

static void hud_bot(App *a) {
    text_clear_bar(&a->text, 1);
    text_puts(&a->text, 1, 0, "32 ROUNDS  DELTA:9E37  XOR");
}

// -------------------------------------------------------------------------
// Init and main
// -------------------------------------------------------------------------

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->key_var = 0;
    a->tile    = 0;
    a->hold    = 0;
}

int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin(&a.screen, &title, "TEA CIPHER", "AVALANCHE");

    corpus_result = tea_gate_crc();

    title_end(&a.screen, &title, 90);

    hud_top(&a);
    hud_bot(&a);

    for (;;) {
        if (a.tile < (uint16_t)CANVAS_NTILES) {
            paint_tiles(&a, TILES_PER_FRAME);
        } else {
            a.hold++;
            if (a.hold >= (uint16_t)N_HOLD) {
                a.key_var = (uint8_t)((a.key_var + 1u) % (uint8_t)KEY_VARIANTS);
                a.tile = 0;
                a.hold = 0;
                canvas_clear(&a.canvas);
                hud_top(&a);
            }
        }
        display_frame(&a.screen);
    }
}
