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
#ifndef GALLERY_START
#define GALLERY_START 0u
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
static uint16_t gallery_z[GALLERY_ASSET_COUNT];
static uint8_t gallery_done[GALLERY_ASSET_COUNT];
static uint8_t gallery_failed[GALLERY_ASSET_COUNT];
static uint8_t gallery_completed_count;
static uint8_t chrbuf[1216];
static uint8_t objpix[256];
static uint16_t objchr[64];
static uint8_t bgmode_tab[7], tm_tab[7];
static const uint8_t zero=0;
static const GalleryAsset *active_asset;
static uint8_t directed_load_status;
static uint16_t viz_pos,viz_dist,viz_out;
static uint8_t viz_len,viz_literal;
static uint8_t arrow_flash;

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
static void oam_compression(uint16_t pos,uint8_t len,uint8_t literal);
static uint8_t decimal(char*s,uint8_t n,uint16_t v);

__attribute__((optnone,noinline))
static uint16_t compress_far(const FAR uint8_t *src,uint16_t len,FAR uint8_t *dst,LzssStats *st){
  uint16_t pos=0,op=0;
  uint16_t next_meter=512;
  for(uint16_t i=0;i<256;i++)HEAD[i]=0xffff;
  st->literals=st->matches=st->longest=0;
  while(pos<len){
    if(nav_cancel)return 0;
    if(op>=PACK_CAP)return 0;
    uint16_t flagpos=op++;uint8_t flags=0;
    for(uint8_t bit=0;bit<8&&pos<len;bit++){
      uint8_t hv=hash_far(src,pos,len);uint16_t p=HEAD[hv],best=0,distbest=0;uint8_t seen=0;
      while(p!=0xffff&&(uint16_t)(pos-p)<=4095u&&seen<64u){
        if(nav_cancel)return 0;
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
        viz_pos=pos;viz_dist=distbest;viz_len=(uint8_t)best;viz_literal=0;
      }else{
        if(op>=PACK_CAP)return 0;dst[op++]=src[pos];advance=1;st->literals++;
        viz_pos=pos;viz_dist=0;viz_len=1;viz_literal=1;
      }
      for(uint16_t n=0;n<advance;n++){
        if(nav_cancel)return 0;
        uint16_t q=(uint16_t)(pos+n);uint8_t h=hash_far(src,q,len);
        PREV[q&4095u]=HEAD[h];HEAD[h]=q;
      }
      pos=(uint16_t)(pos+advance);
    }
    dst[flagpos]=flags;
    if(pos>=next_meter){
      viz_out=op;oam_compression(viz_pos,viz_len,viz_literal);
      progress_line("REPACK",pos,len);next_meter=(uint16_t)(next_meter+512u);
    }
  }
  progress_line("REPACK",len,len);
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
static void load_chevrons(void){
  for(uint16_t i=0;i<256;i++)objpix[i]=0;
  for(uint8_t y=0;y<16;y++){
    uint8_t x=(uint8_t)(4u+(y<8u?7u-y:y-8u));
    if(y&&x<13u)for(uint8_t n=0;n<3;n++)objpix[(uint16_t)y*16u+x+n+1u]=1;
    for(uint8_t n=0;n<3;n++)objpix[(uint16_t)y*16u+x+n]=2;
  }
  for(uint8_t ty=0;ty<2;ty++)for(uint8_t tx=0;tx<2;tx++)for(uint8_t y=0;y<8;y++){
    uint8_t p0=0,p1=0;
    for(uint8_t x=0;x<8;x++){uint8_t p=objpix[(uint16_t)(ty*8u+y)*16u+tx*8u+x];
      if(p&1u)p0|=(uint8_t)(0x80u>>x);if(p&2u)p1|=(uint8_t)(0x80u>>x);}
    objchr[(uint16_t)(ty*2u+tx)*16u+y]=(uint16_t)(p0|((uint16_t)p1<<8));
    objchr[(uint16_t)(ty*2u+tx)*16u+8u+y]=0;
  }
  vram_words(0x6400u,objchr,32);
  vram_words(0x6500u,objchr+32,32);
  /* 8x8 compression outline: cyan box used as single/cap/span sprites. */
  for(uint8_t y=0;y<8;y++){
    uint8_t p=(uint8_t)((y==0u||y==7u)?0xffu:0x81u);
    objchr[y]=(uint16_t)p;objchr[8u+y]=0;
  }
  vram_words(0x6480u,objchr,16);
  REG_CGADD=128;REG_CGDATA=0;REG_CGDATA=0;
  uint16_t c=SNES_RGB(5,4,3);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(31,25,8);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  /* Compression sprites use OBJ palette 1 (attribute bits ppp=001). */
  REG_CGADD=144;REG_CGDATA=0;REG_CGDATA=0;
  c=SNES_RGB(8,31,30);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(31,31,31);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  REG_OBSEL=3u;
}
static void oam_init(void){
  REG_OAMADDL=0;REG_OAMADDH=0;
  for(uint8_t i=0;i<128;i++){REG_OAMDATA=0;REG_OAMDATA=240;REG_OAMDATA=0;REG_OAMDATA=0;}
  REG_OAMADDL=0;REG_OAMADDH=1;for(uint8_t i=0;i<32;i++)REG_OAMDATA=0;
}
static void oam_arrows(uint8_t y,uint8_t hide){
  if(hide)y=240;
  REG_OAMADDL=0;REG_OAMADDH=0;
  REG_OAMDATA=(uint8_t)(arrow_flash==2u?0u:2u);REG_OAMDATA=y;REG_OAMDATA=64;REG_OAMDATA=(uint8_t)(0x30u|(arrow_flash==2u?2u:0u));
  REG_OAMDATA=(uint8_t)(arrow_flash==1u?240u:238u);REG_OAMDATA=y;REG_OAMDATA=64;REG_OAMDATA=(uint8_t)(0x70u|(arrow_flash==1u?2u:0u));
  REG_OAMADDL=0;REG_OAMADDH=1;REG_OAMDATA=0x0a;
}
static void oam_hide_compression(void){
  REG_OAMADDL=8;REG_OAMADDH=0;
  for(uint8_t i=0;i<6;i++){REG_OAMDATA=0;REG_OAMDATA=240;REG_OAMDATA=72;REG_OAMDATA=0x32;}
}
static void oam_compression(uint16_t pos,uint8_t len,uint8_t literal){
  if(!active_asset)return;
  uint16_t rw=((uint16_t)active_asset->width*256u)/active_asset->matrix_scale;
  uint16_t rh=((uint16_t)active_asset->height*256u)/active_asset->matrix_scale;
  uint8_t ox=(uint8_t)((256u-rw)/2u),oy=(uint8_t)((active_asset->display_height-rh)/2u);
  uint16_t px=(uint16_t)(pos%active_asset->width),py=(uint16_t)(pos/active_asset->width);
  uint8_t x=(uint8_t)(ox+(px*256u)/active_asset->matrix_scale);
  uint8_t y=(uint8_t)(oy+(py*256u)/active_asset->matrix_scale);
  uint8_t w=(uint8_t)(((uint16_t)len*256u+active_asset->matrix_scale-1u)/active_asset->matrix_scale);
  if(w<3u)w=3u;if(literal)w=3u;
  uint8_t count=(uint8_t)((w+7u)/8u);if(count>3u)count=3u;
  REG_OAMADDL=8;REG_OAMADDH=0;
  for(uint8_t i=0;i<6;i++){
    uint8_t hide=(uint8_t)(i>=count);
    REG_OAMDATA=(uint8_t)(x+i*8u);REG_OAMDATA=hide?240u:y;
    REG_OAMDATA=72;REG_OAMDATA=0x32;
  }
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
static uint8_t console_row(const GalleryAsset*a){
  return (uint8_t)(a->display_height/8u+2u+a->title_rows+1u);
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
  while(*phase&&n<8)s[n++]=*phase++;
  while(n<8)s[n++]=' ';s[n++]='[';
  uint8_t fill=(uint8_t)(((uint32_t)done*10u)/total);
  for(uint8_t i=0;i<10;i++)s[n++]=i<fill?'#':'.';
  s[n++]=']';s[n]=0;
  uint8_t row=console_row(active_asset);
  snes_wait_vblank();REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)row*32u);
  for(uint8_t i=0;i<32;i++)REG_VMDATA=0;
  text8(row,s);
  if(is_repack){
    n=0;const char*p="RAW ";while(*p)s[n++]=*p++;n=decimal(s,n,done);
    p=" OUT ";while(*p)s[n++]=*p++;n=decimal(s,n,viz_out);
    s[n++]=' ';s[n++]=(char)('0'+viz_len/10u);s[n++]=(char)('0'+viz_len%10u);s[n++]='P';s[n]=0;
    REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)(row+1u)*32u);
    for(uint8_t i=0;i<32;i++)REG_VMDATA=0;text8((uint8_t)(row+1u),s);
  }
  n=0;const char*q="CORPUS ";while(*q)s[n++]=*q++;
  n=decimal(s,n,gallery_completed_count);s[n++]='/';n=decimal(s,n,GALLERY_ASSET_COUNT);
  q=gallery_completed_count==GALLERY_ASSET_COUNT?" PASS":" RUNNING";while(*q)s[n++]=*q++;s[n]=0;
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)(row+2u)*32u);
  for(uint8_t i=0;i<32;i++)REG_VMDATA=0;text8((uint8_t)(row+2u),s);
}
static void status_text(const char*s){
  uint8_t row=console_row(active_asset);
  snes_wait_vblank();REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)row*32u);
  for(uint8_t i=0;i<32;i++)REG_VMDATA=0;text8(row,s);
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
  palette(a);caption(a,0);oam_arrows((uint8_t)(a->display_height/2u-8u),0);
  if(nav_cancel)return 0;
  split_arm(a->display_height);REG_INIDISP=INIDISP_ON;
  gallery_current_asset=(uint8_t)(a-GALLERY_ASSETS);
  return 1;
}

