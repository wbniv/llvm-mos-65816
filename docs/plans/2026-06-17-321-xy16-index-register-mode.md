# Plan: xy16 — 16-bit X/Y index mode (ROADMAP step 5, second half)

**Implementation branch:** `wt/321-xy16` · **Worktree:** `/home/will/SRC/llvm-mos-65816-xy16`  
**Handoff doc:** [`docs/plans/2026-06-18-321-xy16-implementation-handoff.md`](2026-06-18-321-xy16-implementation-handoff.md)
(in the worktree — read it first; covers vendor/ bootstrap, ccache setup, commit discipline, merge-back checklist)

## Context

ROADMAP step 5 second half: the M-flag/accumulator dimension (`+mos-a16`) is complete; the
X-flag/index dimension (`+mos-xy16`) is the next major increment. Together they constitute full
native-register-width codegen for the 65816.

**Prerequisites already done:**
- `platforms/snes/crt0.c` — XCE (enters native mode E=0), native-mode vectors in `link.ld`
  ($FFE4–$FFEF), and final `SEP #$30` anchors 8-bit A+index as the codegen default. DBR stays at
  $00 (reset default; all platform data in bank 0). No crt0 changes needed.
- TSFlags `XLow`/`XHigh` (bits 2–3) already in `MOSMCTargetDesc.h` and `MOSInstrFormats.td` base
  class (`bit XLow = 0; bit XHigh = 0; TSFlags{2}=XLow; TSFlags{3}=XHigh`).
- `MOSInsertREPSEP.cpp` handles the M flag end-to-end and is the direct template for the X
  dimension.
- Latent tripwires already documented at `MOSRegisterInfo.cpp` (`expandLDSTStk` assert) and
  `MOSInstrInfo.cpp` (`loadStoreRegStackSlot` assert).

**Out of scope for this plan:** hardware-stack ABI and new calling convention (ROADMAP step 5
follow-on). This plan gives X/Y 16-bit inside functions while maintaining the current 8-bit
call-boundary ABI. General 16-bit X/Y arithmetic (`a+b` where `a` is in Xc16) routes through
Ac16 via `TXA16+ALU+TAX16` — deferred to a follow-on.

---

## Design notes and corrections vs. the initial draft

These were identified by auditing the existing code before writing the plan.

1. **`STXIndir16`/`LDXIndir16` can't be PseudoInstExpansion** — multi-instruction sequences
   (TXA+STA, LDA+TAX) cannot expand 1:1 to a single MC instruction. **Fix:** introduce
   `TXA16`/`TAX16`/`TYA16`/`TAY16` logical pseudos (PseudoInstExpansion to the confirmed-present
   `TXA_Implied`/`TAX_Implied`/`TYA_Implied`/`TAY_Implied` MC instructions in `MOSInstrInfo.td`);
   expand Xc16/Yc16 **inline** in `expandLDSTStk` using those + existing `STAIndir16`/`LDAIndir16`.
   No separate `STXIndir16`/`LDXIndir16` pseudos.

2. **`insertSwitch` only handles same-direction combined case** — when M needs 16-bit and X needs
   8-bit simultaneously (or vice versa), two separate REP/SEP instructions are required. The
   combined `REP #$30`/`SEP #$30` optimization is only valid when both flags switch to the **same**
   mode. Full logic in Layer 3.

3. **`HasIndex16` predicate missing from `MOSInstrFormats.td`** — needed for
   `let Predicates = [HasIndex16]` in `.td` files. Add `def HasIndex16` there analogous to
   `def HasAccum16`.

4. **Use `[FeatureAccum16]` as the `Implies` argument** of SubtargetFeature — cleaner than an
   assert, enforced at TableGen level. Also makes the pass gate simpler: since `hasIndex16()`
   always implies `hasAccum16()`, the existing `!hasAccum16() → return false` gate is already
   sufficient for both features — no gate change needed.

5. **Xc16/Yc16 `Offset != 0` guard in `expandLDSTStk`** — the inline `TXA16+STAIndir16`
   expansion requires the pointer at offset 0 (like Ac16). Extend the existing
   `(IsAc16 && Offset != 0)` pointer-forming condition to `(IsAc16 || IsXc16 || IsYc16)`.

