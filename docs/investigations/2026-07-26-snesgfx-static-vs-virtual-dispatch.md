# snesgfx: static vs all-virtual dispatch — measured (2026-07-26)

**Question (user-posed):** what happens if ALL snesgfx "static member" functions
(`Type_verb(Type *self, …)`) are made **virtual** (vtable dispatch)? Benchmark the design change.

**Verdict:** all-virtual costs **1.35×** runtime on a dispatch-bound loop (vs out-of-line direct)
and **+15–49% `.text`**, with zero LTO devirtualization to soften it — while, as a genuine surprise,
merely forcing the members **out-of-line (still direct) is 15% FASTER than static inline** on the
65816. The library's §2 discipline (virtualize interfaces, never rasterizers) is quantitatively
validated; "inline everything" is not.

**Charts:** [2026-07-26-snesgfx-dispatch-charts.html](2026-07-26-snesgfx-dispatch-charts.html) ·
**Doc:** the durable summary lives in [`docs/oop-in-c.md` §8](../oop-in-c.md) (plus corrected §4/§5).

---

## Method

Three-mode compile-time switch, `SNESGFX_DISPATCH` (new `snesgfx/dispatch.h`), all 113 demos
compiling unchanged in every mode:

| Mode | Meaning | Isolates |
|---|---|---|
| 0 | `static inline` (production; **verified byte-identical** `.text` to pre-experiment) | baseline |
| 1 | out-of-line direct calls (`noinline` impls, direct call sites) | loss-of-inlining cost |
| 2 | per-type vtables — every member call is `self->vt->verb(self, …)` | + indirect-dispatch cost |

Each `Type_verb` became a static-inline forwarder around a `_Type_verb_impl`; constructors install
the per-type `const TypeVT`. ~40 member functions across 11 headers (VramAlloc, UploadQueue, Scene,
Display, Controller, SpriteSet, TextLayer, BitmapCanvas, TitleLayer, HScrollW, HScrollDB).
**Excluded** (explicit scope decisions): constructors (`*_init` — they install the vt),
`HScrollN`-receiver functions (its `tab[]` IS the DMA-visible HDMA table — a vt member corrupts the
layout), free functions (`splash_show`, `m7splash*`, `splash16` — no receiver), and the
pre-existing `DrawableVT`. Mode 2 adds one 2-byte vt pointer per object (WRAM).

**Vehicles & harness:**

- `examples/snes/mandel-oop.c` via the hardened `dev/run.sh mandel-oop` — correctness
  (`corpus_result == 0x204F` required in every mode), `.text` (linker-map `.lto.o` lines),
  indirect-dispatch call sites (`jmp (` + `jsr (` + `jsr __call_indir`).
