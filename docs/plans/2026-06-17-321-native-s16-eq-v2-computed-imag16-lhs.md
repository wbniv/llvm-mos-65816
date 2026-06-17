# #321 — native s16 equality-as-value v2: computed/`Imag16`-resident operands (`(a+b) == c`)

**Date:** 2026-06-17
**Status:** **DONE — landed 2026-06-17.** A **gate-only** change (no new pseudo): the native 16-bit
compare now fires when both operands are already **`Imag16`-resident** (a computed s16 value — generic
`G_ADD/...` *or* a load-rooted MOS combiner pseudo — or an indirect load) or one is a constant. Measured
`computed == computed` **−3 B**, `computed == const` **−2 B**, a multi-use chained test (`a16eqvalc`)
**146 → 133 B (−13 B)**; a register/param operand stays 8-bit **byte-identical** (the +8 B spill
avoided). Verified: `a16eqvalc` native + `0x1101` on MAME+bsnes-jg, a16 suite + corpus + **fuzz 50/50**,
`-verify-machineinstrs` clean, `0002` round-trips. The value rides the existing
`buildNZSelect → MOSLowerSelect → G_BRCOND_IMM → CmpBrImag16/CmpBrImm16` path.
**ROADMAP:** step 5 (M2) · **TODO:** M2 "native s16 equality-as-value — v2"
**Predecessors:** [v1 indirect](2026-06-16-321-native-s16-eq-gated-impl.md) ·
[v3 both-global](2026-06-17-321-native-s16-eq-as-value-v3-abs-fold-globals.md) ·
[eq-imm const-merge](2026-06-17-321-native-s16-eq-imm-constant-through-merge.md) ·
[design + spike](2026-06-16-321-native-s16-eq-as-value-cmpsel.md) (the −3 B / +8 B residency table).

## Why this is gate-only (grounded in GMIR)

At `legalizeICmp` time a computed operand `(a+b)` is a plain `G_ADD %b, %a` (s16) — the native s16 ALU
(`selectAlu16Native`) produces its result **into `Imag16`**. So the existing value path already knows how
to compare it: `selectBrCondImm`'s `m_CmpNZImag16` reads the LHS/RHS from `Imag16` (`LDAImag16`/
`CMPImag16`), and `m_CmpNZImm16` handles a constant RHS (`CMPImm16`, now reliable via `getI16Const`).
**Branch uses of computed compares already do exactly this** (`a16localx` etc. compute s16 and branch) —
v2 only opens the same path to **value** uses. No new pseudo, no `selectBrCondImm`/`expandCmpBr16` change.

The residency table from the spike (native EQ-as-value vs the 8-bit chain), which dictates the gate:

| operand residency | shape | Δ | v2 |
|---|---|--:|---|
| **`Imag16` computed/local** | `eq_local` (`(a+b) == c`) | **−3** | **fire (this plan)** |
| indirect deref | `*p == c` | −4 | v1 |
| global (abs) | `g1 == g2` / `g == 0x1234` | win w/ fold | v3 |
| register / param | `a == c` (`a`,`c` in regs) | **+8** | **stay 8-bit** |

