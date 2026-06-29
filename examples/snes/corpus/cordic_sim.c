/* Corpus slice: #12 CORDIC rotator, HAL-free. Differential engine (dev/run.sh corpus-a16) checks it
 * 5 ways: host == default == +mos-a16 == +mos-xy16 on MAME + bsnes-jg, -verify-machineinstrs clean.
 * Shares examples/65816/cordic.h with the renderer (examples/snes/cordic.c) and the host oracle
 * (tools/cordic-sim.c).
 *
 * This is the MULTIPLY-FREE payload: cordic_gate_crc folds the rotation (cordic16_sincos) and vectoring
 * (cordic16_atan2) shift-add sweeps — so the disasm of this object has ZERO __mulsi3/__divsi3/variable-shift
 * libcalls (dev/cordic.sh §3 asserts that, inverted vs every other demo). corpus_result is declared volatile
 * before main() so the build leaves it in WRAM for the emulator harness to read back. */
#include "../../65816/cordic.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = cordic_gate_crc();
    for (;;) {}
    return 0;
}