6. **Layer 5 selector needs legalizer support to fire broadly** — without legalizer changes,
   `selectXY16` only fires for vregs the register allocator happens to assign to Xc16/Yc16 (e.g.,
   via the spill path). Treat Layer 5 as an explicit skeleton; legalizer changes are the follow-on.

7. **`isXWidthAgnostic` body is empty in v1** — no X-agnostic ops exist yet (no carry-init
   equivalent for X). Retain the function for symmetry; body returns `false`.

8. **`requiredXWidth` default must be `XW_None`, not `XW_X8`** (silent-miscompile risk) — unlike
   the M flag (where every instruction without `MLow` genuinely requires M=8), most instructions
   are **indifferent** to the X flag: `LDAbs16`, `STAbs16`, `ADCAbs16`, `LDA_ZeroPage`, etc. all
   behave identically whether X is 0 or 1. Returning `XW_X8` by default would force a `SEP #$10`
   after every M16-only instruction inside an X16 block, making 16-bit index mode nearly useless
   and generating wrong assembly. The correct default is `XW_None`. Only `XLow=1` → XW_X16,
   `XHigh=1` → XW_X8 (e.g., `CPX_Immediate`), and call/return → XW_X8 are non-None.

9. **Cross-block dataflow needs X-dimension maps** — the Increment 2 forward dataflow computes
   `First`/`Last`/`In`/`Out` for M only. For the X dimension, parallel `XFirst`/`XLast`/`XIn`/
   `XOut` maps are required, the fixpoint must converge both lattices in the same iteration, the
   `Placement` struct must carry X fields (`XChanged`, `ToX16`), and `placeLegacy` must track
   `EndX16` and restore X8 at block end alongside `EndM16`. Details and full pseudocode in Layer 3
   below.

---

## Approach: 5 layers in order

Each layer independently builds and can be diff-tested before the next.

---

### Layer 1 — Feature flag + register definitions

**`MOSFeatures.td`** — add after `FeatureAccum16`:
```tablegen
// #321 xy16: opt-in 16-bit index register mode for the WDC 65816.
def FeatureIndex16 :
  SubtargetFeature<"mos-xy16", "HasIndex16", "true",
    "16-bit index register mode (insert REP/SEP X) on the WDC 65816.",
    [FeatureAccum16]>;  // implies +mos-a16: soft-stack spill uses TXA→A16→STA
```

**`MOSInstrFormats.td`** — add after `def HasAccum16`:
```tablegen
def HasIndex16 : Predicate<"Subtarget->hasIndex16()">,
  AssemblerPredicate<(all_of FeatureIndex16), "mos-xy16">;
```

**`MOSSubtarget.h`** — add `bool HasIndex16 = false;` (private) and
`bool hasIndex16() const { return HasIndex16; }` (public), mirroring `HasAccum16`.

**`MOSSubtarget.cpp`** — no code change needed; `ParseSubtargetFeatures` is auto-generated and
picks up the new field.

**`MOSRegisterInfo.td`** — add after `def A16` (number 15). The imaginary registers span
0x10–0x28F (Imag8 max 0x20F, Imag16 max 0x28F); 0x500–0x503 are clean:

```tablegen
// #321 xy16: high bytes of X and Y in 16-bit index mode (M=0, X=0). Like B for
// A16, XH/YH are not directly addressable — only live as the high half of X16/Y16.
// Numbers above both imaginary ranges (Imag8 max 0x20F, Imag16 max 0x28F).
def XH : MOSReg<0x500, "xh">;
def YH : MOSReg<0x501, "yh">;
def X16 : MOSReg<0x502, "x16"> {
  let SubRegs = [X, XH]; let SubRegIndices = [sublo, subhi];
  let CoveredBySubRegs = 1;
}
def Y16 : MOSReg<0x503, "y16"> {
  let SubRegs = [Y, YH]; let SubRegIndices = [sublo, subhi];
  let CoveredBySubRegs = 1;
}
// Register classes: one-member, mirror Ac16.
def Xc16 : MOSReg16Class<(add X16)>;
def Yc16 : MOSReg16Class<(add Y16)>;
```

> **Verify after first build:** check `MOSGenRegisterInfo.inc` for collisions at 0x500–0x503.

---

### Layer 2 — 16-bit index instructions (`MOSInstrLogical.td`)

All gated on `Predicates = [HasIndex16]` with `let XLow = 1`. Expand to confirmed-present MC
instructions.

#### Direct pseudos (1:1 PseudoInstExpansion)

