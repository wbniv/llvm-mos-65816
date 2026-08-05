// Seismograph Absolute Trace — #121 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/llabs64.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u
typedef struct { Display screen; BitmapCanvas canvas; TextLayer text; uint16_t step, h; } App;
volatile uint16_t corpus_result;
static const uint16_t pal[4] = { SNES_RGB(1,2,5), SNES_RGB(3,9,17), SNES_RGB(3,27,26), SNES_RGB(31,24,7) };

static void put_hex(TextLayer *t, uint16_t v) {
    static const char H[] = "0123456789ABCDEF";
    char b[9] = {'C','R','C','=',0,0,0,0,0};
    b[4]=H[(v>>12)&15u]; b[5]=H[(v>>8)&15u]; b[6]=H[(v>>4)&15u]; b[7]=H[v&15u];
    text_puts(t,1,1,b);
}

static uint8_t amplitude(uint64_t v) {
    uint8_t n = 0;
    while (v > UINT64_C(0xFF) && n < 7u) { v >>= 8; n++; }
    return n;
}

static void paint(App *a) {
    a->h = llabs64_step(a->h, a->step);
    uint8_t x = (uint8_t)(a->step++ & 15u);
    uint8_t amp = amplitude((uint64_t)llabs64_idiom_out);
    uint8_t signed_y = llabs64_input < 0 ? (uint8_t)(8u + amp) : (uint8_t)(8u - amp);
    for (uint8_t y=0; y<16u; y++) canvas_fill_solid_tile(&a->canvas,x,y,(uint8_t)(y==8u ? 1u : 0u));
    canvas_fill_solid_tile(&a->canvas,x,signed_y,3u);
    canvas_fill_solid_tile(&a->canvas,x,(uint8_t)(7u-amp),2u);
    canvas_fill_solid_tile(&a->canvas,x,(uint8_t)(9u+amp),2u);
    if ((a->step & 15u) == 15u) canvas_fill_solid_tile(&a->canvas,x,0u,3u);
    a->canvas.lo=0u; a->canvas.hi=(uint16_t)(CANVAS_NTILES-1u);
}

int main(void) {
    static App a; static TitleLayer title;
    display_init(&a.screen); canvas_init(&a.canvas,CANVAS_CHR,CANVAS_MAP,8,6);
    text_init(&a.text,CANVAS_MAP,1,25); display_add(&a.screen,(Drawable*)&a.canvas);
    display_add(&a.screen,(Drawable*)&a.text); upq_push_cgram(&a.screen.q,0,pal,0,(uint8_t)sizeof pal);
    text_puts(&a.text,0,2,"SEISMOGRAPH ABS TRACE");
    title_begin16(&a.screen,&title,"LLABS64","SIGNED / RECTIFIED"); title_end(&a.screen,&title,30);
    corpus_result=llabs64_model(); put_hex(&a.text,corpus_result); a.h=UINT16_C(0x1217);
    for (;;) { paint(&a); display_frame(&a.screen); }
}
