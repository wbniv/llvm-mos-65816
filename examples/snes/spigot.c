// π Spigot + Monte-Carlo SNES demo — #19 of the compiler stress-test demo battery.
//
// Renders two live computations side-by-side on the SNES:
//   LEFT (cols 0-15): π digits ticking out via the Rabinowitz-Wagon spigot algorithm —
//     a multi-precision carry sweep across a 76-element uint16 array with uint32 intermediates.
//     Stress: __udivsi3/__umodsi3 × PI_ELEMS per digit + carry chains.
//   RIGHT (cols 16-31, rows 0-15): dart scatter canvas (128×128) — Monte-Carlo estimate of π.
//     Stress: 16×16→32 multiply per throw under +mos-a16.
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
// See docs/plans/2026-06-27-19-snes-pi-spigot-montecarlo.md.
//
// PI_DIGITS=20 (PI_ELEMS=76) keeps the gate+display fast enough for the bsnes-jg WASM runner
// on mobile; corpus/pi_sim.c uses the default PI_DIGITS=200 (676 cells) for the full stress test.
//
// SWEEP_PER_CALL=3, MC_PER_CALL=6: fits the main loop body inside 1 SNES frame (44 667 cycles)
// so display_frame() catches the very next vblank → smooth animation at WASM emulation speed.
// (25 iters × ~7 000 cyc/iter + 32 × ~3 500 cyc/throw ≈ 7× the frame budget → frozen display.)
#define PI_DIGITS      20
#define SWEEP_PER_CALL  3
#define MC_PER_CALL     6
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "font8.h"
#include "../65816/pi_spigot.h"

// BG3 layout
#define CANVAS_CHR  0x0000u   // BG3 char base (word) — canvas tiles 0..255 + blank 256 + font 256..
#define CANVAS_MAP  0x4000u   // BG3 tilemap base (word)
#define BOX_COL     16        // scatter canvas at RIGHT half (cols 16..31)
#define BOX_ROW     0         // rows 0..15

// BG3 2bpp palette (CGRAM 0..3):
//   0 = black (background), 1 = white (text + inside-circle dots),
//   2 = dark gray (labels + outside-circle dots), 3 = cyan (cursor / header accent)
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(10, 10, 10), SNES_RGB(0, 24, 28),
};

// ---------------------------------- PiHud drawable ------------------------------------------
// Manages BG3 tilemap left 16 cols for rows 0..15 (digit panel), and full 32 cols for rows
// 16..19 (stats). Shares BG3 with BitmapCanvas (canvas owns cols 16-31 rows 0-15).

#define PHUD_STAT_ROW    16      // first stats row (below the digit panel)
#define PHUD_STAT_NROWS   4      // rows 16-19
#define PHUD_COLS        16      // left panel width in tiles
#define PHUD_NCOLS_STAT  32      // stats rows span the full screen width
#define FONT_BASE       256      // first font glyph tile# (= TEXT_FONT_BASE in text_layer.h)

// shadow[r][c] covers digit-panel rows 0..15, cols 0..15.
// statshadow[r][c] covers stats rows 0..3 (absolute rows 16-19), cols 0..31.
typedef struct {
    Drawable base;
    uint16_t map_word;
    uint16_t shadow[PHUD_STAT_ROW * PHUD_COLS];      // 256 words = 512 bytes
    uint16_t statshadow[PHUD_STAT_NROWS * PHUD_NCOLS_STAT]; // 128 words = 256 bytes
    uint16_t dirty;      // bit i = digit row i (0..15) needs re-DMA
    uint8_t  statdirty;  // bit i = stats row i (0..3) needs re-DMA
} PiHud;

static void _pihud_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    PiHud *h = (PiHud *)d;
    // Load 2bpp font glyphs at VRAM word FONT_BASE*8 (force-blank; direct write OK here).
    snes_vram_addr((uint16_t)(FONT_BASE * 8));
    for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8; i++) REG_VMDATA = FONT8[i];
    // Mark all rows dirty — DMA happens on the first emit().
    h->dirty     = 0xFFFFu;   // all 16 digit-panel rows (rows 0-15)
    h->statdirty = 0x0Fu;     // all 4 stats rows
}

