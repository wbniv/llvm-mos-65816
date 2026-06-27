// Bignum Factorial SNES demo — #20 of the compiler stress-test demo battery.
//
// Displays n! in full decimal as a growing number that fills the screen: rows 0-26 (27×32 =
// 864 chars) show the most-significant 864 decimal digits; row 27 is the HUD "N=NNNN [NNNN DIGITS]".
// Advances n by 1 per display update (waits for the previous DMA flush to complete first, which
// naturally throttles the animation at large n).
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
// See docs/plans/2026-06-27-20-snes-bignum-factorial-factorial.md.
//
// BG3 only (Mode 1 2bpp). Custom FactDisplay drawable manages the 32×28 tilemap shadow with
// per-row dirty tracking and capped DMA (≤ UPQ_MAX_JOBS rows / V-blank ≈ 1 024 bytes).
// Font (font8.h, 64 glyphs ASCII 0x20..0x5F) lives at tile 256 (chr word 2 048).

#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/drawable.h"
#include "snesgfx/upload.h"
#include "snesgfx/vram.h"
#include "font8.h"
#include "../65816/factorial.h"

// BG3 VRAM layout (matches the spigot.c convention)
#define FACT_CHR      0x0000u    // BG3 chr base word (tiles 0-255 unused; font at tile 256)
#define FACT_MAP      0x4000u    // BG3 tilemap base word (32×32 = 1 024 entries)
#define FONT_BASE     256u       // first font glyph tile# (FONT8_FIRST=0x20, FONT8_N=64)

// Screen geometry
#define FACT_DIGIT_ROWS  27u     // rows 0-26: 27 × 32 = 864 decimal char slots
#define FACT_HUD_ROW     27u     // row 27: status line
#define FACT_NROWS       28u     // total tilemap rows used

#define FACT_MAX_N    1000u      // animate n from 1 to this value

// BG3 2bpp palettes (4 entries × 2 bytes, uploaded to CGRAM during init):
//   palette 0 (CGRAM  0..3): digit area  — white on black
//   palette 1 (CGRAM  8..11): HUD row   — cyan on black
static const uint16_t pal_digits[4] = {
    SNES_RGB(0,  0,  0), SNES_RGB(31, 31, 31), SNES_RGB(0, 0, 0), SNES_RGB(0, 0, 0),
};
static const uint16_t pal_hud[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(0, 20, 24), SNES_RGB(0, 0, 0), SNES_RGB(0, 0, 0),
};

// ---------------------------------------------------------------------------
// FactDisplay drawable — full-screen 32×28 tilemap for decimal text.
// Modeled on PiHud (examples/snes/spigot.c:44-200). Owns BG3 entirely
// (tm_bits = TM_BG3; no BitmapCanvas precedes it on this layer).
// ---------------------------------------------------------------------------

typedef struct {
    Drawable base;
    uint16_t map_word;
    uint16_t shadow[FACT_NROWS * 32u];  // full tilemap shadow (FACT_NROWS × 32 = 896 words)
    uint32_t dirty_rows;                // bit i set → row i needs re-DMA
} FactDisplay;

static void _fact_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    FactDisplay *fd = (FactDisplay *)d;
    // Load font8.h glyphs at tile FONT_BASE = 256 → chr word 2 048 (force-blank; direct write OK).
    snes_vram_addr((uint16_t)(FONT_BASE * 8u));
    for (uint16_t i = 0u; i < (uint16_t)FONT8_N * 8u; i++) REG_VMDATA = FONT8[i];
    // BG3 chr base: BG34NBA low nibble = FACT_CHR >> 12 = 0.
    REG_BG34NBA = (uint8_t)((FACT_CHR >> 12) & 0x0Fu);
    // BG3 tilemap: 32×32 at FACT_MAP (size=0 → 32×32).
    REG_BG3SC = SNES_BGSC(fd->map_word, 0);
    // Pre-fill VRAM tilemap with FONT_BASE (blank tile) — force-blank; direct write safe.
    // This avoids garbage pixels before the first DMA flush completes.
    snes_vram_addr(fd->map_word);
    for (uint16_t i = 0u; i < 32u * 32u; i++) REG_VMDATA = (uint16_t)FONT_BASE;
    // Enable BG3; VRAM is already correct so no dirty rows needed yet.
    fd->base.tm_bits = TM_BG3;
    fd->dirty_rows   = 0u;
}

static void _fact_emit(Drawable *d, UploadQueue *q) {
    FactDisplay *fd = (FactDisplay *)d;
    for (uint8_t r = 0u; r < (uint8_t)FACT_NROWS && q->n < UPQ_MAX_JOBS; r++) {
        if (!(fd->dirty_rows & ((uint32_t)1u << r))) continue;
        upq_push_vram(q, (uint16_t)(fd->map_word + (uint16_t)r * 32u),
                      &fd->shadow[(uint16_t)r * 32u], 0x00u, 32u * 2u, VMAIN_INC_HIGH_1);
        fd->dirty_rows &= ~((uint32_t)1u << r);
    }
}

static const DrawableVT FACT_VT = { _fact_reserve, _fact_emit };

static void fact_display_init(FactDisplay *fd, uint16_t map_word) {
    fd->base.vt      = &FACT_VT;
    fd->base.tm_bits = 0u;
    fd->map_word     = map_word;
    for (uint16_t i = 0u; i < FACT_NROWS * 32u; i++) fd->shadow[i] = (uint16_t)FONT_BASE;
    fd->dirty_rows   = 0u;
}

// ---------------------------------------------------------------------------
// Tile encoding
// ---------------------------------------------------------------------------

