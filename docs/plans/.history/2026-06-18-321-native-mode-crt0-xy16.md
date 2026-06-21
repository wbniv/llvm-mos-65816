| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/05d98c6) | #321 native-mode crt0 — explicit DBR=0 contract + xy16 audit (VERIFIED) |

<!--history-meta v1
05d98c6	author	Will Norris
05d98c6	added	300
05d98c6	deleted	0
05d98c6	files	1
05d98c6	body	Adds the missing `phk; plb` (opcodes 4b ab) to `.init.50` in\n`platforms/snes/crt0.c`, making DBR=0 a *stated* contract rather than a\nreliance on the power-on reset default.  The 8-bit `abs` / R_MOS_ADDR16\nscalar-global path and the crt0's own MMIO writes are DBR-relative; without\nan explicit PHK/PLB a later bank-switch, MVN/MVP, or interrupt handler could\nsilently corrupt those accesses.  The native-16 path (R_MOS_ADDR24 long) is\nDBR-independent and unaffected.\n\nCompanion gate `dev/crt0native.sh` / `dev/run.sh crt0native`:\n  1. byte-exact `.init.50` preamble including phk/plb (4b ab after sep #$30)\n  2. native + emulation interrupt vectors present; RESET -> _start\n  3. 8-bit build corpus_result==0x2345 on MAME + bsnes-jg (DBR=0 at runtime)\n\nAlso updates docs/agent-handoff.md (DBR-relative contract note), docs/ROADMAP.md\n(DBR=0 amendment to the native-crt0 bullet), and adds docs/snes-bootup-sequence.md\n(full power-on -> main() walkthrough).\n\nVerified: crt0native PASS on MAME + bsnes-jg; corpus 7/7; a16abs/far-run/\nfar-bank1 PASS; fuzz 50/50 (seeds 1-50) 0 mismatch on the full +mos-xy16-\ncapable toolchain.  TODO item promoted to [x].\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
