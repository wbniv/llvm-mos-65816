// LZSS Mode 7 Gallery — demo #119.
// mos-a16-only
// snes-gallery-platform
#include <snes.h>
#include "mode7.h"
#include "snesgfx/m7title.h"
#include "font8.h"
#include "font16.h"
#include "sincos.h"
#include "../65816/lzss.h"
#include "lzss-gallery-assets.h"

#define FAR __attribute__((address_space(2)))
#define FB_A ((FAR uint8_t*)0x7E2000u)
#define PACK ((FAR uint8_t*)0x7E6000u)
#define FB_B ((FAR uint8_t*)0x7EA800u)
#define HEAD ((FAR uint16_t*)0x7EE800u)
#define PREV ((FAR uint16_t*)0x7F0000u)
#define PACK_CAP 18144u
#define MAP2 0x4000u
#define MAP3 0x4400u
#define CHR16 0x5000u
#define CHR8 0x6000u
#define PAL16 7u
#define PAL8 7u
/* Leave OBJ range/time headroom for both 16x16 navigation sprites. */
#define OAM_VISUAL_MAX 16u
#define ARROW_TAKEOFF ((int16_t)-0x00c0)
#define ARROW_GRAVITY ((int16_t)0x0010)
enum {
  ARROW_L_REST=64, ARROW_R_REST=66,
  ARROW_L_RISE=68, ARROW_R_RISE=70,
  ARROW_L_APEX=72, ARROW_R_APEX=74,
  ARROW_L_FALL=76, ARROW_R_FALL=78,
  ARROW_L_LAND=96, ARROW_R_LAND=98,
  TRACK_ZIP_UP=128, TRACK_ZIP_DOWN=129, TRACK_ZIP_HEAD=130,
  TRACK_LITERAL=131
};
#ifndef GALLERY_START
#define GALLERY_START 0u
#endif
#ifndef GALLERY_RUN_COLOR
/* biohack.net gallery-specific neon cyan. */
#define GALLERY_RUN_COLOR SNES_RGB(8,31,30)
#endif
#ifndef GALLERY_VISUAL
#define GALLERY_VISUAL 1
#endif

volatile uint16_t corpus_result;
volatile uint8_t gallery_progress;
volatile uint16_t gallery_unpack_frames[GALLERY_ASSET_COUNT];
volatile uint16_t gallery_repack_frames[GALLERY_ASSET_COUNT];
volatile uint16_t gallery_verify_frames[GALLERY_ASSET_COUNT];
volatile uint8_t gallery_clock_lo, gallery_clock_hi;
volatile uint8_t nav_pad_now,nav_pad_previous,nav_request,nav_cancel;
volatile uint8_t gallery_current_asset;
volatile uint16_t gallery_canceled;
volatile uint16_t gallery_last_z;
volatile uint8_t gallery_last_work,gallery_last_ok;
volatile uint8_t arrow_anim,arrow_anim_y,arrow_pose,arrow_previous_direction;
volatile uint8_t arrow_direction;
volatile int16_t arrow_position,arrow_velocity;
static uint16_t gallery_z[GALLERY_ASSET_COUNT];
static uint8_t gallery_done[GALLERY_ASSET_COUNT];
static uint8_t gallery_failed[GALLERY_ASSET_COUNT];
static uint8_t gallery_completed_count;
static uint8_t chrbuf[1216];
static uint8_t objpix[256];
static uint16_t objchr[64];
static uint8_t oam_visual[OAM_VISUAL_MAX*4u];
static uint8_t bgmode_tab[7], tm_tab[7];
static const uint8_t zero=0;
static const GalleryAsset *active_asset;
enum { REPACK_NONE=0,REPACK_LITERAL=1,REPACK_MATCH=2,REPACK_CANCELED=3 };
typedef struct {
  uint16_t sequence,current_offset,source_offset,raw_done,packed_done;
  uint16_t literals,matches,distance;
  uint8_t kind,value,length,copy_progress;
} RepackVisual;
volatile RepackVisual gallery_repack_visual;
static uint8_t token_kind[12],token_len[12],token_count;
static uint8_t flight_active,flight_phase;
static uint16_t flight_source,flight_destination;

