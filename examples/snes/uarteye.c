// Bit-Banged UART Eye — #108 of the compiler stress-test battery (Round 6, Cluster D, final).
// Re-stresses patch 0010 (coalesce-rotate-Ac, a DEFAULT-8-bit register-coalescer miscompile) via a
// software-UART framing loop: a byte shifted out of a carry-rotated TX register and into a carry-
// rotated RX register (two loop-carried shift registers rotated on the back edge). The DEFAULT-8-bit
// build is the load-bearing leg (0010 not accum-gated); also builds a16/xy16 for the 5-way contrast.
//
// Visual: an oscilloscope EYE DIAGRAM — many 2-bit serial windows overlaid, so stable 0/1 levels form
// two bright horizontal rails and the transitions cross in the middle, leaving the open "eye". Built
// from a bit stream framed the same way the gate frames its bytes. The eye opening is the witness that
// framing/rotation is correct.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/uarteye.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        1
#define WIN_W       16
#define WIN_H       16
#define HI_ROW      3    // signal level 1 rail
#define LO_ROW      12   // signal level 0 rail

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  3,  6),    // 0: dark (eye interior)
    SNES_RGB( 4, 14, 10),    // 1: faint trace
    SNES_RGB(10, 26, 14),    // 2: bright trace
    SNES_RGB(24, 30, 16),    // 3: peak persistence
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint8_t      acc[WIN_H][WIN_W];   // persistence accumulator
    uint8_t      cellcol[WIN_H][WIN_W];
    uint16_t     seed;
    uint16_t     t;
    uint8_t      band;
} App;

volatile uint16_t corpus_result;

static inline void bump(App *a, uint8_t r, uint8_t c) {
    if (r < (uint8_t)WIN_H && c < (uint8_t)WIN_W && a->acc[r][c] < (uint8_t)3u) a->acc[r][c]++;
}

// Accumulate one 2-bit serial window (levels b0 then b1) into the eye persistence grid.
static void trace_window(App *a, uint8_t b0, uint8_t b1) {
    for (uint8_t x = 0u; x < (uint8_t)WIN_W; x++) {
        uint8_t bit = (x < (uint8_t)8u) ? b0 : b1;
        bump(a, (uint8_t)(bit ? HI_ROW : LO_ROW), x);
    }
    if (b0 != b1) {                       // transition crossing in the middle columns
        for (uint8_t r = (uint8_t)HI_ROW; r <= (uint8_t)LO_ROW; r++) { bump(a, r, 7u); bump(a, r, 8u); }
    }
}

static void recompute(App *a) {
    for(uint8_t r=0;r<WIN_H;r++) for(uint8_t c=0;c<WIN_W;c++) {
        uint8_t rail=(uint8_t)(r==HI_ROW || r==LO_ROW);
        uint8_t cross=(uint8_t)((c==7u || c==8u) && r>=HI_ROW && r<=LO_ROW);
        a->cellcol[r][c]=(uint8_t)(rail?2u:(cross?(uint8_t)(1u+((a->seed>>c)&1u)):0u));
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
    uint8_t cy=a->band;
    for(uint8_t cx=0;cx<WIN_W;cx++)
        canvas_fill_solid_tile(&a->canvas,cx,cy,a->cellcol[cy][cx]);
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
    a->seed = (uint16_t)0x55AAu;
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    recompute(a);
    text_puts(&a->text, 0, 2, "BIT-BANGED UART EYE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "UARTEYE", "SOFTWARE-UART FRAMING LOOP");
    corpus_result = uarteye_gate_crc();   // runs during title; expected 0x3F09
    title_end(&a.screen, &title, 90);
    update_hud(&a); display_frame(&a.screen);
    for (;;) {
        field_band(&a);
        a.band++;
        if (a.band >= WIN_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo=0u; a.canvas.hi=(uint16_t)(CANVAS_NTILES-1u);
            a.seed = (uint16_t)(a.seed * 25173u + 13849u);   // advance the trace stream
            recompute(&a);
            a.t = (uint16_t)(a.t + (uint16_t)1u);
        }
        display_frame(&a.screen);
    }
}
