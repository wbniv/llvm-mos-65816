# Handoff: xy16 Implementation (`wt/321-xy16`)

**Date:** 2026-06-18 (revised after plan audit)  
**Branch:** `wt/321-xy16`  
**Worktree:** `/home/will/SRC/llvm-mos-65816-xy16`  
**Main repo:** `/home/will/SRC/llvm-mos-65816` (branch `main`)

---

## Read this before touching any code

The implementation plan at
[`docs/plans/2026-06-17-321-xy16-index-register-mode.md`](2026-06-17-321-xy16-index-register-mode.md)
was **audited and revised** — nine design corrections total, five of them in **Layer 3**
(three would have been silent miscompiles). The plan file is authoritative; read it in full.
The critical Layer 3 corrections are also summarised below so you can't miss them.

---

## Context: why you're in a worktree

`main` carries a seed-42 regression bisected to `0002-321-accum16.patch` — a shared-path
miscompile (default and `+mos-a16` both produce `0xB226`; correct is `0xEC0D`). The
fix is being committed to `main` separately. Your xy16 work also modifies `vendor/`, hence
the isolation. **Do not push to `origin/main` from this worktree** until the regression fix is
on main and you've rebased onto it.

---

## First thing: build the toolchain

`vendor/` doesn't exist yet in this worktree. Bootstrap it:

```bash
cd /home/will/SRC/llvm-mos-65816-xy16
dev/run.sh toolchain
```

Should take ~5–10 min (near-100% ccache hit — `build/.ccache` is symlinked to the shared
cache and the patches here match main at the branch point). Confirm with:

```bash
ls -lh build/llvm-mos-install/bin/clang-23   # mtime must be recent; the `clang` symlink is stale
```

---

## Implementation plan: 5 layers in order

Each layer independently builds and can be diff-tested before the next. **Build clean and run
`-verify-machineinstrs` after each layer before starting the next.**

| Layer | Files | Status |
|-------|-------|--------|
| 1 | `MOSFeatures.td`, `MOSInstrFormats.td`, `MOSSubtarget.h/.cpp`, `MOSRegisterInfo.td` | not started |
| 2 | `MOSInstrLogical.td` | not started |
| 3 | `MOSInsertREPSEP.cpp` | not started — **read corrections below first** |
| 4 | `MOSInstrInfo.cpp`, `MOSRegisterInfo.cpp` | not started |
| 5 | `MOSInstructionSelector.cpp` | not started (skeleton only; legalizer follow-on) |

Start with Layer 1 — it changes only `.td` files and adds zero functionality, so it can't
regress anything. It either compiles or fails loudly.

---

## Layer 3 corrections — the five bugs found in the original draft

Read the corrected pseudocode in the plan. Summary of what changed and why:

### Bug 1 (silent miscompile): `requiredXWidth` default must be `XW_None`, not `XW_X8`

The original draft returned `XW_X8` as the catch-all default. This would force a `SEP #$10`
(X → 8-bit) after every M16-only instruction (`LDAbs16`, `STAbs16`, `ADCAbs16`, …) — because
those instructions have `XLow=0`, they'd fall through to the default and require X=8.
The result: `REP #$10 … INX16 … SEP #$10 … LDAbs16 … REP #$10 … INX16 …` — an X-flag toggle
around every accumulator op, making X16 mode nearly useless and generating wrong REP/SEP
sequences.

