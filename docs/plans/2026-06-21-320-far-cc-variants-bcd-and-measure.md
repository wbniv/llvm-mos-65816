# #320 Inc 4 Ph2 — far-ptr CC variants (b)/(c)/(d) + measurement (implementation plan)

**Date:** 2026-06-21 · **Status:** IN PROGRESS (A1 variant b underway) · **Scope:** `vendor/llvm-mos/` codegen
(the CC) on `wt/320-far-cc`. **Supplements** the parent plan
[2026-06-20-320-far-pointer-cc-build-all-variants.md](2026-06-20-320-far-pointer-cc-build-all-variants.md)
(variant matrix, go/no-go, workload, verification bar) with the **implementation-level mechanism** discovered
during A0 + the A1 investigation. **Builds on:** A0 (variant (a) Imag32) DONE & two-emulator verified
(`wt/320-far-cc 10a5fc0`).

## Where A0 left us (carry-forward decisions)

- **Variant (a) Imag32 works** (`+mos-farcc-imag32`): a far ptr crosses a call in one `RL` (Imag32) quad,
  both arg + return. Round-trips `0xF3` on MAME + bsnes-jg; `-verify-machineinstrs` clean; default
  byte-identical; csmith 30 seeds 0-mismatch.
- **Two fixes were needed, both carried by all variants:** (1) `getRegisterTypeForCallingConv` sizes a far
  (addrspace 2) pointer at its true 32 bits when a variant is selected; (2) **`Imag32 ∈ AnyRegBank`** so a far
  ptr only COPY'd through a fn (never deref'd locally) gets a register class via `constrainGenericOp`.
- **Patch home:** the far-CC delta is a stacked **`0004-320-far-cc.patch`** (`dev/regen-patch-0004.sh`),
  **not** folded into `0001`, because the bank fix shares the `AnyRegBank` line with `0002`'s `Ac16`. Keep
  regenerating `0004` after each variant. `0001` stays a16-free.

## The crux for (b) and (c): a HETEROGENEOUS register split

(a) was easy — the whole 32-bit value goes to one 32-bit `RL`, a single COPY. (b) and (c) split the far
pointer into **{16-bit offset, 8-bit bank}** — two registers of **different widths**. The uniform
`getNumRegistersForCallingConv` / `getRegisterTypeForCallingConv` mechanism returns *N copies of one MVT*, so
it cannot express `{i16, i8}`. The supported GISel path is **`assignCustomValue`** (`CallLowering.h:310`,
dispatched at `CallLowering.cpp:794` when `VA.needsCustom()`), exactly as ARM splits an `f64` into two GPRs
(`ARMCallLowering.cpp:142` outgoing / `:319` incoming).

**Mechanism (mirrors ARM, adapted for a heterogeneous pointer split):**

1. **CC table (`MOSCallingConv.td`):** for variant (b)/(c), the far-ptr rule is a **custom** entry — a C++
   assigner `CC_MOS_FarPtrSplit` / `CC_MOS_FarPtrAXY` that allocates the two locations and pushes **two**
   `CCValAssign`s via `State.addLoc(CCValAssign::getCustomReg(...))`, each marked `needsCustom`:
   - (b): offset → an `RS#` (Imag16 pair, caller-saved RS2..RS7); bank → an `RC#` (Imag8).
   - (c): offset → the `A:X` pair (the i16 return convention regs); bank → `Y`.
   Allocation runs *inside* the table CC, so coordination with near-pointer/scalar args (AllocateReg unit
   aliasing) is automatic — the same reason (a) used `CCAssignToReg`.
2. **`MOSCallLowering` handlers** override `assignCustomValue(Arg, VAs, Thunk)`:
   - **Outgoing** (caller / return value out): decompose `Arg.Regs[0]` (the `p2`): `i32 = G_PTRTOINT p2`;
     `offset = G_TRUNC i32 → s16`; `bank = G_TRUNC (G_LSHR i32, 16) → s8`. Then (via `Thunk`, like ARM)
     `assignValueToReg(offset, VAs[0].getLocReg(), VAs[0])` and `assignValueToReg(bank, VAs[1]...)`.
   - **Incoming** (callee formal / return value in): `assignValueToReg` each phys reg into a vreg
     (`offset:s16`, `bank:s8`), then rebuild: `bankw = G_ZEXT bank → s32; off32 = G_ZEXT offset → s32;
     hi = G_SHL bankw, 16; i32 = G_OR off32, hi; p2 = G_INTTOPTR i32`. Write into `Arg.Regs[0]`.
   - Return 2 (VAs consumed). `assert(Arg.Regs.size()==1)`.
