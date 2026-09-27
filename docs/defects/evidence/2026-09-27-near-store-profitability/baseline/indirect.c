typedef unsigned short u16;
volatile u16 g,h;
extern void opaque(void);
extern u16 produce(void);
void simple(u16 *p,u16 v) { *p=v; }
void vol(volatile u16 *p,u16 v) { *p=v; }
u16 ret(u16 *p,u16 v) { *p=v; return v; }
void twice(volatile u16 *p,volatile u16 *q,u16 v) { *p=v; *q=v; }
void abs_and_indir(u16 *p,u16 v) { *p=v; g=v; }
void offset(u16 *p,u16 v) { p[1]=v; }
void indexed(u16 *p,unsigned char i,u16 v) { p[i]=v; }
void call(u16 *p,u16 v) { opaque(); *p=v; }
void conditional(u16 *p,u16 v,unsigned char b) { if(b) opaque(); *p=v; }
void result(u16 *p) { *p=produce(); }
void add(u16 *p,u16 v) { *p=v+42; }
void copy(volatile u16 *p) { *p=g; }
u16 mixed(u16 *p,u16 v) { *p=v; return v+1; }
void native_context(u16 *p,u16 v) { h=h+42; *p=v; }
void loadptr(u16 **p,u16 v) { **p=v; }
void byte_value(u16 *p,unsigned char v) { *p=v; }
void third(u16 *p,u16 a,u16 v) { *p=v; g=a; }
