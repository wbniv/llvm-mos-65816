/* examples/snes/newton.c — Newton's-method fractal SNES demo (#2).
 * Compiler stress-test: complex division (__divsi3) + multiply (__mulsi3) per tile.
 * Visual: basins of attraction for z³−1; 3 palettes (red/green/blue for roots 1/2/3)
 * shaded by convergence speed; 4 tiles/frame fill the 32×28 grid over ~224 frames.
 * No far pointers → full 5-way differential bar.
 * See docs/plans/2026-06-27-2-snes-newton-fractal.md                               */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "../65816/newton.h"

/* VRAM: 16 solid-colour 4bpp tiles (chr) + 32×32 tilemap */
#define NEWTON_CHR  0x0000u
#define NEWTON_MAP  0x4000u
#define NEWTON_W    32          /* tilemap columns */
#define NEWTON_ROWS    28          /* tilemap rows (leaves 4 rows for overscan) */

/* Tiles computed per frame; conservative to keep ≤50% of frame budget */
#define NEWTON_TPF  4

/* 4 palettes × 16 colours = 64 CGRAM entries (128 bytes).
 * Palette 0 = all black (diverged / background).
 * Palettes 1–3 = root 1/2/3: colour 0 = black, colours 1–15 = dark→bright.
 * Tilemap word: (root << 10) | shade  where shade=15 (fast) to 1 (slow).
 * The BG tilemap palette field is bits 10-12 (vhopppcc cccccccc), so the root
 * index (1/2/3 -> palette 1/2/3) shifts << 10, NOT << 12 (which would select the
 * uninitialised CGRAM palettes 4-5 = garbage colours). See hud.h:46. */
static const uint16_t newton_pal[64] = {
    /* Palette 0 — diverged (all black) */
    SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0),
    SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0),
    SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0),
    SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0), SNES_RGB( 0, 0, 0),
    /* Palette 1 — root 1 (z=1): red shades, dark → bright */
    SNES_RGB( 0, 0, 0),
    SNES_RGB( 4, 0, 0), SNES_RGB( 6, 0, 0), SNES_RGB( 8, 0, 0), SNES_RGB(10, 0, 0),
    SNES_RGB(12, 0, 0), SNES_RGB(14, 0, 0), SNES_RGB(16, 0, 0), SNES_RGB(18, 0, 0),
    SNES_RGB(20, 0, 0), SNES_RGB(22, 1, 1), SNES_RGB(24, 2, 2), SNES_RGB(26, 3, 3),
    SNES_RGB(28, 4, 4), SNES_RGB(30, 4, 4), SNES_RGB(31, 8, 8),
    /* Palette 2 — root 2 (ω): green shades, dark → bright */
    SNES_RGB( 0, 0, 0),
    SNES_RGB( 0, 4, 0), SNES_RGB( 0, 6, 0), SNES_RGB( 0, 8, 0), SNES_RGB( 0,10, 0),
    SNES_RGB( 0,12, 0), SNES_RGB( 0,14, 0), SNES_RGB( 0,16, 0), SNES_RGB( 0,18, 0),
    SNES_RGB( 0,20, 0), SNES_RGB( 1,22, 1), SNES_RGB( 2,24, 2), SNES_RGB( 3,26, 3),
    SNES_RGB( 4,28, 4), SNES_RGB( 4,30, 4), SNES_RGB( 8,31, 8),
    /* Palette 3 — root 3 (ω²): blue shades, dark → bright */
    SNES_RGB( 0, 0, 0),
    SNES_RGB( 0, 0, 4), SNES_RGB( 0, 0, 6), SNES_RGB( 0, 0, 8), SNES_RGB( 0, 0,10),
    SNES_RGB( 0, 0,12), SNES_RGB( 0, 0,14), SNES_RGB( 0, 0,16), SNES_RGB( 0, 0,18),
    SNES_RGB( 0, 0,20), SNES_RGB( 1, 1,22), SNES_RGB( 2, 2,24), SNES_RGB( 3, 3,26),
    SNES_RGB( 4, 4,28), SNES_RGB( 4, 4,30), SNES_RGB( 8, 8,31),
};

typedef struct {
    Drawable base;
    uint16_t shadow[NEWTON_ROWS * NEWTON_W];   /* 28×32 tilemap mirror: 1792 bytes */
    uint32_t dirty_rows;                     /* bit r set → row r needs DMA */
    uint8_t  pal_sent;                       /* 1 after first palette DMA */
} NewtonLayer;

