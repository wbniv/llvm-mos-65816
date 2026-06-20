# #321 xy16 — Csmith runtime miscompiles (HANDOFF to the `wt/321-xy16` owner)

**Status:** found by the Csmith sweeps (Phase 4, seeds 101–300; then 301–500), **not yet fixed**. Handed off
to the xy16 work area (`wt/321-xy16`) — these are `+mos-xy16`-only defects; a16 is correct in every case.

## The defects (TWO so far — likely a shared root cause)

```
seed 247:
  default@MAME = a16@MAME = a16@bsnes-jg = 0x80FE   (correct)
  xy16@MAME    = 0x7C73                              (WRONG)
  repro:  dev/run.sh fuzz --gen csmith 1 247

seed 445:
  default@MAME = a16@MAME = a16@bsnes-jg = 0x0D1D   (correct)
  xy16@MAME    = 0x35E7                              (WRONG)
  repro:  dev/run.sh fuzz --gen csmith 1 445
```
Both: a16 (and default + bsnes) agree; only `+mos-xy16`@MAME diverges. Two independent seeds with the same
signature strongly suggest **one** xy16-index-codegen bug. Repros are deterministic (regenerated from the
seed). Across the same 200-seed ranges the a16 path is clean (0 crash, 0 a16 mismatch).

`+mos-a16` agrees with the trusted DEFAULT build on **both** emulators; only the 16-bit-index `+mos-xy16`
mode diverges. So the bug is in the xy16 index-register codegen (the `selectXY16` / `requiredXWidth` /
REP-SEP X-width territory — cf. the landed X-flag-lattice fix `55ec505`), not in the s16-accumulator path.

## Why it's not code-XFAIL'd in the gate

The Csmith harness only classifies **compile-log** failures as XFAIL (`KNOWN_ISSUES`/`classify_known` in
`tools/a16_fuzz.py`). seeds 247/445 are **runtime value** mismatches (they compile clean), for which there is
no per-seed XFAIL mechanism. So the differential gate will *report* these seeds as FAILs if the 101–300 /
301–500 ranges are re-swept — expected until the xy16 owner fixes them. (Adding a per-seed runtime-mismatch
allowlist to the csmith runner is a possible harness follow-up if this lingers.)

## Triage starting points (for the xy16 owner)

- Repro a seed: `dev/run.sh fuzz --gen csmith 1 247` (or `1 445`) — writes `build/fuzz-triage/csmith-seed-00NNN.{c,txt}`.
- **Diff the two repros against each other** — two seeds, one signature ⇒ a shared root cause; the smaller of
  the two triage `.c` files is the better starting point.
- Compare the xy16 vs a16 disasm of the divergent function; the value differs in a way (`0x7C73` vs `0x80FE`)
  consistent with a wrong index width on an indexed load/store or an `X`-governed compare/transfer (the class
  the `requiredXWidth` lattice governs).
- The a16 leg is the oracle here (matches default + bsnes), so diffing xy16 against a16 isolates the
  X-width-specific instruction.

## Owner / coordination

xy16 work lives on `wt/321-xy16` (`git worktree list`). This note + the TODO entry under the xy16 area are the
handoff; the a16 worker did **not** touch xy16 codegen. The companion Csmith find from the same sweep — the
a16 `G_MERGE_VALUES` s8×4→s32 crash (seed 113) — was fixed separately (a16 domain), see
[s32-merge plan](2026-06-20-321-a16-s32-merge-s8x4-legalizer.md).
