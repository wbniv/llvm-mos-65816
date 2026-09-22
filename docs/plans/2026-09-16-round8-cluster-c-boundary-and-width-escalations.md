# Round 8 Cluster C (#151–#155) — boundary and width escalations of paths with one shipped demo

Cluster A (#142–#145) took Round 8's four sharpest *un-entered* branches; Cluster B (#146–#150) took
the five conversion/comparison/layout paths with no demo at all. Cluster C takes the first half of
the third group in the ideas doc — *"paths that are covered, but only at one width or one shape"*.

The question is no longer "which branch has never fired?" but **"the branch fired once, at one
point — does it still hold at the edge, at the other width, and when two of them nest?"** Two of the
five (#152, #154) sit **exactly on a size-gated classifier's boundary constant**, which is the
classic place for an off-by-one in a lowering that has otherwise been correct for 141 demos.

Original September 16 scope, matching Clusters A and B: **build + gate only**.
All five demos were subsequently published September 22; see the
[publication audit](../investigations/2026-09-22-snes-demo-publication-audit.md).
The register-exhaustion defect found by #154 now has a validated standalone fix,
[patch 0029](../upstream-twoaddr-physreg-reschedule-pr.md). The measurements and
logs below retain the original build-stage evidence.

---

## Pre-build measurements — the boundary constants, read from the source, not from the brief

The dispatch brief quoted two constants. This project's first governing lesson is *measure, don't
assume*, so both were read out of `vendor/llvm-mos/` and then confirmed by compiling a probe.

### The jump-table boundary — `Table.MBBs.size() <= 128`, CONFIRMED verbatim

`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp:3334`, inside `legalizeBrJt`:

```cpp
  if (STI.hasJMPIdxIndir() && Table.MBBs.size() <= 128) {
    Offset = Builder.buildShl(S8, Offset, Builder.buildConstant(S8, 1)).getReg(0);
    Builder.buildInstr(MOS::G_BRINDIRECT_IDX) ...
  } else {
    ... two G_LOAD_ABS_IDX (the second under MOS::MO_HI_JT) + G_BRINDIRECT ...
  }
```

Probe (five dispatch functions of 126/127/128/129/130 distinct successors in one TU, `-Os`,
`-verify-machineinstrs` clean), reading the emitted arm per function:

| successors | emitted | arm |
|---|---|---|
| 126 | `jmp (.LJTI1_0,x)` | `JMPIdxIndir` |
| 127 | `jmp (.LJTI2_0,x)` | `JMPIdxIndir` |
| 128 | `jmp (.LJTI3_0,x)` | `JMPIdxIndir` |
| 129 | `lda .LJTI4_0,x` + `lda .LJTI4_0+256,x` + `jmp (__rc2)` | split lo/hi (`MO_HI_JT`) |
| 130 | `lda .LJTI5_0,x` + `lda .LJTI5_0+256,x` + `jmp (__rc2)` | split lo/hi (`MO_HI_JT`) |

**The boundary is exact and inclusive at 128, with no off-by-one.** #152 therefore ships as a
*positive-with-a-negative-result-attached*: the boundary is compiled from both sides in one ROM and
the bug the demo was built to find is **not there**. That is still worth shipping — it is the only
test in the tree that pins the constant, and the split arm's high table lands at a fixed `+256`
offset from the low one regardless of the real entry count, which is itself a measured detail no
prior demo records.

### The by-value ABI boundary — `getTypeSize(Ty) > 32`, CONFIRMED, but "33 bits" does not exist

`vendor/llvm-mos/clang/lib/CodeGen/Targets/MOS.cpp`, `classifyArgumentType`:

```cpp
    if (getRecordArgABI(Ty, getCXXABI()) == CGCXXABI::RAA_DirectInMemory ||
        getContext().getTypeSize(Ty) > 32)
      return getNaturalAlignIndirect(Ty, /*AddrSpace=*/0, /*ByVal=*/false);
    ...
    return ABIArgInfo::getDirect();
```

`getTypeSize` is in **bits**, and on MOS every scalar has ABI alignment 1, so a record's size is
always a whole number of bytes × 8. **There is no 33-bit size class**: a record declaring 33 bits of
bitfield has `sizeof == 5` and therefore `getTypeSize == 40`. The real boundary is between
`sizeof == 4` (32 bits, `getDirect`) and `sizeof == 5` (40 bits, `getNaturalAlignIndirect`), and the
brief's "32, 33 and 40 bits" collapses to two classes, not three.

Probe (`-S -emit-llvm`, `-Os`):

```
define dso_local i16 @f32(i16 %0, i16 %1)                                  ; 4 bytes -> getDirect
define dso_local i16 @f33(ptr noundef readonly captures(none) dead_on_return %0)  ; 33 declared bits -> sizeof 5 -> indirect
define dso_local i16 @f40(ptr noundef readonly captures(none) dead_on_return %0)  ; 5 bytes -> indirect
define dso_local i16 @f64(ptr noundef readonly captures(none) dead_on_return %0)  ; 8 bytes -> indirect
```

The demo keeps all three record shapes anyway — the 33-bit-declared one is what *demonstrates* the
collapse, and it is a genuinely different record (a bitfield record at the boundary, which nothing
in the tree passes by value). #154 ships with that correction recorded rather than claiming a
three-way boundary that the target does not have.

### #151 nested VLAs — the nesting only forms under a specific source shape

`G_DYN_STACKALLOC` is #143 `vlastack`'s corner; the *depth* axis is new. Measured, a naive nesting
does **not** produce two brackets:

| source shape | `G_DYN_STACKALLOC` | `G_STACKSAVE` | `G_STACKRESTORE` |
|---|---|---|---|
| function-scope VLA + inner-block VLA | 2 | 1 | 1 |
| explicit outer block + nested block, both once per call | 2 | 1 | 1 |
| **both blocks inside a driving loop** | **2** | **2** | **2** |

The first two collapse because the outer block's restore coincides with the function's return and is
elided. Only when both VLA scopes are re-entered per loop iteration does the outer
`stacksave`/`stackrestore` survive as a real bracket around the inner one. #151 is written to that
shape deliberately, and the measurement is recorded so the next person does not write the obvious
version and conclude the corner is unreachable.

### #153 sparse switch — the third strategy exists and is reachable

Probe: a 12-case switch on a `uint16_t` with keys spread over 0…55555 emits **zero** `.LJTI`
references and a signed-comparison narrowing tree (`cmp #57`/`sbc #5` → 1337, then `cpy #100` → 100,
then `cpx #156`/`cpy #64` → 40000 = `$9C40`), i.e. a genuine binary-search compare tree over 16-bit
keys. Confirmed reachable, `-verify-machineinstrs` clean.

### #155 overflow matrix — all six generic opcodes are reachable, but constants fold them away

Probe with one constant operand per builtin formed `G_UADDO=2 G_SADDO=2 G_UMULO=2 G_SMULO=2
G_USUBO=1 G_SSUBO=0` — i.e. **folding erases cells**, and a demo written with literal operands would
quietly cover less than it claims. #155 therefore drives **both** operands of every cell from runtime
state, and the gate asserts every one of the 18 (builtin × width × signedness) cells fires **both**
outcomes (overflow and clean) at least once.

---

## The bar

Unchanged from Clusters A and B, and **not weakened for any of the five**:

1. Shared host+target logic header in `examples/65816/<name>.h` — explicit `<stdint.h>` widths.
2. A corpus slice `examples/snes/corpus/<name>_sim.c` + a host oracle `tools/<name>-sim.c`, with an
   `expected.tsv` row carrying the host-computed CRC.
3. **`host == default == +mos-a16 == +mos-xy16`** on **MAME and bsnes-jg**, `-verify-machineinstrs`
   clean in all three modes (`dev/run.sh corpus-a16`).
4. A `snesgfx` visual ROM + a `dev/<name>.{sh,lua}` driver with a **structure gate** asserting the
   intended codegen shape actually reached the ROM.
5. `dev/run.sh` usage text + `Taskfile.yml` `<name>` / `<name>-play` wiring.

**If a demo finds a real bug:** write the investigation, commit the demo **un-gated**, report it.
Never weaken the gate. **If a claimed shape turns out not to exist:** reframe honestly as Cluster B
did for #148/#149 — never force a positive claim.

---

## #151 `vlanest` — the nested soft-SP unwind

*Escalated path:* `G_DYN_STACKALLOC` (`MOSLegalizerInfo.cpp:456` `.custom()`) plus **two** nested
`G_STACKSAVE`/`G_STACKRESTORE` brackets. #143 `vlastack` covers one bracket at one depth.

*Mechanism:* a per-row triangular reduction. For each row the driver enters a block holding a VLA
`a[n]` whose length comes from the data; inside that block, for each element, it enters a **second**
block holding a VLA `b[k]` whose length is derived from `a[i]` — so the inner allocation's size is
not merely runtime, it *depends on the outer allocation's contents*. Both blocks live inside the
driving loop, which is what keeps the outer bracket alive (see measurements).

*What a broken unwind looks like:* if the inner restore overshoots, the outer VLA's storage is
released early and the next inner allocation reuses it. That is silent — no crash, no verifier
complaint. The demo therefore **re-reads the outer VLA after every inner block closes** and folds
both the re-read and a per-row checksum recomputed from `a[]` *after* all inner blocks of that row.

*Differential:* integer-exact. The CRC folds the per-row reduction, every outer re-read, the inner
lengths actually used, and the row checksums. **Pointer values are never folded** — the relative
placement of two VLAs is not specified by C and host and target need not agree.

*Structure gate:* per mode, `G_DYN_STACKALLOC == 2`, `G_STACKSAVE == 2`, `G_STACKRESTORE == 2`
pre-legalizer (a collapse to 1 save/restore means the nesting folded away and the demo covers
nothing new); plus runtime cross-checks that ≥ 3 distinct inner lengths and ≥ 3 distinct outer
lengths occurred and that every outer re-read matched.

## #152 `jtedge` — the 127/128/129 jump-table boundary in one ROM

*Escalated path:* both arms of `legalizeBrJt` and the exact `Table.MBBs.size() <= 128` test.
#142 `jt256` sits at 256 — deep past the boundary, never at it.

*Mechanism:* three `noinline` dispatch functions over the **same** sixteen handler families, with
**127**, **128** and **129** distinct successors. Every arm carries the case value as its own
immediate, so no two arms merge and the emitted table has exactly one entry per case (verified in
the structure gate, not assumed). The gate feeds the *same* opcode stream — restricted to `0…126`,
in range for all three — to all three dispatchers over the same VM state, so **all three must
produce identical results**. A boundary off-by-one that mis-indexed either arm moves one of the
three and diverges the CRC.

*Differential:* integer-exact; folds all three dispatchers' final VM states plus an explicit
three-way agreement flag.

*Structure gate:* per mode, `d127` and `d128` each contain `jmp (.LJTI…,x)` and **zero**
`lda .LJTI`; `d129` contains `lda .LJTI…,x` **and** `lda .LJTI…+256,x` (the `MO_HI_JT` half) and
**zero** `jmp (.LJTI`; and each table has the expected entry count.

## #153 `jtsparse` — the third switch-lowering strategy

*Escalated path:* neither `legalizeBrJt` arm — the **binary-search compare tree** the optimizer
picks when the case values are too sparse to tabulate. No demo across #1–#152 forces it deliberately.

*Mechanism:* two dispatchers over the **same** sixteen handler bodies. `js_sparse` switches on a
`uint16_t` key with sixteen cases spread over 0…60000; `js_dense` switches on the same handler's
dense index 0…15. Every logical operation is executed through **both**, so they must agree —
strategy 3 is differentially checked against strategy 1 inside one program.

*Differential:* integer-exact; folds both VM states plus the agreement flag, and the miss counts
(both dispatchers take their `default` arm on deliberate non-keys).

*Structure gate:* per mode, `js_sparse` contains **zero** `.LJTI` references and ≥ 8 comparison
branches; `js_dense` contains `jmp (.LJTI…,x)`.

## #154 `byvaledge` — the `> 32`-bit by-value ABI boundary

*Escalated path:* `classifyArgumentType`'s `getTypeSize(Ty) > 32` test, compiled from **both** sides
adjacently. #145 `bigbyval` is 144 bits — far past it; #26 `boids` is 32 bits — at it, but with no
indirect sibling in the same ROM.

*Mechanism:* three record shapes passed by value through stages that each **mutate their own
parameter**: `BvR32` (4 bytes, `getDirect`), `BvR33` (a bitfield record declaring 33 bits →
`sizeof 5`, indirect — the shape that demonstrates the collapse), `BvR40` (5 bytes, indirect). After
every call the driver **re-reads its own original**, which is the only way a missing `ByVal=false`
call-site copy is visible at all.

*Differential:* integer-exact; folds every stage output and every caller re-read, plus a
`bad_byval` counter that must be 0.

*Structure gate:* from `-S -emit-llvm` per mode — the 4-byte stage takes **scalar** parameters and no
`ptr`; the 5-byte stages take `ptr … dead_on_return`. Plus `sizeof` reported by the oracle.

## #155 `ovmatrix` — all three overflow builtins at all three widths, together

*Escalated path:* `G_UADDO`/`G_SADDO` (#44), `G_USUBO`/`G_SSUBO` (#144), `G_UMULO`/`G_SMULO`
(#76/#101) — each tested in isolation, never **all six in one kernel under register pressure**.

*Mechanism:* one `noinline` kernel with 18 cells — {add, sub, mul} × {16, 32, 64} ×
{unsigned, signed} — all fed from runtime state, all live across each other, results and overflow
flags accumulated into one state so no cell can be sunk or folded away.

*Differential:* integer-exact — `__builtin_*_overflow` is fully defined (infinite precision, then
wrap into the result type), so host and target must agree bit-for-bit at every width. The CRC folds
each cell's accumulated result and its overflow/clean counts.

*Structure gate:* per mode, all six generic opcodes present pre-legalizer; plus a runtime assertion
that **every one of the 18 cells fires both outcomes** at least once (the check that stops a folded
or one-sided cell passing as coverage).

---

## Files

Per demo `<n>`: `examples/65816/<n>.h`, `examples/snes/corpus/<n>_sim.c`, `tools/<n>-sim.c`,
`examples/snes/<n>.c`, `dev/<n>.sh`, `dev/<n>.lua`; plus one row in
`examples/snes/corpus/expected.tsv`, a usage block in `dev/run.sh`, and `<n>` / `<n>-play` tasks in
`Taskfile.yml`. Doc changes: this plan, the Cluster C results in the ideas doc's `# Round 8`
section, and the `TODO.md` battery entry.

## Verification

Run exactly these, in order, and paste raw output under each.

1. `dev/run.sh corpus` — the default-8-bit corpus (baseline **75/75** + the 5 new slices).
2. `dev/run.sh corpus-a16` — the 5-way differential (baseline **74/74** + the 5 new slices).
3. `dev/run.sh build` — the SNES example build sweep (baseline **279**).
4. `dev/run.sh vlanest` — #151 driver: structure gate + both emulators.
5. `dev/run.sh jtedge` — #152 driver: structure gate + both emulators.
6. `dev/run.sh jtsparse` — #153 driver: structure gate + both emulators.
7. `dev/run.sh byvaledge` — #154 driver: structure gate + both emulators.
8. `dev/run.sh ovmatrix` — #155 driver: structure gate + both emulators.
9. `dev/title-charset.sh` — every new title string is renderable in the generated fonts.

Visible surface: per this repo's precedent for SNES ROMs (Clusters A and B, Round 6 Cluster G), the
visual evidence is the **two-emulator screenshot pair** each driver leaves in
`build/<name>-{mame,jg}.png`, not an HTML mockup.

---

## Results (2026‑09‑16) — Cluster C shipped, five green demos, and **a real compiler bug**

All five build and gate. `host == default == +mos-a16 == +mos-xy16` on MAME **and** bsnes-jg,
`-verify-machineinstrs` clean in all three modes, each with a structure gate proving the intended
shape reached the ROM. Unlike Clusters A and B, **this cluster found a compiler defect** — and it is
not a fork regression: it reproduces on pristine upstream `llc`.

| Demo | Gate CRC | 5-way | Structure gate |
|---|---|---|---|
| **#151 `vlanest`** | `0x153B` | ✅ host == default == a16 == xy16, MAME + bsnes-jg | `G_DYN_STACKALLOC=2 G_STACKSAVE=2 G_STACKRESTORE=2` — all three modes; 13 distinct outer lengths, 12 distinct inner, 253 inner brackets, `reread_bad=0` |
| **#152 `jtedge`** | `0xC199` | ✅ | `je_d127`/`je_d128` = `JMPIdxIndir`, `je_d129` = split lo/hi — all three modes; tables 127 / 128 / 512 entries; `disagreements=0`, `default_arm_hits=0` |
| **#153 `jtsparse`** | `0xA131` | ✅ | `js_sparse` `.LJTI=0` with 59/30/30 compares, `js_dense` `jmp (.LJTI,x)=1` — all three modes; `disagreements=0`, `dense_misses=sparse_misses=76` |
| **#154 `byvaledge`** | `0x4FAB` | ✅ | `bv_stage32` direct-scalar, no pointer; `bv_stage33`/`bv_stage40` `ptr … dead_on_return` — all three modes; `byval_violations=0` over 96 steps × 3 shapes |
| **#155 `ovmatrix`** | `0xD4D0` | ✅ | `G_UADDO=3 G_SADDO=3 G_USUBO=3 G_SSUBO=3 G_UMULO=3 G_SMULO=3` — all three modes; **18/18** cells fired both outcomes |

### The bug #154 found

`ran out of registers during register allocation` — a hard **error**, not a miscompile, on twelve
lines of C with one pointer, one call, and three stores of which one is byte-width. Reproduced on
**pristine upstream `llc`** with the **pristine MOS datalayout** at `-mcpu=mos6502`, `-O1` and above;
clean at `-O0`. Write-up, ingredient table, and minimal repro:
[`docs/investigations/2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md`](../investigations/2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md).
No backend fix was attempted during this September 16 demo pass. `#154` ships **gated**: the offending
libcall was moved out of the 5-byte stage (it is not the corner under test), and nothing about the
`ByVal=false` check, the caller re-read, or the `-verify` requirement was relaxed.

**September 22 follow-up:** patch 0029 fixes the two-address rescheduling
constraint. The MOS suites pass 131 tests with one unsupported; a separate
assertion-enabled build passes 231 focused X86/ARM/AArch64 tests and both new MOS
regressions, with no skips. [Validation and coverage](../pr-preparations/2026-09-22/0029-validation.md).
Final submission review and publication remain.

### 1. `dev/run.sh corpus`

```
==> corpus: 80/80 passed
EXIT=0
  vlanest_sim   PASS  corpus_result=0x153B
  jtedge_sim    PASS  corpus_result=0xC199
  jtsparse_sim  PASS  corpus_result=0xA131
  byvaledge_sim PASS  corpus_result=0x4FAB
  ovmatrix_sim  PASS  corpus_result=0xD4D0
```

**PASS.** Baseline 75/75 + the 5 new slices.

### 2. `dev/run.sh corpus-a16`

```
==> corpus-a16: 79/79 passed, 0 xfail
EXIT=0
  vlanest_sim   PASS   corpus_result=0x153B
  jtedge_sim    PASS   corpus_result=0xC199
  jtsparse_sim  PASS   corpus_result=0xA131
  byvaledge_sim PASS   corpus_result=0x4FAB
  ovmatrix_sim  PASS   corpus_result=0xD4D0
```

**PASS.** Baseline 74/74 + the 5 new slices, 0 xfail. This is the 5-way leg:
`host == default == +mos-a16 == +mos-xy16` on MAME **and** bsnes-jg, `-verify-machineinstrs` clean.

### 3. `dev/run.sh build`

```
==> built 289 program(s)
==> not programs, excluded by contract (3): snes-video-codec snes-video-dma snes-video-stream
EXIT=0
    vlanest                  32768 bytes
    jtedge                   32768 bytes
    jtsparse                 32768 bytes
    byvaledge                32768 bytes
    ovmatrix                 32768 bytes
```

**PASS.** Baseline 279 + 5 visual ROMs + 5 corpus slices = 289. All five ROMs fit the plain 32 KB
LoROM near window — no far-platform contract needed for any of them.

### 4. `dev/run.sh vlanest`

```
==> host oracle: vlanest gate hash = 0x153B
    vlanest rows=24 inner_brackets=253 inner_total=2017 reread_bad=0 acc=51024
==> built build/vlanest.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (2 nested G_STACKSAVE/RESTORE brackets over 2 G_DYN_STACKALLOC; all modes)
    PASS  default: G_DYN_STACKALLOC=2  G_STACKSAVE=2  G_STACKRESTORE=2  (-verify clean)
    PASS  a16: G_DYN_STACKALLOC=2  G_STACKSAVE=2  G_STACKRESTORE=2  (-verify clean)
    PASS  xy16: G_DYN_STACKALLOC=2  G_STACKSAVE=2  G_STACKRESTORE=2  (-verify clean)
    PASS  distinct outer lengths=13  distinct inner lengths=12  inner brackets=253  outer re-read failures=0
==> bsnes-jg: render + assert (build/vlanest-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0x153B (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/vlanest-mame.png)
    SHOT: PASS corpus=0x153B (snapshot at frame 600)

RESULT: PASS — Nested VLA Pyramid on SNES; MAME + bsnes-jg + corpus hash 0x153B host == +mos-a16
```

**PASS.**

### 5. `dev/run.sh jtedge`

```
==> host oracle: jtedge gate hash = 0xC199
    jtedge steps=381 disagreements=0 default_arm_hits=0 plotted=128
==> built build/jtedge.sfc (+mos-a16); corpus_result @ WRAM 0x31
==> structure gate (127/128 take JMP (abs,X); 129 takes the split lo/hi + MO_HI_JT arm)
    PASS  default: je_d127=JMPIdxIndir  je_d128=JMPIdxIndir  je_d129=split-lo/hi  tables=.LJTI1_0:127,.LJTI2_0:128,.LJTI3_0:512  (-verify clean)
    PASS  a16: je_d127=JMPIdxIndir  je_d128=JMPIdxIndir  je_d129=split-lo/hi  tables=.LJTI1_0:127,.LJTI2_0:128,.LJTI3_0:512  (-verify clean)
    PASS  xy16: je_d127=JMPIdxIndir  je_d128=JMPIdxIndir  je_d129=split-lo/hi  tables=.LJTI1_0:127,.LJTI2_0:128,.LJTI3_0:512  (-verify clean)
    PASS  three-way agreement: disagreements=0  default-arm hits=0
    INFO  measured: the boundary is EXACT and INCLUSIVE at 128 — no off-by-one. The split
          arm's high table is addressed at a fixed +256 from the low one whatever the
          real entry count, so it costs a full 512-byte table at 129 entries.
==> bsnes-jg: render + assert (build/jtedge-jg.png, frame 600)
SMOKE: PASS off=0x31 len=2 got=0xC199 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/jtedge-mame.png)
    SHOT: PASS corpus=0xC199 (snapshot at frame 600)

RESULT: PASS — Jump-Table Boundary Sweep on SNES; MAME + bsnes-jg + corpus hash 0xC199 host == +mos-a16
```

**PASS** — and the boundary is exact. The table entry counts are the load-bearing half: 127 and 128
entries take `JMPIdxIndir`, and at 129 the emitted table jumps to **512** `.byte` entries because the
split arm pads both halves to 256 and addresses the high one at a fixed `+256`.

### 6. `dev/run.sh jtsparse`

```
==> host oracle: jtsparse gate hash = 0xA131
    jtsparse steps=384 disagreements=0 dense_misses=76 sparse_misses=76
==> built build/jtsparse.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (js_sparse = compare tree, ZERO .LJTI; js_dense = jump table; all modes)
    PASS  default: js_sparse: LJTI=0 compares=59   js_dense: jmp(.LJTI,x)=1 LJTI=1  (-verify clean)
    PASS  a16: js_sparse: LJTI=0 compares=30   js_dense: jmp(.LJTI,x)=1 LJTI=1  (-verify clean)
    PASS  xy16: js_sparse: LJTI=0 compares=30   js_dense: jmp(.LJTI,x)=1 LJTI=1  (-verify clean)
    PASS  strategy 1 == strategy 3: disagreements=0  default arms taken: dense=76 sparse=76
==> bsnes-jg: render + assert (build/jtsparse-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0xA131 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/jtsparse-mame.png)
    SHOT: PASS corpus=0xA131 (snapshot at frame 600)

RESULT: PASS — Sparse Switch Ladder on SNES; MAME + bsnes-jg + corpus hash 0xA131 host == +mos-a16
```

**PASS.** Worth noting the compare count differs by mode (59 default, 30 under `+mos-a16`/`+mos-xy16`)
— a 16-bit compare needs one instruction where the 8-bit path needs two, so the tree is the same
shape either way. The gate asserts `>= 8`, which is about the *strategy*, not the instruction count.

### 7. `dev/run.sh byvaledge`

```
==> host oracle: byvaledge gate hash = 0x4FAB
    byvaledge steps=96 byval_violations=0
    byvaledge host sizeof BvR32=4 BvR33=8 BvR40=6 (MOS: 4 / 5 / 5)
==> built build/byvaledge.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (4-byte stage = getDirect scalars; 5-byte stages = ptr dead_on_return)
    PASS  default: bv_stage32 direct-scalar=1 indirect=0 | bv_stage33 indirect=1 | bv_stage40 indirect=1  (-verify clean)
    PASS  a16: bv_stage32 direct-scalar=1 indirect=0 | bv_stage33 indirect=1 | bv_stage40 indirect=1  (-verify clean)
    PASS  xy16: bv_stage32 direct-scalar=1 indirect=0 | bv_stage33 indirect=1 | bv_stage40 indirect=1  (-verify clean)
    PASS  caller-visible by-value violations=0 over 96 steps x 3 record shapes
    INFO  there is NO 33-bit size class on MOS: getTypeSize is in BITS and a record is
          always whole bytes, so a 33-bit-declared bitfield record is sizeof 5 (40 bits).
          The boundary this gate pins is sizeof 4 (direct) vs sizeof 5 (indirect).
    INFO  bv_stage40 carries NO libcall on purpose — a call between a byte member and a
          word member of the same pointed-to record hits an OPEN upstream llvm-mos regalloc
          failure. See docs/investigations/
          2026-09-16-mos-regalloc-out-of-registers-mixed-width-pointer-plus-call.md
==> bsnes-jg: render + assert (build/byvaledge-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0x4FAB (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/byvaledge-mame.png)
    SHOT: PASS corpus=0x4FAB (snapshot at frame 600)

RESULT: PASS — By-Value Boundary Trio on SNES; MAME + bsnes-jg + corpus hash 0x4FAB host == +mos-a16
```

**PASS.** The host `sizeof` line (`4 / 8 / 6`) against the target's `4 / 5 / 5` is the measurement that
makes the negative result concrete: `packed`-free layout differences are real on x86‑64 and absent on
MOS, which is exactly why `sizeof` is kept out of the folded CRC.

### 8. `dev/run.sh ovmatrix`

```
==> host oracle: ovmatrix gate hash = 0xD4D0
    ovmatrix steps=96 cells=18 two_sided_cells=18
==> built build/ovmatrix.sfc (+mos-a16); corpus_result @ WRAM 0x31
==> structure gate (all six G_[US]{ADDO,SUBO,MULO} formed, 3 widths each; all three modes)
    PASS  default: G_UADDO=3 G_SADDO=3 G_USUBO=3 G_SSUBO=3 G_UMULO=3 G_SMULO=3  (-verify clean)
    PASS  a16: G_UADDO=3 G_SADDO=3 G_USUBO=3 G_SSUBO=3 G_UMULO=3 G_SMULO=3  (-verify clean)
    PASS  xy16: G_UADDO=3 G_SADDO=3 G_USUBO=3 G_SSUBO=3 G_UMULO=3 G_SMULO=3  (-verify clean)
    PASS  all 18 (builtin, width, signedness) cells fired BOTH overflow and clean
      cell add u16  overflow=37   clean=59
      cell add i16  overflow=46   clean=50
      cell add u32  overflow=40   clean=56
      cell add i32  overflow=49   clean=47
      cell add u64  overflow=45   clean=51
      cell add i64  overflow=40   clean=56
      cell sub u16  overflow=46   clean=50
      cell sub i16  overflow=48   clean=48
      cell sub u32  overflow=49   clean=47
      cell sub i32  overflow=47   clean=49
      cell sub u64  overflow=47   clean=49
      cell sub i64  overflow=55   clean=41
      cell mul u16  overflow=61   clean=35
      cell mul i16  overflow=49   clean=47
      cell mul u32  overflow=67   clean=29
      cell mul i32  overflow=54   clean=42
      cell mul u64  overflow=57   clean=39
      cell mul i64  overflow=59   clean=37
==> bsnes-jg: render + assert (build/ovmatrix-jg.png, frame 600)
SMOKE: PASS off=0x31 len=2 got=0xD4D0 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/ovmatrix-mame.png)
    SHOT: PASS corpus=0xD4D0 (snapshot at frame 600)

RESULT: PASS — Overflow Family Matrix on SNES; MAME + bsnes-jg + corpus hash 0xD4D0 host == +mos-a16
```

**PASS.** Compare the six-opcode census against the design probe's
`G_UADDO=2 G_SADDO=2 G_UMULO=2 G_SMULO=2 G_USUBO=1 G_SSUBO=0`: driving both operands from runtime
state is what turns partial coverage into 3× each, and the per-cell table is what proves neither arm
of any cell was folded flat.

### 9. `dev/title-charset.sh`

```
checked 142 title call sites across 155 demo sources
PASS  every title character has a glyph
EXIT=0
```

**PASS.** 150 → 155 sources, 137 → 142 title call sites: the five new titles are covered.

### Visual evidence

Two-emulator screenshot pairs, per this repo's precedent for SNES ROMs (no HTML mockup):
`build/vlanest-{mame,jg}.png`, `build/jtedge-{mame,jg}.png`, `build/jtsparse-{mame,jg}.png`,
`build/byvaledge-{mame,jg}.png`, `build/ovmatrix-{mame,jg}.png`. Each was asserted against the host
CRC at the moment of capture, so the picture and the number come from the same frame. What they show:

- **`vlanest`** — the pyramid, with a visibly irregular skyline; HUD `R=18 N=0D/K=0C BAD=00`
  (24 rows, 13 distinct outer lengths, 12 distinct inner, zero re-read failures).
- **`jtedge`** — a single-coloured phase portrait. Three traces are drawn, one per dispatcher; only
  the last colour is visible because all three land on exactly the same pixels. `DIS=00 MIS=00`.
- **`jtsparse`** — the sparse key ladder down the left with its irregular gaps, the two dispatchers'
  portraits overlaid on the right as one stroke. `DIS=00 MIS=04C` (76 default-arm hits).
- **`byvaledge`** — three lanes with flat red baselines under each scatter: the baseline is the
  caller's re-read of its own original, and flat *is* the by-value contract. HUD `SZ 4/5/5 BAD=00`
  reports the on-target sizes in the picture.
- **`ovmatrix`** — the 18-cell matrix, every bar two-toned. `2SIDE=12/12` (hex, i.e. 18/18).

### Deviations from the plan

- **#154 `byvaledge` lost a multiply from its 5-byte stage**, because that shape hit the
  **upstream register-allocation defect** the demo itself found. The libcall is not the corner under
  test — the ABI form of the parameter is — so the stage derives its result with shift/add/xor
  instead and the demo ships gated. The gate was not weakened in any other respect, and the defect is
  written up rather than worked around silently.
- **#152 `jtedge`'s premise came back negative and the demo shipped anyway.** The plan predicted the
  boundary was the classic place for an off-by-one; it is exact. Kept, reframed in the same way
  Cluster B kept #148/#149: it is the only test in the tree that pins the constant from both sides,
  and it contributes one new measured fact (the fixed `+256` high-table stride).
- **#154's "32, 33 and 40 bits" collapsed to two size classes**, not three. Recorded in the header,
  the `expected.tsv` row, the gate's own output and the ideas doc; the 33-bit record still ships
  because it is what demonstrates the collapse.
- **#155's operands were redesigned before a line of the demo was written**, on the measurement that
  a single constant operand erases cells and deletes `G_SSUBO` outright.
- **#151's source shape was determined by measurement**, not by the obvious reading of "nested VLAs" —
  two of the three natural spellings produce one bracket, not two.
- **Not done / out of scope:** publishing (explicitly excluded, as for Clusters A and B and Round 6
  Cluster G); a fix for the regalloc defect (needs separate dispatch at a tier that can work in the
  register allocator); Round 8 demos **#156–#160**, which remain drafted for a later cluster.