__attribute__((noinline))
static uint16_t repack_slide(const GalleryAsset*a){
  progress_line("REPACK",0,a->raw_len);
  LzssStats st;uint16_t z=compress_far(FB_A,a->raw_len,PACK,&st);
  oam_hide_compression();
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
  snes_wait_vblank();oam_arrows(0,1);
  m7_set_center((uint16_t)(active_asset->width/2u),(uint16_t)(active_asset->height/2u));
  m7_set_scroll(0,0);
  for(uint8_t f=0;f<32;f++){if(nav_cancel)return 0;uint8_t angle=(uint8_t)(f*2u);int16_t co=SINCOS[(uint8_t)(angle+64u)];int16_t si=SINCOS[angle];
    m7_set_matrix((int16_t)(co>>2),(int16_t)(si>>2),(int16_t)(-si>>2),(int16_t)(co>>2));snes_wait_vblank();}
  return 1;
}

static uint8_t nav_target(uint8_t k){
  uint8_t r=nav_request;nav_request=0;nav_cancel=0;
  gallery_canceled++;directed_load_status=1;
  if(r==1u){
    arrow_flash=1;oam_arrows((uint8_t)(active_asset->display_height/2u-8u),0);
    status_text("LOADING NEXT...");for(uint8_t i=0;i<3;i++)snes_wait_vblank();arrow_flash=0;
    oam_arrows((uint8_t)(active_asset->display_height/2u-8u),0);
    return (uint8_t)(k+1u==GALLERY_ASSET_COUNT?0u:k+1u);
  }
  if(r==2u){
    arrow_flash=2;oam_arrows((uint8_t)(active_asset->display_height/2u-8u),0);
    status_text("LOADING PREVIOUS...");for(uint8_t i=0;i<3;i++)snes_wait_vblank();arrow_flash=0;
    oam_arrows((uint8_t)(active_asset->display_height/2u-8u),0);
    return (uint8_t)(k? k-1u:GALLERY_ASSET_COUNT-1u);
  }
  status_text("LOADING AGAIN...");
  return k;
}

