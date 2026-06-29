/* examples/snes/rdiff.c — Gray-Scott reaction-diffusion SNES demo (#8).
 * Compiler stress-test: heavy fixed-point mul-add in the GS hot loop, stressing
 * __mulsi3 (≥2 calls per cell per step, 32×28 grid, 2 steps/frame).
 * Visual: V-concentration mapped through a 16-colour navy→white palette on BG1 4bpp;
 * Turing spots self-organise from five seeded 2×2 perturbations over ~300 frames.
 *
 * Memory layout (low WRAM, bank 0) — 16-bit fixed-point, 32×24 grid (24 rows keep it in budget):
 *   gs_u[2][GS_H*GS_W]   2 × 768 uint16_t = 3072 B  (ping-pong U buffers)
 *   gs_v[2][GS_H*GS_W]   2 × 768 uint16_t = 3072 B  (ping-pong V buffers)
 *   gstate                4 × 64  uint16_t =  512 B  (gate scratch)
 *   shadow[GS_H/2*GS_W]     12×32 uint16_t =  768 B  (half-tilemap DMA buffer)
 *   Total ≈ 7424 B — just under the 7680 B ram region.
 *
 * corpus_result = rdiff_gate_crc() on an 8×8 sub-grid (50 steps), set once at startup.
 * See docs/plans/2026-06-27-8-snes-rdiff-gray-scott.md                               */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "../65816/rdiff.h"

/* ---- VRAM layout (fixed, not bump-allocated) ---------------------------------- */
/* BG1 chr:  16 solid-colour 4bpp tiles × 16 words/tile = 256 words = 0x100 words  */
/* BG1 map:  32×32 tilemap = 1024 words at word 0x4000                              */
#define RDIFF_CHR  0x0000u
#define RDIFF_MAP  0x4000u

/* ---- Palette: deep navy (V=0, background) → white (V=255, spots) -------------- */
static const uint16_t rdiff_pal[16] = {
    SNES_RGB( 0,  0,  4), SNES_RGB( 0,  2,  8), SNES_RGB( 0,  4, 12),
    SNES_RGB( 0,  8, 16), SNES_RGB( 0, 12, 20), SNES_RGB( 0, 16, 22),
    SNES_RGB( 2, 20, 24), SNES_RGB( 6, 22, 26), SNES_RGB(10, 24, 28),
    SNES_RGB(14, 26, 30), SNES_RGB(18, 28, 30), SNES_RGB(22, 30, 30),
    SNES_RGB(26, 30, 28), SNES_RGB(30, 30, 24), SNES_RGB(30, 28, 16),
    SNES_RGB(31, 31, 31),
};

/* ---- Simulation state (global: 4 × 896 uint8_t = 3584 bytes total) ----------- */
/* Double-buffered so the display drawable can read the completed buffer safely.    */
static uint16_t gs_u[2][GS_H * GS_W];   /* 16-bit fixed-point (scale GS_S) */
static uint16_t gs_v[2][GS_H * GS_W];
static uint8_t  gs_buf = 0;   /* index of the current (just-written) buffer */

/* pointer the drawable reads each frame; set by main after each step batch */
static uint16_t *g_cur_v;

/* ---- RdiffLayer drawable ------------------------------------------------------ */
typedef struct {
    Drawable base;
    uint8_t  half;                       /* 0 = upload rows 0-13, 1 = rows 14-27  */
    uint16_t shadow[(GS_H / 2) * GS_W]; /* half-tilemap shadow (896 B)            */
} RdiffLayer;

static void _rdiff_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    RdiffLayer *l = (RdiffLayer *)d;
    l->half = 0;

    /* BG1 registers — BG12NBA is WRITE-ONLY; we own both nibbles (BG2 unused here). */
    REG_BG1SC   = SNES_BGSC(RDIFF_MAP, 0);
    REG_BG12NBA = (uint8_t)((RDIFF_CHR >> 12) & 0x0Fu);

    /* Build 16 solid-colour 4bpp tiles directly in VRAM (safe: force-blank is active).
     * Each 4bpp tile = 16 words: 8 rows of (bp1|bp0 word) then 8 rows of (bp3|bp2 word).
     * For palette index c: each bitplane row is 0xFF if the corresponding bit of c is set. */
    snes_vram_addr(RDIFF_CHR);
    for (uint8_t c = 0; c < 16; c++) {
        uint16_t bp01 = (uint16_t)((c & 2 ? 0xFF00u : 0u) | (c & 1 ? 0x00FFu : 0u));
        uint16_t bp23 = (uint16_t)((c & 8 ? 0xFF00u : 0u) | (c & 4 ? 0x00FFu : 0u));
        for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp01;
        for (uint8_t r = 0; r < 8; r++) REG_VMDATA = bp23;
    }

    /* Clear the whole 32×32 tilemap to tile 0 (navy): the grid only fills rows
       GS_ROW0..GS_ROW0+GS_H-1, so the border rows must not show power-on garbage. */
    snes_vram_addr(RDIFF_MAP);
    for (uint16_t i = 0; i < (uint16_t)(32u * 32u); i++) REG_VMDATA = 0u;

    l->base.tm_bits = TM_BG1;
}

