// Bitboard Knight Tour — #120 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/bitboard64.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u

typedef struct {
    Display screen;
    BitmapCanvas canvas;
    TextLayer text;
    uint16_t round;
    uint16_t visual_h;
} App;

volatile uint16_t corpus_result;

static const uint16_t pal[4] = {
    SNES_RGB(1,2,6), SNES_RGB(4,9,17), SNES_RGB(4,25,27), SNES_RGB(31,26,7)
};

static void put_hex(TextLayer *t, uint16_t v) {
    static const char H[]="0123456789ABCDEF";
    char b[9]={'C','R','C','=',0,0,0,0,0};
    b[4]=H[(v>>12)&15u]; b[5]=H[(v>>8)&15u]; b[6]=H[(v>>4)&15u]; b[7]=H[v&15u];
    text_puts(t,1,1,b);
}

static void paint(App *a) {
    a->visual_h = bitboard64_step(a->visual_h, a->round++);
    for (uint8_t rank=0; rank<8u; rank++) for (uint8_t file=0; file<8u; file++) {
        uint8_t sq=(uint8_t)(rank*8u+file);
        uint64_t bit=bitboard64_onehot(sq);
        uint8_t c=(uint8_t)(((file^rank)&1u) ? 1u : 0u);
        if (bitboard64_state.visited & bit) c=1u;
        if (bitboard64_state.reachable & bit) c=2u;
        if (bitboard64_state.current & bit) c=3u;
        uint8_t tx=(uint8_t)(file*2u), ty=(uint8_t)(rank*2u);
        canvas_fill_solid_tile(&a->canvas,tx,ty,c);
        canvas_fill_solid_tile(&a->canvas,(uint8_t)(tx+1u),ty,c);
        canvas_fill_solid_tile(&a->canvas,tx,(uint8_t)(ty+1u),c);
        canvas_fill_solid_tile(&a->canvas,(uint8_t)(tx+1u),(uint8_t)(ty+1u),c);
    }
    a->canvas.lo=0u;
    a->canvas.hi=(uint16_t)(CANVAS_NTILES-1u);
}

int main(void) {
    static App a;
    static TitleLayer title;
    display_init(&a.screen);
    canvas_init(&a.canvas,CANVAS_CHR,CANVAS_MAP,8,6);
    text_init(&a.text,CANVAS_MAP,1,25);
    display_add(&a.screen,(Drawable *)&a.canvas);
    display_add(&a.screen,(Drawable *)&a.text);
    upq_push_cgram(&a.screen.q,0,pal,0,(uint8_t)sizeof pal);
    text_puts(&a.text,0,2,"BITBOARD KNIGHT TOUR");
    title_begin16(&a.screen,&title,"BITBOARD64","POP CLZ CTZ");
    title_end(&a.screen,&title,30);
    corpus_result=bitboard64_model();
    put_hex(&a.text,corpus_result);
    bitboard64_reset();
    a.visual_h=0xB120u;
    for (;;) { paint(&a); display_frame(&a.screen); }
}
