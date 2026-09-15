/* examples/65816/rcundef2.c — deterministic repro for CAUSE #2 of the a16/xy16
 * "Using an undefined physical register" MachineVerifier failure, tracked as
 * tools/a16_fuzz.py KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"].
 *
 * CAUSE #2 (distinct from cause #1, which rcundef.c guards and which was FIXED in
 * MOSRegisterInfo::shouldCoalesce, fork patch 0002): the register ALLOCATOR binds a
 * PURE-VIRTUAL Imag16 value — one with no `$rcN` copy anywhere in its def/use chain at
 * coalescing time, so shouldCoalesce has no copy hint to act on — to a call-clobbered
 * `$rc` pair it is live across. The code runs CORRECTLY (the value happens to survive in
 * the pair at runtime; the L-system differential is green, 0x79C3, on both emulators);
 * this is a latent verify-only hazard pending an RA-interference-level fix (greedy RA /
 * LiveRegMatrix must treat the call's regmask clobber of the imaginary pair as
 * interference). See docs/plans/2026-06-29-a16-rc-undef-ra-machineverifier-fix.md.
 *
 * WHY THIS FILE EXISTS — read before editing.
 * The XFAIL's original primary witness was examples/snes/corpus/lsystem_sim.c `main`. It
 * stopped reproducing on 2026-08-01 when commit 903de3e (a 214-file idle-loop hygiene
 * sweep) rewrote that file's `for (;;) {}` to `for (;;) __asm__ volatile("wai")`. The
 * compiler did not change — the pinned inline-asm loop reshapes `main` enough that the
 * vulnerable live range is no longer formed. The XPASS guard then read as "the bug looks
 * FIXED" when the hazard was entirely untouched. This TU exists so the guard's repro is
 * owned by the compiler test-suite, not by a runnable demo slice that a hygiene sweep can
 * reshape out from under it. See docs/plans/2026-09-15-a16-rc-undef-pure-virtual-drift.md.
 *
 * Consequently:
 *   - There is deliberately NO idle loop here. This TU is never linked or run — it is a
 *     -verify-machineinstrs input only — so it needs no forward-progress-proof halt and
 *     must not acquire one.
 *   - It calls lsystem_gate_crc() unchanged from the shared header so the shape stays the
 *     one the differential corpus actually compiles; do not inline or reduce the kernel
 *     here, or the repro stops tracking the real thing.
 *
 * Expected today (tools/a16_fuzz.py known-issues asserts the -Os row on BOTH legs):
 *   +mos-a16  -O1/-O2/-O3/-Os/-Oz  -> FAIL "Using an undefined physical register"
 *                                     (main, `$x = COPY killed renamable $rc11`)
 *   +mos-xy16 -O1/-O2/-O3/-Os      -> FAIL, same signature
 *   both legs -O0                  -> clean (no such live range at -O0)
 *
 * If this file ever verifies CLEAN, that is an XPASS, not a pass: either the RA fix
 * landed (retire the KNOWN_ISSUES entry + promote to a positive gate) or this repro has
 * drifted the way lsystem_sim.c did (find a live witness and re-point the row). Do NOT
 * just delete the row.                                                                  */
#include "lsystem.h"

volatile uint16_t corpus_result;

int main(void) {
    corpus_result = lsystem_gate_crc();
    return 0;
}
