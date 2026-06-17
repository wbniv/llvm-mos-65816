# P2 — hermetic `.ll` crash-regression for the soft-stack `Ac16` spill

**Date:** 2026-06-17 · **Status:** **DONE (2026-06-17)** — `examples/65816/a16spillir.ll` (frozen IR of
`a16spillr.c`) + `dev/a16spillir.sh` (`llc` crash + soft-stack-spill-path gate) landed; test-only, no
vendor change. **TODO:** M2 "soft-stack spill coverage" → P2. **Predecessor:**
[soft-stack plan](2026-06-16-321-soft-stack-spill-coverage.md) (P2 specced there) ·
[F3 fix](2026-06-16-321-fix-cmp-value-selectimm.md).

## Context

The F3 / soft-stack work fixed a real backend crash: a 16-bit-accumulator (`Ac16`) value held
across a call in a **reentrant** (soft-stack) function fell through `MOSRegisterInfo::expandLDSTStk`
to a byte path that `COPY`ed `A16` through an 8-bit GPR → invalid MIR (`Scavenger spill … not
implemented` / `SelectImm $a16`). The fix spills `Ac16` with a 16-bit indirect `STAIndir16`/`LDAIndir16`.

Today's regression guard is `examples/65816/a16spillr.c` + `dev/a16spillr.sh` (runtime differential on
both emulators). It's excellent but **fragile to front-end/optimizer drift**: it only guards the bug as
long as clang+opt keep (a) the recursion (→ soft stack) and (b) the value resident in `Ac16` across the
call. P2 adds a **hermetic** companion: a frozen LLVM-IR fixture run through `llc` so the guard no longer
depends on the C front end — only on the backend codegen path under test. This is the same dual-guard
rationale the F3 plan used (keep both a compile-gate and the value check).

**This is a test-only change. No backend/vendor edit → no toolchain rebuild, no `dev/regen-patch.sh`.**

## Key constraint that shapes the design (verified)