| Pseudo | Expansion | Notes |
|--------|-----------|-------|
| `LDXAbs16` | `LDX_Absolute` | load X16 from abs global |
| `LDXImag16` | `LDX_ZeroPage` | load X16 from Imag16 zp pair |
| `LDXImm16` | `LDX_Immediate16` | load X16 from imm16 |
| `STXAbs16` | `STX_Absolute` | store X16 to abs global |
| `STXImag16` | `STX_ZeroPage` | store X16 to Imag16 zp pair |
| `CPXAbs16` | `CPX_Absolute` | compare X16 vs abs |
| `CPXImag16` | `CPX_ZeroPage` | compare X16 vs Imag16 |
| `CPXImm16` | `CPX_Immediate16` | compare X16 vs imm16 |
| `INX16` | `INX_Implied` | X16 += 1 (N/Z only; no carry) |
| `DEX16` | `DEX_Implied` | X16 -= 1 (N/Z only; no carry) |
| Y variants | `LDY_Absolute`, `LDY_ZeroPage`, `LDY_Immediate16`, `STY_Absolute`, `STY_ZeroPage`, `CPY_Absolute`, `CPY_ZeroPage`, `CPY_Immediate16`, `INY_Implied`, `DEY_Implied` | same pattern |

`INX16`/`DEX16` shape (accumulator-RMW, like `INCAcc16`):
```tablegen
def INX16 : MOSLogicalInstr, PseudoInstExpansion<(INX_Implied)> {
  let Predicates = [HasIndex16]; let XLow = 1; let Constraints = "$dst = $src";
  dag OutOperandList = (outs Xc16:$dst); dag InOperandList = (ins Xc16:$src);
}
```
Load shape (like `LDAbs16`):
```tablegen
def LDXAbs16 : MOSLoad, PseudoInstExpansion<(LDX_Absolute addr16:$src)> {
  let Predicates = [HasIndex16]; let XLow = 1;
  dag OutOperandList = (outs Xc16:$dst); dag InOperandList = (ins addr16:$src);
}
```

#### 16-bit transfer pseudos for soft-stack spill (NEW)

`TXA_Implied`, `TAX_Implied`, `TYA_Implied`, `TAY_Implied` confirmed present in `MOSInstrInfo.td`
(lines 218–220, 213, 205). Both `MLow=1` and `XLow=1` required (these run with M=0, X=0; the
REP/SEP pass must ensure both modes are active). The A16 clobber is encoded in the explicit Ac16
operands — no additional `implicit` annotations needed.

```tablegen
def TXA16 : MOSLogicalInstr, PseudoInstExpansion<(TXA_Implied)> {
  let Predicates = [HasIndex16]; let MLow = 1; let XLow = 1;
  dag OutOperandList = (outs Ac16:$dst); dag InOperandList = (ins Xc16:$src);
}
def TAX16 : MOSLogicalInstr, PseudoInstExpansion<(TAX_Implied)> {
  let Predicates = [HasIndex16]; let MLow = 1; let XLow = 1;
  dag OutOperandList = (outs Xc16:$dst); dag InOperandList = (ins Ac16:$src);
}
def TYA16 : MOSLogicalInstr, PseudoInstExpansion<(TYA_Implied)> {
  let Predicates = [HasIndex16]; let MLow = 1; let XLow = 1;
  dag OutOperandList = (outs Ac16:$dst); dag InOperandList = (ins Yc16:$src);
}
def TAY16 : MOSLogicalInstr, PseudoInstExpansion<(TAY_Implied)> {
  let Predicates = [HasIndex16]; let MLow = 1; let XLow = 1;
  dag OutOperandList = (outs Yc16:$dst); dag InOperandList = (ins Ac16:$src);
}
```

> **Risk:** `T_A`/`TA` logical instructions are lowered in `MOSMCInstLower.cpp`, not via
> PseudoInstExpansion. Verify the new `TXA16`/`TAX16` PseudoInstExpansion path fires before
> MCInstLower's `T_A` case. If not, add `TXA16`/`TAX16` cases to `MOSMCInstLower.cpp`.

---

### Layer 3 — X-flag dataflow in `MOSInsertREPSEP.cpp`

Add a parallel X-flag lattice alongside the existing M-flag lattice. The changes below are
complete and implementable; prior drafts had five defects (see design notes 2, 8, 9).

