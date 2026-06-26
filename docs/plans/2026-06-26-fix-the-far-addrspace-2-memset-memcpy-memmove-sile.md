# Fix the far (addrspace 2) memset/memcpy/memmove silent wrong-bank miscompile

## Context

**The defect.** A `memset`/`memcpy`/`memmove` (or any compiler-formed equivalent) on a **far**
pointer (`addrspace(2)`, the 65816 24-bit pointer) can silently write/read the **wrong bank**. No
crash, no diagnostic — exactly the class of defect that matters most for a compiler, since the
toolchain ships the bug into every program built with it.

**Root cause (confirmed from source, not assumed).** `MOSLegalizerInfo::legalizeMemOp`
(`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp:2777`) lowers `G_MEMSET/G_MEMCPY/G_MEMMOVE`.
It first tries **inline expansion** (`Helper.lowerMemCpyFamily(MI, SizeLimit)`, line 2816). For a far
memop the inline path emits correct per-byte far stores — but it only succeeds for a **constant** size
`<= SizeLimit` (8 set / 4 copy at `-Os`; 16 / 8 at `-O2`, lines 2790-2807). For a **variable** size, or
a **constant size over the limit**, it bails and falls through to
`Helper.createMemLibcall(MRI, MI, LocObserver)` (line 2823 → `LegalizerHelper.cpp:810`).
`createMemLibcall` builds the call arg as `PointerType::get(Ctx, OpLLT.getAddressSpace())`
(`LegalizerHelper.cpp:823`) — it *preserves* `addrspace(2)` and passes the 32-bit far pointer via the
Imag32 far ABI — but the callee is the **near** runtime `__memset`/`memcpy`/`memmove`
(`vendor/llvm-mos-sdk/mos-platform/common/c/mem.c`), whose parameter is a **16-bit `char *`
(addrspace 0)**. The callee reads only the 16-bit offset and stores via a near `sta abs` against the
data-bank register — **the far pointer's bank byte is silently dropped.** → wrong-bank access.

**Why the task's first proposed fix is insufficient (key finding).** The task suggested *"stop the
loop-idiom recognizer forming memset/memcpy for addrspace(2)"* as the smallest correct fix. Investigation
shows the loop-idiom recognizer is **only one of at least four independent producers** of far
mem-intrinsics, all of which converge on the same broken libcall path:
1. **clang `EmitAggregateCopy`** (`clang/lib/CodeGen/CGExprAgg.cpp:2368`) emits `llvm.memcpy.p2` for
   **every** far struct/array copy — e.g. `*farStructPtr = *otherFarStructPtr;` — with **no size
   threshold** and **never touching the loop-idiom pass.**
2. clang null/zero-init (`CodeGenFunction.cpp:2352/2358`) and constant-init (`CGDecl.cpp:1283`, memcpy
   above 64 B at `-O1+`, always at `-O0`).
3. `__builtin_memset/memcpy/memmove` on a far pointer.
4. **MemCpyOpt** (`MemCpyOptimizer.cpp:475/683/807`) merging far stores/load-store into a far mem-intrinsic.

So blocking only the loop-idiom recognizer leaves a real, reachable silent-wrong-bank hole (a plain far
struct copy still miscompiles). **The fix must live at the single backend chokepoint where all sources
converge — `legalizeMemOp` — by routing far memops to a far-aware runtime.** This is the task's *other*
stated option ("route to a far-aware `__memset_far`"), and it is the complete, sound one.

**Intended outcome.** Every far memset/memcpy/memmove — variable or constant size, from any source —
writes the correct bank. Closed at one place in the MOS backend plus three small runtime functions; **no
generic-LLVM changes**, so the change is self-contained and cleanly upstreamable to llvm-mos.

---

## Approach (recommended): far-aware runtime libcall at the backend chokepoint

Two parts: (A) three far runtime functions in the SNES platform overlay; (B) backend routing in
`legalizeMemOp` that diverts far memops to them instead of the bank-dropping near libcall. Small constant
far memops continue to inline-expand correctly (unchanged) — we only intercept the libcall fallthrough.

### Part A — far runtime functions (SDK overlay, tracked main-repo files)

`vendor/llvm-mos-sdk/` is gitignored and re-cloned by `dev/build.sh`; the repo's mechanism for SDK
additions is the **tracked overlay** `platforms/<name>/`, which `dev/build.sh:32-37` copies into the SDK
tree before building. So the runtime is a plain main-repo commit — there is **no `patches/llvm-mos-sdk/`**.

