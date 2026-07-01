// Brainfuck Threaded-Code VM — #38 of the compiler stress-test demo battery.
//
// Renders a live Brainfuck interpreter whose instruction dispatch is a COMPUTED GOTO
// (`goto *handlers[op]`, GNU C labels-as-values → 65816 `jmp ($ind,x)`/`jmp ($ind)`).  The
// program is the canonical "Hello World!"; you watch:
//   - the BF SOURCE with the program counter (the "tape head") scrubbing through it (cyan),
//   - the 64-cell TAPE as an ASCII heat ramp, the data pointer cell highlighted,
//   - the OUT marquee filling in "HELLO WORLD!" one byte at a time, looping forever,
//   - live STEP / DP / PC stats.
//
// No far pointers → builds default-8-bit AND +mos-a16 AND +mos-xy16 → 5-way differential bar.
// The stressed corner is pure control flow (indirectbr); there is no 32-bit ALU here.
// See docs/plans/2026-06-30-38-snes-bf-vm.md.
#include <snes.h>
#include "snesgfx/display.h"
#include "snesgfx/title_layer.h"
#include "snesgfx/upload.h"
#include "snesgfx/drawable.h"
#include "snesgfx/vram.h"
#include "font8.h"
#include "../65816/bf_vm.h"

// BF instructions executed per frame.  Small enough to WATCH the dispatch scrub; Hello World
// (~906 ops) then completes in ~75 frames (~1.3 s) before looping.
#define BF_STEP   12u

// BG3 layout (spigot convention)
#define BFHUD_CHR  0x0000u
#define BFHUD_MAP  0x4000u
#define FONT_BASE  256
#define GRID_COLS  32
#define GRID_ROWS  28

// Screen rows
#define ROW_HEADER   0
#define ROW_PROG     2     // program source rows 2..5
#define PROG_ROWS    4
#define ROW_TAPELBL  7
#define ROW_TAPE     8     // 8x8 tape grid rows 8..15
#define ROW_OUT     18
#define ROW_STEPS   22
#define ROW_DISP    24

// BG3 2bpp palette (CGRAM 0..3): black / white / dim gray / cyan accent.
static const uint16_t bf_pal[4] = {
    SNES_RGB(0, 0, 0), SNES_RGB(31, 31, 31), SNES_RGB(9, 10, 12), SNES_RGB(0, 26, 30),
};

// ASCII heat ramp for tape cell values (11 buckets across 0..255).
static const char HEAT[12] = " .,:;+*oO#@";   // [0]=' ' for empty cell

// ---------------------------------- BfHud drawable -----------------------------------------
// Full BG3 32x28 tilemap.  shadow holds the tile word for each cell; the high palette bits in
// the tilemap word select the color (white text vs cyan cursor).  Per-row dirty bitmask.

typedef struct {
    Drawable base;
    uint16_t map_word;
    uint16_t shadow[GRID_ROWS * GRID_COLS];   // 896 words
    uint32_t dirty;                           // bit r → row r needs re-DMA
} BfHud;

static void _bf_reserve(Drawable *d, VramAlloc *va) {
    (void)va;
    BfHud *h = (BfHud *)d;
    // Load 2bpp font glyphs at VRAM word FONT_BASE*8 (force-blank; direct write OK here).
    snes_vram_addr((uint16_t)(FONT_BASE * 8));
    for (uint16_t i = 0; i < (uint16_t)FONT8_N * 8; i++) REG_VMDATA = FONT8[i];
    REG_BG34NBA = (uint8_t)((BFHUD_CHR >> 12) & 0x0Fu);
    REG_BG3SC   = SNES_BGSC(h->map_word, 0);
    // Clear the ENTIRE 32x32 BG3 tilemap to the blank (space) tile directly — reserve() runs in
    // force-blank so direct VRAM writes are safe.  Without this, rows the demo never writes keep
    // uninitialized VRAM garbage (whose stray palette bits index uninitialized CGRAM → colored
    // stripes); the per-row dirty-DMA can't be relied on to blank them (low rows starve the
    // UPQ_MAX_JOBS budget every frame).  This matches _canvas_reserve.
    snes_vram_addr(h->map_word);
    uint16_t blank = FONT_BASE;
    for (uint16_t i = 0; i < 32u * 32u; i++) REG_VMDATA = blank;
    h->base.tm_bits = TM_BG3;
    h->dirty = 0xFFFFFFFFu;   // all rows dirty
}

static void _bf_emit(Drawable *d, UploadQueue *q) {
    BfHud *h = (BfHud *)d;
    for (uint8_t r = 0; r < GRID_ROWS && q->n < UPQ_MAX_JOBS; r++) {
        if (!(h->dirty & ((uint32_t)1u << r))) continue;
        upq_push_vram(q, (uint16_t)(h->map_word + (uint16_t)r * GRID_COLS),
                      &h->shadow[(uint16_t)r * GRID_COLS], 0x00u,
                      GRID_COLS * 2u, VMAIN_INC_HIGH_1);
        h->dirty &= ~((uint32_t)1u << r);
    }
}