#### Class member

Add `bool HasIndex16 = false;` as a private member of `MOSInsertREPSEP`. Set it alongside
`TII` at the start of `runOnMachineFunction`:
```cpp
TII = STI.getInstrInfo();
HasIndex16 = STI.hasIndex16();
```
This lets `placeIntraBlock` and `placeLegacy` query it without a separate STI reference.

#### Constants and types

```cpp
static constexpr int64_t XFlagBit = 0x10;  // REP/SEP operand bit for X flag

enum XWidth { XW_None, XW_X8, XW_X16, XW_Conflict };
static XWidth meet(XWidth A, XWidth B);          // same logic as MWidth meet()
static bool resolveIsX16(XWidth W) { return W == XW_X16; }

static bool isXWidthAgnostic(const MachineInstr &MI) {
  (void)MI; return false;  // XW_None is already the default; stub for symmetry
}
```

#### `requiredXWidth` — default is `XW_None`, not `XW_X8`

Unlike the M flag (where every instruction without `MLow` genuinely requires M=8), most
instructions — including all M16-only ops like `LDAbs16` — are **indifferent** to the X flag.
Returning `XW_X8` by default would force `SEP #$10` after every M16-only instruction, defeating
X16 mode. The correct default is `XW_None`.

```cpp
static XWidth requiredXWidth(const MachineInstr &MI) {
  // ABI: 8-bit index registers across call/return boundaries.
  if (MI.isReturn() || MI.isCall())
    return XW_X8;
  // Our new XLow=1 pseudos: INX16, LDXAbs16, TXA16, TAX16, etc.
  if (MI.getDesc().TSFlags & MOS::TSFlagXLow)
    return XW_X16;
  // Existing CPX_Immediate / CPY_Immediate carry XHigh=1 ("8-bit immediate when X=1").
  if (MI.getDesc().TSFlags & MOS::TSFlagXHigh)
    return XW_X8;
  // Branches are X-agnostic (same as M treatment).
  if (MI.isBranch())
    return XW_None;
  // Everything else — ordinary 8-bit ops, M16-only ops, pseudos — is X-agnostic.
  // DO NOT return XW_X8 here; that would force X to 8-bit after every LDAbs16.
  return XW_None;
}
```

#### `insertSwitch` — new 6-argument signature

```cpp
void insertSwitch(MachineBasicBlock &MBB, MachineBasicBlock::iterator Pos,
                  bool NewM16, bool NewX16, bool MChanged, bool XChanged) {
  // Combined REP/SEP #$30 when both flags switch to the SAME mode simultaneously.
  if (MChanged && XChanged && NewM16 == NewX16) {
    BuildMI(MBB, Pos, DebugLoc(),
            TII->get(NewM16 ? MOS::REP_Immediate : MOS::SEP_Immediate))
        .addImm(MFlagBit | XFlagBit);
    return;
  }
  // Separate instructions for independent or opposite-direction switches.
  if (MChanged)
    BuildMI(MBB, Pos, DebugLoc(),
            TII->get(NewM16 ? MOS::REP_Immediate : MOS::SEP_Immediate))
        .addImm(MFlagBit);
  if (XChanged)
    BuildMI(MBB, Pos, DebugLoc(),
            TII->get(NewX16 ? MOS::REP_Immediate : MOS::SEP_Immediate))
        .addImm(XFlagBit);
}
```

#### `placeIntraBlock` — new signature, dual-tracking body

```cpp
bool placeIntraBlock(MachineBasicBlock &MBB, bool EntryIsM16, bool EntryIsX16);
```

```cpp
bool MOSInsertREPSEP::placeIntraBlock(MachineBasicBlock &MBB,
                                       bool EntryIsM16, bool EntryIsX16) {
  bool Changed = false;
  bool M16 = EntryIsM16, X16 = EntryIsX16;
  for (MachineInstr &MI : MBB) {
    MWidth MW = requiredWidth(MI);
    XWidth XW = HasIndex16 ? requiredXWidth(MI) : XW_None;
    if (MW == MW_None && XW == XW_None) continue;
    bool WantM16 = (MW == MW_None) ? M16 : resolveIsM16(MW);
    bool WantX16 = (XW == XW_None) ? X16 : resolveIsX16(XW);
    bool MC = (WantM16 != M16), XC = (WantX16 != X16);
    if (MC || XC) {
      insertSwitch(MBB, MI, WantM16, WantX16, MC, XC);
      M16 = WantM16; X16 = WantX16; Changed = true;
    }
  }
  return Changed;
}
```

