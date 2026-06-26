# Fix the far-pointer `G_PHI(p2)` backend gap

## Context

A far (addrspace 2) pointer used as a **loop induction variable** —
`for (; n; p++) *p = v;` — crashes the MOS backend:

```
unable to legalize instruction: %N:_(p2) = G_PHI ...
```

This is valid C that a compiler should never choke on. The MOS GlobalISel
legalizer declares `G_PHI` legal only for `{S1, S8, P, PZ}` (8/16-bit scalars,
near pointer p0, zero-page pointer p1) — **not** the 32-bit far pointer `p2`
(`PF`). A far pointer carried across a loop back-edge forms a `G_PHI(p2)` with
no legalization action, so the backend aborts.

This is a **pre-existing, latent gap**, independent of `+mos-a16` and of the
far-memset fix (commit `a81874d`). It was surfaced this session while writing
`platforms/snes/mem-far.c`, and worked around there by writing the loop
**index-style** (`for(i…) ptr[i]=v;` — phi on the integer index, far address
recomputed each iteration). That workaround is correct but is a constraint
every user far-loop would otherwise hit. The note also records a subtlety:
even clean `i32`-phi-plus-`inttoptr` source re-forms the `p2` phi (the IR
optimizer sinks the `inttoptr` into the phi), so **no source rewrite that ends
in a far-pointer IV escapes the crash** — the fix must live in the backend.

**Intended outcome:** `for(;n;p++) *p=v;` (and any far-pointer-IV loop) compiles
and runs correctly, value-identical on MAME + bsnes-jg. The `mem-far.c`
index-style code stays as-is (equally correct, arguably clearer); this just
removes the backend landmine.

## Approach

Custom-legalize a far-pointer `G_PHI` by converting it to an **s32 phi**:
`G_PTRTOINT` each incoming pointer value (at the end of its predecessor block),
build the phi on s32, then `G_INTTOPTR` the result back to `p2` after the phi.
This is exactly the ptrtoint/inttoptr bridge that far load/store and
`legalizePtrAdd` already use, and it hands off to the **already-proven**
`narrowScalar`-of-`G_PHI(s32)`→bytes path (any `i32` loop counter exercises it).

### Why this is stable (investigated, not assumed)

- The GISel **legalization artifact combiner has no `G_PHI` handler**
  (`LegalizationArtifactCombiner.h` `tryCombineInstruction` switch — no PHI
  case), and `G_INTTOPTR`/`G_PTRTOINT` are **not artifacts** (`Legalizer.cpp`
  `isArtifact()`). So the s32-phi + inttoptr/ptrtoint will **not** be recombined
  back into a `p2` phi. The memory note's "artifact combiner re-forms it" refers
  to the *IR-level* sink-into-phi (pre-GISel); it does not apply post-IRTranslation.
- The exact insertion-point mechanism mirrors LLVM's own
  `LegalizerHelper::widenScalar` G_PHI handler
  (`vendor/llvm-mos/llvm/lib/CodeGen/GlobalISel/LegalizerHelper.cpp:3306`):
  conversions for incoming values go at `OpMBB.getFirstTerminatorForward()`;
  the def conversion goes after the block's phis (`getFirstNonPHI()`).

### Files to modify

**1. `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp`** (the fix)

- **Legality rule** (line 408): add `.customFor({PF})` to the `G_PHI` builder.
  `PF` (`LLT::pointer(2,32)`) is already in constructor scope (line 75). Purely
  additive — every other type still takes the existing
  `legalFor / widenScalarToNextMultipleOf / maxScalar / unsupported` chain, so
  **zero regression risk** to existing shapes.

  ```cpp
  getActionDefinitionsBuilder(G_PHI)
      .legalFor({S1, S8, P, PZ})
      .customFor({PF})                       // #321: far-ptr IV → s32 phi
      .widenScalarToNextMultipleOf(0, 8)
      .maxScalar(0, S8)
      .unsupported();
  ```

  *Scope:* `PF` (p2) only. `PFP` (p3) is memory-only — never a register/phi
  value — so `G_PHI(p3)` cannot arise; it stays `.unsupported()` (no change,
  no regression).

- **Dispatch** (in `legalizeCustom`, the switch at line 541; add under the
  "Control Flow" group near `G_BRCOND`):

  ```cpp
  case G_PHI:
    return legalizePhi(Helper, MRI, MI);
  ```

