| Date | Change |
|------|--------|
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/f62f8c6) | #321 Increment 1a: REP/SEP-insertion pass + opt-in 16-bit-A feature (non-breaking) |

<!--history-meta v1
f62f8c6	author	Will Norris
f62f8c6	added	159
f62f8c6	deleted	0
f62f8c6	files	1
f62f8c6	body	First slice of M2/#321 (16-bit register mode). The implementation surfaced the\ncrux: the accumulator is modeled as 8-bit A only — there is no 16-bit\naccumulator register, so a 16-bit lda/sta needs a dual-width A/C aliasing\nregister (the genuine hard core of #321). So Increment 1 is split: 1a = the\nREP/SEP-insertion *mechanism* (this commit, demonstrable via a register-free\n16-bit STZ next); 1b = the dual-width accumulator register.\n\nThis commit lands the reusable core, captured as patches/llvm-mos/0002-321-\naccum16.patch (the eventual upstream #321 diff):\n- FeatureAccum16 (-mattr=+mos-a16) — opt-in, NOT implied by FamilyW65816, so\n  default mosw65816 (far pointers) and 6502 codegen are untouched.\n- MOSInsertREPSEP MachineFunctionPass — walks each block, reads the existing\n  MC-layer MLow/MHigh width TSFlags (the same signal MOSMCELFStreamer uses for\n  $ml/$mh mapping symbols), tracks the M mode, and inserts REP #$20 / SEP #$20\n  at transitions; functions begin/end in 8-bit A. Registered in addPreEmitPass\n  before branch relaxation so the added REP/SEP affect branch distances.\n- Wiring: subtarget accessor hasAccum16(), pass-registry init, CMake.\n\nNon-breaking by construction: the pass early-returns unless hasAccum16() (off by\ndefault) and is a no-op until a 16-bit (MLow) instruction exists. Verified:\ntoolchain rebuilds clean; 6502 corpus 7/7 on the patched toolchain.\n\nNext (1a part 2): a 16-bit STZ form (MLow=1) + feature-gated legalizer/selector\nfor `*g16 = 0`, so the pass brackets it -> REP #$20; stz; SEP #$20, verified at\ndisasm + on both emulators + smaller than the 8-bit build.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
