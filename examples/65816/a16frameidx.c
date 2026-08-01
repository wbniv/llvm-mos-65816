// examples/65816/a16frameidx.c — #321 regression for the eliminateFrameIndex /
// CmpBrAbsImm16 frame-index scramble (root-caused via c-torture 20071210-1; the one-line
// fix cleared 13 differential miscompiles). Plan:
// docs/plans/2026-06-19-321-cmpbrabsimm16-frameindex-elimination-scramble.md
//
// Under +mos-a16 LTO a stack-resident array compared element-by-element against constants
// folds each load+compare+branch into the CmpBrAbsImm16 pseudo, whose frame-index ADDRESS
// operand sits immediately before the COMPARE immediate. The buggy
// MOSRegisterInfo::eliminateFrameIndex took the displacement from the operand after the
// frame index (the compare value) instead of the frame index's own offset, so every s[i]
// read resolved to base+compareImm instead of base+2*i -> wrong values. Fixed: the loads
// resolve to base+2*i, the checks pass -> corpus_result == 0x4321 on
// host == default == +mos-a16 == +mos-xy16 (MAME + bsnes-jg).
//
// `fill` is noinline and stores values sourced from VOLATILE globals so the optimizer
// cannot const-fold the array away or fold the comparisons through it — the stack slots
// and the six folded compares survive to selection (where the static/zero-page stack +
// CmpBrAbsImm16 path is taken). `check` is noinline so it owns the stack frame (the entry
// `main` loops forever and does not). Drive: dev/run.sh a16frameidx.

// volatile: the stored values (and thus the compares) cannot be const-propagated.
volatile unsigned short ev0 = 4, ev1 = 3, ev2 = 2, ev3 = 1, ev4 = 11, ev5 = 12;
volatile unsigned short corpus_result;

__attribute__((noinline)) void fill(unsigned short *p) {
  p[0] = ev0; p[1] = ev1; p[2] = ev2; p[3] = ev3; p[4] = ev4; p[5] = ev5;
}

__attribute__((noinline)) int check(void) {
  unsigned short s[6];
  fill(s);  // s = {4,3,2,1,11,12} on the static/zero-page stack
  // Each compare folds to CmpBrAbsImm16 reading s[i] at frame + 2*i.
  if (s[0] != 4 || s[1] != 3 || s[2] != 2 || s[3] != 1 || s[4] != 11 || s[5] != 12)
    return 0;             // any wrong-offset read trips here
  return 0x4321;          // echoes s[0..3] = 4,3,2,1 — a recognizable "all correct"
}

int main(void) {
  int r = check();
  corpus_result = (unsigned short)(r ? r : 0xDEAD);
  for (;;) __asm__ volatile("wai");
}
