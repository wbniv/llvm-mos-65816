# Round 8 Cluster B (#146–#150) — conversion, comparison and layout paths with no demo

> **Scope of this dispatch.** Build and gate **Cluster B only** — demos **#146–#150** from the
> `# Round 8` section of
> [the ideas doc](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md). Cluster A
> (#142–#145) is already built and gated (`eeaa170`,
> [plan](2026-09-16-round8-unentered-backend-paths.md)); this plan follows its shape exactly.
> **Publishing is out of scope**, same rule as Cluster A and Round 6 Cluster G: building + gating
> is the job.

Round 8's question is *"which **branch** of an already-exercised rule has never fired?"* Cluster A
took the four sharpest: a legalizer `else` arm, a `.custom()` with zero occurrences, an overflow
form used nowhere, and the argument half of an ABI helper validated only on returns. Cluster B
takes the next five — **conversion, comparison and layout** paths. They are lower-risk than
A's, and two of them turn out, **on measurement**, to be weaker than the ideas doc predicted. Both
of those measurements are written down below rather than papered over, because a future round that
re-derives them wastes a dispatch.

---

## Pre-build measurements — what is actually there

Every claim below was measured in this tree with
`build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Os`, not inferred.

### #146 `dblbridge` — CONFIRMED, the corner is real

```c
d = (double)f;  d = d*3.0 + 1.0;  g = (float)d;
```
emits, in order: `jsr __extendsfdf2`, `jsr __muldf3`, `jsr __adddf3`, `jsr __truncdfsf2`.
Both conversion symbols exist in `build/install/mos-platform/common/lib/libcrt.a` (1 definition
each) and **zero** corpus slices link either today — #57 `mandel-double` runs a `double` escape
loop *and* a `float` twin but never converts between them (only `__floatunsidf`, integer→double).

### #147 `bsearchviz` — CONFIRMED, the corner is real

`bsearch` is declared in `mos-platform/common/include/stdlib.h:187` and defined in `libc.a`
(2 definitions). A spike emits `ldy #mos16lo(cmp)` / `ldy #mos16hi(cmp)` / `jsr bsearch` — the
comparator travels as a **16-bit function pointer in registers** and the call returns a `void*`
the caller must difference against the base to get an index. Zero uses tree-wide.

### #148 `strcmprace` — CONFIRMED as libcalls; the *inline expansion* half is a NEGATIVE result

`memcmp`/`strcmp`/`strncmp` are all in `libc.a` and used **zero** times tree-wide, so the libcall
half of the ideas-doc claim holds. The **inline small-`memcmp` expansion** half does not:

```
memcmp(a,b,2)        -> jsr memcmp
memcmp(a,b,4) == 0   -> jsr memcmp        (the equality-only form, which is what
memcmp(a,b,8)        -> jsr memcmp         ExpandMemCmp specialises on other targets)
```

**Measured: MOS never inline-expands `memcmp`, at any constant size, including the `== 0` form.**
`TargetTransformInfo::enableMemCmpExpansion` is not overridden for this target. So #148 exercises
three never-linked libcalls and their three-way sign contract — not a second lowering. The plan
says so, the demo's header says so, and the structure gate asserts what is actually there
(three distinct libcall symbols reached) rather than a shape that cannot exist.

### #149 `packrec` — the ideas doc's framing is a NEGATIVE result; the demo is REFRAMED

The ideas doc predicted `__attribute__((packed))` would produce "a decomposed multi-byte access"
distinct from a naturally-aligned one. It cannot, and the reason is structural:

