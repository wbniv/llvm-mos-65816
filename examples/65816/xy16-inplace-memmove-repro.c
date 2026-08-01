/* REPRO for the +mos-xy16 in-place memmove/memcpy 16-bit-index miscompile found 2026-06-29 by the #23
 * L-system demo's differential gate. CAP=1700 (16-bit buffer indices) DIVERGES under +mos-xy16 (xy16
 * built-string CRC 0x1CC6 vs host==default==+mos-a16 0x90AA); CAP=200 (8-bit indices) matches. Not a
 * stale build (toolchain c798c31). See docs/investigations/2026-06-29-xy16-inplace-memmove-16bit-index-miscompile.md.
 * Build+run (dev container): --config link each of +mos-a16/+mos-xy16, read corpus_result via jgxcheck. */
#include <stdint.h>
#ifndef CAP
#define CAP 1700
#endif
volatile uint16_t corpus_result;
static char buf[CAP];
static const char *rule(char c){ switch(c){case 'X':return "F-[[X]+X]+F[+FX]-X";case 'F':return "FF";default:return 0;} }
int main(void){
  buf[0]='X'; uint16_t len=1;
  for(uint8_t g=0;g<5u;g++){
    uint16_t i=0;
    while(i<len){
      const char*p=rule(buf[i]);
      if(!p){i++;continue;}
      uint16_t pl=(uint16_t)__builtin_strlen(p);
      if((uint16_t)(len+(pl-1u))>(uint16_t)(CAP-1)) goto done;
      __builtin_memmove(&buf[i+pl], &buf[i+1], (uint16_t)(len-(i+1u)));
      __builtin_memcpy(&buf[i], p, pl);
      len=(uint16_t)(len+(pl-1u)); i=(uint16_t)(i+pl);
    }
  }
done:;
  uint16_t h=0; for(uint16_t i=0;i<len;i++) h=(uint16_t)((uint16_t)(((unsigned)h<<1)|((unsigned)h>>15))^(uint16_t)(uint8_t)buf[i]);
  corpus_result=h; for (;;) __asm__ volatile("wai"); return 0;
}