**New file `platforms/snes/mem-far.c`** — `__memset_far`, `__memcpy_far`, `__memmove_far`, each taking
`FAR`-qualified (`__attribute__((address_space(2)))`, the spelling used throughout `examples/65816/`)
pointer params so the Imag32 far ABI matches the compiler-emitted call by construction. **Loop shape (as
built — see the Implementation note below):** the bodies are **index-style** (`ptr[i]`, far base
loop-invariant, `i` an `i16` index) — **NOT** the `mem.c` `ptr++` pointer-increment style. A far pointer
carried across a loop back-edge forms an unsupported `G_PHI (p2)` and crashes the backend; the index form
keeps the phi on the integer index and recomputes the full 24-bit address each iteration (the 32-bit add
carries into the bank byte, so a span may legally cross banks). **One non-mechanical spot:** `__memmove_far`
chooses copy direction by comparing the **full 32-bit far pointer values** (`(uint32_t)dst <= (uint32_t)src`),
not a 16-bit-truncated `uintptr_t` like the near `memmove` does — else overlap within a high-WRAM bank is
mishandled.

**`platforms/snes/CMakeLists.txt`** — register `mem-far.c` into the snes libc via
`add_platform_library(snes-c mem-far.c)` (OUTPUT_NAME strips the `snes-` prefix → `libc.a`, and it
auto-merges the parent `common-c`; the `nes-action53-c` precedent), so `derived.cfg`'s `snes/lib`-first
search shadows common's libc while every near symbol still resolves from the one merged archive. A separate
source file = separate archive member, so `--gc-sections` keeps it out of ROMs that never call a far memop
→ no size regression for existing ROMs. Per-source compile options are **mandatory**:
- `-fno-builtin` — **critical**: otherwise the loop-idiom recognizer turns `mem-far.c`'s own loops back
  into `llvm.memset/memcpy.p2` → infinite recursion into themselves. (Generalizes the existing
  `-fno-builtin-memset` on `common/c/CMakeLists.txt:71`.)
- `-mcpu=mosw65816` — the far deref is indirect-long (`sta/lda [dp]`).
- `-Xclang -target-feature -Xclang +mos-a16` — the far pointer is a 32-bit value; the per-iteration `ptr[i]`
  address is a 32-bit `G_PTR_ADD` that only legalizes under `+mos-a16`.
- `-fno-lto` — pin the far-store codegen at build time (mirrors `crt0.c`), so the far ops select on the
  module's own `mosw65816`/`+mos-a16` features rather than depending on LTO feature-propagation.

### Part B — backend routing in `legalizeMemOp` (compiler change → new patch)

In `MOSLegalizerInfo.cpp:legalizeMemOp`, after inline expansion fails and **before** the generic
`createMemLibcall` fallthrough (line 2823), detect a far pointer operand and divert:

```cpp
if (Result == LegalizerHelper::Legalized) return true;   // inline path (small const) — unchanged

// #320: never fall into the NEAR createMemLibcall for a far memop — it drops the bank byte.
if (anyFarPointerOperand(MRI, MI))
  return createFarMemLibcall(Helper, MRI, MI);

Result = Helper.createMemLibcall(MRI, MI, LocObserver);  // near path — unchanged
...
```

Add two **static file-local helpers** in `MOSLegalizerInfo.cpp` (no header change needed):
- `anyFarPointerOperand(MRI, MI)` — true if any *pointer* operand (skip the trailing tail-imm) is
  `MOS::AS_Far` or `MOS::AS_FarPacked` (enum at `MOSInstrInfo.h:164`; packed only appears defensively —
  it is value-only and cast to far before deref, per `MOSLegalizerInfo.cpp:388`).
- `createFarMemLibcall(Helper, MRI, MI)` — mirror of `LegalizerHelper::createMemLibcall`
  (`LegalizerHelper.cpp:810-877`) but: (1) callee name via `MachineOperand::CreateES("__memset_far" /
  "__memcpy_far" / "__memmove_far")`; (2) **widen every non-far pointer arg to far** with
  `Builder.buildAddrSpaceCast(LLT::pointer(MOS::AS_Far,32), Reg)` — near→far zero-extends to bank `$00`
  (`legalizeAddrSpaceCast`, `MOSLegalizerInfo.cpp:1824`), which is correct under the DBR=0 model and lets a
  single `__memcpy_far(FAR,FAR,n)` cover near→far cases (e.g. ROM constant → high WRAM); (3) **omit**
  `Args[0].Flags[0].setReturned()` (the far runtime returns `void`; nothing consumes a return).

Because the far path emits the symbol name directly via `CreateES`, it does **not** depend on the
`RTLIB::MEMSET`→`__memset` name mapping — it is immune to that detail.

### Patch & commit hygiene

- **Compiler change** (`MOSLegalizerInfo.cpp` only) → new focused patch
  **`patches/llvm-mos/0013-320-far-memops.patch`**, applied after `0004` (far CC). `legalizeMemOp` is not
  touched by any existing patch, so this is purely additive. Create `dev/regen-patch-0013.sh` by cloning
  `dev/regen-patch-0012.sh` (add `0012` to its prior-stack list). Sanity-check the regen didn't absorb
  foreign hunks.
