# #131 — Far-Pointer Spill Funnel (`farspill`)

**Status:** DONE + PUBLISHED 2026-08-03 — clean positive, no new compiler defect. Round 7 compiler-probe ROM.

## Question and pressure shape

Does the four-byte `Imag32` spill support from patch `0018` survive substantially more pressure
than its original single-pointer reproducer? The kernel creates ten runtime-derived far pointers
from volatile addresses in ROM bank 1, keeps all ten live across a real stateful 32-bit multiply
call, and dereferences them only afterward. The values cannot be legally rematerialized.

The visualization turns this into colored pointer ribbons entering a narrow register funnel.
Magenta branches represent parked values; samples recovered through the far pointers determine the
exit paths. It is driven by additional calls to the same stress kernel after the fixed gate result.

## Gates and result

- Host oracle: `0x7F3B` over 96 pressure rounds.
- Greedy-RA MIR contains seven four-byte spill slots, expanded to 28 byte stores and 28 byte reloads.
- The standing malformed-producer gate finds eight `LDImm` instructions and confirms every
  destination is hardware A/X/Y, never `Imag32`.
- `-verify-machineinstrs` passes for a16 and xy16.
- Host == a16 == xy16 == `0x7F3B` on both MAME and bsnes-jg after 420 frames/ticks.

Result: clean positive. Patch `0018` generalizes to multiple interleaved far-pointer spills without
value corruption or malformed MIR. Run with `dev/run.sh farspill`.

## Publication

- [biohack.net demo](https://biohack.net/snes/farspill/) — release `v1.0.370`, commit `8bde167`
- [indri.studio demo](https://indri.studio/apps/llvm-mos-65816/snes/farspill/) — release `v0.1.140`, commit `3ca41be`
- Published ROM: `build/farspill-a16.sfc`
- SHA-256: `541e77a5b47803c41c29c8f9874d97f51e25006c0c325baa02c7bf560343058f`

Both live pages and both catalog builds include the demo; both live ROM downloads match the local
SHA-256.
