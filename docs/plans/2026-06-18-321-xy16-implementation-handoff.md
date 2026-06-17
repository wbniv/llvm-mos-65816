# Handoff: xy16 Implementation (`wt/321-xy16`)

**Date:** 2026-06-18  
**Branch:** `wt/321-xy16`  
**Worktree:** `/home/will/SRC/llvm-mos-65816-xy16`  
**Main repo:** `/home/will/SRC/llvm-mos-65816` (branch `main`)

---

## Why you're in a worktree

`main` is being diagnosed for a seed-42 regression bisected to patch `0002`
(`patches/llvm-mos/0002-321-accum16.patch`) — a shared-path miscompile in the committed
backend patches (default and `+mos-a16` both produce `0xB226`; correct is `0xEC0D`).
That diagnostic work modifies `vendor/` in the main tree. Your xy16 work also modifies
`vendor/` — hence the isolation.

**Rule for this branch:** Never manually push to `origin/main` or rebase onto main until
the regression is diagnosed and its fix is committed to main. When both sides are done,
the merge-back is: `git rebase main` (from within this worktree) + verify the full suite,
then PR or fast-forward.

---

## First thing to do: build the toolchain

`vendor/` does not exist yet in this worktree — `dev/run.sh toolchain` clones llvm-mos
and applies all three patches automatically:

```bash
cd /home/will/SRC/llvm-mos-65816-xy16
dev/run.sh toolchain
```

**This should be fast** (~5-10 min, not the full 30-90 min cold build) because
`build/.ccache` is already symlinked to the main worktree's shared ccache, and the
patches in `wt/321-xy16` are identical to main at the branch point — near-100% cache hit.

Confirm the build took by checking `clang-23`'s mtime (not the stale `clang` symlink):
```bash
ls -lh build/llvm-mos-install/bin/clang-23
```

---

## What you're implementing

**Plan:** [`docs/plans/2026-06-17-321-xy16-index-register-mode.md`](2026-06-17-321-xy16-index-register-mode.md)

The plan pre-audited 7 design corrections and is ready to execute. Read it in full before
starting. Five layers, in order (each independently builds and can be diff-tested):

| Layer | What | Key files |
|-------|------|-----------|
| 1 | Feature flag, Xc16/Yc16 register defs | `MOSFeatures.td`, `MOSInstrFormats.td`, `MOSSubtarget.h/.cpp`, `MOSRegisterInfo.td` |
| 2 | 16-bit index instructions + TXA16/TAX16 transfer pseudos | `MOSInstrLogical.td` |
| 3 | X-flag lattice in `MOSInsertREPSEP` (dual-tracking `placeIntraBlock`) | `MOSInsertREPSEP.cpp` |
| 4 | Static-stack + soft-stack spill for Xc16/Yc16 | `MOSInstrInfo.cpp`, `MOSRegisterInfo.cpp` |
| 5 | `selectXY16` selector (minimal; fires when RA assigns to Xc16/Yc16) | `MOSInstructionSelector.cpp` |

**Start with Layer 1** — it's the smallest change, touches only `.td` files, and either
TableGen accepts it or it fails loudly. Layer 1 success gates all later layers.

---

## Build / test commands

All identical to main — the worktree runs `dev/run.sh` from its own root (`/work` inside
the container = `/home/will/SRC/llvm-mos-65816-xy16`):

```bash
dev/run.sh toolchain          # rebuild after vendor/ edits
dev/run.sh corpus             # Tier-1 correctness gate (expect 7/7)
dev/run.sh fuzz 50 1          # differential fuzzer (expect 50/50, 0 mismatch)
dev/run.sh a16local           # quick native-s16 sanity (should be unaffected by xy16)
```

For xy16-specific tests (once Layer 5 exists):
```bash
dev/run.sh xy16basic          # new test: load/compare/inc loop using X16
dev/run.sh xy16spill          # new test: forced static-stack spill of X16
dev/run.sh xy16spillr         # new test: recursive soft-stack spill of X16
```

**Always run on a quiet box** — concurrent Docker/MAME load flakes MAME timing.

