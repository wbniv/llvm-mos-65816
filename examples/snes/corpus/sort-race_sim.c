/* Corpus slice: sorting race (quicksort / heapsort / mergesort), HAL-free. The differential
 * engine (dev/run.sh corpus-a16) checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on
 * MAME + bsnes-jg, -verify-machineinstrs clean. Shares examples/65816/sort-race.h with the
 * renderer (examples/snes/sort-race.c) and the host oracle (tools/sort-race-sim.c).
 *
 * The recursive sr_qsort / sr_msort exercise the reentrant soft-stack / frame-ABI path; the gate
 * also asserts all three sorts agree on the identity permutation (a self-check on the recursion).
 * sortrace_gate_crc() allocates its own arrays as locals — no static state needed. */
#include "../../65816/sort-race.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = sortrace_gate_crc();
    for (;;) {}
    return 0;
}
