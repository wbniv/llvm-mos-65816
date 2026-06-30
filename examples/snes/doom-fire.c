/* examples/snes/doom-fire.c — Doom-fire / heat-field SNES demo (#7).
 * Compiler stress-test: a full-grid 8-bit array sweep + per-cell xorshift16 PRNG in the
 * fire_step hot loop (examples/65816/doom-fire.h) — deliberately multiply-/divide-free, so the
 * stress is indexed array traffic + native-16 PRNG (eor/asl/lsr under rep/sep), not ALU libcalls.
 * Visual: a 32×28 heat grid (one BG1 4bpp solid-colour tile per cell) mapped through a 16-colour
 * black→red→orange→yellow→white palette; the bottom row is a constant max-heat source and flames
 * rise + flicker upward.
 *
 * Memory layout (low WRAM, bank 0):
 *   fire[FIRE_W*FIRE_H]            896 B   (single heat buffer; fire_step rewrites in place)
 *   FireLayer.shadow[14*FIRE_W]   896 B   (half-tilemap DMA buffer)
 * No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
 *
 * corpus_result = doomfire_gate_crc() (16×16 grid, 30 steps), set once at startup.
 * See docs/plans/2026-06-28-7-snes-doom-fire.md                                                 */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "../65816/doom-fire.h"

/* ---- VRAM layout (fixed, not bump-allocated) ---------------------------------- */
/* BG1 chr:  16 solid-colour 4bpp tiles × 16 words/tile = 256 words = 0x100 words  */
/* BG1 map:  32×32 tilemap = 1024 words at word 0x4000                              */
#define FIRE_CHR  0x0000u
#define FIRE_MAP  0x4000u

/* ---- Palette: classic fire ramp, heat 0 (black) → 15 (white-hot) -------------- */
static const uint16_t fire_pal[16] = {
    SNES_RGB( 0,  0,  0), SNES_RGB( 7,  0,  0), SNES_RGB(13,  0,  0), SNES_RGB(19,  1,  0),
    SNES_RGB(25,  2,  0), SNES_RGB(31,  5,  0), SNES_RGB(31,  9,  0), SNES_RGB(31, 13,  0),
    SNES_RGB(31, 17,  0), SNES_RGB(31, 21,  1), SNES_RGB(31, 25,  3), SNES_RGB(31, 29,  6),
    SNES_RGB(31, 31, 11), SNES_RGB(31, 31, 18), SNES_RGB(31, 31, 26), SNES_RGB(31, 31, 31),
};

/* ---- Simulation state (single buffer: fire_step rewrites in place each frame) -- */
static uint8_t fire[FIRE_W * FIRE_H];

/* deterministic xorshift seed advanced by fire_step each frame */
static uint16_t fire_seed = 0xF1A3u;

/* ---- FireLayer drawable (BG1 4bpp, FULL-tilemap DMA per frame) ------------------
 * The grid is re-uploaded whole every frame (28×32×2 = 1792 B) so the entire screen
 * advances at 60 Hz from one consistent fire_step. (A half-tilemap split — upload 14
 * rows/frame while fire_step advances the whole grid each frame — refreshes each half at
 * only 30 Hz and from a DIFFERENT sim step than the other half: that reads as a sluggish,
 * shimmering image. 1792 B fits the NTSC v-blank with wide margin, so upload it all.) */
typedef struct {
    Drawable base;
    uint16_t shadow[FIRE_H * FIRE_W];     /* full-tilemap shadow (28*32 = 896 words) */
} FireLayer;

static void _fire_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    FireLayer *l = (FireLayer *)d;
    (void)l;

    /* BG1 registers — BG12NBA is WRITE-ONLY; we own both nibbles (BG2 unused by the demo). */
    REG_BG1SC   = SNES_BGSC(FIRE_MAP, 0);
    REG_BG12NBA = (uint8_t)((FIRE_CHR >> 12) & 0x0Fu);

    /* Build 16 solid-colour 4bpp tiles directly in VRAM (safe: force-blank is active).
     * Each 4bpp tile = 16 words: 8 rows of (bp1|bp0 word) then 8 rows of (bp3|bp2 word).
     * For palette index c: a bitplane row is 0xFF if the corresponding bit of c is set. */
    snes_vram_addr(FIRE_CHR);
    for (uint8_t c = 0; c < 16; c++) {
        uint16_t bp01 = (uint16_t)((c & 2 ? 0xFF00u : 0u) | (c & 1 ? 0x00FFu : 0u));
        uint16_t bp23 = (uint16_t)((c & 8 ? 0xFF00u : 0u) | (c & 4 ? 0x00FFu : 0u));
        for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp01;
        for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp23;
    }

    /* Clear the whole 32×32 tilemap to tile 0 (black). The grid fills rows 0..27; the unused
       rows 28..31 must not show power-on garbage. */
    snes_vram_addr(FIRE_MAP);
    for (uint16_t i = 0; i < (uint16_t)(32u * 32u); i++) REG_VMDATA = 0u;

    l->base.tm_bits = TM_BG1;
}

static void _fire_emit(Drawable *d, UploadQueue *q) {
    FireLayer *l = (FireLayer *)d;

    /* palette upload: 16 colours × 2 bytes from colour index 0 (32 B) */
    upq_push_cgram(q, 0u, fire_pal, 0x00u, (uint16_t)sizeof fire_pal);

    /* rebuild the FULL-grid shadow (tile index == heat value, clamped to the 16-colour ramp) */
    for (uint16_t n = 0; n < (uint16_t)(FIRE_H * FIRE_W); n++) {
        uint16_t t = (uint16_t)fire[n];
        l->shadow[n] = t > 15u ? 15u : t;
    }

    /* DMA the whole tilemap in one job: 28 rows × 32 × 2 = 1792 bytes (fits one v-blank) */
    upq_push_vram(q,
        FIRE_MAP,
        l->shadow,
        0x00u,
        (uint16_t)(FIRE_H * FIRE_W * 2u),
        VMAIN_INC_HIGH_1);
}

static const DrawableVT FIRE_VT = { _fire_reserve, _fire_emit };

/* ---- Simulation init ---------------------------------------------------------- */
static void fire_init(void) {
    for (uint16_t i = 0; i < (uint16_t)(FIRE_W * FIRE_H); i++) fire[i] = 0;
    /* bottom row = constant max-heat source */
    for (uint8_t x = 0; x < FIRE_W; x++)
        fire[(FIRE_H - 1) * FIRE_W + x] = FIRE_MAX;
    fire_seed = 0xF1A3u;
}

/* ---- corpus result ------------------------------------------------------------ */
volatile uint16_t corpus_result;

int main(void) {
    fire_init();

    /* gate hash (16×16 grid, 30 steps) — written once so the corpus harness can read it at
     * WRAM[corpus_result] any time after the first frame. */
    static doomfire_gate_state gstate;
    corpus_result = doomfire_gate_crc(&gstate);

    static FireLayer fl;
    fl.base.vt = &FIRE_VT;

    Display d;
    display_init(&d);
    display_add(&d, (Drawable *)&fl);

    /* Title overlay (BG2), added after the demo layer; held ~1 s then torn down. The fire is
       continuous, so the ~60-frame offset does not affect the (separately-asserted) corpus hash. */
    static TitleLayer title;
    title_begin16(&d, &title, "DOOM FIRE", "HEAT FIELD");
    title_end(&d, &title, 110);

    for (;;) {
        /* one propagation sweep over the full grid (during active display) */
        fire_step(fire, FIRE_W, FIRE_H, &fire_seed);
        display_frame(&d);
    }
}
