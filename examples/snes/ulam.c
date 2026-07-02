// Ulam Prime Sieve — #85 of the compiler stress-test demo battery.
// Sieve of Eratosthenes in a bit-array (variable-count G_SHL/G_LSHR via
// arr[i>>3] |= 1u<<(i&7)), rendered as an Ulam spiral on a 128x128 BG3 canvas.
// The primes form the famous diagonal clusters. Builds default-8-bit AND
// +mos-a16 AND +mos-xy16 (5-way bar, no far pointers).
//
// Distinct from #5 life (fixed 1<<k masks) and #28 hilbert (fixed bit twiddles):
// here the shift amount (i&7) is a RUNTIME value → variable-count shift codegen.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/ulam.h"

#define CANVAS_CHR   0x0000u
#define CANVAS_MAP   0x4000u
#define BOX_COL      8u
#define BOX_ROW      3u
#define HUD_TOP_ROW  1u
#define HUD_BOT_ROW  25u
#define NCOL         4u
#define SPIRAL_MAX   1024u    // steps to plot (fills ~32x32 around center)
#define CENTERX      64
#define CENTERY      64

static const uint16_t bg3_pal[NCOL] = {
    SNES_RGB( 1,  1,  3),    // 0: dark bg (composite / empty)
    SNES_RGB(30, 28, 10),    // 1: prime (gold)
    SNES_RGB( 6,  8, 16),    // 2: composite dot (dim)
    SNES_RGB(30, 30, 30),    // 3: current head
};

typedef struct {
    Display      screen;
    BitmapCanvas canvas;
    TextLayer    text;
    uint16_t     revealed;   // how many spiral steps drawn so far
    uint16_t     frame;
} App;

volatile uint16_t corpus_result;

// Incremental spiral walk state, redrawn each frame up to `revealed`.
static void draw_spiral(App *a) {
    canvas_clear(&a->canvas);
    int16_t px = 0, py = 0, dx = 1, dy = 0, seg = 1, step = 0, turns = 0;
    uint16_t k;
    for (k = 1u; k <= a->revealed && k < (uint16_t)SPIRAL_MAX; k++) {
        int16_t sx = (int16_t)(CENTERX + px);
        int16_t sy = (int16_t)(CENTERY + py);
        if ((uint16_t)sx < (uint16_t)CANVAS_W && (uint16_t)sy < (uint16_t)CANVAS_H) {
            if (ul_is_prime(k)) canvas_plot(&a->canvas, sx, sy, 1u);   // gold prime
        }
        // advance spiral (clockwise): (dx,dy) -> (dy,-dx) every seg steps, grow every 2 turns
        px = (int16_t)(px + dx); py = (int16_t)(py + dy);
        step++;
        if (step == seg) {
            step = 0;
            int16_t ndx = dy, ndy = (int16_t)(-dx);
            dx = ndx; dy = ndy;
            turns++;
            if ((turns & 1) == 0) seg++;
        }
    }
}

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char buf[21];
    buf[0]='C'; buf[1]='R'; buf[2]='C'; buf[3]='=';
    buf[4]=H[(corpus_result>>12)&0xFu]; buf[5]=H[(corpus_result>>8)&0xFu];
    buf[6]=H[(corpus_result>>4)&0xFu]; buf[7]=H[corpus_result&0xFu];
    buf[8]=' '; buf[9]='K'; buf[10]='=';
    buf[11]=H[(a->revealed>>12)&0xFu]; buf[12]=H[(a->revealed>>8)&0xFu];
    buf[13]=H[(a->revealed>>4)&0xFu]; buf[14]=H[a->revealed&0xFu];
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
    a->revealed = 0u;
    a->frame = 0u;
    text_puts(&a->text, 0, 4, "ULAM PRIME SIEVE");
}

int main(void) {
    static App a;
    app_init(&a);
    static TitleLayer title;
    title_begin16(&a.screen, &title, "BIT SIEVE", "ULAM SPIRAL");
    corpus_result = ulam_gate_crc();   // expected 0x1F2F; also fills ul_comp[]
    title_end(&a.screen, &title, 90);
    for (;;) {
        a.frame = (uint16_t)(a.frame + 1u);
        // reveal ~16 steps/frame until the full spiral is shown, then hold + restart
        if (a.revealed < (uint16_t)SPIRAL_MAX) a.revealed = (uint16_t)(a.revealed + 16u);
        else if ((a.frame & 127u) == 0u) a.revealed = 0u;
        draw_spiral(&a);
        update_hud(&a);
        display_frame(&a.screen);
    }
}