asm(".text\n"
    ".global nmi\n"
    "nmi:\n"
    "  php\n"
    /*
     * Save the complete 16-bit accumulator before entering the 8-bit I/O
     * sequence.  Saving after SEP discarded B whenever NMI interrupted the
     * compressor, producing nondeterministic corpus results.
     */
    "  .byte $c2, $20\n"
    "  pha\n"
    "  .byte $e2, $20\n"
    "  inc gallery_clock_lo\n"
    "  bne 1f\n"
    "  inc gallery_clock_hi\n"
    "1:\n"
    "  lda #$01\n"
    "  sta $4016\n"
    "  lda #$00\n"
    "  sta $4016\n"
    "  sta nav_pad_now\n"
    "  .rept 8\n"
    "  asl nav_pad_now\n"
    "  lda $4016\n"
    "  and #$01\n"
    "  ora nav_pad_now\n"
    "  sta nav_pad_now\n"
    "  .endr\n"
    "  lda nav_pad_now\n"
    "  and #$03\n"
    "  sta nav_pad_now\n"
    "  lda nav_pad_previous\n"
    "  eor #$ff\n"
    "  and nav_pad_now\n"
    "  beq 2f\n"
    "  sta nav_request\n"
    "  lda #$01\n"
    "  sta nav_cancel\n"
    "2:\n"
    "  lda nav_pad_now\n"
    "  sta nav_pad_previous\n"
    /*
     * Restore a deselected direction before animating the newly accepted one.
     * All OAM writes remain inside NMI/VBlank.
     */
    "  lda arrow_previous_direction\n"
    "  beq 3f\n"
    "  cmp arrow_direction\n"
    "  beq 2f\n"
    "  cmp #$02\n"
    "  beq 10f\n"
    "  lda #$02\n"              /* right entry */
    "  sta $2102\n"
    "  lda #$00\n"
    "  sta $2103\n"
    "  lda #$ee\n"
    "  sta $2104\n"
    "  lda arrow_anim_y\n"
    "  sta $2104\n"
    "  lda #$42\n"              /* dedicated right rest tile */
    "  sta $2104\n"
    "  lda #$30\n"
    "  sta $2104\n"
    "  clv\n"
    "  bvc 2f\n"
    "10:\n"
    "  lda #$00\n"              /* left entry */
    "  sta $2102\n"
    "  sta $2103\n"
    "  lda #$02\n"
    "  sta $2104\n"
    "  lda arrow_anim_y\n"
    "  sta $2104\n"
    "  lda #$40\n"
    "  sta $2104\n"
    "  lda #$30\n"
    "  sta $2104\n"
    "2:\n"
    "  lda #$00\n"
    "  sta arrow_previous_direction\n"
    "3:\n"
    "  lda arrow_anim\n"
    "  bne 16f\n"
    "  jmp 9f\n"
    "16:\n"
    /*
     * Signed 8.8 ballistic step: position += velocity; velocity += 1/16.
     * Down is positive. Landing clamps to zero and supplies a new -0.75
     * px/frame upward impulse instead of reflecting accumulated velocity.
     */
    "  .byte $c2, $20\n"
    "  lda arrow_position\n"
    "  clc\n"
    "  adc arrow_velocity\n"
    "  sta arrow_position\n"
    "  lda arrow_velocity\n"
    "  clc\n"
    "  .byte $69, $10, $00\n"   /* adc #$0010 in 16-bit accumulator mode */
    "  sta arrow_velocity\n"
    "  lda arrow_position\n"
    "  bmi 4f\n"
    "  .byte $a9, $00, $00\n"   /* lda #$0000 */
    "  sta arrow_position\n"
    "  .byte $a9, $40, $ff\n"   /* lda #$ff40 */
    "  sta arrow_velocity\n"
    "  .byte $e2, $20\n"
    "  lda arrow_direction\n"
    "  cmp #$02\n"
    "  beq 11f\n"
    "  lda #$62\n"              /* right landing-compression pose */
    "  clv\n"
    "  bvc 8f\n"
    "11:\n"
    "  lda #$60\n"              /* left landing-compression pose */
    "  clv\n"
    "  bvc 8f\n"
    "4:\n"
    "  .byte $e2, $20\n"
    "  lda arrow_position+1\n"
    "  cmp #$fe\n"              /* upper half of the 4.5px arc */
    "  bcc 5f\n"
    "  lda arrow_velocity+1\n"
    "  bmi 6f\n"
    "  lda arrow_direction\n"
    "  cmp #$02\n"
    "  beq 12f\n"
    "  lda #$4e\n"              /* right falling pose */
    "  clv\n"
    "  bvc 8f\n"
    "12:\n"
    "  lda #$4c\n"              /* left falling pose */
    "  clv\n"
    "  bvc 8f\n"
    "6:\n"
    "  lda arrow_direction\n"
    "  cmp #$02\n"
    "  beq 13f\n"
    "  lda #$46\n"              /* right rising pose */
    "  clv\n"
    "  bvc 8f\n"
    "13:\n"
    "  lda #$44\n"              /* left rising pose */
    "  clv\n"
    "  bvc 8f\n"
    "5:\n"
    "  lda arrow_direction\n"
    "  cmp #$02\n"
    "  beq 14f\n"
    "  lda #$4a\n"              /* right apex pose */
    "  clv\n"
    "  bvc 8f\n"
    "14:\n"
    "  lda #$48\n"              /* left apex pose */
    "8:\n"
    "  sta arrow_pose\n"
    "  lda arrow_direction\n"
    "  cmp #$02\n"
    "  beq 7f\n"
    "  lda #$02\n"
    "  sta $2102\n"
    "  lda #$00\n"
    "  sta $2103\n"
    "  lda #$ee\n"
    "  sta $2104\n"
    "  clv\n"
    "  bvc 15f\n"
    "7:\n"
    "  lda #$00\n"
    "  sta $2102\n"
    "  sta $2103\n"
    "  lda #$02\n"
    "  sta $2104\n"
    "15:\n"
    "  lda arrow_anim_y\n"
    "  clc\n"
    "  adc arrow_position+1\n"
    "  sta $2104\n"
    "  lda arrow_pose\n"
    "  sta $2104\n"
    "  lda #$30\n"              /* no horizontal flip; dedicated direction art */
    "  sta $2104\n"
    "9:\n"
    "  .byte $c2, $20\n"
    "  pla\n"
    "  plp\n"
    "  rti\n");

static uint16_t clock_read(void){
  uint8_t a,b,lo;
  do{a=gallery_clock_hi;lo=gallery_clock_lo;b=gallery_clock_hi;}while(a!=b);
  return (uint16_t)(((uint16_t)a<<8)|lo);
}

static uint16_t fold_far(const FAR uint8_t *p,uint16_t n){
  uint16_t h=0xffff;while(n--)h=lzss_fold(h,*p++);return h;
}

__attribute__((optnone,noinline))
static uint16_t decode_far(const FAR uint8_t *src,uint16_t slen,FAR uint8_t *dst,uint16_t want){
  uint16_t sp=0,dp=0;
  while(sp<slen&&dp<want){
    if(nav_cancel)return 0;
    uint8_t flags=src[sp++];
    for(uint8_t bit=0;bit<8&&dp<want;bit++){
      if(flags&(uint8_t)(1u<<bit)){
        if((uint16_t)(sp+2u)>slen)return 0;
        uint8_t a=src[sp++],b=src[sp++];
        uint16_t dist=(uint16_t)(a|((uint16_t)(b>>4)<<8));
        uint8_t n=(uint8_t)((b&15u)+3u);
        if(!dist||dist>dp)return 0;
        while(n--&&dp<want){if(nav_cancel)return 0;dst[dp]=dst[(uint16_t)(dp-dist)];dp++;}
      }else{if(sp>=slen)return 0;dst[dp++]=src[sp++];}
    }
  }
  return dp==want?dp:0;
}

static uint8_t hash_far(const FAR uint8_t *p,uint16_t pos,uint16_t len){
  if((uint16_t)(pos+2u)>=len)return 0;
  return (uint8_t)((uint8_t)(p[pos]*31u)^(uint8_t)(p[pos+1u]*17u)^p[pos+2u]);
}

static void progress_line(const char *phase,uint16_t done,uint16_t total);
static void oam_compression(void);
static uint8_t decimal(char*s,uint8_t n,uint16_t v);

static void repack_publish(uint8_t kind,uint16_t pos,uint16_t source,uint16_t raw,
                           uint16_t packed,const LzssStats *st,uint16_t distance,
                           uint8_t value,uint8_t length,uint8_t copied){
  gallery_repack_visual.kind=kind;
  gallery_repack_visual.current_offset=pos;
  gallery_repack_visual.source_offset=source;
  gallery_repack_visual.raw_done=raw;
  gallery_repack_visual.packed_done=packed;
  gallery_repack_visual.literals=st->literals;
  gallery_repack_visual.matches=st->matches;
  gallery_repack_visual.distance=distance;
  gallery_repack_visual.value=value;
  gallery_repack_visual.length=length;
  gallery_repack_visual.copy_progress=copied;
  gallery_repack_visual.sequence++;
}

