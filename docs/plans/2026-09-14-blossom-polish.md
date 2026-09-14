# Blossom — optional-polish pass (TODO #3, remaining bullets a/b/c)

**Status:** done — one of three items implemented (a documentation correction), the other two
investigated and explicitly NOT shipped, each with a measured/evidenced reason. Plan supplements
`~/CLAUDE.md`, project `CLAUDE.md`, `docs/agent-handoff.md`, and the Stage-2 plan
`docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md`.

## Context

`#3 SNES Blossom` (TODO.md ~line 509) is CORE + HUD DONE, verified, landed on `main`, published at
[biohack.net/blossom](https://biohack.net/blossom) — only "optional polish" remains, enumerated in the
TODO item as three bullets:

- **(a)** a literal 64 KB / 256×256 supersampled grid in bank `$7F` for anti-aliasing (currently uses
  16 KB — "the far path is identical, just smaller").
- **(b)** the hw multiplier (`$4202/$4203→$4216`) for the hot `b*x` to speed the ~10 s bloom.
- **(c)** re-test the 2nd far-pointer fragility (a far→far whole-image / far constant-fill in a
  multi-far TU derailed at runtime under `+mos-a16`; worked around with band/near-staging) — likely
  now resolved by the far-memops fix (`0013`/`0014`) that landed on `main` since; confirm and drop
  the workaround if so.

Scope for this pass, per dispatch: **`examples/snes/blossom.c` and its headers only** — no changes to
the shared `examples/65816/hopalong.h` (consumed by `k_hopalong.c`, `spiro.h`, `buddha.h`,
`far_memset.c`, and `k_blossom_far.c` — editing it is cross-cutting, out of this task's remit).

**No mockup bundle**: none of the three items land a rendered-output change (see verdicts below) —
(a) and (b) are not shipped, (c) is a one-line doc-comment correction. The demo's existing screenshots
(`build/blossom-{jg,mame}.png`, captured fresh below) stand in for a mockup, matching how sibling
SNES-demo plans in this repo document verification (this is emulator-ROM output, not a web/TUI
surface the mockup-bundle convention targets).

**Worktree:** hardlink/non-compiler (`docs/howto-feature-worktree.md` — shares `main`'s prebuilt
toolchain read-only, no `vendor/` rebuild), branch `wt/blossom-polish`, dir
`/home/will/llvm-mos-65816-blossom-polish`. SPC700 IPL was present (`dev/roms/s_smp/spc700.rom`), so
both MAME and bsnes-jg legs run (not SKIP).

## Baseline (before any change)

```
$ dev/run.sh blossom
host grid: maxabs=5895 clamps=0  cells_hit=779/16384  saturated=0
==> host reference: grid hash = 0x9047
==> built blossom.sfc (+mos-a16); corpus@$54 blossom_crc@$56 pad_log@$200
    SMOKE: PASS off=0x54 len=2 got=0x9047 (ran 1500 frames, bsnes-jg)
    BLOSSOM: PASS frames=64 nonzero=64 blossom_crc=0xEC5A (host replay == ROM, bsnes-jg)
    SHOT: PASS corpus=0x9047 (snapshot at frame 1500)
RESULT: PASS — interactive Hopalong attractor on SNES; grid hash 0x9047 host == +mos-a16 (MAME +
bsnes-jg); state-math host == ROM (bsnes-jg)

$ task snes-display-quality
SNESDQ: PASS (241 reviewed sensitive access sites; display order and upload budgets valid)
```

## Items

| # | Intended change | Gate | Verdict |
|---|---|---|---|
| (a) supersampled grid | `HOP_GRID` 128→256 in bank `$7F` (64 KB), display path box-sums 2×2 sub-cells back to 128×128 for the AA claim | `dev/run.sh blossom` (would need golden re-baseline: bigger `HOP_NCELLS` changes `grid_hash`) | **NOT SHIPPED — proven zero visual benefit** (below) |
| (b) hw multiplier for `b*x` | Replace `hop_step`'s `(int32_t)b*(int32_t)x` with a `WRMPYA`/`WRMPYB`→`RDMPY` 4-partial-product signed decomposition | `dev/run.sh blossom` (grid hash unchanged if bit-exact) | **NOT DONE — out of stated scope** (below) |
| (c) re-test far-pointer fragility | Re-run the originally-failing shapes (far→far whole-image copy; non-volatile far constant-fill) inside blossom.c's own TU; if fixed, correct the top-of-file comment | `dev/run.sh blossom` (must stay `RESULT: PASS`, hash unchanged) + a standalone MAME/bsnes-jg re-test build | **DONE — confirmed fixed; comment corrected** (below) |

### (a) — 256×256 supersampled grid in bank `$7F`: NOT SHIPPED

**Why the literal ask can't win anything, proven (not assumed):** `hopalong.h`'s coordinate map is
`hop_map(v) = (v >> HOP_SHIFT) + HOP_CENTER`, with `HOP_SHIFT=7`/`HOP_CENTER=64` at `HOP_GRID=128` and
`HOP_SHIFT=6`/`HOP_CENTER=128` at `HOP_GRID=256`. Because `HOP_CENTER` is exactly double and `HOP_SHIFT`
differs by exactly 1 bit, `floor((v+128)/2) == floor(v/2) + 64` for every `v` (the `+128` is even, so the
shift distributes exactly) — i.e. `hop_map_128(v) == hop_map_256(v) >> 1` **bit-for-bit**, always. Each
128-grid cell is therefore the exact union of 4 adjacent 256-grid cells, so a 2×2 box-sum-downsample
of the 256-grid reproduces the 128-grid histogram **exactly**, with no smoothing/AA effect — a
supersample-then-box-sum step here is pure overhead (4× WRAM, ~4× far-read traffic in `build_band`)
for a mathematically provable **zero** rendered-output difference. Confirmed empirically, host-side,
reusing the project's own `hopalong.h` (no SNES build needed for this structural check):

```
$ cc -DHOST -O2 -I examples/65816 -o /tmp/g128 /tmp/grid128.c   # HOP_GRID 128, K=8000 classic points
$ cc -DHOST -O2 -I examples/65816 -o /tmp/g256 /tmp/grid256.c   # HOP_GRID 256, same seed/params/K
$ ./g128 > g128.bin && ./g256 > g256.bin
$ python3 -c '... box-sum each 2x2 block of g256, clamp to 255, diff vs g128 ...'
cells=16384 mismatches(box-sum-clamped vs direct128)=0
nonzero cells: 128grid=779 256grid=1847
```
0/16384 mismatches — the box-sum reconstruction is bit-identical to the current 128-grid render.
(`nonzero cells` differs because the *count of touched cells* is finer at 256×256 before the sum
folds them back — that's the exact-partition identity being visible, not a discrepancy.)

**Verdict:** per CLAUDE.md lesson 3 ("only genuine gains — gate a blanket change… wrong"), this is not
a modest gain, it is a **proven zero gain** at real cost (4× bank-`$7F` memory, ~4× `build_band`
far-read traffic per revealed row, plus a `grid_hash` golden re-baseline for no visible payoff). Not
implemented in `blossom.c`. A genuine AA win here would need real supersampling semantics (e.g. an
overlapping/dithered kernel, or increasing the *orbit's* per-point spread) rather than an aligned
box-sum of an exact 2× finer partition — that's a different, larger design question than "polish,"
left undone.

### (b) — hardware multiplier for `b*x`: NOT DONE (scope)

`hop_step`'s `bx = ((int32_t)b * (int32_t)x) >> 8` — the hot per-point multiply — is defined in the
**shared** `examples/65816/hopalong.h`, not in `examples/snes/blossom.c`. `hopalong.h` states its own
design invariant in its header comment: it is "the single source of truth" compiled by **six**
consumers (`k_hopalong.c`, `spiro.h`, `buddha.h`, `far_memset.c`, `k_blossom_far.c`, `blossom.c`), each
with its own differential golden. Even the minimal, fully-backward-compatible shape (an
`#ifndef`-guarded macro hook mirroring the file's own existing `HOP_NOINLINE`/`HOP_FN` precedent,
default-unchanged for every consumer) still means editing shared math and re-verifying every
consumer's gate to be responsible — genuinely cross-cutting, not "one file, clear spec."

**This task's dispatch scope is explicit:** *"examples/snes/blossom.c and its headers"* — `hopalong.h`
is not blossom's header, it's a shared library header five other demos also depend on. Per the
delegation guide's escalation rule ("the right design is genuinely unclear… stop and say ESCALATE"),
this is flagged rather than forced through:

> **ESCALATE-worthy:** a hardware-accelerated `b*x` needs a hook (or a target-only reimplementation
> of `hop_step`) in `examples/65816/hopalong.h`, which is shared by `k_hopalong.c`/`spiro.h`/
> `buddha.h`/`far_memset.c`/`k_blossom_far.c` in addition to `blossom.c`. A correctly-scoped dispatch
> for this item names `hopalong.h` explicitly and budgets re-verification of all six consumers' gates
> (`dev/run.sh k_hopalong`, `spiro`, `buddha`, `far_memset`, `blossom-grid`, `blossom`), plus real
> cycle evidence that the 4-partial-product `WRMPYA`/`WRMPYB` decomposition (needed because the
> hardware multiplier is 8×8→16 **unsigned only** — a 16×16 signed multiply needs sign-strip +
> 4 byte-wise partial products + recombine, not a single register write) actually beats the
> existing `__mulsi3` libcall on real operand ranges (`b` up to `0x0871`, `x` up to `±5895`, both
> needing all 4 partial products — no simplified 1-byte case applies). Recommend a follow-up TODO
> item scoped to `hopalong.h` + its consumers, tier T3 (multi-file verification against a design
> that itself needs deciding — the hook shape).

Not implemented. `blossom.c`/`blossom.h` unchanged for this item.

### (c) — re-test the 2nd far-pointer fragility: DONE — confirmed fixed, comment corrected

The Stage-2 plan (`docs/plans/2026-06-24-…hopalong-attr.md:234-238`) recorded that, when Blossom was
first built, **two** far-pointer shapes derailed at runtime under `+mos-a16` (clean `-verify`, runtime
runaway, not minimally reproduced in isolation): a far→far whole-image build (the abandoned
`M7_DEFINE_BUILD_VBUF` — no longer present in `mode7.h`, confirmed absent by grep) and a **non-volatile
far constant-fill test pattern**. `patches/llvm-mos/0013-320-far-memops.patch` (far memops routed to a
far-aware `__memset_far`/`__memcpy_far`/`__memmove_far` runtime, closing the generic
`legalizeMemOp` chokepoint — clang `EmitAggregateCopy`, `__builtin_mem*`, and MemCpyOpt-formed memsets
all converge there) and `0014-321-far-ptr-phi-legalize.patch` (far-pointer `G_PHI` legalization) landed
on `main` since — both plausible fixes for exactly this shape.

**Re-test method:** since the original repro "was not minimally reproduced (isolated repros pass)" —
it only manifested inside Blossom's own multi-far translation unit — the re-test had to live in
`blossom.c` itself. Added a temporary `#ifdef BLOSSOM_RETEST_FARFRAGILITY` block (never wired into the
shipped `main()`; deleted after the re-test regardless of outcome) with two `noinline` functions
against a scratch far buffer `grid2` at `$7E6000` (clear of the 16 KiB grid):
- `retest_farfar_copy`: `for (i…) grid2[i] = grid[i];` — **two far pointers live across one
  16384-iteration loop**, the genuine far→far shape (`build_band`'s existing per-band helpers are all
  far→**near**, single far pointer per call — not this shape).
- `retest_constfill`: `for (i…) grid2[i] = 0x42;` — the non-volatile far constant-fill (the same shape
  as the already-documented, already-fixed `docs/320-far-memset-miscompile.md` bug, but re-checked in
  Blossom's own TU rather than the isolated `far_memset.c` repro).

Built standalone (`-DBLOSSOM_RETEST_FARFRAGILITY -DK_GATE=8000`, headless: no PPU/splash, just
grid-fill → both suspect ops → hash → spin), host goldens derived the same way as the shipped gate:

```
$ cc -DHOST -O2 -I examples/65816 -o /tmp/retest_host /tmp/retest_host.c
want_copy(=grid_hash(grid) after K_GATE=8000)=0x9047     # == the shipped corpus_result golden
want_fill(=grid_hash(all-0x42))=0x0000                    # rotate-xor hash of ANY constant fill,
                                                            # period-32 cancellation (verified for
                                                            # 0x00/0x01/0x42/0x43/0x80/0xAA/0xFF)
```

Disassembly (native object, `-fno-lto` to get past the vacuous-LTO-verify pattern noted in
`dev/blossom.sh`) confirms **both** shapes now lower correctly:
```
retest_farfar_copy:   42: a7 00  lda [$0]   ; indirect-long FAR load
                       44: 87 00  sta [$0]   ; indirect-long FAR store   -- real far->far, not a libcall
retest_constfill:      ... jmp $0
                       00000017:  R_MOS_ADDR16  __memset_far             -- the FAR-aware runtime (0013),
                                                                          -- not the buggy near __memset
```

Execution (both emulators, both proof channels — no hang, no runaway, correct values):
```
$ jgxcheck build/blossom-retest.sfc vendor/bsnes-jg/Database 0x200 2 0x9047 900
SMOKE: PASS off=0x200 len=2 got=0x9047 (ran 900 frames, bsnes-jg)
$ jgxcheck build/blossom-retest.sfc vendor/bsnes-jg/Database 0x202 2 0x0000 900
SMOKE: PASS off=0x202 len=2 got=0x0000 (ran 900 frames, bsnes-jg)

$ source dev/_emu.sh && require_bios
$ SMOKE_SETTLE=750 SMOKE_SECONDS=18 run_assert build/blossom-retest.sfc build/blossom-retest.map retest_copy_hash 0x9047
SMOKE: PASS addr=0x7E0200 len=2 got=0x9047 (ran 750 ticks)
$ SMOKE_SETTLE=750 SMOKE_SECONDS=18 run_assert build/blossom-retest.sfc build/blossom-retest.map retest_fill_hash 0x0000
SMOKE: PASS addr=0x7E0202 len=2 got=0x0000 (ran 750 ticks)
```

**Confirmed: the 2nd far-pointer fragility is resolved** — both previously-derailing shapes now
compile to the correct far-aware code and execute correctly on MAME + bsnes-jg. The retest scaffolding
was then deleted (diagnostic only, never shipped — see `git diff` below, the only surviving change is
the comment).

**Whether to "drop the workaround":** the TODO item's own text already flags the caveat — band/near
staging "is also the Stage-3 per-vblank unit." `build_band(trow)` amortizes the far-read + tiled-reorder
cost across `TILES=16` frames so the reveal blooms progressively and no single frame pays for the whole
128×128 image; collapsing it into one far-touching pass would concentrate ~16× the per-frame far-read
work into a single frame (a real, visible pacing regression) and would also delete the "revealed
one band per frame" bloom animation that is a deliberate, visible feature of the demo — not a symptom
of the bug. So there is no longer a compiler-bug *reason* to keep the band/near structure, but the
structure is not "a workaround" to begin with — it is the per-frame budget/reveal mechanism, and stays.
**Change made:** corrected `blossom.c`'s top-of-file comment (was: the structure "sidesteps the
+mos-a16 far-pointer pressure that a far->far whole-image build hits" — no longer accurate) to state
the real, current reason (amortized far-read cost across `TILES` frames), without touching
`build_band`, `dma_chr_to`, or the render loop.

```diff
-// grid_hash idiom that sidesteps the +mos-a16 far-pointer pressure that a far->far whole-image build
-// hits). The orbit state persists across frames so the cloud BLOOMS progressively; the 256-entry CGRAM
-// palette is rotated every frame for the "wallpaper for the mind" shimmer.
+// grid_hash idiom) so the far-read + tiled-reorder cost amortizes across TILES frames instead of
+// stalling one frame on the whole image. The orbit state persists across frames so the cloud BLOOMS
+// progressively; the 256-entry CGRAM palette is rotated every frame for the "wallpaper for the mind"
+// shimmer.
```

## Verification (post-change)

1. **`dev/run.sh blossom`** — unchanged golden, both emulators, comment-only diff:
   ```
   host grid: maxabs=5895 clamps=0  cells_hit=779/16384  saturated=0
   ==> host reference: grid hash = 0x9047
   ==> built blossom.sfc (+mos-a16); corpus@$54 blossom_crc@$56 pad_log@$200
       SMOKE: PASS off=0x54 len=2 got=0x9047 (ran 1500 frames, bsnes-jg)
       BLOSSOM: PASS frames=64 nonzero=64 blossom_crc=0xEC5A (host replay == ROM, bsnes-jg)
       SHOT: PASS corpus=0x9047 (snapshot at frame 1500)
   RESULT: PASS — interactive Hopalong attractor on SNES; grid hash 0x9047 host == +mos-a16 (MAME +
   bsnes-jg); state-math host == ROM (bsnes-jg)
   ```
   **PASS** — golden hash `0x9047` and `blossom_crc` `0xEC5A` both bit-identical to the pre-change
   baseline above; no re-baseline needed (no rendered-output change shipped).

2. **`task snes-display-quality`**:
   ```
   SNESDQ: PASS (241 reviewed sensitive access sites; display order and upload budgets valid)
   ```
   **PASS** — identical site count to baseline (241), no new/changed display-contract sites.

## Publication

Blossom is published at [biohack.net/blossom](https://biohack.net/blossom) (`docs/blossom-manual.md`,
TODO.md line 518). Since the shipped diff is comment-only (the ROM is byte-for-byte unaffected —
`corpus_result`/`blossom_crc` unchanged, checksum unaffected), there is nothing to republish. Even if
there were, **republishing is a separate, user-gated step** (the `snes-rom-page` skill's deploy) and is
explicitly not done here.

## Disposition

Worktree `wt/blossom-polish` (`/home/will/llvm-mos-65816-blossom-polish`) retained, not merged, not
pushed — commit lands only `examples/snes/blossom.c` and this plan on the branch, per dispatch.