#### `placeLegacy` — updated with X-dimension tracking

```cpp
bool MOSInsertREPSEP::placeLegacy(MachineFunction &MF) {
  bool Changed = false;
  for (MachineBasicBlock &MBB : MF) {
    bool EndM16 = false, EndX16 = false;
    for (MachineInstr &MI : MBB) {
      MWidth W = requiredWidth(MI);
      if (W != MW_None) EndM16 = (W == MW_M16);
      if (HasIndex16) {
        XWidth XW = requiredXWidth(MI);
        if (XW != XW_None) EndX16 = (XW == XW_X16);
      }
    }
    Changed |= placeIntraBlock(MBB, /*EntryIsM16=*/false, /*EntryIsX16=*/false);
    if (EndM16 || EndX16) {
      insertSwitch(MBB, MBB.getFirstTerminator(),
                   /*NewM16=*/false, /*NewX16=*/false,
                   /*MChanged=*/EndM16, /*XChanged=*/EndX16);
      Changed = true;
    }
  }
  return Changed;
}
```

#### `runOnMachineFunction` — cross-block dataflow with X-dimension maps

The existing `isPassthrough` lambda becomes `isPassthroughM`; add `isPassthroughX`. Add
`XFirst`/`XLast`/`XIn`/`XOut` maps. Extend the fixpoint and the `Placement` struct.

**Step 1 — per-block transfer facts:**
```cpp
DenseMap<MachineBasicBlock *, MWidth> First, Last;
DenseMap<MachineBasicBlock *, XWidth> XFirst, XLast;
for (MachineBasicBlock &MBB : MF) {
  MWidth Fst = MW_None, Lst = MW_None;
  XWidth XFst = XW_None, XLst = XW_None;
  for (MachineInstr &MI : MBB) {
    MWidth W = requiredWidth(MI);
    if (W != MW_None) { if (Fst == MW_None) Fst = W; Lst = W; }
    if (HasIndex16) {
      XWidth XW = requiredXWidth(MI);
      if (XW != XW_None) { if (XFst == XW_None) XFst = XW; XLst = XW; }
    }
  }
  First[&MBB] = Fst; Last[&MBB] = Lst;
  XFirst[&MBB] = XFst; XLast[&MBB] = XLst;
}
auto isPassthroughM = [&](MachineBasicBlock *B) { return First[B] == MW_None; };
auto isPassthroughX = [&](MachineBasicBlock *B) { return XFirst[B] == XW_None; };
```

**Step 2 — fixpoint for entry modes:**
```cpp
DenseMap<MachineBasicBlock *, MWidth> In, Out;
DenseMap<MachineBasicBlock *, XWidth> XIn, XOut;
for (MachineBasicBlock &MBB : MF) {
  if (&MBB == Entry) {
    In[&MBB] = MW_M8;
    XIn[&MBB] = XW_X8;  // ABI entry: both flags are 8-bit
  } else {
    In[&MBB] = isPassthroughM(&MBB) ? MW_None : First[&MBB];
    XIn[&MBB] = (HasIndex16 && !isPassthroughX(&MBB)) ? XFirst[&MBB] : XW_None;
  }
}
auto outOfM = [&](MachineBasicBlock *B) -> MWidth {
  return isPassthroughM(B) ? In[B] : Last[B];
};
auto outOfX = [&](MachineBasicBlock *B) -> XWidth {
  return isPassthroughX(B) ? XIn[B] : XLast[B];
};
bool Stable = false;
while (!Stable) {
  Stable = true;
  for (MachineBasicBlock &MBB : MF) {
    if (&MBB == Entry) continue;
    if (isPassthroughM(&MBB)) {
      MWidth NewIn = MW_None;
      for (MachineBasicBlock *Pred : MBB.predecessors())
        NewIn = meet(NewIn, outOfM(Pred));
      if (NewIn != In[&MBB]) { In[&MBB] = NewIn; Stable = false; }
    }
    if (HasIndex16 && isPassthroughX(&MBB)) {
      XWidth NewXIn = XW_None;
      for (MachineBasicBlock *Pred : MBB.predecessors())
        NewXIn = meet(NewXIn, outOfX(Pred));
      if (NewXIn != XIn[&MBB]) { XIn[&MBB] = NewXIn; Stable = false; }
    }
  }
}
for (MachineBasicBlock &MBB : MF) {
  Out[&MBB] = outOfM(&MBB);
  XOut[&MBB] = outOfX(&MBB);
}
```