__attribute__((optnone,noinline))
static uint16_t compress_far(const FAR uint8_t *src,uint16_t len,FAR uint8_t *dst,LzssStats *st){
  uint16_t pos=0,op=0;
  uint16_t next_meter=256;
  for(uint16_t i=0;i<256;i++)HEAD[i]=0xffff;
  st->literals=st->matches=st->longest=0;
  token_count=0;
  repack_publish(REPACK_NONE,0,0,0,0,st,0,0,0,0);
  while(pos<len){
    if(nav_cancel){repack_publish(REPACK_CANCELED,pos,0,pos,op,st,0,0,0,0);return 0;}
    if(op>=PACK_CAP)return 0;
    uint16_t flagpos=op++;uint8_t flags=0;
    for(uint8_t bit=0;bit<8&&pos<len;bit++){
      uint8_t hv=hash_far(src,pos,len);uint16_t p=HEAD[hv],best=0,distbest=0;uint8_t seen=0;
      while(p!=0xffff&&(uint16_t)(pos-p)<=4095u&&seen<64u){
        if(nav_cancel){repack_publish(REPACK_CANCELED,pos,0,pos,op,st,0,0,0,0);return 0;}
        uint16_t n=0;
        while(n<18u&&(uint16_t)(pos+n)<len&&src[p+n]==src[pos+n]){if(nav_cancel)return 0;n++;}
        uint16_t dist=(uint16_t)(pos-p);
        if(n>=3u&&(n>best||(n==best&&dist<distbest))){best=n;distbest=dist;}
        p=PREV[p&4095u];seen++;
      }
      uint16_t advance;
      if(best>=3u){
        if((uint16_t)(op+2u)>PACK_CAP)return 0;
        flags|=(uint8_t)(1u<<bit);dst[op++]=(uint8_t)distbest;
        dst[op++]=(uint8_t)(((distbest>>8)<<4)|(best-3u));
        advance=best;st->matches++;if(best>st->longest)st->longest=best;
        repack_publish(REPACK_MATCH,pos,(uint16_t)(pos-distbest),
                       (uint16_t)(pos+best),op,st,distbest,0,(uint8_t)best,(uint8_t)best);
      }else{
        if(op>=PACK_CAP)return 0;dst[op++]=src[pos];advance=1;st->literals++;
        repack_publish(REPACK_LITERAL,pos,pos,(uint16_t)(pos+1u),op,st,0,src[pos],1,1);
      }
      for(uint16_t n=0;n<advance;n++){
        if(nav_cancel){repack_publish(REPACK_CANCELED,pos,0,pos,op,st,0,0,0,0);return 0;}
        uint16_t q=(uint16_t)(pos+n);uint8_t h=hash_far(src,q,len);
        PREV[q&4095u]=HEAD[h];HEAD[h]=q;
      }
      pos=(uint16_t)(pos+advance);
    }
    dst[flagpos]=flags;
    if(pos>=next_meter){
      /*
       * Presentation consumes only the newest complete event.  Token history
       * advances here, not in the codec's byte-emission path.
       */
#if GALLERY_VISUAL
      for(uint8_t i=0;i<11;i++){token_kind[i]=token_kind[i+1u];token_len[i]=token_len[i+1u];}
      token_kind[11]=gallery_repack_visual.kind;token_len[11]=gallery_repack_visual.length;
      if(token_count<12u)token_count++;
      progress_line("REPACK",pos,len);oam_compression();
#endif
      next_meter=(uint16_t)(next_meter+256u);
    }
  }
#if GALLERY_VISUAL
  progress_line("REPACK",len,len);
#endif
  return op;
}

