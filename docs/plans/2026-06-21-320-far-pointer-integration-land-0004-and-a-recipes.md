# #320 far-pointer integration — land 0004 (far-cc) + fold the (a) recipes into 0001

**Date:** 2026-06-21 · **Scope:** patch source-of-truth on `main` (no new codegen) · **Goal:** land the entire
#320 far-pointer line that has lived as gitignored `vendor/` recipes on worktrees — the far function pointer
(a) sub-project (backend Layers 1–3 + Gap A/B + the `__call_indir_far` mechanism + the clang F2 `far`
attribute + typed `far_fn_t` variable + `sizeof(far*)==4` + the `isFarSymbol` far_indir fix) folded into
**`0001`**, and the far-pointer calling-convention winner (Imag32) landed as **`0004`**.

## State discovered (2026-06-21)

- **None of the (a) work is in main's `0001`** (0 hits for isFarSymbol/buildFarAddrWords/__call_indir_far/
  MOSFarCall). The whole (a) sub-project is gitignored `vendor/` on `wt/320-far-followups`.
- **`wt/320-far-followups` is the verified target state.** Its `0001`/`0002` are **byte-identical to main's**
  (same sha); it has `0003` + `0004` stacked + all the (a) recipes applied; this session it built clean and
  ran the **whole far suite (12 ROMs) + corpus 7/7 + csmith 0-mismatch** on MAME + bsnes-jg. So the *combined*
  tree is already build-verified — the work here is to express it as patches, not to re-build.
- **`0004` (far-cc, Imag32 winner) applies cleanly on main's base** (apply-check passed, all 9 files), and was
  re-verified this session (4 variants 0xF3 both emulators; Imag32 70 B/50441 wins).
- `wt/320-far-cc` carries the canonical `0004` but against an **older** `0001`/`0002` (differ from main) — use
  it only for the `0004` patch text, not its 0001/0002.

## Plan (round-trip-verified patch surgery — no new build needed)

Let **FF** = `wt/320-far-followups/vendor/llvm-mos` (the verified target vendor tree). All scratch trees are
detached git worktrees of `vendor/llvm-mos` at pristine upstream `c798c31416f7`.

1. **Reference R** = pristine + `main 0001` + `main 0002` + `0003` + `far-cc 0004`. (No build.) This is FF's
   base *without* the (a) recipes.
2. **Extract the (a)-delta** = `diff(FF, R)` over `clang/` + `llvm/lib/Target/MOS/`. Because FF and R share the
   exact same `0001`/`0002`/`0003`/`0004`, this delta is purely the (a) recipes (0004's changes are subtracted
   out). Sanity: the delta touches the expected files (Attr.td, SemaDeclAttr/SemaType/CGExpr*/TypeBase.h/
   TypeProperties.td/ASTContext/TypePrinter/CodeGenTypes/CodeGenModule.h/Basic/Targets/MOS.cpp + the backend
   MOSInstructionSelector/MOSMCInstLower/MOSInstrInfo.h/MOSLegalizerInfo/MOSRegisterInfo/MOSCallLowering) and
   *nothing* a16/far-cc-specific.
3. **Build new-0001 source** = pristine + `main 0001` + apply the (a)-delta. The (a) work is a16-free and far-cc-
   independent, so it must apply on `0001` alone. (If a hunk needs 0002/0004 context, that's a finding — the
   (a) recipe wasn't truly a16-free; resolve by hand.) Regenerate **`0001`** from this tree (`dev/regen-patch-0001.sh`
   equivalent — diff vs pristine over 0001's owned files). new-`0001` = main-`0001` + the (a) recipes, a16-free.
4. **`0004`** = the far-cc `0004` patch text, re-verified to apply on `pristine + new-0001 + main-0002 + 0003`.
5. **ROUND-TRIP CHECK (the safety net):** `pristine + new-0001 + main-0002 + 0003 + 0004` → `diff` vs **FF** must
   be **empty** over `clang/` + `llvm/lib/Target/MOS/`. Empty ⇒ the patches reproduce the exact tree that was
   built + ran the full far suite green ⇒ verified without a rebuild.
6. **Land on main:** new-`0001` + `0004` into `patches/llvm-mos/`, + the `0004` regen script + `dev/farcc_*.sh`/
   `farcc_*.c` + `measure-far-cc.sh`/`probe-cycles.lua` + the upstream far-cc measurement note; commit.
   (`0002`/`0003` unchanged.) **Then sync the stale `main` status docs** — the far-cc study + the (a) line are
   marked in-progress on main's `agent-handoff.md` (the `wt/320-far-cc` row), `implementation-status.md`, and
   the far-cc parent plans, but both are done; flip them to landed/RESOLVED. (The worktree copies are already
   RESOLVED; main's never got the merge.)
7. **Belt-and-suspenders (optional):** a fresh `dev/toolchain.sh` build of the landed patches on a scratch
   worktree + `dev/run.sh corpus`/`far_*`/`farcc_*` — only if the round-trip diff is non-empty or any hunk
   needed manual resolution.

## Verification bar

- Round-trip diff (step 5) empty over `clang/` + `llvm/lib/Target/MOS/`.
- `0001` stays **a16-free** (grep the new hunks: no `+mos-a16`/`Ac16`/`hasAccum16`); `0002`/`0003` untouched
  (sha unchanged); `0004` is the far-cc delta only.
- Each patch applies in sequence on pristine (the apply order `dev/toolchain.sh` uses).
- (If step 7 runs) corpus 7/7, the far suite 4-way, csmith 0-mismatch.

## Risks

- **(a)↔0004 overlap in `MOSCallLowering.cpp`** — both touch lowerCall. The same-base diff (step 2) subtracts
  0004's hunks, so the (a)-delta should be clean; but if a hunk straddles both, step 3's apply on 0001-alone
  fails → resolve by hand, re-verify with the round-trip.
- **Contamination** — never regen `0001` on a tree that has `0002`/`0004` applied (it would absorb their
  changes to 0001's shared files). That is exactly why step 3 builds 0001+(a) *in isolation*.
- **Hot main tree** — commit only the patch files + harness; never stage `vendor/` (gitignored) or another
  worker's files.
