# Do 3c — finish #320 Increment 3 (runtime far-pointer arithmetic)

## Context

GitHub issue **#320** (far pointers) Increment 3 has three sub-items. **3a** (runtime far
dereference, `lda [dp]`) and **3b** (near→far addrspacecast, AS0→AS2) shipped 2026-06-20 in patch
`0001`, two-emulator verified. **3c** (far-pointer arithmetic, `fp++` → `G_PTR_ADD` on AS2) was the
one **deferred** item — it is the last thing standing between Inc 3 and "done".

3c was deferred because its gate, `far_arith.c`, is the **first program to hit a missing legalization**:
the symmetric **`s32 → 4×s8 G_UNMERGE_VALUES`** rule. The *opposite* direction (`4×s8 → s32
G_MERGE_VALUES`) already exists as `legalizeMergeS32FromBytes` (a `hasAccum16`-gated custom rule in
`0002`). The unmerge mirror was never written because nothing reached it — until `fp++`.

**Why it's unblocked now:** the change is purely mechanical — mirror the merge. A Plan-agent review
confirmed the design is correct as-is, and that it additionally closes a **latent pre-existing bug**
(an a16 `uint32_t` shift-by-≥8 in `legalizeShiftRotate` also emits the same unsupported unmerge; no
test hits it yet). The foreign `MOSIndexWidthClobber` WIP that the #320 plan's patch-hygiene note
warned about is **gone** from the live tree (xy16 work resolved, commit `f5ec818`), so the normal
`dev/regen-patch.sh` path for `0002` is clean again.

**Outcome:** `far_arith.c` compiles and runs; `fp++` on a far pointer lowers to a correct 32-bit add
(bank byte preserved); Inc 3's verification Step 5 flips DEFERRED → PASS; Inc 3 is complete.

### The exact mechanism (traced + verified)

`fp++` on a 32-bit far pointer (`PF`):
1. `G_PTR_ADD {PF,S32}` +1 → `legalizePtrAdd` (`MOSLegalizerInfo.cpp:1723`) **skips** the `G_INC`
   fast-path (guard `…getScalarSizeInBits() != 32` at `:1748`) → generic
   `buildPtrToInt(s32)/buildAdd(s32)/buildIntToPtr` (`:1755-1759`).
2. `G_ADD s32` → rule at `:179-182` (`.custom()`) → `legalizeAddSub` (`:735`). The a16 early-return is
   **s16-only** (`:752`), so s32+const-±1 reaches `Builder.buildUnmerge(S8, Src)` (`:769`) =
   **`G_UNMERGE_VALUES {S8,S32}`** → `unsupported()` (rule at `:160-166`). ← the failure.
3. The symmetric `buildMergeValues` (`:780`) is already handled by `legalizeMergeS32FromBytes` (`:645`).

So only the unmerge direction is missing. Add it and 3c compiles.

---

## Part A — Backend: the `s32 → 4×s8` unmerge legalization (lands in `0002`, `hasAccum16`-gated)

All edits in `vendor/llvm-mos/llvm/lib/Target/MOS/`.

**1. `MOSLegalizerInfo.h` (~line 42)** — declare the mirror next to `legalizeMergeS32FromBytes`:
```cpp
// #321 a16: 4x s8 <- s32 G_UNMERGE_VALUES -> legal 2-level (2x s16) form (mirror of merge).
bool legalizeUnmergeS32ToBytes(LegalizerHelper &Helper, MachineRegisterInfo &MRI,
                               MachineInstr &MI) const;
```

**2. `MOSLegalizerInfo.cpp` action rule (`:160-166`)** — add `.customFor({{S8,S32}})` under `hasAccum16`,
mirroring the merge rule at `:157` (`legalFor({{S32,S16}}).customFor({{S32,S8}})`):
```cpp
auto &B = getActionDefinitionsBuilder(G_UNMERGE_VALUES)
              .legalForCartesianProduct({S8, PZ}, {S16, P});
if (STI.hasAccum16())
  B.legalFor({{S16, S32}}).customFor({{S8, S32}});
B.unsupported();
```
(First-match-wins, dispatched by **dst** type: src=S32 with dst=S16 → legal, dst=S8 → custom. Disjoint,
order-independent — verified against `LegalizerInfo.cpp:193-215`.)

**3. `MOSLegalizerInfo.cpp` dispatch (`:540`, next to `case G_MERGE_VALUES`)**:
```cpp
case G_UNMERGE_VALUES:
  return legalizeUnmergeS32ToBytes(Helper, MRI, MI);
```