static void _pihud_emit(Drawable *d, UploadQueue *q) {
    PiHud *h = (PiHud *)d;
    // Digit panel rows 0..15: 32 bytes each (16 words at cols 0-15).
    for (uint8_t i = 0; i < PHUD_STAT_ROW && q->n < UPQ_MAX_JOBS; i++) {
        if (!(h->dirty & (uint16_t)(1u << i))) continue;
        upq_push_vram(q, (uint16_t)(h->map_word + (uint16_t)i * 32u),
                      &h->shadow[(uint16_t)i * PHUD_COLS], 0x00u,
                      PHUD_COLS * 2u, VMAIN_INC_HIGH_1);
        h->dirty &= (uint16_t)~(1u << i);
    }
    // Stats rows 0..3 (absolute 16-19): 64 bytes each (32 words, full screen width).
    for (uint8_t i = 0; i < PHUD_STAT_NROWS && q->n < UPQ_MAX_JOBS; i++) {
        if (!(h->statdirty & (uint8_t)(1u << i))) continue;
        upq_push_vram(q, (uint16_t)(h->map_word + (uint16_t)(PHUD_STAT_ROW + i) * 32u),
                      &h->statshadow[(uint16_t)i * PHUD_NCOLS_STAT], 0x00u,
                      PHUD_NCOLS_STAT * 2u, VMAIN_INC_HIGH_1);
        h->statdirty &= (uint8_t)~(1u << i);
    }
}

static const DrawableVT PIHUD_VT = { _pihud_reserve, _pihud_emit };

static void pihud_init(PiHud *h, uint16_t map_word) {
    h->base.vt = &PIHUD_VT;
    h->base.tm_bits = 0;      // canvas already enables BG3
    h->map_word = map_word;
    // Fill all shadow entries with "space" (= FONT_BASE, the transparent blank glyph).
    for (uint16_t i = 0; i < PHUD_STAT_ROW * PHUD_COLS; i++) h->shadow[i] = FONT_BASE;
    for (uint16_t i = 0; i < PHUD_STAT_NROWS * PHUD_NCOLS_STAT; i++) h->statshadow[i] = FONT_BASE;
    h->dirty     = 0;
    h->statdirty = 0;
}

// Convert ASCII `c` to tile index.
static inline uint16_t _tile(char c) {
    uint8_t ch = (uint8_t)c;
    return (ch >= FONT8_FIRST && ch < FONT8_FIRST + FONT8_N)
              ? (uint16_t)(FONT_BASE + (ch - FONT8_FIRST)) : (uint16_t)FONT_BASE;
}

// Write ASCII char at (row, col) of digit panel shadow (marks dirty).
static inline void pihud_putc(PiHud *h, uint8_t row, uint8_t col, char c) {
    if (row >= PHUD_STAT_ROW || col >= PHUD_COLS) return;
    h->shadow[(uint16_t)row * PHUD_COLS + col] = _tile(c);
    h->dirty |= (uint16_t)(1u << row);
}

// Write NUL-terminated string into digit panel.
static void pihud_puts(PiHud *h, uint8_t row, uint8_t col, const char *s) {
    for (; *s && col < PHUD_COLS; s++, col++) pihud_putc(h, row, col, *s);
}

// Write NUL-terminated string into stats panel (stats_row = 0..3, absolute row 16-19).
static void pihud_stats_puts(PiHud *h, uint8_t stats_row, uint8_t col, const char *s) {
    if (stats_row >= PHUD_STAT_NROWS) return;
    uint16_t *row_ptr = &h->statshadow[(uint16_t)stats_row * PHUD_NCOLS_STAT];
    for (; *s && col < PHUD_NCOLS_STAT; s++, col++) row_ptr[col] = _tile(*s);
    h->statdirty |= (uint8_t)(1u << stats_row);
}

// ---------------------------------- number formatting ---------------------------------------

// Write decimal digits of v (right-to-left) into buf[], return digit count.
// buf must be at least 11 bytes. Caller reverses to get left-to-right.
static uint8_t _u32_digits(char *buf, uint32_t v) {
    uint8_t n = 0;
    if (!v) { buf[0] = '0'; return 1; }
    while (v && n < 10) { buf[n++] = (char)('0' + (uint8_t)(v % 10)); v /= 10; }
    return n;
}

// Convert uint32 to decimal string (NUL-terminated, buf >= 11 bytes). Returns buf.
static char *u32_to_str(char *buf, uint32_t v) {
    char tmp[10]; uint8_t n = _u32_digits(tmp, v);
    for (uint8_t i = 0; i < n; i++) buf[i] = tmp[n - 1u - i];
    buf[n] = 0;
    return buf;
}

