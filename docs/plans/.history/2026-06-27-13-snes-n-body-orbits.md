| Date | Change |
|------|--------|
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/9369ced) | chore(todo): mark biohack.net cache headers done (v1.0.91) |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/cab7d24) | docs(snes-nbody): close out #13 — fix plan publication section + TODO done + cookbook entry |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/dbec1b5) | docs(plan): mark #13 N-body publish step PASS (biohack.net/nbody/ live, v1.0.88) |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/f0eead4) | feat(snes): #13 N-body orbits demo (examples/snes/nbody.c) |
| [2026-06-27](https://github.com/wbniv/llvm-mos-65816/commit/a659f72) | docs(plan): #13 N-body orbits — Newtonian gravity · Verlet · 1/r² |

<!--history-meta v1
9369ced	author	Will Norris
9369ced	added	414
9369ced	deleted	0
9369ced	files	1
9369ced	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
cab7d24	author	Will Norris
cab7d24	added	0
cab7d24	deleted	0
cab7d24	files	0
cab7d24	body	Plan: fix --site (biohack.net not indri.studio), fill actual selfcheck args, record\ncommit/tag. TODO.md done: "publish pending" → published biohack.net/nbody/. Cookbook:\nadd N-body to worked-examples table (__mulsi3 + __udivsi3 + noinline RA pattern).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
dbec1b5	author	Will Norris
dbec1b5	added	0
dbec1b5	deleted	0
dbec1b5	files	0
dbec1b5	body	Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
f0eead4	author	Will Norris
f0eead4	added	0
f0eead4	deleted	0
f0eead4	files	0
f0eead4	body	Three-body Newtonian gravity (Sun + Earth + Jupiter) integrated by Symplectic\nEuler on a 128×128 2bpp BitmapCanvas with CGRAM palette fade. Codegen under\ntest: 16×16→32 __mulsi3 (r²), __udivsi3 (GRAV_K/r² force), 32-bit mul\n(directional force). No far pointers → full 5-way differential bar.\n\nGate: NBODY_GATE_STEPS=32 → corpus_result=0xCC65. host == default@MAME ==\n+mos-a16@MAME == +mos-xy16@MAME == a16@bsnes-jg. Disasm: __udivsi3=2\n__mulsi3=6 rep/sep=82. corpus-a16: 12/13 PASS (rdiff pre-existing).\n\nnbody_force_pair extracted as noinline to cap register pressure and avoid\n"undefined physical register" verify-machineinstrs crash in the large inlined\nform (backend RA limitation with 6+ live int32_t values across blocks).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
a659f72	author	Will Norris
a659f72	added	0
a659f72	deleted	0
a659f72	files	0
a659f72	body	Plan for compiler stress-test demo #13: 3-body orbit simulation under\nNewtonian gravity (Sun + 2 planets), Symplectic Euler integration,\n16×16→32 __mulsi3 + __udivsi3 (1/r² force) hot path, CGRAM palette\ndimming for fading trails, full 5-way differential bar.  Publishes to\nbiohack.net/nbody/.  TODO.md and plan-index.md updated.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