static void _rdiff_emit(Drawable *d, UploadQueue *q) {
    RdiffLayer *l = (RdiffLayer *)d;

    /* palette upload: 16 colours × 2 bytes starting at colour index 0 */
    upq_push_cgram(q, 0u, rdiff_pal, 0x00u, (uint16_t)sizeof rdiff_pal);

    /* rebuild the half-shadow for the rows we're about to DMA this frame */
    uint8_t start = l->half ? (uint8_t)(GS_H / 2) : 0u;
    uint8_t end   = l->half ? (uint8_t)GS_H        : (uint8_t)(GS_H / 2);
    uint16_t *src = g_cur_v + (uint16_t)start * GS_W;
    for (uint16_t n = 0; n < (uint16_t)((GS_H / 2) * GS_W); n++) {
        /* V ∈ [0,GS_S] → tile index [0,15] (GS_S>>8 = 16, clamp to 15) */
        uint16_t t = (uint16_t)(src[n] >> 8);
        l->shadow[n] = t > 15u ? 15u : t;
    }

    /* DMA half the tilemap to VRAM (centred via GS_ROW0): 12 rows × 32 × 2 = 768 bytes */
    upq_push_vram(q,
        (uint16_t)(RDIFF_MAP + (uint16_t)(start + GS_ROW0) * 32u),
        l->shadow,
        0x00u,
        (uint16_t)((GS_H / 2u) * GS_W * 2u),
        VMAIN_INC_HIGH_1);

    l->half ^= 1u;
}

static const DrawableVT RDIFF_VT = { _rdiff_reserve, _rdiff_emit };

/* ---- Simulation init ---------------------------------------------------------- */
/* 16-bit xorshift PRNG (deterministic seed) — scatters the seed spots that break the
   symmetry. A single symmetric seed only grows a symmetric ring; scattered noise lets the
   Turing instability fragment into the spot pattern. */
static uint16_t gs_rng = 0xACE1u;
static uint16_t gs_xs(void) {
    uint16_t x = gs_rng;
    x ^= (uint16_t)(x << 7);
    x ^= (uint16_t)(x >> 9);
    x ^= (uint16_t)(x << 8);
    return gs_rng = x;
}

static void gs_init(void) {
    /* Full-grid random noise: each cell is, with ~50% probability, perturbed to U=S/2, V=S/4
       (else the trivial U=S, V=0 rest state). Seeding the whole field — rather than a few spots —
       gives immediate on-screen texture that organises into the Turing spot pattern within a couple
       hundred steps (important: the 16-bit step is heavy, so the SNES advances slowly; a sparse seed
       would spend the first many seconds nearly blank). Deterministic xorshift → reproducible. */
    gs_rng = 0xACE1u;
    for (uint16_t i = 0; i < (uint16_t)(GS_H * GS_W); i++) {
        if (gs_xs() & 1u) { gs_u[0][i] = GS_S / 2; gs_v[0][i] = GS_S / 4; }
        else              { gs_u[0][i] = GS_S;     gs_v[0][i] = 0;       }
    }
}

/* ---- corpus result ------------------------------------------------------------ */
volatile uint16_t corpus_result;

int main(void) {
    /* gate hash on 8×8 sub-grid, 50 steps — written once so the corpus harness can
     * read it at WRAM[corpus_result] any time after the first frame (independent of the
     * displayed field, which lives in gs_u/gs_v). */
    static rdiff_gate_state gstate;
    corpus_result = rdiff_gate_crc(&gstate);

    /* g_cur_v points at the (still all-zero BSS) field for the title-hold frames. Every cell
       therefore maps to tile 0 = 4bpp colour 0 = TRANSPARENT, so the BG2 title shows cleanly.
       We seed the field only AFTER the title is hidden: in Mode 1 BG1 has higher priority than
       BG2, so seeding the whole grid first (opaque cells) would bury the title text — the bug
       this ordering fixes. See title_layer.h's priority caveat. */
    gs_buf  = 0;
    g_cur_v = gs_v[0];

    static RdiffLayer rdiff;
    rdiff.base.vt = &RDIFF_VT;

    Display d;
    display_init(&d);
    display_add(&d, (Drawable *)&rdiff);

    /* Title overlay (BG2), added after the demo layer. rdiff's gate hash is computed before the
       display exists (above), so there is no long compute to hide behind — hold the title a fixed
       ~1 s, then tear it down. The reaction-diffusion is continuous, so the ~60-frame offset does
       not affect the (separately-asserted) corpus hash; re-confirm the screenshot if it ever gates
       on a framebuffer CRC. */
    static TitleLayer title;
    title_init(&title, "REACTION DIFFUSION", "GRAY-SCOTT");
    display_add(&d, (Drawable *)&title);
    display_hold(&d, 110);
    display_hide_layer(&d, (Drawable *)&title);

    /* Title gone — now seed the field. From here BG1 fills with opaque Turing texture. */
    gs_init();
    gs_buf  = 0;
    g_cur_v = gs_v[0];

    for (;;) {
        /* GS simulation steps (during active display — compute budget ≈ 44% of frame) */
        for (uint8_t s = 0; s < GS_STEPS_PER_FRAME; s++) {
            gs_step(gs_u[gs_buf], gs_v[gs_buf],
                    gs_u[gs_buf ^ 1u], gs_v[gs_buf ^ 1u],
                    GS_W, GS_H);
            gs_buf ^= 1u;
        }
        /* expose the freshly written buffer to the drawable */
        g_cur_v = gs_v[gs_buf];

        display_frame(&d);
    }
}
