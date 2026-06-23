# Fix the A2 hygiene gap — capture & commit far-ptr CC variant (c) A:X+Y

**Repo/branch:** `wt/320-far-cc` (`/home/will/SRC/llvm-mos-65816-far-cc`) · **Date:** 2026-06-21

## Context

The far-pointer calling-convention effort (#320 Inc 4 Ph2) built variant **(c) "A:X+Y"** — a 32-bit far
pointer (`p2`) crossing a call with its 16-bit offset in hardware regs **A:X** and bank byte in **Y** —
directly in the gitignored `vendor/llvm-mos/` tree, but **never captured it into the tracked record**. So
the live compiler ≠ the tracked patch. Concretely:

- `vendor/` has the complete, *correct-looking* AXY implementation (CC rule + `CC_MOS_FarPtrAXY` assigner +
  the 3-location dispatch in `assignCustomValue`), **already compiled into `build/.../clang-23`**
  (`nm`-confirmed: `MOSFarCCAXY` + `CC_MOS_FarPtrAXY` symbols present) and already exercised
  (`build/farcc_axy.sfc` built 2026-06-21 02:35).
- The tracked patch `patches/llvm-mos/0004-320-far-cc.patch` (365 lines) has only the `MOSFarCCAXY`
  *predicate* (added in P0) — **not** the assigner or its table rule (`grep -c CC_MOS_FarPtrAXY 0004` = 0).
  Variant (b) `Split` is present (6 hits); variant (d) `Stack` absent (0).
- `dev/farcc_axy.sh` (the variant-(c) gate, 81 lines, modeled on `dev/farcc_split.sh`) is **untracked**;
  `dev/run.sh` (+5 lines) and `dev/xcheck.sh` (+2 lines) carry uncommitted AXY wiring (verified: purely AXY).

Until captured, a rebuild-from-patches yields (a)/(b) but not (c), and the status docs that currently say
"A2 uncommitted WIP" describe a half-state. **Intended outcome:** variant (c) re-verified on both emulators,
captured into `0004`, committed as a proper **A2** mirroring how A0/A1 landed, and the docs flipped to
"landed."

This is a **capture + commit of already-written, already-compiled code — not new feature work.** A source
audit (3 read-only agents + direct checks) found the AXY code complete and symmetric with the committed (b)
Split path. **No toolchain rebuild is required** (confirmed: no MOS source is newer than `clang-23`).

> Governing lesson (CLAUDE.md): *measure, don't assume.* The build artifacts strongly imply the gate
> passes, but that is **inference** — the agents are read-only and never ran it. The whole commit is
> therefore **contingent on actually running the gate** and it passing.

## Approach — gate-first, then capture, then commit, then sync docs

### 1. Pre-flight (read-only guards; `vendor/` is a hot shared tree)
- Re-confirm no rebuild pending:
  `find vendor/llvm-mos/llvm/lib/Target/MOS -type f \( -name '*.cpp' -o -name '*.td' -o -name '*.h' \) -newer build/llvm-mos-install/bin/clang-23`
  → **empty ⇒ proceed.** Non-empty ⇒ `dev/run.sh toolchain` first, then confirm `clang-23` mtime advanced
  **and** `nm build/llvm-mos-install/bin/clang-23 | grep CC_MOS_FarPtrAXY` (the stale-`clang-23` gotcha).
- Confirm dev/ WIP is purely AXY: `git diff dev/run.sh dev/xcheck.sh` — every added line references `axy`.

### 2. THE GATE — verify variant (c) on BOTH emulators (must pass)
- `dev/run.sh farcc_axy` → runs `dev/farcc_axy.sh`: negative control (no flag ⇒ does **not** compile),
  build `+mos-a16 +mos-farcc-axy` `-verify-machineinstrs` clean, size (64 KiB / banks $00+$01), placement
  (bank-1 sentinel in $01), disasm (`A7` indirect-long deref + `JSR` present), MAME exec `corpus_result == 0xF3`.
- `dev/run.sh xcheck` → bsnes-jg cross-check of `farcc_axy.sfc` → `0xF3` (independent second emulator).
- **STOP CONDITION:** if either fails, **do not commit.** Report the failure; debugging variant (c) becomes
  a separate task (see Out of scope).

### 3. Confirm default codegen still byte-identical (feature is inert)
- `dev/run.sh corpus` → 7/7 (optionally `dev/frameabi-byte-identical.sh`). Proves the AXY assigner — gated
  on the off-by-default `+mos-farcc-axy` — never perturbs default codegen.

### 4. Capture AXY into `0004`
- `dev/regen-patch-0004.sh` (host-side; **self-verifies** via the isolated-worktree round-trip: it reapplies
  `0001+0002+0003+new-0004` to a fresh worktree and `diff -rq` against live vendor — fails loudly on mismatch).
- Sanity-grep the regenerated patch: `CC_MOS_FarPtrAXY` now **> 0**; `CC_MOS_FarPtrSplit` still **> 0**;
  `FarPtrStack` still **0** (variant d must not leak in); line count grew from 365 (~+100).

### 5. Stage the authored set + verify scope
- `git add dev/farcc_axy.sh dev/run.sh dev/xcheck.sh patches/llvm-mos/0004-320-far-cc.patch`
- `git diff --cached --name-only` **must be exactly those 4.** Never `vendor/` (gitignored),
  `docs/transcripts/`, or any other patch. Confirm `git diff --cached --stat patches/` touches only `0004`.

### 6. Commit as A2 (mirror the A1 / `741a8c2` template)
- Subject: `#320 Inc 4 Ph2 A2: far-ptr CC variant (c) A:X+Y (hardware-register split)`
- Body: the 3-way **{A,X,Y}** hardware-register split via the GISel `assignCustomValue` hook (3 CCValAssigns),
  symmetric decompose (ptrtoint→bytes→A/X/Y) / recompose (A:X|Y→inttoptr), `getRegisterTypeForCallingConv`
  sizing the far ptr at i32 for any selected variant.
- **Honest verification paragraph** — adapt A1's but **do NOT copy its "coexistence (far ptr + 2 near ptrs +
  scalar)" claim.** Variant (c) is **singular by design**: A:X+Y holds exactly one far ptr and it must
  precede any A/X-consuming scalar arg (a *documented limitation* in the vendor comments, not a defect).
  State only what `farcc_axy.sh` actually proves: round-trip `0xF3` MAME+bsnes-jg, `-verify-machineinstrs`
  clean, negative control, default byte-identical (corpus+kernels), csmith N seeds (if run), `0004`
  round-trips (N files, +L lines), `0001` stays a16-free.