static void vram_clear(void){
  REG_VMAIN=VMAIN_INC_LOW_1;REG_VMADD=0;REG_DMAP0=0x08;REG_BBAD0=0x18;
  REG_A1T0L=(uint8_t)(uintptr_t)&zero;REG_A1T0H=(uint8_t)((uintptr_t)&zero>>8);REG_A1B0=0;
  REG_DAS0L=0;REG_DAS0H=0x80;REG_MDMAEN=1;
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=0;REG_BBAD0=0x19;
  REG_DAS0L=0;REG_DAS0H=0x80;REG_MDMAEN=1;
}
static void vram_words(uint16_t at,const uint16_t *p,uint16_t n){
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=at;while(n--)REG_VMDATA=*p++;
}
static void load_fonts(void){
  REG_BG2SC=SNES_BGSC(MAP2,0);REG_BG3SC=SNES_BGSC(MAP3,0);
  REG_BG12NBA=(uint8_t)(5u<<4);REG_BG34NBA=6u;
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=CHR16;
  for(uint16_t g=0;g<FONT16_N;g++)for(uint8_t tile=0;tile<4;tile++){
    for(uint8_t r=0;r<8;r++)REG_VMDATA=FONT16[g*32u+(uint16_t)tile*8u+r];
    for(uint8_t r=0;r<8;r++)REG_VMDATA=0;
  }
  vram_words(CHR8,FONT8,FONT8_N*8u);
  /* Keep a dedicated copy of the 8x8 T at tile 63.  Tile 52 is corrupted on
     the gallery's split BG3 path on hardware/core despite correct source data. */
  vram_words((uint16_t)(CHR8+63u*8u),FONT8+(uint16_t)('T'-FONT8_FIRST)*8u,8u);
}
static void pack_chevron_tiles(void){
  for(uint8_t ty=0;ty<2;ty++)for(uint8_t tx=0;tx<2;tx++)for(uint8_t y=0;y<8;y++){
    uint8_t p0=0,p1=0,p2=0,p3=0;
    for(uint8_t x=0;x<8;x++){
      uint8_t p=objpix[(uint16_t)(ty*8u+y)*16u+tx*8u+x],m=(uint8_t)(0x80u>>x);
      if(p&1u)p0|=m;if(p&2u)p1|=m;if(p&4u)p2|=m;if(p&8u)p3|=m;
    }
    uint16_t q=(uint16_t)(ty*2u+tx)*16u+y;
    objchr[q]=(uint16_t)(p0|((uint16_t)p1<<8));
    objchr[q+8u]=(uint16_t)(p2|((uint16_t)p3<<8));
  }
}
static void upload_chevron_pose(uint8_t base,uint8_t right,uint8_t pose){
  for(uint16_t i=0;i<256;i++)objpix[i]=0;
  uint8_t face=(uint8_t)(pose?4u:2u);
  /* Draw the lower-right extrusion first, then the face. */
  for(uint8_t y=2;y<14;y++){
    uint8_t d=(uint8_t)(y<8u?7u-y:y-8u),lx=(uint8_t)(3u+d);
    uint8_t x=(uint8_t)(right?(12u-d):lx),thick=(uint8_t)(pose==2u?3u:4u);
    uint8_t fy=y;
    if(pose==1u&&fy)fy--;
    else if(pose==3u&&fy<15u)fy++;
    else if(pose==4u){
      if(y==2u||y==13u)continue;
      fy=(uint8_t)(y<8u?y+1u:y-1u);
    }
    for(uint8_t n=0;n<thick;n++){
      uint8_t sx=(uint8_t)(x+n+1u),sy=(uint8_t)(y+1u);
      if(sx<16u&&sy<16u)objpix[(uint16_t)sy*16u+sx]=1u;
    }
    for(uint8_t n=0;n<thick;n++){
      uint8_t fx=(uint8_t)(x+n);
      if(fx<16u&&fy<16u)objpix[(uint16_t)fy*16u+fx]=face;
    }
  }
  /* Fixed upper-left light: one pale edge pixel per occupied row. */
  for(uint8_t y=0;y<16;y++)for(uint8_t x=0;x<16;x++){
    uint16_t at=(uint16_t)y*16u+x;
    if(objpix[at]==face){objpix[at]=5u;break;}
  }
  pack_chevron_tiles();
  for(uint8_t t=0;t<2;t++)vram_words((uint16_t)(0x6000u+(uint16_t)(base+t)*16u),objchr+(uint16_t)t*16u,16);
  for(uint8_t t=0;t<2;t++)vram_words((uint16_t)(0x6000u+(uint16_t)(base+16u+t)*16u),objchr+(uint16_t)(2u+t)*16u,16);
}
static void upload_tracker_tile(uint8_t tile,uint8_t shape,uint8_t color){
  for(uint8_t i=0;i<64;i++)objpix[i]=0;
  if(shape<2u){
    /* Bright opposing zipper teeth; never draw a closed edge or filled cell. */
    uint8_t y=(uint8_t)(shape?5u:2u),tip=(uint8_t)(shape?y-1u:y+1u);
    for(uint8_t x=1u;x<7u;x++)objpix[(uint16_t)y*8u+x]=(uint8_t)(x==3u||x==4u?5u:color);
    objpix[(uint16_t)tip*8u+3u]=color;objpix[(uint16_t)tip*8u+4u]=color;
  }else{
    static const uint8_t width[8]={0,2,4,6,6,4,2,0};
    for(uint8_t y=0;y<8;y++){
      uint8_t w=width[y],start=(uint8_t)((8u-w)/2u);
      for(uint8_t x=0;x<w;x++)objpix[(uint16_t)y*8u+start+x]=(uint8_t)(y==3u||y==4u?5u:color);
    }
  }
  for(uint8_t y=0;y<8;y++){
    uint8_t p0=0,p1=0,p2=0,p3=0;
    for(uint8_t x=0;x<8;x++){uint8_t p=objpix[(uint16_t)y*8u+x],m=(uint8_t)(0x80u>>x);
      if(p&1u)p0|=m;if(p&2u)p1|=m;if(p&4u)p2|=m;if(p&8u)p3|=m;}
    objchr[y]=(uint16_t)(p0|((uint16_t)p1<<8));objchr[8u+y]=(uint16_t)(p2|((uint16_t)p3<<8));
  }
  vram_words((uint16_t)(0x6000u+(uint16_t)tile*16u),objchr,16);
}
static void load_chevrons(void){
  upload_chevron_pose(ARROW_L_REST,0,0);upload_chevron_pose(ARROW_R_REST,1,0);
  upload_chevron_pose(ARROW_L_RISE,0,1);upload_chevron_pose(ARROW_R_RISE,1,1);
  upload_chevron_pose(ARROW_L_APEX,0,2);upload_chevron_pose(ARROW_R_APEX,1,2);
  upload_chevron_pose(ARROW_L_FALL,0,3);upload_chevron_pose(ARROW_R_FALL,1,3);
  upload_chevron_pose(ARROW_L_LAND,0,4);upload_chevron_pose(ARROW_R_LAND,1,4);
  upload_tracker_tile(TRACK_ZIP_UP,0,4);upload_tracker_tile(TRACK_ZIP_DOWN,1,4);
  upload_tracker_tile(TRACK_ZIP_HEAD,2,4);upload_tracker_tile(TRACK_LITERAL,2,4);
  REG_CGADD=128;REG_CGDATA=0;REG_CGDATA=0;
  uint16_t c=SNES_RGB(5,4,3);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(31,25,8);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  /* Palette-0 colors 4/5 are accent/white; 134..255 remain artwork-owned. */
  REG_CGADD=132;
  c=GALLERY_RUN_COLOR;REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(31,31,31);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  REG_OBSEL=3u;
}
static void oam_init(void){
  REG_OAMADDL=0;REG_OAMADDH=0;
  for(uint8_t i=0;i<128;i++){REG_OAMDATA=0;REG_OAMDATA=240;REG_OAMDATA=0;REG_OAMDATA=0;}
  REG_OAMADDL=0;REG_OAMADDH=1;for(uint8_t i=0;i<32;i++)REG_OAMDATA=0;
}
static void oam_arrow_sizes(void){
  REG_OAMADDL=0;REG_OAMADDH=1;
  REG_OAMDATA=0x0a;REG_OAMDATA=0;
}
static void oam_arrows(uint8_t y,uint8_t hide){
  if(hide)y=240;
  REG_OAMADDL=0;REG_OAMADDH=0;
  REG_OAMDATA=2;REG_OAMDATA=y;REG_OAMDATA=ARROW_L_REST;REG_OAMDATA=0x30;
  REG_OAMDATA=238;REG_OAMDATA=y;REG_OAMDATA=ARROW_R_REST;REG_OAMDATA=0x30;
  oam_arrow_sizes();
}
static void oam_upload_visual(void){
  snes_wait_vblank();
  REG_OAMADDL=4;REG_OAMADDH=0; /* sprite 2 = OAM word address 4 */
  REG_DMAP0=0;REG_BBAD0=0x04;
  REG_A1T0L=(uint8_t)(uintptr_t)oam_visual;
  REG_A1T0H=(uint8_t)((uintptr_t)oam_visual>>8);REG_A1B0=0;
  REG_DAS0L=(uint8_t)sizeof(oam_visual);REG_DAS0H=0;
  REG_MDMAEN=1;
}
static void oam_stage(uint8_t i,uint8_t x,uint8_t y,uint8_t tile){
  uint8_t *p=&oam_visual[(uint16_t)i*4u];
  p[0]=x;p[1]=y;p[2]=tile;p[3]=0x30;
}
static void oam_hide_compression(void){
  flight_active=0;
  for(uint8_t i=0;i<OAM_VISUAL_MAX;i++)oam_stage(i,0,240,TRACK_ZIP_UP);
  oam_upload_visual();
}
static void project_offset(uint16_t pos,uint8_t *x,uint8_t *y){
  uint16_t rw=((uint16_t)active_asset->width*256u)/active_asset->matrix_scale;
  uint16_t rh=((uint16_t)active_asset->height*256u)/active_asset->matrix_scale;
  uint8_t ox=(uint8_t)((256u-rw)/2u),oy=(uint8_t)((active_asset->display_height-rh)/2u);
  uint16_t px=(uint16_t)(pos%active_asset->width),py=(uint16_t)(pos/active_asset->width);
  *x=(uint8_t)(ox+(px*256u)/active_asset->matrix_scale);
  *y=(uint8_t)(oy+(py*256u)/active_asset->matrix_scale);
}
static uint8_t sprite_origin(int16_t v){
  if(v<3)return 0;
  if(v>250)return 247;
  return (uint8_t)(v-3);
}
static void oam_compression(void){
  if(!active_asset)return;
  uint16_t seq=gallery_repack_visual.sequence;
  RepackVisual v;
  v.current_offset=gallery_repack_visual.current_offset;
  v.source_offset=gallery_repack_visual.source_offset;
  v.kind=gallery_repack_visual.kind;v.length=gallery_repack_visual.length;
  if(seq!=gallery_repack_visual.sequence)return;
  if(flight_active&&flight_phase>=8u)flight_active=0;
  if(!flight_active&&v.kind==REPACK_MATCH){
    flight_active=1;flight_source=v.source_offset;flight_destination=v.current_offset;
    flight_phase=0;
  }
  uint8_t used=0;
  if(flight_active){
    uint8_t sx,sy,dx,dy;project_offset(flight_source,&sx,&sy);project_offset(flight_destination,&dx,&dy);
    uint8_t teeth=15u,reveal=(uint8_t)(flight_phase*2u+1u);
    if(reveal>teeth)reveal=teeth;
    uint8_t step=(uint8_t)((uint16_t)(reveal-1u)*31u/(teeth-1u));
    /*
     * Close a luminous zipper from source to destination. Fifteen alternating
     * teeth are enough to read as a seam without turning short byte runs into
     * boxes; successive presentation hooks reveal the teeth progressively.
     */
    if(sx!=dx||sy!=dy){
      for(uint8_t i=0;i<reveal;i++){
        uint8_t phase=(uint8_t)((uint16_t)i*31u/(teeth-1u));
        int16_t x=(int16_t)sx+((int16_t)dx-(int16_t)sx)*(int16_t)phase/31;
        int16_t y=(int16_t)sy+((int16_t)dy-(int16_t)sy)*(int16_t)phase/31;
        oam_stage(used++,sprite_origin(x),sprite_origin(y),
                  (uint8_t)(i&1u?TRACK_ZIP_DOWN:TRACK_ZIP_UP));
      }
      int16_t hx=(int16_t)sx+((int16_t)dx-(int16_t)sx)*(int16_t)step/31;
      int16_t hy=(int16_t)sy+((int16_t)dy-(int16_t)sy)*(int16_t)step/31;
      oam_stage(used++,sprite_origin(hx),sprite_origin(hy),TRACK_ZIP_HEAD);
    }
    flight_phase++;
  }else if(v.kind==REPACK_LITERAL){
    uint8_t x,y;project_offset(v.current_offset,&x,&y);
    oam_stage(0,sprite_origin(x),sprite_origin(y),TRACK_LITERAL);used=1;
  }
  while(used<OAM_VISUAL_MAX){oam_stage(used,0,240,TRACK_ZIP_UP);used++;}
  oam_upload_visual();
}
static void blank_maps(void){
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=MAP2;for(uint16_t i=0;i<1024;i++)REG_VMDATA=(uint16_t)(PAL16<<10);
  REG_VMADD=MAP3;for(uint16_t i=0;i<1024;i++)REG_VMDATA=(uint16_t)(PAL8<<10);
}
static uint8_t slen(const char*s,uint8_t max){uint8_t n=0;while(s&&*s++&&n<max)n++;return n;}
static void text16_at(uint8_t row,uint8_t col,const char*s){
  uint8_t n=slen(s,16);
  for(uint8_t i=0;i<n;i++){
    uint8_t g=(uint8_t)s[i]-FONT16_FIRST;uint16_t t=(uint16_t)(g*4u)|(uint16_t)(PAL16<<10);
    REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP2+(uint16_t)row*32u+col+i*2u);
    REG_VMDATA=t;REG_VMDATA=(uint16_t)(t+1u);
    REG_VMADD=(uint16_t)(MAP2+(uint16_t)(row+1u)*32u+col+i*2u);
    REG_VMDATA=(uint16_t)(t+2u);REG_VMDATA=(uint16_t)(t+3u);
  }
}
static void text16(uint8_t row,const char*s){
  uint8_t n=slen(s,16);text16_at(row,(uint8_t)(16u-n),s);
}
static void text8_at(uint8_t row,uint8_t col,const char*s){
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)row*32u+col);
  while(*s){uint8_t ch=(uint8_t)*s++;uint8_t tile=(uint8_t)(ch=='T'?63u:ch-FONT8_FIRST);
    REG_VMDATA=(uint16_t)(tile|(PAL8<<10));}
}
static void text8(uint8_t row,const char*s){
  uint8_t n=slen(s,30);text8_at(row,(uint8_t)((32u-n)/2u),s);
}
static void text8_replace(uint8_t row,char*s){
  uint8_t n=slen(s,30);while(n<30u)s[n++]=' ';s[30]=0;
  snes_wait_vblank();text8_at(row,1,s);
}
static uint8_t console_row(const GalleryAsset*a){
  /*
   * Three telemetry rows must finish at row 26.  The last metadata row is
   * deliberately reused while a benchmark is active; caption() restores it
   * for the next work.
   */
  uint8_t row=(uint8_t)(a->display_height/8u+2u+a->title_rows);
  return row>24u?24u:row;
}
static void artist_line(uint8_t row,const GalleryAsset*a){
  uint8_t nb=slen(a->artist_small_before,31),nl=slen(a->artist_large,16),na=slen(a->artist_small_after,31);
  uint16_t width=(uint16_t)nb*8u+(uint16_t)nl*16u+(uint16_t)na*8u;
  if(nb&&nl)width+=8u;if(na&&(nb||nl))width+=8u;
  uint8_t col=(uint8_t)((256u-width)/16u);
  if(nb){text8_at((uint8_t)(row+1u),col,a->artist_small_before);col=(uint8_t)(col+nb);}
  if(nb&&nl)col++;
  if(nl){text16_at(row,col,a->artist_large);col=(uint8_t)(col+nl*2u);}
  if(na){col++;text8_at((uint8_t)(row+1u),col,a->artist_small_after);}
}
static void caption(const GalleryAsset*a,const char*status){
  blank_maps();uint8_t row=(uint8_t)(a->display_height/8u);
  artist_line(row,a);row=(uint8_t)(row+2u);
  for(uint8_t i=0;i<a->title_rows;i++)text8((uint8_t)(row+i),a->title[i]);
  row=(uint8_t)(row+a->title_rows);text8(row,a->date);
  if(status)text8((uint8_t)(row+1u),status);
}
static void progress_line(const char *phase,uint16_t done,uint16_t total){
  char s[31];uint8_t n=0,is_repack=(uint8_t)(phase[0]=='R'&&phase[1]=='E');
  uint8_t row=console_row(active_asset);
  if(is_repack){
    uint16_t seq=gallery_repack_visual.sequence;
    RepackVisual v;
    v.current_offset=gallery_repack_visual.current_offset;v.raw_done=gallery_repack_visual.raw_done;
    v.packed_done=gallery_repack_visual.packed_done;v.literals=gallery_repack_visual.literals;
    v.matches=gallery_repack_visual.matches;v.distance=gallery_repack_visual.distance;
    v.kind=gallery_repack_visual.kind;v.value=gallery_repack_visual.value;
    v.length=gallery_repack_visual.length;v.copy_progress=gallery_repack_visual.copy_progress;
    if(seq!=gallery_repack_visual.sequence)return;
    const char*p="R ";while(*p)s[n++]=*p++;n=decimal(s,n,v.raw_done);s[n++]='/';n=decimal(s,n,total);
    p=" P";while(*p)s[n++]=*p++;n=decimal(s,n,v.packed_done);s[n++]=' ';
    if(!v.raw_done){p="--.-%";while(*p)s[n++]=*p++;}
    else{
      int16_t tenth=(int16_t)(((int32_t)v.raw_done-(int32_t)v.packed_done)*1000l/(int32_t)v.raw_done);
      s[n++]=tenth<0?'-':'+';if(tenth<0)tenth=(int16_t)-tenth;
      n=decimal(s,n,(uint16_t)(tenth/10));s[n++]='.';s[n++]=(char)('0'+tenth%10);s[n++]='%';
    }
    s[n]=0;text8_replace(row,s);n=0;
    if(v.kind==REPACK_MATCH){
      p="MATCH L";while(*p)s[n++]=*p++;n=decimal(s,n,v.length);p=" D";while(*p)s[n++]=*p++;
      n=decimal(s,n,v.distance);p=" COPY ";while(*p)s[n++]=*p++;n=decimal(s,n,v.copy_progress);
      s[n++]='/';n=decimal(s,n,v.length);
    }else{
      static const char hex[]="0123456789ABCDEF";
      p="LITERAL $";while(*p)s[n++]=*p++;s[n++]=hex[v.value>>4];s[n++]=hex[v.value&15u];
      p="  L ";while(*p)s[n++]=*p++;n=decimal(s,n,v.literals);p=" M ";while(*p)s[n++]=*p++;n=decimal(s,n,v.matches);
    }
    s[n]=0;text8_replace((uint8_t)(row+1u),s);n=0;p="TOK ";while(*p)s[n++]=*p++;
    uint8_t first=(uint8_t)(12u-token_count);
    for(uint8_t i=0;i<12u;i++){
      if(i<first)s[n++]='.';
      else{s[n++]=token_kind[i]==REPACK_MATCH?(token_len[i]>=12u?'M':'m'):'L';}
    }
    p="  L";while(*p)s[n++]=*p++;n=decimal(s,n,v.literals);p=" M";while(*p)s[n++]=*p++;n=decimal(s,n,v.matches);
    s[n]=0;text8_replace((uint8_t)(row+2u),s);
    return;
  }
  while(*phase&&n<8)s[n++]=*phase++;
  while(n<8)s[n++]=' ';s[n++]='[';
  uint8_t fill=(uint8_t)(((uint32_t)done*10u)/total);
  for(uint8_t i=0;i<10;i++)s[n++]=i<fill?'#':'.';
  s[n++]=']';s[n]=0;text8_replace(row,s);
  n=0;const char*q="CORPUS ";while(*q)s[n++]=*q++;
  n=decimal(s,n,gallery_completed_count);s[n++]='/';n=decimal(s,n,GALLERY_ASSET_COUNT);
  q=gallery_completed_count==GALLERY_ASSET_COUNT?" PASS":" RUNNING";while(*q)s[n++]=*q++;s[n]=0;
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)(row+2u)*32u);
  text8_replace((uint8_t)(row+2u),s);
}
static uint8_t decimal(char*s,uint8_t n,uint16_t v){
  char r[5];uint8_t k=0;do{r[k++]=(char)('0'+v%10u);v/=10u;}while(v&&k<5);
  while(k)s[n++]=r[--k];return n;
}
static void result_line(uint8_t ok,uint16_t unpack,uint16_t repack,uint16_t verify){
  char s[31];uint8_t n=0;
  uint8_t row=console_row(active_asset);const char*p=ok?"PASS DECODE ":"FAIL DECODE ";while(*p)s[n++]=*p++;
  n=decimal(s,n,unpack);s[n++]='F';s[n]=0;
  snes_wait_vblank();
  for(uint8_t line=0;line<3;line++){REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)(row+line)*32u);for(uint8_t i=0;i<32;i++)REG_VMDATA=0;}
  text8(row,s);n=0;p="REPACK ";while(*p)s[n++]=*p++;n=decimal(s,n,repack);
  p="F VERIFY ";while(*p)s[n++]=*p++;n=decimal(s,n,verify);s[n++]='F';s[n]=0;text8((uint8_t)(row+1u),s);
  n=0;p="CORPUS ";while(*p)s[n++]=*p++;n=decimal(s,n,gallery_completed_count);
  s[n++]='/';n=decimal(s,n,GALLERY_ASSET_COUNT);p=" COMPLETE";while(*p)s[n++]=*p++;s[n]=0;text8((uint8_t)(row+2u),s);
}
static void split_arm(uint8_t split){
  uint8_t rest=(uint8_t)(split-127u),bottom=(uint8_t)(224u-split);
  uint8_t a[7]={127,BGMODE_7,rest,BGMODE_7,bottom,BGMODE_1,0};
  uint8_t b[7]={127,(uint8_t)(TM_BG1|TM_OBJ),rest,(uint8_t)(TM_BG1|TM_OBJ),bottom,(uint8_t)(TM_BG2|TM_BG3|TM_OBJ),0};
  for(uint8_t i=0;i<7;i++){bgmode_tab[i]=a[i];tm_tab[i]=b[i];}
  REG_DMAP1=0;REG_BBAD1=0x05;REG_A1T1L=(uint8_t)(uintptr_t)bgmode_tab;REG_A1T1H=(uint8_t)((uintptr_t)bgmode_tab>>8);REG_A1B1=0;
  REG_DMAP2=0;REG_BBAD2=0x2c;REG_A1T2L=(uint8_t)(uintptr_t)tm_tab;REG_A1T2H=(uint8_t)((uintptr_t)tm_tab>>8);REG_A1B2=0;
  REG_HDMAEN=0x06;
}
static void palette(const GalleryAsset*a){
  REG_CGADD=0;for(uint16_t i=0;i<512u;i++)REG_CGDATA=a->pal[i];
  uint16_t c=0;
  REG_CGADD=28;REG_CGDATA=0;REG_CGDATA=0;
  c=SNES_RGB(31,25,8);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(5,4,3);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  REG_CGDATA=0;REG_CGDATA=0;
  REG_CGADD=(uint8_t)(PAL16*16u);REG_CGDATA=0;REG_CGDATA=0;
  c=SNES_RGB(31,25,8);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(5,4,3);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  REG_CGADD=128;REG_CGDATA=0;REG_CGDATA=0;
  c=SNES_RGB(5,4,3);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(31,25,8);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  /* Restore reserved OBJ colors after the artwork's full 256-color upload. */
  REG_CGADD=132;
  c=GALLERY_RUN_COLOR;REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(31,31,31);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
}
static uint8_t upload_image(const GalleryAsset*a){
  for(uint8_t ty=0;ty<a->tile_rows;ty++){
    if(nav_cancel)return 0;
    for(uint8_t tx=0;tx<a->tile_cols;tx++)for(uint8_t y=0;y<8;y++)for(uint8_t x=0;x<8;x++){
      uint16_t py=(uint16_t)ty*8u+y;
      uint16_t px=(uint16_t)tx*8u+x;
      chrbuf[(uint16_t)tx*64u+(uint16_t)y*8u+x]=(py<a->height&&px<a->width)?FB_A[py*a->width+px]:0;
    }
    uint16_t n=(uint16_t)a->tile_cols*64u;
    REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(64u+(uint16_t)ty*n);REG_DMAP0=0;REG_BBAD0=0x19;
    REG_A1T0L=(uint8_t)(uintptr_t)chrbuf;REG_A1T0H=(uint8_t)((uintptr_t)chrbuf>>8);REG_A1B0=0;
    REG_DAS0L=(uint8_t)n;REG_DAS0H=(uint8_t)(n>>8);REG_MDMAEN=1;
  }
  return 1;
}
static uint8_t exact_stream(const GalleryAsset*a,uint16_t n){
  if(n!=a->lz_len)return 0;for(uint16_t i=0;i<n;i++){if(nav_cancel)return 0;if(PACK[i]!=a->lz[i])return 0;}return 1;
}
static uint8_t hold(uint16_t n){while(n--){if(nav_cancel)return 0;snes_wait_vblank();}return 1;}