**4. `MOSLegalizerInfo.cpp` new function (next to `legalizeMergeS32FromBytes`, ~`:660`)** — the mirror:
unmerge s32 → 2×s16 (legal `{S16,S32}`), then each s16 → 2×s8 (legal `{S8,S16}`), reusing the four
original def regs. Little-endian D0=LSB, consistent with the merge:
```cpp
// #321 a16: a 4x s8 <- s32 G_UNMERGE_VALUES (only reached via customFor({S8,S32}) under
// +mos-a16) — rewrite into the legal 2-level form, mirroring legalizeMergeS32FromBytes:
// unmerge s32 -> 2x s16 (legal), then each s16 -> 2x s8 (legal). The artifact combiner
// folds these against a feeding merge; building only unmerges can't create a merge<->unmerge loop.
bool MOSLegalizerInfo::legalizeUnmergeS32ToBytes(LegalizerHelper &Helper,
                                                 MachineRegisterInfo &MRI,
                                                 MachineInstr &MI) const {
  MachineIRBuilder &Builder = Helper.MIRBuilder;
  const LLT S16 = LLT::scalar(16);
  Register D0 = MI.getOperand(0).getReg();
  Register D1 = MI.getOperand(1).getReg();
  Register D2 = MI.getOperand(2).getReg();
  Register D3 = MI.getOperand(3).getReg();
  Register Src = MI.getOperand(4).getReg();   // G_UNMERGE: defs first, source last
  auto Words = Builder.buildUnmerge(S16, Src);       // {S16,S32} legal
  Builder.buildUnmerge({D0, D1}, Words.getReg(0));   // {S8,S16} legal
  Builder.buildUnmerge({D2, D3}, Words.getReg(1));   // {S8,S16} legal
  MI.eraseFromParent();
  return true;
}
```
`buildUnmerge(ArrayRef<Register>, SrcOp)` (`MachineIRBuilder.h:1153`) — the `{D0,D1}` form binds
unambiguously (LLT ctors are static factories; AMDGPU uses the identical pattern). Verified.

