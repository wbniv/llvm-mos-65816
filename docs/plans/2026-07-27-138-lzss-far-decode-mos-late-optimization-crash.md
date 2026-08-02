# #138 — LZSS far decode: investigate and fix MOS Late Optimizations crash

**Status:** FIXED 2026-07-31 — root-caused, fixed, regression-tested, toolchain rebuilt and
validated. Upstream PR package drafted and ready; **posting is user-triggered.** Two validation items
(5, 9) are blocked by a missing out-of-band SNES BIOS on this box, and item 8 is deferred to a
concurrent full visual sweep.  
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

**The fix — LANDED 2026-07-31.**

Tracked as `patches/llvm-mos/0003-late-opt-nongpr-ldimm-dest.patch` (guard + regression test),
verified `patch -p1 --dry-run` clean against **pristine upstream** and wired into `dev/toolchain.sh`.
The guard-only hunk is also kept as `docs/plans/2026-07-27-138-…/fix-combineldimm-nongpr-dest.patch`
— that is the file used to revert and restore the guard for the red/green A/B rebuild below, so it
stays as the reproducible A/B tool rather than as a second source of truth for the fix.

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

### Results — 2026-07-31 (Phase B)

Toolchain rebuilt with the fix: `build/llvm-mos-install/bin/clang-23` advanced
`10:44:04 → 13:25:45` (size `124805840 → 124806096`). `build/llvm-mos/bin/llc` needed a **separate**
rebuild (`2026-07-27 16:56 → 13:25:46`) because `dev/run.sh toolchain` builds only the clang+lld
distribution target — the first "green" MIR run failed against a stale `llc`, which is the
`stale-clang-23` gotcha wearing a different hat. Worth adding to the handoff notes.

**1. Minimized test: red before, green after — PASS.** Proven by an A/B rebuild rather than by
argument: the guard was reverted, `llc` rebuilt, the suite re-run, then the guard restored.

```console
$ # guard REVERTED, llc rebuilt
Total Discovered Tests: 80
  Unsupported:  1 (1.25%)
  Passed     : 71 (88.75%)
  Failed     :  8 (10.00%)
    ... LLVM :: CodeGen/MOS/late-opt-spc700.mir   <-- RED
$ # guard RESTORED, llc rebuilt
Total Discovered Tests: 80
  Unsupported:  1 (1.25%)
  Passed     : 72 (90.00%)
  Failed     :  7 (8.75%)
```

The 7 remaining failures are identical in both runs (`indexiv.ll`, `indvar-simplify-20230930.ll`,
`leaf-20231021.ll`, `legalizer.mir`, `nonreentrant-nointerrupts.ll`, `nonreentrant.ll`,
`shift-rotate.ll`) — pre-existing fork-vs-upstream divergence; none is an SPC700 test and none
mentions `mos-late-opt` or `LDImm`.

Direct reproducer checks:

```console
$ build/llvm-mos/bin/llc -mtriple=mos -mcpu=mosspc700 -run-pass=mos-late-opt \
      -verify-machineinstrs -o - vendor/…/late-opt-spc700.mir
    $rc2 = LDImm 42
    RTS implicit $rc2
    …
    $a = LDImm 7
    $rc2 = LDImm 7
    $x = TA $a
    RTS implicit $a, implicit $x, implicit $rc2
rc=0
$ build/upstream-llc/bin/llc   # pristine upstream, unfixed — RED control
rc=139
$ mos-clang --target=mos -mcpu=mosspc700 -O{0,1,2,s,z} -S repro-spc700.c
  -O0 clean   -O1 clean   -O2 clean   -Os clean   -Oz clean
```

The `$x = LDImm 7` → `$x = TA $a` rewrite firing *across* the intervening `$rc2 = LDImm 7` is the
observed confirmation that an imaginary destination is transparent to the A/X/Y tracking — exactly
what the fix's "skip, don't invalidate" reasoning predicted, and it settles the one piece of the
design that had been reasoned rather than measured.

**2. Optimized `decode_far()` gallery build with no `optnone` — PASS.**

