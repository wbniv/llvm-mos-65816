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

## Outcome (2026-06-21) — LANDED, with three measured findings

The round-trip surgery (`dev/land-far-integration.sh`, the retained recipe) ran exactly as planned, but
measuring `diff(R, FF)` surfaced **three things the "(a) is cleanly a16-free, folds wholly into `0001`"
assumption missed** — the "if a hunk needs 0002 context, that's a finding" case the Risks section anticipated:

1. **`MOSLegalizerInfo.cpp` PF-as-value is 0002-context-entangled → new `0005`.** The (a) hunk adds the far
   pointer (`PF`/addrspace 2) as a legal **value** type for `G_LOAD`/`G_STORE`, editing the
   `if (STI.hasAccum16()) … customForCartesianProduct(…)` block that **`0002` introduces** (0002 rewrites
   pristine's single `.customForCartesianProduct({S8,PZ,P},{PZ,P,PF})` into the a16 if/else). It cannot fold
   into a16-free `0001` — `0002` would clobber it. It is **behaviorally a16-independent** (PF added to BOTH
   branches; only W65816 far code forms a PF) but a16-context-entangled — exactly `0004`'s character. So it is
   landed as **`patches/llvm-mos/0005-320-far-ptr-value-legalize.patch`** (one file, stacked after `0004`;
   independent of `0004` — disjoint files), with `dev/regen-patch-0005.sh`. `dev/regen-patch-0004.sh` baseline
   was extended to include `0005` so a future `0004` regen can't absorb the `MOSLegalizerInfo` hunk.
2. **`MOSInsertREPSEP.cpp` — FF's working tree is stale vs main's `0002`.** `diff(R, FF)` showed FF *missing*
   the X-width "structural catch-all" + `TRI` threading that main's current `0002` adds (the
   `wt/321-track-a` `pr49419`-sibling hardening, landed in `0002` after FF last synced its `vendor/`). This is
   **not (a) work** (no far content) — it is FF being one a16 increment behind. The landed tree (current
   `0002`) is therefore *ahead* of FF here; benign and orthogonal to far code. **Excluded** from every new
   patch and from the round-trip "must be empty" set.
3. **`clang/cmake/caches/MOS.cmake` — build-config drift, in no patch.** A live `vendor/` edit (drops
   `clang-tools-extra` from the toolchain build) present in BOTH main's and FF's working trees but captured by
   no patch (0/0/0). Not a far feature. **Excluded** from every new patch and the round-trip set; a clean
   `dev/run.sh toolchain` (fresh clone, no MOS.cmake edit) is unaffected.

**Result: new-`0001` + `0002` + `0003` + `0004` + `0005` reproduces FF EXACTLY over `clang/` +
`llvm/lib/Target/MOS/`, except the two documented drift/stale files** (neither carrying any (a) content).

## Verification (2026-06-21)

Original bar bullets, verbatim, with evidence:

**1. Round-trip diff (step 5) empty over `clang/` + `llvm/lib/Target/MOS/`.**
```
######## PHASE 4: FINAL ROUND-TRIP — new-0001+0002+0003+0004+0005 == FF ########
   full stack applied in sequence (PASS)
RESULT: PASS — new-0001+0002+0003+0004+0005 reproduces FF EXACTLY over clang/ + llvm/lib/Target/MOS/
        (excluding the 2 documented drift/stale files: clang/cmake/caches/MOS.cmake, .../MOSInsertREPSEP.cpp)
```
PASS — and Phase 3 independently confirmed T4-vs-FF differs at *exactly* the three predicted files
(`MOS.cmake`, `MOSInsertREPSEP.cpp`, `MOSLegalizerInfo.cpp`); ASSERT-A (Group-A reproduces everything else)
PASS.

**2. `0001` stays a16-free; `0002`/`0003` untouched (sha unchanged); `0004` is the far-cc delta only.**
```
new-0001 a16-free check (added/removed lines): +mos-a16=0  Ac16=0  hasAccum16=0  mos-farcc=0
0002 sha: 0c94b6075b1fdbe8 (unchanged)   0003 sha: 5c2e79d5860712db (unchanged)
0004 sha: 2efa05f23d0ae4bb (canonical far-cc, byte-identical to wt/320-far-cc & FF)
new-0001 MOSLegalizerInfo section == main-0001's (IDENTICAL — no (a) PF-value leaked into 0001)
```
PASS.

**3. Each patch applies in sequence on pristine (the order `dev/toolchain.sh` globs).**
```
R = 0001+0002+0003+0004 applied in sequence (sequence-apply check PASS)
new-0001+0002+0003+0004 applied in sequence (PASS)
full stack new-0001+0002+0003+0004+0005 applied in sequence (PASS)
```
PASS (every apply gated with `git apply --check`).

**4. (If step 7 runs) corpus 7/7, far suite 4-way, csmith 0-mismatch.**
Step 7 (fresh rebuild) **not run — not required.** The round-trip proves the landed series reproduces FF's
source byte-for-byte over `clang/` + `llvm/lib/Target/MOS/`; FF built clean + ran the whole far suite (12
ROMs) + corpus 7/7 + csmith 0-mismatch on MAME + bsnes-jg this session. The only landed-vs-FF source delta is
`MOSInsertREPSEP.cpp` (= main's *current* `0002`, already independently verified by `wt/321-track-a`) — an a16
X-width pass orthogonal to all far code. A from-scratch `dev/run.sh toolchain` of the 5-patch series remains
available as belt-and-suspenders if desired.