__attribute__((noinline))
static uint8_t unpack_slide(const GalleryAsset*a){
  return (uint8_t)(decode_far(a->lz,a->lz_len,FB_A,a->raw_len)!=0&&fold_far(FB_A,a->raw_len)==a->checksum);
}

__attribute__((noinline))
static uint8_t prepare_slide(const GalleryAsset*a){
  active_asset=a;REG_HDMAEN=0;REG_INIDISP=INIDISP_FORCE_BLANK;
  m7_set_matrix(a->matrix_scale,0,0,a->matrix_scale);
  m7_tilemap_clear(0,(uint16_t)(uintptr_t)&zero,M7_TILEMAP_WORDS);
  for(uint8_t ty=0;ty<a->tile_rows;ty++)for(uint8_t tx=0;tx<a->tile_cols;tx++)
    m7_tilemap_set((uint16_t)((uint16_t)ty*128u+tx),(uint8_t)(1u+ty*a->tile_cols+tx));
  uint16_t render_w=((uint16_t)a->width*256u)/a->matrix_scale;
  uint16_t render_h=((uint16_t)a->height*256u)/a->matrix_scale;
  m7_set_center(0,0);m7_set_scroll((int16_t)(-((int16_t)(256u-render_w)/2)),
                                  (int16_t)(-((int16_t)(a->display_height-render_h)/2)));
  if(!upload_image(a))return 0;
  palette(a);caption(a,0);
  arrow_anim=0;arrow_direction=0;arrow_previous_direction=0;arrow_pose=ARROW_L_REST;
  arrow_position=0;arrow_velocity=0;
  arrow_anim_y=(uint8_t)(a->display_height/2u-8u);
  oam_arrows(arrow_anim_y,0);
  if(nav_cancel)return 0;
  split_arm(a->display_height);REG_INIDISP=INIDISP_ON;
  gallery_current_asset=(uint8_t)(a-GALLERY_ASSETS);
  return 1;
}

