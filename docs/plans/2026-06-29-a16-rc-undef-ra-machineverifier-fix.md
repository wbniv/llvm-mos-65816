# `a16-*-rc-undef` — fix the `$x = COPY $rcN` "undefined physical register" MachineVerifier failure

**Status:** PLANNED. Root-cause + fix of the long-standing `a16-newton-step-rc-undef` MachineVerifier
false-positive, now with a **second independent witness** (the #23 L-System demo). The goal is to make
**both** `newton_sim.c` and `lsystem_sim.c` pass `-verify-machineinstrs` at `-O1`/`-Os` (a16 + xy16) so the
two `rc-undef` XFAILs can be **dropped** (not papered over) — per the battery's "stress the compiler, never
work around it" directive.

## Context

Under `+mos-a16`/`+mos-xy16` at `-O1`/`-Os`, high-register-pressure functions emit a
`renamable $x = COPY killed renamable $rcN` where the `$rcN` (a **zero-page imaginary 16-bit register
pair**, e.g. `$rc3`, `$rc11`) has **no visible definition** on the path reaching the COPY. The
MachineVerifier rejects it (`*** Bad machine code: Using an undefined physical register ***`, exit 70),
aborting `-verify` builds. **The emitted code runs CORRECTLY** (the value is genuinely in `$rcN` at
runtime — verified: both demos' 5-way differential is exact: newton `0x4D8B`, lsystem `0x79C3`), so this is
a **verifier false-positive / def-tracking gap**, not a miscompile.

It has been an open issue since the #2 Newton demo shipped (2026-06-27) with `newton_sim.c` registered as
`KNOWN_ISSUES["a16-newton-step-rc-undef"]` + a `KNOWN_ISSUE_REPROS` XFAIL in `tools/a16_fuzz.py`. The #23
L-System demo independently reproduces the same class (in `main`, after the demo's string-rewrite + bracket
stack inline), confirming it is **not** newton-specific.

## Diagnosis (so far)

- The bad COPY appears **after the Virtual Register Rewriter** (the last `IR Dump After` before the verifier
  aborts is `Virtual Register Rewriter`; the Greedy RA assigns the value, the rewriter materializes the
  physical `$x = COPY $rcN`).
- `$rcN` are **imaginary** registers (zero-page pairs with `sublo`/`subhi` sub-registers, the soft
  accumulator/index spill pool). Hypothesis: a **partial/sub-register def** of the pair (e.g. defining
  `$rcNlsb` / `$rcN.sublo` only, or a def on a sibling path) is not recognised by the verifier's liveness as
  defining the **full** `$rcN` read by the COPY — so the full-pair use looks undefined even though every
  byte is in fact defined at runtime. This is the sub-register-liveness / `implicit-def` tracking corner the
  MOS backend's imaginary-register model has to get exactly right.

## Plan

1. **Minimal repro.** Reduce `newton_sim.c` (or a synthesized high-pressure a16 function) to the smallest
   function that emits `$x = COPY $rcN` with an undefined `$rcN`, surviving `-Os`. Add it as
   `examples/65816/rcundef.c` (a `dev/` differential + `-verify` gate, like `xy16inplace`).
2. **Pin the pass + the missing def.** Dump MIR before/after Greedy RA and the Virtual Register Rewriter;
   identify where `$rcN`'s def is (sub-register? other block? folded into a `LDImag16`/spill?) and why the
   verifier doesn't see it reaching the COPY.
3. **Classify the gap** — one of:
   a. RA/rewriter emits the COPY before/without a corresponding `$rcN` def (a real def-insertion bug);
   b. a sub-register def (`$rcNlsb`) isn't marked as (partially) defining `$rcN`, so the verifier treats the
      super-register read as undefined (a `Register{Info,Bank}`/sub-reg-liveness modelling gap);
   c. an `implicit-def`/`undef` flag is missing on a reload/spill of the imaginary pair.
4. **Fix at the root** in `vendor/llvm-mos/llvm/lib/Target/MOS/` (likely `MOSRegisterInfo`, the
   rewriter/RA glue, or `MOSInstrInfo` copy/spill lowering) on the **`throwaway/rc-undef-fix` compiler
   worktree** (own `vendor/` + warm `build/`). Conservative: a misclassification must only ever add a def /
   mark liveness correctly, never change emitted bytes on the corpus.
5. **Verify.** `newton_sim.c` + `lsystem_sim.c` both `-verify` clean at `-O0/-O1/-Os` (a16 + xy16);
   `dev/run.sh newton` + `dev/run.sh lsystem` still PASS with unchanged hashes (`0x4D8B`/`0x79C3`); corpus
   7/7; xy16 suite; torture; fuzz csmith N×2 (0 mismatch / 0 new crash); the disasm is **byte-identical** on
   the corpus (proving the fix is inert — only adds liveness/def info). Regenerate `0002` (round-trips, 0
   foreign content).
6. **Drop the XFAILs.** Remove `a16-newton-step-rc-undef` from `KNOWN_ISSUES` + both `KNOWN_ISSUE_REPROS`
   rows (newton + any lsystem entry) in `tools/a16_fuzz.py` so a recurrence **hard-FAILs**; add the new
   `dev/run.sh rcundef` `-verify` gate as the regression guard.

## Files (anticipated)

| File | Purpose |
|---|---|
| `vendor/llvm-mos/llvm/lib/Target/MOS/MOS*.cpp` (TBD) | the def-tracking / sub-reg-liveness fix (→ `0002`) |
| `patches/llvm-mos/0002-321-accum16.patch` | regenerated |
| `examples/65816/rcundef.c`, `dev/rcundef.sh` | minimal repro + `-verify` regression gate |
| `tools/a16_fuzz.py` | drop the `rc-undef` KNOWN_ISSUES + REPROS XFAILs |
| `TODO.md` | close the open `a16-newton-step-rc-undef` investigate item |

## Verification steps

1. Minimal repro `-verify`-fails on the current toolchain (a16 + xy16, `-O1`/`-Os`), clean at `-O0`.
2. MIR diagnosis pins the missing-def site + the gap class (a/b/c above).
3. After the fix: repro + `newton_sim.c` + `lsystem_sim.c` all `-verify` clean (a16/xy16, all opt levels).
4. `dev/run.sh newton` (`0x4D8B`) + `dev/run.sh lsystem` (`0x79C3`) PASS, hashes unchanged.
5. Corpus disasm byte-identical (fix is inert); corpus 7/7; xy16 suite; torture; fuzz 0-mismatch.
6. XFAILs dropped; `dev/run.sh rcundef` is green and a recurrence hard-FAILs.

## Risk / scope note

This is a **deep RA / sub-register-liveness** fix in the imaginary-register model — potentially intricate
and uncertain. It is **code-correct already** (verifier false-positive), so the impact of *not* fixing it is
only that `-verify` builds of two demos need an XFAIL. Worth fixing (it blocks the clean `-verify` bar and
is a real modelling gap), but a candidate to **timebox**: if the root cause proves to be a large RA rework,
fall back to the documented XFAIL (newton precedent) and keep this plan as the standing fix-it ticket.
