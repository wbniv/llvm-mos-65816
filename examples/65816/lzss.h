// Deterministic LZSS compressor/decompressor shared by host and SNES gallery.
#ifndef LZSS_H
#define LZSS_H
#include <stdint.h>

#define LZSS_WINDOW 4095u
#define LZSS_MIN 3u
#define LZSS_MAX 18u
#define LZSS_CANDIDATES 64u
#define LZSS_NONE 0xFFFFu

typedef struct {
  uint16_t literals, matches, longest;
} LzssStats;

static inline uint8_t lzss_hash3(const uint8_t *p, uint16_t pos, uint16_t len) {
  if ((uint16_t)(pos + 2u) >= len) return 0;
  return (uint8_t)((uint8_t)(p[pos] * 31u) ^ (uint8_t)(p[pos + 1u] * 17u) ^ p[pos + 2u]);
}

static uint16_t lzss_compress(const uint8_t *src, uint16_t len, uint8_t *dst, uint16_t cap,
                              uint16_t head[256], uint16_t prev[4096], LzssStats *st) {
  uint16_t pos=0, op=0;
  for (uint16_t i=0;i<256;i++) head[i]=LZSS_NONE;
  st->literals=st->matches=st->longest=0;
  while (pos<len) {
    if (op>=cap) return 0;
    uint16_t flagpos=op++; uint8_t flags=0;
    for (uint8_t bit=0;bit<8 && pos<len;bit++) {
      uint8_t hv=lzss_hash3(src,pos,len);
      uint16_t p=head[hv], bestlen=0, bestdist=0; uint8_t seen=0;
      while (p!=LZSS_NONE && (uint16_t)(pos-p)<=LZSS_WINDOW && seen<LZSS_CANDIDATES) {
        uint16_t n=0;
        while (n<LZSS_MAX && (uint16_t)(pos+n)<len && src[p+n]==src[pos+n]) n++;
        uint16_t dist=(uint16_t)(pos-p);
        if (n>=LZSS_MIN && (n>bestlen || (n==bestlen && dist<bestdist))) {
          bestlen=n; bestdist=dist;
        }
        p=prev[p&4095u]; seen++;
      }
      uint16_t advance;
      if (bestlen>=LZSS_MIN) {
        if ((uint16_t)(op+2u)>cap) return 0;
        flags|=(uint8_t)(1u<<bit);
        dst[op++]=(uint8_t)bestdist;
        dst[op++]=(uint8_t)(((bestdist>>8)<<4)|(bestlen-LZSS_MIN));
        advance=bestlen; st->matches++; if(bestlen>st->longest)st->longest=bestlen;
      } else {
        if (op>=cap) return 0;
        dst[op++]=src[pos]; advance=1; st->literals++;
      }
      for (uint16_t n=0;n<advance;n++) {
        uint16_t q=(uint16_t)(pos+n); uint8_t h=lzss_hash3(src,q,len);
        prev[q&4095u]=head[h]; head[h]=q;
      }
      pos=(uint16_t)(pos+advance);
    }
    dst[flagpos]=flags;
  }
  return op;
}

static uint16_t lzss_decode(const uint8_t *src,uint16_t slen,uint8_t *dst,uint16_t want) {
  uint16_t sp=0,dp=0;
  while(sp<slen && dp<want) {
    uint8_t flags=src[sp++];
    for(uint8_t bit=0;bit<8 && dp<want;bit++) {
      if(flags&(uint8_t)(1u<<bit)) {
        if((uint16_t)(sp+2u)>slen)return 0;
        uint8_t a=src[sp++],b=src[sp++];
        uint16_t dist=(uint16_t)(a|((uint16_t)(b>>4)<<8));
        uint8_t n=(uint8_t)((b&15u)+LZSS_MIN);
        if(!dist||dist>dp)return 0;
        while(n-- && dp<want){dst[dp]=dst[(uint16_t)(dp-dist)];dp++;}
      } else {
        if(sp>=slen)return 0; dst[dp++]=src[sp++];
      }
    }
  }
  return dp==want?dp:0;
}

static inline uint16_t lzss_fold(uint16_t h,uint8_t v) {
  return (uint16_t)((uint16_t)((h<<1)|(h>>15))^v);
}
#endif