`dev/regen-patch.sh` mirrors **only** `llvm/lib/Target/MOS` into patch `0002`. A `.ll` placed in the
vendor lit suite (`vendor/llvm-mos/llvm/test/CodeGen/MOS/`) is gitignored and **NOT captured** → it would
be lost. So the hermetic fixture must live in the **project repo** and run via a `dev/` script (the
established pattern), not in the vendor lit suite. (Adding a real upstream lit test is deferred to the
#321 upstreaming work — see *Deferred*.)

## Approach (recommended)

### 1. Fixture — `examples/65816/a16spillir.ll` (tracked)

The frozen LLVM IR of `a16spillr.c`, captured with the installed toolchain:

```
build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os -S -emit-llvm \
  examples/65816/a16spillr.c -o examples/65816/a16spillir.ll
```

This yields ~87 lines with `target triple = "mos"`, the datalayout, and the recursive `work` self-call
intact. **Verified viable** (read-only probe during planning): `llc -mattr=+mos-a16
-verify-machineinstrs` compiles it clean, and `-print-after=virtregrewriter` shows `STStk/LDStk $a16` ×1
(the soft-stack `Ac16` spill — the exact bug path).

- Add a top-of-file comment block: what it is (frozen IR of `a16spillr.c`), why (drift-immune hermetic
  crash-regression for the soft-stack `Ac16` spill), how it was generated (the command above), and what
  to check (`-verify-machineinstrs` clean + a soft-stack `Ac16` spill present). Comments in `.ll` are
  `;`-prefixed.
- **Optional reduction:** trim obviously-irrelevant IR (`main`, unused globals) **re-verifying after each
  trim that `STStk/LDStk $a16` still appears**. If a trim drops the spill, keep the fuller form — a guard
  that doesn't fire is worse than a slightly larger fixture. The full frozen IR is an acceptable fallback.

### 2. Driver — `dev/a16spillir.sh` (tracked, auto-discovered by `dev/run.sh`)

Model structure on `dev/a16spill.sh` (the static-stack compile-time gate) — `set -euo pipefail`,
`-h/--help`, `RESULT: PASS/FAIL`, no emulator. Use the **build-tree `llc`** (pure codegen, most hermetic;
matches the `build/f4-littest.sh` precedent — `llc` lives at `build/llvm-mos/bin/llc`, not the install):

- Locate `llc` at `${MOS_TOOLCHAIN:-/work/build/llvm-mos}/bin/llc` … resolve the actual in-container path
  (the C tests use `…/llvm-mos-install/bin`; `llc` is in the sibling `…/llvm-mos/bin`). Fail with a clear
  "run dev/run.sh toolchain first" message if absent.
- **Crash gate:** `llc -mtriple=mos -mcpu=mosw65816 -mattr=+mos-a16 -verify-machineinstrs -o /dev/null
  $LL` → assert exit 0 (this is the F3 regression; on a pre-fix backend it crashes).
- **Path gate:** `llc … -print-after=virtregrewriter -o /dev/null $LL 2>&1 | grep -ciE '(STStk|LDStk).*a16'`
  ≥ 1 → proves the soft-stack `Ac16` spill is actually exercised (mirrors `dev/a16spillr.sh`'s gate so the
  test can't silently stop guarding the bug).
- (No `FileCheck` — grep matches the project's dev-script convention and avoids a build-tree dep.)

### 3. Wire into `dev/run.sh`

Add a one-line usage entry for `a16spillir` (informational; the dispatcher auto-maps the name to
`dev/a16spillir.sh`). No registration needed.

## Files

- **New** `examples/65816/a16spillir.ll` — frozen hermetic IR fixture.
- **New** `dev/a16spillir.sh` — the `llc`-driven crash + path gate.
- **Edit** `dev/run.sh` — usage line.
- **Reuse / model on:** `dev/a16spill.sh` (compile-gate structure), `dev/a16spillr.sh` (the
  `(STStk|LDStk).*a16` MIR gate), `build/f4-littest.sh` (build-tree `llc` precedent).
- No vendor edit; no `patches/`, no rebuild, no patch regen.

## Verification — DONE (2026-06-17)

1. **`dev/run.sh a16spillir` → PASS.**
   ```
   ==> 1) llc -verify-machineinstrs on the frozen .ll must compile CLEAN (was: SelectImm $a16)
     PASS: clean (exit 0)
   ==> 2) the body must still SPILL the 16-bit accumulator on the soft stack (STStk/LDStk $a16)
     PASS: 1 soft-stack Ac16 spill op(s) (STStk/LDStk $a16) — the F3 path is exercised
   RESULT: PASS — hermetic .ll: soft-stack Ac16 spill compiles clean and the spill path is exercised
   ```
2. **Hermeticity — PASS.** The fixture is plain frozen IR (compile-time gate, no emulator, no front end).
3. **Non-breaking — PASS.** Test-only; no vendor/codegen edit, so `0002` is untouched. Spot-check
   `dev/run.sh a16spill` → `RESULT: PASS` (compile-gate sibling). `a16spillr` is unaffected by construction
   (no backend change); not re-run on the emulator.
4. **"Proves-it-bites" revert-check — NOT RUN (optional; deliberately skipped).** Would require temporarily
   reverting the `IsAc16` case in shared `vendor/` + two rebuilds — risky with concurrent agents on
   `vendor/`. The path-gate (step 1, gate 2) already proves the soft-stack `Ac16` spill is exercised, and
   the F3 plan already established this exact path crashed pre-fix; so the test demonstrably guards the bug
   without the revert-check.

## Deferred (out of scope for P2)

- A real upstream **lit test** under `llvm/test/CodeGen/MOS/` (with `FileCheck`, `; RUN: llc …
  -mattr=+mos-a16 -verify-machineinstrs`) belongs with the #321 **upstreaming** work — it needs
  `regen-patch.sh` extended to also mirror the MOS test dir into a patch (or the upstream PR carries it
  directly). Note this in the soft-stack plan so the upstreaming step picks it up.
- The actual `xy16` index-16 spill case stays gated on the `xy16` increment (P1's tripwire covers it).