- **New handler** `legalizePhi`, modeled on `legalizePtrAdd` (line 1770) for the
  builder idiom and on `widenScalar`'s G_PHI case (LegalizerHelper.cpp:3306) for
  insertion points:

  ```cpp
  bool MOSLegalizerInfo::legalizePhi(LegalizerHelper &Helper,
                                     MachineRegisterInfo &MRI,
                                     MachineInstr &MI) const {
    MachineIRBuilder &Builder = Helper.MIRBuilder;
    Register Dst = MI.getOperand(0).getReg();
    LLT IntTy = LLT::scalar(MRI.getType(Dst).getSizeInBits()); // s32 for p2

    Helper.Observer.changingInstr(MI);
    // ptrtoint each incoming far-ptr value at the end of its predecessor block.
    for (unsigned I = 1, E = MI.getNumOperands(); I < E; I += 2) {
      MachineBasicBlock &Pred = *MI.getOperand(I + 1).getMBB();
      Builder.setInsertPt(Pred, Pred.getFirstTerminatorForward());
      auto Int = Builder.buildPtrToInt(IntTy, MI.getOperand(I).getReg());
      MI.getOperand(I).setReg(Int.getReg(0));
    }
    // Retype the phi def to s32, then inttoptr back to p2 after all phis.
    Register NewDst = MRI.createGenericVirtualRegister(IntTy);
    MI.getOperand(0).setReg(NewDst);
    MachineBasicBlock &MBB = *MI.getParent();
    Builder.setInsertPt(MBB, MBB.getFirstNonPHI());
    Builder.buildIntToPtr(Dst, NewDst);
    Helper.Observer.changedInstr(MI);
    return true;
  }
  ```

  The `changingInstr/changedInstr` bracket re-queues the now-`s32` phi for the
  standard narrow-to-bytes legalization; the new `G_PTRTOINT(p2→s32)` /
  `G_INTTOPTR(s32→p2)` are observed and legalized by the same machinery
  `legalizePtrAdd`/`legalizeLoad`/`legalizeStore` already rely on.

**2. `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.h`** — declare
`legalizePhi` next to `legalizePtrAdd` (line ~72), same signature.

**3. `patches/llvm-mos/0014-321-far-ptr-phi-legalize.patch`** (NEW patch) +
`dev/regen-patch-0014.sh` (NEW, modeled on `dev/regen-patch-0013.sh`).

> **Execution correction (was: regenerate `0002` via `dev/regen-patch.sh`).** The
> plain `dev/regen-patch.sh` is legacy: its baseline is only pristine+0001+0003
> and it captures the *entire* live `llvm/lib/Target/MOS` dir as 0002 — but
> `toolchain.sh` applies *all* patches 0001..0013 to the live tree, so running it
> now folds 0004..0013 (e.g. far-memops `__memset_far`) into 0002 (+1350 lines).
> Its round-trip "PASS" is misleading (it passes *because* 0002 absorbed
> everything). The established pattern since 0004 is **one numbered patch + one
> dedicated `regen-patch-NNNN.sh` per fix** (per-patch delta isolation: baseline =
> pristine + all *other* patches, overlay the touched file(s), diff). So this fix
> ships as its own **0014** with `dev/regen-patch-0014.sh` (baseline 0001..0013,
> overlays `MOSLegalizerInfo.{cpp,h}`). Verified: 0014 is 86 lines / 2 files,
> contains `legalizePhi`/`customFor({PF})`/`case G_PHI:` and **zero** foreign
> hunks (`__memset_far`/`createFarMemLibcall`/`packed24` all 0), and round-trips
> (`pristine + 0001..0014` reproduces the live `MOSLegalizerInfo.{cpp,h}`).

### Test (the regression guard) — executable micro-test, matching `far_memops` precedent

The project bar is the executable 4-way differential, not lit tests
(`far_memops` shipped with no lit test). Mirror it exactly.

**`examples/65816/far_loop.c`** — modeled on `examples/65816/far_memops.c`. A
far-pointer **induction-variable** write loop *and* read-back loop (the exact
`p++` shape that used to abort), into high WRAM bank `$7E`:

