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
#define PACK ((FAR uint8_t*)0x7E5200u)
#define FB_B ((FAR uint8_t*)0x7E8B00u)
#define HEAD ((FAR uint16_t*)0x7EBD00u)
#define PREV ((FAR uint16_t*)0x7EC000u)
#define PACK_CAP 14400u
#define MAP2 0x4000u
#define MAP3 0x4400u
#define CHR16 0x5000u
#define CHR8 0x6000u
#define PAL16 7u
#define PAL8 0u

volatile uint16_t corpus_result;
volatile uint8_t gallery_progress;
volatile uint16_t gallery_unpack_frames[GALLERY_ASSET_COUNT];
volatile uint16_t gallery_repack_frames[GALLERY_ASSET_COUNT];
volatile uint16_t gallery_verify_frames[GALLERY_ASSET_COUNT];
volatile uint8_t gallery_clock_lo, gallery_clock_hi;
static uint8_t chrbuf[1024];
static uint8_t bgmode_tab[7], tm_tab[7];
static const uint8_t zero=0;
static const GalleryAsset *active_asset;

asm(".text\n"
    ".global nmi\n"
    "nmi:\n"
    "  php\n"
    "  .byte $e2, $20\n"
    "  pha\n"
    "  inc gallery_clock_lo\n"
    "  bne 1f\n"
    "  inc gallery_clock_hi\n"
    "1:\n"
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
    uint8_t flags=src[sp++];
    for(uint8_t bit=0;bit<8&&dp<want;bit++){
      if(flags&(uint8_t)(1u<<bit)){
        if((uint16_t)(sp+2u)>slen)return 0;
        uint8_t a=src[sp++],b=src[sp++];
        uint16_t dist=(uint16_t)(a|((uint16_t)(b>>4)<<8));
        uint8_t n=(uint8_t)((b&15u)+3u);
        if(!dist||dist>dp)return 0;
        while(n--&&dp<want){dst[dp]=dst[(uint16_t)(dp-dist)];dp++;}
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

__attribute__((optnone,noinline))
static uint16_t compress_far(const FAR uint8_t *src,uint16_t len,FAR uint8_t *dst,LzssStats *st){
  uint16_t pos=0,op=0;
  uint16_t next_meter=512;
  for(uint16_t i=0;i<256;i++)HEAD[i]=0xffff;
  st->literals=st->matches=st->longest=0;
  while(pos<len){
    if(op>=PACK_CAP)return 0;
    uint16_t flagpos=op++;uint8_t flags=0;
    for(uint8_t bit=0;bit<8&&pos<len;bit++){
      uint8_t hv=hash_far(src,pos,len);uint16_t p=HEAD[hv],best=0,distbest=0;uint8_t seen=0;
      while(p!=0xffff&&(uint16_t)(pos-p)<=4095u&&seen<64u){
        uint16_t n=0;
        while(n<18u&&(uint16_t)(pos+n)<len&&src[p+n]==src[pos+n])n++;
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
      }else{
        if(op>=PACK_CAP)return 0;dst[op++]=src[pos];advance=1;st->literals++;
      }
      for(uint16_t n=0;n<advance;n++){
        uint16_t q=(uint16_t)(pos+n);uint8_t h=hash_far(src,q,len);
        PREV[q&4095u]=HEAD[h];HEAD[h]=q;
      }
      pos=(uint16_t)(pos+advance);
    }
    dst[flagpos]=flags;
    if(pos>=next_meter){progress_line("REPACK",pos,len);next_meter=(uint16_t)(next_meter+512u);}
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
}
static void blank_maps(void){
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=MAP2;for(uint16_t i=0;i<1024;i++)REG_VMDATA=(uint16_t)(PAL16<<10);
  REG_VMADD=MAP3;for(uint16_t i=0;i<1024;i++)REG_VMDATA=(uint16_t)(PAL8<<10);
}
static uint8_t slen(const char*s,uint8_t max){uint8_t n=0;while(s&&*s++&&n<max)n++;return n;}
static void text16(uint8_t row,const char*s){
  uint8_t n=slen(s,15),col=(uint8_t)(16u-n);
  for(uint8_t i=0;i<n;i++){
    uint8_t g=(uint8_t)s[i]-FONT16_FIRST;uint16_t t=(uint16_t)(g*4u)|(uint16_t)(PAL16<<10);
    REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP2+(uint16_t)row*32u+col+i*2u);
    REG_VMDATA=t;REG_VMDATA=(uint16_t)(t+1u);
    REG_VMADD=(uint16_t)(MAP2+(uint16_t)(row+1u)*32u+col+i*2u);
    REG_VMDATA=(uint16_t)(t+2u);REG_VMDATA=(uint16_t)(t+3u);
  }
}
static void text8(uint8_t row,const char*s){
  uint8_t n=slen(s,30),col=(uint8_t)((32u-n)/2u);
  REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)row*32u+col);
  while(*s)REG_VMDATA=(uint16_t)(((uint8_t)*s++-FONT8_FIRST)|(PAL8<<10));
}
static void caption(const GalleryAsset*a,const char*status){
  blank_maps();uint8_t split=(uint8_t)(a->height*2u),row=(uint8_t)(split/8u);
  for(uint8_t i=0;i<a->artist_rows;i++)text16((uint8_t)(row+i*2u),a->artist[i]);
  row=(uint8_t)(row+a->artist_rows*2u);
  for(uint8_t i=0;i<a->title_rows;i++)text8((uint8_t)(row+i),a->title[i]);
  if(status)text8((uint8_t)(row+a->title_rows),status);
}
static void progress_line(const char *phase,uint16_t done,uint16_t total){
  char s[31];uint8_t n=0;
  while(*phase&&n<8)s[n++]=*phase++;
  while(n<8)s[n++]=' ';s[n++]='[';
  uint8_t fill=(uint8_t)(((uint32_t)done*10u)/total);
  for(uint8_t i=0;i<10;i++)s[n++]=i<fill?'#':'.';
  s[n++]=']';s[n]=0;
  uint8_t row=(uint8_t)(active_asset->height/4u+active_asset->artist_rows*2u+active_asset->title_rows);
  snes_wait_vblank();REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)row*32u);
  for(uint8_t i=0;i<32;i++)REG_VMDATA=0;
  text8(row,s);
}
static void status_text(const char*s){
  uint8_t row=(uint8_t)(active_asset->height/4u+active_asset->artist_rows*2u+active_asset->title_rows);
  snes_wait_vblank();REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)(MAP3+(uint16_t)row*32u);
  for(uint8_t i=0;i<32;i++)REG_VMDATA=0;text8(row,s);
}
static uint8_t decimal(char*s,uint8_t n,uint16_t v){
  char r[5];uint8_t k=0;do{r[k++]=(char)('0'+v%10u);v/=10u;}while(v&&k<5);
  while(k)s[n++]=r[--k];return n;
}
static void result_line(uint8_t ok,uint16_t unpack,uint16_t repack,uint16_t verify){
  char s[31];uint8_t n=0;
  const char*p=ok?"OK D":"FAIL D";while(*p)s[n++]=*p++;
  n=decimal(s,n,unpack);s[n++]=' ';s[n++]='C';n=decimal(s,n,repack);
  s[n++]=' ';s[n++]='V';n=decimal(s,n,verify);s[n++]='F';s[n]=0;
  status_text(s);
}
static void split_arm(uint8_t split){
  uint8_t rest=(uint8_t)(split-127u),bottom=(uint8_t)(224u-split);
  uint8_t a[7]={127,BGMODE_7,rest,BGMODE_7,bottom,BGMODE_1,0};
  uint8_t b[7]={127,TM_BG1,rest,TM_BG1,bottom,(uint8_t)(TM_BG2|TM_BG3),0};
  for(uint8_t i=0;i<7;i++){bgmode_tab[i]=a[i];tm_tab[i]=b[i];}
  REG_DMAP1=0;REG_BBAD1=0x05;REG_A1T1L=(uint8_t)(uintptr_t)bgmode_tab;REG_A1T1H=(uint8_t)((uintptr_t)bgmode_tab>>8);REG_A1B1=0;
  REG_DMAP2=0;REG_BBAD2=0x2c;REG_A1T2L=(uint8_t)(uintptr_t)tm_tab;REG_A1T2H=(uint8_t)((uintptr_t)tm_tab>>8);REG_A1B2=0;
  REG_HDMAEN=0x06;
}
static void palette(const GalleryAsset*a){
  REG_CGADD=0;for(uint8_t i=0;i<64;i++)REG_CGDATA=a->pal[i];
  REG_CGADD=(uint8_t)(PAL16*16u);uint16_t c=0;REG_CGDATA=0;REG_CGDATA=0;
  c=SNES_RGB(31,25,8);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
  c=SNES_RGB(5,4,3);REG_CGDATA=(uint8_t)c;REG_CGDATA=(uint8_t)(c>>8);
}
static void upload_image(const GalleryAsset*a){
  uint8_t rows=(uint8_t)((a->height+7u)/8u);
  for(uint8_t ty=0;ty<rows;ty++){
    for(uint8_t tx=0;tx<16;tx++)for(uint8_t y=0;y<8;y++)for(uint8_t x=0;x<8;x++){
      uint16_t py=(uint16_t)ty*8u+y;
      chrbuf[(uint16_t)tx*64u+(uint16_t)y*8u+x]=py<a->height?FB_A[py*128u+(uint16_t)tx*8u+x]:0;
    }
    REG_VMAIN=VMAIN_INC_HIGH_1;REG_VMADD=(uint16_t)ty*1024u;REG_DMAP0=0;REG_BBAD0=0x19;
    REG_A1T0L=(uint8_t)(uintptr_t)chrbuf;REG_A1T0H=(uint8_t)((uintptr_t)chrbuf>>8);REG_A1B0=0;
    REG_DAS0L=0;REG_DAS0H=4;REG_MDMAEN=1;
  }
}
static uint8_t exact_stream(const GalleryAsset*a,uint16_t n){
  if(n!=a->lz_len)return 0;for(uint16_t i=0;i<n;i++)if(PACK[i]!=a->lz[i])return 0;return 1;
}
static void hold(uint16_t n){while(n--){snes_wait_vblank();}}