static const DrawableVT BFHUD_VT = { _bf_reserve, _bf_emit };

// Map ASCII to a tile word.  `accent`!=0 selects palette 3 (cyan) for highlight.
static inline uint16_t _cell(char c, uint8_t accent) {
    uint8_t ch = (uint8_t)c;
    uint16_t tile = (ch >= FONT8_FIRST && ch < FONT8_FIRST + FONT8_N)
                      ? (uint16_t)(FONT_BASE + (ch - FONT8_FIRST)) : (uint16_t)FONT_BASE;
    // BG3 2bpp tilemap word: bits 10-12 = palette.  Palette 1 (CGRAM 4..7) holds the cyan in
    // slot 1.  We set up CGRAM so palette 1 colour 1 = cyan, palette 0 colour 1 = white.
    return accent ? (uint16_t)(tile | 0x0400u) : tile;
}

static void bf_init_hud(BfHud *h, uint16_t map_word) {
    h->base.vt = &BFHUD_VT;
    h->base.tm_bits = 0;
    h->map_word = map_word;
    for (uint16_t i = 0; i < GRID_ROWS * GRID_COLS; i++) h->shadow[i] = _cell(' ', 0);
    h->dirty = 0;
}

static inline void hud_put(BfHud *h, uint8_t row, uint8_t col, char c, uint8_t accent) {
    if (row >= GRID_ROWS || col >= GRID_COLS) return;
    h->shadow[(uint16_t)row * GRID_COLS + col] = _cell(c, accent);
    h->dirty |= ((uint32_t)1u << row);
}

static void hud_puts(BfHud *h, uint8_t row, uint8_t col, const char *s) {
    for (; *s && col < GRID_COLS; s++, col++) hud_put(h, row, col, *s, 0);
}

static void hud_clear_row(BfHud *h, uint8_t row) {
    for (uint8_t c = 0; c < GRID_COLS; c++) hud_put(h, row, c, ' ', 0);
}

// ---------------------------------- BF op → source char -------------------------------------
// The compiled prog[] stores BF_* opcodes; map back to the printable BF character.
static const char OPCHAR[9] = { '>', '<', '+', '-', '.', ',', '[', ']', '!' };

// ---------------------------------- number formatting ---------------------------------------
static void put_u16_dec(BfHud *h, uint8_t row, uint8_t col, uint16_t v, uint8_t width) {
    char buf[6];
    for (int8_t i = (int8_t)(width - 1); i >= 0; i--) {
        buf[i] = (char)('0' + (uint8_t)(v % 10u)); v /= 10u;
    }
    for (uint8_t i = 0; i < width; i++) hud_put(h, row, (uint8_t)(col + i), buf[i], 0);
}

// ---------------------------------- rendering -----------------------------------------------

typedef struct {
    Display screen;
    BfHud   hud;
    bf_vm   vm;
} App;

volatile uint16_t corpus_result;   // proof channel (read from WRAM by the gate; bf CRC)

// Draw the static frame (header, program text, captions).
static void draw_static(App *a) {
    BfHud *h = &a->hud;
    hud_puts(h, ROW_HEADER, 2, "BRAINFUCK THREADED-CODE VM");
    hud_puts(h, ROW_TAPELBL, 0, "TAPE");
    hud_puts(h, ROW_OUT, 0, "OUT>");
    hud_puts(h, ROW_DISP, 0, "DISPATCH  GOTO *HANDLERS[OP]");
    // The program source, wrapped GRID_COLS per row across PROG_ROWS rows.
    for (uint8_t r = 0; r < PROG_ROWS; r++) hud_clear_row(h, (uint8_t)(ROW_PROG + r));
    for (uint16_t i = 0; i < a->vm.prog_len; i++) {
        uint8_t r = (uint8_t)(i / GRID_COLS), c = (uint8_t)(i % GRID_COLS);
        if (r >= PROG_ROWS) break;
        hud_put(h, (uint8_t)(ROW_PROG + r), c, OPCHAR[a->vm.prog[i]], 0);
    }
}

// Redraw the program-cursor highlight: dim everything on the PC's row pair, re-accent PC token.
static uint16_t prev_pc = 0xFFFFu;
static void draw_pc(App *a) {
    BfHud *h = &a->hud;
    bf_vm *v = &a->vm;
    // Un-accent previous PC token.
    if (prev_pc < v->prog_len && (prev_pc / GRID_COLS) < PROG_ROWS) {
        uint8_t r = (uint8_t)(ROW_PROG + prev_pc / GRID_COLS), c = (uint8_t)(prev_pc % GRID_COLS);
        hud_put(h, r, c, OPCHAR[v->prog[prev_pc]], 0);
    }
    uint16_t pc = v->pc < v->prog_len ? v->pc : (uint16_t)(v->prog_len - 1u);
    if ((pc / GRID_COLS) < PROG_ROWS) {
        uint8_t r = (uint8_t)(ROW_PROG + pc / GRID_COLS), c = (uint8_t)(pc % GRID_COLS);
        hud_put(h, r, c, OPCHAR[v->prog[pc]], 1);
    }
    prev_pc = pc;
}

