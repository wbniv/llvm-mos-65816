// Corpus: setjmp/longjmp non-local return on the 65816 (native-mode 16-bit stack).
// Regression guard for the 6502-only common setjmp.S bug (docs/investigations/
// 2026-06-30-setjmp-longjmp-65816-native-stack-bug.md): the common setjmp.S restored
// the hard stack pointer with `tax; txs`, which in native mode drops S into page 0 so
// longjmp rts-es to garbage and never returns. platforms/snes/setjmp.S fixes it by
// reconstructing the page-1 16-bit S and reading/writing the return address
// stack-relative. Surfaced scoping stress-demo #35.
//
// The setjmp/longjmp/jmp_buf declarations are mirrored inline from <setjmp.h> rather
// than #included: the corpus-a16 verify-machineinstrs gate compiles with `--target=mos`
// and NO `--config`, so it has no -isystem path for platform libc headers (the same
// reason the Csmith fuzz path skips verify — see tools/a16_fuzz.py). Keeping this TU
// header-free lets the full differential (verify + default/a16/xy16 @ MAME + bsnes-jg)
// run. The inline decls are codegen-identical to <setjmp.h> (verified by diffing -S).
//
// Result (unsigned 16-bit):
//   setjmp returns 0 first pass -> jump() -> longjmp(jb, 7) -> setjmp returns 7
//   corpus_result = 0x2000 + 7 = 0x2007  (a hang/garbage return leaves 0x1111)
#include <stdint.h>

struct __jmp_buf_tag {
  void *ret_addr;
  char s;
  void *sp;
  char csrs[14];
};
typedef struct __jmp_buf_tag jmp_buf[1];
// preserve_none is a no-op on the mos target today (dropped as "not supported for this
// target"), but is kept verbatim to match <setjmp.h>. In a system header clang silences
// the -Wunknown/ignored-attributes diagnostics; do the same explicitly here.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-attributes"
#pragma clang diagnostic ignored "-Wignored-attributes"
__attribute__((preserve_none, leaf)) int setjmp(jmp_buf src);
#pragma clang diagnostic pop
void longjmp(jmp_buf dst, int arg);

volatile uint16_t corpus_result;
static jmp_buf jb;

__attribute__((noinline)) static void jump(void) { longjmp(jb, 7); }

int main(void) {
  int r = setjmp(jb);
  if (r == 0) {
    corpus_result = 0x1111u;   // pre-longjmp sentinel; must be overwritten
    jump();                    // non-local return back to setjmp with r = 7
  }
  corpus_result = (uint16_t)(0x2000u + r);   // expected 0x2007
  for (;;) __asm__ volatile("wai");
}
