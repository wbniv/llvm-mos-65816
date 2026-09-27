typedef unsigned short u16;
u16 g, h;
volatile u16 vg;
u16 arr[128];
void set(u16 v) { g = v; }
void vset(u16 v) { vg = v; }
void pset(u16 *p, u16 v) { *p = v; }
void iset(unsigned char i, u16 v) { arr[i] = v; }
void copy(void) { g = h; }
void add(u16 v) { g = v + 42; }
void bit(u16 v) { g = v ^ 0x1234; }
void zero(void) { g = 0; }
void multiple(u16 v) { g = v; h = v; }
u16 mixed(u16 v) { g = v; return v + 1; }
u16 passthrough(u16 v) { g = v; return v; }
extern u16 f(void);
void callresult(void) { g = f(); }
