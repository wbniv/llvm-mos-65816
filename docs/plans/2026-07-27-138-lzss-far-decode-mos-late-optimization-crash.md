# #138 — LZSS far decode: investigate and fix MOS Late Optimizations crash

**Status:** ROOT-CAUSED 2026-07-31 (Phase A complete; Phase B — apply fix + rebuild + validate —
gated on toolchain quiescence)  
**Trigger:** removing `optnone` from `decode_far()` in
`examples/snes/lzss-gallery.c` crashes `ld.lld` during LTO. *Superseded:* that trigger no longer
fires; the live reproducer is 4 lines of MIR on the upstream SPC700 target (see **Root cause**).  
**Deliverable:** root-cause fix, minimized regression test, full gallery validation, and an
upstream-ready llvm-mos issue/PR package.

## Goal

Treat the compiler crash found while making the far-vs-near LZSS benchmark fair as a compiler-suite
result. Make optimized `decode_far()` compile reliably, then compare:

- optimized far decode directly from ROM;
- far ROM → WRAM copy;
- optimized near decode from WRAM; and
- the fair end-to-end total `copy + near`.

Both decoder bodies must have equivalent validation/control flow and the same optimization policy.
Do not publish benchmark conclusions from the current asymmetric build (`decode_far` is `optnone`,
`decode_near` is `-Oz`) as the final result.

## Known red state

The gallery builds with:

```c
__attribute__((optnone,noinline))
static uint16_t decode_far(...);
```

Changing that to:

```c
__attribute__((noinline))
static uint16_t decode_far(...);
```

reliably reaches LTO and aborts:

```text
Running pass 'MOS Late Optimizations' on function '@decode_far'
MOSLateOptimization::runOnMachineFunction(llvm::MachineFunction&)
ld.lld: Segmentation fault
mos-clang: error: ld.lld command failed
```

Reproduction command:

```sh
QUICK=1 dev/run.sh lzss-gallery
```

Configuration:

```text
mos-clang --config mos-snes-gallery.cfg -mcpu=mosw65816
  -Xclang -target-feature -Xclang +mos-a16 -Oz -flto
```

The crash also appeared earlier when `unpack_slide()` became large enough for the same late pass;
splitting that wrapper avoided it. That is a useful structural clue, not an acceptable fix.

## Root cause — SOLVED 2026-07-31 (Phase A)

**One line:** `MOSLateOptimization::combineLdImm` dereferences a null `ImmLoad *` for any `LDImm`
whose destination register is not `A`, `X` or `Y`.

`MOSLateOptimization.cpp:399` unconditionally writes through `Load`:

```cpp
    // Store this instruction (changed or not) and the new register value.
    switch (Dst) {
    case MOS::A: Load = &LoadA; break;
    case MOS::X: Load = &LoadX; break;
    case MOS::Y: Load = &LoadY; break;
    }

    Load->MI = &MI;          // <- Load is still nullptr if Dst is none of A/X/Y
    Load->Val = Val;
```

`Load` is initialised to `nullptr` at the top of each iteration and is only ever assigned inside
switches over `{A, X, Y}`, so a fourth kind of destination walks straight off the end into a write
to address `0`. Faulting instruction, confirmed under `gdb`:

```text
=> mov %r15,0x0(%rbp)      ; Load->MI = &MI      rbp = 0x0, r15 = &MI
   mov 0x8(%rsp),%rax
   mov %rax,0x8(%rbp)      ; Load->Val = Val
```

Two distinct producers reach it:

1. **Upstream, still live today.** On **SPC700**, `MOSInstrInfo::getRegClass` deliberately widens
   `LDImm`'s destination class to `Anyi8` — `$rcN = LDImm imm` is how `mov dp, #imm` is modelled:

   ```cpp
   // On SPC700, LDImm can be used for imaginary registers.
   if (STI->hasSPC700() && MCID.getOpcode() == MOS::LDImm && OpNum == 0)
     return &MOS::Anyi8RegClass;
   ```

   So an imaginary destination is **legal, verifier-clean MIR** and the crash needs no fork feature
   at all. Reproduces on **pristine upstream** `llvm-mos`.

2. **The #138 gallery path.** The 2026&#8209;07&#8209;26 fork toolchain emitted `$rl1 = LDImm -1` /
   `$rl1 = LDImm 0` — an `Imag32` (far-pointer) destination on a GPR-only opcode, i.e. malformed
   MIR — in `@unpack_slide`. That producer bug is **no longer present** after the
   2026&#8209;07&#8209;31 08:08 vendor rebuild (see the reduction log), which is why the gallery no
   longer crashes. The consumer defect it exposed is unchanged, so #138's root cause is fully live;
   the demo merely stopped stepping on it.