__attribute__((noinline))
static uint8_t unpack_slide(const GalleryAsset*a){
  return (uint8_t)(decode_far(a->lz,a->lz_len,FB_A,a->raw_len)!=0&&fold_far(FB_A,a->raw_len)==a->checksum);
}

__attribute__((noinline))
static void prepare_slide(const GalleryAsset*a){
  active_asset=a;REG_HDMAEN=0;REG_INIDISP=INIDISP_FORCE_BLANK;
  m7_set_matrix(0x0080,0,0,0x0080);
  m7_tilemap_clear(0,(uint16_t)(uintptr_t)&zero,M7_TILEMAP_WORDS);
  m7_tilemap_identity(16,(uint8_t)((a->height+7u)/8u));
  m7_set_center(64,(uint16_t)(a->height/2u));m7_set_scroll(0,0);
  upload_image(a);palette(a);caption(a,0);split_arm((uint8_t)(a->height*2u));REG_INIDISP=INIDISP_ON;
}

__attribute__((noinline))
static uint16_t repack_slide(const GalleryAsset*a){
  progress_line("REPACK",0,a->raw_len);
  LzssStats st;uint16_t z=compress_far(FB_A,a->raw_len,PACK,&st);
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
  if(!ok){REG_COLDATA=0x3f;gate^=0x8000;}
  gate=lzss_fold(gate,(uint8_t)a->checksum);gate=lzss_fold(gate,(uint8_t)(a->checksum>>8));
  gate=lzss_fold(gate,(uint8_t)z);gate=lzss_fold(gate,(uint8_t)(z>>8));
  gallery_progress=(uint8_t)(k+1u);if(k==(uint8_t)(GALLERY_ASSET_COUNT-1u))corpus_result=gate;
  return gate;
}