**No `0001` change** — these are a16/`0002` hunks. (3c's pointer type-rules — `G_INTTOPTR/PTRTOINT/
PTR_ADD {…,S32}` — already exist in `0001` from 3a/3b, at `:129-136`, `:252-253`.)

---

## Part B — The 3c gate test (tracked files; normal commit, not a patch)

**5. `examples/65816/far_arith.c`** — new. Follows the real `corpus_result`-WRAM harness (NOT the
plan's simplified `return …?0:1` snippet); bank $00 like `far_cast.c`; `arr[1]=0xA9` so the
post-increment read XORs to the canonical `0xF3`:
```c
// #320 Increment 3 (3c) — far-pointer arithmetic (G_PTR_ADD on AS2). A runtime far
// pointer to arr[0] is incremented (fp++ -> G_PTR_ADD {PF,S32}, a 32-bit add) and the
// result dereferenced via lda [dp]. Needs +mos-a16 (32-bit value legalization, incl.
// the s32->4x s8 unmerge this gate first exercised). Harness: dev/far_arith.sh.
#include <stdint.h>
#define FAR __attribute__((address_space(2)))
static const uint8_t arr[3] = { 0x11, 0xA9, 0x33 };   // arr[1]=0xA9 -> ^0x5A = 0xF3
volatile uint8_t corpus_result;                        // sampled from $7E WRAM
volatile uint16_t opaque_near;                         // launders addr -> runtime (no fold)
int main(void) {
  opaque_near = (uint16_t)(uintptr_t)&arr[0];
  FAR const uint8_t *fp = (FAR const uint8_t *)(uintptr_t)(uint32_t)opaque_near;
  fp++;                                                 // G_PTR_ADD {PF,S32}: &arr[0]->&arr[1]
  corpus_result = *fp ^ 0x5A;                           // lda [dp] arr[1]=0xA9; 0xA9^0x5A=0xF3
  for (;;) { }                                          // stay alive while MAME settles
}
```

**6. `dev/far_arith.sh`** — new driver, a near-verbatim copy of `dev/far_cast.sh` (same
`mos-snes.cfg`, `+mos-a16`, `-verify-machineinstrs`, A7 disasm gate, `WANT=0xF3`). Diffs: filenames
`far_arith`, header comment cites 3c / `fp++` / `G_PTR_ADD`, usage string.

**7. `dev/run.sh`** — add `far_arith` to the usage list (line 3) and the help block (after the
`far_cast` entry ~`:60`). No dispatch case needed: `dev/run.sh <t>` runs `dev/<t>.sh` generically
(`:291`).

**8. `dev/xcheck.sh`** — add the bsnes-jg leg, mirroring the `far_cast` lines:
- after `:68`: `build_rom far_arith mos-snes.cfg -Xclang -target-feature -Xclang +mos-a16`
- after `:92`: `xassert "$BUILD/far_arith.sfc" "$BUILD/far_arith.map" corpus_result 0xF3   # bank $00, fp++ then lda [dp]`

---

## Part C — Regenerate `0002` + verify the stack

**9.** After the backend edits build clean, regenerate the a16 patch:
```bash
dev/regen-patch.sh        # mirrors live MOS dir -> 0002; round-trips (pristine+0001+0002+0003 == live)
```
Guard rails (project commit discipline):
- Round-trip must print `RESULT: PASS`.
- `0002` absorbs **only** my unmerge hunks — sanity-check it didn't pull foreign hunks:
  `grep -c 'IndexWidthClobber' patches/llvm-mos/0002-*.patch` → `0` (and the diff is the unmerge
  rule + dispatch + function only, no unrelated files).
- `0001` is **untouched** (regen-patch only writes `0002`); confirm `git diff --name-only` for
  `patches/` shows just `0002`.
- Pre-flight: confirm the live tree has no *other* uncommitted vendor divergence before regen (the
  round-trip diff is the proof). If a concurrent agent left a16 WIP, snapshot-diff just my files
  instead (per the #320 plan's hygiene method) — not expected, tree is currently clean.

---

## Part D — Docs (same turn)

**10.** `docs/plans/2026-06-20-320-far-pointer-runtime.md`: flip the 3c row (`:21`) DEFERRED→DONE;
rewrite **Step 5** evidence (paste raw `far_arith` MAME + bsnes-jg output, PASS); add a Results line.
Keep the existing numbered steps verbatim, evidence pasted beneath.
**11.** `TODO.md`: mark `#320 Inc 3c` `[x]`, move to the done section as one tight line; note Inc 3
complete. Triage any hook-captured Inbox bullet for it.
**12.** `docs/implementation-status.md`: row `:32` 3c → ✅ Done; fold into the `:31` "Done (Inc 3)"
row; correct the `:11-12` sentence (far-pointer *arithmetic* was never ABI-gated — only the far CC is).
**13.** Note the incidental `legalizeShiftRotate` latent-bug fix in the commit message (and, optional,
a tiny `a16shift32.c` regression guard for an s32 `>>8` — out of core scope; mention, don't block).

---

## Verification

Run from the repo root (host driver shells into the container). The 3c gate is **3-way**
(host-expected == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg) — the default 8-bit build can't compile a
32-bit far value, exactly like 3a/3b.

1. **Rebuild toolchain** with the backend edit: `dev/run.sh toolchain` (incremental). Watch for the
   stale-`clang-23` gotcha — confirm the rebuild actually took.
2. **Compile gate (no a16 needed for the trace, but the value is 32-bit so build with a16):**
   `far_arith.c` compiles clean under `-mllvm -verify-machineinstrs` (previously: *unable to legalize
   `G_UNMERGE_VALUES {S8,S32}`*).
3. **Disasm gate:** `dev/run.sh far_arith` → the deref is indirect-long (`a7`), not absolute-long.
4. **MAME execution:** same command → `corpus_result == 0xF3` (reads `arr[1]` after `fp++`).
5. **bsnes-jg execution:** `dev/run.sh xcheck` → all far ROMs PASS, **including the new `far_arith`
   row** == `0xF3`.
6. **No regression:** `dev/run.sh xcheck` shows `far`/`far-run`/`far-bank1`/`far_indir`/`far_cast`
   still PASS; spot-run a couple of `a16*` targets (e.g. `a16add`, `a16incdec`) and/or
   `dev/run.sh fuzz --gen csmith 30 1` → `0 mismatch, 0 crash`.
7. **Patch hygiene:** `grep -c 'IndexWidthClobber' patches/llvm-mos/0002-*.patch` → `0`;
   `regen-patch.sh` round-trip `RESULT: PASS`; `git diff --cached --name-only` is exactly my set
   (the `0002` patch + the test/doc files), never `0001`, `vendor/`, a foreign patch, or
   `docs/transcripts/`.

Negative control (optional): flip `arr[1]` to a non-`0xA9` byte → gate FAILs, proving it reads the
incremented address, not a folded constant.

---

## Out of scope (stays deferred — NOT part of finishing Inc 3)

- **Far-pointer calling convention** (pass/return `p2` across functions) — ABI decision, upstream-gated,
  grouped with **far calls (Inc 4)**.
- **`sta [dp]` store micro-test** (`*fp = v`) — the store is already implemented; a dedicated gate is a
  cheap optional follow-up, listed separately in the #320 plan's *Deferred* section.