```c
struct P { uint8_t t; uint16_t w; uint32_t d; uint8_t e; };              /* unpacked */
struct __attribute__((packed)) Q { /* same members */ };                /* packed   */
_Static_assert(sizeof(struct P) == 8 && sizeof(struct Q) == 8, "");
_Static_assert(__builtin_offsetof(struct P, w) == 1, "");               /* both */
_Static_assert(__builtin_offsetof(struct Q, w) == 1, "");
_Static_assert(_Alignof(uint32_t) == 1, "");
```
All five assertions **pass**. On MOS every scalar already has ABI alignment 1, so an unpacked
struct has **no padding to remove** and `packed` is a layout no-op. The IR confirms it from the
other side: an ordinary `uint32_t` global is emitted as `@sink = global i32 align 1`, so the
`load i32 … align 1` a packed member produces is not distinguishable from any other load.

**This is the round's second negative result** and it goes in the ideas doc alongside
`G_PTRMASK`/`G_FREEZE`. But #149 is still worth building, with an honest and narrower purpose:
it becomes the tree's **only regression guard for the padding-free-layout invariant**. Zero packed
structs and, more to the point, zero *layout assertions* exist today; if a future backend change
ever raised `_Alignof(uint16_t)` or `_Alignof(uint32_t)` to 2, every binary-record parse in every
program built with this toolchain would silently start reading the wrong bytes, with no
diagnostic. The demo parses a genuine packed record stream at odd byte offsets through computed
pointers and CRCs every field, and its structure gate pins the layout facts. It is **not** claimed
as a distinct lowering.

### #150 `trapguard` — CONFIRMED, with the ideas doc's own honest framing

`MOSLegalizerInfo.cpp:448` sends `G_TRAP` to `.custom()`, and `legalizeTrap` turns it into an
`RTLIB::ABORT` libcall. Measured on a dense state machine with an opaque input:

```
pre-legalizer:  G_TRAP = 1
emitted asm:    jsr abort   (×1)
```

`__builtin_unreachable` alone emits *nothing* (it is an optimizer fact, not an instruction), so
the demo must use `__builtin_trap()` to form `G_TRAP` at all — that is itself a measured detail
worth recording. The probe stays **presence-and-inertness**: the trap cannot be taken in a gate
run, so what is asserted is that it reached the ROM *and* that the surrounding dispatch still
computes the reachable state trace bit-identically in all three modes.

---

## The bar

Unchanged from Cluster A, and **not weakened for any of the five**:

1. Shared host+target logic header in `examples/65816/<name>.h` — explicit `<stdint.h>` widths.
2. A corpus slice `examples/snes/corpus/<name>_sim.c` + a host oracle `tools/<name>-sim.c`, with an
   `expected.tsv` row carrying the host-computed CRC.
3. **`host == default == +mos-a16 == +mos-xy16`** on **MAME and bsnes-jg**, `-verify-machineinstrs`
   clean in all three modes (`dev/run.sh corpus-a16`).
4. A `snesgfx` visual ROM + a `dev/<name>.{sh,lua}` driver with a **structure gate** asserting the
   intended codegen shape actually reached the ROM.
5. `dev/run.sh` usage text + `Taskfile.yml` `<name>` / `<name>-play` wiring.