**Step 3a — edge placement decision (extended `Placement` struct):**
```cpp
struct Placement {
  MachineBasicBlock *MBB;
  bool AtEnd;
  bool MChanged = false, ToM16 = false;
  bool XChanged = false, ToX16 = false;
};
SmallVector<Placement, 8> Placements;
bool Bail = false;
for (MachineBasicBlock &B : MF) {
  if (&B == Entry) continue;
  const bool NeedM16 = resolveIsM16(In[&B]);
  const bool NeedX16 = HasIndex16 ? resolveIsX16(XIn[&B]) : false;
  for (MachineBasicBlock *P : B.predecessors()) {
    bool M_diff = resolveIsM16(Out[P]) != NeedM16;
    bool X_diff = HasIndex16 && (resolveIsX16(XOut[P]) != NeedX16);
    if (!M_diff && !X_diff) continue;
    MachineBasicBlock *PlaceMBB; bool AtEnd;
    if (P->succ_size() == 1)     { PlaceMBB = P;  AtEnd = true; }
    else if (B.pred_size() == 1) { PlaceMBB = &B; AtEnd = false; }
    else                          { Bail = true; break; }
    Placements.push_back({PlaceMBB, AtEnd,
                          M_diff, NeedM16, X_diff, NeedX16});
  }
  if (Bail) break;
}
```

**Step 3b — intra-block (pass both entry modes):**
```cpp
for (MachineBasicBlock &MBB : MF)
  Changed |= placeIntraBlock(MBB,
                              resolveIsM16(In[&MBB]),
                              resolveIsX16(XIn[&MBB]));
```

**Step 3c — edge materialization (updated call):**
```cpp
for (const Placement &Pl : Placements) {
  MachineBasicBlock::iterator Pos =
      Pl.AtEnd ? Pl.MBB->getFirstTerminator() : Pl.MBB->begin();
  insertSwitch(*Pl.MBB, Pos,
               Pl.ToM16, Pl.ToX16, Pl.MChanged, Pl.XChanged);
  Changed = true;
}
```

> **Note:** The STZ-fusion section uses `BuildMI` directly (not `insertSwitch`), so no call-site
> update is needed there. Verify by checking the fusion loop before touching it.

#### Implementation checklist for Layer 3

1. Add `bool HasIndex16 = false;` private member; set it in `runOnMachineFunction`.
2. Add `XWidth` enum, `meet(XWidth, XWidth)`, `resolveIsX16`, `isXWidthAgnostic` stub.
3. Add `requiredXWidth` with `XW_None` as default (not `XW_X8`); check `XLow` and `XHigh`.
4. Replace `insertSwitch` with the 6-arg form.
5. Replace `placeIntraBlock` declaration and definition with the 3-arg form.
6. Rewrite `placeLegacy` with `EndX16` tracking and 6-arg `insertSwitch` call.
7. In `runOnMachineFunction`:
   - Rename `isPassthrough` → `isPassthroughM`; add `isPassthroughX`.
   - Add Step 1 X-dimension map population.
   - Add Step 2 `XIn`/`XOut` maps and extend fixpoint.
   - Replace `Placement` struct; extend Step 3a loop.
   - Update Step 3b to pass `resolveIsX16(XIn[&MBB])`.
   - Update Step 3c to pass all six `Placement` fields.
8. Build; confirm zero compile errors before running `-verify-machineinstrs`.

---

### Layer 4 — Spill handling

**Static-stack path** — `MOSInstrInfo::loadStoreRegStackSlot`:

Add Xc16 and Yc16 cases before the `assert`, parallel to the existing Ac16 case:
```cpp
if ((Reg.isPhysical() && MOS::Xc16RegClass.contains(Reg)) ||
    (Reg.isVirtual() &&
     MRI.getRegClass(Reg)->hasSuperClassEq(&MOS::Xc16RegClass))) {
  Builder.buildInstr(IsLoad ? MOS::LDXAbs16 : MOS::STXAbs16)
      .addReg(Reg, getDefRegState(IsLoad) | getKillRegState(IsKill))
      .addFrameIndex(FrameIndex)
      .addMemOperand(MMO);
  return;
}
// Yc16 similarly with LDYAbs16/STYAbs16
```