// ---------------------------------- digit grid scroll --------------------------------------

#define DGRID_ROW_START  1    // first digit-output row (row 0 = "PI=3." header)
#define DGRID_ROW_END    14   // last digit-output row (inclusive)

// State for digit grid cursor
typedef struct {
    uint8_t row;    // current row within DGRID_ROW_START..DGRID_ROW_END
    uint8_t col;    // current col 0..PHUD_COLS-1
    uint8_t group;  // position within a group of 5 (for the space separator)
} DigitCursor;

static void dgcursor_init(DigitCursor *dc) {
    dc->row = DGRID_ROW_START; dc->col = 0; dc->group = 0;
}

// Append one digit to the grid (0-9). Handles group spacing and row scroll.
static void dgrid_append(PiHud *h, DigitCursor *dc, uint8_t digit) {
    pihud_putc(h, dc->row, dc->col, (char)('0' + digit));
    dc->col++;
    dc->group++;
    // Insert a space separator every 5 digits
    if (dc->group == 5 && dc->col < PHUD_COLS) {
        pihud_putc(h, dc->row, dc->col, ' ');
        dc->col++;
        dc->group = 0;
    }
    // Advance to next row when line is full
    if (dc->col >= PHUD_COLS) {
        dc->col = 0; dc->group = 0;
        if (dc->row < DGRID_ROW_END) {
            dc->row++;
        } else {
            // Scroll: shift rows DGRID_ROW_START..DGRID_ROW_END-1 up by one
            for (uint8_t r = DGRID_ROW_START; r < DGRID_ROW_END; r++) {
                for (uint8_t c = 0; c < PHUD_COLS; c++)
                    h->shadow[(uint16_t)r * PHUD_COLS + c] =
                        h->shadow[(uint16_t)(r + 1) * PHUD_COLS + c];
                h->dirty |= (uint16_t)(1u << r);
            }
            // Clear the last row
            for (uint8_t c = 0; c < PHUD_COLS; c++)
                h->shadow[(uint16_t)DGRID_ROW_END * PHUD_COLS + c] = FONT_BASE;
            h->dirty |= (uint16_t)(1u << DGRID_ROW_END);
        }
    }
}

// ---------------------------------- π estimate display ------------------------------------

// Display 4*hits/total as "N.NNNNN" in the stats panel stats row 3 (label at col 16).
// Uses long-division to extract 5 fractional digits without overflow.
__attribute__((noinline))
static void stats_update_estimate(PiHud *h, uint32_t hits, uint32_t total) {
    if (!total) { pihud_stats_puts(h, 3, 16, "PI~3.?????"); return; }
    uint32_t ip = (uint32_t)(4u * (uint32_t)hits / total);
    uint32_t rem = 4u * (uint32_t)hits - ip * total;
    char buf[12]; uint8_t n = 0;
    buf[n++] = (char)('0' + (uint8_t)ip);
    buf[n++] = '.';
    for (uint8_t i = 0; i < 5; i++) {
        rem *= 10u;
        uint8_t dig = (uint8_t)(rem / total);
        if (dig > 9) dig = 9;
        buf[n++] = (char)('0' + dig);
        rem -= (uint32_t)dig * total;
    }
    buf[n] = 0;
    pihud_stats_puts(h, 3, 16, "PI~");
    pihud_stats_puts(h, 3, 19, buf);
}

// ---------------------------------- Main application --------------------------------------

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    PiHud        hud;
    pi_spigot_state sp;
    mc_state     mc;
    DigitCursor  dc;
} App;

volatile uint16_t corpus_result;  // proof channel (read from WRAM by the gate; spigot+mc CRC)

