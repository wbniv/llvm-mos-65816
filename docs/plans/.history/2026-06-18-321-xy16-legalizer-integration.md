| Date | Change |
|------|--------|
| [2026-06-18](https://github.com/wbniv/llvm-mos-65816/commit/5d5e1f5) | #321 1e fix: G_MERGE_VALUES explicit zero-high-byte in tryAbsoluteIndexedAddressing (seed-56 crash) |

<!--history-meta v1
5d5e1f5	author	Will Norris
5d5e1f5	added	309
5d5e1f5	deleted	0
5d5e1f5	files	1
5d5e1f5	body	The KnownBits truncation path in tryAbsoluteIndexedAddressing (fires when an\ns16 offset has ≤8 active bits) created a G_TRUNC to s8 but left the original\nNewOffset:s16 Imag16 pair alive with a dead high lane.  During live-range\nsplitting the RA emits "undef %d.sublo = COPY %s.sublo" — only the low byte\nis copied — and the subsequent spill of the full Imag16 pair reads the\nundefined high byte → "Using an undefined physical register" crash.\n\nFix: before the G_PTR_ADD, insert G_TRUNC + G_CONSTANT(0) + G_MERGE_VALUES\nto build an explicit s16 value whose high byte is definitionally 0.  Replace\nall uses of NewOffset with the new explicit-s16 (except the G_TRUNC itself),\nthen use the s8 Lo as the index.  GPR (s8) spills never have the Imag16\npartial-define issue.\n\nVerified: seed-56 compiles clean under -mllvm -verify-machineinstrs with\n+mos-a16; corpus 7/7; xy16basic/spill/spillr PASS.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
