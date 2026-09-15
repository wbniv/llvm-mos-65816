// sjcompat.h — setjmp/longjmp declarations shared by the Cluster-G stress demos
// (#116 backtrack, #117 csrjmp, #118 retryjmp) and their host oracles.
//
// On the host, <setjmp.h> is the real thing. On the mos target the declarations are
// mirrored inline rather than #included, for the same reason corpus/setjmp_sim.c does
// it: the corpus-a16 verify-machineinstrs leg compiles with `--target=mos` and NO
// `--config`, so it has no -isystem path to the platform libc headers. Keeping every
// Cluster-G translation unit header-free there lets the full differential (verify +
// default/+mos-a16/+mos-xy16 @ MAME + bsnes-jg) run over the same sources the SNES
// demo ROMs build from. The inline decls are byte-layout- and codegen-identical to
// mos-platform/common/include/setjmp.h (jmp_buf = ret_addr[2], s[1], sp[2], csrs[14]).
//
// The 65816-native implementation under test is platforms/snes/setjmp.S — see
// docs/investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md (bug #35)
// and docs/plans/2026-07-02-35-setjmp-longjmp-65816-fix.md.

#ifndef SJCOMPAT_H
#define SJCOMPAT_H

#ifdef __mos__

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

#else  /* host oracle */

#include <setjmp.h>

#endif

#endif /* SJCOMPAT_H */
