// #320 far (addrspace 2) runtime memset/memcpy/memmove.
//
// The 65816 "far" pointer is a full 24-bit address (addrspace 2, a 32-bit value).
// When the compiler forms a far G_MEMSET/G_MEMCPY/G_MEMMOVE that it cannot
// inline-expand (a variable size, or a constant size over MOSLegalizerInfo's
// inline SizeLimit), `legalizeMemOp` routes it HERE instead of to the near
// runtime (memset/__memset/memcpy/memmove), whose pointer parameter is a 16-bit
// `char *` (addrspace 0) — passing a far pointer to those would drop the bank
// byte and store/read the WRONG BANK. These variants take far-qualified pointers,
// so the 32-bit far pointer (Imag32 calling convention) survives intact and every
// access is a 65816 indirect-long (`sta/lda [dp]`).
//
// The backend widens any near/zp pointer operand to far (bank $00) before the
// call, so both pointer parameters are always far — one variant per op covers the
// far<-far, far<-near and near<-far combinations.
//
// Built with -fno-builtin (so the loop-idiom recognizer does NOT turn these very
// loops back into llvm.memset/memcpy.p2 -> infinite recursion into ourselves),
// -mcpu=mosw65816 (indirect-long deref) and +mos-a16 (the far pointer is a 32-bit
// value; computing ptr[i] is a 32-bit G_PTR_ADD that only legalizes under a16).
// See platforms/snes/CMakeLists.txt and
// docs/plans/2026-06-26-fix-the-far-addrspace-2-memset-memcpy-memmove-sile.md.
//
// IMPORTANT loop shape: walk with an INTEGER index (`ptr[i]`), keeping the far
// base loop-invariant — NOT a far-pointer induction variable (`ptr++`). A far
// pointer carried across a loop back-edge becomes a `G_PHI` of a far (addrspace 2)
// pointer, which the MOS legalizer does not support (G_PHI is legal only for
// {s1,s8,p0,p1}), so `ptr++` aborts the backend ("unable to legalize ... G_PHI
// (p2)"). The index form recomputes the full 24-bit address each iteration (the
// 32-bit add carries into the bank byte, so a span may cross banks) and emits a
// plain `sta/lda [dp]` — the same invariant-base + integer-index shape the far
// Mandelbrot renderer (examples/snes/mandel-display.c) already uses.

#include <stddef.h>
#include <stdint.h>

#define FAR __attribute__((address_space(2)))

// Mirrors the near __memset (the intrinsic form: value is a char, not an int).
__attribute__((weak)) void __memset_far(FAR char *ptr, char value, size_t num) {
  for (size_t i = 0; i < num; i++)
    ptr[i] = value;
}

__attribute__((weak)) void __memcpy_far(FAR char *__restrict__ dst,
                                        FAR const char *__restrict__ src,
                                        size_t num) {
  for (size_t i = 0; i < num; i++)
    dst[i] = src[i];
}

__attribute__((weak)) void __memmove_far(FAR char *dst, FAR const char *src,
                                         size_t num) {
  // Choose copy direction by comparing the FULL 32-bit far pointer values — NOT
  // a 16-bit uintptr_t truncation like the near memmove, or overlap that crosses
  // (or lives within) a high-WRAM bank would be mishandled. A far pointer is a
  // 32-bit value, so (uint32_t) is a width-preserving ptrtoint.
  if ((uint32_t)dst <= (uint32_t)src) {
    for (size_t i = 0; i < num; i++)
      dst[i] = src[i]; // forward (or non-overlapping)
  } else {
    for (size_t i = num; i; i--)
      dst[i - 1] = src[i - 1]; // backward, to handle dst > src overlap
  }
}
