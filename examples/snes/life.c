/* examples/snes/life.c — Conway's Game of Life SNES demo (#5 of the compiler stress-test battery).
 *
 * A bit-packed 128×112 grid evolves by B3/S23: each cell's 8 live neighbours are summed bit-parallel
 * (examples/65816/life.h, life_step) — a SWAR full-adder ripple of and/eor/ora on packed bytes, plus
 * constant-1 asl/lsr for the cross-byte neighbour shifts. Deliberately multiply-/divide-free: the
 * stress is boolean logic + indexed row/byte loads + the two-buffer ping-pong swap.
 *
 * Visual: a centred 16×14-tile window on BG3 2bpp (1 cell = 1 green pixel). A Gosper glider gun sits
 * top-left and fires gliders down-right into a deterministic random soup (xorshift16) that settles
 * into still-lifes and oscillators.
 *
 * Memory (low WRAM, bank 0):
 *   LifeGrid.buf_a / buf_b   1792 B each  (ping-pong packed grids; life_step src→dst, then swap)
 *   LifeGrid.stage            896 B       (one DMA slice = 56 tiles × 16 B)
 *   life_gate_crc ga/gb       768 B       (the separate gate grid; corpus_result hash)
 * No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
 *
 * corpus_result = life_gate_crc() (64×48 grid, 32 gens), set once at startup.
 * See docs/plans/2026-06-28-5-snes-life.md                                                        */
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "../65816/life.h"

/* ---- grid + display geometry --------------------------------------------------- */
#define LIFE_W       128u                 /* cells wide              */
#define LIFE_H       112u                 /* cells tall              */
#define LIFE_WB       16u                 /* bytes/row (LIFE_W / 8)  */
#define LIFE_BYTES   (LIFE_WB * LIFE_H)   /* 1792                    */
#define LIFE_TW       16u                 /* window width  in tiles  */
#define LIFE_TH       14u                 /* window height in tiles  */
#define LIFE_NTILES  (LIFE_TW * LIFE_TH)  /* 224                     */
#define LIFE_FLUSH    56u                 /* tiles streamed per frame → 224/56 = 4 frames/gen */

/* ---- VRAM layout (fixed, not bump-allocated) ----------------------------------- */
#define LIFE_CHR   0x0000u   /* BG3 chr base (word): 224 grid tiles + 1 blank tile */
#define LIFE_MAP   0x4000u   /* BG3 tilemap base (word): 32×32 static identity map */
#define LIFE_BOX_COL  8u     /* centred 16×14 box: cols 8..23                       */
#define LIFE_BOX_ROW  7u     /* rows 7..20                                          */

/* BG3 2bpp palette: colour 0 = black (dead/background), colour 3 = green (live cell). */
#define LIFE_DEAD  SNES_RGB( 0,  0,  0)
#define LIFE_LIVE  SNES_RGB( 4, 31,  6)

/* ---- LifeGrid drawable --------------------------------------------------------- */
/* Owns the ping-pong grids and streams the whole displayed grid to chr at LIFE_FLUSH tiles/frame.
 * cursor == LIFE_NTILES means "stream complete / idle" — the main loop computes the next generation
 * only then, so the displayed buffer is stable across the 4-frame stream (no tearing). */
typedef struct {
    Drawable base;
    uint8_t  buf_a[LIFE_BYTES];
    uint8_t  buf_b[LIFE_BYTES];
    uint8_t  use_a;                       /* 1: displayed/src = buf_a, dst = buf_b */
    uint16_t cursor;                      /* next tile to stream; == LIFE_NTILES → idle */
    uint8_t  stage[LIFE_FLUSH * 16u];     /* DMA staging for one slice (896 B) */
} LifeGrid;

static void _life_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    LifeGrid *l = (LifeGrid *)d;

    /* BG3 registers — BG34NBA is WRITE-ONLY; BG3 char base in the low nibble (BG4 unused). */
    REG_BG3SC   = SNES_BGSC(LIFE_MAP, 0);
    REG_BG34NBA = (uint8_t)((LIFE_CHR >> 12) & 0x0Fu);

    /* Palette (force-blank: direct CGRAM write is safe). 0 = black, 3 = green; 1,2 unused. */
    REG_CGADD  = 0u;
    REG_CGDATA = (uint8_t)LIFE_DEAD;        REG_CGDATA = (uint8_t)(LIFE_DEAD >> 8);  /* colour 0 */
    REG_CGDATA = (uint8_t)LIFE_DEAD;        REG_CGDATA = (uint8_t)(LIFE_DEAD >> 8);  /* colour 1 */
    REG_CGDATA = (uint8_t)LIFE_DEAD;        REG_CGDATA = (uint8_t)(LIFE_DEAD >> 8);  /* colour 2 */
    REG_CGDATA = (uint8_t)LIFE_LIVE;        REG_CGDATA = (uint8_t)(LIFE_LIVE >> 8);  /* colour 3 */

    /* Zero the chr region: 224 grid tiles + 1 blank tile, 8 words/tile (matches the .bss grids). */
    snes_vram_addr(LIFE_CHR);
    for (uint16_t w = 0; w < (uint16_t)((LIFE_NTILES + 1u) * 8u); w++) REG_VMDATA = 0u;

    /* Static identity tilemap: the 16×14 box shows grid tiles row-major (chr tile = iny*16 + inx);
       everything else points at the zeroed blank tile (index LIFE_NTILES). */
    uint16_t blank = (uint16_t)LIFE_NTILES;
    snes_vram_addr(LIFE_MAP);
    for (uint8_t sy = 0; sy < 32u; sy++)
        for (uint8_t sx = 0; sx < 32u; sx++) {
            uint8_t inx = (uint8_t)(sx - LIFE_BOX_COL), iny = (uint8_t)(sy - LIFE_BOX_ROW);
            uint16_t tile = (inx < LIFE_TW && iny < LIFE_TH)
                              ? (uint16_t)((uint16_t)iny * LIFE_TW + inx) : blank;
            REG_VMDATA = tile;
        }

    l->base.tm_bits = TM_BG3;
}