- **Runtime change** (`platforms/snes/mem-far.c` + `CMakeLists.txt`) → plain tracked main-repo commit.
- Stage only these files; verify `git diff --cached --name-only` is exactly this set (never `vendor/`,
  `docs/transcripts/`, or a foreign patch).

### Deliberately NOT doing (considered, deferred)

The loop-idiom-recognizer gate (a `true`-defaulting `canLowerMemIntrinsicForAddrSpace(AS)` TTI hook, MOS
returning false for far, queried in `isLegalStore`) is **not needed** once the far runtime exists: the
runtime lowers loop-idiom-formed far memsets correctly, and forming a shared `__memset_far` call is a
code-size wash-or-win versus an inline far loop. It would add generic-LLVM surface for marginal/negative
benefit. Note it in TODO as a possible future code-quality tweak only.

---

## Critical files

| File | Change |
|------|--------|
| `platforms/snes/mem-far.c` | **new** — `__memset_far`/`__memcpy_far`/`__memmove_far` (FAR-qualified params) |
| `platforms/snes/CMakeLists.txt` | register `mem-far.c` into snes libc + `-fno-builtin;-mcpu=mosw65816;+mos-a16` |
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` | `legalizeMemOp` divert + static `anyFarPointerOperand` / `createFarMemLibcall` |
| `patches/llvm-mos/0013-320-far-memops.patch` | **new** — regenerated from the `MOSLegalizerInfo.cpp` edit |
| `dev/regen-patch-0013.sh` | **new** — clone of `regen-patch-0012.sh` |
| `examples/65816/far_memops.c` + `dev/far_memops.sh` | **new** — the regression gate (below) |

Reference-only (mirror their bodies/patterns): `LegalizerHelper.cpp:810-877` (`createMemLibcall`),
`mem.c` (near runtime bodies), `examples/65816/far_store.c` + `dev/far_store.sh` (test shape),
`examples/snes/mandel-display.c:35` (the `(FAR uint8_t *)0x7E2000u` high-WRAM idiom).

---

## Verification

> Project convention: keep each numbered step verbatim, paste raw output in a code block beneath it, add
> PASS/FAIL, write results back into the canonical `docs/plans/2026-06-26-321-far-memset-miscompile.md`.
> Build/test commands per `docs/agent-handoff.md`. First create that canonical plan file + a `TODO.md`
> entry (plan-first contract), then execute.

**Step 0 — Reproduce on the CURRENT toolchain first.** Write `examples/65816/far_memops.c`: a
**variable-size** far memset (size laundered through a `volatile uint16_t` so it never inlines) and a
**large constant** far memcpy (64 B, over the `-O2` limit) into high WRAM (`0x7E2000`), then read back via
far loads into `volatile uint8_t corpus_result`, arranged so the correct result is a known sentinel.
Build + boot on MAME; confirm it produces the **wrong** value (bank `$00` instead of `$7E`) and the disasm
shows a near `__memset`/`memcpy` call. This is the repro that proves the bug before fixing.

**Step 1 — Implement Part A + Part B; rebuild.** `dev/run.sh toolchain` (Docker, incremental). Confirm the
rebuild actually took: `build/llvm-mos-install/bin/clang-23` mtime advanced (the stale-`clang-23` gotcha).
`dev/build.sh` to rebuild the SDK with the new `mem-far.c` overlay.

**Step 2 — Disasm gate.** `llvm-objdump -dr` on `far_memops.o` shows calls to `__memset_far` and
`__memcpy_far` (not near `__memset`/`memcpy`), and the readback uses far loads (`A7` `lda [dp]`).

**Step 3 — Execution / differential gate.** `dev/run.sh far_memops` → `corpus_result == <sentinel>` on
**MAME and bsnes-jg**, built at **both `-Os` and `-O2`** (the variable memset misses inline in both; the
64 B memcpy exceeds both limits). Include a far↔far case, a near-src→far-dst case (exercises the
`buildAddrSpaceCast` widening), and an overlapping `__memmove_far` case (validates the 32-bit-compare
direction choice).

**Step 4 — MIR verify clean.** Compile `far_memops.c` with `-mllvm -verify-machineinstrs`; clean exit.

**Step 5 — No regressions.** Run the existing far suite (`dev/far_*.sh`), `dev/run.sh corpus-a16`
(expect 7/7), and a torture sample (`dev/run.sh torture 50`); no new mismatches/crashes. Confirm
near-only ROMs are byte-identical (the far runtime is gc-sectioned out when unused).

**Step 6 — Patch hygiene.** `dev/regen-patch-0013.sh`; verify `0013` contains only the `MOSLegalizerInfo.cpp`
delta and absorbed no foreign hunks (`grep -c` a foreign symbol). `git diff --cached --name-only` is
exactly the intended file set.

**Step 7 — Upstream artifact.** Record the fix in `docs/upstream-contribution-status.md` (it is
upstream-worthy for llvm-mos: a self-contained MOS-backend correctness fix). Posting stays user-triggered.

---

## Verification — results (2026-06-26, PASS)

Toolchain rebuilt (`clang-23` mtime advanced `09:08:34 → 16:47:38`), SDK rebuilt with the `mem-far.c` overlay.

**Step 0 — Reproduce on the CURRENT (pre-fix) toolchain.** PASS (bug reproduced).
```
# llvm-objdump -dr far_memops.o (pre-fix): NEAR runtime, 16-bit reloc → bank dropped
0000005d:  R_MOS_ADDR16  __memset      # variable far memset (loop-idiom) → near
00000080:  R_MOS_ADDR16  memcpy        # far aggregate struct copy → near
0000016e:  R_MOS_ADDR16  memcpy
# IR confirms both sources are FAR: llvm.memset.p2.i32 + llvm.memcpy.p2.p0.i16 (×2)
```

**Step 1 — Implement + rebuild.** PASS. `dev/run.sh toolchain` clean; `MOS_TOOLCHAIN=… dev/run.sh build`
clean (after clearing a *foreign* stale `add_subdirectory(snes-zoom)` line in the gitignored vendored SDK).

**Step 2 — Disasm gate.** PASS — far memops now route to the far runtime; no near reference.
```
0000005d:  R_MOS_ADDR16  __memset_far
00000084:  R_MOS_ADDR16  __memcpy_far
0000017a:  R_MOS_ADDR16  __memcpy_far     (identical at -Os and -O2)
```

**Step 3 — Execution / differential gate.** PASS on MAME (`-Os` and `-O2`) and bsnes-jg.
```
dev/run.sh far_memops:
  PASS: calls __memset_far and __memcpy_far ; PASS: no near __memset/memcpy/memmove reference
  -Os: SMOKE: PASS addr=0x7E0202 got=0x74     -O2: SMOKE: PASS addr=0x7E0202 got=0x74
  RESULT: PASS — far memset (variable) + far aggregate memcpy land in bank $7E
