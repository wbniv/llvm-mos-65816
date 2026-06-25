# #320 thunk tail calls — far→near folds; far-indirect is BLOCKED

**Date:** 2026-06-26 · **Issue:** #320 (M1, far pointers/calls) · **Status:** ✅ **Phase A DONE + verified
both emulators** (far→near thunk tail). ⛔ **Phase B BLOCKED** — far-indirect calls don't link on `main`
(prerequisite unlanded). · **Builds on:** `4adda8b` (direct far→far tail, the `TailJML` pseudo + far arm) ·
**Worktree:** `wt/320-far-tail-thunks`.

---

## 0. TL;DR

The far-tail peephole (`MOSLateOptimization::tailJMP`) already folds a **direct far→far** tail
`JSL <far global>; RTL` → `TailJML` (`$5C` long jump, −1 B), landed `4adda8b`. Its §7 left **two thunk-tail
cases deliberately excluded** (the conservative gate keyed on `isGlobal() && .far_`):

- **(b) far→near** — `JSL __call_near_from_far; RTL` (the thunk is `ChangeToES`'d to an EXTERNAL symbol).
- **(c) far-indirect** — `JSL __call_indir_far; RTL` (the thunk is a bank-0 global in a non-`.far_` section).

**Phase A (this change) folds (b).** Broaden the far arm to also match `__call_near_from_far` by exact symbol
name. Per converted far→near tail: **−1 B** + the redundant push/pop dropped. Conservative — matched by exact
name (mirrors how `MOSCallLowering` special-cases the same symbol), so any other `JSL` is left alone.

**Phase B (c) is BLOCKED by a prerequisite, not by the gate.** A far-indirect *call* doesn't even link on
`main`: `__call_indir_far`'s runtime stub (`call-indir-far.s` + the `__mos_far_target` slot) was never landed
into the tracked `platforms/snes/` or the SDK — only WIP commits (`7ee5f6f`, `1ea7507`) exist. Proven below
(§4). Optimizing the tail of a path that doesn't link is premature; the `IndirFarThunk` arm was intentionally
**not** added. Recommended follow-up: land the stub + a far-indirect-**call** e2e first (that also closes a
latent overclaim — the status doc lists far-fn-pointer *calls* as "done + landed", but they don't link).

---

## 1. The stale-doc discovery (why this work was even opened)

`docs/implementation-status.md` carried a **self-contradicting** pair: the summary (`:53-54`) recorded the
`4adda8b` landing, but the table row (`:72`) still said *"tail peephole keys on `JSR`, so a `JSL` is never
tail-converted"* — the pre-`4adda8b` text. The direct far→far fold has been live + two-emulator verified
since 2026-06-23. This change fixes the row and folds the far→near thunk tail on top.

---

## 2. Stack-discipline proof — far→near thunk tail (the crux)

A far function `F` is entered by its caller's `JSL F`, leaving a **3-byte** return `R_F` on top. `F`'s tail
`return near_helper(x)` lowers to `JSL __call_near_from_far; RTL`. The thunk
(`platforms/snes/call-near-from-far.s`):

```asm
__call_near_from_far:
	pea	.Lback-1	; push the near RTS target (2-byte)
	jmp	(__rc18)	; near indirect jump to the near callee (PBR stays $00)
.Lback:
	rtl			; pop the 3-byte far return
```

```
BEFORE  (JSL __call_near_from_far; RTL)         AFTER  (TailJML __call_near_from_far)
  entry: [R_F]            (3-byte)                entry: [R_F]
  JSL thunk  -> push R_thunk (3)  [R_F][R_thunk]  JMP.l thunk  -> push NOTHING; PBR:=$00  [R_F]
    pea .Lback-1 (2) ; jmp(ind) -> near callee      pea .Lback-1 (2) ; jmp(ind) -> near callee
    callee RTS pops back -> .Lback                  callee RTS pops back -> .Lback
    rtl pops R_thunk -> back to F's RTL              rtl pops R_F (3) -> F's caller  ✓ tail
  RTL pops R_F (3) -> F's caller
```

The thunk's `pea`…`rts` is a **net-0** near frame, so the 3-byte `R_F` beneath is untouched; its terminal
`rtl` pops exactly `R_F` → control lands at **`F`'s caller** with the result in the return register. The
folded `JSL`'s own 3-byte return is exactly what the long jump elides. The dangerous near→far shape
`JSL g; RTS` can never reach here (the arm requires an `RTL` terminator, which `lowerReturn` emits only for a
`.far_` frame). **No corruption.**

---

## 3. Implementation

### 3a. `vendor/llvm-mos/.../MOSLateOptimization.cpp` — broaden the far arm

`+#include "llvm/ADT/StringRef.h"` and replace the single `isGlobal && .far_` predicate with two named
arms (lands in `0001`):

```cpp
  const MachineOperand &Tgt = It->getOperand(0);
  const bool DirectFarGlobal =
      Tgt.isGlobal() && Tgt.getGlobal()->getSection().starts_with(".far_");
  const bool NearFromFarThunk =
      Tgt.isSymbol() &&
      StringRef(Tgt.getSymbolName()) == "__call_near_from_far";
  if (!DirectFarGlobal && !NearFromFarThunk)
    return false;
  Ret.eraseFromParent();
  It->setDesc(TII.get(MOS::TailJML));
  return true;
```

No new pseudo: `TailJML` (`JMP_AbsoluteLong`/`$5C`/`addr24`/`R_MOS_ADDR24`) is operand-compatible with the
`JSL_AbsoluteLong addr24` operand for **both** a global and an external symbol (`setDesc` swaps only the
opcode). The thunk lives in bank `$00`, `F` in bank `$01`, so the `$5C` cross-bank jump is exactly right.

### 3b. `dev/far_near_call.sh` — flip negative → positive

`far_caller`'s only call is its tail, so it now folds. The old NEGATIVE gate (assert `jsl+rtl`, no `jmp`)
becomes a POSITIVE gate: assert a long `jmp __call_near_from_far` (`$5C`, **`R_MOS_ADDR24`** — distinguishes
it from a near `$4C`/`R_MOS_ADDR16`) and **no** `jsl`/`rtl` in `far_caller`. Kept unchanged: the thunk body
gate (`pea`+`jmp(ind)`+`rtl`), the link/bank gates, and the execution gate `corpus_result == 0xE0`.

### 3c. `dev/regen-patch-0001.sh` — `STACK` was stale

The regen verify `diff -rq`'s the whole MOS dir; live vendor now has `0010`–`0012` applied
(`MOSRegisterInfo.cpp`/`MOSMCInstLower.cpp`), but `STACK` stopped at `0009`, so the round-trip would falsely
FAIL. Appended `0010`/`0011`/`0012` (the script's own contract: "append new patches to STACK") + updated the
`0001..0007` → `0001..0012` echo/comment strings.

---

## 4. Phase B proof — far-indirect calls don't link on `main`

A minimal clang `far`-attribute call, compiled with the worktree toolchain:

```
$ mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os -c probe.c
  17: 22 00 00 00  jsl  $0 <main>
        00000018:  R_MOS_ADDR24  __call_indir_far          # compiles fine
$ mos-clang --config mos-snes-far.cfg -mcpu=mosw65816 +mos-a16 -Os -o probe.sfc probe.c
  ld.lld: error: undefined symbol: __mos_far_target
  ld.lld: error: undefined symbol: __call_indir_far        # <-- the gap
```

`__call_indir_far` / `__mos_far_target` exist nowhere in the live SDK; the snes `CMakeLists.txt` builds crt0
from only `crt0.c header.s call-near-from-far.s`. So far-indirect calls are unlinkable on `main` — its
thunk-tail opt is premature. **Recommended follow-up (separate plan):** restore `platforms/snes/call-indir-far.s`
(`jml (__mos_far_target)` + the 4-byte `.noinit` slot) per `docs/plans/2026-06-21-320-far-calls-followups.md`
§, add a far-indirect-**call** e2e (resurrect `far_fnptr.c`), confirm it links + runs on both emulators, THEN
add the `IndirFarThunk` arm (its stack proof: the stub pushes nothing, so the far target's `RTL` pops `R_F`).

---

## 5. Verification — all PASS (2026-06-26, worktree `wt/320-far-tail-thunks`)

Incremental rebuild took (`clang-23` mtime 02:48 → 05:26; `MOSLateOptimization.cpp.o` recompiled).

**1. far→near tail folds; execution `0xE0` on MAME (`dev/run.sh far_near_call`):**
```
==> disasm gate: the far->near TAIL call folds to a long jmp to __call_near_from_far (TailJML $5C), not jsl+rtl
       8: 5c 00 00 00  	jmp	$0 <far_caller>
			00000009:  R_MOS_ADDR24	__call_near_from_far
  PASS: far_caller's far->near tail folded to a long jmp __call_near_from_far ($5C, R_MOS_ADDR24); no jsl/rtl
  PASS: near helper still returns via RTS
  PASS: thunk body = pea + jmp(ind) + rtl
  PASS: __call_near_from_far linked into the ROM
  PASS: far_caller in bank $01
SMOKE: PASS addr=0x7E0201 len=1 got=0xE0 (ran 60 ticks)
RESULT: PASS
```
**PASS.**

**2. Second emulator + far suite unregressed (`dev/run.sh xcheck`, bsnes-jg):**
```
  PASS  far_near_call.sfc: SMOKE: PASS off=0x201 len=1 got=0xE0 (ran 180 frames, bsnes-jg)
  PASS  far_tail.sfc:      SMOKE: PASS off=0x202 len=1 got=0xCB (ran 180 frames, bsnes-jg)
  ... (all 12 far ROMs PASS) ...
RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)
```
**PASS** (both emulators agree on `0xE0`).

**3. Direct far→far still folds + a16-independent (`dev/run.sh far_tail`, MAME):**
```
  PASS: +mos-a16 compile + -verify-machineinstrs clean
  PASS: far_outer folds to a long jmp ($5C) under +mos-a16 too (a16-independent)
  PASS: far_pick's TWO far-tail blocks both folded to long jmps; no jsl/rtl
SMOKE: PASS addr=0x7E0202 len=1 got=0xCB (ran 60 ticks)
RESULT: PASS
```
**PASS.**

**4. Default codegen unaffected — corpus 7/7; fuzz 0-mismatch:**
```
==> corpus: 7/7 passed
==> csmith: 45/50 PASS, 0 xfail, 5 skip  (0 mismatch, 0 crash, 0 error)
```
**PASS** (5 skips = the standard `corpus_result GC'd` category).

**5. Patch hygiene (`dev/regen-patch-0001.sh`):**
```
RESULT: PASS — 0001 round-trips (reapplied 0001..0012 == live vendor, MOS + clang)
TailJML: 0001=3  0002=0  0003=0
diff(regenerated 0001, main's 0001) = only the StringRef include + the far-arm broadening
```
**PASS.**

---

## 6. Scope / non-goals

- **In scope:** the far→near thunk tail `JSL __call_near_from_far; RTL` → `TailJML`.
- **Blocked (prerequisite unlanded):** the far-indirect thunk tail — `__call_indir_far` doesn't link (§4).
- **Not needed:** a new pseudo (reuse `TailJML`), any GISel tail path (the peephole is the whole mechanism).

## 7. Upstream

Rides on the not-yet-upstreamed #320 far-call mechanism; no standalone upstream artifact (mirror the
existing far-tail pointer in `docs/upstream-contribution-status.md` when the #320 PR is assembled).