```c
#include <stdint.h>
#define FAR __attribute__((address_space(2)))
static FAR uint8_t *const hi = (FAR uint8_t *)0x7E2000u;
volatile uint16_t n;
volatile uint8_t corpus_result;

int main(void) {
  n = 50;
  uint16_t cnt = n;                 // runtime trip count
  FAR uint8_t *p = hi;              // far-ptr IV (the G_PHI(p2) shape)
  for (uint16_t i = 0; i < cnt; i++, p++) *p = (uint8_t)i;   // hi[i] = i
  FAR uint8_t *q = hi; uint8_t acc = 0;
  for (uint16_t i = 0; i < cnt; i++, q++) acc += *q;         // sum hi[0..49]
  corpus_result = acc;             // sum(0..49) = 1225 -> 0xC9
  for (;;) {}
}
```

Expected `corpus_result == 0xC9` (`1225 & 0xFF`). Both loops carry a far-ptr IV,
so the fix is exercised twice; the value-sensitive sum means a wrong-bank store
would change it. `+mos-a16`-only (a runtime far pointer is a 32-bit value), like
every other far test.

**`dev/far_loop.sh`** — modeled on `dev/far_memops.sh`. Disasm gate
(far-ptr loop compiles and lowers to indirect-long `sta [dp]` / `lda [dp]`; no
backend abort) + execution gate at `-Os` and `-O2` on MAME asserting
`corpus_result == 0xC9`. Runnable via `dev/run.sh far_loop` (generic dispatch —
no `run.sh` case needed). Close with `emu_verdict`.

**Wire-ups:**
- `dev/run.sh` usage block — add a one-line `far_loop` help entry (near the
  other `far_*` entries, ~line 95).
- `dev/xcheck.sh` — add `build_rom far_loop mos-snes.cfg -Xclang -target-feature
  -Xclang +mos-a16` (~line 73) and `xassert "$BUILD/far_loop.sfc"
  "$BUILD/far_loop.map" corpus_result 0xC9` (~line 128) for the bsnes-jg
  second-emulator cross-check.

### Docs / bookkeeping (same turn)

- **Write `docs/plans/2026-06-26-far-pointer-loop-iv-gphi-p2-legalize.md`** as
  the contract (this plan, project format) — first execution step.
- **`TODO.md`** — add an M2 row for this fix (use `/todo`); move to Done with the
  commit SHA when landed.
- **`docs/upstream-contribution-status.md`** — this gap is already noted there as
  a future item; promote it to a ready-to-post upstream artifact (a clean
  `G_PHI` pointer-legalization fix is upstream-worthy for `llvm-mos`). Draft
  only — **posting is user-triggered**. Mirror the one-line pointer in TODO's
  *Upstream / Contribution* section.
- **Update the memory** `far-pointer-loop-iv-gphi-p2-unsupported.md`: the gap is
  now fixed (cite commit); far-ptr IV loops are supported. Keep the index-style
  note as the still-recommended idiom (clearer), but drop "crashes the backend".

## Verification

All steps run 2026-06-26. Raw output below each step; PASS/FAIL noted.

> **Test-shape note (measured during execution).** At `-Os`/`-O2` LLVM's
> indvars/LSR strength-reduces a *plain* unit-stride far-ptr IV (`p++`) into an
> integer index (`hi + i`, a `G_PTR_ADD`), dissolving the phi — so a naive `p++`
> loop compiles even *without* the fix and does **not** exercise it. `far_loop.c`
> advances by a **runtime stride** (`p += s`, `s==1` at runtime but a volatile
> load, opaque to the optimizer) so the far-ptr phi survives to the legalizer at
> every `-O`. Confirmed: the `-Os` IR carries 2 `phi ptr addrspace(2)` (write +
> read-back loops).

1. **Pre-fix crash reproduction (negative control).** `far_loop.c` on the
   unpatched install toolchain, `-Os` and `-O2`:

   ```
   === far_loop.c -Os/-O2 on CURRENT (unpatched) toolchain ===
   fatal error: error in backend: unable to legalize instruction:
     %17:_(p2) = G_PHI %28:_(p2), %bb.3, %21:_(p2), %bb.6 (in function: main)
   exit: 1   (both -Os and -O2)
   ```
   Also direct, optimizer-independent repro — explicit `phi ptr addrspace(2)` IR
   through the install clang at `-O0`:
   ```
   unable to legalize instruction: %5:_(p2) = G_PHI %0:_(p2), %bb.1, %8:_(p2), %bb.2
   ```
   **PASS** (bug reproduced; vendor `MOSLegalizerInfo.cpp` line 408 confirmed
   unpatched `{S1,S8,P,PZ}` at the time).

