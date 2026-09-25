#include <stdint.h>
#define FAR __attribute__((address_space(2)))
extern const FAR uint8_t  tab[];
extern const FAR uint16_t tw[];
extern FAR uint16_t       ww[];
volatile uint16_t base;
volatile uint16_t out;
uint8_t  dst[64];
uint16_t dstw[32];
/* Realistic SNES idioms, 16-bit ambient (+mos-a16): */
/* (1) far ROM table -> WRAM at a runtime 16-bit offset (same shape as the [dp],Y blit) */
void blit(void){ uint16_t o = base; for (uint8_t j = 0; j < 64; j++) dst[j] = tab[o + j]; }
/* (2) word table walk, induction-variable index */
void sumw(void){ uint16_t s = 0; for (uint8_t j = 0; j < 32; j++) s += tw[j]; out = s; }
/* (3) word copy far ROM -> near WRAM, induction index */
void copyw(void){ for (uint8_t j = 0; j < 32; j++) dstw[j] = tw[j]; }
/* (4) store: fill a far WRAM word array */
void fillw(void){ uint16_t x = base; for (uint8_t j = 0; j < 32; j++) ww[j] = x; }
