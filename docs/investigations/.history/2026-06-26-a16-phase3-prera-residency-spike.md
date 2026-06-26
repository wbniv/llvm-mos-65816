| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/91ba959) | #321 a16 Phase-3 investigation: record B2 + post-RA-extension probe (both NO-GO) |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/fc74388) | #321 a16 Phase-3 close-out artifacts (verdict + spike diff + measure trigger line) |

<!--history-meta v1
91ba959	author	Will Norris
91ba959	added	44
91ba959	deleted	5
91ba959	files	1
91ba959	body	B2 (residency defaulted ON so the differential exercises it): correct\n(corpus 7/7, a16/k_ suite 66/66, csmith 200 0-mismatch, 196/196 verify-clean)\nbut net +530 B over the whole example+corpus set (41 worse, 6 better) ->\nfails net-neutral-or-better.\n\nPost-RA extension probe: NOT real. threadAccum16 already removes 100% of\nA-clean (resident) STAImag16->LDAImag16 pairs (0 survive in a16cmpaudit's\npost-pass MIR); the 220 remaining reloads are all A-dirty (the single $a16\nreused by an intervening 16-bit op), so the value genuinely lives in Imag16\nand post-RA cannot thread it. The residency benefit is intrinsically RA-level\n= the net-negative pre-RA residency. Nothing to salvage from the 6 winners.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
fc74388	author	Will Norris
fc74388	added	102
fc74388	deleted	0
fc74388	files	1
fc74388	body	Companion to the TODO.md close-out (landed via a concurrent commit on this hot\nshared tree). Records the trigger-check + pre-RA Ac16-residency spike that\nmeasured Phase 3 as net-negative (zero ZP-pressure relief, +24 B regression):\n - docs/investigations/2026-06-26-a16-phase3-prera-residency-spike.md (+ .diff)\n - dev/measure-zp-pressure.sh: explicit Phase-3 trigger (b) FIRE/defer line\n - plan: OUTCOME banner (trigger fired -> spike -> closed)\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