Because the guard is a register-class test rather than an enumeration, one fix covers both producers.

### Adjacent finding — not fixed here

`lowerCmpZeros` (`MOSLateOptimization.cpp:142`) tests a **loop-carried** `Changed` flag:

```cpp
    if (Changed)
      continue;      // meant to mean "this CmpZero was folded", but Changed is
                     // sticky for the whole basic block
    Changed = true;
    lowerCmpZero(MI);
```

Once any `CmpZero` in a block folds into a preceding NZ-defining instruction, every later `CmpZero`
in that block that fails to fold is skipped instead of lowered. `MOS::CmpZero` is lowered **only**
by this pass, so a survivor reaches the asm printer as an unlowered pseudo. Reported, not fixed —
separate bug, separate change.

### No visible surface

This is a compiler backend fix. There is no UI, rendered page, CLI screen or generated document, so
the plan carries no mockup bundle; the co-named directory holds the reproducers and the fix instead.

## Working-tree isolation

`examples/snes/lzss-gallery.c` contains concurrent, uncommitted scanner-beam work (#137) and the
near-decode benchmark. Preserve it. Create the compiler reproducer from an explicit diff or a
temporary/worktree copy, and record the exact source revision plus local patch SHA. Do not fold the
scanner visualization into the compiler fix.

The current benchmark also reduced the bank-$00 safety gate from 4096 to 3584 bytes. Reassess and
prefer restoring the 4096-byte gate after the compiler fix/code-size pass; do not let that temporary
accommodation silently become part of the backend submission.

## Investigation

### 1. Capture a durable reproducer

1. Save the full failing compiler/link command (`-v`) and complete stack trace.
2. Preserve the LTO inputs and linked IR using the appropriate LTO save-temps option.
3. Confirm whether the failure reproduces in:
   - the repository toolchain;
   - a debug/assertions build;
   - current pristine llvm-mos upstream tip; and
   - `llc` directly on reduced IR/MIR, without the SNES linker script/assets.
4. Record the first bad pass and function with `-stop-before/-stop-after` or pass bisect.
5. Obtain a symbolized debug backtrace and the exact crashing source line in
   `MOSLateOptimization.cpp`.

Acceptance: one checked-in or documented command reproduces the crash without the 1 MiB gallery
asset corpus.

**PASS — 2026-07-31.** Two checked-in reproducers, neither needing the corpus, the SNES platform,
`+mos-a16`, LTO, or any fork feature.

**(a) 4-line MIR, current toolchain** — `2026-07-27-138-…/late-opt-spc700.mir`:

```console
$ build/llvm-mos/bin/llc -mtriple=mos -mcpu=mosspc700 -run-pass=mos-late-opt -o - \
      docs/plans/2026-07-27-138-…/late-opt-spc700.mir
2.	Running pass 'MOS Late Optimizations' on function '@ldimm_imag8_only'
 #4 0x... (anonymous namespace)::MOSLateOptimization::runOnMachineFunction(llvm::MachineFunction&)
Segmentation fault
```

**(b) 7-line C, current toolchain** — `2026-07-27-138-…/repro-spc700.c`:

```console
$ build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosspc700 -Os -S -o /dev/null \
      docs/plans/2026-07-27-138-…/repro-spc700.c
4.	Running pass 'MOS Late Optimizations' on function '@f'
mos-clang: error: clang frontend command failed due to signal
```

Crashes at `-O1`, `-O2`, `-Os` and `-Oz`; clean at `-O0` (nothing is allocated to an imaginary
register).

**Provenance, per step 3 of this section:**

| Toolchain | Result |
|---|---|
| repository toolchain (`build/llvm-mos-install`, rebuilt 2026-07-31 08:08) | **crashes** on (a) and (b) |
| repository toolchain, `-fno-lto -S` on `lzss-gallery.c` | clean (producer bug gone) |
| 2026-07-26 toolchain (`…-gallery-repack/build/llvm-mos-install`), `-fno-lto -S` on `lzss-gallery.c` | **crashes** on `@unpack_slide` at `-O0` and `-Oz`; clean at `-O1` |
| 2026-07-26 toolchain, full LTO link, `optnone` removed from `decode_far()` | clean — the plan's original trigger no longer fires even on the old toolchain |
| repository toolchain, full LTO link, `optnone` removed from `decode_far()` | clean, 1 048 576-byte ROM produced |
| **pristine upstream `llvm-mos`** (`build/upstream-llc/bin/llc`) | **crashes** on (a) and on `-Os` IR from (b) |

`llc` on reduced IR/MIR without the SNES linker script and assets: covered by (a) and by feeding
(b)'s `-emit-llvm` output to `build/upstream-llc/bin/llc`.

Step 4 (first bad pass/function) and step 5 (symbolized backtrace + crashing line): `MOS Late
Optimizations` / `@unpack_slide` (gallery) and `@f` / `@ldimm_imag8_only` (reduced), crashing at
`MOSLateOptimization.cpp:399`. The release binaries carry no line info, so the line was pinned by
disassembling around `$pc` under `gdb` (the two-field `ImmLoad` store at `+0`/`+8` through a null
base, reached by the `jne` that skips the `std::abs(Load->Val - Val) == 1` IN_/DE_ rewrite) and
confirmed by reading operand 0 of the crashing `MachineInstr`: opcode 483 = `LDImm`, register 276 =
`$rl1`.

### 2. Minimize without erasing the trigger

Reduce in this order:

1. whole gallery → `decode_far()` plus a tiny caller;
2. C/LTO → LLVM IR;
3. IR → MIR immediately before MOS Late Optimizations;
4. remove decoder branches, loop structure, far source/destination accesses, and `+mos-a16`
   independently;
5. vary `-Oz`, LTO, address-space-2 pointers, accumulator width, and function size separately.

Keep a reduction log. In particular, determine whether the trigger is:

- a stale/deleted `MachineInstr` or iterator invalidation;
- an unexpected operand/register class from 24/32-bit far-pointer lowering;
- a malformed branch/CFG introduced by late peepholes;
- a width-state (`REP`/`SEP`) assumption;
- an LTO-only property; or
- a generic upstream bug merely exposed by the fork’s far-pointer feature.

Run `-verify-machineinstrs` before and after the suspect pass. If verification fails earlier, fix
the producer rather than papering over the consumer.

**Reduction log — 2026-07-31.**

| Step | Outcome |
|---|---|
| whole gallery, LTO | no crash on either toolchain — LTO is **not** required and, contrary to the plan's premise, no longer triggers it |
| whole gallery, `-fno-lto -S`, 2026‑07‑26 toolchain | crash on `@unpack_slide` (`-O0`, `-Oz`); clean at `-O1` |
| same source + `-Oz -emit-llvm -S`, IR re-fed to the same clang (with and without `-disable-llvm-passes`) | **no crash** — the textual-IR round trip re-runs the pipeline and lands on a different allocation, so IR is the wrong reduction layer here |
| `-mllvm -print-before=mos-late-opt`, 2026‑07‑26 | MIR contains `$rl1 = LDImm -1` and `$rl1 = LDImm 0` — malformed (an `Imag32` destination on a GPR-only opcode) |
| same, repository toolchain | only `$a`/`$x`/`$y` destinations (268 + 438 + 339 occurrences, zero others) — producer bug gone |
| `gdb` on the 2026‑07‑26 `clang-23` | faulting store is the 16-byte `ImmLoad` write through a null base; crashing `MachineInstr` = `LDImm` (opcode 483) with operand 0 = `$rl1` (register 276) |
| read `MOSInstrInfo::getRegClass` | SPC700 legalises an `Anyi8` `LDImm` destination → same null path reachable with **valid** MIR, no fork feature |
| synthetic MIR `$rc2 = LDImm 42` on `-mcpu=mosspc700` | crash, current toolchain **and** pristine upstream |
| plain C, 8 live bytes, `-mcpu=mosspc700 -Os` | crash, current toolchain |
| same C reduced to 4 live bytes | **no crash** — everything stays in A/X/Y, nothing is allocated to an imaginary register |

Trigger classification against the plan's checklist: **an unexpected operand/register class**. Not a
stale `MachineInstr`/iterator invalidation, not a malformed CFG, not a `REP`/`SEP` width-state
assumption, and **not** LTO-only. The 65816 far-pointer (`Imag32`) shape was the *fork's* way in; the
underlying defect is a generic upstream one that the fork merely reached from a second direction.

`-verify-machineinstrs` notes:

- Reduced reproducer (a): the input MIR is verifier-clean (`-run-pass=none -verify-machineinstrs`
  round-trips it), so this is not "garbage in, garbage out" — the pass must handle it.
- 2026‑07‑26 gallery build: `-verify-machineinstrs` aborts *earlier*, at `@prepare_slide`, with two
  `*** Bad machine code: Using an undefined physical register ***`. That is the same
  `Imag32`-handling defect family addressed by the concurrently-authored
  `patches/llvm-mos/0018-320-imag32-spill.patch`, i.e. a **producer** bug that has since been fixed
  by other work; it is out of scope here and is *not* what this change papers over.

### 3. Root cause and fix

The fix must:

- address the invalid invariant at its owner;
- avoid function-name, size, or LZSS-specific exceptions;
- retain valid late optimizations;
- be safe for default 8-bit, `+mos-a16`, and `+mos-xy16` configurations; and
- include an explanatory comment only where the invariant is non-obvious.

Add the smallest regression at the lowest useful layer:

- MIR test under `llvm/test/CodeGen/MOS/` for a late-pass invariant/transform; or
- IR codegen test if legalization/register allocation is part of the trigger.

The test must crash before the fix and pass after it. Add output checks only for behavior essential
to the bug; the primary regression is “no crash + machine verification succeeds.”

**Proposed fix — ready to implement, Phase B gated on toolchain quiescence.**

`docs/plans/2026-07-27-138-…/fix-combineldimm-nongpr-dest.patch`, verified to apply cleanly to the
current `vendor/llvm-mos` with `git apply --check`:

```diff
     // Process LD_ #.
     Register Dst = MI.getOperand(0).getReg();
+
+    // LDImm's destination is not always a GPR. MOSInstrInfo::getRegClass
+    // widens it to Anyi8 on SPC700, where `$rcN = LDImm imm` is how
+    // `mov dp, #imm` is modelled. Only A, X and Y take part in the rewrites
+    // below, and an imaginary destination writes none of them, so there is
+    // nothing to rewrite here and no tracked value to invalidate.
+    if (!MOS::GPRRegClass.contains(Dst))
+      continue;
+
     int64_t Val = MI.getOperand(1).getImm();
```

Against the plan's constraints: it addresses the invalid invariant at its owner (`combineLdImm` owns
the assumption that a tracked destination is a GPR); it is a register-class test, not a function-name,
size or LZSS-specific exception; every valid A/X/Y rewrite is retained untouched; and it is a no-op
for default 8-bit, `+mos-a16` and `+mos-xy16` configurations, where `LDImm`'s destination class is
already GPR-only. The comment sits exactly where the invariant is non-obvious.

Skipping is the correct semantic, not merely a safe one: `$rcN = LDImm imm` writes no GPR, so the
`LoadA`/`LoadX`/`LoadY` values tracked across it stay valid and must **not** be invalidated. The
second MIR test case pins that.

Rejected alternative: give SPC700 its own opcode instead of widening `LDImm`'s destination class in
`MOSInstrInfo::getRegClass`. That removes the surprise at its source, but it rewrites a deliberate
upstream modelling decision, touches instruction selection, the asm printer and the post-RA
expanders, and risks regressing SPC700 codegen — a large blast radius for a defect that is really a
missing guard in one consumer. Also rejected: `default: llvm_unreachable(...)`, which is wrong
because the case is legal, and which in a release (no-assertions) build is UB rather than a
diagnostic — precisely how this stayed a silent segfault.

Regression test: `docs/plans/2026-07-27-138-…/late-opt-spc700.mir`, to land as
`llvm/test/CodeGen/MOS/late-opt-spc700.mir` (matching the existing `late-opt.mir` /
`late-opt-65c02.mir` / `late-opt-65816.mir` family). Its `CHECK` lines are hand-written and must be
regenerated with `llvm/utils/update_mir_test_checks.py` once the fix is built.

### 4. Red/green validation

Required evidence:

1. minimized test: red before, green after;
2. optimized `decode_far()` gallery build succeeds with no `optnone`;
3. `-verify-machineinstrs` succeeds;
4. relevant MOS lit suite passes;
5. repository compiler/corpus suite passes;
6. LZSS host `-O0/-O2` oracle remains identical;
7. quick bsnes-jg smoke passes;
8. full 62-work, 200,000-frame gallery reaches `corpus_result == 0x5CF0`;
9. MAME and bsnes-jg agree on the final WRAM oracle; and
10. bank-$00 margin is measured and the normal 4096-byte safety gate is restored if possible.

## Fair benchmark rerun

After the compiler fix:

1. Generate `decode_far()` and `decode_near()` from visibly equivalent logic.
2. Compile both with `-Oz`, `noinline`, and no `optnone`.
3. Put cancellation checks outside all timed regions, or put identical checks inside both.
4. Time, for every artwork:
   - `far`;
   - `copy`;
   - `near`; and
   - `copy + near`.
5. Preserve correctness independently:
   - expected decompressed length;
   - checksum of both outputs;
   - byte-for-byte equality at least in the verification path.
6. Report min/median/mean/max frames, aggregate frames, compressed-byte correlation, and crossover
   point. Note the ±1-frame quantization of the NMI clock.
7. Audit disassembly to prove the far path uses long/far accesses and the near path uses
   DBR-relative absolute accesses in WRAM bank `$7E`.

The preliminary asymmetric measurement for *Approach to Venice* is retained only as a clue:

| Path | Frames |
|---|---:|
| current `optnone` far | 291 |
| ROM→WRAM copy | 55 |
| optimized near | 122 |
| copy + optimized near | 177 |

Do not label the 39% result final until the optimized-far rerun above is complete.

## Upstream submission package

Determine provenance before choosing the submission shape:

- **Reproduces on pristine upstream:** standalone llvm-mos bug fix and PR.
- **Requires the fork-only far-pointer/a16 series:** fold the fix and regression into the relevant
  upstream feature series; do not submit an introduce-then-fix sequence.

**Decided 2026-07-31: the first shape.** `build/upstream-llc/bin/llc` (pristine upstream, no fork
patches) segfaults on both reduced reproducers, and the triggering register-class widening
(`MOSInstrInfo::getRegClass`, SPC700) is upstream code. This is a standalone upstream bug fix: one
commit touching `llvm/lib/Target/MOS/MOSLateOptimization.cpp` plus
`llvm/test/CodeGen/MOS/late-opt-spc700.mir`, with the SPC700 C reproducer quoted in the PR body and
the LZSS gallery linked as the real-world sighting. No fork artifacts (`+mos-a16`, far pointers,
`Imag32`, the SNES platform, benchmark telemetry, patch-stack mechanics) belong in the upstream
commit — the fork's `$rl1 = LDImm` producer bug is a *separate* fork-side issue and must not appear
in the upstream narrative beyond, at most, a one-line "also seen with a 32-bit imaginary
destination".

Prepare, but do not post without the explicit submission step:

1. clean branch based on current upstream tip;
2. one focused fix commit plus regression test;
3. issue body when diagnosis benefits from a public crash report;
4. PR title/body explaining symptom, root cause, invariant, fix, and tests;
5. minimized reproducer and exact red/green commands;
6. release note only if user-visible behavior warrants it;
7. update `docs/upstream-contribution-status.md`;
8. run `dev/upstream-status.sh`;
9. link the gallery as the real-world reproducer without requiring its asset corpus for review.

Before submission, verify formatting, lit tests, a pristine upstream build, and that no generated
ROM/assets, site changes, scanner-beam changes, benchmark telemetry, or local patch-stack mechanics
are present in the upstream commit.

## Completion record

Done (Phase A, 2026-07-31):

- ~~minimized reproducer~~ — `late-opt-spc700.mir` (4 lines of MIR) and `repro-spc700.c` (7 lines of
  C), both in the co-named bundle directory; neither needs the asset corpus, the SNES platform,
  `+mos-a16` or LTO;
- ~~crashing source line and root cause~~ — `MOSLateOptimization.cpp:399`, null `ImmLoad *` for a
  non-GPR `LDImm` destination;
- ~~upstream-tip applicability decision~~ — reproduces on pristine upstream `llvm-mos`, so this is a
  **standalone upstream bug fix and PR**, not something to fold into the fork's far-pointer series.

Pending (Phase B, gated on toolchain quiescence — a rebuild swaps `build/llvm-mos-install` under
every concurrent agent, and several `dev/run.sh` jobs were live when Phase A closed):

- fix commit and regression test — patch and test are written and the patch is `git apply --check`
  clean; applying it needs a `dev/run.sh toolchain` rebuild to validate;
- red/green validation §4 items 1–10;
- full suite/corpus results;
- fair benchmark table;
- draft issue/PR documents;
- upstream branch/commit and submission URL.

### Severity — no shipped-ROM risk

The defect is a null-pointer *store* that faults immediately; it is a hard crash, never a silent
miscompile. The pass reads and writes only its own tracking struct at that point, so a build that
completes cannot have been mis-optimized by this path. Shipped LTO ROMs are unaffected, and no
re-validation of already-published demos is required on this account.