static void _newton_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    NewtonLayer *l = (NewtonLayer *)d;
    /* 16 solid-colour 4bpp tiles in VRAM (force-blank, direct write OK).
     * Tile c: all pixels = colour index c. Pattern from rdiff.c:
     *   bp01 word = (bit1(c)?0xFF00:0) | (bit0(c)?0x00FF:0)
     *   bp23 word = (bit3(c)?0xFF00:0) | (bit2(c)?0x00FF:0)              */
    snes_vram_addr(NEWTON_CHR);
    for (uint8_t c = 0; c < 16u; c++) {
        uint16_t bp01 = (uint16_t)((c & 2u ? 0xFF00u : 0u) | (c & 1u ? 0x00FFu : 0u));
        uint16_t bp23 = (uint16_t)((c & 8u ? 0xFF00u : 0u) | (c & 4u ? 0x00FFu : 0u));
        for (uint8_t row = 0; row < 8u; row++) REG_VMDATA = bp01;
        for (uint8_t row = 0; row < 8u; row++) REG_VMDATA = bp23;
    }
    /* BG1 registers */
    REG_BG1SC   = SNES_BGSC(NEWTON_MAP, 0);
    REG_BG12NBA = (uint8_t)((NEWTON_CHR >> 12) & 0x0Fu);
    /* Zero the BG1 tilemap in VRAM. Power-on VRAM is garbage; any row not yet
       DMA'd by the progressive fill would otherwise show random tiles/colours. */
    snes_vram_addr(NEWTON_MAP);
    for (uint16_t i = 0; i < (uint16_t)(32u * 32u); i++) REG_VMDATA = 0;
    /* Shadow cleared to tile-0/palette-0 = black */
    for (uint16_t i = 0; i < (uint16_t)(NEWTON_ROWS * NEWTON_W); i++) l->shadow[i] = 0;
    l->dirty_rows = 0;
    l->pal_sent   = 0;
    l->base.tm_bits = TM_BG1;
}

static void _newton_emit(Drawable *d, UploadQueue *q) {
    NewtonLayer *l = (NewtonLayer *)d;
    /* Palette: 128 bytes (64 colours), sent once */
    if (!l->pal_sent) {
        upq_push_cgram(q, 0u, newton_pal, 0x00u, (uint16_t)sizeof newton_pal);
        l->pal_sent = 1u;
    }
    /* DMA each dirty row (64 bytes = 32 cols × 2 bytes) */
    for (uint8_t r = 0; r < NEWTON_ROWS && q->n < UPQ_MAX_JOBS; r++) {
        if (!(l->dirty_rows & ((uint32_t)1u << r))) continue;
        upq_push_vram(q,
            (uint16_t)(NEWTON_MAP + (uint16_t)r * 32u),
            &l->shadow[(uint16_t)r * 32u],
            0x00u, 64u, VMAIN_INC_HIGH_1);
        l->dirty_rows &= ~((uint32_t)1u << r);
    }
}

static const DrawableVT NEWTON_VT = { _newton_reserve, _newton_emit };

/* Compute the BG1 tilemap word for tile (tx, ty).
 * Returns (root<<10)|shade (shade=1..15, bright=fast convergence) or 0 (diverged). */
static uint16_t newton_tile(uint16_t tx, uint16_t ty) {
    /* Tile centre in Q8.8: real∈[−2,2] over 32 tiles, imag∈[1.68,−1.70] over 28 tiles */
    int16_t zr = (int16_t)((int16_t)tx * 32 - 494);   /* tx=0→−1.93, tx=31→+1.95 */
    int16_t zi = (int16_t)(430 - (int16_t)ty * 32);    /* ty=0→+1.68, ty=27→−1.69 */
    int8_t  root = newton_nearest_root(zr, zi);
    uint8_t iters = 0;
    while (!root && iters < NWT_MAX_ITER) {
        newton_step(&zr, &zi);
        iters++;
        root = newton_nearest_root(zr, zi);
    }
    if (!root) return 0x0000u;   /* did not converge: black */
    /* shade: iters=0→15 (already at root), iters=1→14, …, iters≥14→1 */
    uint8_t shade = (iters == 0u) ? 15u :
                    (iters >= 14u) ? 1u  :
                    (uint8_t)(15u - iters);
    return (uint16_t)(((uint16_t)(uint8_t)root << 10) | shade);
}

volatile uint16_t corpus_result;

int main(void) {
    static NewtonLayer layer;
    layer.base.vt = &NEWTON_VT;

    Display d;
    display_init(&d);
    display_add(&d, (Drawable *)&layer);

    /* Title overlay on BG2, added AFTER the demo layer so its REG_BG12NBA write wins. Shown while
       the slow gate-hash compute runs below (no display_frame -> the PPU holds the title on screen),
       then torn down before the progressive fill begins. Gate-neutral: no DMA, hash is pre-loop. */
    static TitleLayer title;
    title_begin16(&d, &title, "NEWTON FRACTAL", "COMPLEX DIVISION");
    display_frame(&d);                       /* release force-blank with the title visible */

    /* Gate hash runs before the display loop (no V-blank waits; ~64-128 ms emulated). */
    corpus_result = newton_gate_crc();
    title_end(&d, &title, 0);   /* no extra hold — the gate compute already held the card */

    /* Progressive rendering: NEWTON_TPF tiles/frame → full screen in ~224 frames. */
    uint16_t next_tile = 0;
    for (;;) {
        for (uint8_t t = 0; t < NEWTON_TPF; t++) {
            if (next_tile < (uint16_t)(NEWTON_W * NEWTON_ROWS)) {
                uint16_t tx = (uint16_t)(next_tile % (uint16_t)NEWTON_W);
                uint16_t ty = (uint16_t)(next_tile / (uint16_t)NEWTON_W);
                layer.shadow[next_tile] = newton_tile(tx, ty);
                if (tx == (uint16_t)(NEWTON_W - 1u)) {
                    layer.dirty_rows |= ((uint32_t)1u << ty);
                }
                next_tile++;
            }
        }
        display_frame(&d);
    }
}