The +8 B register/param regression is the one to avoid: a register operand must **spill** to `Imag16`
(`sta; stx` + `rep`/`sep`) for the native `CMPImag16`, where the 8-bit `cpx; cmp` reads the register
directly. So v2 must fire **only** when neither operand is a register-arg (and not a global — v3's domain).

## Design — one gate disjunct

`MOSLegalizerInfo.cpp`, beside the v1/v3 predicates:

```cpp
// #321 v2: an s16 value already resident in Imag16 — a computed native-s16 result or an
// indirect load (isIndirectS16Load). NOT a register-arg (G_MERGE_VALUES of COPY $physreg
// -> would spill), a global (v3), or a constant. getDefIgnoringCopies looks through COPYs.
auto isComputedS16 = [&](Register Reg) -> bool {
  MachineInstr *Def = getDefIgnoringCopies(Reg, MRI);
  if (!Def || MRI.getType(Def->getOperand(0).getReg()) != LLT::scalar(16))
    return false;
  switch (Def->getOpcode()) {
  // Generic native-s16 ALU/shift (single-use computed -> Imag16).
  case TargetOpcode::G_ADD: case TargetOpcode::G_SUB:
  case TargetOpcode::G_AND: case TargetOpcode::G_OR: case TargetOpcode::G_XOR:
  case TargetOpcode::G_SHL: case TargetOpcode::G_LSHR: case TargetOpcode::G_ASHR:
  // Load-rooted MOS combiner pseudos: a near-abs-global computation that is REUSED, so
  // its result is stored to Imag16 (the store-rooted "_ABS" forms feed a store, never a
  // compare operand). Discovered during impl: a multi-use `(a+b)` of globals becomes
  // G_ADD16_ABSLD, not generic G_ADD, so without these the multi-use case stays 8-bit.
  case MOS::G_ADD16_ABSLD: case MOS::G_SUB16_ABSLD:
  case MOS::G_ADDCHAIN16_ABSLD: case MOS::G_BITCHAIN16_ABSLD:
    return true;
  default:
    return false;
  }
};
auto isImag16Resident = [&](Register Reg) -> bool {
  return isComputedS16(Reg) || isIndirectS16Load(Reg);
};
const bool ComputedEq =
    (isImag16Resident(LHS) && (isImag16Resident(RHS) || RHSIsCst)) ||
    (isImag16Resident(RHS) && (isImag16Resident(LHS) || LHSIsCst));
// ... add `|| ComputedEq` to NativeS16Eq, beside BothGlobal / GlobalVsImm.
```

Covered: `computed == computed`, `computed == indirect`, `computed == nonzero-const` (+ symmetric).
Excluded by construction: `computed == register` (spill), `computed == global` (mixed; not measured —
left to a micro-follow-up), `_ == 0` (the `!RHSIsZero` guard keeps it on `G_CMPZ`).

No canonicalization needed: for `computed == const`, the constant is already RHS-canonical and
`m_CmpNZImm16` reads operand 6; for `computed == computed`, order is immaterial (`CMPImag16` either way).

## Measurement (measure first — the residency win is not assumed) — DONE

`+mos-a16` `.text` bytes, v2-on vs v2-off (gate disabled), single source per shape:

```
computed == computed   (a+b)==(c+d)   71 -> 68 B   (-3, the spike's number)
computed == const      (a+b)==0x1234  60 -> 58 B   (-2)
multi-use chained       a16eqvalc     146 -> 133 B (-13; CmpBrImag16 ×2 + CmpBrImm16, cpxy 0)
computed == param       f(p){(a+b)==p} 0x32 -> 0x32 (byte-identical; gate declines, [2 CmpBrImag8])
```

The param case stays 8-bit (`isComputedS16` matches no register-arg, so the spill is never taken) →
no regression. The computed cases select `LDAImag16`/`CMPImag16` (or `CMPImm16`) with no `cpx/cpy`.

## Verification steps

1. **`dev/run.sh a16eqvalc` — PASS.** `examples/65816/a16eqvalc.c` + `dev/a16eqvalc.sh`: `(a+b)==(c+d)`,
   `(a+b)==(c+a)`, `!=`, `(a+b)==0x1234` as stored values.
   ```
   PASS: 4 rep #$20 bracket(s) — native 16-bit compares
   PASS: 3 native 16-bit cmp ops (computed operands compared in Imag16)
   PASS: 1 cmp #imm16 (computed==const folds to cmp #imm)
   PASS: no 8-bit cpx/cpy compare-chain (fully native 16-bit)
   SMOKE: PASS got=0x1101 (MAME default / MAME +mos-a16 / bsnes-jg)
   ```
   `-verify-machineinstrs` clean. **PASS.**
2. **No regression — PASS.** `computed == param` byte-identical to v2-off (measurement above).
3. `dev/run.sh a16eq a16eqval a16eqvalp a16eqvalg a16cmp a16scmp a16localx a16chainld a16bitchain
   a16loadfold` — all green (the `_ABSLD` multi-use pseudos still select correctly; the s16 ALU/chain
   tests unaffected). **PASS.**
4. **Non-breaking — PASS.** a16 suite (24/24 in this batch + the eq set) + `dev/run.sh corpus` (7/7);
   `dev/run.sh fuzz 50 1` → **`50/50 PASS, 0 mismatch / 0 new-crash / 0 error`**.
5. `dev/regen-patch.sh` (host) → **`RESULT: PASS — 0002 round-trips`**. **PASS.**

## Risks

- **Residency mis-model** → a "computed" operand that isn't `Imag16`-resident at selection (threaded in
  A16, or a spill) → a regression. Mitigation: branch-use computed compares already read `Imag16`
  (proven by `a16localx`); the measurement §1–3 + the disasm spill-check are the guard; the enumerated
  opcode set is conservative (only the native s16 ALU/shift ops).
- **Register operand sneaks in** → +8 B. Mitigation: `isComputedS16` matches only ALU/shift opcodes, so
  a `G_MERGE_VALUES(COPY $physreg)` register-arg is never `Imag16`-resident; `computed == register` needs
  the register side to be `isImag16Resident`/const, which it isn't → gate declines.
- **Blast radius:** s16 computed-`==`-as-value sites. Fuzzer + quiet box.
