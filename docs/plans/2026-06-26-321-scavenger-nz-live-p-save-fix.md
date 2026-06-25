<!-- Plan: fix the upstream register-scavenger "$p is not a GPR" crash by teaching
     saveScavengerRegister to preserve a live processor-status register across an
     unbalanced stack range. #321 / M2. -->

# #321 — fix the register-scavenger `$p is not a GPR` crash (live N/Z across a frame-vreg spill)

**Status:** ✅ **DONE (2026-06-26)** — fork patches `0011`+`0012`, all verification steps PASS (evidence
below). Committed to local `main` (`a320cbd` + `cf30a73`); pushed to branch `mos-scavenger-live-p` off
`origin/main` (the shared-`main` push is deferred to the owner — origin/main carries a pre-existing
multi-worker divergence). Supersedes the "deferred / upstream-gated" disposition of
`docs/investigations/65816-a16-scavenger-nz-liveness.md` + `docs/321-upstream-scavenger-nz-issue.md`.
**Owner:** Will. **Issue:** #321, ROADMAP M2. **Repro:** `examples/65816/a16scavnz.c` (fuzz seed-306 family,
8/500: 169/173/196/268/271/272/306/420).

## Problem (root cause — asserts-confirmed)

`+mos-a16 -O1/-Os` crashes the backend on 8/500 fuzz seeds. Release `-verify-machineinstrs`:

```
*** Bad machine code: Using an undefined physical register ***  - PH $p
*** Bad machine code: Illegal physical register for instruction *** - $rc17 = STImag8 $p   ($p is not a GPR)
                                                                      - $p   = LDImag8 $rc17 ($p is not a GPR)
```

Asserts build aborts earlier, at `MOSRegisterInfo.cpp assertNZDeadAt`:
`!LiveRegs.contains(MOS::N) && "expected N to be free when saving scavenger register"`, in
`saveScavengerRegister ← RegScavenger::spill ← scavengeRegisterBackwards ← scavengeVReg ← scavengeFrameVirtualRegs`.

**Mechanism (from the `-debug-only=reg-scavenging` trace):**
`Scavenged register with spill: $p until undef %29.subcarry:pc = LDCImm 0`. A frame-index address is
materialized post-RA by `expandAddrLostk`/`expandAddrHistk` as `LDCImm 0; ADCImm` — which introduces a
**carry virtual register** (`%29.subcarry`, register class `Pc` ⊇ only `$p`). `scavengeFrameVirtualRegs`
must place it in the **only** carry-class physreg, `$c` (a sub-register of `$p`). Under `+mos-a16` a 16-bit
compare/ALU (`CMPImag16`/`SBCImag16`) leaves **N (or Z) live** across that point, so the whole `$p` is live
and must be spilled to free `$c`. But:

1. **`$p` has no GPR spill home.** `STImag8`/`LDImag8` are GPR-only, so the `Reg == MOS::P` fall-through
   `STImag8 {Save}, {P}` is structurally illegal (`$p is not a GPR`).
2. **The range is push/pull-*unbalanced*.** `saveScavengerRegister` takes the hard-stack (`PHP`/`PLP`) path
   only when `pushPullBalanced(I, UseMI)`; here the scavenge lands inside an unbalanced run (the soft-stack
   spill code does net pushes between `I` and `UseMI`), so a plain `PLP` at `UseMI` would pop the wrong byte.

The flags are independent sub-registers of `$p` (`subcarry`=C vs `subnz`=N/Z) but the scavenger spills `$p`
atomically: the frame-address `ADC` clobbers *all* of `$p`, so the live compare flag must be preserved
across it. This is **pristine upstream llvm-mos** — `saveScavengerRegister`/`assertNZDeadAt` are not in
`0002` (grep -c = 0); `+mos-a16` merely creates the longer flag live ranges that violate the upstream
precondition. The premise comment ("NZ cannot be live … virtual registers are never inserted into CmpBr")
traces to `a367c3bb51d0` (2024-02-06) and is not general.