- Trailers (both, per repo convention):
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01MfznzHZwGwQHUDg7yjrJ8u`.

### 7. Sync the status docs (close the "uncommitted" half-state)
Flip A2 **WIP → landed** in the three durable docs (their current text explicitly says A2 is uncommitted —
that becomes false on commit):
- plan `docs/plans/2026-06-20-320-far-pointer-cc-build-all-variants.md` — Implementation-status table row
  A2, the A1–A3 phased-row note, and the two ⚠️ hygiene-gap callouts (now resolved);
- `docs/agent-handoff.md` — the `wt/320-far-cc` row (A2 landed; remaining A3/M/D);
- `TODO.md` — the Ph2 in-progress block (A2 done; next A3 → cycle harness → M → D).
Commit these (editing the plan fires the `.history` sidecar hook). Fold into the A2 commit **or** a follow-up
`docs:` commit — keep `TODO.md` staged explicitly (it's a hot file).

## Critical files
- **Capture:** `dev/regen-patch-0004.sh` → `patches/llvm-mos/0004-320-far-cc.patch`.
- **Gate:** `dev/farcc_axy.sh`, `dev/run.sh`, `dev/xcheck.sh`; shared source `examples/65816/farcc_imag32.c`
  (covers both **pass** and **return** of a `p2`).
- **Already-written vendor code the patch captures:** `vendor/.../MOS/MOSCallingConv.{td,cpp,h}` (AXY rule +
  `CC_MOS_FarPtrAXY` assigner + `MOSFarCCAXY` predicate), `MOSCallLowering.cpp` (the 3-location dispatch in
  both outgoing/incoming handlers), `MOSFeatures.td` / `MOSSubtarget.h` (feature + `farPtrCC()` enum).
- **Template:** commit `741a8c2` (A1 / variant-b). **Docs to sync:** the plan, `docs/agent-handoff.md`, `TODO.md`.

## Verification (end-to-end)
The commit is sound only if, in order: pre-flight clean → `dev/run.sh farcc_axy` **PASS** (both emulators,
`0xF3`) → `dev/run.sh xcheck` **PASS** → `dev/run.sh corpus` **7/7** (default byte-identical) →
`dev/regen-patch-0004.sh` round-trips (AXY in, Stack out, ~+100 lines) → `git diff --cached --name-only` =
exactly the 4 authored files → commit lands with both trailers → `git show --stat HEAD` shows only those 4
(plus the docs if folded in). Leave `wt/320-far-cc` **unpushed** (push is user-triggered).

## Out of scope / notes
- **Not** building variant (d) stack, **not** the M measurement/cycle harness, **not** promoting any winner.
- **Note for the future D step** (surfaced by `dev/regen-patch-0004.sh`'s header): folding the eventual
  winner into `0001` is non-trivial — Imag32 shares an `AnyRegBank` line that `0002` (a16) also edits, which
  is exactly why `0004` is a *stacked* patch rather than folded into `0001`. Revisit at D; doesn't affect
  this fix.
- **If the gate fails in step 2**, this plan converts to "debug variant (c)" — a separate, larger effort to
  raise with the user before any commit.
