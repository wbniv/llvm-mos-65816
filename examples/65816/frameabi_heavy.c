/* frameabi_heavy.c — #321 frame-ABI study, A0 census boundary characterization.
 *
 * Synthetic stress shapes for dev/frameabi-census.sh: deliberately constructed to
 * MAXIMIZE static-stack (spill) traffic and MINIMIZE __rc (imaginary-register)
 * traffic — the only regime where a DP-window / stack-relative frame could beat
 * the soft static stack. They map the winning boundary the realistic corpus
 * never reaches.
 *
 * Finding (see the plan): only the *atypical* shapes profit —
 *   - volatile locals (every access is a direct static-stack load/store, ~no
 *     arithmetic) -> spill-heavy -> PROFIT, but volatile is for MMIO, not plain
 *     locals;
 *   - constant-indexed local arrays shuffled with minimal arithmetic -> PROFIT.
 * The *realistic* shapes all LOSE with spill=0, because llvm-mos keeps locals
 * register-resident in __rc and routes local arrays/buffers through a pointer in
 * __rc (`lda (__rc),y`) — so element/buffer/struct/address-taken access is __rc
 * traffic, not static-stack traffic. Realistic compute is __rc-dominated => NULL.
 *
 * Compile-only fodder (extern sink() is unresolved by design); never linked/run.
 */

extern void sink(unsigned char *p);

/* ---- atypical: PROFIT (volatile / const-index, spill-heavy, low __rc) ---- */

/* volatile scalars: every read/write is a direct static-stack access */
unsigned char fh_vol_copy(void) {
  volatile unsigned char a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8;
  a = b; b = c; c = d; d = e; e = f; f = g; g = h; h = a;
  a = c; c = e; e = g; g = a; b = d; d = f; f = h; h = b;
  return a + b + c + d + e + f + g + h;
}

/* volatile array, constant indices -> direct static-stack accesses */
unsigned char fh_vol_array(void) {
  volatile unsigned char v[12] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11};
  v[0] = v[1];  v[2] = v[3];  v[4] = v[5];  v[6] = v[7];  v[8] = v[9];  v[10] = v[11];
  v[1] = v[2];  v[3] = v[4];  v[5] = v[6];  v[7] = v[8];  v[9] = v[10];
  return v[0] + v[3] + v[6] + v[9] + v[11];
}

/* ---- realistic: LOSE (spill=0; locals live in __rc) ---- */

/* address-taken scalars: still land in __rc (imaginary regs ARE addressable ZP) */
unsigned char fh_addrtaken(void) {
  unsigned char a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8;
  sink(&a); sink(&b); sink(&c); sink(&d); sink(&e); sink(&f); sink(&g); sink(&h);
  a = b; c = d; e = f; g = h; b = a; d = c; f = e; h = g;
  return a + b + c + d + e + f + g + h;
}

/* local buffer copy via a runtime index -> pointer in __rc, (zp),y accesses */
unsigned char fh_buf_copy(void) {
  unsigned char dst[16], src[16];
  sink(src);
  for (unsigned char i = 0; i < 16; i++) dst[i] = src[i];
  sink(dst);
  return dst[0] ^ dst[15];
}

/* large local struct, field shuffling -> pointer in __rc */
struct S { unsigned char a, b, c, d, e, f, g, h, i, j, k, l; };
unsigned char fh_struct(void) {
  struct S s;
  sink((unsigned char *)&s);
  s.a = s.b; s.c = s.d; s.e = s.f; s.g = s.h; s.i = s.j; s.k = s.l;
  s.b = s.c; s.d = s.e; s.f = s.g; s.h = s.i; s.j = s.k;
  sink((unsigned char *)&s);
  return s.a ^ s.f ^ s.l;
}

/* in-place reverse of a local buffer -> pointer-heavy, __rc-dominated */
unsigned char fh_reverse(void) {
  unsigned char v[20];
  sink(v);
  for (unsigned char i = 0, j = 19; i < j; i++, j--) {
    unsigned char t = v[i]; v[i] = v[j]; v[j] = t;
  }
  sink(v);
  return v[0] ^ v[19];
}
