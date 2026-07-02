// Range Coder — #86 of the compiler stress-test demo battery.
// Binary arithmetic (range) coder visualized as an interval-zoom bar + a waterfall of
// emitted bytes on a 128x128 BG3 canvas. The interval split uses a 32-bit multiply and
// the renormalization is a byte-wise shift carry loop. Builds default-8-bit AND +mos-a16
// AND +mos-xy16 (5-way bar, no far pointers).
//
// Distinct from #67 huffman (table codes) and #49 lzdec (LZ copy): this is arithmetic coding.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/rangecode.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  1,  4),    // 0: bg
    SNES_RGB( 6, 26, 22),    // 1: range bar (teal)
    SNES_RGB(28, 14,  4),    // 2: emitted byte waterfall (orange)
    SNES_RGB(30, 30, 30),    // 3: probability marker (white)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    RangeEnc     enc;
    uint16_t     s;        // PRNG state
    uint16_t     prob;     // adaptive probability
    uint8_t      row;      // waterfall row
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

// Encode a few bits per frame and draw: the range bar (top) + a byte waterfall.
static void step_and_draw(App *a) {
    // encode 4 bits/frame
    uint8_t k;
    for (k = 0u; k < 4u; k++) {
        a->s = rc_xs16(a->s);
        uint8_t bit = (uint8_t)(a->s & 1u);
        rc_encode_bit(&a->enc, bit, a->prob);
        if (bit == 0u) a->prob = (uint16_t)(a->prob + (uint16_t)((4096u - a->prob) >> 5));
        else           a->prob = (uint16_t)(a->prob - (uint16_t)(a->prob >> 5));
        if (a->prob < 32u) a->prob = 32u;
        if (a->prob > 4064u) a->prob = 4064u;
    }
    // range bar: width proportional to (range >> 25) in [0..127]
    uint8_t barw = (uint8_t)((a->enc.range >> 25) & 0x7Fu);
    uint8_t x;
    for (x = 0u; x < (uint8_t)CANVAS_W; x++) {
        canvas_plot(&a->canvas, (int16_t)x, (int16_t)0, (uint8_t)(x <= barw ? 1u : 0u));
        canvas_plot(&a->canvas, (int16_t)x, (int16_t)1, (uint8_t)(x <= barw ? 1u : 0u));
    }
    // probability marker column
    uint8_t pm = (uint8_t)((a->prob >> 5) & 0x7Fu);   // 0..127
    canvas_plot(&a->canvas, (int16_t)pm, (int16_t)2, 3u);
    canvas_plot(&a->canvas, (int16_t)pm, (int16_t)3, 3u);
    // byte waterfall: plot the low-byte pattern of low on the current row (rows 5..127)
    uint8_t rowy = (uint8_t)(5u + (a->row % 122u));
    uint8_t b = (uint8_t)(a->enc.low >> 24);
    uint8_t bx;
    for (bx = 0u; bx < 8u; bx++) {
        uint8_t on = (uint8_t)((b >> bx) & 1u);
        canvas_plot(&a->canvas, (int16_t)(bx * 16 + 4), (int16_t)rowy, (uint8_t)(on ? 2u : 0u));
    }
    a->row++;
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='P'; buf[10]='=';
    buf[11]=H[(a->prob>>12)&0xFu]; buf[12]=H[(a->prob>>8)&0xFu];
    buf[13]=H[(a->prob>>4)&0xFu]; buf[14]=H[a->prob&0xFu];
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
    rc_init(&a->enc);
    a->s = 0xACE1u;
    a->prob = 2048u;
    a->row = 0u;
    a->frame = 0u;
    text_puts(&a->text, 0, 3, "RANGE CODER RENORM");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "RANGE CODER", "MUL-CARRY RENORM");
    corpus_result = rangecode_gate_crc();   // expected 0x6D21
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        // reset the coder occasionally so the interval keeps re-zooming visibly
        if ((a.frame % 240u) == 0u) { rc_init(&a.enc); a.prob = 2048u; canvas_clear(&a.canvas); a.row = 0u; }
        step_and_draw(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