Update the `// Handled so far:` contract comment.

**Soft-stack path** — `MOSRegisterInfo::expandLDSTStk`:

**Step 1** — extend the pointer-forming guard (the `Offset != 0` condition for indirect-only ops):
```cpp
const bool IsXc16 = MOS::Xc16RegClass.contains(Loc);
const bool IsYc16 = MOS::Yc16RegClass.contains(Loc);
// Was: if (Offset >= 256 || (IsAc16 && Offset != 0))
// Now:
if (Offset >= 256 || ((IsAc16 || IsXc16 || IsYc16) && Offset != 0)) {
  // ... form exact pointer (existing logic) ...
}
```

**Step 2** — add Xc16 case after the IsAc16 case, before the Imag16 case (inline expansion,
no separate pseudo):
```cpp
if (IsXc16) {
  assert(Offset == 0 && "Xc16 nonzero offset should have formed a pointer above");
  Register A16v = MRI.createVirtualRegister(&MOS::Ac16RegClass);
  if (!IsLoad) {
    // Store: TXA16 (A16 = X16) then STAIndir16 ([ptr] = A16)
    Builder.buildInstr(MOS::TXA16).addDef(A16v).addUse(Loc);
    Builder.buildInstr(MOS::STAIndir16)
        .addUse(A16v, RegState::Kill)
        .add(MI->getOperand(2))
        .addMemOperand(*MI->memoperands_begin());
  } else {
    // Load: LDAIndir16 (A16 = [ptr]) then TAX16 (X16 = A16)
    Builder.buildInstr(MOS::LDAIndir16)
        .addDef(A16v)
        .add(MI->getOperand(2))
        .addMemOperand(*MI->memoperands_begin());
    Builder.buildInstr(MOS::TAX16).addDef(Loc).addUse(A16v, RegState::Kill);
  }
  MI->eraseFromParent();
  return;
}
// Yc16 similarly with TYA16/TAY16
```

Update the spill-contract comment: add Xc16/Yc16 to the "Handled so far" list, remove the
`LATENT NEXT: xy16` comment from both `MOSRegisterInfo.cpp` and `MOSInstrInfo.cpp`.

---

### Layer 5 — Instruction selector (`MOSInstructionSelector.cpp`)

**Scope note:** without legalizer changes, `selectXY16` fires only when the register allocator
has assigned a vreg to Xc16/Yc16 (e.g., via the spill path). Layers 1–4 are the minimal working
implementation (no crashes, correct spill). A full legalizer integration — allow s16
G_LOAD/G_STORE/G_ICMP/G_ADD/G_SUB to remain un-narrowed under `+mos-xy16` with Xc16/Yc16 as
legal register classes, analogous to the `+mos-a16` rules in `MOSLegalizerInfo.cpp` — is the
follow-on task that makes the selector fire broadly.

Add `selectXY16(MachineInstr &MI)`, called from `select()` when the def vreg class is `Xc16`
or `Yc16`:

| G_* opcode | Operand pattern | Emits |
|------------|----------------|-------|
| `G_LOAD s16` | from abs global | `LDXAbs16` / `LDYAbs16` |
| `G_LOAD s16` | from Imag16 ptr | `LDXImag16` / `LDYImag16` |
| `G_LOAD s16` | from imm16 | `LDXImm16` / `LDYImm16` |
| `G_STORE s16` | to abs global | `STXAbs16` / `STYAbs16` |
| `G_STORE s16` | to Imag16 | `STXImag16` / `STYImag16` |
| `G_ICMP` | Xc16/Yc16 operand vs abs | `CPXAbs16` / `CPYAbs16` |
| `G_ICMP` | Xc16/Yc16 operand vs imm | `CPXImm16` / `CPYImm16` |
| `G_ADD(x, 1)` | Xc16/Yc16 | `INX16` / `INY16` |
| `G_SUB(x, 1)` | Xc16/Yc16 | `DEX16` / `DEY16` |

---

## Files to modify