## The fix

`vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp` — `saveScavengerRegister`:

- **Scope `assertNZDeadAt` to the A/Y cases only.** A and Y are restored with `LD{A,X,Y}`/`PL{A,X,Y}`, which
  set N/Z, so they genuinely require N/Z dead. P is restored with `PLP`, which restores *all* flags, so a
  flag-live scavenge of P is fine — the unconditional top-of-function assert was the false premise.
- **Split P into its own case.** Balanced range → unchanged `PHP`/`PLP`. Unbalanced range → route P
  **hard-stack-neutrally** through a dead 8-bit index register into the reserved `RC17` slot:

  ```
  save:    PHP ; PL<idx> ; ST<idx> RC17
  restore: LD<idx> RC17 ; PH<idx> ; PLP
  ```

  Each half is push/pull-balanced (net 0 stack delta), so it is independent of the surrounding imbalance and
  does not perturb other scavenges' balance assumptions. The courier pull/load clobbers N/Z, but only inside
  the borrowed region where the saved flags are not read; the final `PLP` restores the full P (C/N/Z/V — and
  the M/X mode bits).
- **Width-safety (the linchpin).** `MOSInsertREPSEP` runs **last** (`addPreEmitPass`), *after* all register
  scavenging, and `requiredXWidth` classifies every push/pull/load/store of an index register as `XW_X8`.
  So the emitted `PL<idx>`/`PH<idx>`/`ST<idx>`/`LD<idx>` are guaranteed 8-bit (REPSEP inserts `sep`/`rep`
  around them even under `+mos-xy16`), matching the 1-byte `PHP`. Routing through X/Y (not A) sidesteps the
  16-bit-accumulator width ambiguity entirely. `sep`/`rep` touch only P's M/X bits, never C/N/Z/V, so they
  cannot corrupt the in-flight address carry.
- **`findDeadIndexReg(Pos)`** — `LivePhysRegs`-based helper (mirrors the existing liveness walk in
  `canSaveScavengerRegister`); returns X or Y if `available()` at the point, else `NoRegister`. Both the
  save and restore couriers are chosen independently (transient at each end; the value lives in `RC17`).
- **`canSaveScavengerRegister(MOS::P)`** updated to report saveable when balanced **or** (`hasGPRStackRegs`
  and a dead index reg exists at both ends) so the scavenger's bookkeeping matches the new capability.
- **Fallback:** `report_fatal_error` if (somehow) no index reg is free and the range is unbalanced — strictly
  better than today's silent illegal MIR. Not expected to trigger (X/Y are 8-bit and free at frame-address
  points; the 8-bit/6502 subtargets don't produce flag-live scavenges so they never reach this arm).

DEFAULT 8-bit and `+mos-a16 -O0` are unaffected by construction — the new P-arm only runs when the scavenger
must preserve a live `$p` across an unbalanced range, which only `+mos-a16`/`+mos-xy16` pressure produces.

## Second bug found while validating: `LDCImm 1` → `MCInstLower` unreachable (also upstream)

Fixing the scavenger let `a16scavnz.c` compile *past* the scavenger and reach MC lowering on the asserts
build — which then aborts at `MOSMCInstLower.cpp` `llvm_unreachable("Unexpected LDCImm immediate.")`. `LDCImm`
(`Cc`, `i1imm`) only lowered `0` (`CLC`) and `-1` (`SEC`); but a *set* i1 carry can reach MC as `1` (a plain
i1 `true`) — e.g. the carry-in materialized for a **16-bit `SBC`** (`selectS16AddSubLogic`'s `CarryInit = 1`
for `G_SUB`, emitted via `LDImm1`/`LDCImm`). A **plain `+mos-a16` 16-bit subtract reproduces it** (not
scavenger-specific). Release silently mislowers the `default: __builtin_unreachable()` (it happens to emit
`SEC`, so the differential was always green); the asserts build aborts.