__attribute__((noinline))
static void spinout(void){
  for(uint8_t f=0;f<32;f++){uint8_t angle=(uint8_t)(f*2u);int16_t co=SINCOS[(uint8_t)(angle+64u)];int16_t si=SINCOS[angle];
    m7_set_matrix((int16_t)(co>>2),(int16_t)(si>>2),(int16_t)(-si>>2),(int16_t)(co>>2));snes_wait_vblank();}
}

int main(void){
  snes_ppu_reset_blank();m7splash("PACK UNPACK", "LZSS GALLERY",90);
  vram_clear();load_fonts();m7_begin();m7_set_matrix(0x0080,0,0,0x0080);
  REG_NMITIMEN=NMITIMEN_NMI;uint16_t gate=0xffff;
  for(;;)for(uint8_t k=0;k<GALLERY_ASSET_COUNT;k++){
    const GalleryAsset*a=&GALLERY_ASSETS[k];
    uint16_t t=clock_read();uint8_t ok=unpack_slide(a);
    gallery_unpack_frames[k]=(uint16_t)(clock_read()-t);
    prepare_slide(a);hold(60);
    t=clock_read();uint16_t z=repack_slide(a);
    gallery_repack_frames[k]=(uint16_t)(clock_read()-t);
    t=clock_read();
    ok=verify_slide(a,z,ok);
    gallery_verify_frames[k]=(uint16_t)(clock_read()-t);
    result_line(ok,gallery_unpack_frames[k],gallery_repack_frames[k],gallery_verify_frames[k]);
    gate=record_result(a,k,z,gate,ok);
    hold(180);spinout();
  }
}