| File | Change |
|------|--------|
| `vendor/.../MOSFeatures.td` | Add FeatureIndex16 with `[FeatureAccum16]` implies |
| `vendor/.../MOSInstrFormats.td` | Add `def HasIndex16` predicate |
| `vendor/.../MOSSubtarget.h/.cpp` | HasIndex16 field + accessor |
| `vendor/.../MOSRegisterInfo.td` | XH, YH, X16, Y16, Xc16, Yc16 |
| `vendor/.../MOSInstrLogical.td` | LDX*/STX*/CPX*/INX16/DEX16 + TXA16/TAX16/TYA16/TAY16 pseudos (+ Y variants of all) |
| `vendor/.../MOSInsertREPSEP.cpp` | X-flag lattice; fixed insertSwitch; dual-tracking placeIntraBlock |
| `vendor/.../MOSInstrInfo.cpp` | Xc16/Yc16 static-stack spill cases |
| `vendor/.../MOSRegisterInfo.cpp` | Xc16/Yc16: extend pointer-forming guard + inline spill expansion |
| `vendor/.../MOSInstructionSelector.cpp` | selectXY16 function |
| `patches/llvm-mos/0002-321-accum16.patch` | Regenerate (all above lands in this patch) |
| `examples/65816/xy16basic.c` | New: load/compare/inc loop using X16 |
| `examples/65816/xy16spill.c` | New: forced static-stack spill of X16/Y16 |
| `examples/65816/xy16spillr.c` | New: recursive function → soft-stack spill of X16/Y16 |
| `tools/a16_fuzz.py` | Add `+mos-xy16` differential track |

---

## Verification

1. **Build clean**: `dev/run.sh toolchain` — zero errors, zero `-verify-machineinstrs` failures.

2. **New test programs**: compile `xy16basic.c`, `xy16spill.c`, `xy16spillr.c` with
   `-Xclang -target-feature -Xclang +mos-a16,+mos-xy16`; run differential on MAME + bsnes-jg:
   host == default == `+mos-a16` == `+mos-a16,+mos-xy16`.

3. **REP/SEP output check**: `llc -mattr=+mos-a16,+mos-xy16` on a test `.ll` that uses Xc16;
   verify `rep #$10` / `sep #$10` appear at the right places — no redundant per-instruction
   toggles in a straight-line block; combined `rep #$30` / `sep #$30` present when both M and X
   switch to 16-bit simultaneously; opposite-direction switch emits two separate instructions.
   Also compile a **mixed-mode** test (function that uses both Ac16 and Xc16): verify M16-only
   ops (`LDAbs16`) do NOT emit a surrounding `rep/sep #$10` — the X-flag must be undisturbed by
   M16 instructions that don't have `XLow=1`.

4. **Fuzzer**: `dev/run.sh fuzz 50` with the `+mos-xy16` track enabled; zero differential
   failures. Re-run with a fresh seed.

5. **Regression**: existing corpus (`dev/run.sh corpus`) and `dev/run.sh fuzz 50` (default +
   `+mos-a16` tracks) remain all-green — xy16 must not regress the M-flag path.

---

## Key risks

1. **Register numbers**: 0x500–0x503 are above Imag16's upper bound (0x28F). Verify no collision
   in `MOSGenRegisterInfo.inc` after Layer 1 build.

2. **TXA16 PseudoInstExpansion vs MOSMCInstLower**: `T_A` is lowered in `MOSMCInstLower.cpp`
   (not via PseudoInstExpansion). Verify the new `TXA16` PseudoInstExpansion fires correctly.
   If MCInstLower intercepts it, add `TXA16`/`TAX16`/`TYA16`/`TAY16` cases there.

3. **Combined REP #$30**: only emit when `hasAccum16() && hasIndex16()` AND both switch to the
   same target mode in the same `insertSwitch` call.

4. **Existing `XHigh=1` on CC0 `_Immediate` forms**: `CPX_Immediate`/`CPY_Immediate` have
   `XHigh=1` (assembler/decoder: "8-bit immediate when X flag high"). Our `CPXImm16`/`CPYImm16`
   expand to `CPX_Immediate16`/`CPY_Immediate16` (which have `XLow=1` at MC level) — orthogonal.

5. **Layer 5 follow-on**: without `MOSLegalizerInfo.cpp` changes the selector produces minimal
   XY16 code. Legalizer additions needed: under `+mos-xy16`, allow s16 G_LOAD/G_STORE/G_ICMP/
   G_ADD/G_SUB to remain un-narrowed with Xc16/Yc16 as legal classes.
