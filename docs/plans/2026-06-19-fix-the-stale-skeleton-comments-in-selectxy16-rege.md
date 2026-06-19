# Fix the stale `// skeleton` comments in `selectXY16` (+ regen `0002`)

**Issue:** #321, xy16. **Trivial:** comment-only `vendor/` change + `0002` regen. User confirmed no other agents are running, so the earlier deferral (0002-regen could absorb a concurrent agent's foreign hunks) is moot.

## Context

`selectXY16` is fully implemented (C1 direct load/store/inc/dec/compare + C2 `abs,X16`/`(zp),Y16` indexed), but three comments in `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstructionSelector.cpp` still describe it as an unimplemented stub — actively misleading (it nearly led me to re-implement done work). The function header even contains BOTH the stale "skeleton / returns false for everything" preamble AND an accurate "Handles: C1/C2" block. Correct the three spots to describe the real behavior.

## Edits (exact)

**1. Declaration comment, line 106:**
- `  // #321 xy16: G_* ops assigned to Xc16/Yc16; skeleton for M2 legalizer work.`
+ `  // #321 xy16: select G_* ops that use the 16-bit index registers Xc16/Yc16.`

**2. Dispatch-gate comment, lines 273-275:**
```
  // #321 xy16: route G_* ops assigned to Xc16/Yc16 here. Currently a skeleton
  // that returns false for everything; will be filled in during M2 legalizer
  // integration (index-register operand widening / load-address forms).
```
→
```
  // #321 xy16: route G_* ops that use Xc16/Yc16 to selectXY16 (direct load/store/
  // inc/dec/compare + abs,X16 / (zp),Y16 indexed addressing); returns false for ops
  // it doesn't own, falling through to selectImpl.
```

**3. Function-header preamble, lines 2500-2504** (drop the stale 3-line preamble + fold the redundant 2-line restatement into one accurate intro; keep the `// Handles: C1/C2` block at 2505-2509 unchanged):
```
// #321 xy16: skeleton selector for G_* ops whose result RA assigned to Xc16/Yc16.
// Returns false to fall through to selectImpl — actual X/Y-index selection is a
// follow-on task (M2 legalizer integration: index-operand widening, LEA forms).
// #321 xy16: select operations that use the 16-bit X/Y index registers (Xc16/Yc16).
// Called before selectImpl from the early gate `if (STI.hasIndex16() && selectXY16(MI))`.
```
→
```
// #321 xy16: select G_* ops that use the 16-bit X/Y index registers (Xc16/Yc16),
// routed here before selectImpl by the early `STI.hasIndex16() && selectXY16(MI)` gate.
// Returns false for ops it doesn't own (the default case) → they fall through to selectImpl.
```

## Regen + verify + commit

1. `dev/regen-patch.sh` (regenerate `0002` from `vendor/`). Comment-only → **no toolchain rebuild** (comments are inert; the installed binary is unaffected).
2. **Safety check:** `git diff patches/llvm-mos/0002-*.patch` shows **only** my 3 comment hunks (context lines around `selectXY16` / line 106 / the gate). If any unrelated hunk appears (a pre-existing uncommitted `vendor/` edit), stop and investigate before committing — do not commit foreign hunks.
3. `grep -c 'Xc16\|HasIndex16' patches/llvm-mos/0002-*.patch` non-zero (xy16 content intact); `grep -c 'legalizeICmp\|NativeS16Eq' …` unchanged vs before (no foreign absorption).
4. Stage **only** `patches/llvm-mos/0002-321-accum16.patch`; verify `git diff --cached --name-only` is exactly that. Commit (no push). End with the `Co-Authored-By: Claude Opus 4.8 (1M context)` line.

## Result — VERIFIED 2026-06-19

- `dev/regen-patch.sh` → **round-trip PASS** ("reapplied MOS dir == live vendor"; 4123 lines, 22 files).
- `git diff` of `0002` = **exactly the 3 comment hunks** (declaration, dispatch gate, function header) — no
  other files, no unrelated hunks.
- grep: `legalizeICmp|NativeS16Eq` = 9 (**unchanged** — no foreign absorption); `Xc16|HasIndex16` 105→104 and
  `selectXY16` 9→10 are just my comment rewording (codegen content intact).
- Committed `c2882b3` (3 files: `0002`, this plan, TODO Done entry); not pushed. No toolchain rebuild
  (comments are inert).

## Out of scope
- Any functional change. Comments only.
