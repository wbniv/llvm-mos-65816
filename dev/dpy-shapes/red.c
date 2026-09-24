#include <stdint.h>
#define FAR __attribute__((address_space(2)))
extern const FAR uint8_t b[];
extern const FAR uint16_t w[];
volatile uint16_t k;
volatile uint8_t  k8;
volatile uint32_t k32;
volatile uint16_t out;

// (A) 16-bit unsigned index into a far byte array  -> ideal: lda [dp],y
void fa(void){ uint16_t i = k; out = b[i]; }
// (B) 8-bit index
void fb(void){ uint8_t i = k8; out = b[i]; }
// (C) 16-bit index into far uint16 array
void fc(void){ uint16_t i = k; out = w[i]; }
// (D) loop: sum 16 bytes at runtime base index -> does the add amortize?
void fd(void){ uint16_t i = k; uint16_t s=0; for (uint8_t j=0;j<16;j++) s += b[i+j]; out=s; }
// (E) 32-bit index (farindex class)
void fe(void){ uint32_t i = k32; out = b[i]; }
