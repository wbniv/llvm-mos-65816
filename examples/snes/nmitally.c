// VBlank Interrupt Tally — #123 of the compiler stress-test demo battery.
//
// The FIRST demo in the battery with a real __attribute__((interrupt)) handler. crt0 installs a
// weak `nmi: rti` stub (platforms/snes/crt0.c) and link.ld points both the native ($FFEA) and
// emulation ($FFFA) NMI vectors at it; the strong C definition below takes the vector.
//
// What it stresses: the MOS interrupt calling convention on a 65816 in NATIVE mode. Hardware
// interrupt entry pushes PB/PC/P, sets I and clears D — but does NOT normalise M/X. The handler
// therefore inherits whatever accumulator/index width the interrupted code was running in, and
// under +mos-a16 the main loop below is deliberately full of long `rep #$20` brackets for the NMI
// to land inside. A handler that does not re-establish its assumed widths at entry mis-sizes its
// own prologue pushes and immediates.
//
// Determinism: the tally advances behind an arm/service/clear handshake so the CRC counts fenced
// TICKS, not elapsed v-blanks. Full design review in
// docs/plans/2026-08-03-123-snes-nmitally.md ("Determinism design review").
//
// No far pointers, all state in bank-0 WRAM -> 5-way differential bar.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "font8.h"
#include "../65816/nmitally.h"

// BG3 layout (identical to spigot.c — the canonical two-panel split).
#define CANVAS_CHR  0x0000u   // BG3 char base (word): canvas tiles 0..255, font at 256
#define CANVAS_MAP  0x4000u   // BG3 tilemap base (word)
#define BOX_COL     16        // scatter canvas occupies the RIGHT half (cols 16..31)
#define BOX_ROW     0         // rows 0..15

// BG3 2bpp palette (CGRAM 0..3): black / white / grey / cyan.
static const uint16_t bg3_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(10, 10, 10), SNES_RGB(0, 24, 28),
};

// ------------------------------------------------------------------------------------------
// The interrupt handler and the state it shares with the main loop.
//
// ALL of these are `volatile`: they are read and written by an asynchronous handler, and nothing
// else would force the main loop to reload them across the fence (the compiler can prove nmi() is
// never *called* from main). The work state is deliberately NOT volatile — see nmitally.h.
// ------------------------------------------------------------------------------------------

static volatile NmiTallyState g_tally;   // gated tally: advanced exactly once per arm
static volatile NmiTallyState g_disp;    // free-run tally: display only, never folded into the CRC
static volatile uint8_t       g_arm;     // 1 = one gated tally step is requested
static volatile uint8_t       g_free;    // 1 = free-run the display tally every v-blank

// The NMI service routine. Runs at the start of every v-blank once display_init() has set
// NMITIMEN bit 7.
//
// It deliberately does NOT read RDNMI ($4210): snesgfx's display_frame() paces on the RDNMI poll,
// and RDNMI is read-clearing, so an ack here would eat the main loop's v-blank edge. The 65816's
// NMI is edge-triggered, so leaving the flag latched does not re-enter the handler.
__attribute__((interrupt)) void nmi(void) {
    if (g_arm) {                     // fenced gate step: exactly one per arm
        nmitally_isr_step(&g_tally);
        g_arm = 0;                   // release the main loop's spin
    }
    if (g_free) {                    // post-gate: keep the screen alive, CRC-neutral
        nmitally_isr_step(&g_disp);
    }
}

// ---------------------------------- TallyHud drawable ---------------------------------------
// Left panel (cols 0..15, rows 0..15) + full-width stats rows 16..19. PiHud model (spigot.c:44).

#define THUD_STAT_ROW    16      // first stats row
#define THUD_STAT_NROWS   4      // rows 16..19
#define THUD_COLS        16      // left panel width in tiles
#define THUD_NCOLS_STAT  32      // stats rows span the full width
#define FONT_BASE       256      // first font glyph tile#

typedef struct {
    Drawable base;
    uint16_t map_word;
    uint16_t shadow[THUD_STAT_ROW * THUD_COLS];
    uint16_t statshadow[THUD_STAT_NROWS * THUD_NCOLS_STAT];
    uint16_t dirty;      // bit i = left-panel row i needs re-DMA
    uint8_t  statdirty;  // bit i = stats row i needs re-DMA
} TallyHud;

