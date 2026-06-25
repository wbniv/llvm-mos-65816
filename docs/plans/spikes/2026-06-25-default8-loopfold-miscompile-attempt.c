// SPIKE — a NON-reproducing minimization attempt for the default-8bit matrix-fold-loop miscompile
// (see docs/investigations/2026-06-25-default8-65816-loopfold-miscompile.md). This is the zoom
// compute in isolation — zoom_step + zoom_matrix + the LOOP fold computing a rolling CRC into
// corpus_result. VERDICT: it does NOT reproduce — host == default-8bit == +mos-a16 == 0x1300 here.
// The miscompile only fires inside the FULL examples/snes/mandel-zoom.c register pressure (the SNES
// MMIO/DMA/boot-hash surrounding the fold), so this compute slice is too small. Kept as the starting
// point for a future cvise reduction FROM the full demo (on branch wt/321-mandel-zoom), not as a
// working repro. Build: mos-clang --config mos-snes.cfg -mcpu=mosw65816 -Os ; host: cc -DHOST_ORACLE.
#include <stdint.h>
static const int16_t SINCOS[256] = {
  0, 6, 13, 19, 25, 31, 38, 44, 50, 56, 62, 68, 74, 80, 86, 92,
  98, 104, 109, 115, 121, 126, 132, 137, 142, 147, 152, 157, 162, 167, 172, 177,
  181, 185, 190, 194, 198, 202, 206, 209, 213, 216, 220, 223, 226, 229, 231, 234,
  237, 239, 241, 243, 245, 247, 248, 250, 251, 252, 253, 254, 255, 255, 256, 256,
  256, 256, 256, 255, 255, 254, 253, 252, 251, 250, 248, 247, 245, 243, 241, 239,
  237, 234, 231, 229, 226, 223, 220, 216, 213, 209, 206, 202, 198, 194, 190, 185,
  181, 177, 172, 167, 162, 157, 152, 147, 142, 137, 132, 126, 121, 115, 109, 104,
  98, 92, 86, 80, 74, 68, 62, 56, 50, 44, 38, 31, 25, 19, 13, 6,
  0, -6, -13, -19, -25, -31, -38, -44, -50, -56, -62, -68, -74, -80, -86, -92,
  -98, -104, -109, -115, -121, -126, -132, -137, -142, -147, -152, -157, -162, -167, -172, -177,
  -181, -185, -190, -194, -198, -202, -206, -209, -213, -216, -220, -223, -226, -229, -231, -234,
  -237, -239, -241, -243, -245, -247, -248, -250, -251, -252, -253, -254, -255, -255, -256, -256,
  -256, -256, -256, -255, -255, -254, -253, -252, -251, -250, -248, -247, -245, -243, -241, -239,
  -237, -234, -231, -229, -226, -223, -220, -216, -213, -209, -206, -202, -198, -194, -190, -185,
  -181, -177, -172, -167, -162, -157, -152, -147, -142, -137, -132, -126, -121, -115, -109, -104,
  -98, -92, -86, -80, -74, -68, -62, -56, -50, -44, -38, -31, -25, -19, -13, -6,
  
};
typedef struct { uint8_t lvl; int16_t scale; uint8_t angle, pal; uint16_t prev; } zt;
#define S0 0x80
static void zstep(zt*z,uint16_t pad){
  if(pad&0x10){z->scale-=4; if(z->scale<=S0/2){ if(z->lvl<7){z->lvl++;z->scale=S0;} else z->scale=S0/2; }}
  if(pad&0x20){z->scale+=4; if(z->scale>=2*S0){ if(z->lvl>0){z->lvl--;z->scale=S0;} else z->scale=2*S0; }}
  if(pad&0x80)z->angle=(uint8_t)(z->angle+2);
  if(pad&0x4000)z->angle=(uint8_t)(z->angle-2);
  z->prev=pad;
}
static void zmat(const zt*z,int16_t m[4]){
  int16_t c=SINCOS[(uint8_t)(z->angle+64)],s=SINCOS[z->angle];
  m[0]=(int16_t)(((int32_t)c*z->scale)>>8); m[1]=(int16_t)(((int32_t)(-s)*z->scale)>>8);
  m[2]=(int16_t)(((int32_t)s*z->scale)>>8); m[3]=(int16_t)(((int32_t)c*z->scale)>>8);
}
static uint16_t cb(uint16_t crc,uint8_t b){crc^=(uint16_t)((uint16_t)b<<8);
  for(uint8_t i=0;i<8;i++)crc=(crc&0x8000)?(uint16_t)((uint16_t)(crc<<1)^0x1021):(uint16_t)(crc<<1);return crc;}
static uint16_t fold(uint16_t crc,const zt*z,const int16_t m[4]){
  crc=cb(crc,z->lvl);crc=cb(crc,(uint8_t)z->scale);crc=cb(crc,(uint8_t)((uint16_t)z->scale>>8));
  crc=cb(crc,z->angle);crc=cb(crc,z->pal);
  for(int i=0;i<4;i++){crc=cb(crc,(uint8_t)m[i]);crc=cb(crc,(uint8_t)((uint16_t)m[i]>>8));}
  return crc;
}
static uint16_t run(void){
  static const uint16_t pads[8]={0x10,0x10,0x80,0x10,0x10,0x80,0x10,0x10};
  zt z={0,S0,0,0,0}; uint16_t crc=0xFFFF; int16_t m[4];
  for(int f=0;f<64;f++){ zstep(&z,pads[f&7]); zmat(&z,m); crc=fold(crc,&z,m); }
  return crc;
}
#ifdef HOST_ORACLE
#include <stdio.h>
int main(void){ printf("host fold CRC = 0x%04X\n", run()); return 0; }
#else
volatile uint16_t corpus_result;
int main(void){ corpus_result=run(); for(;;){} }
#endif