// Throw `n` darts, plot each on the canvas. Split into its own noinline to cap RA pressure.
__attribute__((noinline))
static void throw_and_plot(App *a, uint16_t n) {
    mc_state *m = &a->mc;
    BitmapCanvas *cv = &a->canvas;
    for (uint16_t k = 0; k < n; k++) {
        // xorshift16 RNG (same 3-tap used in invaders_logic.h)
        uint16_t rx = m->rng; rx ^= (uint16_t)(rx << 7); rx ^= (uint16_t)(rx >> 9);
        rx ^= (uint16_t)(rx << 8); m->rng = rx;
        uint16_t ry = m->rng; ry ^= (uint16_t)(ry << 7); ry ^= (uint16_t)(ry >> 9);
        ry ^= (uint16_t)(ry << 8); m->rng = ry;
        int16_t sx = (int16_t)rx, sy = (int16_t)ry;
        int32_t r2 = (int32_t)sx * sx + (int32_t)sy * sy;  // 16×16→32
        uint8_t hit = (r2 <= (int32_t)0x40000000L) ? 1u : 0u;
        if (hit) m->hits++;
        m->total++;
        // Map signed [-32768,32767] → [0,127]: flip sign bit, then >>9
        uint8_t cx = (uint8_t)((uint16_t)(rx + 0x8000u) >> 9);
        uint8_t cy = (uint8_t)((uint16_t)(ry + 0x8000u) >> 9);
        canvas_plot(cv, (int16_t)cx, (int16_t)cy, hit ? 1 : 2);
    }
}

// Stats row 0: "DIGIT NNN/200" — noinline to cap RA pressure in stats_update.
__attribute__((noinline))
static void stats_row0(PiHud *h, uint16_t n) {
    char buf[5]; u32_to_str(buf, (uint32_t)n);
    pihud_stats_puts(h, 0, 0, "DIGIT ");
    pihud_stats_puts(h, 0, 6, buf);
    pihud_stats_puts(h, 0, 9, "/200");
}

// Stats row 1: "DARTS NNNNNNN" (right half) — noinline to cap RA pressure.
__attribute__((noinline))
static void stats_row1(PiHud *h, uint32_t total) {
    char buf[11]; u32_to_str(buf, total);
    pihud_stats_puts(h, 1, 16, "DARTS ");
    pihud_stats_puts(h, 1, 22, buf);
}

// Stats row 2: "HITS  NNNNNNN" (right half) — noinline to cap RA pressure.
__attribute__((noinline))
static void stats_row2(PiHud *h, uint32_t hits) {
    char buf[11]; u32_to_str(buf, hits);
    pihud_stats_puts(h, 2, 16, "HITS  ");
    pihud_stats_puts(h, 2, 22, buf);
}

static void stats_update(App *a) {
    stats_row0(&a->hud, a->sp.n);
    stats_row1(&a->hud, a->mc.total);
    stats_row2(&a->hud, a->mc.hits);
    stats_update_estimate(&a->hud, a->mc.hits, a->mc.total);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    pihud_init(&a->hud, CANVAS_MAP);
    display_add(&a->screen, (Drawable *)&a->canvas);  // reserve BG3 + tilemap (force-blank)
    display_add(&a->screen, (Drawable *)&a->hud);     // reserve: load font (force-blank)
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);

    pi_spigot_init(&a->sp);
    mc_init(&a->mc, 0xBEEF);
    dgcursor_init(&a->dc);

    // Header: "PI=3." on digit-panel row 0 (static)
    pihud_puts(&a->hud, 0, 0, "PI=3.");
    stats_update(a);
}

int main(void) {
    static App a;
    app_init(&a);

    // Self-verify: run the gate CRC using the App's pre-allocated state.
    // pi_gate_crc() reinitializes sp + mc; we re-init them after for the main loop.
    corpus_result = pi_gate_crc(&a.sp, &a.mc);
    pi_spigot_init(&a.sp);
    mc_init(&a.mc, 0xBEEF);

    for (;;) {
        // 1. Spigot: advance the carry sweep; dequeue output digits.
        pi_spigot_sweep(&a.sp, (int16_t)SWEEP_PER_CALL);
        int16_t d;
        while ((d = pi_dequeue(&a.sp)) >= 0)
            dgrid_append(&a.hud, &a.dc, (uint8_t)d);

        // Flush predigit when all digits are done.
        if (a.sp.n >= PI_DIGITS) {
            pi_spigot_flush(&a.sp);
            while ((d = pi_dequeue(&a.sp)) >= 0)
                dgrid_append(&a.hud, &a.dc, (uint8_t)d);
        }

        // 2. Monte-Carlo: throw darts, plot on scatter canvas.
        throw_and_plot(&a, MC_PER_CALL);

        // 3. Update stats panel every frame.
        stats_update(&a);

        // 4. Sync to v-blank: flush dirty HUD rows + dirty canvas tiles via DMA.
        display_frame(&a.screen);
    }
}