static void _thud_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    TallyHud *h = (TallyHud *)d;
    snes_vram_addr((uint16_t)(FONT_BASE * 8));                 // force-blank: direct write is legal
    for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8; i++) REG_VMDATA = FONT8[i];
    h->dirty     = 0xFFFFu;
    h->statdirty = 0x0Fu;
}

static void _thud_emit(Drawable *d, UploadQueue *q) {
    TallyHud *h = (TallyHud *)d;
    for (uint8_t i = 0; i < THUD_STAT_ROW && q->n < UPQ_MAX_JOBS; i++) {
        if (!(h->dirty & (uint16_t)(1u << i))) continue;
        upq_push_vram(q, (uint16_t)(h->map_word + (uint16_t)i * 32u),
                      &h->shadow[(uint16_t)i * THUD_COLS], 0x00u,
                      THUD_COLS * 2u, VMAIN_INC_HIGH_1);
        h->dirty &= (uint16_t)~(1u << i);
    }
    for (uint8_t i = 0; i < THUD_STAT_NROWS && q->n < UPQ_MAX_JOBS; i++) {
        if (!(h->statdirty & (uint8_t)(1u << i))) continue;
        upq_push_vram(q, (uint16_t)(h->map_word + (uint16_t)(THUD_STAT_ROW + i) * 32u),
                      &h->statshadow[(uint16_t)i * THUD_NCOLS_STAT], 0x00u,
                      THUD_NCOLS_STAT * 2u, VMAIN_INC_HIGH_1);
        h->statdirty &= (uint8_t)~(1u << i);
    }
}

static const DrawableVT THUD_VT = { _thud_reserve, _thud_emit };

static void thud_init(TallyHud *h, uint16_t map_word) {
    h->base.vt = &THUD_VT;
    h->base.tm_bits = 0;      // the canvas already enables BG3
    h->map_word = map_word;
    for (uint16_t i = 0; i < THUD_STAT_ROW * THUD_COLS; i++) h->shadow[i] = FONT_BASE;
    for (uint16_t i = 0; i < THUD_STAT_NROWS * THUD_NCOLS_STAT; i++) h->statshadow[i] = FONT_BASE;
    h->dirty = 0;
    h->statdirty = 0;
}

static inline uint16_t _tile(char c) {
    uint8_t ch = (uint8_t)c;
    return (ch >= FONT8_FIRST && ch < FONT8_FIRST + FONT8_N)
              ? (uint16_t)(FONT_BASE + (ch - FONT8_FIRST)) : (uint16_t)FONT_BASE;
}

static void thud_puts(TallyHud *h, uint8_t row, uint8_t col, const char *s) {
    if (row >= THUD_STAT_ROW) return;
    for (; *s && col < THUD_COLS; s++, col++) {
        h->shadow[(uint16_t)row * THUD_COLS + col] = _tile(*s);
        h->dirty |= (uint16_t)(1u << row);
    }
}

static void thud_stats_puts(TallyHud *h, uint8_t stats_row, uint8_t col, const char *s) {
    if (stats_row >= THUD_STAT_NROWS) return;
    uint16_t *row_ptr = &h->statshadow[(uint16_t)stats_row * THUD_NCOLS_STAT];
    for (; *s && col < THUD_NCOLS_STAT; s++, col++) row_ptr[col] = _tile(*s);
    h->statdirty |= (uint8_t)(1u << stats_row);
}

// ---------------------------------- number formatting ---------------------------------------

static uint8_t _u32_digits(char *buf, uint32_t v) {
    uint8_t n = 0;
    if (!v) { buf[0] = '0'; return 1; }
    while (v && n < 10) { buf[n++] = (char)('0' + (uint8_t)(v % 10u)); v /= 10u; }
    return n;
}

static char *u32_to_str(char *buf, uint32_t v) {
    char tmp[10]; uint8_t n = _u32_digits(tmp, v);
    for (uint8_t i = 0; i < n; i++) buf[i] = tmp[n - 1u - i];
    buf[n] = 0;
    return buf;
}

static const char HEXD[17] = "0123456789ABCDEF";

