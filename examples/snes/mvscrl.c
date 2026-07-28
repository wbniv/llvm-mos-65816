// Descending memmove Scroll Slabs — #79 of the compiler stress-test demo battery.
// Renders the portable memmove scroll (examples/65816/mvscrl.h) on the 128x128 BG3
// 2bpp canvas; builds default-8-bit AND +mos-a16 AND +mos-xy16 (no far pointers →
// full 5-way bar).
//
// The codegen corner: G_MEMMOVE at MOSLegalizerInfo.cpp:422 (.custom()).
//   memmove(&upper[1][0], &upper[0][0], 7×16) — dst > src, overlapping → Descending=true
//   memmove(&lower[0][0], &lower[1][0], 7×16) — dst < src, overlapping → Ascending
// descending detection: compareOperandLocations :3145-3152 returns −1 for G_MEMMOVE,
// sets Descending=true; offset adjusts :3231/:3247.
// SDK memmove: llvm-mos-sdk mos-platform/common/c/mem.c:15.
// Distinct from #23 lsystem (memmove incidental, non-overlapping) and #49 lzdec
// (overlapping back-ref copy byte-by-byte, never emits G_MEMMOVE).
//
// Visual: 128×128 canvas split into 8-tile upper (scrolling DOWN) and 8-tile lower
// (scrolling UP) bands.  Bands meet at the centre where fresh coloured rows spawn.
// Each tile colour = upper[row][col] or lower[row][col] (uint8 0..3).  A 4-level
// BG3 2bpp palette shows the bands as vivid counter-scrolling slabs.
// Shadow update: one tile-row per frame; the full canvas is flushed atomically (F1), and one
// mv_step (both memmoves) runs per completed shadow so every painted row is one coherent state.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/mvscrl.h"

#define CANVAS_CHR  0x0000u
#define CANVAS_MAP  0x4000u
#define BOX_COL     8
#define BOX_ROW     6
#define HUD_TOP_ROW 1
#define HUD_BOT_ROW 25
#define NCOL        4
#define BAND        1
#define NTILES_W    16
#define NTILES_H    16
#define UPPER_ROWS  8u   // tile rows 0..7: scroll DOWN (memmove descending)
#define LOWER_ROWS  8u   // tile rows 8..15: scroll UP  (memmove ascending)

// 4-colour slab palette.
static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 2,  2, 14),    // 0: deep indigo
    SNES_RGB( 4, 20, 16),    // 1: teal
    SNES_RGB(26, 12,  2),    // 2: orange
    SNES_RGB(28, 22,  2),    // 3: gold
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    MVState      mv;
    uint16_t     t;        // animation tick (= seed for next scroll step)
    uint8_t      band;
} App;

volatile uint16_t corpus_result;


// Paint one tile row straight from the memmove buffers. The picture MUST be a read of
// mv.upper/mv.lower — this demo's premise (#79) is that the visual IS the proof that
// G_MEMMOVE's Ascending and Descending paths moved the right bytes, so a decorative
// stand-in pattern would silently void it. corpus_result cannot catch that: the gate
// runs mvscrl_gate_crc() during the title, independently of this loop.
__attribute__((noinline))
static void field_band(App *a) {
    uint8_t cy = a->band;
    for (uint8_t cx = 0u; cx < (uint8_t)NTILES_W; cx++) {
        uint8_t col = (cy < (uint8_t)UPPER_ROWS)
                    ? a->mv.upper[cy][cx]
                    : a->mv.lower[cy - (uint8_t)UPPER_ROWS][cx];
        canvas_fill_solid_tile(&a->canvas, cx, cy, col);
    }
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
    mv_init(&a->mv);
    a->t = (uint16_t)0u;
    a->band = (uint8_t)0u;
    text_puts(&a->text, 0, 2, "MEMMOVE SCROLL SLABS");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "G_MEMMOVE", "DESCEND+ASCEND");
    corpus_result = mvscrl_gate_crc();   // runs during title; expected 0x72A7
    title_end(&a.screen, &title, 90);
    update_hud(&a); display_frame(&a.screen);
    for (;;) {
        field_band(&a);
        a.band++;
        if (a.band >= NTILES_H) {
            a.band = (uint8_t)0u;
            a.canvas.lo=0u; a.canvas.hi=(uint16_t)(CANVAS_NTILES-1u);
            // One scroll step per completed shadow, so all 16 painted rows come from a
            // single coherent buffer state: upper scrolls DOWN (descending memmove),
            // lower scrolls UP (ascending). This is the stress under test — it must run.
            mv_step(&a.mv, a.t);
            a.t = (uint16_t)(a.t + (uint16_t)7u);
            update_hud(&a);
        }
        display_frame(&a.screen);
    }
}