The correctness bar: host-computed == default == `+mos-xy16` on both MAME and bsnes-jg,
plus `-verify-machineinstrs` clean. See `docs/agent-handoff.md` for the exact
`mos-clang` incantation.

---

## Commit discipline for this branch

- **Stage only your files.** `vendor/` is gitignored, so it never shows in `git status`.
  Stage `.td`, `.cpp`, `.h`, plan docs, patch — nothing else.
- **Verify `git diff --cached --name-only`** matches exactly what you touched.
- **Don't run `dev/regen-patch.sh` until a logical checkpoint** (e.g., after each Layer).
  The hook `regen-md-history` snapshots plan docs; `audit-plan-deferrals` writes to
  `TODO.md`'s Inbox — triage before committing.
- **Co-Authored-By line** at the end of every commit message:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Do NOT push to `origin/main`.** This branch is isolated. When ready to merge, check
  with the user first.

### Patch regeneration

When ready to regenerate `patches/llvm-mos/0002-321-accum16.patch`:
```bash
dev/regen-patch.sh
```
Run this ONLY from the worktree root (`/home/will/SRC/llvm-mos-65816-xy16`) — never from
the main worktree while this branch has vendor/ edits, or you'll get cross-contamination
(the exact bug documented in `docs/plans/2026-06-17-321-unify-1b-1c-peephole-into-native.md`
§"What actually landed where").

---

## Key risks from the plan (pre-audited)

1. **Register numbers 0x500–0x503**: above Imag16's upper bound (0x28F). After Layer 1
   build, verify no collision in `MOSGenRegisterInfo.inc` (`grep '0x500'`).
2. **TXA16 PseudoInstExpansion vs MOSMCInstLower**: `T_A` is lowered in
   `MOSMCInstLower.cpp` (not via PseudoInstExpansion). After Layer 2, confirm the new
   `TXA16` PseudoInstExpansion path fires rather than the MCInstLower `T_A` case. If it
   doesn't, add `TXA16`/`TAX16`/`TYA16`/`TAY16` cases to `MOSMCInstLower.cpp`.
3. **Combined REP #$30**: only emit when `hasAccum16() && hasIndex16()` AND both flags
   switch to the same target mode in the same `insertSwitch` call (Layer 3).
4. **`XHigh=1` on `CPX_Immediate`**: `CPXImm16`/`CPYImm16` expand to
   `CPX_Immediate16`/`CPY_Immediate16` (which have `XLow=1`) — orthogonal, but verify
   the `XHigh=1` 8-bit forms don't interfere.
5. **Layer 5 is minimal without legalizer changes**: `selectXY16` only fires when RA
   assigns to Xc16/Yc16 (e.g., via spill). The legalizer integration that makes xy16
   fire broadly is the follow-on task — don't attempt it in this pass.

---

## What main is doing (don't collide)

The main worktree is diagnosing the seed-42 regression. Suspect is `0001` (far-pointer
patch — only committed patch that changes *default* 65816 codegen). Diagnostic work may
modify files in `vendor/llvm-mos/llvm/lib/Target/MOS/` related to MOSCombiner, MOSInstrInfo.

Your xy16 work touches DIFFERENT files (MOSFeatures.td, MOSRegisterInfo.td,
MOSInstrLogical.td, MOSInsertREPSEP.cpp, new instructions). The only overlap risk is if
the regression fix also touches MOSInsertREPSEP.cpp or MOSInstrLogical.td — check
`git log main --oneline -5` before regenerating the patch to see if the fix landed.

---

## Merge-back checklist (for future reference)

Before merging `wt/321-xy16` back to `main`:
- [ ] Regression on main diagnosed and fix committed
- [ ] All 5 Layers built and `-verify-machineinstrs` clean
- [ ] `xy16basic`, `xy16spill`, `xy16spillr` tests PASS on both MAME + bsnes-jg
- [ ] Corpus 7/7, `fuzz 50 1` 50/50 (with `+mos-xy16` fuzzer track enabled)
- [ ] `0002` regenerated and round-trips (`dev/regen-patch.sh` + round-trip check)
- [ ] `git rebase main` clean (no conflicts)
- [ ] Full suite re-run post-rebase