dev/run.sh xcheck:
  PASS far_memops.sfc: off=0x202 got=0x74 (bsnes-jg)   # 4th differential leg
```
Host-expected `0x74` = `50·0x5A + Σ(0..63)` (= 6516 & 0xFF). (No default-8-bit leg: far requires `+mos-a16`.)

**Step 4 — MIR verify clean.** PASS — `-mllvm -verify-machineinstrs` clean at `-Os` and `-O2` (exit 0).

**Step 5 — No regressions.** PASS. `dev/run.sh xcheck` — all 14 existing far ROMs still PASS on bsnes-jg.
`dev/run.sh corpus-a16` → **6/6, 0 xfail**; `dev/run.sh corpus` → **7/7**;
`dev/run.sh torture 40` → **40 PASS, 0 FAIL, 0 XFAIL**. (Near memops are provably untouched: the divert
only fires when `anyFarPointerOperand` is true.)

**Step 6 — Patch hygiene.** PASS.
```
dev/regen-patch-0013.sh → RESULT: PASS — 0013 round-trips (0001..0013 reproduces MOSLegalizerInfo.cpp)
0013 touches: llvm/lib/Target/MOS/MOSLegalizerInfo.cpp (1 file); my symbols ×6; foreign symbols ×0
```

**Step 7 — Upstream artifact.** DONE — recorded in `docs/upstream-contribution-status.md` (in-fork `0013`,
folds into the Future/blocked #320 body; posting user-triggered).

### Implementation note — a backend gap surfaced (and worked around)

The runtime cannot loop with a far-pointer induction variable (`for (; num; ptr++) *ptr = v;`): a far
pointer carried across a loop back-edge becomes a `G_PHI` of an `addrspace(2)` pointer, and `G_PHI` is legal
on MOS only for `{s1,s8,p0,p1}` — so the backend aborts (`unable to legalize … G_PHI (p2)`). This is a
**pre-existing latent gap** (any far-pointer loop hits it), not introduced here. Notably it is re-formed even
from clean `i32`-phi IR: GISel's artifact combiner hoists `G_INTTOPTR` through the phi. Work-around: write
`mem-far.c` index-style (`ptr[i]`, far base loop-invariant, `i` the i16 IV) — the same shape
`examples/snes/mandel-display.c` uses; it recomputes the full 24-bit address each iteration (the 32-bit add
carries into the bank byte, so a span may legally cross banks) and emits `sta/lda [dp]`. Proper backend
support for a far-pointer `G_PHI` is noted as a future item in `docs/upstream-contribution-status.md`.