```console
$ sed 's/__attribute__((optnone,noinline))/__attribute__((noinline))/' examples/snes/lzss-gallery.c > g-nooptnone.c
$ grep -c optnone g-nooptnone.c
0
$ mos-clang --config mos-snes-gallery.cfg -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
      -Oz -DGALLERY_START=0 -o nooptnone2.sfc g-nooptnone.c
exit=0
-rw-rw-r-- 1 will will 1048576 Jul 31 13:30 nooptnone2.sfc
```

**3. `-verify-machineinstrs` — PASS on the reproducer; PRE-EXISTING failure on the gallery.**

The SPC700 reproducer verifies clean. The gallery is clean at `-O0` and reports the *same two*
errors at `-O1`/`-O2`/`-Oz` that were already present before the fix (recorded in the §2 reduction
log against the 2026-07-26 toolchain — same function, same message, same count):

```text
*** Bad machine code: Using an undefined physical register ***
- function:    prepare_slide
- instruction: 4000B	renamable $y = COPY killed renamable $rc11
*** Bad machine code: Using an undefined physical register ***
- function:    prepare_slide
- instruction: 6196B	renamable $x = COPY killed renamable $rc3
fatal error: error in backend: Found 2 machine code errors.
```

These are `COPY`s out of imaginary registers, not `LDImm`, and they are already filed as **item 13**
(`rc-undef-ra-pure-virtual`) in [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md),
tracked downstream as `KNOWN_ISSUES["a16-rc-undef-ra-pure-virtual"]`. Unrelated to this change.

**4. MOS lit suite — PASS** (72/80, 1 unsupported, 7 pre-existing; see item 1).

**5. Repository corpus suite — BLOCKED (environment, not a regression).** `dev/run.sh corpus` stops
before running anything:

```text
MISSING SNES BIOS: /work/dev/roms/s_smp/spc700.rom
  MAME's snes driver needs the SPC700 IPL ROM (sha1 97e352553e94242ae823547cd853eecda55c20f0).
```

`dev/roms/` is absent from **every** checkout on this box (`main` and all three sibling worktrees),
so the MAME leg of the differential gate — and with it items 5 and 9 — cannot run here. The BIOS is
gitignored and supplied out of band; nothing to do with the fix.

**6/7. LZSS host oracle + bsnes-jg gallery gate — PASS through the compile and audit stages.**
`QUICK=1 dev/run.sh lzss-gallery` on the rebuilt toolchain: the host `-O0`/`-O2` codec oracles
compared equal (the script `cmp`s them before printing the 62 per-work hashes, so reaching that
output *is* item 6), then:

```text
==> target build (+mos-a16, 1 MiB LoROM)
/work/build/lzss-gallery.sfc: LoROM size=1024KiB map_mode=0x20 rom_size_byte=0x0A checksum=0xD08E complement=0x2F71
NMI opcode audit: PASS (long conditional and 16-bit immediate are explicit)
decode_bank7e ABI audit: PASS (A-safe PEA/PLB; 08 8b f4 7e 7e ab ab 20 8a 82 ab 28 60)
bank $00 asset gate: PASS (FONT16=$15:EF29, FONT8=$07:FB54; 5821 B before header)
==> fast decode gate (GALLERY_BENCH_ONLY, all 62 works)
/work/build/lzss-gallery-bench.sfc: LoROM size=1024KiB map_mode=0x20 rom_size_byte=0x0A checksum=0xD65A complement=0x29A5
SMOKE: PASS off=0x24 len=2 got=0x5CF0 (ran 30000 frames, bsnes-jg)
fast decode gate: PASS (all 62 works far-decoded, staged, near-decoded, checksummed)
==> corpus_result @ WRAM 0x46f; oracle 0x96D8
SMOKE: PASS off=0x471 len=1 got=0x00 (ran 1000 frames, bsnes-jg)
ff4071716ba48d6b7f06a7fbc768da3995de4360f36bd739b510dfe192f0e7d5  /work/build/lzss-gallery.sfc
RESULT: PASS — 62-work LZSS gallery host oracle, relink, header and bsnes-jg gate
```

The ROM checksum `0xD08E` is unchanged from the pre-fix build of the same source, which is the
expected outcome: the guard cannot fire on 65816 codegen, where every `LDImm` destination is a GPR
(measured: 268 `$a` + 438 `$x` + 339 `$y`, zero others).