__attribute__((noinline))
static uint16_t repack_slide(const GalleryAsset*a){
#if GALLERY_VISUAL
  progress_line("REPACK",0,a->raw_len);
#endif
  LzssStats st;uint16_t z=compress_far(FB_A,a->raw_len,PACK,&st);
#if GALLERY_VISUAL
  oam_hide_compression();
#endif
  return z;
}

__attribute__((noinline))
static uint8_t verify_stream(const GalleryAsset*a,uint16_t z){
  return (uint8_t)(z&&exact_stream(a,z));
}

__attribute__((noinline))
static uint8_t verify_decode(const GalleryAsset*a,uint16_t z){
  return (uint8_t)(decode_far(PACK,z,FB_B,a->raw_len)&&fold_far(FB_B,a->raw_len)==a->checksum);
}

__attribute__((noinline))
static uint8_t verify_bytes(const GalleryAsset*a){
  for(uint16_t i=0;i<a->raw_len;i++){
    if(nav_cancel)return 0;
    if(FB_A[i]!=FB_B[i])return 0;
    if((i&1023u)==1023u)progress_line("COMPARE",(uint16_t)(i+1u),a->raw_len);
  }
  return 1;
}

__attribute__((noinline))
static uint8_t verify_slide(const GalleryAsset*a,uint16_t z,uint8_t ok){
  ok=(uint8_t)(ok&&verify_stream(a,z));
  progress_line("COMPARE",0,a->raw_len);
  ok=(uint8_t)(ok&&verify_decode(a,z));
  if(ok)ok=verify_bytes(a);
  progress_line(ok?"VERIFIED":"FAILED",a->raw_len,a->raw_len);
  return ok;
}

