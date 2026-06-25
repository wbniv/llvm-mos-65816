# #320 far tail calls — PLAN

**Date:** 2026-06-22 · **Issue:** #320 (M1, far pointers/calls) · **Status:** ✅ **DONE + verified both
emulators** (built on `wt/320-far-tailcall`; regenerated into `0001` there + round-trip-proven; landing to
`main`'s shared `vendor/` is the pending follow-up; §6 has the pasted evidence) ·
**Builds on:** Inc 4 Ph1 direct `JSL`/`RTL` far calls (landed in `0001`) + follow-up (b) far→near thunk.
**Supersedes the out-of-scope `(c)` stub in** [`2026-06-21-320-far-calls-followups.md`](2026-06-21-320-far-calls-followups.md) §0/§8.

The TODO item this realizes: *"#320 far tail calls — the tail-call peephole keys on `MOS::JSR`, so a `JSL`
far call is never tail-converted. An optimization, not a correctness gap."* (`TODO.md`).

---

## 0. TL;DR

The MOS backend's **only** tail-call mechanism is one post-RA peephole,
`MOSLateOptimization.cpp::tailJMP`, which rewrites a block ending in **`JSR g; RTS`** → **`TailJMP g`** (a
near `$4C` jump): `g` runs and its own `RTS` returns straight to the original caller. It hard-codes the
**near** opcodes `MOS::JSR`/`MOS::RTS`, so a **far** function whose tail is **`JSL g; RTL`** is never
converted — every far tail call carries a redundant `RTL` and a full return-address push/pop.

**The fix** (small, symmetric, a16-independent): add a far analogue.
1. A new pseudo **`TailJML`** that expands to the existing **`JMP_AbsoluteLong`** (opcode **`$5C`**, the
   *direct* 24-bit long jump; relocates `R_MOS_ADDR24` exactly like `JSL`).
2. A second arm in `tailJMP` matching **`JSL g; RTL`** → **`TailJML g`**, **gated to fire only when `g` is a
   direct far-function global** (`g.isGlobal() && section.starts_with(".far_")`).

**Per converted far tail call: −1 byte** (`$5C` jmp-long 4 B vs `$22` jsl 4 B + `$6B` rtl 1 B = −1 B) **and
the redundant return push/pop is eliminated** (faster). On a compiler, banked across every far-heavy program
the SDK builds.

This was adversarially verified before writing (3-agent workflow, 2026-06-22, all claims **confirmed**, no
stack-corruption case): the far→far stack-width invariant holds, the dangerous near→far shape can't match
the gate, the bank-0 thunks are auto-excluded, and `TailJML` must expand to `$5C` (not reuse `TailJMP`'s
near `$4C`). See §3 for the proof, §8 for the verdict.

---

## 1. The gap — why a far call is never tail-converted

`MOSLateOptimization.cpp::tailJMP` (grep the symbol; line numbers drift in the multi-agent `vendor/`):

```cpp
bool MOSLateOptimization::tailJMP(MachineBasicBlock &MBB) const {
  if (MBB.size() < 2) return false;
  auto It = std::prev(MBB.end());
  if (It->getOpcode() != MOS::RTS) return false;   // <-- NEAR return only
  MachineInstr &RTS = *It;
  --It;
  if (It->getOpcode() != MOS::JSR) return false;    // <-- NEAR call only
  MachineInstr &JSR = *It;
  RTS.eraseFromParent();
  JSR.setDesc(JSR.getMF()->getSubtarget().getInstrInfo()->get(MOS::TailJMP));
  return true;
}
```

A far call lowers to **`MOS::JSL`** and a far function returns **`MOS::RTL`** (both in `MOSCallLowering.cpp`,
gated `STI.hasW65816() && section.starts_with(".far_")`). Neither half of the adjacency check matches a far
frame, so the far tail is left as `JSL g; RTL`. This is the *whole* reason — there is **no** GISel/SelectionDAG
tail-call path to also patch: `MOSCallLowering::lowerCall` lowers **every** call as an ordinary `JSR`/`JSL`
(it only `report_fatal_error`s on `musttail`), and `MOS::TailJMP` is produced at exactly one site (the
`setDesc` above). So this peephole is the **sole and complete** insertion point. (Verified — §8 CLAIM I/II.)

---

## 2. Why a far tail call needs `$5C`, not the near `$4C`

| | mnemonic | opcode | operand | sets PBR? | reloc |
|---|---|---|---|---|---|
| near tail (`TailJMP`) | `jmp` | `$4C` (`JMP_Absolute`) | 16-bit | no | `R_MOS_ADDR16` |
| **far tail (`TailJML`, new)** | **`jmp`-long** | **`$5C`** (`JMP_AbsoluteLong`) | **24-bit** | **yes** | **`R_MOS_ADDR24`** |
| (`$DC` `jml` = *indirect* — NOT this) | `jml` | `$DC` | 16-bit ind | yes | — |

`JMP_AbsoluteLong` (`$5C`) **already exists** (`MOSInstrInfo.td`, `Inst32<"jmp", …, AbsoluteLong>`); it takes
the same `addr24` operand class as `JSL_AbsoluteLong` (`$22`) and relocates identically (`R_MOS_ADDR24` — the
callee's bank-`$01` address). A near `$4C` to a far symbol would jump within the *wrong* bank (PBR unchanged)
and a 16-bit reloc can't carry the bank — so the far case **must** use `$5C`. (Verified — §8 CLAIM B / the
mechanics-agent correction.)

> **⚠ Disasm gotcha:** `JMP_AbsoluteLong` (`$5C`) disassembles as **`jmp`** (a *long*-operand `jmp`), **not**
> `jml`. The `jml` mnemonic belongs to `$DC` (`JML_Indirect16`, the indirect long jump). So the test's disasm
> gate must distinguish the `$5C` tail jump by its **operand width / `R_MOS_ADDR24` reloc**, not by grepping
> `jml`. (See §6 gate.)

---

## 3. Correctness — the far→far stack walk (the crux)

A far function `F` is entered by the caller's `JSL` (`$22`), which pushes a **3-byte** `PBR:PC` return `R`;
`F` returns via `RTL` (`$6B`, pops 3). Consider `F`'s block ending `JSL g; RTL` where `g` is a far function:

```
BEFORE                                   AFTER (TailJML g)
  ; entry: [R] on stack (3-byte, from        ; entry: [R] on stack
  ;          caller's JSL F)
  JSL g     ; push Rg (3-byte ret to F)       JMP.l g   ; $5C — pushes NOTHING; PBR:PC := g
  ; g runs, g's RTL pops Rg -> back to F      ; g runs with stack top = R (the only return)
  RTL       ; pop R -> back to F's caller     ; g's own RTL pops R (3-byte) -> F's caller
```

`g` is far ⇒ `g` returns `RTL` ⇒ pops **3** bytes = `R` (3-byte) ⇒ control lands at **`F`'s caller**, with
`g`'s result in the return register — exactly the tail-call contract. The width invariant holds: `R` was
*pushed* as 3 bytes by the caller's `JSL F` and is *popped* as 3 bytes by `g`'s `RTL`. **No corruption.**
(Verified — §8 CLAIM 1.)

### Why the gate is conservative-safe (a misclassification only ever *misses a win*)

The arm keys on the pair **`JSL` (penultimate) + `RTL` (last)** AND on **`g` being a direct far global**:

- **near→far is excluded for free.** A *near* function tail-calling a far `g` emits **`JSL g; RTS`** (`JSL`
  because `g` is far; **`RTS`** because the *current* function is near). The last instr is `RTS`, not `RTL`,
  so the far arm never matches it. Crucially, `RTL` is emitted **only** when the current function is far
  (`lowerReturn`), so an `RTL` terminator is itself proof the frame is far (the 3-byte return is on the
  stack). Converting near→far would make `g`'s `RTL` pop 3 bytes off a 2-byte near return → corruption — and
  the key structurally cannot reach it. (Verified — §8 CLAIM 2.)

- **the bank-0 thunks are auto-excluded.** far→near routes through `__call_near_from_far` and far-indirect
  through `__call_indir_far`; `lowerCall` retargets both via `MachineOperand::ChangeToES` → **external
  symbol** operands, not globals. The gate's `Tgt.isGlobal()` is **false** for them, so `JSL <thunk>; RTL`
  is left alone. (Converting them would in fact also be stack-safe — the thunk's own `RTL` would return to
  `F`'s caller — but it requires reasoning about each thunk's internal discipline; excluding them only
  *misses a ~1-byte win*, never regresses. Deferred — §7.) (Verified — §8 CLAIM 3.)

This matches the project's lesson #2: **make the gate conservative — a misclassification must only ever miss
a win, never cause a regression.** The far arm fires on *exactly* the direct far→far case, where the global
callee operand survives post-RA (`lowerCall` does `.add(Info.Callee)` for the direct far path, keeping it a
global) — so the same predicate that produced the `JSL` (`CalleeIsFar`) is re-checkable at the peephole.

---

## 4. Implementation recipe

> All edits are **a16-independent** (no `hasAccum16()` gate) — gated on `HasW65816` semantics via the
> far-section predicate, exactly like the existing far `JSL`/`RTL`. Compiler-changing → do it on a
> **worktree** (`wt/320-far-tailcall`, own `vendor/` + warm-copied `build/`; see
> [`howto-feature-worktree.md`](../howto-feature-worktree.md)), not on `main`'s hot shared tree.

### 4a. `MOSInstrLogical.td` — new `TailJML` pseudo

Mirror `TailJMP` verbatim but expand to the **long** jump (`JMP_AbsoluteLong`, `addr24`). Place it directly
after `def TailJMP` (grep for `def TailJMP`):

```tablegen
// #320 far tail call: the far analogue of TailJMP. Emitted by MOSLateOptimization::tailJMP
// only for a `JSL <far global>; RTL` block tail — converts a far->far tail call into a direct
// 24-bit long jump ($5C, sets PBR:PC, relocates R_MOS_ADDR24). The far callee's own RTL pops the
// caller's 3-byte JSL return, so control returns to the original caller (tail-call style). Like
// JSL/RTL, the def carries no Predicate — HasW65816 is enforced at the emit site (the peephole's
// far-section gate, reachable only on W65816 where JSL/RTL exist).
def TailJML : MOSLogicalInstr, PseudoInstExpansion<(JMP_AbsoluteLong addr24:$tgt)> {
  dag InOperandList = (ins label:$tgt);

  let isBarrier = true;
  let isTerminator = true;
  let isCall = true;
  let isReturn = true;
}
```

`PseudoInstExpansion` is tablegen-driven (handled by the generated `MOSGenMCPseudoLowering.inc` via
`MOSAsmPrinter::lowerPseudoInstExpansion`) — **no new C++ for expansion**; no hand-written switch
special-cases `JSL`/`TailJMP`/`JMP_AbsoluteLong` anywhere. (Verified — §8 CLAIM A.) The `(ins label:$tgt)`
shape is identical to `JSL`, so `setDesc(JSL → TailJML)` is operand-compatible (operand 0 = the far global;
implicit arg-reg uses + regmask carry over untouched). (Verified — §8 CLAIM 4.)

### 4b. `MOSLateOptimization.cpp` — the far arm in `tailJMP`

Rewrite `tailJMP` to handle both returns. Gate the far arm on the direct-far-global predicate (mirrors
`MOSCallLowering`'s `CalleeIsFar` — `isGlobal() && section.starts_with(".far_")`):

```cpp
bool MOSLateOptimization::tailJMP(MachineBasicBlock &MBB) const {
  if (MBB.size() < 2)
    return false;
  auto It = std::prev(MBB.end());
  const unsigned RetOp = It->getOpcode();
  if (RetOp != MOS::RTS && RetOp != MOS::RTL)   // near OR far return
    return false;
  MachineInstr &Ret = *It;
  --It;
  const auto &TII = *MBB.getParent()->getSubtarget().getInstrInfo();

  if (RetOp == MOS::RTS) {                       // near: JSR; RTS -> TailJMP   (unchanged)
    if (It->getOpcode() != MOS::JSR)
      return false;
    Ret.eraseFromParent();
    It->setDesc(TII.get(MOS::TailJMP));
    return true;
  }

  // far: JSL <direct far global>; RTL -> TailJML. The RTL terminator already proves the
  // current function is far (lowerReturn emits RTL only for a .far_ frame); restrict the
  // callee to a direct far-function GLOBAL so the bank-0 thunks (__call_near_from_far /
  // __call_indir_far, ChangeToES'd to external symbols) are excluded -- conservative: a
  // misclassification can only miss a win, never emit a wrong-bank/return.
  if (It->getOpcode() != MOS::JSL)
    return false;
  const MachineOperand &Tgt = It->getOperand(0);
  if (!Tgt.isGlobal() || !Tgt.getGlobal()->getSection().starts_with(".far_"))
    return false;
  Ret.eraseFromParent();
  It->setDesc(TII.get(MOS::TailJML));
  return true;
}
```

Notes:
- `TII.get(MOS::TailJML)` / `MBB.getParent()->getSubtarget()` mirror the existing `setDesc` idiom.
- No `hasAccum16()` and no command-line/varargs gate (the peephole is ungated by design — correctness rests
  purely on the call/return adjacency, which `MBB.size()<2` + the two opcode checks enforce; any intervening
  return-value `COPY` or frame teardown naturally blocks it). (Verified — §8 CLAIM III / GAP B.)
- Consider hoisting the far-section predicate into a shared helper if you prefer to dedupe it against
  `MOSCallLowering`'s three `.far_` checks and the selector's `isFarSymbol` — **but** note `isFarSymbol`
  (`MOSInstructionSelector.cpp`) is `static`/file-scope (not callable cross-TU) **and** tests `.far` (no
  underscore, aliasee-aware) vs `MOSCallLowering`'s `.far_`. The two predicates are **not** byte-identical;
  inline-mirroring `CalleeIsFar` (`.far_`, on the direct global) is the precise, minimal choice and avoids a
  refactor that conflates them. (Verified — §8 CLAIM C + correction.)

### 4c. Patch placement

Both edits are a16-free far-call domain → **land in `0001-320-far-addrspace.patch`** (it already edits
`MOSInstrLogical.td` where `JSL`/`RTL`/`TailJMP` live; the peephole hunk newly adds `MOSLateOptimization.cpp`
to `0001`). `0002`/`0003` also edit `MOSLateOptimization.cpp` but in *different* functions (`threadAccum16`,
the txy dead-flag), so the hunks don't overlap and apply cleanly in stack order. After implementing:
`dev/regen-patch.sh` (or `dev/regen-patch-0001.sh`), then **sanity-check the far-tail hunk didn't leak into
a later patch**: `grep -c TailJML patches/llvm-mos/0002-*.patch patches/llvm-mos/0003-*.patch` must be `0`,
and `grep -c TailJML patches/llvm-mos/0001-*.patch` must be `>0`. Confirm `0001` round-trips byte-identical.

---

## 5. Test plan

Far calls are **a16-independent** (8-bit values, A/X CC), so the differential is
`host == mosw65816@MAME == mosw65816@bsnes-jg` — model on `far_near_call`. *(As built, the harness also
exercises the `+mos-a16` build as a host-side `-verify`/disasm leg — the fold is a pure post-RA opcode swap
with no accumulator-mode reference, so this proves mode-independence cheaply without a second ROM.)*

### 5a. Positive test — `examples/65816/far_tail.c` + `dev/far_tail.sh` (new)

Two complementary `.far_text` shapes (both bank `$01`). The first is the minimal demonstrator; the second
makes **execution** target-sensitive and covers multiple tail-blocks per function (added after the post-impl
review flagged the original single-leaf test as execution-insensitive — see §8):

- **`far_outer(x) → far_addk(x)`** — a *single* far→far tail. Folds `jsl`(4)+`rtl`(1) = **5 B → 4 B** (one
  `$5C` long jmp). The size/disasm demonstrator.
- **`far_pick(s, x): if (s) return far_addk(x); return far_xork(x);`** — a *conditional* with **two**
  far-tail blocks tail-calling two leaves that return **distinct** values (`far_addk` = `+0x11`, `far_xork` =
  `^0x5A`). Both blocks fold to `$5C`; block A is adjacent to block B by construction, so a **broken block-A
  tail jump falls through to block B** and yields `far_xork`'s value instead — a *wrong* `corpus_result`, not
  a silent pass. This is what makes execution discriminate the jump target (the leaves share bank `$01`, so
  adjacency/fall-through is the realistic mis-lowering execution can catch within one bank; the disasm gate
  separately proves the `$5C` form).

`main`: `corpus_result = far_pick(1, far_outer(0xA9))` → path A → `far_addk(0xBA)` = **`0xCB`** (a broken
block-A jump would fall through to `far_xork(0xBA)` = `0xE0`).

`dev/far_tail.sh` (model on `dev/far_near_call.sh`), gates in order:

1. **compile+link + a16 leg** `--config mos-snes-far.cfg -mcpu=mosw65816 -Os -mllvm -verify-machineinstrs` →
   clean; **plus** a `+mos-a16` host compile (`-verify` clean + `far_outer` still folds to `$5C`).
2. **disasm gate (the optimization fired):** `far_outer` = exactly **one** long `jmp` carrying
   `R_MOS_ADDR24` into `.far_text`, **no `jsl`, no `rtl`**; `far_pick` = **two** long `jmp`s + two
   `R_MOS_ADDR24`, no `jsl`/`rtl`; `far_addk` and `far_xork` each keep their **own `rtl`**. *(Distinguish the
   `$5C` long `jmp` from a near `$4C` `jmp` by the `R_MOS_ADDR24` reloc — the `R_MOS_ADDR24` + `.far_text`
   conjunction is the load-bearing discriminator, not the bare `jmp` token; see §2. `jml` is `$DC`, the wrong
   instr. The reloc names the **section** `.far_text+N`, not the static symbol.)*
3. **link gate:** all four far functions placed in bank `$01` (`$018000–$01FFFF`) via the `.map`.
4. **execution gate:** boot in MAME, assert `corpus_result == 0xCB`. Close with `emu_verdict` (bsnes-jg
   confirms via `dev/run.sh xcheck`).

Wire into `dev/run.sh` dispatch (+ usage string) and `dev/xcheck.sh` (the bsnes-jg leg), mirroring
`far_near_call`.

### 5b. Negative test — extend `dev/far_near_call.sh`

`far_near_call.c`'s `far_caller` does `return near_helper(x)` — a far→**near** tail whose shape is
`JSL __call_near_from_far; RTL`. The new arm must **NOT** convert it (callee is the external thunk symbol).
Add an assertion to `dev/far_near_call.sh`: `far_caller` still contains **`jsl __call_near_from_far`** and a
trailing **`rtl`** (NOT a long `jmp` to the thunk). This directly exercises the gate's `isGlobal()`
exclusion — a regression guard so a future loosening of the gate can't silently convert a thunk tail.

### 5c. Fuzzer note

The differential fuzzer (`tools/a16_fuzz.py`, csmith) does **not** emit `.far_text` functions, so it won't
reach this path — consistent with every other far test (far is section-attribute-driven, not fuzzer-reached).
The §5a positive e2e + §5b negative assertion are the coverage; both run on **both emulators**.

---

## 6. Verification steps

Run on the worktree `wt/320-far-tailcall` (compiler-changing: own `vendor/` + `cp -a` warm `build/`; the
incremental rebuild took — `clang-23` mtime advanced, `MOSLateOptimization.cpp.o` recompiled referencing the
new `MOS::TailJML`, so tablegen regenerated the pseudo). The warm-copied SDK already had `mos-snes-far.cfg`
+ `__call_near_from_far`, so no SDK rebuild was needed for this compiler-only change. **All six steps
executed 2026-06-22 — all PASS.**

1. **MIR-verify clean (positive), default AND `+mos-a16`:** `dev/run.sh far_tail` compile+link with `-mllvm
   -verify-machineinstrs` clean, plus a `+mos-a16` host leg (the optimization is a16-independent).

   ```
   ==> compile+link .../far_tail.c -> far_tail.sfc  (--config mos-snes-far.cfg -mcpu=mosw65816 -Os)
   /work/build/far_tail.sfc: size=64KiB ...
   ==> a16 gate: the fold is accumulator-mode-independent (-verify clean + still $5C under +mos-a16)
     PASS: +mos-a16 compile + -verify-machineinstrs clean
     PASS: far_outer folds to a long jmp ($5C) under +mos-a16 too (a16-independent)
   ```
   **PASS.**

2. **Disasm gate — the conversion fired (both shapes):** `far_outer` = one `$5C` long `jmp` (`R_MOS_ADDR24`
   into `.far_text`, no `jsl`/`rtl`); `far_pick` = **two** `$5C` folds (its two far-tail blocks); the leaves
   keep their own `rtl`. `far_outer` went `jsl`(4)+`rtl`(1) = **5 B** → long `jmp`(4) = **4 B** (the predicted
   **−1 B**).

   ```
     PASS: far_outer = one long jmp into .far_text (TailJML $5C); no jsl/rtl
     far_pick: long-jmp count=2  R_MOS_ADDR24 count=2
     PASS: far_pick's TWO far-tail blocks both folded to long jmps; no jsl/rtl
     PASS: far_addk keeps its own rtl
     PASS: far_xork keeps its own rtl
   ```
   (Raw `far_outer`: `0: 5c 00 00 00  jmp  ... R_MOS_ADDR24 .far_text+0x11`.) **PASS.**

3. **Execution differential (positive):** `corpus_result == 0xCB` on **MAME** and **bsnes-jg** (host computes
   `0xCB` = `far_pick(1, far_outer(0xA9))`; a broken block-A tail jump would fall through to `far_xork` →
   `0xE0`, so this value proves the jump target, not just stack-balance).

   ```
   # MAME (dev/run.sh far_tail):
   SMOKE: PASS addr=0x7E0202 len=1 got=0xCB (ran 60 ticks)
   RESULT: PASS — far->far tail calls folded to long jmps (TailJML $5C); far_pick took path A and
                  far_addk's RTL returned past far_pick to main; value == 0xCB
   # bsnes-jg (dev/run.sh xcheck):
   PASS  far_tail.sfc: SMOKE: PASS off=0x202 len=1 got=0xCB (ran 180 frames, bsnes-jg)
   RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)
   ```
   **PASS** (both emulators agree).

4. **Negative gate — thunk NOT converted:** `dev/run.sh far_near_call` still PASSes `0xE0`, and the new
   assertion confirms `far_caller`'s `JSL __call_near_from_far; RTL` is **left intact** (the thunk is an
   external symbol → `isGlobal()` false → excluded).

   ```
     PASS: far_caller keeps JSL __call_near_from_far + its own RTL (far->near thunk tail NOT converted)
   RESULT: PASS — far->near mixed-banking call via __call_near_from_far (JSL); ... value == 0xE0
   ```
   **PASS.**

5. **Regression — far suite + corpus + fuzzer green, default build inert:**

   ```
   far_near_call: PASS (0xE0) | corpus: 7/7 passed | far: PASS | far-bank1: PASS (0xF3)
   far_call: PASS (0xF3) | far_cast: PASS (0xF3) | far_indir: PASS (0xF3)
   far_arith: PASS (0xF3) | far_store: PASS (0xF3)
   xcheck (bsnes-jg, all 12 far ROMs incl. packed24_e2e/packed24_table): RESULT: PASS
   csmith fuzz 50 1: 45/50 PASS, 0 xfail, 5 skip  (0 mismatch, 0 crash, 0 error)
   ```
   **PASS** — the fuzzer compiles every program default **and** a16 and finds 0 mismatch, proving the
   peephole is inert for all non-far code (it never emits `.far_text`, so the far arm never fires and the
   near arm is byte-unchanged).

6. **Patch hygiene:** `TailJML` lands in `0001` only; `0001` round-trips the full `0001..0007` stack
   byte-identical; the diff vs `main`'s committed `0001` is *exactly* the far-tail additions.

   ```
   0001: TailJML=3   0002: TailJML=0   0003: TailJML=0
   RESULT: PASS — 0001 round-trips (reapplied 0001..0007 == live vendor, MOS + clang)
   diff(regenerated 0001, main's 0001) = only the TailJML def + the tailJMP far arm + the GlobalValue.h include
   ```
   **PASS.**

---

## 7. Scope / non-goals

- **In scope:** direct **far→far** tail calls (the `JSL <far global>; RTL` shape).
- ~~**Deferred (conservative-excluded, future micro-opt):** converting the **thunk** tails
  (`JSL __call_near_from_far; RTL` and `JSL __call_indir_far; RTL`).~~ **Followed up 2026-06-26**
  ([plan](2026-06-26-320-thunk-tail-calls.md)): the per-thunk stack-discipline proof was discharged.
  **far→near (`__call_near_from_far`) is now DONE** — gate matches the thunk's external symbol by exact name,
  `0xE0` MAME+bsnes-jg. **far-indirect (`__call_indir_far`) is BLOCKED, not deferred** — that *call* path
  doesn't link on `main` (its SDK runtime stub was never landed; `ld.lld: undefined symbol: __call_indir_far`),
  so its tail-opt is premature until the stub + a far-indirect-call e2e land.
- **Not needed:** any GISel/SelectionDAG tail-call lowering — the backend has none (§1); the peephole is the
  complete mechanism.

---

## 8. Verification — two adversarial-workflow passes (2026-06-22)

### 8a. Pre-write design verification (3-agent workflow) — all confirmed

A `Workflow` fan-out red-teamed the design before this plan was written. **Verdict: all claims confirmed; no
stack-corruption case found.**

- **Stack-safety agent (high effort):** CLAIM 1 far→far width invariant ✅; CLAIM 2 near→far can't match
  (`JSL;RTS` not `JSL;RTL`; `RTL` proves far frame) ✅; CLAIM 3 thunks excluded via `ChangeToES`→external,
  and exclusion only misses a win ✅; CLAIM 4 `setDesc` preserves operands + `TailJML` must expand to `$5C`
  not `$4C` ✅.
- **Mechanics agent:** CLAIM A no new C++ (tablegen `PseudoInstExpansion`) ✅; CLAIM B `$5C` = direct
  long jmp, `addr24`, `R_MOS_ADDR24` (and `$DC` `jml` = indirect, the wrong one) ✅; CLAIM C `isFarSymbol`
  is `static`/file-scope + tests `.far` vs `MOSCallLowering`'s `.far_` → inline-mirror `CalleeIsFar` ✅.
- **Scope agent:** CLAIM I no GISel tail path (only `musttail` rejected) ✅; CLAIM II `TailJMP` produced at
  exactly one site ✅; CLAIM III peephole runs every block, immediate-adjacency only ✅; GAP A/B/C: extend
  the opcode match + add the far pseudo (this plan), peephole is ungated (fine), `far_near_call.c` is the
  natural negative test ✅.

**Two caveats folded in:** (1) `TailJML` over `JMP_AbsoluteLong` (`$5C`), never reuse `TailJMP`'s `$4C` —
§2/§4a; (2) the far-section predicate has two non-identical spellings in-tree — inline-mirror `CalleeIsFar`'s
`.far_` form — §4b.

### 8b. Post-implementation review (3-agent workflow) — 2 ship, 1 test-strengthening applied

After building, a second `Workflow` fan-out reviewed the actual diff + tests.

- **C++-correctness agent: ship.** Iterator validity (erasing `Ret` doesn't invalidate the held `It`),
  operand 0 = the call target, `getGlobal()` short-circuit-guarded, `setDesc`-alone sufficiency, no dead
  code, the `GlobalValue.h` include correct/required — all ✅.
- **Gate-precision agent: ship.** All seven far/near/thunk/data scenarios classified; the gate fires on
  exactly direct far→far and excludes the rest; `HasW65816` check confirmed unnecessary (the far arm is
  unreachable on non-W65816 since no `RTL` opcode can exist there) ✅.
- **Test-robustness agent: fix-needed (applied).** Found the original single-leaf test's **execution** gate
  was near-insensitive (the leaf sat immediately after the caller in the *same* bank, so a broken `$5C`
  would fall through to it and still pass) and that `+mos-a16` wasn't exercised. **Fixed:** the test now uses
  a two-distinct-value-leaf **conditional** `far_pick` (two far-tail blocks; a broken block-A jump falls
  through to block B → a *different* value, making execution target-sensitive), plus a `+mos-a16` host leg.
  Re-verified `0xCB` on both emulators (§5a, §6 steps 1–3).
- **Both code agents** independently flagged one comment nit: my source comment wrongly said *both* bank-0
  thunks are excluded by being `ChangeToES`'d to external symbols — true only for `__call_near_from_far`;
  `__call_indir_far` stays a global and is excluded by the **`.far_` section** check. **Comment corrected**
  in `MOSLateOptimization.cpp` (and §4b). The code was already correct (both excluded).

---

## 9. Upstream

Part of the **#320 fork implementation body**, not standalone — it rides on the not-yet-upstreamed far-call
mechanism (`JSL`/`RTL`/thunks). It posts/upstreams with the broader #320 far-call work, after the
five-address-space design note opens the ABI conversation. Add a one-line pointer to
[`upstream-contribution-status.md`](../upstream-contribution-status.md) under the #320 far body if/when the
PR is assembled. No standalone upstream artifact now.

---

## 10. Worktree & resume

- **Worktree:** `wt/320-far-tailcall` off `main` HEAD (compiler-changing: own `vendor/` + `cp -al`/`cp -a`
  warm-copied `build/`; far needs `dev/run.sh toolchain` **and** `dev/run.sh build`). Per policy, **retain
  until the #320 work merges upstream**; durable artifacts (the two recipes, `far_tail.c`, `far_tail.sh`,
  the `far_near_call.sh` negative assertion) land on `main`.
- **Resume:** this plan is the full spec — §4 recipes are mechanical, §5 is the test, §6 the gates. Read
  [`docs/agent-handoff.md`](../agent-handoff.md) (build/disasm/differential mechanics) +
  [`2026-06-21-320-far-calls-followups.md`](2026-06-21-320-far-calls-followups.md) (the far-call mechanism
  this builds on) first.