**If a demo finds a real bug:** write the investigation, commit the demo **un-gated**, report it.
Never weaken the gate. (#118 `retryjmp` precedent.)

### One extra discipline this cluster needs: host float determinism

#146 is the battery's first demo whose differential depends on the **host** and the target agreeing
on IEEE rounding. Two hazards, both handled in the demo rather than hoped away:

- **FMA contraction.** GCC at `-O2` defaults to `-ffp-contract=fast` and will fuse `a*b + c`
  across statements; the MOS target has no FMA, so a contracted host would silently disagree.
  Mitigation is belt **and** braces: every host oracle compile in this cluster passes
  `-ffp-contract=off`, *and* the map is written with each multiply and each add in its **own
  statement** so there is no contractable expression to begin with.
- **Transcendentals.** No `libm` call appears anywhere in the header. The map is built from
  `+ - *` only, all correctly-rounded by IEEE-754, so host and target must agree bit-for-bit.

The CRC folds the **bit patterns** of the demoted `float`s (via a `uint32_t` union), never a
printed or compared decimal.

---

## #146 `dblbridge` — the float↔double promotion pair

*Un-entered path:* `G_FPEXT` S32→S64 / `G_FPTRUNC` S64→S32 (`MOSLegalizerInfo.cpp:375`/`:376`,
`.libcallFor`) → `__extendsfdf2` / `__truncdfsf2`.

*Mechanism:* the same chaotic map iterated twice — once wholly at `float`, once at `double` with
the state **demoted back to `float` and re-promoted every step**. The demotion is the point: it is
a correctly-rounded round trip through binary32 on every iteration, so the two orbits are
identical for a while and then separate, and the step at which they first separate is a
first-class output.

*Genuine, not a toy:* the divergence step is a real numerical-analysis quantity, and it is what a
wrong rounding mode or a fused multiply-add on either side would move.

*Structure gate:* the corpus slice's asm must reference **both** `__extendsfdf2` and
`__truncdfsf2`, in all three modes; and the oracle must report a divergence step that is neither 0
(the orbits must start identical) nor the trace length (they must actually separate) — otherwise
the demo would compile the same code while proving nothing.

*Differential:* CRC folds every demoted `float`'s `uint32_t` bit pattern from both orbits, plus the
divergence step and the per-step disagreement mask.

## #147 `bsearchviz` — the `bsearch` callback ABI

*Un-entered path:* `bsearch` and its three-way comparator, structurally unlike `qsort`'s: the
result drives an interval bisection and the call returns a `void*` **into** the array or `NULL`,
which the caller must difference back into an index.

*Mechanism:* a sorted key table is probed with a fixed query set containing both hits and
deliberate misses; each lookup's returned pointer is converted to an index (or the miss sentinel)
and the whole result vector is folded.

*Structure gate:* `jsr bsearch` must be present in all three modes, the comparator must be reached
through a function pointer (`mos16lo`/`mos16hi` of the comparator materialized into registers, not
inlined), and the query set must produce **both** hits and misses at run time — a query set that
never missed would never exercise the `NULL` return.

*Differential:* CRC folds every found index and every miss sentinel, plus a per-query probe count.

## #148 `strcmprace` — the three never-linked comparison libcalls

*Un-entered path:* `memcmp` / `strcmp` / `strncmp`, zero uses tree-wide. (The inline-expansion half
is a measured negative — see above.)

*Mechanism:* a set of string lanes merged under a real lexicographic order, with each comparison's
resolving byte position recorded. All three functions are used for what each is actually for:
`memcmp` over fixed-width keys, `strcmp` over NUL-terminated ones, `strncmp` over a bounded prefix.

*Structure gate:* all three symbols must be referenced in all three modes; and the run must
produce all three comparison signs (negative, zero, positive) for each of the three functions —
a lane set that only ever compared one way would leave two thirds of the contract untested.

*Differential:* CRC folds the **sign** of every comparison (`-1`/`0`/`+1`, never the magnitude,
which is implementation-defined), the resolving byte positions, and the final merged ordering.

## #149 `packrec` — the packed-record layout invariant

*Reframed corner (see the measurement above):* not a distinct lowering — on MOS `packed` is a
layout no-op because every scalar already has alignment 1. What the demo guards is the
**invariant** that makes binary-record parsing work at all on this target: zero padding, members
at their exact byte offsets, and wide members readable through computed pointers at odd
displacements.

*Mechanism:* a packed binary record stream (mixed `uint8`/`uint16`/`uint32` fields, deliberately
landing the wide ones at odd offsets) parsed live out of a byte blob through a computed record
pointer, with every field folded.

*Structure gate:* a compile-time layout assertion block (`_Static_assert` on `sizeof` and every
`__builtin_offsetof`, packed **and** unpacked, asserting they agree) must compile in all three
modes; and the parsed wide fields must reach the ROM as byte-wise accesses at the odd
displacements, not a single aligned load of a padded struct.

*Differential:* integer-exact; CRC folds every parsed field of every record.

## #150 `trapguard` — the untaken `G_TRAP`

*Un-entered path:* `G_TRAP` `.custom()` (`MOSLegalizerInfo.cpp:448` → `RTLIB::ABORT`).

*Mechanism:* a dense `(state, event)` state machine whose transition switch covers every legal
pair and whose `default:` arm is `__builtin_trap()`. The event stream is generated so that the
impossible pairs genuinely never occur, but the compiler cannot prove it (the events come through
a `volatile`-seeded generator), so the trap survives to the ROM.

*Honest framing:* this is a **presence-and-inertness** probe, weaker than #142–#145. The
interesting property is that the trap's presence does not perturb the surrounding block's codegen
or flag liveness — not that it is ever taken.

*Structure gate:* `G_TRAP` must be formed pre-legalizer (≥ 1) and `jsr abort` must be present in
the emitted asm, in all three modes; and the reachable state trace must visit **every** legal
(state, event) pair at least once, so the dispatch around the trap is fully exercised.

*Differential:* CRC folds the reachable state trace and the per-state visit counts.

---

## Files

Per demo `<n>`: `examples/65816/<n>.h`, `examples/snes/corpus/<n>_sim.c`, `tools/<n>-sim.c`,
`examples/snes/<n>.c`, `dev/<n>.sh`, `dev/<n>.lua`; plus one row in
`examples/snes/corpus/expected.tsv`, a usage block in `dev/run.sh`, and `<n>` / `<n>-play` tasks in
`Taskfile.yml`. Doc changes: this plan, the Cluster B results in the ideas doc's `# Round 8`
section (including the two negative results), and the `TODO.md` battery entry.

---

## Verification

Run exactly these, in order, and paste raw output under each.

1. `dev/run.sh corpus` — the default-8-bit corpus (baseline **70/70** + the 5 new slices).
2. `dev/run.sh corpus-a16` — the 5-way differential (baseline **69/69** + the 5 new slices).
3. `dev/run.sh build` — the SNES example build sweep (baseline **269**).
4. `dev/run.sh dblbridge` — #146 driver: structure gate + both emulators.
5. `dev/run.sh bsearchviz` — #147 driver: structure gate + both emulators.
6. `dev/run.sh strcmprace` — #148 driver: structure gate + both emulators.
7. `dev/run.sh packrec` — #149 driver: structure gate + both emulators.
8. `dev/run.sh trapguard` — #150 driver: structure gate + both emulators.
9. `dev/title-charset.sh` — every new title string is renderable in the generated fonts.

Visible surface: per this repo's precedent for SNES ROMs (Cluster A, Cluster G), the visual
evidence is the **two-emulator screenshot pair** each driver leaves in `build/<name>-{mame,jg}.png`,
not an HTML mockup.

**Process note — do not edit `dev/run.sh` while a long `dev/run.sh` target is running.** The first
`corpus-a16` run of this cluster reported `74/74 passed, 0 xfail` and then printed
`dev/run.sh: line 504: —: command not found` at exit. That is not a defect in anything this cluster
built: `bash` reads a script incrementally from a byte offset, and `dev/run.sh` was edited (the
Cluster B usage block, +60 lines) while that ~50-minute invocation was still executing it, so bash
resumed mid-line in the shifted file and tried to run an em-dash as a command. The run was repeated
on the stable file for the verification evidence below. Worth writing down because on this tree —
where a target can run for an hour and the same files are edited concurrently — it will happen
again and it looks alarming.

## Results (2026‑09‑16) — Cluster B shipped, five green demos, no compiler bug, **two measured negatives**

All five build and gate. `host == default == +mos-a16 == +mos-xy16` on MAME **and** bsnes-jg,
`-verify-machineinstrs` clean in all three modes, each with a structure gate proving the intended
shape reached the ROM. **No compiler bug was found.** The more valuable half of the cluster is the
two corners that turned out **not to be corners on this target** — both predicted by the ideas doc,
both disproved by measurement, both now written down so a later round does not re-derive them.

| Demo | Gate CRC | 5-way | Structure gate |
|---|---|---|---|
| **#146 `dblbridge`** | `0xF829` | ✅ host == default == a16 == xy16, MAME + bsnes-jg | `__extendsfdf2=1`, `__truncdfsf2=1`, `double-arith=3` — all three modes; lanes agree then separate (`div_min=1`, `div_max=4`, of 64 steps) |
| **#147 `bsearchviz`** | `0x7FF5` | ✅ | `jsr bsearch=1`, comparator-address refs=2, `qsort=0` — all three modes; `hits=34 misses=14 bad_index=0` over 266 comparator calls |
| **#148 `strcmprace`** | `0xF0BA` | ✅ | `memcmp=1 strcmp=1 strncmp=1` — all three modes; **all 9 (function, sign) cells fire** over 252 comparisons |
| **#149 `packrec`** | `0x4676` | ✅ | layout `_Static_assert` block compiles in all three modes; `pk_parse_at` present, 145–167 loads (not const-folded); `A=31 B=24 odd_wide_reads=90` |
| **#150 `trapguard`** | `0x2C2D` | ✅ | `G_TRAP=1` pre-legalizer **and** `jsr abort=1` emitted — all three modes; every legal (state, event) pair fired, `illegal_taken=0` |

### 1. `dev/run.sh corpus`

```
==> corpus: 75/75 passed
EXIT=0
  dblbridge_sim  PASS  corpus_result=0xF829
  bsearchviz_sim PASS  corpus_result=0x7FF5
  strcmprace_sim PASS  corpus_result=0xF0BA
  packrec_sim    PASS  corpus_result=0x4676
  trapguard_sim  PASS  corpus_result=0x2C2D
```

**PASS** — 70 baseline + 5 new = 75/75, no regression.

### 2. `dev/run.sh corpus-a16`

```
==> corpus-a16: 74/74 passed, 0 xfail
EXIT=0
  dblbridge_sim  PASS   corpus_result=0xF829
  bsearchviz_sim PASS   corpus_result=0x7FF5
  strcmprace_sim PASS   corpus_result=0xF0BA
  packrec_sim    PASS   corpus_result=0x4676
  trapguard_sim  PASS   corpus_result=0x2C2D
```

**PASS** — 69 baseline + 5 new = 74/74, 0 xfail. This is the leg that carries the real bar:
`host == default == +mos-a16 == +mos-xy16` on MAME **and** bsnes-jg, `-verify-machineinstrs` clean
in all three modes. #146 passing here is the sharper result of the two — it means the SNES soft-float
`__extendsfdf2` / `__truncdfsf2` round trip is **bit-identical to glibc/x86‑64**, on 384 promotions
and 384 demotions of a chaotic orbit, in every mode.

### 3. `dev/run.sh build`

```
==> built 279 program(s)
EXIT=0
```

**PASS** — 269 baseline + 5 corpus slices + 5 visual ROMs = 279.

### 4. `dev/run.sh dblbridge`

```
==> host oracle: dblbridge gate hash = 0xF829
    dblbridge orbits=6 steps=64 promotions=384 div_min=1 div_max=4
==> built build/dblbridge.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (__extendsfdf2 + __truncdfsf2 referenced; all three modes)
    PASS  default: __extendsfdf2=1  __truncdfsf2=1  double-arith=3  (-verify clean)
    PASS  a16: __extendsfdf2=1  __truncdfsf2=1  double-arith=3  (-verify clean)
    PASS  xy16: __extendsfdf2=1  __truncdfsf2=1  double-arith=3  (-verify clean)
    PASS  precision instrument live: lanes agree then separate (div_min=1, div_max=4, steps=64)
==> bsnes-jg: render + assert (build/dblbridge-jg.png, frame 2200)
SMOKE: PASS off=0x13E7 len=2 got=0xF829 (ran 2200 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/dblbridge-mame.png)
    SHOT: PASS corpus=0xF829 (snapshot at frame 2200)
RESULT: PASS — Precision Bridge on SNES; MAME + bsnes-jg + corpus hash 0xF829 host == +mos-a16
EXIT=0
```

**PASS**, on the second run. The first run's structure gate passed but both emulators read
`corpus_result = 0x0000` at the battery's usual frame 600 — **not** a defect, just the frame budget:
384 double-precision steps, each `__extendsfdf2 + __subdf3 + __muldf3 + __muldf3 + __truncdfsf2` in
soft float on a 3.58 MHz 65816, on top of the float twin, are simply not finished by then. Raised to
2200 frames / `-seconds_to_run 45`, which is the budget #57 `mandel-double` already needs for exactly
this reason. The headless 5-way gate on the same code had already passed (it settles 1000 frames).

`div_min=1` and `div_max=4` are the assertion that matters beyond the libcalls being present: the two
lanes are provably identical at the seed and provably separate well before the trace ends, so the
demo is a live precision instrument rather than two copies of the same computation.

### 5. `dev/run.sh bsearchviz`

```
==> host oracle: bsearchviz gate hash = 0x7FF5
    bsearchviz keys=64 queries=48 hits=34 misses=14 cmp_calls=266 bad_index=0 probe_sig=0xD0E6
==> built build/bsearchviz.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (bsearch called + comparator taken by address; all three modes)
    PASS  default: jsr bsearch=1  comparator-address refs=2  qsort=0  (-verify clean)
    PASS  a16: jsr bsearch=1  comparator-address refs=2  qsort=0  (-verify clean)
    PASS  xy16: jsr bsearch=1  comparator-address refs=2  qsort=0  (-verify clean)
    PASS  both bsearch arms live and every index re-derives: hits=34 misses=14 bad_index=0 comparator_calls=266
==> bsnes-jg: render + assert (build/bsearchviz-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0x7FF5 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/bsearchviz-mame.png)
    SHOT: PASS corpus=0x7FF5 (snapshot at frame 600)
RESULT: PASS — Bisection Oracle on SNES; MAME + bsnes-jg + corpus hash 0x7FF5 host == +mos-a16
EXIT=0
```

**PASS.** `bad_index=0` is the check that earns its keep: every recovered index was re-derived from
the key table, so the `void*`→index conversion is right rather than merely plausible. 14 of the 48
queries take the `NULL` arm, so the miss path is live too.

### 6. `dev/run.sh strcmprace`

```
==> host oracle: strcmprace gate hash = 0xF0BA
    strcmprace lanes=24 width=12 comparisons=252 uncovered_cells=0
==> built build/strcmprace.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (memcmp + strcmp + strncmp all referenced; all three modes)
    PASS  default: memcmp=1  strcmp=1  strncmp=1  (-verify clean)
    PASS  a16: memcmp=1  strcmp=1  strncmp=1  (-verify clean)
    PASS  xy16: memcmp=1  strcmp=1  strncmp=1  (-verify clean)
    PASS  all 9 (function, sign) cells fire over 252 comparisons:
        strcmp   neg=18 zero=7 pos=131
        strncmp  neg=3 zero=42 pos=3
        memcmp   neg=23 zero=2 pos=23
==> bsnes-jg: render + assert (build/strcmprace-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0xF0BA (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/strcmprace-mame.png)
    SHOT: PASS corpus=0xF0BA (snapshot at frame 600)
RESULT: PASS — Lexicographic Race on SNES; MAME + bsnes-jg + corpus hash 0xF0BA host == +mos-a16
EXIT=0
```

**PASS**, after two corrections during construction, both recorded in the header rather than quietly
fixed:

- The first run had `memcmp zero = 0` out of 46 — the per-lane filler past each terminator is unique,
  so no two *distinct* lanes are ever equal over the full width, and the fixed-width equality arm
  would have gone untested while the other two were exercised. Fixed by adding one deliberate
  byte-for-byte duplicate lane.
- That alone did **not** fix it: the second pass compares only *adjacent* pairs of the sorted order,
  the sort is by `strcmp`, several lanes share a string, and a stable sort left the two identical
  records non-adjacent. Fixed by comparing the duplicate pair explicitly, in both directions.

### 7. `dev/run.sh packrec`

```
==> host oracle: packrec gate hash = 0x4676
    packrec bytes=480 records=55 shapeA=31 shapeB=24 odd_wide_reads=90 check=2384159343
==> built build/packrec.sfc (+mos-a16); corpus_result @ WRAM 0x13e7
==> structure gate (packed layout assertions hold + parse not const-folded; all three modes)
    PASS  default: pk_parse_at present=1  loads=146  direct pk_blob refs=0  (-verify clean)
    PASS  a16: pk_parse_at present=1  loads=167  direct pk_blob refs=0  (-verify clean)
    PASS  xy16: pk_parse_at present=1  loads=145  direct pk_blob refs=13  (-verify clean)
    PASS  both shapes parsed and wide members land at odd offsets: A=31 B=24 odd_wide_reads=90
    INFO  packrec sizeof PkA=10 PkB=7 (packed) / 12 12 (plain)
    INFO  packed is a LAYOUT NO-OP on MOS (every scalar already has alignment 1) — this
          gate guards the padding-free-layout invariant, NOT a distinct lowering.
==> bsnes-jg: render + assert (build/packrec-jg.png, frame 600)
SMOKE: PASS off=0x13E7 len=2 got=0x4676 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/packrec-mame.png)
    SHOT: PASS corpus=0x4676 (snapshot at frame 600)
RESULT: PASS — Unaligned Record Reader on SNES; MAME + bsnes-jg + corpus hash 0x4676 host == +mos-a16
EXIT=0
```

**PASS**, with the honest reframing intact in the gate's own output. The `INFO` line reporting
`sizeof PkA=10 PkB=7 (packed) / 12 12 (plain)` is worth reading twice: those *plain* numbers are the
**host's**, where `packed` really does remove padding. On MOS the same two structs are 10 and 7 either
way. That contrast is the negative result, printed by the gate every run rather than buried in a doc.

One incidental observation the gate surfaced: `+mos-xy16` emits 13 direct `pk_blob` references where
the other two modes emit 0 (145 vs 146/167 loads) — a real codegen difference in how the computed
record pointer is addressed. The CRC is identical in all three modes, so it is benign; noted because
this gate is now the thing that would catch it changing.

### 8. `dev/run.sh trapguard`

```
==> host oracle: trapguard gate hash = 0x2C2D
    trapguard ticks=480 trace=256 guarded=60 legal_unvisited=0 illegal_taken=0 acc=0x341B
==> built build/trapguard.sfc (+mos-a16); corpus_result @ WRAM 0x5b
==> structure gate (G_TRAP formed + jsr abort in the ROM; all three modes)
    PASS  default: G_TRAP=1 (pre-legalizer)  jsr abort=1 (emitted)  (-verify clean)
    PASS  a16: G_TRAP=1 (pre-legalizer)  jsr abort=1 (emitted)  (-verify clean)
    PASS  xy16: G_TRAP=1 (pre-legalizer)  jsr abort=1 (emitted)  (-verify clean)
    PASS  every legal (state, event) pair fired, no impossible pair did: unvisited=0 illegal=0 guarded_rerolls=60
    NOTE  presence-and-inertness probe: the trap is NEVER taken in a gate run (it
          terminates), so this asserts it is PRESENT and that its presence leaves the
          surrounding dispatch bit-identical — weaker than #142-#145, stated as such.
==> bsnes-jg: render + assert (build/trapguard-jg.png, frame 600)
SMOKE: PASS off=0x5B len=2 got=0x2C2D (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/trapguard-mame.png)
    SHOT: PASS corpus=0x2C2D (snapshot at frame 600)
RESULT: PASS — Unreachable Sentinel on SNES; MAME + bsnes-jg + corpus hash 0x2C2D host == +mos-a16
EXIT=0
```

**PASS**, after one real obstacle that is itself a finding. The first `corpus` run failed to *link*:

```
ld.lld: error: undefined symbol: __putchar
>>> referenced by ld-temp.o
>>>               build/trapguard_sim.sfc.lto.o:(raise)
```

`G_TRAP` → `abort` → `raise` → the default `SIGABRT` handler → stdio. `__putchar` is the SDK's
per-platform character hook and `platforms/snes` has no console, so it is never defined — which means
**the first `__builtin_trap()` in any SNES program is a link error** until the program supplies the
hook. That is not a workaround for this demo; it is the cost of `G_TRAP` on this platform, and it is
why nothing across #1–#141 could have linked one by accident. The header supplies a side-effect-free
but non-removable stub (a store through a volatile sink) and documents why.

Also measured while building this: `__builtin_unreachable()` alone emits **nothing** and cannot form
`G_TRAP` at all. A demo written around it, as the ideas doc's wording invited, would have compiled
cleanly and covered zero.

### 9. `dev/title-charset.sh`

```
checked 137 title call sites across 150 demo sources
PASS  every title character has a glyph
```

**PASS.**

### Visual evidence

Two-emulator screenshot pairs, per this repo's precedent for SNES ROMs (no HTML mockup):
`build/dblbridge-{mame,jg}.png`, `build/bsearchviz-{mame,jg}.png`, `build/strcmprace-{mame,jg}.png`,
`build/packrec-{mame,jg}.png`, `build/trapguard-{mame,jg}.png`. Each was asserted against the host
CRC at the moment of capture, so the picture and the number come from the same frame.

### Deviations from the plan

- **#149 `packrec` was reframed before a line of it was written**, on measurement — see
  §Pre-build measurements. The plan as drafted already carries the reframing; it is listed here
  because the *ideas doc* still predicted a distinct lowering, and that prediction is wrong.
- **#148 `strcmprace` lost half its claim** the same way: the inline small-`memcmp` expansion does
  not exist on MOS at any constant size. The demo still covers three never-linked libcalls; it no
  longer claims a second lowering.
- **#146 `dblbridge` moved to the far platform.** Measured 5,299 bytes over the plain 32 KB LoROM
  near window — the double soft-float library *and* the float twin, which is intrinsic to running two
  precisions side by side. Takes #57 `mandel-double`'s existing contract (`snes-far-platform` +
  `TITLE_FONT16_FAR` + `mos-a16-only`, 64 KB ROM) plus two local trims: a `const` seed table instead
  of `__floatunsisf`, and an integer sign test on the bit pattern instead of `__ltsf2`/`__gtsf2` in
  the plot scaler. Neither trim changes a single folded value — the CRC was `0xF829` before and after
  both. The visual ROM being `+mos-a16`-only does **not** narrow the differential: the 5-way gate is
  the HAL-free corpus slice, which links no HAL, needs no far pointers, and is compiled and asserted
  in all three modes.
- **#146's frame budget** raised 600 → 2200 (`-seconds_to_run 14` → 45); see step 4.
- **#147 `bsearchviz` narrowed what it folds.** The plan said the driver would compare the probe
  signature across the three target modes. It does not: the C standard says nothing about how
  `bsearch` bisects, glibc and llvm-mos-sdk are separate implementations free to pick different
  midpoints, and implementing a cross-mode runtime comparison would have meant building and running
  three extra ROMs to assert an unspecified property. Replaced with the well-defined check that is
  actually the corner — `bs_verify_indices()` re-derives every recovered index from the key table, so
  a wrong pointer→index conversion fails the gate. The probe trace is still captured for the visual.
- **Not done / out of scope:** publishing (explicitly excluded, as for Cluster A and Cluster G);
  Round 8 demos **#151–#160**, the boundary and width escalations, which remain drafted for a later
  cluster.
