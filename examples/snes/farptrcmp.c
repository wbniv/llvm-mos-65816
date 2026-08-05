#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/farptrcmp.h"
#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u
typedef struct{Display screen;BitmapCanvas canvas;TextLayer text;uint8_t phase;}App;volatile uint16_t corpus_result;static const uint16_t pal[4]={SNES_RGB(1,2,6),SNES_RGB(3,11,24),SNES_RGB(25,5,23),SNES_RGB(31,25,7)};
static void hx(TextLayer*t,uint16_t v){static const char H[]="0123456789ABCDEF";char b[9]={'C','R','C','=',0,0,0,0,0};b[4]=H[v>>12];b[5]=H[(v>>8)&15];b[6]=H[(v>>4)&15];b[7]=H[v&15];text_puts(t,1,1,b);}static void paint(App*a){for(uint8_t y=0;y<16;y++)for(uint8_t x=0;x<16;x++){uint8_t i=(uint8_t)(x>>1),bank=farptrcmp_order[i],c=0;if(y==(uint8_t)(2u+bank*4u))c=(uint8_t)(bank&1u?2u:1u);if(x==(a->phase&15u))c=3u;if(y>11u&&x<14u&&((farptrcmp_gaps[x>>1]>>(y-12u))&1u))c=2u;canvas_fill_solid_tile(&a->canvas,x,y,c);}a->canvas.lo=0;a->canvas.hi=CANVAS_NTILES-1;a->phase++;}
int main(void){static App a;static TitleLayer title;display_init(&a.screen);canvas_init(&a.canvas,CANVAS_CHR,CANVAS_MAP,8,6);text_init(&a.text,CANVAS_MAP,1,25);display_add(&a.screen,(Drawable*)&a.canvas);display_add(&a.screen,(Drawable*)&a.text);upq_push_cgram(&a.screen.q,0,pal,0,sizeof pal);text_puts(&a.text,0,2,"FAR POINTER ORDER SHUFFLE");title_begin16(&a.screen,&title,"FARPTRCMP","24-BIT SORT + DIFF");title_end(&a.screen,&title,30);corpus_result=farptrcmp_run();hx(&a.text,corpus_result);for(;;){paint(&a);display_frame(&a.screen);}}