int main(void){
  /*
   * Decode the first work behind the fully visible title card.  m7splash_end()
   * finishes on force blank, so doing the expensive decode after it used to
   * leave the screen black for the entire first-image load.
   */
  snes_ppu_reset_blank();m7splash_begin("PACK UNPACK", "LZSS GALLERY");
  uint8_t k=GALLERY_START;
  const GalleryAsset*a=&GALLERY_ASSETS[k];
  uint16_t t=clock_read();uint8_t ok=unpack_slide(a);
  gallery_unpack_frames[k]=(uint16_t)(clock_read()-t);
  nav_request=0;nav_cancel=0;
  m7splash_end(0);
  vram_clear();load_fonts();load_chevrons();oam_init();m7_begin();m7_set_matrix(0x0080,0,0,0x0080);
  REG_NMITIMEN=NMITIMEN_NMI;uint16_t gate=0xffff;uint8_t decoded=1;
  for(;;){
    a=&GALLERY_ASSETS[k];
    if(!decoded){
      /*
       * Keep the outgoing work at its normal scale while the next stream is
       * decoded.  Previously spinout ran first and left only a collapsed,
       * effectively black Mode 7 plane throughout this work.
       */
      if(!directed_load_status)status_text("LOADING NEXT...");
      directed_load_status=0;
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
