// VBlank Interrupt Tally — #123 of the compiler stress-test battery (Round 7).
// First C interrupt handler in the battery. The ISR performs native-width 16/32-bit work while
// main keeps unrelated values live; an armed/done handshake makes the differential exact.
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/nmitally.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u
#define WIN_W 16u
#define WIN_H 16u

typedef struct {
    Display screen;
    BitmapCanvas canvas;
    TextLayer text;
    uint16_t t;
} App;

volatile uint16_t corpus_result;
static volatile uint16_t irq_tally;
static volatile uint32_t irq_wide;
static volatile uint8_t irq_armed;
static volatile uint8_t irq_done;
static volatile uint16_t main_live16;
static volatile uint32_t main_live32;

void nmi(void) __attribute__((interrupt, noinline));
void nmi(void) {
    if (irq_armed) {
        uint16_t next = (uint16_t)(irq_tally + 1u);
        irq_tally = next;
        irq_wide = nmitally_step32(irq_wide, next);
        if (next == (uint16_t)NMITALLY_FRAMES) {
            irq_armed = 0u;             // publication barrier: no later NMI mutates the snapshot
            irq_done = 1u;
        }
    }
}

static const uint16_t pal[4] = {
    SNES_RGB(1, 2, 7), SNES_RGB(3, 13, 25), SNES_RGB(5, 25, 18), SNES_RGB(29, 29, 12)
};

static void update_hud(App *a) {
    static const char H[] = "0123456789ABCDEF";
    char b[21];
    b[0]='N'; b[1]='='; b[2]=H[(irq_tally>>8)&15u]; b[3]=H[(irq_tally>>4)&15u];
    b[4]=H[irq_tally&15u]; b[5]=' '; b[6]='C'; b[7]='R'; b[8]='C'; b[9]='=';
    b[10]=H[(corpus_result>>12)&15u]; b[11]=H[(corpus_result>>8)&15u];
    b[12]=H[(corpus_result>>4)&15u]; b[13]=H[corpus_result&15u];
    b[14]=' '; b[15]=' '; b[16]=' '; b[17]=' '; b[18]=' '; b[19]=' '; b[20]='\0';
    text_puts(&a->text, 1, 0, b);
}

static void paint(App *a) {
    uint8_t sweep = (uint8_t)((a->t >> 1) & 15u);
    for (uint8_t y=0u; y<(uint8_t)WIN_H; y++)
        for (uint8_t x=0u; x<(uint8_t)WIN_W; x++) {
            /* Oscilloscope-like VBlank pulse train: each column is one interrupt slot, the
               travelling yellow edge makes the periodic entry into C visible. */
            uint8_t pulse = (uint8_t)((x & 3u) == 0u);
            uint8_t trace_y = (uint8_t)(pulse ? 4u : 11u);
            uint8_t c = (uint8_t)((y == trace_y || (pulse && y >= 4u && y <= 11u)) ? 2u : 0u);
            if (x == sweep) c = (uint8_t)(c ? 3u : 1u);
            canvas_fill_solid_tile(&a->canvas, x, y, c);
        }
    a->canvas.lo = 0u;
    a->canvas.hi = (uint16_t)(CANVAS_NTILES - 1u);
}

static uint16_t run_gate(void) {
    irq_tally = 0u;
    irq_wide = (uint32_t)0x13579BDFu;
    irq_done = 0u;
    irq_armed = 1u;
    uint16_t live16 = (uint16_t)0xA55Au;
    uint32_t live32 = (uint32_t)0xC001D00Du;
    while (!irq_done) {                   // native arithmetic gives NMIs long M=0 landing windows
        live16 = (uint16_t)((live16 << 1) ^ (live16 >> 3) ^ (uint16_t)0x1021u);
        live32 = (uint32_t)((live32 << 3) ^ (live32 >> 5) ^ (uint32_t)live16);
        main_live16 = live16;
        main_live32 = live32;
    }
    uint16_t h = (uint16_t)0x4E4Du;
    uint16_t tally = irq_tally;
    uint32_t wide = irq_wide;
    h=nmitally_fold(h,(uint8_t)tally); h=nmitally_fold(h,(uint8_t)(tally>>8));
    h=nmitally_fold(h,(uint8_t)wide); h=nmitally_fold(h,(uint8_t)(wide>>8));
    h=nmitally_fold(h,(uint8_t)(wide>>16)); h=nmitally_fold(h,(uint8_t)(wide>>24));
    return h;
}

int main(void) {
    static App a;
    display_init(&a.screen);
    canvas_init(&a.canvas, CANVAS_CHR, CANVAS_MAP, 8, 6);
    text_init(&a.text, CANVAS_MAP, 1, 25);
    display_add(&a.screen, (Drawable *)&a.canvas);
    display_add(&a.screen, (Drawable *)&a.text);
    upq_push_cgram(&a.screen.q, 0, pal, 0, (uint8_t)sizeof pal);
    text_puts(&a.text, 0, 2, "VBLANK INTERRUPT TALLY");
    static TitleLayer title;
    title_begin16(&a.screen, &title, "NMITALLY", "INTERRUPT WIDTH CONTRACT");
    title_end(&a.screen, &title, 30);
    corpus_result = run_gate();
    for (;;) {
        paint(&a); update_hud(&a); a.t++;
        display_frame(&a.screen);
    }
}
