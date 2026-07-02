// 256-bit Modular Exponentiation — #104 of the compiler stress-test battery (Round 6, Cluster C final).
// Re-stresses patch 0017's s64 (un)merge glue (#61 dhmix) as a HIGH-VOLUME regression guard: a 256-bit
// Diffie-Hellman modexp built from uint32[8] limbs + uint64 multiply-accumulate — no s128/s256 node,
// so it re-runs the green s64 path hundreds of times under register pressure. Builds default-8-bit AND
// +mos-a16 AND +mos-xy16 (5-way bar).
//
// Visual: the 256-bit Diffie-Hellman shared secret rendered as a 16×16 field of colour cells (2 bits
// per cell from the secret's 256 bits). Computed once at startup (the modexp is heavy); a slow palette
// cycle keeps it alive. A modmul miscompile (a dropped/duplicated s64 lane) breaks A^b==B^a AND the CRC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/modexp256.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        4
#define WIN_W       16
#define WIN_H       16

static uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  4, 16),
    SNES_RGB( 4, 20, 16),
    SNES_RGB(26, 12,  2),
    SNES_RGB(30, 28, 10),
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      cellcol[WIN_H][WIN_W];
    uint16_t     t;
    uint8_t      band;
    uint8_t      pal_phase;
} App;

volatile uint16_t corpus_result;

// Compute one 256-bit DH shared secret and colour the field from its 256 bits (2 bits/cell).
static void compute_field(App *a, uint16_t seed) {
    U256 g;
    me_set_u32(&g, (uint32_t)(7u + seed));
    g.w[3] = (uint32_t)(0x9E3779B9u ^ (uint32_t)seed);
    g.w[6] = (uint32_t)(0x12345678u + (uint32_t)seed);
    uint32_t sa = (uint32_t)((seed + 1u) * 0x00010007u) & 0xFFu; if (sa == 0u) sa = 7u;
    uint32_t sb = (uint32_t)((seed + 3u) * 0x00030005u) & 0xFFu; if (sb == 0u) sb = 11u;
    U256 A, B, secret;
    me_modexp(&A, &g, sa);
    me_modexp(&B, &g, sb);
    me_modexp(&secret, &B, sa);   // the shared secret (== A^sb)
    for (uint8_t r = 0u; r < (uint8_t)WIN_H; r++) {
        for (uint8_t c = 0u; c < (uint8_t)WIN_W; c++) {
            uint16_t bit = (uint16_t)(((uint16_t)r * (uint16_t)WIN_W + (uint16_t)c) & 0xFFu);  // 0..255
            uint8_t limb = (uint8_t)(bit >> 5);          // which of 8 u32 limbs
            uint8_t sh   = (uint8_t)((bit & 31u) & 30u); // even bit position within the limb
            a->cellcol[r][c] = (uint8_t)((secret.w[limb] >> sh) & 3u);
        }
    }
}

static void cell_fill(BitmapCanvas *cv, uint8_t cx, uint8_t cy, uint8_t color) {
    uint16_t tile = (uint16_t)((uint16_t)cy * (uint16_t)CANVAS_TILES_W + (uint16_t)cx);
    uint8_t *t = &cv->chr[tile * (uint16_t)CANVAS_TILEBYTES];
    uint8_t p0 = (uint8_t)((color & 1u) ? 0xFFu : 0u);
    uint8_t p1 = (uint8_t)((color & 2u) ? 0xFFu : 0u);
    for (uint8_t r = 0u; r < 8u; r++) { t[r * 2u] = p0; t[r * 2u + 1u] = p1; }
}

__attribute__((noinline))
static void field_band(App *a) {
    uint8_t y0 = (uint8_t)((uint8_t)(a->band) * (uint8_t)BAND);
    for (uint8_t cy = y0; cy < (uint8_t)(y0 + (uint8_t)BAND) && cy < (uint8_t)WIN_H; cy++)
        for (uint8_t cx = 0u; cx < (uint8_t)WIN_W; cx++)
            cell_fill(&a->canvas, cx, cy, a->cellcol[cy][cx]);
    uint16_t lo = (uint16_t)((uint16_t)y0 * (uint16_t)CANVAS_TILES_W);
    uint16_t hi = (uint16_t)((uint16_t)(y0 + (uint8_t)BAND) * (uint16_t)CANVAS_TILES_W - (uint16_t)1u);
    if (hi >= (uint16_t)CANVAS_NTILES) hi = (uint16_t)(CANVAS_NTILES - (uint16_t)1u);
    if (a->canvas.lo > lo) a->canvas.lo = lo;
    if (a->canvas.hi < hi) a->canvas.hi = hi;
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='T'; buf[1]='=';
    buf[2]=H[(a->t >> 12) & 0xFu]; buf[3]=H[(a->t >> 8) & 0xFu];
    buf[4]=H[(a->t >>  4) & 0xFu]; buf[5]=H[a->t & 0xFu];
    buf[6]=' '; buf[7]='C'; buf[8]='R'; buf[9]='C'; buf[10]='=';
    buf[11]=H[(corpus_result >> 12) & 0xFu]; buf[12]=H[(corpus_result >> 8) & 0xFu];
    buf[13]=H[(corpus_result >>  4) & 0xFu]; buf[14]=H[corpus_result & 0xFu];
    buf[15]=' '; buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    a->pal_phase = (uint8_t)0u;
    compute_field(a, (uint16_t)1u);
    text_puts(&a->text, 0, 2, "256-BIT DIFFIE-HELLMAN");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "MODEXP256", "256-BIT DH ON THE S64 GLUE");
    corpus_result = modexp256_gate_crc();   // runs during title; expected 0x31D4
    title_end(&a.screen, &title, 90);
    compute_field(&a, (uint16_t)1u);         // restore the display secret after the gate
    for (;;) {
        field_band(&a);
        a.band++;
        if ((uint8_t)((uint8_t)(a.band) * (uint8_t)BAND) >= (uint8_t)WIN_H) {
            a.band = (uint8_t)0u;
            a.t = (uint16_t)(a.t + (uint16_t)1u);
            update_hud(&a);
            // slow palette cycle for liveliness (cheap — no per-frame modexp).
            a.pal_phase++;
            uint8_t k = (uint8_t)(a.pal_phase & 31u);
            bg3_pal[1] = SNES_RGB((uint8_t)(4u + (k >> 1)), 20u, 16u);
            bg3_pal[2] = SNES_RGB(26u, (uint8_t)(6u + (k >> 2)), 2u);
            upq_push_cgram(&a.screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
        }
        display_frame(&a.screen);
    }
}
