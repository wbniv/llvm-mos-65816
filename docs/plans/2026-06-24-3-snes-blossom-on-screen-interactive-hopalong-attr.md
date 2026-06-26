# #3 — SNES Blossom: on-screen interactive Hopalong-attractor port

**Status:** plan. Phase 1 (headless Q8.8 kernel `examples/65816/k_hopalong.c`) is landed + 4-way
verified (golden `0x1BBC`). This plan covers the on-screen interactive renderer.
Plan supplements the standing guides (`~/SRC/CLAUDE.md`, project `CLAUDE.md`,
`docs/agent-handoff.md`) and the Phase-1 plan `docs/plans/2026-06-24-blossom-snes.md`.

## Context

Blossom is Barry Martin's "Hopalong" strange attractor — `x' = y - sign(x)·sqrt(|b·x − c|)`,
`y' = a − x`, iterated from `(0,0)`. Phase 1 shipped the Q8.8 math headless (orbit → checksum)
through the differential gate. The deliverable here is the **graphical payoff**: render the
attractor live on the SNES and make it interactive, demonstrating `+mos-a16` on a realistic,
*animated* fixed-point + far-pointer workload. This is the M2 / #321 demo item (`TODO.md` #3).

**Two findings from exploration that reshape the scope (the task brief is stale):**

1. **Graphics is NOT greenfield.** A full Mode 7 demo family landed 2026-06-25 *after* the Phase-1
   plan was written: `examples/snes/mandel-mode7.c` (per-pixel far-compute → reveal),
   `examples/snes/mandel-interactive.c` + `examples/snes/view.h` (joypad fly-around with a
   host-replayable state machine), `examples/snes/mandel-zoom.c`. They ship reusable helpers
   (`examples/snes/mode7.h`) and a complete **two-emulator differential harness**
   (`dev/jgxcheck.cpp` with `JGX_VIEW` scripted-input replay; `dev/mandel-interactive.sh`).
2. **The "Phase-2 graphics-register pull-forward" is already done.** All VRAM/Mode-7/DMA/CGRAM/
   joypad registers live in `platforms/snes/snes_{ppu,dma,cpu,joypad}.h`; `mode7.h` is the reusable
   gfx helper; `snes_read_pad1()` already exists. **No HAL work is needed.**

So the real remaining work is: a Hopalong **plotter/accumulator** (the new `+mos-a16` codegen
customer — far read-modify-write), a **colorizer**, the **animated render loop**, a **joypad param
state machine**, and the **differential gates** — each closely mirroring a proven mandel pattern.

**Library framing** (`docs/investigations/open-source-snes-libraries.md`): the repo is "growing a
SNES rendering library"; there is no LLVM SNES C library to adopt. Keep any extracted gfx helper a
*thin, reusable layer on top of `snes.h`* (per the rendering handoff's "Recommended library shape"),
borrowing API shape from PVSnesLib and DMA/rep-sep discipline from libSFX as references — not as
deps. The reusable bits of this demo feed that library.

## What genuinely new `+mos-a16` codegen this exercises

Beyond the existing demos (orbit math is already proven; mandel's far traffic is write-only `sta [dp]`
+ read-only `lda [dp]`), Blossom adds:
- **Far read-modify-write through a *runtime* 24-bit pointer** — `lda [dp]` / saturate-compare /
  `inc` / `sta [dp]` to a runtime-computed index (the coordinate map output), so the pointer can't
  fold to absolute-long; a fresh 32-bit pointer is built per plotted point.
- **Q8.8 coordinate transform → pointer arithmetic**, interleaved with the orbit's 16-bit math
  (heavier 8/16 interleave than the orbit alone).
- **Far-load downsample** (the colorize pass) — a 2×2 box-sum far scan distinct from a flat CRC scan.

## Architecture

Reuse `mandel-mode7.c`'s loop shape (far compute buffer → colorize → reveal-by-band-in-vblank →
hash the far buffer) and `view.h`'s host-replayable pure state machine. The novelty is the
accumulation (far RMW) and the per-frame amortization.

### Buffers & memory map (target = "Rung B"; de-risk via "Rung A")

