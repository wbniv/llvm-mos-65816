// Limb-Seam Barrel — #138 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/shift64seam.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u
typedef struct { Display screen; BitmapCanvas canvas; TextLayer text; uint16_t step,h; } App;
volatile uint16_t corpus_result;
static const uint16_t pal[4]={SNES_RGB(1,2,6),SNES_RGB(3,9,17),SNES_RGB(4,25,27),SNES_RGB(31,25,7)};

static void put_hex(TextLayer*t,uint16_t v){static const char H[]="0123456789ABCDEF";char b[9]={'C','R','C','=',0,0,0,0,0};b[4]=H[(v>>12)&15u];b[5]=H[(v>>8)&15u];b[6]=H[(v>>4)&15u];b[7]=H[v&15u];text_puts(t,1,1,b);}

static void band(BitmapCanvas*c,uint8_t row,uint64_t value,uint8_t accent){
    for(uint8_t x=0;x<16u;x++){
        uint8_t nib=(uint8_t)(value&15u),color=(uint8_t)(nib?accent:0u);
        if(nib==15u)color=3u;
        for(uint8_t y=0;y<4u;y++)canvas_fill_solid_tile(c,x,(uint8_t)(row+y),color);
        value>>=4;
    }
    for(uint8_t x=0;x<16u;x++)canvas_fill_solid_tile(c,x,(uint8_t)(row+4u),0u);
}

static void paint(App*a){
    a->h=shift64seam_step(a->h,a->step++);
    band(&a->canvas,0u,shift64seam_left_out,2u);
    band(&a->canvas,5u,shift64seam_right_out,2u);
    band(&a->canvas,10u,(uint64_t)shift64seam_arith_out,1u);
    uint8_t mark=(uint8_t)(shift64seam_amount((uint16_t)(a->step-1u))>>2);
    for(uint8_t x=0;x<16u;x++)canvas_fill_solid_tile(&a->canvas,x,15u,(uint8_t)(x==mark?3u:1u));
    a->canvas.lo=0u;a->canvas.hi=(uint16_t)(CANVAS_NTILES-1u);
}

int main(void){static App a;static TitleLayer title;display_init(&a.screen);canvas_init(&a.canvas,CANVAS_CHR,CANVAS_MAP,8,6);text_init(&a.text,CANVAS_MAP,1,25);display_add(&a.screen,(Drawable*)&a.canvas);display_add(&a.screen,(Drawable*)&a.text);upq_push_cgram(&a.screen.q,0,pal,0,(uint8_t)sizeof pal);text_puts(&a.text,0,2,"64-BIT LIMB-SEAM BARREL");title_begin16(&a.screen,&title,"SHIFT64SEAM","15 16 17 / 31 32 33");title_end(&a.screen,&title,30);corpus_result=shift64seam_model();put_hex(&a.text,corpus_result);a.h=0x8138u;for(;;){paint(&a);display_frame(&a.screen);}}
