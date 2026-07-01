/* examples/snes/hdr-bloom.c — HDR additive-bloom SNES demo (#44).
 * Compiler stress-test: SATURATING / overflow-checked add (__builtin_add_overflow) — many
 * overlapping glows summed per cell, each add clamping to 255 instead of wrapping, so where
 * lights pile up the field blows out to white (examples/65816/hdr_bloom.h). The corner is the
 * carry/overflow-flag test + branch (adc; bcs), a flag-sequence no other battery demo runs.
 * Visual: a 32×28 field (one BG1 4bpp solid-colour tile per cell) mapped through a 16-colour
 * black→blue→magenta→orange→white bloom ramp; six drifting lights bloom and blow out where they
 * cross.
 *
 * No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
 * corpus_result = hdr_bloom_gate_crc() (24 steps), set once at startup.
 * See docs/plans/2026-06-30-44-snes-hdr-bloom.md                                                */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "../65816/hdr_bloom.h"

/* ---- VRAM layout (fixed, not bump-allocated) ---------------------------------- */
#define BLOOM_CHR  0x0000u   /* 16 solid-colour 4bpp tiles × 16 words = 256 words   */
#define BLOOM_MAP  0x4000u   /* 32×32 tilemap at word 0x4000                         */

/* ---- Palette: HDR bloom ramp, intensity 0 (black) → 15 (white blowout) --------- */
static const uint16_t bloom_pal[16] = {
    SNES_RGB( 0,  0,  0), SNES_RGB( 2,  0,  6), SNES_RGB( 5,  0, 12), SNES_RGB( 9,  0, 18),
    SNES_RGB(14,  0, 22), SNES_RGB(19,  1, 24), SNES_RGB(24,  2, 22), SNES_RGB(28,  4, 16),
    SNES_RGB(31,  7, 10), SNES_RGB(31, 12,  6), SNES_RGB(31, 17,  3), SNES_RGB(31, 22,  2),
    SNES_RGB(31, 26,  6), SNES_RGB(31, 29, 14), SNES_RGB(31, 31, 23), SNES_RGB(31, 31, 31),
};

/* ---- Simulation state --------------------------------------------------------- */
static bloom_state bs;

/* ---- BloomLayer drawable (BG1 4bpp, FULL-tilemap DMA per frame) ---------------- */
typedef struct {
    Drawable base;
    uint16_t shadow[BLOOM_H * BLOOM_W];   /* full-tilemap shadow (28*32 = 896 words) */
} BloomLayer;

static void _bloom_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    BloomLayer *l = (BloomLayer *)d;
    (void)l;

    REG_BG1SC   = SNES_BGSC(BLOOM_MAP, 0);
    REG_BG12NBA = (uint8_t)((BLOOM_CHR >> 12) & 0x0Fu);

    /* Build 16 solid-colour 4bpp tiles directly in VRAM (force-blank is active). */
    snes_vram_addr(BLOOM_CHR);
    for (uint8_t c = 0; c < 16; c++) {
        uint16_t bp01 = (uint16_t)((c & 2 ? 0xFF00u : 0u) | (c & 1 ? 0x00FFu : 0u));
        uint16_t bp23 = (uint16_t)((c & 8 ? 0xFF00u : 0u) | (c & 4 ? 0x00FFu : 0u));
        for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp01;
        for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp23;
    }

    /* Clear the whole 32×32 tilemap to tile 0 (black) so unused rows 28..31 are blank. */
    snes_vram_addr(BLOOM_MAP);
    for (uint16_t i = 0; i < (uint16_t)(32u * 32u); i++) REG_VMDATA = 0u;

    l->base.tm_bits = TM_BG1;
}

static void _bloom_emit(Drawable *d, UploadQueue *q) {
    BloomLayer *l = (BloomLayer *)d;

    upq_push_cgram(q, 0u, bloom_pal, 0x00u, (uint16_t)sizeof bloom_pal);

    /* tile index = intensity bucket (>> 4 → 0..15); 255 → 15 = white blowout */
    for (uint16_t n = 0; n < (uint16_t)(BLOOM_H * BLOOM_W); n++)
        l->shadow[n] = (uint16_t)(bs.field[n] >> 4);

    upq_push_vram(q, BLOOM_MAP, l->shadow, 0x00u,
                  (uint16_t)(BLOOM_H * BLOOM_W * 2u), VMAIN_INC_HIGH_1);
}

static const DrawableVT BLOOM_VT = { _bloom_reserve, _bloom_emit };

/* ---- corpus result ------------------------------------------------------------ */
volatile uint16_t corpus_result;

int main(void) {
    static BloomLayer bl;
    bl.base.vt = &BLOOM_VT;

    Display d;
    display_init(&d);
    display_add(&d, (Drawable *)&bl);   /* bs is zero-init → black under the title */

    /* Title overlay held while the gate CRC computes (the gate is compute-heavy; hiding it behind
       the title keeps the startup from being a long black screen and lands corpus_result early). */
    static TitleLayer title;
    title_begin16(&d, &title, "HDR BLOOM", "SATURATING ADD");
    corpus_result = hdr_bloom_gate_crc();   /* gate uses its own static state */
    bloom_init(&bs);                        /* arm the live simulation */
    title_end(&d, &title, 90);

    for (;;) {
        bloom_step(&bs);
        display_frame(&d);
    }
}
