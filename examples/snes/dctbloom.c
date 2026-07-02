// DCT Bloom — #88 of the compiler stress-test demo battery.
// Split view on a 128x128 BG3 canvas: left = animated 8x8 source block (upscaled),
// right = its 8x8 integer-DCT coefficient heat grid. The DCT is an int32 16x16->32 MAC
// + signed arithmetic-shift descale + narrowing cast. Builds default-8-bit AND +mos-a16
// AND +mos-xy16 (5-way bar, no far pointers).
//
// Distinct from #25 fft (radix-2 butterflies/twiddles): dense O(N^2) cosine MAC.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/dctbloom.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u
#define BLK          7          // px per cell (8*7=56, fits in a 64px half)

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  1,  4),    // 0: bg / near-zero
    SNES_RGB( 6, 14, 24),    // 1: low magnitude (blue)
    SNES_RGB(22, 20,  8),    // 2: mid (amber)
    SNES_RGB(31, 18, 24),    // 3: high (hot pink)
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    int16_t      phase;
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

static void fill_cell(BitmapCanvas *cv, uint8_t ox, uint8_t oy, uint8_t cx, uint8_t cy, uint8_t color) {
    uint8_t px0 = (uint8_t)(ox + cx * BLK), py0 = (uint8_t)(oy + cy * BLK);
    uint8_t i, j;
    for (j = 0u; j < BLK; j++)
        for (i = 0u; i < BLK; i++)
            canvas_plot(cv, (int16_t)(px0 + i), (int16_t)(py0 + j), color);
}

// magnitude → 4-level colour
static inline uint8_t mag_col(int16_t v) {
    int16_t a = (int16_t)(v < 0 ? -v : v);
    if (a >= 96) return 3u;
    if (a >= 40) return 2u;
    if (a >= 12) return 1u;
    return 0u;
}

static void draw_split(App *a) {
    int16_t coeff[8][8];
    db_dct8x8(a->phase, coeff);
    uint8_t y, x;
    // left: source block (0..55 px), colour by sample magnitude
    for (y = 0u; y < 8u; y++)
        for (x = 0u; x < 8u; x++)
            fill_cell(&a->canvas, 4u, 4u, x, y, mag_col(db_src(x, y, a->phase)));
    // right: DCT coefficient heat grid (72..127 px), colour by coeff magnitude
    for (y = 0u; y < 8u; y++)
        for (x = 0u; x < 8u; x++)
            fill_cell(&a->canvas, 72u, 4u, x, y, mag_col(coeff[y][x]));
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='S'; buf[10]='R'; buf[11]='C'; buf[12]=0x7Cu; buf[13]='D'; buf[14]='C'; buf[15]='T';
    buf[16]=' '; buf[17]=' '; buf[18]=' '; buf[19]=' '; buf[20]='\0';
    text_puts(&a->text, 1, 0, buf);
}

static void app_init(App *a) {
    display_init(&a->screen);
    canvas_init(&a->canvas, CANVAS_CHR, CANVAS_MAP, BOX_COL, BOX_ROW);
    text_init(&a->text, CANVAS_MAP, HUD_TOP_ROW, HUD_BOT_ROW);
    display_add(&a->screen, (Drawable *)&a->canvas);
    display_add(&a->screen, (Drawable *)&a->text);
    upq_push_cgram(&a->screen.q, 0, bg3_pal, 0x00u, (uint8_t)sizeof bg3_pal);
    a->phase = 0;
    a->frame = 0u;
    text_puts(&a->text, 0, 3, "DCT BLOOM 8X8 MAC");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "DCT BLOOM", "INT COSINE MAC");
    corpus_result = dctbloom_gate_crc();   // expected 0x5364
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        a.phase = (int16_t)(a.phase + 3);
        draw_split(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