2. **Rebuild** `dev/run.sh toolchain` (incremental). Rebuild took — binaries
   `22:33` vs source `16:45` (no stale-`clang-23`):
   ```
   2026-06-26 22:33:38 build/llvm-mos-install/bin/mos-clang
   2026-06-26 22:33:37 build/llvm-mos-install/bin/clang-23
   ```
   **PASS**.

3. **Fix compiles + MIR-verifies.** `far_loop.c -Os/-O2` and explicit-phi IR
   `-O0`, all with `-verify-machineinstrs` → exit 0, no abort. `-stop-after=legalizer`
   on the explicit phi shows the `p2` phi gone, bridged by ptrtoint/inttoptr and
   narrowed to byte-phis:
   ```
   %31:_(s32) = G_PTRTOINT %0(p2)
   %42:_(s8) = G_PHI %34(s8), %bb.1, %38(s8), %bb.2   (+ 3 more byte-phis)
   %5:_(p2)  = G_INTTOPTR %33(s32)
   G_STORE_FAR_INDIR %6(s8), %5(p2) :: (store (s8) into %ir.p, addrspace 2)
   ```
   **PASS**.

4. **Micro-test differential.** `dev/run.sh far_loop`:
   ```
   PASS: compiled (no 'unable to legalize ... G_PHI (p2)' abort)
   PASS: far indirect-long store + load present (sta [dp] / lda [dp])
   SMOKE: PASS addr=0x7E0204 len=1 got=0xC9 (ran 60 ticks)   PASS (-Os)
   SMOKE: PASS addr=0x7E0204 len=1 got=0xC9 (ran 60 ticks)   PASS (-O2)
   RESULT: PASS — far-pointer induction-variable write+read-back loops fill bank $7E …== 0xC9
   ```
   **PASS**.

5. **bsnes-jg cross-check.** `dev/run.sh xcheck`:
   ```
   PASS  far_loop.sfc: SMOKE: PASS off=0x204 len=1 got=0xC9 (ran 180 frames, bsnes-jg)
   RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (16/16)
   ```
   **PASS** (4-way differential closed: host 0xC9 == a16@MAME -Os/-O2 == a16@bsnes-jg).

6. **No regression.** `corpus` 7/7; `corpus-a16` 6/6, 0 xfail; `far` disasm gate
   PASS; `far_memops` PASS (`0x74` -Os/-O2, far runtime routing intact):
   ```
   ==> corpus: 7/7 passed
   ==> corpus-a16: 6/6 passed, 0 xfail
   RESULT: PASS — addrspace 2 -> absolute-long (24-bit) …            [far]
   RESULT: PASS — far memset (variable) + far aggregate memcpy …0x74  [far_memops]
   ```
   **PASS**.

7. **Patch round-trips.** `dev/regen-patch-0014.sh`:
   ```
   wrote …/0014-321-far-ptr-phi-legalize.patch (86 lines, 2 files)
   RESULT: PASS — 0014 round-trips (0001..0014 reproduces MOSLegalizerInfo.{cpp,h})
   ```
   Foreign-hunk guard: `__memset_far`/`createFarMemLibcall`/`anyFarPointerOperand`/
   `packed24` all 0 in 0014; `legalizePhi`×4, `customFor({PF})`×1, `case G_PHI:`×1.
   **PASS**.

## Commit

Stage only my files — explicitly — then verify `git diff --cached --name-only`
is exactly: `MOSLegalizerInfo.{cpp,h}` is **not** committed (it's `vendor/`,
gitignored); the tracked set is `patches/llvm-mos/0014-321-far-ptr-phi-legalize.patch`,
`dev/regen-patch-0014.sh`, `examples/65816/far_loop.c`, `dev/far_loop.sh`,
`dev/run.sh`, `dev/xcheck.sh`,
`docs/plans/2026-06-26-fix-the-far-pointer-g-phi-p2-backend-gap.md`, `TODO.md`,
`docs/upstream-contribution-status.md`, and the memory file. Never stage
`vendor/`, a foreign patch (incl. an accidentally-regenerated `0002`), or
`docs/transcripts/`. End the message with the `Co-Authored-By` trailer. Don't
push without coordinating.