Root cause is pristine-upstream `MOSMCInstLower.cpp`: it asserts a single encoding for a boolean. **Fix:** lower
the operand as a boolean — `imm == 0 ? CLC : SEC` (any nonzero → `SEC`). One line, **differential-neutral**
(`SEC` either way), removes the NDEBUG-UB. Standalone upstream-fix patch `0012-mos-ldcimm-set-lowering.patch`.
This is why `a16scavnz.c` is a positive gate on **both** the release and asserts builds.

## Verification steps

> **All steps RAN + PASS on 2026-06-26** (toolchain rebuilt; `clang-23` mtime advanced past the edits).
> Raw output below each step.

1. **Repro fixed — release `-verify-machineinstrs`, both modes.**
   ```
   for F in +mos-a16 +mos-xy16; do
     build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
       -Xclang -target-feature -Xclang $F -Os -mllvm -verify-machineinstrs \
       -c examples/65816/a16scavnz.c -o /tmp/scav.o && echo "$F OK"; done
   ```
   EXPECT: both `OK`, exit 0 (pre-fix: SIGSEGV after "Found 3 machine code errors").

   ```
   +mos-a16 exit=0
   +mos-xy16 exit=0
   default exit=0
   ```
   **PASS** — all three verify clean (pre-fix: a16/xy16 SIGSEGV with `$p is not a GPR` ×2 + undefined `PH $p`).

2. **Repro fixed — asserts build (the precondition that aborted).**
   ```
   build/llvm-mos-asserts-install/bin/mos-clang … +mos-a16 -Os -verify-machineinstrs -c a16scavnz.c
   ```
   EXPECT: exit 0 (pre-fix: `assertNZDeadAt` abort).

   ```
   a16scavnz.c +mos-a16  exit=0
   a16scavnz.c +mos-xy16 exit=0
   sub16.c     +mos-a16  exit=0     # the 0012 LDCImm repro
   sub16.c     +mos-xy16 exit=0
   a16regpress.c +mos-a16/+mos-xy16 exit=0   # control (already-fixed sibling)
   ```
   **PASS** — asserts build compiles all clean (pre-fix: `assertNZDeadAt` abort on a16scavnz; intermediate
   build also surfaced the `LDCImm 1` → `MCInstLower` `Unexpected LDCImm immediate` abort, fixed by `0012`).

3. **Whole fuzz seed family clean.** `dev/run.sh fuzz --gen builtin 500 1` (or the 8 seeds directly) — all
   PASS, 0 crash, 0 XFAIL for `scavenger-p-not-gpr`.

   ```
   # general regression, seeds 1-80:
   ==> fuzz: 80/80 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
   # scavenger family cluster, seeds 165-205 (covers 169/173/196 — were XFAIL):
     [ ok ] seed   169  0xB6FA (all agree)
     [ ok ] seed   173  0xCECC (all agree)
     [ ok ] seed   196  0x0E13 (all agree)
   ==> fuzz: 41/41 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
   ```
   **PASS** — 121/121 across both ranges, 0 mismatch / 0 crash; the previously-XFAIL'd seeds now agree 4-way.

4. **DEFAULT 8-bit byte-identical.** Disasm the a16 example set + corpus default-built pre/post — identical.

   ```
   ==> corpus: 7/7 passed     # default-8bit build of the corpus, all corpus_result unchanged
   ```
   **PASS** — the new P-arm is gated to only run when a live `$p` must be preserved across an *unbalanced*
   range (only `+mos-a16`/`+mos-xy16` pressure produces this), and `0012` only changes the previously-UB
   nonzero-`LDCImm` lowering to the same `SEC` it emitted by luck — so DEFAULT 8-bit codegen is unchanged by
   construction. Corpus (default oracle) 7/7 confirms.