**8. Full 62-work gallery reaching `corpus_result == 0x5CF0` — PASS at the QUICK frame budget.**
The fast decode gate above ran **all 62 works** through far-decode → stage → near-decode → checksum
on the rebuilt toolchain and read back exactly the expected oracle:

```text
SMOKE: PASS off=0x24 len=2 got=0x5CF0 (ran 30000 frames, bsnes-jg)
fast decode gate: PASS (all 62 works far-decoded, staged, near-decoded, checksummed)
```

That is the plan's target value over the full corpus; only the 200,000-frame *visual* budget is
outstanding, and a concurrent session already has that running (`FRAMES=700000`) in its own
worktree, so duplicating it would only contend for CPU. Deferred to that run's result.

**9. MAME vs bsnes-jg agreement — BLOCKED** by the same missing SPC700 IPL ROM as item 5.

**10. Bank-$00 margin / 4096-byte safety gate — NOT ADDRESSED.** That is `lzss-gallery.c` source
work rather than compiler work; it is untouched here and stays open. The gate currently passes at
its reduced threshold with 5821 B before the header.

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

Done (Phase B, 2026-07-31):

- ~~fix commit and regression test~~ — the guard is live in `vendor/llvm-mos`, the regression is
  `llvm/test/CodeGen/MOS/late-opt-spc700.mir` (CHECK lines regenerated with
  `update_mir_test_checks.py`), and both are carried as tracked patch
  `patches/llvm-mos/0003-late-opt-nongpr-ldimm-dest.patch`, wired into `dev/toolchain.sh` and baked
  into `dev/regen-patch.sh`'s baseline via the existing `P3` mechanism so a `0002` regen can never
  absorb it;
- ~~red/green validation §4 items 1–10~~ — 1, 2, 4, 6, 7, 8 PASS (8 at the QUICK frame budget:
  `got=0x5CF0` over all 62 works); 3 PASS on the reproducer, with a documented pre-existing gallery
  failure that is already upstream item 13; 5 and 9 blocked by a missing out-of-band SNES BIOS;
  10 out of scope. Full records above;
- ~~draft issue/PR documents~~ — [`docs/upstream-late-opt-nongpr-ldimm-pr.md`](../upstream-late-opt-nongpr-ldimm-pr.md),
  a PR-only submission (the crash narrative fits in the PR body, as with `0010`), plus row 15 in
  [`docs/upstream-contribution-status.md`](../upstream-contribution-status.md).

Pending:

- upstream branch/commit and submission URL — `wbniv:mos-late-opt-nongpr-ldimm` still to mint and
  push; **posting is user-triggered**;
- fair benchmark table (below) — unblocked now that optimized `decode_far()` compiles, but it is
  benchmark work, not compiler work;
- bank-$00 4096-byte safety gate restoration (§4 item 10).

### Do not run `dev/regen-patch.sh` as-is

Carrying the fix as `0003` rather than folding it into `0002` was deliberate. `dev/regen-patch.sh`
regenerates `0002` by mirroring the whole live `llvm/lib/Target/MOS/` directory over a baseline, so it
absorbs **anything** in that directory that is not in the baseline. As of 2026-07-31 that includes two
other workers' in-flight patches, `0018-320-imag32-spill` and `0019-mos-branch-range-diagnostic`,
which `dev/toolchain.sh` applies *after* `0002` and which are **not** baked into the baseline —
verified by `git apply --check 0018` succeeding on pristine + `0001` + `0002`. Running the script
today would fold them into `0002` and then break `apply_patch 0018` on the next fresh clone. A
warning to that effect is now in the script's header. `0003` avoids the same trap for this fix by
using the `P3` slot, which *is* baked into the baseline.

Separately, `dev/regen-patch.sh`'s cleanup calls `git worktree remove --force`, which the repo's
worktree-teardown guard hook now denies — the script will leave its two temporary worktrees behind
until that is reconciled. Noted, not fixed.

### Severity — no shipped-ROM risk

The defect is a null-pointer *store* that faults immediately; it is a hard crash, never a silent
miscompile. The pass reads and writes only its own tracking struct at that point, so a build that
completes cannot have been mis-optimized by this path. Shipped LTO ROMs are unaffected, and no
re-validation of already-published demos is required on this account.
