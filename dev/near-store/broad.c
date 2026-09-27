typedef unsigned short u16;
typedef unsigned char u8;
extern volatile u16 g, h;
extern volatile u8 byte;
extern void opaque(void);
extern u16 produce(void);

u16 absolute_decrement(u16 v) { g = v; return v - 1; }
u16 indirect_decrement(u16 *p, u16 v) { *p = v; return v - 1; }
u16 volatile_increment(volatile u16 *p, u16 v) { *p = v; return v + 1; }
u16 volatile_decrement(volatile u16 *p, u16 v) { *p = v; return v - 1; }
u16 indirect_add_two(u16 *p, u16 v) { *p = v; return v + 2; }
void indirect_increment_result(u16 *p, u16 v) { *p = v; g = v + 1; }
void indirect_decrement_result(u16 *p, u16 v) { *p = v; g = v - 1; }
u16 indirect_twice_increment(volatile u16 *p, volatile u16 *q, u16 v) {
  *p = v; *q = v; return v + 1;
}
u16 indirect_return_call(u16 *p) { u16 v = produce(); *p = v; return v; }
void indirect_call_increment(u16 *p) { *p = produce() + 1; }
void indirect_byte_load(u16 *p) { *p = byte; }
void indirect_byte_pointer(u16 *p, volatile u8 *q) { *p = *q; }
void indirect_byte_native(u16 *p, u8 v) { h = h + 42; *p = v; }
u16 indirect_byte_return(u16 *p, u8 v) { *p = v; return v; }
void indirect_byte_call(u16 *p, u8 v) { opaque(); *p = v; }
void indirect_byte_twice(volatile u16 *p, volatile u16 *q, u8 v) {
  *p = v; *q = v;
}
void loaded_pointer_byte(u16 **p, u8 v) { **p = v; }
u16 loaded_pointer_increment(u16 **p, u16 v) { **p = v; return v + 1; }
u16 absolute_decrement_call(u16 v) { opaque(); g = v; return v - 1; }
u16 absolute_decrement_native(u16 v) { h = h + 42; g = v; return v - 1; }