__attribute__((noinline))
static uint16_t record_result(const GalleryAsset*a,uint8_t k,uint16_t z,uint16_t gate,uint8_t ok){
  gallery_last_z=z;gallery_last_work=k;gallery_last_ok=ok;
  if(!ok){REG_COLDATA=0x3f;gallery_failed[k]=1;}else gallery_failed[k]=0;
  gallery_z[k]=z;
  if(!gallery_done[k]){gallery_done[k]=1;gallery_completed_count++;}
  gallery_progress=gallery_completed_count;
  if(gallery_completed_count==GALLERY_ASSET_COUNT){
    uint8_t any_failed=0;
    for(uint8_t i=0;i<GALLERY_ASSET_COUNT;i++){
      any_failed|=gallery_failed[i];
    }
    /*
     * The host generator owns the canonical corpus oracle.  Reaching it still
     * requires every target-side exact-stream, second-decode, checksum, and
     * byte comparison to pass; bit 15 is inverted on any per-work failure.
     */
    gate=(uint16_t)(GALLERY_CORPUS_ORACLE^(any_failed?0x8000u:0u));
    corpus_result=gate;
  }
  return gate;
}

__attribute__((noinline))
static uint8_t spinout(void){
  snes_wait_vblank();if(!arrow_anim)oam_arrows(0,1);
  m7_set_center((uint16_t)(active_asset->width/2u),(uint16_t)(active_asset->height/2u));
  m7_set_scroll(0,0);
  for(uint8_t f=0;f<32;f++){if(nav_cancel)return 0;uint8_t angle=(uint8_t)(f*2u);int16_t co=SINCOS[(uint8_t)(angle+64u)];int16_t si=SINCOS[angle];
    m7_set_matrix((int16_t)(co>>2),(int16_t)(si>>2),(int16_t)(-si>>2),(int16_t)(co>>2));snes_wait_vblank();}
  return 1;
}