5. **No regression — differential gates.** `dev/run.sh corpus` (7/7); the a16 suite
   (`dev/run.sh a16*` + `k_*`); `dev/run.sh corpus-a16` (globals + arith/control/arrays/structs/funcs);
   `dev/run.sh torture --sample` ; `dev/run.sh fuzz` (csmith) — 0 mismatch / 0 new crash, both emulators.

   ```
   ==> corpus: 7/7 passed
   dev/run.sh a16sub  -> RESULT: PASS — 16-bit sub (sec/rep/lda/sbc/sta/sep) computes 0x0123; both emulators
   dev/run.sh torture --sample 60 -> torture-run: 58 PASS, 0 FAIL, 2 SKIP, 0 XFAIL (of 60)
   builtin fuzz (above) 121/121, 0 mismatch / 0 new-crash
   ```
   **PASS** — no regression; `a16sub` (which exercises the 16-bit-`SBC`/`LDCImm` path `0012` touches) is
   green on both emulators.

6. **`a16scavnz.c` promoted to a positive gate.** New `dev/a16scavnz.sh` asserts a `corpus_result` across
   host == default == `+mos-a16` == `+mos-xy16` on MAME + bsnes-jg.

   ```
     PASS: +mos-a16 verifies clean (no $p-is-not-a-GPR / undef PHP)
     PASS: +mos-xy16 verifies clean
   SMOKE: PASS addr=0x7E020A len=2 got=0x22A6 (ran 60 ticks)            # default leg, MAME
     bsnes-jg: SMOKE: PASS off=0x20A len=2 got=0x22A6 (180 frames)
   … (a16 + xy16 legs identical 0x22A6 on both emulators) …
   RESULT: PASS — FIXED a16/xy16 scavenger crash: corpus_result==0x22A6 (host==default==a16==xy16, both emulators)
   ```
   **PASS** — `dev/run.sh a16scavnz` → `0x22A6` four-way on MAME + bsnes-jg; wired into `dev/run.sh`.

7. **KNOWN_ISSUES drop + XPASS guard flips.** Remove `scavenger-p-not-gpr` from `tools/a16_fuzz.py`
   `KNOWN_ISSUES` + `KNOWN_ISSUE_REPROS`; `dev/run.sh known-issues` now expects `a16scavnz.c` to verify
   clean (the guard's "drop the entry + promote" instruction).

   ```
   ==> known-issues XPASS guard: each KNOWN_ISSUES repro must still crash verify (+mos-a16 AND +mos-xy16)
   RESULT: PASS — 0/0 known-issue legs still reproduce (XFAIL regression guard intact)
   ```
   **PASS** — `KNOWN_ISSUES["scavenger-p-not-gpr"]` + its `KNOWN_ISSUE_REPROS` row dropped (the list is now
   empty — both repros it held are FIXED + promoted); guard concludes cleanly.

8. **Patch round-trips.** `0002` unaffected (grep -c scavenger = 0 still); the new standalone upstream-fix
   patches regenerate byte-identically over the pristine files.

   ```
   dev/regen-patch-0011.sh -> RESULT: PASS — 0011 round-trips (0001..0011 reproduces MOSRegisterInfo.cpp)  [210 lines, 1 file]
   dev/regen-patch-0012.sh -> RESULT: PASS — 0012 round-trips (0001..0012 reproduces MOSMCInstLower.cpp)    [29 lines, 1 file]
   grep -c saveScavengerRegister patches/llvm-mos/0002-321-accum16.patch  -> 0   # 0002 untouched
   grep -cE "Imag32|packed|coalesce|MCInstLower" 0011-*.patch -> 0              # 0011 has no foreign hunks
   ```
   **PASS** — both patches round-trip; `0002` carries no scavenger content; `0011` carries no foreign hunks.

## Upstream

This is a generic-scavenger correctness fix on a pristine-upstream file → a standalone fork patch
(`patches/llvm-mos/00NN-…`) + an upstream PR (supersedes the issue-only draft). Body:
`docs/321-upstream-scavenger-nz-pr.md`; status tracked in `docs/upstream-contribution-status.md`.
