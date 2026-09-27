# 1 "dev/near-store/context.c"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 365 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "dev/near-store/context.c" 2
typedef unsigned short u16;
volatile u16 g,h;
extern void opaque(void);
void across_call(u16 v) { opaque(); g=v; }
void native_context(u16 v) { h=h+42; g=v; }
void before_call(u16 v) { g=v; opaque(); }
void conditional(u16 v, unsigned char b) { if (b) opaque(); g=v; }
void through_pointer(u16 v, u16 *p) { *p=v; g=v; }