// Redraw the 64-cell tape heat grid (8 cols x 8 rows), DP cell accented.
static void draw_tape(App *a) {
    BfHud *h = &a->hud;
    bf_vm *v = &a->vm;
    for (uint16_t i = 0; i < BF_TAPE_N; i++) {
        uint8_t val = v->tape[i];
        // 0 → ' ', else bucket 1..10 over 1..255 (so any nonzero cell is visible).
        uint8_t bucket = val ? (uint8_t)(1u + (uint16_t)(val * 10u) / 256u) : 0u;
        if (bucket > 10u) bucket = 10u;
        uint8_t r = (uint8_t)(ROW_TAPE + i / 8u), c = (uint8_t)(2u + (i % 8u) * 3u);
        hud_put(h, r, c, HEAT[bucket], (uint8_t)(i == v->dp));
    }
}

// Redraw the output marquee: last GRID_COLS-5 bytes of output, uppercased for the font.
static void draw_out(App *a) {
    BfHud *h = &a->hud;
    bf_vm *v = &a->vm;
    uint8_t width = GRID_COLS - 5;
    uint16_t total = v->out_head;
    uint16_t start = total > width ? (uint16_t)(total - width) : 0u;
    for (uint8_t i = 0; i < width; i++) {
        uint16_t idx = (uint16_t)(start + i);
        char ch = ' ';
        if (idx < total && (total - idx) <= BF_OUT_N) {
            uint8_t b = v->out[idx & BF_OUT_MASK];
            if (b >= 'a' && b <= 'z') b = (uint8_t)(b - 32);   // uppercase for the font
            if (b == '\n' || b < 0x20 || b > 0x5F) b = ' ';
            ch = (char)b;
        }
        hud_put(h, ROW_OUT, (uint8_t)(5 + i), ch, 0);
    }
}

static void draw_stats(App *a) {
    BfHud *h = &a->hud;
    bf_vm *v = &a->vm;
    hud_puts(h, ROW_STEPS, 0, "STEPS");
    put_u16_dec(h, ROW_STEPS, 6, v->steps, 5);
    hud_puts(h, ROW_STEPS, 13, "DP");
    put_u16_dec(h, ROW_STEPS, 16, v->dp, 2);
    hud_puts(h, ROW_STEPS, 20, "PC");
    put_u16_dec(h, ROW_STEPS, 23, v->pc, 3);
    hud_put(h, ROW_STEPS, 26, '/', 0);
    put_u16_dec(h, ROW_STEPS, 27, v->prog_len, 3);
}

static void app_init(App *a) {
    display_init(&a->screen);
    bf_init_hud(&a->hud, BFHUD_MAP);
    display_add(&a->screen, (Drawable *)&a->hud);
    // CGRAM: palette 0 (white text) + palette 1 (cyan highlight).
    // BG3 2bpp uses 4 colours per palette; we push 8 colours (palettes 0 and 1).
    static uint16_t cg[8];
    cg[0] = bf_pal[0]; cg[1] = bf_pal[1]; cg[2] = bf_pal[2]; cg[3] = bf_pal[3];  // pal 0
    cg[4] = bf_pal[0]; cg[5] = bf_pal[3]; cg[6] = bf_pal[2]; cg[7] = bf_pal[3];  // pal 1 (cyan)
    upq_push_cgram(&a->screen.q, 0, cg, 0x00u, (uint8_t)sizeof cg);

    bf_init(&a->vm, BF_SOURCE);
    draw_static(a);
    draw_pc(a);
    draw_tape(a);
    draw_out(a);
    draw_stats(a);
}

int main(void) {
    static App a;
    app_init(&a);

    static TitleLayer title;
    title_begin(&a.screen, &title, "THREADED VM", "BRAINFUCK");

    // Self-verify: run the gate CRC into the WRAM proof channel.
    corpus_result = bf_vm_gate_crc();
    // Re-init the display VM (the gate used its own static machine).
    bf_init(&a.vm, BF_SOURCE);
    prev_pc = 0xFFFFu;

    title_end(&a.screen, &title, 100);

    uint16_t hold = 0;
    for (;;) {
        if (!a.vm.halted) {
            bf_run(&a.vm, BF_STEP);
        } else if (++hold >= 90u) {    // dwell on the finished "HELLO WORLD!" then loop
            bf_init(&a.vm, BF_SOURCE);
            prev_pc = 0xFFFFu;
            hold = 0;
        }
        draw_pc(&a);
        draw_tape(&a);
        draw_out(&a);
        draw_stats(&a);
        display_frame(&a.screen);
    }
}
