| Date | Change |
|------|--------|
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/3257fea) | feat(snes): #19 π spigot + Monte-Carlo demo (examples/snes/spigot.c) |

<!--history-meta v1
3257fea	author	Will Norris
3257fea	added	291
3257fea	deleted	0
3257fea	files	1
3257fea	body	Rabinowitz-Wagon π spigot + Monte-Carlo SNES demo (#19 of the compiler\nstress-test battery). Left panel streams π digits via a right-to-left\ncarry sweep across a 676-element uint16 array with uint32 intermediates\n(__udivmodsi4 + __mulsi3 per iteration). Right panel scatters MC darts\n(xorshift16 RNG → 16×16→32 r² test) onto a BitmapCanvas.\n\nGate (task pi, dev/run.sh corpus-a16):\n  PI_GATE_DIGITS=1, PI_GATE_THROWS=256 → hash 0x771D\n  host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg\n  corpus-a16: 10/10 PASS (pi_sim executes in ~120 frames < 180-frame window)\n  disasm: __udivmodsi4=2 __mulsi3=3 rep/sep=52\n\nTiming calibration: clang emits __udivmodsi4 (combined div+mod) rather\nthan separate __udivsi3/__umodsi3; signed MC multiplies hit the slow\n24–32 iteration path in __mulsi3. PI_GATE_THROWS capped to 256 to keep\ntotal under the 180-frame corpus-a16 window (vs the original 2048=~163\nframes for MC alone).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
