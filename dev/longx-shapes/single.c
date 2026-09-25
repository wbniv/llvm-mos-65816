#include <stdint.h>
#define FAR __attribute__((address_space(2)))
/* Far GLOBAL bases: a statically-known 24-bit address, no pointer in the source. */
extern const FAR uint8_t  tb[];   /* far ROM byte table  */
extern const FAR uint16_t tw[];   /* far ROM word table  */
extern FAR uint8_t        wb[];   /* far WRAM byte array (store target, $7E/$7F) */
extern FAR uint16_t       ww[];   /* far WRAM word array */
extern const FAR uint16_t fg;     /* far scalar global (long-form ALU operand) */
volatile uint8_t  k8;
volatile uint16_t k, v, out;

/* loads: lda long,X (bf) */
void ga(void){ uint8_t  i = k8; out = tb[i]; }   /* 8-bit index, byte elem   */
void gb(void){ uint16_t i = k;  out = tb[i]; }   /* 16-bit index, byte elem  */
void gc(void){ uint8_t  i = k8; out = tw[i]; }   /* 8-bit index, word elem (scaled <=510) */
void gd(void){ uint16_t i = k;  out = tw[i]; }   /* 16-bit index, word elem  */
/* stores: sta long,X (9f) */
void sa(void){ uint8_t  i = k8; wb[i] = (uint8_t)v; }
void sb(void){ uint16_t i = k;  ww[i] = v; }
/* long-form ALU against a far scalar: cmp/eor/adc long (cf/4f/6f) */
uint16_t xc(uint16_t x){ return x == fg; }
uint16_t xe(uint16_t x){ return x ^ fg; }
uint16_t xa(uint16_t x){ return x + fg; }
