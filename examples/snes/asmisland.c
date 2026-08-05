// Inline-Asm Island — #125 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/asmisland.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u
typedef struct { Display screen; BitmapCanvas canvas; TextLayer text; uint16_t t; } App;
volatile uint16_t corpus_result;

static const uint16_t pal[4] = {
    SNES_RGB(1,2,7), SNES_RGB(7,20,27), SNES_RGB(26,8,18), SNES_RGB(30,27,10)
};

static void put_hex(TextLayer *t, uint16_t v) {
    static const char H[]="0123456789ABCDEF";
    char b[9]={'C','R','C','=',0,0,0,0,0};
    b[4]=H[(v>>12)&15u]; b[5]=H[(v>>8)&15u]; b[6]=H[(v>>4)&15u]; b[7]=H[v&15u];
    text_puts(t,1,1,b);
}

static void paint(App *a) {
    for (uint8_t y=0; y<16u; y++) for (uint8_t x=0; x<16u; x++) {
        uint8_t tick=(uint8_t)(a->t>>2);
        uint8_t island=(uint8_t)(x>=5u && x<=10u && y>=3u && y<=12u);
        uint8_t edge=(uint8_t)(island && (x==5u || x==10u || y==3u || y==12u));
        uint8_t c=edge ? 3u : (uint8_t)(island ? 2u : 0u);
        /* A live-value packet enters from the left, crosses the opaque island, and exits on the
           right. Its vertical lane changes inside the block to distinguish hidden asm state. */
        uint8_t packet=(uint8_t)(tick&15u);
        uint8_t lane=(uint8_t)((packet>=5u && packet<=10u) ? 8u : 7u);
        if (x==packet && y==lane) c=3u;
        if (!island && ((x + y + (uint8_t)(tick>>1)) & 7u)==0u) c=1u;
        canvas_fill_solid_tile(&a->canvas,x,y,c);
    }
    a->canvas.lo=0u;
    a->canvas.hi=(uint16_t)(CANVAS_NTILES-1u);
}

int main(void) {
    static App a;
    display_init(&a.screen);
    canvas_init(&a.canvas,CANVAS_CHR,CANVAS_MAP,8,6);
    text_init(&a.text,CANVAS_MAP,1,25);
    display_add(&a.screen,(Drawable *)&a.canvas);
    display_add(&a.screen,(Drawable *)&a.text);
    upq_push_cgram(&a.screen.q,0,pal,0,(uint8_t)sizeof pal);
    text_puts(&a.text,0,2,"INLINE ASM ISLAND");
    static TitleLayer title;
    title_begin16(&a.screen,&title,"ASMISLAND","OPAQUE M/X STATE");
    title_end(&a.screen,&title,30);
    corpus_result=asmisland_model();
    put_hex(&a.text,corpus_result);
    for (;;) { paint(&a); a.t++; display_frame(&a.screen); }
}