| Region | Contents |
|---|---|
| `$7F0000–$7FFFFF` | **256×256 × u8 hit grid (64 KB)** — far RMW target (the spec's "64 KB shadow buffer") |
| `$7E6000–$7EDFFF` | `m7_vbuf` 32 KB interleaved Mode-7 staging (`mode7.h:24`) |
| `$7E2000–$7E5FFF` | scratch (and the **Rung-A** 128×128/16 KB grid during de-risk) |
| `$7E0200–$7E1FFF` | low WRAM: near `chrbuf[1024]`, `pad_log[]`, proof-channel volatiles, state |

> **Spec correction:** a literal 64 KB grid cannot live "in bank `$7E`" (`$7E` holds low-WRAM +
> the 32 KB `m7_vbuf`). The 64 KB grid goes in the entirely-free **bank `$7F`**; it stays on the
> far-pointer path (`address_space(2)` reaches any 24-bit address). The 256×256 grid downsamples
> 2×2 to the 128×128 Mode-7 display, giving anti-aliasing the sparse point cloud benefits from.

**Coordinate map** — constant-coefficient so it folds identically on host (`int`=32) and target
(`int`=16): `coord = (int16_t)(((int32_t)v_q88 * HOP_GAIN) >> HOP_GSHIFT) + HOP_CENTER`, sized so the
measured `maxabs≈5857` maps to ~120 px from center 128 (margin to spare). A point outside `[0,G)` is
**dropped, not clamped** (a pure integer compare; clamping would smear a bright border). The
`(int32_t)` cast on the product is load-bearing (cf. `mandel.h:45`, `view.h:79`). Increment is
**8-bit saturating**: `if (s[i]!=255) s[i]++;` — host and target saturate identically (shared code).

### Per-frame loop (amortized — measured fact forces this)

A full 32 KB `vbuf` DMA is **~262k master cycles ≈ ~5 vblanks** (NTSC vblank ≈ 52k); `mandel-mode7`
only does it once at boot in force-blank. So amortize (the rendering handoff §"Timing & animation"
prescribes exactly this):

- **Active display** (CPU free; grid is WRAM): plot `P` orbit points (far RMW) **+** colorize **one**
  Mode-7 tile-row (16 tiles): far-load counts from `$7F` (2×2 box-sum), map count→palette index, write
  near `chrbuf[1024]` in tiled order (`mandel-mode7.c:139-143`).
- **Vblank** (PPU writable; DMA-only): DMA `chrbuf` (1 KB) → VRAM band (`dma_chr_to`,
  `mandel-mode7.c:61`) + rewrite the rotated 256-entry CGRAM palette (512 B, `cycle_palette` shape,
  `mandel-interactive.c:41`).

Full chr refresh = 16 frames (~0.27 s); the cheap 60 fps "wallpaper for the mind" shimmer is carried
by **CGRAM palette-cycling** every frame while the chr updates underneath at band rate. All PPU writes
stay strictly in vblank (access-window rule, handoff §1–§2).

### Function decomposition (register-pressure safe)

`+mos-a16 -Os` can crash the regalloc / emit undefined-physreg COPYs when one function holds many live
16-bit values; mitigation is `noinline` callees (handoff §4; `mandel.h:31-38`). Split so the orbit
intermediates and the 32-bit far pointer never co-exist live:

```
noinline hop_step(state*)            // one orbit iteration; updates x,y
noinline hop_plot(shadow, x, y)      // coord map + bounds-drop + far-RMW increment
         hop_plot_n(shadow, n)       // thin driver; live set ≈ {x,y,i}
         hop_colorize_band(...)      // far-load + 2×2 downsample → chrbuf
         hop_hash_far(shadow, len)   // far-load hash (proof channel)
```

Build every variant with `-mllvm -verify-machineinstrs`; keep a rep/sep disasm gate asserting native
16-bit fires on the far-RMW + coordinate transform (cf. `k_hopalong.sh`).

## Critical files

**New:**
- `examples/65816/hopalong.h` — **shared pure math, single source of truth** (host + target), the
  `mandel.h`/`view.h` pattern. Holds `SQRT_LUT`, params, `hop_step`, `hop_map`, `hop_color`
  (count→BGR555/index, shared so a host PNG and CGRAM agree), `hop_hash_far`. Stamp the plot body
  over a pointer qualifier — `HOP_DEFINE_PLOT(NAME, QUAL)`, exactly like
  `mode7.h:33` `M7_DEFINE_BUILD_VBUF(NAME, SRCQUAL)` — so the host instantiates with an empty
  qualifier (near `malloc`) and the target with `M7_FAR`; same body ⇒ host==target by construction.
- `examples/snes/blossom.h` — **pure interactive state machine** (the `view.h` analog): params/
  palette/scale/formula state + `blossom_step(state, pad)` + rolling-CRC fold. Included by the demo
  and by `jgxcheck.cpp`. No MMIO (host-linkable).
- `examples/snes/blossom.c` — the SNES demo `main`: boot gate, render loop, `apply_view`-style PPU
  writes, joypad via `snes_read_pad1()`.
- `dev/blossom.sh` — differential driver, cloned from `dev/mandel-interactive.sh`.

**Modified:**
- `examples/65816/k_hopalong.c` — pull `hop_step` from `hopalong.h`; **the `0x1BBC` orbit-fold gate
  must not regress** (re-run `dev/run.sh k_hopalong`).
- `dev/jgxcheck.cpp` — add a `JGX_BLOSSOM` mode mirroring the `JGX_VIEW` block (`jgxcheck.cpp:225-257`):
  replay `blossom.h` over the ROM's ground-truth pad log, assert identical CRC.
- `dev/run.sh` — register the `blossom` command (help text + dispatch, like `mandel-interactive`).
- `TODO.md` (#3 → in-progress/done), `docs/plans/2026-06-24-blossom-snes.md` (link this plan; mark the
  "greenfield" / "bank $7E" notes corrected).

**Reused as-is:** `examples/snes/mode7.h`, `platforms/snes/snes*.h`, `dev/jgxcheck.cpp` harness
plumbing, `dev/mandel-shot.lua`, `tools/snes-checksum.py`.

## Differential gates (the correctness bar)

Two independent channels, each a proven pattern:

1. **Deterministic grid-hash gate** (gates the new far-RMW path). At boot, in force-blank, *before any
   input*, plot exactly `K_GATE` points with classic params + the constant coordinate map; hash the
   whole far grid via far loads → `corpus_result`; assert `== host oracle golden`. Far grid ⇒
   **`+mos-a16`-only**: `host == +mos-a16 @ MAME == +mos-a16 @ bsnes-jg` (the `mandel-far`/`mandel-mode7`
   shape). Host oracle = `hopalong.h` compiled host-side (a small bake/oracle tool). Use the cheap
   `img_hash16` rotate-xor (`mandel.h:111`) over 64 KB, not full CRC16 (seconds under `+mos-a16`).
2. **Host-replayable param state machine** (gates the joypad math). Scripted controller sequence →
   ROM logs pads + a rolling `blossom_crc`; `jgxcheck` `JGX_BLOSSOM` replays `blossom.h` and asserts an
   identical CRC. Pure near math ⇒ builds **both** default-8bit and `+mos-a16` ⇒
   `host == default == +mos-a16`. **Fold only state-machine outputs, never the grid or per-frame point
   counts** (those differ by emulator frame timing — keeps the animated demo from flapping).

Plus screenshots: bsnes-jg framebuffer PNG + MAME snapshot under Xvfb (the `mandel-interactive.sh`
pipeline). Determinism: `snes_ppu_reset_blank()` first (stops bsnes power-on flap, handoff §3.1);
sample well after a deterministic plotted-point count, never at a frame edge (handoff §3.3).

## Staged implementation (de-risk order — fastest-to-confidence first)

1. **Shared header + headless far-RMW gate (no display).** Create `hopalong.h`; refactor `k_hopalong.c`
   onto it and confirm `0x1BBC` holds. Add `hop_plot_n` + `hop_hash_far` into the **Rung-A** 16 KB
   grid (`$7E2000`); assert `host == +mos-a16` on both emulators + rep/sep disasm gate. (This is
   "mandel-far for Blossom": the new codegen, zero display risk.)
2. **Static display, force-blank, full 32 KB DMA at boot** (the `mandel-mode7.c:96-110` path). Colorize
   converged grid → `m7_vbuf` → one DMA → `m7_show`. Validate the de-linearize/colorize with a
   **synthetic test grid first** (`MANDEL_TESTPAT` trick) before the slow plot. Proves grid→chr→pixel.
3. **Amortized animation.** Move colorize+DMA to per-band/per-vblank; plot during active display; add
   CGRAM palette-cycling. Graduate the grid to **Rung B** (256×256/64 KB in `$7F`, 2×2 downsample).
4. **Interactivity.** `blossom.h` state machine (joypad → params a/b/c, palette/color-mode, auto-scale,
   reset) + the `view.h`-style replay gate (`JGX_BLOSSOM`).
5. **Full gate + screenshots** wired into `dev/blossom.sh` (clone `dev/mandel-interactive.sh`); register
   in `dev/run.sh`; live-play task entry (like `task mandel-mame`).
6. *(Optional / gated stretch)* hardware multiplier (`$4202/$4203→$4216`) for the hot `b·x` — only if
   measured to win; gate per the project's "native op isn't automatically smaller" lesson.

## MUST MEASURE — do not assume (governing lesson #1)

1. Points plotted per active-display frame (`P`) — far-RMW cost is the dominant unknown.
2. Colorize-band time (far loads + 2×2 downsample) fits active display alongside the plot.
3. 1 KB chr DMA + 512 B CGRAM DMA fit one vblank (~9 of ~38 scanlines expected).
4. Confirm the full 32 KB DMA does **not** fit a vblank (~262k vs ~52k cycles) — the number forcing amortization.
5. Boot-gate hash time over 64 KB (`img_hash16` vs CRC16) — pick by measured seconds.
6. Does 256×256 supersample materially improve the 128×128 image? (justifies Rung B over Rung A).
7. Convergence: total points to a recognizable attractor; transient-skip count if early orbit looks bad.
8. Cross-emulator determinism: sample the CRC well after a fixed point count, never at a frame edge.
9. `-verify-machineinstrs` clean on each decomposed function under `-Os +mos-a16`; rep/sep gate fires.
10. Saturation: confirm the host-oracle saturation count, and that `K_GATE`'s hash matches host==target
    *with* saturation active (don't assume hot pixels stay below 255).

## Verification (run end-to-end; paste raw output + PASS/FAIL into this file as steps complete)

1. **Phase-1 gate not regressed:** `dev/run.sh k_hopalong` → still `RESULT: PASS … 0x1BBC`.

   ```
   PASS: native 16-bit active (12 rep / 13 sep brackets on the orbit arithmetic)
   PASS: host oracle corpus_result=0x1BBC == golden 0x1BBC
   default:   SMOKE: PASS addr=0x7E0200 len=2 got=0x1BBC (ran 120 ticks)
   +mos-a16:  SMOKE: PASS addr=0x7E0200 len=2 got=0x1BBC (ran 120 ticks)
   bsnes-jg:  SMOKE: PASS off=0x200 len=2 got=0x1BBC (ran 180 frames)
   RESULT: PASS — host == default == +mos-a16 (both emulators)
   ```
   **PASS** — `hopalong.h` refactor (hop_step shared) is value-preserving; `0x1BBC` holds.

2. **Headless far-RMW gate (Stage 1):** `dev/run.sh blossom-grid` → grid-hash `host == +mos-a16 @ MAME
   == +mos-a16 @ bsnes-jg`; far-RMW disasm gate; `-verify-machineinstrs` clean.

   ```
   host grid: maxabs=5895 clamps=0  cells_hit=1050/16384  saturated=0   golden = 0x19DE
   PASS: far RMW present (lda [dp]=2, sta [dp]=2)
   PASS: native 16-bit active (rep=20, sep=25)
   MAME:      SMOKE: PASS addr=0x7E0206 len=2 got=0x19DE (ran 750 ticks)
   bsnes-jg:  SMOKE: PASS off=0x206 len=2 got=0x19DE (ran 900 frames)
   RESULT: PASS — Hopalong far-RMW hit grid in high WRAM $7E2000; hash 0x19DE host == +mos-a16
   ```
   **PASS** — the new +mos-a16 customer (far read-modify-write at a runtime 24-bit index) is
   differentially verified. **Found + worked around a far-pointer miscompile en route:** a far constant
   fill is coalesced to the near `__memset` (wrong bank); fixed in `HOP_DEFINE_CLEAR` with a volatile
   far store; repro `examples/65816/far_memset.c`, diagnosis `docs/320-far-memset-miscompile.md`.

3. **Render correctness (Stage 2):** `dev/run.sh blossom` → grid-hash gate PASS on both emulators;
   bsnes-jg PNG + MAME snapshot written (`build/blossom-{jg,mame}.png`) and visually show the attractor.

   ```
   host grid: maxabs=5895 clamps=0  cells_hit=1115/16384  saturated=0   golden = 0x2FD2 (K=24000)
   bsnes-jg:  SMOKE: PASS off=0x206 len=2 got=0x2FD2 (ran 6000 frames)   -> build/blossom-jg.png
   MAME:      SHOT:  PASS corpus=0x2FD2 (snapshot at frame 6000)         -> build/blossom-mame.png
   RESULT: PASS — Hopalong attractor on SNES (far hit-grid + Mode 7 band DMA); MAME + bsnes-jg match host
   ```
   **PASS** — the attractor renders on-screen (Mode 7, 128×128 8bpp; the characteristic Hopalong lobes +
   central V + fractal edges, fire palette, white-hot dense core), identical on both emulators. Display
   path: far hit grid → per-band far-load into a NEAR `chrbuf` → DMA to VRAM char bytes (the `grid_hash`
   one-far-pointer idiom). **Note:** the originally-planned far→far whole-image build (`m7_vbuf` /
   `M7_DEFINE_BUILD_VBUF`) and a synthetic far constant-fill *test pattern* both derailed at runtime
   under `+mos-a16` (clean `-verify`, runtime runaway) — a second far-pointer pressure fragility beyond
   the Stage-1 `__memset` bug; not minimally reproduced (isolated repros pass), worked around by the
   band/near-staging structure, which is also the Stage-3 per-vblank unit.
4. **Interaction gate:** `VIEW`/`BLOSSOM: PASS` — host replay of `blossom.h` == ROM `blossom_crc`, for
   both default and `+mos-a16` builds.
5. **Live play:** `task blossom-mame` (or `task mandel-mame ROM=blossom`) — joypad changes params/
   palette/scale; reset works.
6. **Size delta recorded** for `examples/snes/blossom.c`, `+mos-a16` vs default (`.text` sections),
   documented like the Phase-1 `+14 B` note (a measurement, not a defect; the differential is the bar).