static void _life_emit(Drawable *d, UploadQueue *q) {
    LifeGrid *l = (LifeGrid *)d;
    if (l->cursor >= (uint16_t)LIFE_NTILES) return;   /* idle: stream complete */

    const uint8_t *g = l->use_a ? l->buf_a : l->buf_b;
    uint16_t start = l->cursor;
    uint16_t n = (uint16_t)(LIFE_NTILES - start);
    if (n > LIFE_FLUSH) n = LIFE_FLUSH;

    /* Build the DMA slice: a packed grid byte IS a 2bpp bitplane byte, so each pixel-row byte is
       written into BOTH planes → colour 3 where the bit is set. tile (tc,tr): tc = tile&15,
       tr = tile>>4 (LIFE_TW = 16, so no divide). */
    for (uint16_t t = 0; t < n; t++) {
        uint16_t tile = (uint16_t)(start + t);
        uint8_t  tc = (uint8_t)(tile & 15u);
        uint16_t toprow = (uint16_t)((uint16_t)(tile >> 4u) * 8u);   /* top pixel row of this tile */
        uint8_t *dstp = &l->stage[(uint16_t)t * 16u];
        for (uint8_t pr = 0; pr < 8u; pr++) {
            uint8_t gb = g[(uint16_t)(toprow + pr) * LIFE_WB + tc];
            dstp[(uint16_t)pr * 2u]      = gb;   /* bitplane 0 */
            dstp[(uint16_t)pr * 2u + 1u] = gb;   /* bitplane 1 */
        }
    }
    upq_push_vram(q, (uint16_t)(LIFE_CHR + start * 8u), l->stage, 0x00u,
                  (uint16_t)(n * 16u), VMAIN_INC_HIGH_1);
    l->cursor = (uint16_t)(start + n);
}

static const DrawableVT LIFE_VT = { _life_reserve, _life_emit };

/* ---- seed: Gosper gun + display-only random soup ------------------------------- */
static void life_grid_seed(LifeGrid *l) {
    uint16_t i;
    for (i = 0; i < (uint16_t)LIFE_BYTES; i++) { l->buf_a[i] = 0u; l->buf_b[i] = 0u; }

    /* Gosper glider gun, top-left, clear of the soup so its gliders form cleanly. */
    life_seed_gun(l->buf_a, LIFE_WB, 4u, 4u);

    /* Random soup (~25%) in the bottom rows — the gun's gliders stream down-right into it.
       Display-only: corpus_result hashes the separate gate grid, never this. */
    uint16_t seed = 0x1234u;
    for (uint8_t y = 48u; y < (uint8_t)LIFE_H; y++)
        for (uint8_t x = 0; x < (uint8_t)LIFE_W; x++)
            if ((life_rng16(&seed) & 3u) == 0u) life_set(l->buf_a, LIFE_WB, x, y);

    l->use_a  = 1u;     /* displayed = buf_a (the seed) */
    l->cursor = 0u;     /* stream the seed first; gen 1 computes once it is fully shown */
}

/* ---- corpus result ------------------------------------------------------------- */
volatile uint16_t corpus_result;

int main(void) {
    static LifeGrid life;
    life.base.vt = &LIFE_VT;
    life_grid_seed(&life);

    /* gate hash (64×48 grid, 32 gens) — written once so the corpus harness can read it at
       WRAM[corpus_result] any time after the first frame. */
    corpus_result = life_gate_crc();

    Display d;
    display_init(&d);
    display_add(&d, (Drawable *)&life);

    /* Title overlay (BG2), added after the demo layer; held ~2 s then torn down. The gun/soup
       continue underneath; the corpus hash is the separate pre-loop gate value, so unaffected. */
    static TitleLayer title;
    title_begin16(&d, &title, "CONWAY LIFE", "GLIDER GUN");
    title_end(&d, &title, 110);

    for (;;) {
        /* When the displayed grid has fully streamed, advance one generation and ping-pong. */
        if (life.cursor >= (uint16_t)LIFE_NTILES) {
            const uint8_t *s = life.use_a ? life.buf_a : life.buf_b;
            uint8_t       *t = life.use_a ? life.buf_b : life.buf_a;
            life_step(s, t, LIFE_WB, LIFE_H);
            life.use_a ^= 1u;      /* displayed = the new generation */
            life.cursor = 0u;      /* restart the 4-frame stream */
        }
        display_frame(&d);
    }
}
