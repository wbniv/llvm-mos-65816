/* Corpus slice: L-system string-rewriting gate, HAL-free. Differential engine (dev/run.sh corpus-a16)
 * checks it 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify clean. Shares
 * examples/65816/lsystem.h with the renderer (examples/snes/lsystem.c) and the host oracle
 * (tools/lsystem-sim.c).
 *
 * lsystem_gate_crc rewrites the axiom GEN generations IN PLACE in a grown char buffer — using memmove
 * (overlapping shift) + memcpy (write the production) + strlen (its length), the string-libcall corner —
 * then a turtle interprets the result with a `[`/`]` bracket push/pop stack, folding the path into a
 * CRC16. No pointers leave bank 0, so it is a full 5-way test; the byte/integer ops are exact, so host
 * and target must agree bit-for-bit. */
#include "../../65816/lsystem.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = lsystem_gate_crc();
    for (;;) {}
    return 0;
}