**Fix:** most instructions are genuinely X-agnostic (X flag doesn't affect their behavior).
The correct default is `XW_None`. Only `XLow=1` → `XW_X16`, `XHigh=1` → `XW_X8` (for the
existing `CPX_Immediate`/`CPY_Immediate`), and call/return → `XW_X8`.

```cpp
static XWidth requiredXWidth(const MachineInstr &MI) {
  if (MI.isReturn() || MI.isCall())
    return XW_X8;
  if (MI.getDesc().TSFlags & MOS::TSFlagXLow)
    return XW_X16;
  if (MI.getDesc().TSFlags & MOS::TSFlagXHigh)   // CPX_Immediate / CPY_Immediate
    return XW_X8;
  if (MI.isBranch())
    return XW_None;
  return XW_None;   // NOT XW_X8 — most ops are X-agnostic
}
```

### Bug 2 (silent miscompile): cross-block dataflow missing X-dimension maps

The original draft said "parallel lattices run in the same iteration" but never showed
`XFirst`/`XLast`/`XIn`/`XOut` being computed. Without these, the Increment 2 cross-block
optimization (mode held across edges) only works for M — the X flag would never be hoisted
out of loops. Full corrected pseudocode is in the plan.

Key: add `bool HasIndex16 = false;` as a class member (set alongside `TII` at the start of
`runOnMachineFunction`), rename `isPassthrough` → `isPassthroughM`, add `isPassthroughX`, and
add the X-dimension maps to Steps 1–3c.

### Bug 3 (missing functionality): `Placement` struct missing X-dimension

The original `Placement` struct was `{MBB, AtEnd, ToM16}`. The edge-placement loop and Step 3c
materialization only handled M transitions; X-flag edge transitions were never emitted. Extend:

```cpp
struct Placement {
  MachineBasicBlock *MBB;
  bool AtEnd;
  bool MChanged = false, ToM16 = false;
  bool XChanged = false, ToX16 = false;
};
```

The edge-placement loop must compute both `M_diff` and `X_diff` for each predecessor edge and
populate both fields. Step 3b must pass `resolveIsX16(XIn[&MBB])` to `placeIntraBlock`.

### Bug 4 (silent miscompile): `placeLegacy` missing X-dimension block-end restoration

`placeLegacy` tracked `EndM16` and restored M to 8-bit at block end, but had no `EndX16`
tracking. If a block ends in X16 mode, `placeLegacy` would emit nothing for X — the next
block inherits wrong X state. Fix: track `EndX16` and pass both to `insertSwitch`.

```cpp
// In placeLegacy:
bool EndM16 = false, EndX16 = false;
for (MachineInstr &MI : MBB) {
  MWidth W = requiredWidth(MI); if (W != MW_None) EndM16 = (W == MW_M16);
  if (HasIndex16) { XWidth XW = requiredXWidth(MI); if (XW != XW_None) EndX16 = (XW == XW_X16); }
}
Changed |= placeIntraBlock(MBB, false, false);
if (EndM16 || EndX16)
  insertSwitch(MBB, MBB.getFirstTerminator(), false, false, EndM16, EndX16);
```

### Bug 5 (compile error): `insertSwitch` call sites use old 3-arg signature

The plan introduces a new 6-arg `insertSwitch(MBB, Pos, NewM16, NewX16, MChanged, XChanged)`.
All call sites — in `placeIntraBlock`, `placeLegacy`, and Step 3c — must use the new form.
The STZ-fusion section uses `BuildMI` directly (not `insertSwitch`), so it needs no update;
verify this before starting Layer 3.

---

## All other plan content is correct

Layers 1, 2, 4, and 5 are correct as written in the plan. The other design corrections (items
1–7 in the plan's "Design notes" section) are also correct. The verification steps and key risks
are correct, with one addition: after Layer 3, compile a **mixed-mode** test that uses both
Ac16 and Xc16 in the same function and confirm that M16-only ops (`LDAbs16`) emit no
surrounding `rep/sep #$10`.

---

## Build / test commands

```bash
dev/run.sh toolchain          # rebuild after vendor/ edit (Docker; incremental)
dev/run.sh corpus             # Tier-1 gate: expect 7/7
dev/run.sh fuzz 50 1          # differential fuzzer: expect 50/50, 0 mismatch
```

Compile + MIR-verify a single file (host, no container):
```bash
build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16,+mos-xy16 \
  -Os -mllvm -verify-machineinstrs -c FILE.c -o /tmp/x.o
```

Disasm: `build/llvm-mos-install/bin/llvm-objdump -d --mcpu=mosw65816 /tmp/x.o`

**GOTCHA:** `build/llvm-mos-install/bin/clang` is a stale symlink — the real binary is
`clang-23`. Confirm a rebuild took by checking `clang-23`'s mtime, not `clang`'s.

**Run on a quiet box** — concurrent Docker/MAME load flakes MAME timing.

After Layer 5, add tests:
```bash
dev/run.sh xy16basic          # load/compare/inc loop using X16
dev/run.sh xy16spill          # forced static-stack spill of X16
dev/run.sh xy16spillr         # recursive soft-stack spill of X16
```

---

## Commit discipline

- **Stage only your files.** `vendor/` is gitignored; stage `.td`, `.cpp`, `.h`, plans, patch.
- **Verify `git diff --cached --name-only`** is exactly your set — no foreign files.
- **Regenerate the patch at each logical checkpoint** (end of each Layer):
  ```bash
  dev/regen-patch.sh   # run from worktree root only
  ```
  Sanity-check afterward: `grep -c 'Xc16\|HasIndex16' patches/llvm-mos/0002-321-accum16.patch`
  should be non-zero, and `grep -c 'legalizeICmp\|NativeS16' ...` should be zero (no foreign hunks).
- **Commit hooks fire automatically:** `regen-md-history` (snapshots plans),
  `audit-plan-deferrals` (writes Inbox to `TODO.md` — triage before committing).
- **Co-Authored-By line** on every commit:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
- **Do NOT push to `origin/main`** — check with the user first.

---

## Key risks (full list from the plan)

1. **Register numbers 0x500–0x503**: after Layer 1 build, verify no collision in
   `MOSGenRegisterInfo.inc` (`grep -n '0x500' build/llvm-mos/lib/Target/MOS/MOSGenRegisterInfo.inc`).
2. **TXA16 PseudoInstExpansion vs `T_A` in `MOSMCInstLower.cpp`**: after Layer 2, confirm the
   new `TXA16` PseudoInstExpansion path fires. If `MCInstLower`'s `T_A` case intercepts it
   first, add `TXA16`/`TAX16`/`TYA16`/`TAY16` cases to `MOSMCInstLower.cpp`.
3. **Combined `REP #$30`**: only emit when both flags switch to the **same** mode in one
   `insertSwitch` call (`MChanged && XChanged && NewM16 == NewX16`).
4. **`XHigh=1` on `CPX_Immediate`**: `CPXImm16`/`CPYImm16` expand to `CPX_Immediate16`/
   `CPY_Immediate16` (which have `XLow=1`) — orthogonal to `CPX_Immediate` (XHigh=1), but
   `requiredXWidth` must check `TSFlagXHigh` to return `XW_X8` for the 8-bit forms.
5. **Layer 5 scope**: `selectXY16` fires only when the RA assigns to Xc16/Yc16 (e.g., via
   spill). Legalizer integration (making xy16 fire broadly) is the follow-on task — implement
   the skeleton, leave a clear `// TODO: legalizer follow-on` comment, and stop there.

---

## What main is doing (don't collide)

Main is fixing the seed-42 regression in `0002`. That fix touches `MOSLegalizerInfo.cpp`
(`legalizeICmp`). Your xy16 work touches different files — `MOSFeatures.td`,
`MOSRegisterInfo.td`, `MOSInstrLogical.td`, `MOSInsertREPSEP.cpp`, `MOSInstrInfo.cpp`,
`MOSRegisterInfo.cpp`, `MOSInstructionSelector.cpp`. No overlap expected. Before regenerating
the patch, run `git log main --oneline -3` to confirm the regression fix has landed and check
that it didn't touch any file you modified.

---

## Merge-back checklist

Before merging `wt/321-xy16` → `main`:

- [x] Regression on main diagnosed and fix committed (`51a5bae` on main; same fix applied to xy16 vendor/ at `c6e6c7c`)
- [x] All 5 layers built and `-verify-machineinstrs` clean (`c6e6c7c`)
- [x] `xy16basic`, `xy16spill`, `xy16spillr` PASS on MAME + bsnes-jg (MAME ✓; bsnes-jg skipped — needs `dev/run.sh xcheck`)
- [x] Mixed-mode test: Ac16+Xc16 in same function, `LDAbs16` emits no `rep/sep #$10` (verified via xy16basic.sh disasm)
- [x] Corpus 7/7 and `fuzz 50 1` 50/50 with `+mos-xy16` fuzzer track enabled (post-rebase ✓)
- [x] `0002` regenerated + round-trips clean; no foreign hunks
- [x] `git rebase main` clean (no conflicts; rebased 2026-06-18)
- [x] Full suite re-run post-rebase (fuzz 50/50, corpus 7/7, all xy16 tests PASS)
