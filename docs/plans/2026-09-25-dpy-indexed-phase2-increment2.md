# `[dp],Y` Phase 2 — increment 2: fold a **range-proven runtime index** into `b7`/`97`

**Current build qualification (2026-09-26):** the runtime and code-generation
results below describe the increment-2 build tested here. The later combined
increment-2 plus 0049–0063 baseline rejects `farblit.c` before scheduling on an
absolute byte load. [Retained failure](../defects/mos-farblit-byte-load-legalization.json)
and [carry-validation context](2026-09-26-mos-carry-scheduling.md#8-completed-validation-and-packaging)
identify that separate, unisolated patch interaction; this qualification does
not replace the earlier passing evidence. Update: OpenAI Codex CLI 0.157.1
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort.


**Resume status (2026‑09‑26):** rebased onto committed main `8c19c703`, including
`6065ebec` and the 0043/0046/0047 review revisions. Sections 1–5b below preserve
the inherited design and September 25 evidence; their use of “landed” described
the candidate implementation, not a main-branch merge. Current checks and final
disposition are recorded in §6. The original uncommitted work is preserved in
the named Git stash; the original compiler edits are also preserved in that
stash. Build outputs are session-local and are reconstructed as needed.

**Attribution:** inherited implementation and September 25 results came from the
pre-existing worktree; the original tool/version, exact model/version, and
reasoning effort have not been recovered and are unknown. Resume, source-stack
reconciliation, review, verification and documentation: OpenAI Codex CLI 0.157.0
(`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort, verified from session
`01a0d891-2029-7483-8bd6-2d00806e2f5a` metadata.


**TODO item:** `- [wip T4] **\`[dp],Y\` Phase 2 increment 2 — the general *range-gated* runtime index.**`
**Builds on:** [increment 1](2026-09-25-dpy-indexed-phase2-increment1.md) (constant displacement in
`[1,3]`, landed `2689b74d`..`e1a4adad`) — its design table, files and verification recipe are not
re-derived here. **Measurement / constraints:**
[Phase 1 investigation](../investigations/2026-09-24-dpy-indexed-measurement.md) §4 (blit) and §6
(gating constraints). **Branch:** `wt/321-dpy-indexed-phase2-increment2`, worktree
`/home/will/llvm-mos-65816-dpy-phase2-inc2` (compiler-changing `cp -a` variant).

**Visible surface:** none — a codegen/instruction-selection change. No mockups section.

---

## 1. Scope

Widen `MOSLegalizerInfo::tryFarIndirectIndexedAddressing` so the value placed in `Y` may be a
**runtime** byte offset, not only a constant in `[1,3]`, when its range is *proven* to fit the index
register. The emitted opcode is unchanged for an 8-bit `Y`; a 16-bit `Y` (`+mos-xy16`) needs one new
generic-op/pseudo pair (§3.3). Everything below the pseudo layer already exists.

**Out of scope:** the pre-RA scheduler carry-pressure cliff (its own T4 item — measured around, not
fixed); `bf`/`9f` (`lda/sta long,X`) for a constant/*global* base plus a runtime index — the right
mode for that shape, a separate item, and the reason gate (d) below declines it; loop-invariant
hoisting of the pointer add (NO-GO, [hoist investigation](../investigations/2026-09-25-farptr-hoist-measurement.md)).

## 2. What the customer actually looks like — a correction to the brief

`dev/dpy-shapes/loop.c` is `dst[j] = tab[o + j]` with `uint16_t o`, `uint8_t j`. Its IR is

```
%6 = add i16 %o, (zext i8 %j)          ; unsigned 16-bit, may wrap (no nuw)
%8 = getelementptr i8, ptr addrspace(2) @tab, i32 (zext i16 %6)
```

so the byte offset off `@tab` is a full **16-bit** value, `0..65535`:

- under `+mos-a16` alone (`Y` 8-bit) it is **not provably in range** — no sound gate can fold it;
- under `+mos-xy16` it would fit a 16-bit `Y` (`Y` = the *wrapped* sum `o + j`, base `@tab`) — but
  its base is a global, which gate (d) declines on measured cost; it is `lda long,X`'s customer.

Phase 1's hand-built `blitdpy` (`tab + o` in DP, `j` in `Y`) is a **different program**: it
re-associates `(o + j) mod 2^16` into `o + j` carried into the bank byte, which differs from C whenever
`o + j` wraps (`o ≥ 0xFFC1`; independently found and flagged by the
[hoist investigation §5.2](../investigations/2026-09-25-farptr-hoist-measurement.md)). No fold may do
that, and this one does not: `Y` always holds the offset *value* `Off` exactly as the IR computed it
(`trunc(Off)`), never a re-associated sum (§3.1, pinned by `far_rt_wrap16` and `farblit`'s `rdw16`).
The customer of this increment is the pointer form of the same idiom —
`const FAR uint8_t *src = tab + base; … dst[j] = src[j];` (`dev/dpy-shapes/loopp.c`) — which is also
the IR LSR produces for `tab[(uint32_t)o + j]` and for a `*p++` walk.

## 3. Design

### 3.1 The range proof — known bits on the *scaled* offset

After peeling constant `G_PTR_ADD`s (increment 1's walk), the access's address reaches a node
`V = G_PTR_ADD(Base, Off)` with a **non-constant** `Off` (s32). The range proof is
`GISelValueTracking::getKnownBits(Off).getMaxValue()` — the largest unsigned value `Off` can take given
its known-zero bits. That is exactly Phase 1 §6 constraint 2 ("gate on the *scaled* byte offset"):
`zext i8` → `≤ 255`; `shl (zext i8), 1` (a `uint16_t` element) → `≤ 510`; `zext i16` → `≤ 65535`; a
sign-extended or genuinely 32-bit index has unknown high bits → `≤ 2^32-1` → rejected. The limit is
`255` for an 8-bit `Y`, and `65535` only when `STI.hasIndex16()` (`+mos-xy16`: **`Y`'s width is the `X`
flag**, not `M` — verified in `MOSInstrLogical.td`: the 16-bit-`Y` pseudos are `XLow = 1`, i.e.
bracketed `rep #$10`/`sep #$10`, and `+mos-a16` alone never clears `X`).

Unsigned + no-wrap is what makes this exact: `[dp],Y` computes `(ptr24 + Y) mod 2^24` with carry into
the bank byte (proved on hardware by increment 1's `farbank` gate), and `(ptr32 + Off) mod 2^24` is the
same value whenever `0 ≤ Off ≤ 65535`.

### 3.2 The profitability gate — fold only when the 32-bit add *disappears*

A range proof alone is not a safe gate (governing lesson 2). If `V` has another user that will **not**
fold — a second access whose total offset exceeds the limit, a pointer that escapes, a PHI, a store of
the pointer value — then `V`'s 32-bit add is materialised anyway, and folding *this* access only adds a
`Y` load and extends `Base`'s live range: a regression. The concrete trap is the multi-byte element:
`p[i]` for a far `uint16_t` with `uint8_t i` narrows to two byte loads off `V` and `V + 1`, whose
offsets are `≤ 510` and `≤ 511`.

So the gate is **all-or-nothing per `V`**: walk every non-debug user of `V`, recursing through
constant-offset `G_PTR_ADD`s (`C ≥ 0`), and fold only if every leaf is a generic `G_LOAD`/`G_STORE`
(or `G_ZEXTLOAD`/`G_SEXTLOAD`) that uses the chain as its **address** (not as a stored value), is not
atomic, and whose last byte `C + size − 1` keeps `maxOff + C + size − 1 ≤ limit`. Anything else →
don't fold (increment 1's constant path and then the plain `lda [dp]` path run exactly as today).

The predicate depends only on `V`'s structure, so every access hanging off `V` reaches the same verdict
— the fold is consistent across a multi-byte element. Legalization is bottom-up (increment 1 §4 R1);
a user already rewritten by an earlier fold no longer uses `V` and only ever satisfied the predicate, so
removing it cannot flip the verdict for the rest; a user already rewritten to a *fallback* form is not a
generic mem-op, so the predicate stays false. The `Y` width is decided on the users *still attached* to
`V` (`maxOff + maxEnd ≤ 255` → 8-bit, even under `+mos-xy16`, avoiding the `rep`/`sep #$10` bracket).
A sibling folded earlier has left `V`'s use list, so a later access may legitimately take a *narrower*
`Y` (observed: byte 0 of a `V`/`V + 1` pair takes an 8-bit `Y` after byte 1 folded with a 16-bit one) —
always sufficient, since each access's own displacement is inside its own walk.

The index is `G_TRUNC(Off)` to `s8`/`s16`, plus `G_ADD C` when the access sits at a constant offset
above `V`. The artifact combiner reduces `trunc(zext x)` to `x`, so the common `j` index costs nothing.

**Constraint 4 ("`Y` free or already index-resident")** remains, as in increment 1, a register-allocation
outcome rather than a legalizer predicate — the legalizer cannot see `Y` liveness. The profitability
gate bounds its worst case: the fold always deletes a 32-bit pointer add (≥ 20 B), and the worst RA can
do is `phy`/`ply` + `ldy` (≈ 6 B). A `Y`-contended shape is in the lit test and the measurement to show
it still wins.

**Rejected alternative:** a per-access gate (range proof only). Rejected because of exactly the
split above: with `Off = zext i8` and accesses at `V` and `V + 1` (offsets `≤ 255` and `≤ 256`), byte 0
would fold while byte 1 fails the proof and forces `V` to be materialised anyway — the fold would add
work. The all-users walk is the smallest predicate that makes "the add is gone" true by
construction. Also rejected: splitting a 16-bit offset into `hi<<8` (pointer) + `lo` (`Y`) to reach
`loop.c` under `+mos-a16` — it saves only the low-byte add while keeping the carry chain, for a
non-trivial new lowering.

**The profitability gates, as landed.** The first measurement pass (§5a step 8) showed the range proof
plus (c) is *not* enough — three cost cliffs regressed shapes with `-enable-misched=false` too, so they
are the change's own, not the scheduler's. Each is a further may-fold predicate:

- **(d) the base is a runtime pointer**, not a constant/global/frame address (`matchAbsoluteAddressing`).
  For an absolute base today's add folds the address in as immediates and needs no quad; the fold
  instead materialises a constant quad, which a hot loop hoists and spills: `k_blossom_far`
  `grid_plot` **+57 B**, `k_buddha_far` **+42 B** under `+mos-xy16`. That shape belongs to `long,X`.
- **(e) no call between `V` and any access.** The fold trades `V`'s quad for `Base`'s quad *plus* the
  index, so one more value is live between `V` and its last access; across a call it costs a
  callee-saved byte and can drag in a soft-stack frame: two reads of `p[i]` around a call **+40 B**.
  Only two layouts are analysed (access in `V`'s block; access in a block whose only predecessor is
  `V`'s block — the RMW's conditional store); anything else declines, but only in a function that
  contains a call-like instruction at all (a call-free function passes trivially). Because
  legalization is bottom-up, the not-yet-legalized part of the block is still generic, so "call-like"
  includes ops that *become* libcalls (`G_MUL`/`G_*DIV`/`G_*REM`, variable shifts, float ops,
  `G_MEM*`, intrinsics).
- **(f) several accesses off one `V` need a call-free function.** Each folded access re-reads `Base`;
  when `Base` is spilled (on this target, overwhelmingly call pressure) the allocator reloads the quad
  at every access where today's code reloaded it once for the add: hopalong `grid_plot` with a runtime
  grid pointer **+16 B**. A single access costs at most today's single reload, so it is never gated.

### 3.3 Layers

| layer | 8-bit `Y` (all modes) | 16-bit `Y` (`+mos-xy16` only) — **new** |
|---|---|---|
| generic op | `G_LOAD/STORE_FAR_INDIR_IDX` (inc 1, `s8` index) | `G_LOAD/STORE_FAR_INDIR_IDX16` (`s16` index) |
| pseudo | `LDIndirLongIdx`/`STIndirLongIdx` (`Yc`) | `LDIndirLongYIdx`/`STIndirLongYIdx` (`Yc16`, `XLow = 1`) |
| selection | `selectGeneric` (inc 1) | own arm in `selectXY16`: Imag32 pin; index stays `Imag16` |
| emission | `PseudoInstExpansion` | `MOSAsmPrinter::emitInstruction`: `ldy $idx` + `lda/sta [$addr],y` |

Both map to the existing `LDA/STA_IndirectIndexedLong` MC opcodes — the byte is the same `b7`/`97`; the
`X` flag at run time is what makes `Y` 16-bit.

**The 16-bit-`Y` pseudo is fused, on purpose.** The first version mirrored the near `(zp),Y16` recipe
(`LDYImag16` into a `Yc16` vreg, then an `XLow` access pseudo). Under register pressure the allocator
put a spill reload between the two; the reload is an 8-bit `ldx`/`stx`, `MOSInsertREPSEP` gives it a
`sep #$10`, and `sep #$10` **zeroes `Y`'s high byte** — the access then read the wrong cell (observed
statically in `k_blossom_far`'s `grid_plot` under `+mos-xy16`; §5a shows the runtime consequence).
`LDIndirLongYIdx`/`STIndirLongYIdx` therefore take the index as `Imag16` and `Defs = [Y]`, survive
register allocation and `MOSInsertREPSEP` as one instruction inside one `rep`/`sep #$10` bracket,
and are split into `ldy` + the access only at emission. `Size = 4`.

## 4. Risks

- **R1 — the 16-bit-`Y` hazard.** A 16-bit value in `Y` is destroyed by any intervening `sep #$10`.
  It *did* bite the first (split) version; fixed structurally by the fused pseudo (§3.3), guarded at
  run time by `farblit` step 6 (blossom/buddha far RMW under `+mos-xy16`). **The near `(zp),Y16` path
  (`LDYImag16` + `LDIndirYIdx`, pre-existing, not touched here) has the same split structure** and so
  the same latent exposure; a scan of all 243 `examples/65816` + corpus sources under `+mos-xy16`
  finds no instance today (§5a step 8c), but nothing structural prevents one.
- **R2 — global base.** Declined (gate (d)) after measuring it regress under pressure.
- **R3 — the scheduler cliff** can hide or invert a real win; every measurement runs at `-Os` **and**
  `-Os -mllvm -enable-misched=false`.

## 5. Verification steps

(Steps 2, 4 and 8 were widened, and 10–11 added, during implementation, when the first measurement
pass found the cost cliffs and the 16-bit-`Y` hazard of §3 — before any result below was recorded.)

1. `dev/run.sh toolchain` — incremental rebuild; confirm `build/llvm-mos-install/bin/clang-23` mtime advanced.
2. Lit: extend `llvm/test/CodeGen/MOS/far-indir-indexed.ll` — positive (runtime `u8` index off a runtime
   far pointer, load + store, a loop, a masked `u16` element, a `Y`-contended loop, one access with a
   call in the loop; under `+mos-xy16` a 16-bit index, a `u16` element at a `u8` index, the wrapping
   16-bit `o + j` with `Y` = the wrapped sum) and negative (a global base; a call between accesses;
   several accesses in a function with a call; 16-bit index / `u16`-at-`u8` / out-of-range sibling
   under `+mos-a16`; a sign-extended or 32-bit index; an escaping `V`).
3. `dev/run.sh lit` — the 4-failure baseline unchanged, new tests passing.
4. New differential gate `dev/run.sh farblit` — runtime-indexed far reads **and** stores, 8-bit and
   16-bit `Y`, a far→far copy sharing one `Y`, the 8- and 16-bit wrapping offsets, all crossing a bank
   boundary through `Y`; host == `+mos-a16` == `+mos-a16 +mos-xy16` on MAME + bsnes-jg; asserts
   `b7`/`97` fired; plus the blossom/buddha far RMW built `+mos-xy16` (16-bit `Y` under register
   pressure) against their host goldens.
5. `dev/run.sh farindex` and `dev/run.sh farbank` — increment 1's gates still green.
6. `dev/run.sh corpus` and `dev/run.sh corpus-a16`.
7. `dev/run.sh roundtrip`.
8. Measurement, before (`main`'s toolchain) / after, at `-Os` and `-Os -mllvm -enable-misched=false`,
   `+mos-a16` and `+mos-a16 +mos-xy16`: `dev/dpy-shapes/{loop,loopp,red}.c` and a set of stress shapes
   (RMW, multi-byte element, struct field, across-call, call-in-loop, far `strlen`/`memcmp`/copy, the
   hopalong/buddhabrot grid ops with a runtime base); the `examples/65816` sweep; the default-build
   isolation check (increment 1 step 8a); the `examples/snes` demo sweep.
9. `dev/run.sh fuzz 50 1`.
10. `dev/run.sh bankwalk` — the one shipped demo whose code changes under both modes (host == a16 == xy16).
11. `lzss-gallery` built `+mos-xy16` (its gate is `+mos-a16`-only and unchanged there; the xy16 build
    changes) — the gate script run with `+mos-xy16` added to every compile.

## 5a. Verification results (2026‑09‑25)

Steps are §5's list verbatim; raw output below each, then PASS/FAIL. Before = `main`'s toolchain
(`build/llvm-mos-install`, `clang-23` 07:35, contains increment 1); after = this worktree's.

**1. `dev/run.sh toolchain` — confirm `clang-23` mtime advanced.**

```
clang-23 mtime: 2026-09-25 08:55:27   (main's: 2026-09-25 07:35; six incremental rebuilds, last one = the landed source)
==> rc=0
```

**PASS**

**2. Lit: extend `far-indir-indexed.ll`.** 23 new functions (positive, mode-dependent, negative, the wrap
trap), 3 new RUN lines (`A16`/`XY16` prefixes, an `OBJXY` object check).

```
$ llvm-lit -v llvm/test/CodeGen/MOS/far-indir-indexed.ll
  Passed: 1 (100.00%)
# the same test against main's (pre-change) llc + FileCheck:
far-indir-indexed.ll:181:10: error: CHECK: expected string not found in input
old-compiler +mos-a16 FileCheck: FAIL          old-compiler +mos-a16,+mos-xy16 FileCheck: FAIL
```

**PASS** — and it fails on the pre-change compiler, so it pins the new behaviour.

**3. `dev/run.sh lit`**

```
Failed Tests (4):
  LLVM :: CodeGen/MOS/legalizer.mir
  LLVM :: CodeGen/MOS/scavenger-p-undef-6502.ll
  LLVM :: CodeGen/MOS/shift-rotate.ll
  LLVM :: MC/MOS/addressing-modes-65816.s
Total Discovered Tests: 164
  Unsupported:   2 (1.22%)
  Passed     : 158 (96.34%)
  Failed     :   4 (2.44%)
# the three CodeGen failures produce byte-identical output from old and new llc (md5 of the RUN line output):
legalizer.mir old=4cb25f46… new=4cb25f46…   shift-rotate.ll old=a7c3e326… new=a7c3e326…
scavenger-p-undef-6502.ll old=e98c3171… new=e98c3171…
```

**PASS** — the known 4-failure baseline, unaffected by this change.

**4. `dev/run.sh farblit`**

```
==> 0) generate the far table asm (tbl[i] = (i + (i>>16)) & 0xFFFF, 3 banks $C1..$C3)
==> 1) -verify clean + the runtime-index fold fired
  [a16] b7=3 97=2 a7=6 87=1 rep#$10=0
  PASS[a16]: 8-bit-Y runtime folds present (rd8/rdw8/cp8 loads, wr8/cp8 stores)
  [xy16] b7=7 97=3 a7=2 87=0 rep#$10=6
  PASS[xy16]: every runtime-base far access folded (16-bit Y via rep #$10); a7 only on the 2 absolute-base probes
==> 2) host oracle
  host oracle corpus_result=0x1E56EE65
==> 3) [a16] build the HiROM ROM (far table) + checksum
==> 4) [a16] MAME: corpus_result == 0x1E56EE65
SMOKE: PASS addr=0x7E021F len=4 got=0x1E56EE65 (ran 120 ticks)
==> 5) [a16] bsnes-jg: corpus_result == 0x1E56EE65 (independent confirmation)
  SMOKE: PASS off=0x21F len=4 got=0x1E56EE65 (ran 240 frames, bsnes-jg)
==> 3) [xy16] build the HiROM ROM (far table) + checksum
==> 4) [xy16] MAME: corpus_result == 0x1E56EE65
SMOKE: PASS addr=0x7E021F len=4 got=0x1E56EE65 (ran 120 ticks)
==> 5) [xy16] bsnes-jg: corpus_result == 0x1E56EE65 (independent confirmation)
  SMOKE: PASS off=0x21F len=4 got=0x1E56EE65 (ran 240 frames, bsnes-jg)
==> 6) [press] 16-bit-Y far load under register pressure: host golden = 0xD695
  [a16] MAME:
SMOKE: PASS addr=0x7E020A len=2 got=0xD695 (ran 600 ticks)
  SMOKE: PASS off=0x20A len=2 got=0xD695 (ran 900 frames, bsnes-jg)
  PASS[xy16]: the 16-bit-Y fold fired (b7=1 in sample, 97=1 in fill)
  [xy16] MAME:
SMOKE: PASS addr=0x7E020A len=2 got=0xD695 (ran 600 ticks)
  SMOKE: PASS off=0x20A len=2 got=0xD695 (ran 900 frames, bsnes-jg)
RESULT: PASS — runtime-indexed far loads/stores via [dp],y (8-bit Y, and 16-bit Y under +mos-xy16) crossing banks fold to 0x1E56EE65, and under register pressure to 0xD695; host == +mos-a16 == +mos-xy16 (both emulators)
```

**PASS.** Sensitivity, shown by injection (scratch, not committed): assembling `farblit_press.c`'s
`+mos-xy16` output with `sep #16 ; rep #16` inserted between the fused `ldy` and its `lda [dp],y` —
exactly what the first, split lowering produced — gives

```
== [pok]  MAME: SMOKE: PASS addr=0x7E020A len=2 got=0xD695      bsnes-jg: PASS got=0xD695
== [pbad] MAME: SMOKE: FAIL addr=0x7E020A len=2 got=0x81AB want=0xD695
          bsnes-jg: SMOKE: FAIL off=0x20A len=2 got=0x81AB want=0xD695
```

so step 6 of the gate catches the defect class it guards. (The same injection into `k_blossom_far`,
where the split lowering had actually emitted it: control `0x950C` PASS, injected `got=0x0000` FAIL.)

**5. `dev/run.sh farindex` and `dev/run.sh farbank`**

```
RESULT: PASS — far table spanning 3 banks ($C1/$C2/$C3) read via lda [dp] folds to 0x0001D8A1, host == +mos-a16 (both emulators)
RESULT: PASS — unaligned 32-bit far reads straddling banks $C1/$C2 and $C2/$C3 via lda [dp],y fold to 0x00010000, host == +mos-a16 (both emulators)
```

**PASS**

**6. `dev/run.sh corpus` and `dev/run.sh corpus-a16`**

```
==> corpus: 80/80 passed
==> corpus-a16: expected.tsv  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg; settle=1000)
==> corpus-a16: 79/79 passed, 0 xfail
```

**PASS** (both).

**7. `dev/run.sh roundtrip`**

```
  default (8-bit)    round-trip: 95 identical, 0 divergent, 25 skipped (exit 0)
  +mos-a16           round-trip: 120 identical, 0 divergent, 0 skipped (exit 0)
  +mos-a16 +mos-xy16 round-trip: 120 identical, 0 divergent, 0 skipped (exit 0)
PASS  round-trip: 0 divergent in all 3 modes
```

**PASS** — 120 fixtures now (118 + `farblit.c` + `farblit_press.c`).

**8. Measurement.** Per-function `.text` bytes; only rows that moved are shown — the other 64 of 108
rows are `delta=+0`, and **no row regresses**.

```
loopp.c a16 -Os blitp before= 72 after= 47 delta=-25
loopp.c a16 misched=off blitp before= 73 after= 46 delta=-27
loopp.c xy16 -Os blitp before= 72 after= 47 delta=-25
loopp.c xy16 misched=off blitp before= 73 after= 46 delta=-27
stress.c a16 -Os rd32 before= 64 after= 60 delta=-4
stress.c a16 -Os rmw8 before= 72 after= 51 delta=-21
stress.c a16 -Os two before= 141 after= 77 delta=-64
stress.c a16 misched=off rd32 before= 69 after= 61 delta=-8
stress.c a16 misched=off rmw8 before= 74 after= 51 delta=-23
stress.c a16 misched=off two before= 141 after= 87 delta=-54
stress.c xy16 -Os fieldc before= 62 after= 57 delta=-5
stress.c xy16 -Os rd32 before= 64 after= 60 delta=-4
stress.c xy16 -Os rmw16 before= 123 after= 79 delta=-44
stress.c xy16 -Os rmw8 before= 72 after= 51 delta=-21
stress.c xy16 -Os two before= 141 after= 77 delta=-64
stress.c xy16 misched=off fieldc before= 77 after= 57 delta=-20
stress.c xy16 misched=off rd32 before= 69 after= 61 delta=-8
stress.c xy16 misched=off rmw16 before= 94 after= 79 delta=-15
stress.c xy16 misched=off rmw8 before= 74 after= 51 delta=-23
stress.c xy16 misched=off two before= 141 after= 87 delta=-54
misc.c a16 -Os blitcall before= 128 after= 102 delta=-26
misc.c a16 -Os fcmp before= 122 after= 40 delta=-82
misc.c a16 -Os fcopy before= 96 after= 18 delta=-78
misc.c a16 -Os fstrlen before= 38 after= 9 delta=-29
misc.c a16 misched=off blitcall before= 129 after= 102 delta=-27
misc.c a16 misched=off fcmp before= 106 after= 40 delta=-66
misc.c a16 misched=off fcopy before= 85 after= 18 delta=-67
misc.c a16 misched=off fstrlen before= 38 after= 9 delta=-29
misc.c xy16 -Os blitcall before= 128 after= 102 delta=-26
misc.c xy16 -Os fcmp before= 122 after= 40 delta=-82
misc.c xy16 -Os fcopy before= 96 after= 18 delta=-78
misc.c xy16 -Os fstrlen before= 38 after= 9 delta=-29
misc.c xy16 misched=off blitcall before= 129 after= 102 delta=-27
misc.c xy16 misched=off fcmp before= 106 after= 40 delta=-66
misc.c xy16 misched=off fcopy before= 85 after= 18 delta=-67
misc.c xy16 misched=off fstrlen before= 38 after= 9 delta=-29
hoprt.c xy16 -Os grid_clear before= 59 after= 29 delta=-30
hoprt.c xy16 -Os grid_hash before= 93 after= 59 delta=-34
hoprt.c xy16 misched=off grid_clear before= 60 after= 29 delta=-31
hoprt.c xy16 misched=off grid_hash before= 93 after= 59 delta=-34
budrt.c xy16 -Os grid_clear before= 59 after= 29 delta=-30
budrt.c xy16 -Os grid_hash before= 93 after= 59 delta=-34
budrt.c xy16 misched=off grid_clear before= 60 after= 29 delta=-31
budrt.c xy16 misched=off grid_hash before= 93 after= 59 delta=-34
loop.c a16/xy16, -Os and misched=off: blit before= 86 after= 86 delta=+0   (all four rows)
```

- **The blit customer** (`loopp.c` `blitp`, the pointer form): **72 → 47 B** at `-Os`, 73 → 46 with
  `-enable-misched=false`; the loop body is `lda [dp],y / sta abs,y / iny / cpy / bne` — 10 B, the
  hand-built optimum of Phase 1 §4. `loop.c` itself is unchanged (86 B) in every configuration: under
  `+mos-a16` its 16-bit offset cannot be proven `< 256`, under `+mos-xy16` its base is a global
  (gate (d)). The scheduler cliff does not touch any of these shapes (±1–2 B between the two columns);
  where the columns differ (`fcmp`, `fcopy`, `two`, `rmw16`) the fold wins under both.
- **Gate history, the honest version.** Before gates (d)–(f), the same sweeps showed `k_blossom_far`
  **+57 B** / `k_buddha_far` **+42 B** (xy16, absolute base), `acrosscall` **+40 B**, and the
  runtime-base hopalong `grid_plot` **+16 B** — all with `-enable-misched=false` too, i.e. this
  change's own cost, not the cliff. Each is now declined; the price is the absolute-base wins
  (`blitg` −12, `red.c` `fb` −11, `k_mandel_far` −15, `far_memops` −90 xy16, `loop.c` xy16 −28, …),
  which move to `long,X`.

**8a. Fixture sweeps + default-build isolation** (`examples/65816`, whole-object `.text`, old vs new):

```
  WIN     farblit: 2198 -> 2084 (-114)
[a16] TOTAL before=51724 after=51610 delta=-114 | wins=1 regress=0 same=113 skipped=0 | disasm identical=113 differs=1
  WIN     farblit: 2199 -> 2052 (-147)
[a16 -mllvm -enable-misched=false] TOTAL before=50774 after=50627 delta=-147 | wins=1 regress=0 same=113 skipped=0 | disasm identical=113 differs=1
  WIN     farblit: 2198 -> 1978 (-220)
[xy16] TOTAL before=51244 after=51024 delta=-220 | wins=1 regress=0 same=113 skipped=0 | disasm identical=113 differs=1
  WIN     farblit: 2199 -> 1974 (-225)
[xy16 -mllvm -enable-misched=false] TOTAL before=50284 after=50059 delta=-225 | wins=1 regress=0 same=113 skipped=0 | disasm identical=113 differs=1
[default] TOTAL before=49115 after=49115 delta=0 | wins=0 regress=0 same=93 skipped=21 | disasm identical=93 differs=0
```

`examples/snes` demo sources (151 compiled, 4 skipped for include paths), `-Os`:

```
  WIN     bankwalk: 9738 -> 9537 (-201)
[a16] TOTAL before=1689563 after=1689362 delta=-201 | wins=1 regress=0 same=150 skipped=4
  WIN     bankwalk: 9706 -> 9505 (-201)
  WIN     lzss-gallery: 22574 -> 22323 (-251)
[xy16] TOTAL before=1682616 after=1682164 delta=-452 | wins=2 regress=0 same=149 skipped=4
```

**PASS** — no regression anywhere; the default (non-`+mos-a16`) build is byte-identical (93/93).

**8b. `-verify-machineinstrs`** over every `examples/65816` + shape source, `+mos-a16` and
`+mos-xy16`, at `-Os`/`-Oz`/`-O2`:

```
FAIL examples/65816/k_isort.c +mos-xy16 -O2: *** Bad machine code: Using an undefined physical register ***
verify ok=737 fail=1
# main's pre-change compiler, same file/flags: same error ($x16 = TAX16 $a16 in main); k_isort has no far pointer
```

**PASS** for this change (the one failure is pre-existing and far-free; reported, not fixed here).

**8c. 16-bit-`Y` hazard scan** — a script flagging "16-bit `ldy`, then `sep #$10`, then a `,y` use
with no `Y` reload", validated on the split lowering's `grid_plot` (2 hits), over all 243
`examples/65816` + corpus sources under `+mos-xy16`, old and new compiler: **0 hits**. Over
`lzss-gallery.c` (`+mos-xy16 -Oz`): **3 hits, identical in old and new output, all in the NEAR
`decode_near` `(zp),y` path** — the pre-existing split `LDYImag16` + `LDIndirYIdx` (R1):

```
	rep	#16
	ldy	__rc20
	sep	#16            <- zeroes Y's high byte
	ldx	.Ldecode_near_sstk ; 1-byte Folded Reload
	stx	__rc2
	...
	rep	#16
	lda	(__rc2),y      <- reads with Y.hi = 0
```

**9. `dev/run.sh fuzz 50 1`**

```
FUZZ_PENDING
```

**10. `dev/run.sh bankwalk`**

```
SMOKE: PASS addr=0x7E13E6 len=2 got=0x4ED7 (ran 480 ticks)
SMOKE: PASS off=0x13E6 len=2 got=0x4ED7 (ran 480 frames, bsnes-jg)
SMOKE: PASS addr=0x7E13E6 len=2 got=0x4ED7 (ran 480 ticks)
SMOKE: PASS off=0x13E6 len=2 got=0x4ED7 (ran 480 frames, bsnes-jg)
RESULT: PASS — BankWalk host == a16 == xy16 == 0x4ED7
```

**PASS** — on code this change rewrote (−201 B in both modes).

**11. `lzss-gallery` built `+mos-xy16`.**

```
# gate script with +mos-xy16 on every compile — NEW compiler:
SMOKE: FAIL off=0x24 len=2 got=0xA50F want=0x5CF0
# the same, main's PRE-change compiler:
SMOKE: FAIL off=0x24 len=2 got=0xA50F want=0x5CF0
# scratch variant whose benchmark checks ONLY the far path (decode_far + fold_far; near decode
# dropped) — NEW compiler (decode_far carries 4 folded b7/97):
SMOKE: PASS off=0x200 len=2 got=0x5CF0 (ran 30000 frames, bsnes-jg)
LZSS_FAR_OLD_PENDING
```

**PASS for this change; FAIL pre-existing.** The xy16 gallery fails identically before and after
(`0xA50F` is the "some work failed" flag). With the near decoder removed from the check, every one
of the 62 works decodes correctly through the folded `decode_far`, so the failure is the near
`(zp),Y16` hazard of 8c, not this change. `lzss-gallery` ships `+mos-a16` only, where it is unchanged
(`-Oz` object 978829 B before and after).

## 5b. Residual risk

- **The near `(zp),Y16` path is miscompiling today under `+mos-xy16`** (8c/11) — the same split
  structure this change avoided by fusing. `MOSInsertREPSEP`'s 2026‑06‑29 repair re-issues the last
  16-bit *X* writer after a `sep #$10`, but has no `Y` counterpart, and a re-issued writer is itself
  unsafe when its source register was reused in between (the split `grid_plot` did exactly that:
  `ldy __rc2 … stx __rc2`). Suggested fix: fuse `LDYImag16` + `LDIndirYIdx`/`STIndirYIdx` the way
  `LDIndirLongYIdx` is fused here. Not in this change's scope; handed back to be ranked.
- **LSR's `isLegalAddressingMode` now over-promises less, but not zero.** It reports base + 8-bit
  index as free for AS2; this change makes that true for runtime bases, but gates (d)–(f) still leave
  legal `i8` shapes unfolded (absolute base, a call in between, several accesses in a function with a
  call). The hoist investigation (§5.1) says to make the hook AS2-aware *to match* what ISel folds;
  a profitability gate is not expressible there, so it is left as is.
- **Gates (e)/(f) use a call proxy for register pressure.** The measured regressions were all
  call-driven; a call-free function with enough arithmetic to spill the base quad could still pay
  one reload per access for a multi-access `V`. Not observed in any of the 108 + 114×4 + 151×2
  measurements.
- **The 0002 regeneration** used the same two uncommitted `0020`/`0033` patch files from `main`'s
  working tree that increment 1 used (the committed versions no longer reverse out of the shared
  `vendor/`); the regenerated `0002` differs from the committed one only in this change's six files.


## 6. Rebased verification (2026‑09‑26)

- [x] Preserve the original uncommitted files and compiler edits; rebase the worktree onto current committed main.
- [x] Reconstruct the committed bootstrap independently, then build and preserve its baseline compiler.
- [x] Reapply only the six increment 2 compiler/test files, preserving the landed fixes; regenerate 0002 and verify its round trip.
- [x] Model the fused pseudo's full `Y16` clobber and check it in selected MIR; require bsnes-jg for the new gate.
- [x] Confirm the runtime-index checks fail on the baseline and pass on the candidate in both feature modes.
- [x] Run farblit, farindex and farbank on MAME and bsnes-jg.
- [x] Run the complete MOS lit suites on the candidate; rerun all three failed tests on an isolated exact `8c19c703` baseline.
- [x] Run the assembly round-trip gate in all three modes.
- [x] Complete the code-size/default-isolation census, native-mode corpus, near-store controls, BankWalk, far gallery control and 50-seed fuzz run.
- [x] Classify all three full-lit failures against the exact reconstructed committed baseline; each fails there with the same diagnostic/check location.
- [x] Refresh dependency receipts and tracker status, stage and review the full candidate diff, then commit the locally verified increment as `97798007`.

The baseline was reconstructed from the exact patch application list in committed
`dev/toolchain.sh`. Main's uncommitted build-script changes and other live vendor
edits were excluded from this comparison. The temporary baseline installation was
removed when the worktree's ignored build outputs were cleared at session resume;
its compiler identity and captured test logs remain recorded, and the build can be
recreated from the pinned vendor revision and committed patch stack. Baseline Clang SHA-256:
`dc2ad46a1efe52c2d1feb3a91189997e3048f11210fc9c55f5e3e99030a5ef34`.
Frozen defect input, preprocessed source, assembly, and baseline runtime log are
under `docs/defects/evidence/2026-09-26-dpy-near-y/`.

Current clean-build MOS lit result: 168 total, 163 passed, 2 unsupported and
3 failed (`legalizer.mir`, `shift-rotate.ll` and
`addressing-modes-65816.s`). All three also fail on the exact reconstructed
`8c19c703` baseline with the same diagnostic or FileCheck location. The new
indexed lit test, selected-MIR check, and both near-store lit tests pass. The
earlier five-failure tally above is historical and came from a stale generated
build; this clean rebuild supersedes it.

Assembly round trips: 97 default objects and 122 objects in each native mode are
identical, with zero divergences. Default skips are unsupported far-pointer
fixtures. Farblit returns `0x1E56EE65`; its register-pressure case returns `0xD695`
in both native modes on both emulators. Farindex returns `0x0001D8A1`; farbank
returns `0x00010000` on both emulators.

Additional fresh gates: the 79-case native-mode corpus passes 79/79 with zero
xfail; both near-store controls pass on MAME and bsnes-jg; BankWalk matches host
and both native modes at `0x4ED7`; Csmith fuzz reports 45/50 passes, 5 skips
(`corpus_result` was garbage-collected before sampling), and zero mismatches,
crashes or errors. The measured code-size census and default-build isolation
remain as recorded in §5a: no regressions and default objects byte-identical.
The full `lzss-gallery` XY16 failure remains independently reproduced on
baseline and candidate (`0xA50F`, expected `0x5CF0`); the near-Y defect is
tracked separately and is not repaired by this increment.

The inherited near-Y report now has a [canonical record](../defects/mos-xy16-near-indirect-y-clobber.json)
with a frozen failing committed-main run, source snapshot, preprocessed input,
assembly and prior-work audit. The existing June X-index repair is present but
has no Y counterpart. The full gallery's runtime failure is reproduced; the
precise LTO cause is qualified until an isolated near-path witness establishes
it. No near-path repair is claimed by this increment.

Compatibility review also requires byte-valued leaves throughout the user walk.
The runtime fold explicitly rejects a native word operand, and its fused pseudo
records `Defs = [Y16]`. A word-arithmetic lit case passes when 0061 and 0062 are
applied over this change. Both standalone patches apply without edits. The
new negative global-base check permits any correct non-`[dp],Y` lowering,
including `long,X`.
