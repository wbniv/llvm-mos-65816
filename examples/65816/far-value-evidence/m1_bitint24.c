/* WORKS: a genuine 24-bit value flows through GISel with NO MVT::i24 —
   it narrows to 3x s8 (lda/ldx/ldy + adc chain). This is why packed-24
   does not require a new MVT. */
typedef unsigned _BitInt(24) u24;
volatile u24 s, d;
void f(void){ u24 a = s; a += (u24)0x010000; d = a; }   /* +carry into byte 3 */