// ASCII char → BG3 tilemap entry using palette 0 (white digits).
static inline uint16_t _tile(char c) {
    uint8_t ch = (uint8_t)c;
    return (ch >= (uint8_t)FONT8_FIRST && ch < (uint8_t)((uint16_t)FONT8_FIRST + FONT8_N))
        ? (uint16_t)(FONT_BASE + (uint8_t)(ch - (uint8_t)FONT8_FIRST))
        : (uint16_t)FONT_BASE;
}

// Same but palette 1 (cyan HUD): OR in palette bits 13-15 = 001 → 1 << 13.
static inline uint16_t _tile_hud(char c) {
    return (uint16_t)(_tile(c) | (uint16_t)(1u << 13));
}

// uint16_t → NUL-terminated decimal (buf ≥ 6 bytes). Returns buf.
static char *u16_to_str(char *buf, uint16_t v) {
    char tmp[5]; uint8_t n = 0u;
    if (!v) { buf[0] = '0'; buf[1] = 0; return buf; }
    while (v) { tmp[n++] = (char)('0' + (uint8_t)(v % 10u)); v = (uint16_t)(v / 10u); }
    for (uint8_t i = 0u; i < n; i++) buf[i] = tmp[n - 1u - i];
    buf[n] = 0;
    return buf;
}

// ---------------------------------------------------------------------------
// Display update: convert bignum → shadow tilemap rows.
// ---------------------------------------------------------------------------

__attribute__((noinline))
static void fact_display_update(FactDisplay *fd, const bignum_state *bn) {
    uint16_t *sh = fd->shadow;
    uint16_t  pos = 0u;
    const uint16_t limit = (uint16_t)(FACT_DIGIT_ROWS * 32u);

    // Digit rows 0-26: write bignum decimal most-significant first.
    if (bn->nelem > 0u) {
        // Most-significant element (1-4 chars, no leading zeros).
        char msd[4];
        uint16_t nmsd = bignum_write_msd(msd, bn->d[bn->nelem - 1u]);
        for (uint16_t i = 0u; i < nmsd && pos < limit; i++, pos++)
            sh[pos] = _tile(msd[i]);

        // Remaining elements (exactly 4 chars each, high to low).
        if (bn->nelem > 1u) {
            uint16_t ei = bn->nelem - 1u;
            while (ei > 0u && pos < limit) {
                ei--;
                char blk[4];
                bignum_write4(blk, bn->d[ei]);
                for (uint8_t j = 0u; j < 4u && pos < limit; j++, pos++)
                    sh[pos] = _tile(blk[j]);
            }
        }
    }
    // Pad remaining digit area with spaces.
    for (; pos < limit; pos++) sh[pos] = (uint16_t)FONT_BASE;

    // HUD row 27: "N=NNNN   [NNNN DIGITS]"
    uint16_t *hud = &sh[(uint16_t)FACT_HUD_ROW * 32u];
    for (uint8_t c = 0u; c < 32u; c++) hud[c] = _tile_hud(' ');
    char nbuf[6], dbuf[6];
    u16_to_str(nbuf, bn->n);
    u16_to_str(dbuf, bignum_ndigits(bn));
    uint8_t hp = 0u;
    hud[hp++] = _tile_hud('N'); hud[hp++] = _tile_hud('=');
    for (uint8_t i = 0u; nbuf[i] && hp < 32u; i++) hud[hp++] = _tile_hud(nbuf[i]);
    hud[hp++] = _tile_hud(' '); hud[hp++] = _tile_hud(' '); hud[hp++] = _tile_hud(' ');
    hud[hp++] = _tile_hud('[');
    for (uint8_t i = 0u; dbuf[i] && hp < 32u; i++) hud[hp++] = _tile_hud(dbuf[i]);
    static const char kDIGITS[] = " DIGITS]";
    for (uint8_t i = 0u; kDIGITS[i] && hp < 32u; i++) hud[hp++] = _tile_hud(kDIGITS[i]);

    // Mark all rows dirty.
    fd->dirty_rows = ((uint32_t)1u << FACT_NROWS) - 1u;
}

// ---------------------------------------------------------------------------
// Main application
// ---------------------------------------------------------------------------

typedef struct {
    Display     screen;
    FactDisplay disp;
    bignum_state bn;
} App;

volatile uint16_t corpus_result;    // proof channel — read from WRAM by the differential gate

static void app_init(App *a) {
    display_init(&a->screen);
    fact_display_init(&a->disp, FACT_MAP);
    display_add(&a->screen, (Drawable *)&a->disp);

    upq_push_cgram(&a->screen.q, 0u, pal_digits, 0x00u, (uint8_t)sizeof pal_digits);
    upq_push_cgram(&a->screen.q, 8u, pal_hud,    0x00u, (uint8_t)sizeof pal_hud);

    bignum_init(&a->bn);
    fact_display_update(&a->disp, &a->bn);
}

int main(void) {
    static App a;
    app_init(&a);

    // Gate CRC uses its own static bignum_state; does not affect a.bn.
    corpus_result = factorial_gate_crc();

    // delay: count-down between advances. Starts at 2 to let the initial
    // CGRAM+rows 0-13 DMA settle; thereafter 1 drain frame lets rows 16-27
    // finish before the next advance. Using a counter (not dirty_rows == 0)
    // avoids a 32-bit zero-compare that can misfire on bits 16-27 under
    // +mos-a16 codegen on the 65816, which would permanently stall n at 1.
    uint8_t delay = 2u;
    for (;;) {
        if (a.bn.n < (uint16_t)FACT_MAX_N) {
            if (delay == 0u) {
                bignum_mul_n(&a.bn, (uint16_t)(a.bn.n + 1u));
                fact_display_update(&a.disp, &a.bn);
                delay = 1u;
            } else {
                delay--;
            }
        }
        display_frame(&a.screen);
    }
}
