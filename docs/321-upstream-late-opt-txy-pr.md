# Upstream PR preview — the mos-late-opt <span style="white-space: nowrap">TYX/TXY</span> dead-flag fix

> Two 65816 index-register transfers are involved: <span style="white-space: nowrap">**TYX**</span>
> (transfer Y→X) and <span style="white-space: nowrap">**TXY**</span> (X→Y). The exact PR title is in the
> [PR title](#pr-title) block below.

> **Status: branch pushed, PR NOT opened.** This is the preview of the upstream contribution for review.
> Found by the #321 differential fuzzer (P0 recursion). See
> [F4 plan](plans/2026-06-16-321-f4-late-opt-txy-dead-flag.md).

| | |
|---|---|
| **Fork branch** | [`wbniv/llvm-mos:mos-late-opt-txy-dead-flag`](https://github.com/wbniv/llvm-mos/tree/mos-late-opt-txy-dead-flag) |
| **Commit** | `f690dc886` (1 commit, 2 files, +32 / −2) |
| **Base** | `llvm-mos/llvm-mos:main` (branched from `c798c3141`, a clean ancestor of `main`) |
| **Open it** | `gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-late-opt-txy-dead-flag --base main` — or visit https://github.com/wbniv/llvm-mos/pull/new/mos-late-opt-txy-dead-flag |
| **Carried locally as** | [`patches/llvm-mos/0003-late-opt-txy-dead-flag.patch`](../patches/llvm-mos/0003-late-opt-txy-dead-flag.patch) (drop once merged + the vendor pin is bumped) |

---

## PR title

```
[MOS] mos-late-opt: clear dead/kill flags when rewriting LDImm to TYX/TXY
```

## PR body (as it would appear on GitHub)

`MOSLateOptimization::combineLdImm` rewrites `LD_ #imm` into a register transfer when another register
already holds the immediate, then clears the dead flag and any kill flags on the transfer's **source**
register (its value is now used). Every transfer rewrite sets `Load` to its source so this shared cleanup
runs — `TAX`/`TAY` (`Load = &LoadA`), `TXA`/`TYA` (`Load = &LoadX/Y`) — **except the W65816/65EL02
`TYX`/`TXY` branches, which never assign `Load`**.

So rewriting `$y = LDImm k` → `$y = TX $x` where `$x` came from a `dead $x = LDImm k` (e.g. an
RA-rematerialized constant whose value was otherwise unused) leaves the source def marked dead, and the
machine verifier rejects the new use:

```
*** Bad machine code: Using an undefined physical register ***
- instruction: $y = TX $x
```

The default 8-bit path never hits it; it shows up on the 65816 under register pressure that produces a
dead `LDImm` followed by a same-value `LDImm`.

### Fix

Set `Load` to the transfer source (`&LoadY` for `TYX`, `&LoadX` for `TXY`) in the two W65816 branches,
matching the sibling transforms, so the existing
`if (Load) { Load->MI->getOperand(0).setIsDead(false); clearRegisterKills(...); }` block runs.

### Tests

`llvm/test/CodeGen/MOS/late-opt-65816.mir`:
- Two new cases, `ldimm_to_txy_clears_dead_source` / `ldimm_to_tyx_clears_dead_source` — a `dead` `LDImm`
  source reused as `TXY`/`TYX`. They fail `-verify-machineinstrs` without the fix and pass with it.
- The existing `ldimm_to_txy` / `ldimm_to_tyx` checks are updated: the stale `killed` flag on the source
  is now correctly cleared (`STImag8 killed $x` → `STImag8 $x`).

Found by a differential fuzzer generating recursive (soft-stack) 65816 functions, whose register pressure
produces the pattern this peephole mishandled.

---

## The diff

```diff
diff --git a/llvm/lib/Target/MOS/MOSLateOptimization.cpp b/llvm/lib/Target/MOS/MOSLateOptimization.cpp
@@ -331,10 +331,12 @@ bool MOSLateOptimization::combineLdImm(MachineBasicBlock &MBB) const {
       } else if (STI.hasW65816Or65EL02()) {
         if (Dst == MOS::X && LoadY.MI && LoadY.Val == Val) {
           // LDX #imm -> TYX if Y==imm
+          Load = &LoadY;
           MI.setDesc(TII.get(MOS::TX));
           MI.getOperand(1).ChangeToRegister(MOS::Y, /*isDef=*/false);
         } else if (Dst == MOS::Y && LoadX.MI && LoadX.Val == Val) {
           // LDY #imm -> TXY if X==imm
+          Load = &LoadX;
           MI.setDesc(TII.get(MOS::TX));
           MI.getOperand(1).ChangeToRegister(MOS::X, /*isDef=*/false);
         }
```

Plus the `late-opt-65816.mir` test additions/updates (2 new dead-source cases; existing `txy`/`tyx`
checks lose the stale `killed`). Full diff: `patches/llvm-mos/0003-late-opt-txy-dead-flag.patch`.

## Validation (local, on the rebuilt toolchain)

- `llc -run-pass=mos-late-opt -verify-machineinstrs late-opt-65816.mir | FileCheck` → PASS.
- The #321 fuzz gate `dev/run.sh fuzz 50 1` → 50/50 (the 2 formerly-crashing recursive seeds now clean,
  values agree host == default == `+mos-a16` on MAME + bsnes-jg).
- Non-breaking: corpus 7/7, `a16spillr`/`a16spill`/`a16localx`/`a16localbit` green.
