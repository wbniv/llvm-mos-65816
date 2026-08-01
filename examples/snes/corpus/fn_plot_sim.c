/* Corpus slice: fn-plot recursive-descent parser, HAL-free.
 * Differential engine (dev/run.sh corpus-a16) checks it 5 ways:
 * host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean.
 * Stresses: soft-float libcalls (__mulsf3/__addsf3/__subsf3/__divsf3) + recursive
 * call graph (fn_eval_expr→fn_eval_term→fn_eval_factor) + soft-stack pressure. */
#include <stdint.h>
volatile uint16_t corpus_result;
#include "../../65816/fn_plot.h"

int main(void) {
    corpus_result = fn_gate_crc();
    for (;;) __asm__ volatile("wai");
    return 0;
}
