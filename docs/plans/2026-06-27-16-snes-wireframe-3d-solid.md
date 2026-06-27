# #16 — SNES Wireframe 3-D Solid: rotation matrix · perspective divide · Bresenham lines

**Status:** PLANNED. Demo **#16** of the **compiler stress-test demo battery**
([ideas](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md#L68); `TODO.md` →
"Compiler stress-test demo battery" → **#16**). Supplements the standing guides (`~/SRC/CLAUDE.md`,
project `CLAUDE.md`, [`docs/agent-handoff.md`](../agent-handoff.md)). It is the **direct successor to the
Spirograph (#11)** demo and reuses that demo's entire `snesgfx` frame wholesale — same NEAR 2bpp bitmap
canvas, same tiled HUD, same differential machinery. Final step: **publish the verified `.sfc` as a
playable in-browser page at [https://biohack.net/3d-wireframe/](https://biohack.net/3d-wireframe/)** via the
`snes-rom-page` skill (the Spirograph P6 path).

## Context

A **wireframe 3-D solid** spins a polyhedron (cube / tetrahedron / octahedron / icosahedron) on screen by,
each frame: building a 3×3 rotation matrix from a sin/cos LUT, transforming each model vertex through it,
**perspective-projecting** each transformed vertex to 2-D with a divide, and drawing the model's edges as
**Bresenham lines**. It is the **3-D / linear-algebra** member of the battery, and its job is to **stress
the llvm-mos 65816 codegen on three corners at once** — a **3×3 matrix multiply** (Q8.8 fixed-point), a
**per-vertex perspective divide** (`__divsi3`/`__udivsi3` — the hard one Mandelbrot/Spirograph don't
exercise on the hot path), and **integer line rasterization** — while **rendering the computation itself**:
the spinning solid *is* the proof, not a side channel.

**Why it's a distinct test (not a re-skin of #11):** Spirograph stresses a sin/cos-LUT + two 16×16→32
multiplies *with no division on the hot path* (its one divide is the cold per-parameter gear ratio).
Wireframe puts the **divide on the hot path** (two per vertex, every frame) and adds a **3×3 matrix·matrix
and matrix·vector** shape that no demo here has. Per the coverage map it is the only battery member tagged
in **both** the `multiply` and the `division` rows besides the fractals (#16 ∈ {1–4,8,9–11,13,16} ∩
{2,13,15,16,19}). It is also on the "recommended first picks" list.

**Relation to existing demos (none duplicated):**
- **Mandelbrot** (`examples/snes/mandel-display.c`) — multiply-bound per-pixel, far Mode-7 framebuffer; no divide, no 3-D.
- **Spirograph** (`examples/snes/spirograph.c`) — sin/cos-LUT + fixed-point multiply, **accumulating** NEAR canvas, full 5-way bar. **The frame this demo reuses.**
- **Space Invaders** (`examples/snes/invaders.c`) — the `snesgfx` OOP sprite game.

## The codegen under test — and what is NEW vs already-built

The brief: *"3×3 matrix mul + projection divide + line raster."* Mapping each onto the existing toolbox:

| Stress | How this demo hits it | New code? |
|---|---|---|
| **3×3 matrix mul** (Q8.8) | `mat3_mul` composes axis rotations; `project()` does matrix·vector per vertex | **NEW** (`wire3d.h`) |
| **perspective divide** | `(rx·FOV)/z`, `(ry·FOV)/z` — two signed 32/16→16 divides per vertex | **NEW** (`wire3d.h`) |
| **line raster** (Bresenham) | `canvas_line(c, x0,y0, x1,y1, color)` | **ALREADY EXISTS** — `snesgfx/bitmap_canvas.h:110`, built for #11 |
| set-pixel into 2bpp tiles | `canvas_plot` | **ALREADY EXISTS** — `bitmap_canvas.h:95` |
| sin/cos LUT | the shared Q8.8 256-entry table | **ALREADY EXISTS** — `sincos.h` / inlined in `spiro.h` |

So the **entire renderer and almost the entire library are reuse**. The genuinely new artifact is one pure
math header (`examples/65816/wire3d.h`) — the rotation/projection pipeline and the polyhedron tables — plus
the thin demo/state/gate scaffolding that every battery demo gets. **This is a high-reuse, math-focused
demo**, which is exactly why it is a good next pick: maximal new *codegen coverage* (matrix + divide) for
minimal new *infrastructure*.

## Key design decision — stay NEAR, earn the full 5-way bar (inherit #11's choice)

Like Spirograph, the figure is a **thin set of edges**, so its canvas is small and **everything stays in
bank-0 low WRAM (no far pointers)**. The program then builds **default-8-bit AND `+mos-a16` AND
`+mos-xy16`**, earning the **richer 5-way differential bar**
(host == default@MAME == a16@MAME == xy16@MAME == default/a16@bsnes-jg) — not the a16-only bar Blossom is
stuck with. The brief's codegen targets are matrix-mul + divide, **not** far pointers; keeping it near is
the faithful choice *and* the stronger test (the same matrix+divide math compiled three ways must agree to
the byte). A far/high-res framebuffer would collapse the bar to a16-only and is **explicitly out of scope**
(§Risks).

## The one genuinely new rendering challenge — animate = clear + redraw (not accumulate)

This is the **single substantive difference** from Spirograph and the thing to de-risk first. Spirograph
*accumulates* (the rose blooms; `canvas_clear` only ever runs on a parameter change). A **spinning solid
must erase last frame and redraw this frame** — and `BitmapCanvas` is OR-only with a **contiguous
`[lo,hi]` dirty range** flushed at a `CANVAS_FLUSH_TILES = 64` (1 KB/v-blank) cap (`bitmap_canvas.h:28,66`).
A naïve full-canvas `canvas_clear()` re-DMAs all 256 tiles → 4 frames to fully flush → smear on a fast spin.

**De-risk ladder (measure each rung before climbing — Lesson 1):**

- **Rung 0 — "phosphor trail" mode (zero new render code).** Do **not** clear: let the spinning solid leave
  glowing trails (the existing accumulate semantics + the Blossom CGRAM palette-cycle for the fade). This is
  a genuinely attractive effect *and* the first-light path — it proves the whole math→project→line pipeline
  on screen with the canvas exactly as-is. Ship it as a selectable mode regardless.
- **Rung 1 — crisp spin, small canvas, one-v-blank re-DMA.** Clear+redraw every frame into a **96×96**
  (12×12 = 144 tiles) or **64×64** (8×8 = 64 tiles, fits the *current* 1 KB cap exactly) canvas, with
  `CANVAS_FLUSH_TILES` raised so a full re-DMA fits **one** v-blank. **MUST MEASURE** the real v-blank DMA
  budget (the 1 KB cap was a conservative Blossom-band choice; ~38 NTSC v-blank lines can move several KB).
- **Rung 2 — `canvas_clear_dirty()` (modest, reusable library add).** If 128×128 is wanted, add a clear that
  zeroes only the figure's last-frame `[lo,hi]` tile bytes and **leaves `lo/hi` set**, so redraw extends the
  range to the union and `emit()` re-DMAs exactly that union. A small **centred** solid touches a tight
  range. (Honest caveat: the contiguous-range model over-DMAs the full-width rows a vertical span crosses; a
  per-tile-row run flush is the escalation if even that doesn't fit — note it, don't pre-build it.)

The plan's **primary path is Rung 0 → Rung 1** (trail mode for first light, then crisp spin on a small
canvas with a measured flush cap). Rung 2 is the documented escalation. **Do not assume** a full re-DMA
fits one v-blank — measure it (MUST-MEASURE-3).

## The 3-D pipeline, in exact integer form (host == target by construction)

Floating point is banned (no FPU; host `double` ≠ target). Everything is fixed-point integer over the
existing **256-entry signed Q8.8 sine LUT** (`SINCOS[a] = round(256·sin(2π a/256))`, `1.0 == 256`;
`cos(a) = SINCOS[(a+64)&255]`). `int` is 16-bit on target, 32-bit on host, so **every narrowing is an
explicit `int16_t`/`int32_t`** and **every product that can exceed 16 bits is cast `(int32_t)` before
multiplying** (load-bearing — cf. `spiro.h`, `mandel.h:45`).

```c
/* A 3x3 rotation matrix, row-major, entries Q8.8 (1.0 == 256). */
typedef struct { int16_t m[9]; } mat3;

/* o = a . b  (Q8.8 . Q8.8 -> Q8.8) — the declared 3x3 MATRIX MULTIPLY stress.
   Composing the per-axis rotations is two of these per frame. */
WIRE3_FN void mat3_mul(const mat3 *a, const mat3 *b, mat3 *o) {
  for (uint8_t r = 0; r < 3; r++)
    for (uint8_t c = 0; c < 3; c++) {
      int32_t s = 0;
      for (uint8_t k = 0; k < 3; k++)
        s += (int32_t)a->m[r*3+k] * b->m[k*3+c];     /* Q8.8 * Q8.8 = Q16.16 */
      o->m[r*3+c] = (int16_t)(s >> 8);               /* back to Q8.8 */
    }
}

/* Build R = Rx . Ry . Rz from three uint8_t Euler angles (LUT phase). Each axis matrix's entries
   are {0, +-256(==1.0), +-cos, +-sin}; mat3_from_euler fills Rx,Ry,Rz then folds via mat3_mul. */
WIRE3_FN void mat3_from_euler(uint8_t ax, uint8_t ay, uint8_t az, mat3 *o);  /* 2x mat3_mul */

/* Transform a model vertex by R (Q8.8 . integer -> integer), then PERSPECTIVE-PROJECT with a
   per-vertex DIVIDE (the declared division stress). DIST > model radius keeps z>0. */
WIRE3_FN void project(const mat3 *R, const int16_t v[3], int16_t *sx, int16_t *sy) {
  int16_t rx = (int16_t)(((int32_t)R->m[0]*v[0] + (int32_t)R->m[1]*v[1] + (int32_t)R->m[2]*v[2]) >> 8);
  int16_t ry = (int16_t)(((int32_t)R->m[3]*v[0] + (int32_t)R->m[4]*v[1] + (int32_t)R->m[5]*v[2]) >> 8);
  int16_t rz = (int16_t)(((int32_t)R->m[6]*v[0] + (int32_t)R->m[7]*v[1] + (int32_t)R->m[8]*v[2]) >> 8);
  int16_t z  = (int16_t)(rz + WIRE3_DIST);
  *sx = (int16_t)(((int32_t)rx * WIRE3_FOV) / z);    /* <-- perspective divide */
  *sy = (int16_t)(((int32_t)ry * WIRE3_FOV) / z);    /* <-- perspective divide */
}
```

Per frame: **2× `mat3_mul`** (18 multiplies each) + per vertex **9 multiplies + 2 divides**. A 12-vertex
solid ⇒ ~144 multiplies + 24 divides/frame — precisely the declared **matrix-mul + projection-divide**
stress. `__mulsi3` (or the a16 widening-multiply path) and `__divsi3`/`__udivsi3` both fire on the hot path;
a disasm gate asserts it. All integer ⇒ `host == default == +mos-a16 == +mos-xy16` to the byte.

## Variations — "a spinning solid" is a *family* (the richness axis, like #11's curve families)

The same pipeline, with a different vertex/edge table, sweeps a zoo of polyhedra — each a slightly
different per-vertex count / edge-raster shape, all sharing the matrix+divide kernel. A `solid` field selects
the model; the differential gate covers **every** one (the corpus CRC folds a fixed spin per solid, so a
codegen defect in any shape is caught):

1. **Tetrahedron** — 4 verts, 6 edges (the minimal solid).
2. **Cube** — 8 verts, 12 edges (the classic; corners at `(±R,±R,±R)`).
3. **Octahedron** — 6 verts, 12 edges (the cube's dual; `(±R,0,0)` &c).
4. **Icosahedron** — 12 verts, 30 edges (golden-ratio vertices: cyclic perms of `(0,±a,±b)` with
   `b/a ≈ φ`, e.g. `a=20, b=32` → 1.60; integers ⇒ host==target trivially).

Each model is a committed `int16_t SOLID_V[][3]` + `uint8_t SOLID_E[][2]` table (asset-free, generated by a
small Python snippet in a comment, like the LUT). **Extra free axes** the same kernel gives: live **rotation
speed / direction** (D-pad), **projection distance** (L/R — dollies the perspective in/out, visibly
exaggerating/flattening the foreshortening, i.e. the divide), **auto-spin vs manual tumble**, palette
cycling, and the Rung-0 **trail toggle**.

## Visual mockup

**Screen layout** (BGMODE 1; BG3 carries both the centred canvas and the tiled HUD — the #11 layout):

```
┌──────────────────────────────────────────────┐
│  CUBE       SPD 03      DIST 60      AUTO    │  ← top HUD: solid / spin rate / proj. distance / mode
│                                              │
│              [ spinning solid — BG3 ]        │  ← BG3 BitmapCanvas, centred 96×96 box:
│               wireframe · Bresenham          │  ← the rotating polyhedron's edges
│                                              │
│  DPAD SPD    LR DIST    AY SOLID    SEL TRAIL│  ← bottom HUD: control legend
└──────────────────────────────────────────────┘
```

**What the canvas shows** — a cube mid-tumble (solid = front edges, dotted = the back face seen through it):

```
              ●──────────●
             ╱┆         ╱│
            ╱ ┆        ╱ │
           ●──────────●  │
           │  ●┄┄┄┄┄┄┄│┄┄●
           │ ╱        │ ╱
           │╱         │╱
           ●──────────●
```

**The four solids** (A/Y cycles; each a distinct vertex/edge table, all through the *same* matrix+divide
kernel — the richness axis, like #11's curve families):

```
   TETRA · 4v 6e        CUBE · 8v 12e        OCTA · 6v 12e        ICOSA · 12v 30e
        ●                 ●────────●              ●                   (30 edges — busy in
       ╱│╲               ╱│       ╱│             ╱│╲                   ASCII; renders cleanly
      ╱ │ ╲             ● │      ● │            ● │ ●                  on the 96×96 canvas as
     ╱  ●  ╲            │ ●──────│─●             ╲│╱                   a faceted sphere-like
    ●───────●           │╱       │╱               ●                   ball of triangles)
                        ●────────●
```

**The per-frame pipeline** — each stage maps to the codegen corner it stresses:

```
  model vertices        rotate (3×3 matrix)       project (divide)        raster (lines)
  int16 (x,y,z)   ─►    R = Rx·Ry·Rz       ─►     z  = rz + DIST   ─►     canvas_line()   ─►   BG3
  SOLID_V[N][3]         mat3_mul ×2               sx = (rx·FOV)/z         per model edge        2bpp
                        project: mat·vec          sy = (ry·FOV)/z         (ALREADY EXISTS)      canvas
  ──────────────        ──────────────────        ──────────────────      ────────────────
  table lookup          __mulsi3 / a16 mul        __divsi3 / __udivsi3    int shift / cmp
  (no codegen)          ◄ 3×3 MATRIX MUL          ◄ PERSPECTIVE DIVIDE    ◄ BRESENHAM (reuse)
```

The two middle columns — the **matrix multiply** and the **perspective divide** — are the new codegen this
demo exists to exercise; the outer columns (table lookup, Bresenham raster) are already-built reuse.

## Architecture — reuse the Spirograph `snesgfx` frame wholesale

Three `Drawable`s in one BGMODE_1 frame, the exact #11 layout (`spirograph.c:34-45,90-106`):

| Drawable | Layer | Role | Status |
|---|---|---|---|
| **`BitmapCanvas`** | BG3 (2bpp) | the wireframe plot surface — `canvas_line` the edges | **exists** (`bitmap_canvas.h`) |
| **`TextLayer`** | BG3 (co-tenant) | the `SOLID / speed / dist / mode` HUD + control legend | **exists** (`text_layer.h`) |
| **`SpriteSet`** | OBJ | optional: a small axis-gnomon or vertex markers | **exists** (`sprite_set.h`) |

`TM = TM_BG3 | TM_OBJ`. `Display`/`Scene`/`UploadQueue`/`VramAlloc`/`Controller` all reused unchanged. The
**only** library touch is the optional Rung-2 `canvas_clear_dirty()` add — and even that is gated behind
measurement.

### `examples/65816/wire3d.h` — pure 3-D math (single source of truth)

The host+target math core, included by `examples/snes/wireframe.h`, by `tools/wire3d-sim.c`, and by the
corpus slice: the Q8.8 LUT (re-`#include "sincos.h"` or inline as `spiro.h` does — keep host-linkable),
the `SOLID_V`/`SOLID_E` tables + `solid_nverts[]`/`solid_nedges[]`, `mat3_mul`, `mat3_from_euler`,
`project`, and **`wire3d_gate_crc()`** — fold the projected `(sx,sy)` of every vertex of every solid over a
**fixed** spin sequence (`WIRE3_GATE_FRAMES` of fixed `(ax,ay,az)` deltas) into a CRC16 (the `spiro_hash` /
`mandel.h` routine). **Hash the projected-vertex stream, never the canvas** (the canvas is display;
emulator frame-timing differs). Each kernel is `WIRE3_FN` (= `noinline static`, overridable) to bound a16
register pressure — same reason `spiro.h`'s `SPIRO_FN` and `hopalong.h`'s `HOP_FN` are noinline.

### `examples/snes/wireframe.h` — interactive state machine + HUD format

The `spirograph.h` analog: a **pure, HAL-free** state machine (host-linkable, no MMIO). `wire3d_view` =
`{ solid, ax, ay, az, dax, day, daz, dist, pal, trail, dirty }`. `wire3d_view_step(view, pad)` maps the
edge-detected pad: D-pad ±spin rates, L/R ±projection distance, A/Y cycle solid, X cycle palette, Select
toggle trail mode, Start reset. It folds a rolling `wire3d_crc` over its outputs **and** the Q-format→decimal
HUD bytes (the displayed numbers are host==target verified too — the Blossom/Spirograph HUD lesson).

### `examples/snes/wireframe.c` — the SNES demo `main`

Mirrors `spirograph.c` exactly: a `Display` + `BitmapCanvas` + `TextLayer` (+ optional gnomon `SpriteSet`),
`app_init` boot bracket, `corpus_result = wire3d_gate_crc()` self-verify, and a per-frame loop:
`controller_poll` → `wire3d_view_step` → (clear per the trail mode) → `mat3_from_euler` →
**`noinline draw_frame()`**: for each vertex `project()`, for each edge `canvas_line()` between the two
projected endpoints (`CX+sx, CY-sy`) → `hud_update` on change → `display_frame`. No bare `snes_`/`REG_`
outside methods.

### Frame loop budget (amortize — transform/raster in active display, DMA in v-blank)

`game_update` (active display, CPU free): poll; step; clear (Rung-1/2) or not (Rung-0); build matrix;
transform+project ≤12 vertices; raster ≤30 edges via `canvas_line`. `display_frame` (v-blank): `scene_emit`
(virtual calls) + `upq_flush` — the dirty canvas tiles (capped/measured to fit one v-blank) + dirty HUD rows
+ optional OAM + rotating CGRAM. First frame releases force-blank last (deterministic boot). `noinline` the
register-heavy `draw_frame`/`project`/`mat3_mul`; always `-mllvm -verify-machineinstrs`.

## Differential gates (the correctness bar)

Same proven channels as #11:

1. **Deterministic projected-vertex CRC** (gates the matrix-mul + divide hot loop). At boot, in force-blank,
   *before any input*, run `wire3d_gate_crc` over a fixed spin for **each solid**; fold to `corpus_result`;
   assert `== host oracle golden` (`tools/wire3d-sim.c`). All-integer NEAR ⇒ **full 5-way**. **Disasm gate:**
   the matrix/vertex `__mulsi3` (or a16 widening-mul) present **and** the perspective-divide
   `__divsi3`/`__udivsi3` present on the hot path (and under a16 the native-16 `rep`/`sep` bracket).
2. **Host-replayable controller CRC** (gates the joypad + HUD-format math). A **deterministic scripted pad
   sequence** → a corpus slice (`wire3d_ctrl_sim.c`) folds `wire3d.h`'s state-machine + HUD-format outputs to
   `corpus_result` — the #11 `spiro_ctrl_sim` pattern (same host==target guarantee, no `jgxcheck` change,
   earns the full 5-way bar for free). **Fold state + format outputs only, never the canvas or per-frame
   counts** (those differ by emulator frame timing).
3. **Corpus 5-way slices:** `examples/snes/corpus/wire3d_sim.c` + `wire3d_ctrl_sim.c` + their `expected.tsv`
   rows → `dev/run.sh corpus-a16` gives `default == a16 == xy16` on MAME + bsnes-jg + dual
   `-verify-machineinstrs` for free. Shared headers ⇒ the sites can't drift.
4. **Screenshots:** bsnes-jg framebuffer PNG + MAME `video:snapshot` under Xvfb (the `dev/spirograph.sh`
   pipeline cloned to `dev/wireframe.sh`/`dev/wireframe.lua`). `snes_ppu_reset_blank()` first; sample after a
   **fixed** spin frame count, never at a frame edge; **3× bsnes byte-identical** capture.

## Staged implementation (de-risk order — fastest-to-confidence first)

Work on a `wt/321-wireframe` worktree off `main` (feature work, not an investigation — durable deliverable),
per the project worktree workflow; reach the main checkout's built toolchain via `CLANG`/`OBJDUMP` env
overrides or `cp -al build/` (handoff / `docs/howto-feature-worktree.md`).

1. **Shared math + headless projected-vertex gate (no display).** Write `examples/65816/wire3d.h`
   (LUT include, `mat3_*`, `project`, solid tables, `wire3d_gate_crc`) + `tools/wire3d-sim.c` host oracle +
   the `corpus/wire3d_sim.c` slice. Gate `host == default == +mos-a16 == +mos-xy16` on both emulators + the
   **mul *and* div** disasm gate + `-verify` clean. *This is the whole compiler test; zero display risk.*
2. **Rung-0 trail render (no clear).** Reuse `BitmapCanvas` as-is: per frame build matrix, project, line the
   edges, **don't clear** → spinning solid with phosphor trails + CGRAM palette fade. Proves the full
   pipeline on screen with zero new render code. Validate `canvas_line` endpoints with one static solid first.
3. **Rung-1 crisp spin.** Add per-frame clear+redraw on a 96×96 (or 64×64) canvas; raise/measure
   `CANVAS_FLUSH_TILES` so a full re-DMA fits one v-blank (MUST-MEASURE-3). If 128×128 wanted → Rung-2
   `canvas_clear_dirty()`.
4. **HUD + interactivity.** Wire `wireframe.h` (`Controller` → solid / spin rate / distance / palette / trail
   toggle / reset) + the `SOLID/speed/dist/mode` HUD bars (reuse `text_layer.h`/`font8.h`); add the
   `corpus/wire3d_ctrl_sim.c` controller slice.
5. **Full gate + screenshots + corpus** wired into `dev/wireframe.sh` (clone `dev/spirograph.sh`); register in
   `dev/run.sh`; add both corpus slices + `expected.tsv` rows; live-play task entry.
6. **Publish a playable in-browser page** at
   **[https://biohack.net/3d-wireframe/](https://biohack.net/3d-wireframe/)** via the **`snes-rom-page`**
   skill (the Spirograph P6 path): copies the shared bsnes-jg WASM player, adds the ROM + a manifest entry,
   scaffolds a `/3d-wireframe` Astro page (centred player + controls + instructions). **Ship the `+mos-a16`
   ROM** (`build/wireframe.sfc`) — it showcases the #321 native-16-bit codegen *and* is the same all-near
   program the 5-way gate proved. **Hard prerequisite:** pass the **bsnes 3×-capture determinism check**
   (the page runs bsnes-jg WASM). The ROM boots into a deterministic auto-spin and hands control to the
   player. **Production deploy is outward + guardrail-gated** — `cd ~/SRC/biohack.net && task publish TAG=v…`
   **awaits explicit user OK**; the page is built + screenshot-verified + committed first.
7. *(Optional / gated stretch — Lesson 2: only if measured to win.)* the SNES **hardware divider**
   (`$4204/$4205 ÷ $4206 → $4214`, 16/8→16) for the perspective divide and/or the **hardware multiplier**
   (`$4202·$4203 → $4216`) for the matrix products — gate per "a native op isn't automatically smaller";
   the portable C `/`,`*` baseline is what earns the 5-way bar, and any hardware path must produce the
   byte-identical truncating quotient (sign handling included) or it breaks the differential. Likewise a
   far/high-res framebuffer is a *separate* demo (drops the bar to a16-only).

## MUST MEASURE — do not assume (governing Lesson 1)

1. **Per-frame cost:** is the matrix·vector + divide the bottleneck, or the line raster? (decides whether
   step 7's hardware divider/multiplier is worth building — measure before building it).
2. **Spin smoothness vs vertex count:** does a 12-vertex/30-edge icosahedron transform+raster+DMA inside one
   frame, or must the spin step every 2–3 frames? (sets the rotation delta per frame).
3. **Clear/redraw DMA throughput** (the central new risk, §"one new challenge"): does a full canvas re-DMA
   fit **one** v-blank at 96×96 / 64×64 with a raised `CANVAS_FLUSH_TILES`, or is Rung-2
   `canvas_clear_dirty()` needed for 128×128? Measure the real v-blank DMA budget — don't trust the 1 KB cap.
4. **WRAM budget:** the canvas chr shadow (4 KB at 128×128, ~2.3 KB at 96×96, 1 KB at 64×64) + HUD shadows +
   state, all inside `$0200–$1FFF`.
5. **`__mulsi3`/`__divsi3` vs the a16 widening paths:** byte/cycle delta on the hot loop (size note, not a
   gate); confirm the divide actually lowers to the library routine (or the gated hardware path).
6. **Cross-emulator determinism:** sample the projected-vertex CRC after a **fixed** spin frame count, never
   at a frame edge; confirm the controller CRC is timing-insensitive (state-only fold).
7. **`-mllvm -verify-machineinstrs` clean** on each `noinline` `mat3_mul` / `project` / `draw_frame` under
   `-Os` `+mos-a16` **and** `+mos-xy16` (the register-pressure risk surface — 9 live Q8.8 entries + 32-bit
   products + the divide).
8. **Visual:** does each solid (tetra/cube/octa/icosa) render a recognizable, distinct spinning figure on
   **both** emulators, with believable perspective foreshortening as `dist` changes?

## Verification (run end-to-end during `[verify]`; paste raw output + PASS/FAIL below each — do not pre-fill)

1. **Host determinism:** `cc -O2 -I examples/65816 tools/wire3d-sim.c -o build/wire3d-sim && build/wire3d-sim`
   prints a stable hash twice.

   ```
   (to run)
   ```

2. **5-way differential (3-D math + controller math):** `dev/run.sh corpus-a16` — `wire3d_sim`
   (projected-vertex hash, fixed spin × 4 solids) and `wire3d_ctrl_sim` (controller + HUD-format over a
   scripted pad seq) both `host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg`;
   dual `-verify` clean; existing corpus slices unregressed.

   ```
   (to run)
   ```

3. **On-console render + disasm gate + both-emulator screenshot:** `dev/run.sh wireframe` — the on-screen
   `+mos-a16` ROM self-verifies `corpus_result == host` on both emulators; the disasm gate confirms the hot
   loop is the declared codegen (matrix `__mulsi3` **+ perspective `__divsi3`/`__udivsi3`** + native-16
   `rep`/`sep`); bsnes 3× byte-identical; both framebuffer screenshots written.

   ```
   (to run)
   ```

4. **`-verify-machineinstrs` clean** for `wireframe.c` under `+mos-a16` AND `+mos-xy16` (and default).

   ```
   (to run)
   ```

5. **No-bare-functions audit:** `grep -nE 'REG_|snes_|upq_|vram_' examples/snes/wireframe.c` — hits only
   inside `app_init`/methods; `main` only constructs + calls methods.

   ```
   (to run)
   ```

6. **Visual:** `build/wireframe-{jg,mame}.png` — a recognizable spinning solid in the centred plot box with
   the live `SOLID / speed / dist / mode` HUD; the four solids render as distinct figures, identical on both
   emulators.

   ```
   (to run — embed screenshots/wireframe-*.png)
   ```

7. **Publish (P6):** `snes-rom-page` scaffolds `/3d-wireframe` on `biohack.net` with `build/wireframe.sfc`
   (`+mos-a16`) + a Verify-fidelity selfcheck; built + headless-screenshot-verified; deployed via
   `task publish TAG=v…` **on explicit user OK**; `https://biohack.net/3d-wireframe/` returns HTTP 200.

   ```
   (to run — user-authorized)
   ```

## Risks

- **R1 — clear/redraw DMA throughput** (the central new risk): a full-canvas re-DMA may not fit one v-blank
  at the 1 KB cap → smeared spin. Mitigation: the **Rung-0 trail mode needs no clear** (always works) and is
  the first-light path; Rung-1 small canvas + measured raised cap; Rung-2 `canvas_clear_dirty()` for the
  union range. **Measure before committing a size** (MUST-MEASURE-3).
- **R2 — `+mos-a16` / `+mos-xy16` register pressure** in `mat3_mul`/`project`/`draw_frame` (9 live Q8.8
  entries + 32-bit products + the divide) → allocator crash or undefined-physreg COPY (caught only by
  `-verify-machineinstrs`). Mitigation: `noinline` those kernels (the `WIRE3_FN` idiom); the **default-8-bit
  build is the safety net**.
- **R3 — perspective-divide hazards:** `z` must stay strictly `> 0` (DIST > model radius, clamp `z` to a
  floor) or a near-zero/negative `z` blows the projection (and a `/0` traps). Any un-cast `int` intermediate
  (especially `rx*FOV` overflowing 16-bit before the divide) diverges host vs target. Signed-divide
  truncation must match between the C baseline and any hardware-divider path. A default/a16/xy16 CRC mismatch
  is a **real codegen defect** — triage it (don't shrug it off).
- **R4 — determinism traps:** never CRC the raw struct or the canvas (host≠target padding; canvas is
  display); use the serialized projected-vertex / state stream. Sample at a fixed spin frame count.
- **R5 — the tempting far/high-res escalation.** A 4bpp / 256×256 / bank-`$7F` framebuffer (for anti-aliased
  or filled faces) would need far pointers, drop the bar to a16-only, and re-expose Blossom's far-pointer
  fragilities. Keep the canvas NEAR; ship any far/filled-solid variant as a *separate* demo.
- **R6 — screenshot capture:** MAME needs Xvfb; freeze-at-fixed-N defuses cross-core frame races;
  `snes_ppu_reset_blank` is mandatory or bsnes screenshots flap (handoff §3.1).
- **R7 — model scale / FOV tuning:** wrong `MODEL_R`/`FOV`/`DIST` either clips the solid off-canvas or
  shrinks it to a dot. Tune so the largest solid (icosa) fills ~⅔ of the canvas at the nominal distance.
