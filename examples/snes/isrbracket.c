// Mid-Bracket Interrupt Torture — #124 of the compiler stress-test battery (Round 7).
#include <snes.h>
#define CANVAS_FLUSH_TILES 256
#include "snesgfx/display.h"
#include "snesgfx/bitmap_canvas.h"
#include "snesgfx/text_layer.h"
#include "snesgfx/title_layer.h"
#include "../65816/isrbracket.h"

#define CANVAS_CHR 0x0000u
#define CANVAS_MAP 0x4000u
typedef struct{Display screen;BitmapCanvas canvas;TextLayer text;uint16_t t;}App;
volatile uint16_t corpus_result;
static volatile uint16_t irq_tally, mismatch_count, tunnel_seed, tunnel_last;
static volatile uint32_t irq_mix;
static volatile uint8_t irq_armed,irq_done;

void nmi(void) __attribute__((interrupt,noinline));
void nmi(void){
    if(irq_armed){
        uint16_t n=(uint16_t)(irq_tally+1u);irq_tally=n;irq_mix=isrbracket_irq_step(irq_mix,n);
        if(n==ISRBRACKET_FRAMES){irq_armed=0u;irq_done=1u;}
    }
}

/* Two calls with the same volatile seed must agree regardless of whether NMI lands inside one.
   The dense native-width chain provides long M=0 windows without making the golden timing-based. */
__attribute__((noinline)) static uint16_t tunnel(uint16_t x){
    for(uint8_t i=0;i<48u;i++){
        x=(uint16_t)(x+UINT16_C(0x9E37)+(uint16_t)i);
        x=(uint16_t)((x<<3)|(x>>13));
        x^=(uint16_t)(UINT16_C(0xA55A)+(uint16_t)(i*UINT16_C(0x0101)));
    }
    tunnel_last=x;return x;
}

static void paint(App*a);
static void progress_hud(App*a);
static uint16_t run_gate(App*a){
    irq_tally=0u;irq_mix=UINT32_C(0x1240A16F);mismatch_count=0u;irq_done=0u;irq_armed=1u;
    uint16_t seed=UINT16_C(0x5AA5),shown=UINT16_C(0xFFFF);
    while(!irq_done){
        tunnel_seed=seed;uint16_t first=tunnel(tunnel_seed);uint16_t second=tunnel(tunnel_seed);
        if(first!=second)mismatch_count++;seed=(uint16_t)(seed+UINT16_C(0x1021));
        uint16_t bucket=(uint16_t)(irq_tally>>4);
        if(bucket!=shown){shown=bucket;paint(a);progress_hud(a);display_frame(&a->screen);}
    }
    uint16_t h=UINT16_C(0xB124),n=irq_tally,e=mismatch_count;uint32_t m=irq_mix;
    h=isrbracket_fold(h,(uint8_t)n);h=isrbracket_fold(h,(uint8_t)(n>>8));
    h=isrbracket_fold(h,(uint8_t)m);h=isrbracket_fold(h,(uint8_t)(m>>8));
    h=isrbracket_fold(h,(uint8_t)(m>>16));h=isrbracket_fold(h,(uint8_t)(m>>24));
    h=isrbracket_fold(h,(uint8_t)e);h=isrbracket_fold(h,(uint8_t)(e>>8));return h;
}

static const uint16_t pal[4]={SNES_RGB(1,2,6),SNES_RGB(3,10,20),SNES_RGB(24,5,24),SNES_RGB(31,25,7)};
static void put_hex(TextLayer*t,uint16_t v){static const char H[]="0123456789ABCDEF";char b[24]={'C','R','C','=',0,0,0,0,' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',0};b[4]=H[(v>>12)&15u];b[5]=H[(v>>8)&15u];b[6]=H[(v>>4)&15u];b[7]=H[v&15u];text_puts(t,1,1,b);}
static void put_dec4(char*b,uint16_t v){b[3]=(char)('0'+v%10u);v/=10u;b[2]=(char)('0'+v%10u);v/=10u;b[1]=(char)('0'+v%10u);v/=10u;b[0]=(char)('0'+v%10u);}
static void progress_hud(App*a){char b[25]={'N','M','I',' ',0,0,0,0,'/','1','0','2','4',' ','E','R','R',' ',0,0,0,0,' ',' ',0};uint16_t n=irq_tally;if(n>ISRBRACKET_FRAMES)n=ISRBRACKET_FRAMES;put_dec4(&b[4],n);put_dec4(&b[18],mismatch_count);text_puts(&a->text,1,1,b);}
static void paint(App*a){
    uint8_t needle=(uint8_t)((a->t>>1)&15u),rail=(uint8_t)(tunnel_last&7u);
    for(uint8_t y=0;y<16u;y++)for(uint8_t x=0;x<16u;x++){
        uint8_t c=(uint8_t)(((x+y+(tunnel_last>>8))&3u)<2u?1u:2u);
        if(y==rail||y==(uint8_t)(13u-rail))c=2u;if(x==needle)c=3u;
        canvas_fill_solid_tile(&a->canvas,x,y,c);
    }
    uint8_t filled=(uint8_t)(irq_tally>>6);if(filled>16u)filled=16u;
    for(uint8_t x=0;x<16u;x++){canvas_fill_solid_tile(&a->canvas,x,14u,(uint8_t)(x<filled?3u:1u));canvas_fill_solid_tile(&a->canvas,x,15u,(uint8_t)(mismatch_count?3u:2u));}
    a->canvas.lo=0u;a->canvas.hi=(uint16_t)(CANVAS_NTILES-1u);a->t++;
}
int main(void){static App a;static TitleLayer title;display_init(&a.screen);canvas_init(&a.canvas,CANVAS_CHR,CANVAS_MAP,8,6);text_init(&a.text,CANVAS_MAP,1,25);display_add(&a.screen,(Drawable*)&a.canvas);display_add(&a.screen,(Drawable*)&a.text);upq_push_cgram(&a.screen.q,0,pal,0,(uint8_t)sizeof pal);text_puts(&a.text,0,2,"MID-BRACKET NMI TUNNEL");title_begin16(&a.screen,&title,"ISRBRACKET","NMI THROUGH A16 WINDOWS");title_end(&a.screen,&title,30);
    /* The deterministic gate deliberately occupies 1,024 VBlanks (~17 seconds). Publish a real
       tunnel frame and explicit status before arming it so this stress interval never looks hung. */
    tunnel_last=UINT16_C(0xA16A);paint(&a);text_puts(&a.text,1,1,"RUNNING 1024 NMI TORTURE");display_frame(&a.screen);
    corpus_result=run_gate(&a);put_hex(&a.text,corpus_result);for(;;){paint(&a);display_frame(&a.screen);}}