3. **Legality:** these are `s32`/`s16`/`s8` ops + `G_PTRTOINT`/`G_INTTOPTR`/`G_TRUNC`/`G_ZEXT`/`G_SHL`/`G_OR`
   — all already legal under `+mos-a16` (the s32 value path Inc 3 relies on). A far ptr crossing a call already
   requires `+mos-a16` to *form* (inttoptr of a 32-bit runtime value), so no new legalizer rules expected;
   confirm with `-verify-machineinstrs`. The "Generic extend/truncate can not operate on pointers" error means
   we must go through `G_PTRTOINT` first (not unmerge the `p2` directly) — that is exactly why step 2 ptrtoints.

This mechanism is **built once for (b)** and **reused by (c)** (only the registers differ:
`RS#`/`RC#` → `A:X`/`Y`). (d) is different (stack), below.

## Per-variant design

| Variant | Flag | Offset (low 16) | Bank (1 byte) | Return | Mechanism |
|---|---|---|---|---|---|
| (a) Imag32 ✅ | `+mos-farcc-imag32` | — whole 32-bit in one `RL` quad — | `RL` | `CCAssignToReg` (uniform i32) — **done** |
| (b) Imag16+bank | `+mos-farcc-split` | `RS#` (RS2..RS7) | `RC#` (Imag8) | offset `RS1`+bank `RC#` | custom `assignCustomValue` |
| (c) A:X+Y | `+mos-farcc-axy` | `A:X` | `Y` | same (A:X+Y) | custom `assignCustomValue` (reuse b's) |
| (d) hw-stack | `+mos-farcc-stack` | — 3–4 bytes pushed on the 65816 stack (reverse) — | via `CCAssignToStack` | the soft-stack path already exists; far ptr → 4-byte stack slot |

**(d) note:** the parent plan frames (d) as the WDC816CC/ORCA prior-art control. The existing
`CCAssignToStack` already passes overflow values on the soft stack; a far ptr (32-bit) → one 4-byte stack slot
is the *uniform* path (no custom split) — likely the **least** code of b/c/d, but per-access cost on the
callee side. If `CCAssignToStack<0,1>` + the 32-bit value handler already covers it once a far ptr is sized at
i32 (the A0 `getRegisterType` change) and stack-assigned, (d) may be nearly free to add. Measure.

## Phased, gated sequence (remaining)

| Phase | Deliverable | Gate |
|---|---|---|
| **A1 (b)** | `CC_MOS_FarPtrSplit` custom assigner + `assignCustomValue` (offset→RS#, bank→RC#); `+mos-farcc-split`. | `examples/65816/farcc_split.c` (reuse the farcc round-trip shape) round-trips `0xF3` on MAME + bsnes-jg; `-verify-machineinstrs`; negative control; **default byte-identical**. |
| **A2 (c)** | `CC_MOS_FarPtrAXY` (offset→A:X, bank→Y), reusing the `assignCustomValue` split. | same bar, `farcc_axy.c`. The (a)-vs-(c) head-to-head is the most informative (all-ZP vs hardware-reg). |
| **A3 (d)** | `+mos-farcc-stack`: far ptr → 4-byte soft-stack slot (uniform). Likely just a CC rule + the i32 stack path. | same bar, `farcc_stack.c`. Record-and-drop only if it proves materially harder for no plausible win. |
| **M** | `dev/probe-cycles.lua` (MAME `totalcycles` sentinel) + `dev/measure-far-cc.sh`: N-way bytes+cycles table on the far-ptr-passing corpus, every cell differentially verified. Build the **census** first (how often far ptrs cross calls in realistic code) — it may short-circuit. | The `prog \| a \| b \| c \| d \| Δ` table (bytes + cycles), inner-loop + whole-call brackets. |
| **D** | Apply the pre-registered go/no-go (parent plan): ship the smallest-not-slower variant; ties → (a). Land the winner; record the rest. | Winner differential-clean; `0004` round-trips; docs + decision record + upstream evidence paragraph queued. |

## Workload (extends A0's `farcc_imag32.c`)

Each variant gets a `farcc_<variant>.c` that is the **same round-trip shape** as `farcc_imag32.c` (a far ptr
returned from `make_far_ptr()` AND passed into `deref_far()` across noinline calls), built with the variant's
flag. Plus the parent plan's richer cases: **pass a far ptr among other args** (forces the spill/coexistence
rule — the real test of the table-CC allocation coordination) and a **multi-layer far buffer-walk kernel** for
the measurement. Reuse `dev/farcc_imag32.sh` as the script template (negative control + disasm + placement +
execution gates + `emu_verdict`); reuse `tools/a16_fuzz.py evaluate()` extended with the `+mos-farcc-*` flags.

## Verification (per variant, the project differential)

1. **Default byte-identical** (`dev/frameabi-byte-identical.sh`, before/after) — every variant is gated on its
   off-by-default feature; adding it must not perturb corpus+kernels default/+mos-a16. (A0 held; keep holding.)
2. **Round-trip** on MAME + bsnes-jg (`dev/run.sh farcc_<v>` + `xcheck`), `-verify-machineinstrs` clean,
   negative control (no flag ⇒ does not compile / errors as before).
3. **Coexistence**: a far ptr passed alongside near ptrs + scalars compiles + round-trips (the custom assigner
   must not double-book a register the table CC also hands out).
4. **Non-regression**: existing far ROMs rebuilt with the new toolchain still `0xF3` (the A0 bank/getRegType
   changes are shared); csmith fuzz `--gen csmith 30 1` 0-mismatch.
5. **Patch hygiene**: `dev/regen-patch-0004.sh` round-trips; staged set is exactly the authored files; `0001`
   stays a16-free; `0002`/`0003` untouched.

## Critical files

- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSCallingConv.td` — add the (b)/(c) custom far-ptr rules (gated, before
  `CCIfPtr`); `MOSCallingConv.h`/`.cpp` — declare/define `CC_MOS_FarPtrSplit`/`CC_MOS_FarPtrAXY` (push the two
  custom `CCValAssign`s).
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSCallLowering.cpp` — override `assignCustomValue` on the
  outgoing/incoming handlers (ptrtoint/trunc/merge); the `getCustomReg` plumbing.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.td` — `A`,`X`,`Y` already exist; no new regclass for
  (b)/(c). (d) reuses the soft stack — `MOSInstrInfo.td` `,S` defs only if (d) needs hardware-stack addressing.
- Harness: `dev/probe-cycles.lua` + `dev/measure-far-cc.sh` (new, phase M); `dev/farcc_*.c`/`.sh` (per variant);
  reuse `dev/frameabi-byte-identical.sh`, `dev/regen-patch-0004.sh`, `tools/a16_fuzz.py`.

## Reference (the GISel custom-split contract)

- `CallLowering.cpp:794` dispatches `assignCustomValue(Arg, ArrayRef(ArgLocs).slice(j), &Thunk)` when
  `VA.needsCustom()`; the return value (count of VAs consumed) advances the loop.
- ARM model: `ARMCallLowering.cpp:142` (outgoing, `buildUnmerge` + Thunk'd `assignValueToReg`) / `:319`
  (incoming, `assignValueToReg` + `buildMergeLikeInstr`). We substitute ptrtoint/trunc (out) and
  merge/inttoptr (in) for ARM's uniform unmerge/merge because our split is heterogeneous (`{i16,i8}`).

## Out of scope / non-goals

- **Not** changing near-pointer/scalar passing or the A/X scalar return convention (LOCKED) — far (p2) only.
- **Not** far function pointers / indirect far calls — far *data* pointers crossing a call.
- **Not** auto-merging all variants: only the measured winner lands; the rest stay an inert spike on
  `wt/320-far-cc`.