- NEW `examples/snes/snesgfx_bench.c` + `tools/snesgfx-bench-oracle.c` +
  `dev/measure-snesgfx-dispatch.sh` — throughput: infinite loop of `canvas_clear` + 12-line
  Bresenham star (mode 2 pays one virtual `canvas_plot` per plotted pixel), volatile `iters`
  read back at a fixed frame. **bsnes-jg only** (deterministic; the SPC700 IPL needed by MAME
  is absent in this environment — the repo's established `JG_ONLY` posture, `dev/_emu.sh`).
  Correctness sentinel: CRC16 of the 4 KB canvas shadow vs an independent host oracle
  (`0x26EC`) — a fast-but-wrong mode can't score.

Experiment ran on throwaway worktree branch **`throwaway/snesgfx-virt-bench`** (commit `8ad0f28`,
based on main `9bddc38`); toolchain: the 2026-07-25-rebased from-source `mos-clang`,
`+mos-a16 -Os -mllvm -verify-machineinstrs` (clean ×3 modes).

## Results

**mandel-oop** (`+mos-a16 -Os`; CRC `0x204F` in all modes):

| Mode | `.text` | Δ vs 0 | Indirect call sites |
|---|---|---|---|
| 0 static inline | 3,660 B | — | 1 |
| 1 out-of-line direct | 3,537 B | **−3.4%** | 2 |
| 2 all-virtual | 5,470 B | **+49%** | 15 |

**snesgfx_bench throughput** (2,400 deterministic bsnes-jg frames; CRC `0x26EC` in all modes):

| Mode | `.text` | Ind. calls | Redraws | Relative cost |
|---|---|---|---|---|
| 0 static inline | 1,918 B | 0 | 175 | 1.00× |
| 1 out-of-line direct | 1,934 B | 0 | **201** | **0.87×** (15% faster) |
| 2 all-virtual | 2,199 B | 5 | 149 | 1.35× vs 1 · 1.17× vs 0 |

(600-frame run reproduced identical ratios — 40/46/34 — deterministic, not noise.)

## Findings

1. **Out-of-line direct calls BEAT static inline by 15%** on the dispatch-bound loop. Inlining
   `canvas_plot` into the Bresenham loop bloats the caller's a16/ZP live set; forcing it
   out-of-line relieves register pressure — the same effect that motivated `canvas_line`'s
   pre-existing `noinline` (handoff §4). Governing lesson #1 (measure, don't assume) strikes
   again: the "obvious" inline-everything baseline is not the fastest shape on this machine.
2. **The vtable indirection itself costs 1.35×** (mode 1 → 2, the clean comparison) via the
   `__call_indir` route: ZP vt load, slot load, indirect JSR — per pixel, in the bench's case.
3. **LTO devirtualizes nothing**: all 15 provably-single-target indirect sites survive in
   mode-2 mandel-oop. "The compiler will devirtualize it" is not an argument on llvm-mos.
4. **The §2 discipline is validated**: 1 coarse virtual call/drawable/frame is unmeasurable;
   1 virtual call/pixel costs a third of the machine and half again the code size.
5. Also corrected while re-measuring (mandel-oop, hardened gate): the 2026-06-30 "0 indirect
   JMPs / LTO devirtualized all vtable calls" claim was a measurement artifact (`grep 'jmp ('`
   misses `__call_indir`; `|| true` over a missing ELF reads as 0) — **1 indirect call
   survives** even in the production build. And `mandel-display.c` has diverged (8,290 B
   `.text` — coarse-preview pass + title card), so the historical "+338 B / +10% OOP overhead"
   §5 figure is no longer a current comparison.

## Reproducing

The full experiment diff is archived as
[2026-07-26-snesgfx-all-virtual.patch](2026-07-26-snesgfx-all-virtual.patch) (14 files:
`snesgfx/dispatch.h` + 11 converted headers + bench + oracle + measure script). To re-run:

```bash
git worktree add -b throwaway/snesgfx-redo ../llvm-mos-65816-redo main
cd ../llvm-mos-65816-redo && git apply ../llvm-mos-65816/docs/investigations/2026-07-26-snesgfx-all-virtual.patch
# hardlink build assets per docs/howto-feature-worktree.md, then:
dev/run.sh mandel-shot && dev/run.sh mandel-oop                     # mode 0 baseline
SNESGFX_CFLAGS=-DSNESGFX_DISPATCH=2 dev/run.sh mandel-oop           # all-virtual
BENCH_FRAMES=2400 dev/run.sh measure-snesgfx-dispatch               # 3-mode throughput table
```

(`dev/mandel-oop.sh`'s hardening + `dev/run.sh`'s `SNESGFX_CFLAGS`/`BENCH_FRAMES` forwarding
landed on main — the patch carries only the experiment proper.)

## Status / decision

Measured and recorded; the experiment code stays on `throwaway/snesgfx-virt-bench` pending the
user's call (adopt / land the flag default-off / discard + teardown). Per the numbers, the
recommendation is **discard the all-virtual variant** (it exists to be re-appliable from the
patch) — but the mode-1 finding suggests a separate, genuinely promising follow-up:
**selective `noinline` on fat snesgfx members** (`canvas_plot`? `text_puts`? `upq_push_*`?) could
be a free ~15% on dispatch-heavy demos. That is a new investigation, gated per lesson #2
(operand residency / schedule — only where it wins).
