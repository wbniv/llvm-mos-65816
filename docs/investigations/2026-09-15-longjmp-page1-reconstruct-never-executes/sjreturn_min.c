/* Minimal repro for the 2026-09-15 longjmp page-1-reconstruct defect.
 *
 *   docs/investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md
 *
 * Build + run (bsnes-jg, no SPC700 IPL needed):
 *
 *   T=build/llvm-mos-install/bin
 *   $T/mos-clang --config build/install/bin/mos-snes.cfg -mcpu=mosw65816 -Os \
 *       -Wl,-Map=/tmp/sjreturn.map -o /tmp/sjreturn.sfc \
 *       docs/investigations/2026-09-15-longjmp-page1-reconstruct-never-executes/sjreturn_min.c
 *   python3 tools/snes-checksum.py /tmp/sjreturn.sfc
 *   V=$(awk '$NF=="corpus_result"{print $1; exit}' /tmp/sjreturn.map)
 *   build/jgxcheck /tmp/sjreturn.sfc vendor/bsnes-jg/Database "0x$V" 2 0xF00D 300 /tmp/sjreturn.png
 *
 * Expected once the defect is fixed: corpus_result == 0xF00D.
 * Observed 2026-09-15: corpus_result == 0x1111 — `runner`'s `rts` reads its return
 * address out of the ZERO PAGE, because longjmp left the hard stack pointer at $00xx.
 *
 * It is header-free for the same reason corpus/setjmp_sim.c is: the a16/xy16
 * -verify-machineinstrs leg compiles with `--target=mos` and no `--config`.
 */
#include <stdint.h>

struct __jmp_buf_tag { void *ret_addr; char s; void *sp; char csrs[14]; };
typedef struct __jmp_buf_tag jmp_buf[1];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunknown-attributes"
#pragma clang diagnostic ignored "-Wignored-attributes"
__attribute__((preserve_none, leaf)) int setjmp(jmp_buf src);
#pragma clang diagnostic pop
void longjmp(jmp_buf dst, int arg);

volatile uint16_t corpus_result;
static jmp_buf jb;

__attribute__((noinline)) static void go(void) { longjmp(jb, 1); }

/* The one thing corpus/setjmp_sim.c never does: RETURN from the setjmp frame. */
__attribute__((noinline)) static uint16_t runner(void) {
    if (setjmp(jb) == 0) go();
    return 0xF00Du;
}

int main(void) {
    corpus_result = 0x1111u;
    corpus_result = runner();
    for (;;) __asm__ volatile("wai");
    return 0;
}