static char *u16_to_hex(char *buf, uint16_t v) {
    buf[0] = '0'; buf[1] = 'X';
    buf[2] = HEXD[(v >> 12) & 0x0Fu];
    buf[3] = HEXD[(v >>  8) & 0x0Fu];
    buf[4] = HEXD[(v >>  4) & 0x0Fu];
    buf[5] = HEXD[ v        & 0x0Fu];
    buf[6] = 0;
    return buf;
}

// ---------------------------------- Main application ----------------------------------------

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TallyHud     hud;
    NmiWorkState work;
} App;

volatile uint16_t corpus_result;   // proof channel (read from WRAM by the gate)

// Repaint the live counter panel. noinline to cap register-allocator pressure.
__attribute__((noinline))
static void hud_counters(App *a, volatile const NmiTallyState *t, uint16_t crc, const char *state) {
    char buf[12];
    thud_puts(&a->hud, 4, 0, "TICKS ");
    thud_puts(&a->hud, 4, 6, u32_to_str(buf, (uint32_t)t->ticks));
    thud_puts(&a->hud, 6, 0, "ACCUM ");
    thud_puts(&a->hud, 6, 6, u32_to_str(buf, t->accum));
    thud_puts(&a->hud, 8, 0, "LFSR  ");
    thud_puts(&a->hud, 8, 6, u16_to_hex(buf, t->lfsr));
    thud_puts(&a->hud, 10, 0, "CRC   ");
    thud_puts(&a->hud, 10, 6, u16_to_hex(buf, crc));
    thud_stats_puts(&a->hud, 0, 0, "STATE   ");
    thud_stats_puts(&a->hud, 0, 8, state);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    thud_init(&a->hud, CANVAS_MAP);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->hud);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);

    nmitally_work_init(&a->work);
    nmitally_tally_init(&g_tally);
    nmitally_tally_init(&g_disp);
    g_arm = 0;
    g_free = 0;

    thud_puts(&a->hud, 0, 0, "NMI TALLY");
    thud_puts(&a->hud, 1, 0, "ISR-DRIVEN");
    thud_stats_puts(&a->hud, 1, 0, "NMI CC  ATTRIBUTE INTERRUPT");
    thud_stats_puts(&a->hud, 2, 0, "FENCE   ARM / SERVICE / CLEAR");
    thud_stats_puts(&a->hud, 3, 0, "BAR     HOST == DEFAULT == A16 == XY16");
    hud_counters(a, &g_tally, 0u, "BOOT");
}

// Plot one scatter point from the free-run tally's LFSR: visible proof the handler is still
// servicing v-blanks after the gate has closed. CRC-neutral.
__attribute__((noinline))
static void plot_from_isr(App *a) {
    uint16_t r = g_disp.lfsr;
    uint16_t n = g_disp.ticks;
    uint8_t cx = (uint8_t)(r & 0x7Fu);
    uint8_t cy = (uint8_t)((r >> 7) & 0x7Fu);
    canvas_plot(&a->canvas, (int16_t)cx, (int16_t)cy, (n & 1u) ? 1u : 3u);
}

int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin16(&a.screen, &title, "NMI TALLY", "INTERRUPT CC");
    title_end(&a.screen, &title, 110);

    // ---- The fenced gate loop. One tally tick per v-blank, NMITALLY_TICKS of them. ----
    // Each iteration: main-owned +mos-a16 arithmetic (the window the NMI lands in), arm, sync to
    // v-blank (the NMI at that v-blank services the arm), fence on the disarm, fold.
    uint16_t h = 0u;
    for (uint16_t i = 0u; i < (uint16_t)NMITALLY_TICKS; i++) {
        nmitally_work_step(&a.work);
        g_arm = 1u;
        display_frame(&a.screen);
        while (g_arm) { }                          // fence — the tally step is complete
        h = nmitally_fold(h, &g_tally, &a.work);
        if ((i & 7u) == 0u) hud_counters(&a, &g_tally, h, "GATE");
    }
    corpus_result = h;
    hud_counters(&a, &g_tally, h, "SEALED");

    // ---- Post-gate: free-run the display tally so the screen keeps moving. ----
    g_free = 1u;
    for (;;) {
        nmitally_work_step(&a.work);
        plot_from_isr(&a);
        hud_counters(&a, &g_disp, corpus_result, "FREE-RUN");
        display_frame(&a.screen);
    }
}