static uint8_t nav_target(uint8_t k){
  uint8_t r=nav_request;nav_request=0;nav_cancel=0;
  gallery_canceled++;
  if(r==1u){
    if(arrow_anim&&arrow_direction!=1u)arrow_previous_direction=arrow_direction;
    arrow_direction=1;arrow_position=0;arrow_velocity=ARROW_TAKEOFF;arrow_anim=1;
    arrow_anim_y=(uint8_t)(active_asset->display_height/2u-8u);
    return (uint8_t)(k+1u==GALLERY_ASSET_COUNT?0u:k+1u);
  }
  if(r==2u){
    if(arrow_anim&&arrow_direction!=2u)arrow_previous_direction=arrow_direction;
    arrow_direction=2;arrow_position=0;arrow_velocity=ARROW_TAKEOFF;arrow_anim=1;
    arrow_anim_y=(uint8_t)(active_asset->display_height/2u-8u);
    return (uint8_t)(k? k-1u:GALLERY_ASSET_COUNT-1u);
  }
  return k;
}

int main(void){
  /*
   * Decode the first work behind the fully visible title card.  m7splash_end()
   * finishes on force blank, so doing the expensive decode after it used to
   * leave the screen black for the entire first-image load.
   */
  gallery_clock_lo=gallery_clock_hi=0;
  nav_pad_now=nav_pad_previous=nav_request=nav_cancel=0;
  arrow_anim=arrow_direction=arrow_previous_direction=0;
  arrow_position=arrow_velocity=0;arrow_anim_y=0;arrow_pose=ARROW_L_REST;
  flight_active=0;
  snes_ppu_reset_blank();m7splash_begin("PACK UNPACK", "LZSS GALLERY");
  uint8_t k=GALLERY_START;
  const GalleryAsset*a=&GALLERY_ASSETS[k];
  uint16_t t=clock_read();uint8_t ok=unpack_slide(a);
  gallery_unpack_frames[k]=(uint16_t)(clock_read()-t);
  nav_request=0;nav_cancel=0;
  m7splash_end(0);
  /*
   * The title owns Mode 7, TM, scroll/centre latches, CGRAM, and NMI state.
   * VRAM clearing alone leaves those live during the first gallery setup,
   * which can expose a stale title/background plane for the first work only.
   * The decoded pixels are already in WRAM, so reset the complete PPU here
   * and rebuild every gallery-owned resource from a known force-blank state.
   */
  snes_ppu_reset_blank();
  vram_clear();load_fonts();load_chevrons();oam_init();m7_begin();
  m7_set_matrix(0x0080,0,0,0x0080);
  /*
   * These hot variables live in .zp.noinit. Initialize every NMI-consumed
   * field before enabling interrupts; otherwise the first VBlank can mistake
   * power-on residue for an active animation and write arbitrary OAM state.
   */
  gallery_clock_lo=gallery_clock_hi=0;
  nav_pad_now=nav_pad_previous=nav_request=nav_cancel=0;
  arrow_anim=arrow_direction=arrow_previous_direction=0;
  arrow_position=arrow_velocity=0;arrow_anim_y=0;arrow_pose=ARROW_L_REST;
  flight_active=0;
  REG_NMITIMEN=NMITIMEN_NMI;uint16_t gate=0xffff;uint8_t decoded=1;
  for(;;){
    a=&GALLERY_ASSETS[k];
    if(!decoded){
      /*
       * Keep the outgoing work at its normal scale while the next stream is
       * decoded.  Previously spinout ran first and left only a collapsed,
       * effectively black Mode 7 plane throughout this work.
       */
      t=clock_read();ok=unpack_slide(a);
      if(nav_cancel){k=nav_target(k);continue;}
      gallery_unpack_frames[k]=(uint16_t)(clock_read()-t);
      if(!spinout()){k=nav_target(k);continue;}
    }
    decoded=0;
    if(!prepare_slide(a)||!hold(60)){k=nav_target(k);continue;}
    t=clock_read();uint16_t z=repack_slide(a);
    if(nav_cancel){k=nav_target(k);continue;}
    gallery_repack_frames[k]=(uint16_t)(clock_read()-t);
    t=clock_read();
    ok=verify_slide(a,z,ok);
    if(nav_cancel){k=nav_target(k);continue;}
    gallery_verify_frames[k]=(uint16_t)(clock_read()-t);
    gate=record_result(a,k,z,gate,ok);
    result_line(ok,gallery_unpack_frames[k],gallery_repack_frames[k],gallery_verify_frames[k]);
    if(!hold(180)){k=nav_target(k);continue;}
    k=(uint8_t)(k+1u==GALLERY_ASSET_COUNT?0u:k+1u);
  }
}
