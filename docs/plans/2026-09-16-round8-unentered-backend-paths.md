# Round 8 (#142+) — the un-entered backend paths: cluster A (#142–#145)

> **Scope of this dispatch.** (1) a fresh untested-corner coverage audit over demos **#1–#141**,
> (2) a drafted `# Round 8` section in
> [the ideas doc](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md), and
> (3) **the first cluster only** — 4 demos, built and gated. Not the whole round. Publishing is
> **out of scope** (same rule as Round 6 Cluster G): building + gating is this dispatch's job.

Rounds 1–5 hunted *new* corners; Round 6 re-stressed *fixed* bugs; Round 7 was a targeted
defect-hunting audit. All three are complete (#1–#141). Round 8 takes a fourth angle, and it is the
one the previous three structurally could not reach: **the legalizer rules and ABI paths the
backend genuinely HAS, that no demo has ever made the compiler take.**

The distinction matters. Rounds 2–5 asked "*which opcode has no demo?*" and answered it from the
opcode list. That question is now exhausted — every opcode a plain C program forms has a demo. The
Round 8 question is narrower and sharper: **which *branch* of an already-exercised rule has never
fired?** A legalizer rule with an `if (STI.hasJMPIdxIndir() && Table.MBBs.size() <= 128)` in it has
*two* implementations; 141 demos have taken exactly one of them. An ABI classifier that routes both
returns *and* arguments through `getNaturalAlignIndirect` has been validated on returns only.

Every corner below was **measured in this tree**, not inferred: the audit compiled the existing
corpus slices and counted the actual opcodes/libcalls formed. The measurement commands and their
output are in [§Coverage audit — as measured](#coverage-audit--as-measured).

---

## Coverage audit — as measured

Method: `build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Os` over every
`examples/snes/corpus/*.c`, with `-S` (to count emitted libcalls / jump-table forms) and with
`-mllvm -print-before=legalizer` (to count generic opcodes formed), cross-referenced against
`vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp` and
`vendor/llvm-mos/clang/lib/CodeGen/Targets/MOS.cpp`.

| # | Un-entered path | Backend site | Measured evidence it is un-entered | Demo |
|---|---|---|---|---|
| A | **Split lo/hi jump table** — the `else` arm of `legalizeBrJt`: two `G_LOAD_ABS_IDX` over separate low-byte and high-byte tables (`MO_HI_JT`) feeding `G_BRINDIRECT`, taken only when the switch has **>128** successors (or the subtarget lacks `JMPIdxIndir`) | `MOSLegalizerInfo.cpp:443` `G_BRJT .customIf`, handler `legalizeBrJt` ≈3311, the `<= 128` test ≈3334 | Exactly **5** corpus slices form a jump table at all (`bf_vm_sim`, `cordic_sim`, `duff_sim`, `perlin_sim`, `turtle-vm_sim`) and **all 5** take the `jmp (.LJTI0_0,x)` `JMPIdxIndir` arm. A synthesized 200-case switch takes the other arm (`lda .LJTI0_0,x` + a 512-byte table) — so the arm exists, is reachable, and **no demo reaches it** | **#142** |
| B | **`G_DYN_STACKALLOC`** — a genuinely *runtime*-sized VLA, i.e. a soft-stack SP adjust by a value not known at compile time | `MOSLegalizerInfo.cpp:456` `.custom()` | **Zero** corpus slices form `G_DYN_STACKALLOC`. #68 `polyfill` *has* a VLA (`int16_t xs[nv]`) but `nv` const-folds, so it forms only `G_STACKSAVE`/`G_STACKRESTORE` over a fixed-size alloca — the save/restore pair is covered, the dynamic *allocation* is not | **#143** |
| C | **`G_USUBO` / `G_SSUBO`** — subtract-with-overflow, custom-lowered separately from the add forms | `MOSLegalizerInfo.cpp:296` (rule), `:2031`/`:2034` (custom cases) | `__builtin_sub_overflow` appears **0** times in the tree. `__builtin_add_overflow` appears 7× (#44 `hdr-bloom`) and `__builtin_mul_overflow` 14× (#76 `smulorbit`, #101 `mulov64`). Borrow is not carry and the signed-subtract overflow predicate is not the signed-add one | **#144** |
| D | **Large record passed BY VALUE as an ARGUMENT** — `getNaturalAlignIndirect(…, ByVal=false)` for any aggregate `> 32` bits | `clang/lib/CodeGen/Targets/MOS.cpp:64` `classifyArgumentType`, the `getTypeSize(Ty) > 32` test at `:71` | #91 `matcascade` validated the **return** side of the same helper (`classifyReturnType`, `MOS.cpp:89`). **No demo passes a >32-bit record by value.** `ByVal=false` is the sharp part: the callee is handed a *pointer to the caller's object*, so a callee that mutates its own by-value parameter must copy first — a missed copy silently corrupts the caller's original with no crash | **#145** |
| E | **`G_FPEXT` S32→S64 / `G_FPTRUNC` S64→S32** (`__extendsfdf2` / `__truncdfsf2`) | `MOSLegalizerInfo.cpp:375`/`:376` `.libcallFor` | **Zero** corpus slices link either symbol. #57 `mandel-double` uses `double` but only ever forms `__floatunsidf` (integer→double); nothing in the battery *promotes a float to a double* or *demotes back* | Round 8 candidate |
| F | **`memcmp` / `strcmp` / `strncmp` / `bsearch`** | SDK/compiler-rt + clang's inline `memcmp` expansion | **Zero** uses tree-wide. `strlen` (1×) and `qsort` (15×) are the only string/search libc the battery touches. `bsearch` in particular is a *different* callback ABI from `qsort` — it returns a `void*` **into** the array rather than permuting it | Round 8 candidate |
| G | **`__attribute__((packed))` misaligned wide member** | load/store decomposition | **Zero** packed structs tree-wide. #52 `disbits` covers *bitfields* crossing byte boundaries; nothing covers a naturally-typed `uint32_t` member sitting at an odd offset | Round 8 candidate |
| H | **`G_TRAP` `.custom()`** | `MOSLegalizerInfo.cpp:448` | Zero `__builtin_trap` / `__builtin_unreachable` uses | Round 8 candidate (differential-awkward — see the ideas doc) |
| — | **`G_PTRMASK`** (`:279`), **`G_FREEZE`** (`:460`), **`G_FFREXP`** (`:366`, explicitly "will fail if encountered"), **`G_FCANONICALIZE`** (`:373`) | — | Un-entered, and **measured NOT constructible from plain C**: `__builtin_align_down` const-folds away rather than forming `G_PTRMASK`; `G_FREEZE` is an optimizer artifact, not a source construct. Recorded as un-buildable, **not** proposed as demos | — |

**Honest framing.** A–D are the four this cluster builds, ordered by how sharp the probe is rather
than how pretty the picture is. E–H are real and go in the round's candidate list. The last row is
the round's negative result and is written down so a future round does not re-derive it.

---

## The bar

Unchanged from every prior round, and **not weakened for any of the four**:

1. Shared host+target logic header in `examples/65816/<name>.h` — explicit `<stdint.h>` widths.
2. A corpus slice `examples/snes/corpus/<name>_sim.c` + a host oracle `tools/<name>-sim.c`, with an
   `expected.tsv` row carrying the host-computed CRC.
3. **`host == default == +mos-a16 == +mos-xy16`** on **MAME and bsnes-jg**, `-verify-machineinstrs`
   clean in all three modes (`dev/run.sh corpus-a16`).
4. A `snesgfx` visual ROM + a `dev/<name>.{sh,lua}` driver with a **structure gate** asserting the
   intended codegen shape actually reached the ROM (this is what stops a demo silently
   const-folding into a different, already-covered corner).
5. `dev/run.sh` usage text + `Taskfile.yml` `<name>` / `<name>-play` wiring.

**If a demo finds a real bug:** write the investigation, commit the demo **un-gated** (no
`expected.tsv` row, no driver, no visual ROM), report it. Never weaken the gate. This is the #118
`retryjmp` precedent.

---

## #142 `jt256` — the split lo/hi jump table

*Un-entered path:* `legalizeBrJt`'s `else` arm. A **256-case** opcode dispatch (a 65816 instruction
decoder — every opcode `$00`–`$FF` gets its own `case` returning that opcode's addressing mode,
operand length and cycle count) blows past the `Table.MBBs.size() <= 128` test, so the legalizer
cannot use `JMP (abs,X)` and must instead build **two** parallel byte tables, index each with
`G_LOAD_ABS_IDX`, reassemble a pointer, and `G_BRINDIRECT` through it — with the high table
addressed by a distinct `MO_HI_JT` relocation flavour.

*Why no earlier demo hit it:* the five jump tables that exist in the tree are VM opcode dispatches
of 8–16 cases and a Duff's device of 8. Every one fits in 128, so every one takes the other arm.

*Genuine, not a toy:* the decoder table is real 65816 data (derived from the same opcode matrix
`tools/gen-65816-ref.py` validates against), the switch is genuinely dense, and the demo decodes an
actual byte stream — so a wrong table entry is a wrong disassembly, visible and CRC-divergent, not
an abstract branch.

*Structure gate:* the ROM must contain `lda .LJTI` low/high table loads and **must not** contain
`jmp (.LJTI`, proving the else-arm fired.

*Differential:* integer-exact. The CRC folds the decoded (mode, length, cycles) triple of every
byte in a fixed stream plus the reconstructed instruction boundaries.

## #143 `vlastack` — the runtime-sized VLA

*Un-entered path:* `G_DYN_STACKALLOC` `.custom()` — the soft-stack pointer adjusted by a value the
compiler cannot fold, then restored, **inside a loop** so `G_STACKSAVE`/`G_STACKRESTORE` bracket a
genuinely variable allocation each iteration.

*Why no earlier demo hit it:* #68 `polyfill`'s VLA length is provably constant at its one call
site, so it never reaches the dynamic path (measured: 0 `G_DYN_STACKALLOC` across the whole
corpus). Making it dynamic requires the length to come from data the optimizer cannot see through.

*Genuine, not a toy:* a per-row run-length scanline decoder — each row's temporary scratch array is
exactly as long as that row's run count, which comes from the compressed data. Real algorithm, real
data-dependent size, and the allocation is re-done ~128 times.

*Structure gate:* the `G_DYN_STACKALLOC` must survive to the ROM as an actual soft-SP adjust
(`__rc0`/`__rc1` arithmetic by a computed value), and the alloca must **not** const-fold.

*Differential:* integer-exact; the CRC folds the decoded image plus the per-row allocation sizes.

## #144 `borrowov` — subtract-with-overflow

*Un-entered path:* `G_USUBO` / `G_SSUBO` at `MOSLegalizerInfo.cpp:296`, custom cases `:2031`/`:2034`.

*Why no earlier demo hit it:* `__builtin_add_overflow` (#44) and `__builtin_mul_overflow` (#76,
#101) are both used; `__builtin_sub_overflow` is used **nowhere**. Unsigned subtract-overflow is a
*borrow* out, the inverse sense of the carry the add form tests, and signed subtract-overflow has a
different sign-agreement predicate than signed add.

*Genuine, not a toy:* a bounded-arithmetic simulation — a set of accounts/reservoirs draining into
each other where every transfer is a checked `__builtin_sub_overflow`, and a detected underflow is
a first-class event that changes the simulation (the transfer is rejected and the reservoir
bounces). Both `uint16_t` (borrow) and `int16_t`/`int32_t` (signed) forms in one ROM.

*Structure gate:* the overflow branch must reach the ROM (a `bcc`/`bcs` or `bvc`/`bvs` consuming
the subtract's flags), and no `__sub*o*` libcall may appear where the native form is expected.

*Differential:* the **outcome** (accept/reject count, final reservoir vector) is folded, never a
raw undefined value — `__builtin_sub_overflow` is fully standard-defined on both host and target.

## #145 `bigbyval` — the large by-value struct argument

*Un-entered path:* `clang/lib/CodeGen/Targets/MOS.cpp:71` — any aggregate over 32 bits passed **as
an argument** goes indirect with **`ByVal=false`**, i.e. the callee receives a pointer to the
caller's own object and no copy is made for it.

*Why no earlier demo hit it:* #91 `matcascade` exercised the **return** half of the same helper
(over-32-bit `sret`). #26 `boids` and #60 pass 32-bit records, which sit exactly at or under the
threshold and take `getDirect`. Nothing in the battery passes a bigger record by value.

*Genuine, not a toy:* an affine-transform pipeline. A `Mat3` (9 × `int16_t` = 144 bits) and a
`Vert` batch are passed **by value** through a chain of stages; each stage **mutates its own
parameter** (the C semantics say that is a private copy) before returning a derived record, and the
caller then re-uses its original. That is precisely the shape a missing `ByVal` copy corrupts —
silently, with no crash, and only in the caller.

*Structure gate:* the call must pass a pointer (a frame-index address materialized into the
argument registers), and the caller's original must be re-read **after** the call so the copy is
observable.

*Differential:* integer-exact; the CRC folds every stage's output record **and** the caller's
post-call re-read of its own un-mutated original — the second is what catches the missing copy.

---

## Files

Per demo `<n>`: `examples/65816/<n>.h`, `examples/snes/corpus/<n>_sim.c`, `tools/<n>-sim.c`,
`examples/snes/<n>.c`, `dev/<n>.sh`, `dev/<n>.lua`; plus one row in
`examples/snes/corpus/expected.tsv`, a usage block in `dev/run.sh`, and `<n>` / `<n>-play` tasks in
`Taskfile.yml`. Doc changes: the `# Round 8` section in the ideas doc, this plan, and the `TODO.md`
battery entry.

---

## Verification

Run exactly these, in order, and paste raw output under each.

1. `dev/run.sh corpus` — the default-8-bit corpus (baseline **66/66** + the new slices).
2. `dev/run.sh corpus-a16` — the 5-way differential (baseline **65/65** + the new slices).
3. `dev/run.sh build` — the SNES example build sweep (baseline **261**).
4. `dev/run.sh jt256` — #142 driver: structure gate + both emulators.
5. `dev/run.sh vlastack` — #143 driver: structure gate + both emulators.
6. `dev/run.sh borrowov` — #144 driver: structure gate + both emulators.
7. `dev/run.sh bigbyval` — #145 driver: structure gate + both emulators.
8. `dev/title-charset.sh` — every new title string is renderable in the generated fonts.

Visible surface: per this repo's own precedent for SNES ROMs (see the Cluster G plan), the visual
evidence is the **two-emulator screenshot pair** each driver leaves in
`build/<name>-{mame,jg}.png`, not an HTML mockup.

## Results (2026‑09‑16) — Cluster A shipped, four clean positives, no compiler bug found

All four un-entered paths lower correctly. Each demo's structure gate confirms the intended shape
actually reached the ROM rather than folding into an already-covered corner, so these are genuine
positives rather than vacuous passes.

| Demo | Gate CRC | 5-way | Structure gate |
|---|---|---|---|
| **#142 `jt256`** | `0xB8CC` | ✅ host == default == a16 == xy16, MAME + bsnes-jg | `jt-table-loads=2`, **`jmp (abs,X)=0`**, `indirect-jmp=1`, `table-entries=512`, `handlers_entered=256/256` — all three modes |
| **#143 `vlastack`** | `0xD77B` | ✅ | `G_DYN_STACKALLOC=1`, `G_STACKSAVE=1`, `G_STACKRESTORE=1`, `soft-SP writes=6`, allocation sizes vary `9..15` — all three modes |
| **#144 `borrowov`** | `0x81FB` | ✅ | `G_USUBO=1`, `G_SSUBO=4`, `-verify` clean; overflow predicate fires in **every** width (u16=80, s16=9, s32=9 rejections) — all three modes |
| **#145 `bigbyval`** | `0xBD6B` | ✅ | `BvMat=144 bits`, `BvVert=64 bits` (both > 32 → indirect); `indirect-arg calls=2`, `ptr params=2`, `call-site copies=5`; **54 callee mutations, 0 caller-visible violations** — all three modes |

### 1. `dev/run.sh corpus`

```
==> corpus: 70/70 passed
EXIT=0
  jt256_sim  PASS  corpus_result=0xB8CC
  vlastack_sim PASS  corpus_result=0xD77B
  borrowov_sim PASS  corpus_result=0x81FB
  bigbyval_sim PASS  corpus_result=0xBD6B
```

**PASS** — 66 baseline + 4 new = 70/70, no regression.

### 2. `dev/run.sh corpus-a16`

```
==> corpus-a16: 69/69 passed, 0 xfail
EXIT=0
  jt256_sim  PASS   corpus_result=0xB8CC
  vlastack_sim PASS   corpus_result=0xD77B
  borrowov_sim PASS   corpus_result=0x81FB
  bigbyval_sim PASS   corpus_result=0xBD6B
```

**PASS** — 65 baseline + 4 new = 69/69, 0 xfail. This is the leg that carries the real bar:
`host == default == +mos-a16 == +mos-xy16` on MAME **and** bsnes-jg, `-verify-machineinstrs` clean.

### 3. `dev/run.sh build`

```
==> built 269 program(s)
EXIT=0
```

**PASS** — 261 baseline + 4 corpus slices + 4 visual ROMs = 269.

### 4. `dev/run.sh jt256`

```
==> host oracle: jt256 gate hash = 0xB8CC
==> built build/jt256.sfc (+mos-a16); corpus_result @ WRAM 0x31
==> structure gate (split lo/hi jump table, NOT jmp (abs,X); all three modes)
    PASS  default: jt-table-loads=2  jmp-(abs,X)=0  indirect-jmp=1  table-entries=512
    PASS  a16: jt-table-loads=2  jmp-(abs,X)=0  indirect-jmp=1  table-entries=512
    PASS  xy16: jt-table-loads=2  jmp-(abs,X)=0  indirect-jmp=1  table-entries=512
    PASS  opcode sweep: handlers_entered=256/256
==> bsnes-jg: render + assert (build/jt256-jg.png, frame 600)
SMOKE: PASS off=0x31 len=2 got=0xB8CC (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/jt256-mame.png)
    SHOT: PASS corpus=0xB8CC (snapshot at frame 600)
RESULT: PASS — ISA-256 Bytecode Machine on SNES; MAME + bsnes-jg + corpus hash 0xB8CC host == +mos-a16
EXIT=0
```

**PASS.** The dispatch really does take the arm no prior demo takes: two jump-table loads
(`ldy .LJTI1_0,x` for the low byte, `lda .LJTI1_0+256,x` for the high) feeding `jmp (__rc2)`, over a
512-entry table, with **zero** `jmp (abs,X)` — in every mode. The first time this project has
compiled `legalizeBrJt`'s `else` arm.

### 5. `dev/run.sh vlastack`

```
==> host oracle: vlastack gate hash = 0xD77B
==> built build/vlastack.sfc (+mos-a16); corpus_result @ WRAM 0x31
==> structure gate (G_DYN_STACKALLOC formed + soft-SP adjusted; all three modes)
    PASS  default: G_DYN_STACKALLOC=1  G_STACKSAVE=1  G_STACKRESTORE=1  soft-SP writes=6
    PASS  a16: G_DYN_STACKALLOC=1  G_STACKSAVE=1  G_STACKRESTORE=1  soft-SP writes=6
    PASS  xy16: G_DYN_STACKALLOC=1  G_STACKSAVE=1  G_STACKRESTORE=1  soft-SP writes=6
    PASS  allocation sizes vary: runs_min=9 runs_max=15
==> bsnes-jg: render + assert (build/vlastack-jg.png, frame 600)
SMOKE: PASS off=0x31 len=2 got=0xD77B (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/vlastack-mame.png)
    SHOT: PASS corpus=0xD77B (snapshot at frame 600)
RESULT: PASS — Run-Length Scanline Decoder on SNES; MAME + bsnes-jg + corpus hash 0xD77B host == +mos-a16
EXIT=0
```

**PASS.** The allocation is genuinely dynamic — lengths range 9..15 across the 24 rows, and the
`runs_min != runs_max` assertion is in the gate precisely so a future const-fold turns this into a
failure rather than a silent downgrade to #68 `polyfill`'s already-covered fixed alloca.

### 6. `dev/run.sh borrowov`

```
==> host oracle: borrowov gate hash = 0x81FB
==> built build/borrowov.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (G_USUBO + G_SSUBO formed; all three modes)
    PASS  default: G_USUBO=1  G_SSUBO=4  (-verify clean)
    PASS  a16: G_USUBO=1  G_SSUBO=4  (-verify clean)
    PASS  xy16: G_USUBO=1  G_SSUBO=4  (-verify clean)
    PASS  overflow predicate fires in every width: u16=80 s16=9 s32=9 rejections
==> bsnes-jg: render + assert (build/borrowov-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0x81FB (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/borrowov-mame.png)
    SHOT: PASS corpus=0x81FB (snapshot at frame 600)
RESULT: PASS — Reservoir Ladder on SNES; MAME + bsnes-jg + corpus hash 0x81FB host == +mos-a16
EXIT=0
```

**PASS**, on the second run. The first run reported `FAIL  a width never overflowed:
u16=rej=160 s16=rej=231 s32=rej=231` — a bug in the **gate script**, not the demo: `cut -d/ -f2`
over `u16 acc/rej=160/80` splits on the `/` inside `acc/rej` and returns the accept count. Fixed to
`awk -F/ '{print $NF}'`; the emulator legs had already passed on that run with the same
`0x81FB`. Both arms of all three predicates are taken at run time (80 / 9 / 9 rejections against
240 ticks), which is what makes the compiled overflow branch live rather than dead.

### 7. `dev/run.sh bigbyval`

```
==> host oracle: bigbyval gate hash = 0xBD6B
==> built build/bigbyval.sfc (+mos-a16); corpus_result @ WRAM 0x31
==> threshold gate: PASS  BvMat=144 bits, BvVert=64 bits (both > 32 -> indirect)
==> structure gate (indirect >32-bit arguments + their call-site copies; all three modes)
    PASS  default: indirect-arg calls=2  ptr params=2  call-site copies=5
    PASS  a16: indirect-arg calls=2  ptr params=2  call-site copies=5
    PASS  xy16: indirect-arg calls=2  ptr params=2  call-site copies=5
    PASS  by-value contract: 54 callee mutations, 0 caller-visible violations
==> bsnes-jg: render + assert (build/bigbyval-jg.png, frame 600)
==> MAME (under Xvfb): snapshot + assert (build/bigbyval-mame.png)
    SHOT: PASS corpus=0xBD6B (snapshot at frame 600)
RESULT: PASS — Affine Stage Pipeline on SNES; MAME + bsnes-jg + corpus hash 0xBD6B host == +mos-a16
EXIT=0
```

**PASS.** The IR confirms the path: both callees take `ptr noundef … dead_on_return` parameters
(the `ByVal=false` indirect form) and the call sites emit the copies that give them by-value
semantics. 54 callee mutations of by-value parameters produced **0** caller-visible corruptions —
the by-value contract holds on this ABI.

### 8. `dev/title-charset.sh`

```
checked 132 title call sites across 145 demo sources
PASS  every title character has a glyph
```

**PASS.**

### Visual evidence

Two-emulator screenshot pairs, per this repo's precedent for SNES ROMs (no HTML mockup):
`build/jt256-{mame,jg}.png`, `build/vlastack-{mame,jg}.png`, `build/borrowov-{mame,jg}.png`,
`build/bigbyval-{mame,jg}.png`. Each was asserted against the host CRC at the moment of capture, so
the picture and the number come from the same frame.

### Deviations from the plan

- **#143 `vlastack` was resized** from 96×64 with ≤48 runs/row to **64×24 with ≤16** — the first
  build overflowed the SNES near-`ram` region by 9,513 bytes (`.bss` + `.noinit`). The corner is
  unaffected (the VLA is still runtime-sized and still varies per row, 9..15); only the data volume
  changed. Gate CRC moved `0x5DF6` → `0xD77B` accordingly.
- **#144 `borrowov`'s signed schedule was rewritten** after the first host run showed
  `s16 rej=0, s32 rej=0` — the signed overflow predicate compiled but was never true at run time,
  which would have made the demo a vacuous pass on two of its three widths. Reworked so the signed
  reservoirs are topped up by **subtracting a negative** (opposite-sign operands — the pairing an
  *add* can never overflow on, which is the point of testing the subtract form separately), driving
  both `INT16_MAX` and `INT16_MIN` edges. Gate CRC settled at `0x81FB`.
- **Not done / out of scope:** publishing (explicitly excluded, as for Cluster G); Round 8 demos
  **#146–#160**, which are drafted in the ideas doc for later clusters, not built here.
