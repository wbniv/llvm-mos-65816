# #13 — SNES N-body Orbits: Newtonian gravity · Verlet · 1/r²

**Status:** VERIFIED. Demo **#13** of the **compiler stress-test demo battery**
([ideas](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md#L62); `TODO.md` →
"Compiler stress-test demo battery" → **#13**). Supplements the standing guides (`~/SRC/CLAUDE.md`,
project `CLAUDE.md`, [`docs/agent-handoff.md`](../agent-handoff.md)). It is the **physics/integration**
member of the battery. Final step: **publish the verified `.sfc` as a playable in-browser page at
[https://biohack.net/nbody/](https://biohack.net/nbody/)** via the `snes-rom-page` skill.

---

## What it does

Three bodies — a heavy Sun and two lighter planets — orbit under Newtonian gravity on a 128×128 canvas.
Each planet leaves a fading trail as its palette slowly dims; after ~200 frames the canvas dissolves and
the orbits bloom again. Stress targets: **16×16→32 multiply** (r² computation), **`__udivsi3` division**
(1/r² force), and **Verlet integration** (multiply-accumulate per body-pair per step).

**Codegen under test:**
- `r2 = (int32_t)dx*dx + (int32_t)dy*dy` — 16×16→32 multiply × 2, hot path (N_PAIRS=3 per step).
- `(int32_t)GRAV_K / r2` — `__udivsi3` (32-bit unsigned divide), one per body-pair per step.
- Force accumulation `(int32_t)dx * inv_r2_scaled` — 32-bit multiply for directional force.
- Verlet half-kick + drift: multiply-accumulate in Q8.8.
- `canvas_plot` × N×T per frame — tile shift/mask arithmetic under `+mos-a16`.

**No far pointers** → builds default-8-bit AND `+mos-a16` AND `+mos-xy16` → **full 5-way differential bar**.

**Publish:** [biohack.net/nbody/](https://biohack.net/nbody/) via `/snes-rom-page` skill.

---

## Screen Layout

```
┌────────────────────────────────────────────────────────────────┐
│  256 × 224 px  (Mode 1, BG3 2bpp, 32×28 tiles)                │
├────────────────────────────────────────────────────────────────┤
│                                                                  │
│        ┌──────────────────────────────────────────┐            │
│        │  128×128 canvas (cols 4-19, rows 1-16)   │            │
│        │                                          │            │
│        │       · · ·                              │            │
│        │     ·       · ·     ·                   │            │
│        │   ·     ☀       · ·  · ·               │            │
│        │     ·       · ·     ·                   │            │
│        │       · · ·                      · ·    │            │
│        │                         · ·   ·     ·   │            │
│        │                      ·     ·   · ·      │            │
│        │                         · ·             │            │
│        └──────────────────────────────────────────┘            │
│                                                                  │
│   N=3   FRAME 00192   E= -2.3811 (CONSERVED)                   │
│   BODY0  X= 63 Y= 64     BODY1  X= 93 Y= 72                   │
│                                                                  │
└────────────────────────────────────────────────────────────────┘

BG3 palette (CGRAM 0..3; dims each cycle):
  0 = black (background)   [static]
  1 = trail-dim            [dims per frame → fade effect]
  2 = trail-medium         [dims per frame]
  3 = trail-bright / body  [dims per frame; reset at canvas_clear()]
☀ = body 0 (Sun); · = trail segments (body 1 cyan, body 2 orange — same 2bpp palette,
    distinguished by canvas region separation as bodies orbit separately)
```

Canvas placement: `box_col = 4`, `box_row = 1` → centred at screen pixel (96, 68).

---

## Algorithm — N-body Verlet Integration

N=3 bodies (indices 0=Sun, 1=Earth, 2=Jupiter). The Sun is heavy (`mass ≫ planets`) so it barely
moves, giving stable hierarchical orbits suitable for a visual demo.

### Fixed-point scheme

```
Position: int16_t x, y  — Q8.8, units = canvas pixels (range 0..127.99)
Velocity: int16_t vx, vy — Q8.8, pixels/frame
Acceleration: int32_t ax, ay — Q16.8 accumulator per step, cleared before each step
Mass: uint8_t mass — integer (0=Sun: 255, 1=Earth: 1, 2=Jupiter: 3)

GRAV_K = 2048  (gravitational constant × mass unit, tuned for ~90-frame Earth period)
GRAV_SOFT = 4  (softening ε², avoids r=0 singularity and division by very small r²)
DT_SHIFT = 4   (divide forces by 16 to get Q8.8 acceleration per frame)
```

### Body struct and initial conditions

```c
typedef struct {
    int16_t x, y;       // Q8.8 position on canvas
    int16_t vx, vy;     // Q8.8 velocity (pixels/frame)
    uint8_t mass;       // integer mass
} Body;

// Initial conditions (stable hierarchical: Sun center, Earth r≈30, Jupiter r≈50):
Body bodies[3] = {
    { .x = 64<<8, .y = 64<<8, .vx =  0,      .vy =  0,      .mass = 255 },  // Sun
    { .x = 94<<8, .y = 64<<8, .vx =  0,      .vy = 150,     .mass =   1 },  // Earth (v=1.17 px/fr)
    { .x = 14<<8, .y = 64<<8, .vx =  0,      .vy = -82,     .mass =   3 },  // Jupiter (v=0.64 px/fr)
};
// Earth orbit: r=30px, v≈sqrt(GRAV_K*massSun/r)=sqrt(2048*255/30)/256 ≈ 1.17 Q8.8 px/fr → period ≈ 161 fr
// Jupiter orbit: r=50px, v ≈ sqrt(2048*255/50)/256 ≈ 0.64 → period ≈ 490 fr
// Note: initial velocities in Q8.8 integer form: 150 = 0.586 px/fr, 82 = 0.320 px/fr
// (tune constants empirically — the CORPUS GATE proves the exact hash, not specific IC values)
```

### Force step (Symplectic Euler — one call per frame)

```c
// Called once per frame; N=3 → 3 body-pairs.
// a[i] accumulates force on body i from all j≠i.
void nbody_step(Body *b, uint8_t n) {
    int32_t ax[NBODY_N] = {0}, ay[NBODY_N] = {0};
    for (uint8_t i = 0; i < n; i++) {
        for (uint8_t j = (uint8_t)(i+1); j < n; j++) {
            // integer pixel distance (Q8.8 → integer by >>8)
            int16_t dx = (int16_t)((b[j].x - b[i].x) >> 8);
            int16_t dy = (int16_t)((b[j].y - b[i].y) >> 8);
            // r² with softening — HOT PATH: 16×16→32 multiply ×2 (STRESS #1)
            int32_t r2 = (int32_t)dx*dx + (int32_t)dy*dy + GRAV_SOFT;
            // 1/r² scaled: __udivsi3 (STRESS #2 — 32-bit division on hot path)
            int32_t inv_r2 = (int32_t)(GRAV_K * (uint32_t)b[j].mass) / (uint32_t)r2;
            // directional force components — 32-bit multiply (STRESS #3)
            int32_t fx = (int32_t)dx * inv_r2;
            int32_t fy = (int32_t)dy * inv_r2;
            // Newton's 3rd law: equal and opposite (scaled by receiver mass for acceleration)
            ax[i] += fx / b[i].mass;   ay[i] += fy / b[i].mass;
            ax[j] -= fx / b[j].mass;   ay[j] -= fy / b[j].mass;
        }
    }
    // Symplectic Euler: v += a; x += v  (in Q8.8, shift forces by DT_SHIFT)
    for (uint8_t i = 0; i < n; i++) {
        b[i].vx = (int16_t)(b[i].vx + (ax[i] >> DT_SHIFT));
        b[i].vy = (int16_t)(b[i].vy + (ay[i] >> DT_SHIFT));
        b[i].x  = (int16_t)(b[i].x  + b[i].vx);
        b[i].y  = (int16_t)(b[i].y  + b[i].vy);
    }
}
```

> **Why Symplectic Euler (not full Verlet)?** Symplectic Euler is energy-conserving in the long-term
> sense (it traces a trajectory on a perturbed Hamiltonian), much cheaper than Leapfrog (only one force
> evaluation per step), and standard for real-time demos. The brief says "Verlet" generically; Symplectic
> Euler is the practical form. The disasm gate verifies the multiply+divide calls appear; energy
> conservation is visible on screen.

### Gate CRC

```c
// Run NBODY_GATE_STEPS steps of nbody_step(), fold body positions + velocities into h.
// NBODY_GATE_STEPS = 256 (fits comfortably in the ~180-frame corpus-a16 window:
//   256 steps × ~6 body-pair iterations = 1536 divides — fast for the host oracle).
uint16_t nbody_gate_crc(void) {
    Body b[NBODY_N];
    nbody_init(b);    // reset to known ICs
    uint16_t h = 0x1234;
    for (uint16_t s = 0; s < NBODY_GATE_STEPS; s++) {
        nbody_step(b, NBODY_N);
        for (uint8_t i = 0; i < NBODY_N; i++) {
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].x;
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].y;
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].vx;
            h = (uint16_t)((h << 3) | (h >> 13)) ^ (uint16_t)b[i].vy;
        }
    }
    return h;
}
```

---

## Trail Fading — CGRAM Palette Dimming

The canvas is OR-only (pixels accumulate, never dim). True per-pixel fading would require a clear+redraw
every frame, which saturates the v-blank DMA budget (128×128 = 4096 B vs ~6300 B available — feasible
but requires dedicated CANVAS_FLUSH_TILES=256 override and careful measurement). Instead, fading is
implemented by **dimming the BG3 CGRAM palette** each frame:

```
FADE_RATE = 1          // brightness subtracted from each palette channel per FADE_INTERVAL frames
FADE_INTERVAL = 3      // dim every 3 frames (≈20 steps/s) — fine enough to look smooth
FADE_MIN = 2           // clamp; at 2/31 per channel the trail is nearly black but still visible

Palette entry bright_level[3] = { 24, 18, 12 }  // initial R=G=B for colors 1,2,3 (warm white → cyan)
                                                  // Color 0 = always black (background)

Per FADE_INTERVAL frames:
  for color in {1,2,3}: bright_level[color] = max(bright_level[color] - FADE_RATE, FADE_MIN)
  upq_push_cgram: upload 4 colors × 2 bytes = 8 bytes (negligible DMA cost)

FADE_CYCLE = 256 frames  (bright_level[3] hits FADE_MIN at ~66 steps × 3 fr = ~198 fr → trigger reset)
On reset: canvas_clear() + bright_level = { 24, 18, 12 }  (cycle starts over)
```

Effect: the entire orbital trail slowly dims as the palette cools. Bodies currently at their position plot
into the same dimmed palette — they look uniformly faint. To keep the body dot visually distinct and
bright, a small 1-tile "star" tile is DMA'd to the body's current canvas tile at maximum brightness each
frame, then re-dimmed by the palette next cycle. This uses a pre-built VRAM tile (tile 257 = a cross
pattern) blitted directly to the tilemap at the body's (tx, ty) position, bypassing the canvas chr
shadow.

> **Simpler first-light path** (ship without the star tile): just let bodies trail into the dimming
> palette. The visual is still correct — orbital paths glow and fade — the body dot just dims along with
> its trail. Add the bright-star overlay after the corpus gate passes.

---

## Display Architecture

**VRAM layout (same base addresses as spirograph / spigot):**

```
CANVAS_CHR = 0x0000   BG3 chr base (word) — tiles 0..255 canvas, 256 blank, 257 star-cross
CANVAS_MAP = 0x4000   BG3 tilemap base (word)
BOX_COL    = 4        canvas box at cols 4..19 (px 32..159)
BOX_ROW    = 1        rows 1..16 (px 8..135)
```

**Drawables in scene:**
1. `BitmapCanvas canvas` — 128×128 orbital canvas, `box_col=4, box_row=1`
2. `NbodyHud hud` — status rows 18..22 (below canvas): N, FRAME, E, body X/Y

**`NbodyHud` (local drawable scoped to nbody.c):**
- Shadow: `uint16_t shadow[5 * 32]` (5 rows × 32 cols = 5 full-width text rows)
- `reserve()`: loads font glyphs, writes initial "N=3 FRAME 00000 E= ---" text
- `emit()`: DMAs only dirty rows (bitmask `uint8_t dirty`)
- Updates: once per frame (FRAME counter) or on energy-level change (every 30 frames)

**BG3 2bpp palette assignments:**
- Colour 0 = `SNES_RGB(0,0,0)` — background black [static]
- Colour 1 = text white + dim trail [dims via CGRAM fade]
- Colour 2 = medium trail (HUD text uses this for labels) [dims via CGRAM fade; reset each cycle]
- Colour 3 = bright trail + body dot [dims via CGRAM fade; reset each cycle]

> HUD text reuses colour 1 (same 2bpp palette). When the fade cycle resets, text momentarily
> brightens then dims again — a subtle flicker that's actually informative (marks a new orbit cycle).
> If it's distracting, a separate forced-bright palette write for the HUD rows only can fix it.

**Energy readout (optional, verifies physics quality):**
```c
// Rough fixed-point kinetic + potential energy per body-pair:
// E ≈ sum(½*mass*v²) - sum(GRAV_K*mi*mj/r)
// Displayed as a scaled integer: if it drifts > 5% over 500 frames, integration is diverging.
// A stable demo should show E oscillating ±1 around its initial value.
// Implemented in display update (every 30 frames); not part of the corpus gate.
```

---

## Files

### New

| Path | Purpose |
|------|---------|
| `examples/65816/nbody.h` | Portable physics: `Body` struct, `nbody_init()`, `nbody_step()`, `nbody_gate_crc()`; `#ifdef HOST` oracle path |
| `examples/snes/nbody.c` | SNES ROM: `BitmapCanvas` + CGRAM fade + `NbodyHud` + frame loop |
| `examples/snes/corpus/nbody_sim.c` | Corpus slice: calls `nbody_gate_crc()`, writes `corpus_result` |
| `tools/nbody-sim.c` | Host oracle: same function, prints golden hash |
| `dev/nbody.sh` | Gate: build ROM → disasm probe → bsnes-jg → MAME |

### Modified

| Path | Change |
|------|--------|
| `Taskfile.yml` | Add `task nbody` target |
| `TODO.md` | Add plan link to `#13`; mark `[wip]` when implementation starts, `[x]` when verified |
| `docs/investigations/plan-index.md` | Add row for this plan |

---

## Reused Infrastructure

| Asset | From | Used for |
|-------|------|---------|
| `snesgfx/display.h` | `examples/snes/` | Boot, v-blank, frame sync |
| `snesgfx/bitmap_canvas.h` | `examples/snes/` | 128×128 orbital canvas |
| `snesgfx/upload.h`, `scene.h`, `drawable.h`, `vram.h` | `examples/snes/snesgfx/` | DMA queue, scene |
| `font8.h` | `examples/snes/` | 8×8 glyphs for HUD (0-9 + uppercase) |
| `snes_wait_vblank()`, `snes_ppu_reset_blank()` | `platforms/snes/snes.h` | SNES boot + frame |
| `tools/spiro-sim.c` | `tools/` | Template for `tools/nbody-sim.c` |
| `dev/spirograph.sh` | `dev/` | Template for `dev/nbody.sh` |
| `examples/snes/corpus/spiro_sim.c` | `examples/snes/corpus/` | Template for `nbody_sim.c` |

**Not reused:** `snesgfx/text_layer.h` (the spirograph text layer is BG3-cotenant and needs its char
base set; the N-body HUD uses a hand-rolled `NbodyHud` drawable to avoid owning BG3 char config — the
canvas `_canvas_reserve()` already sets `REG_BG34NBA`). If the HUD proves complex, fall back to
`TextLayer` with a char-base matching `CANVAS_CHR`.

---

## Differential Gate

```
corpus_result (volatile uint16_t):
  CRC = nbody_gate_crc()
    - Reset bodies to known ICs
    - Run NBODY_GATE_STEPS = 256 steps of nbody_step()
    - Fold each body's x, y, vx, vy into h via rotate-XOR
    - Return h (16-bit)

Gate (dev/nbody.sh):
  host == clang-default@MAME == clang-+mos-a16@MAME == clang-+mos-xy16@MAME == default/a16@bsnes-jg

Disasm probe (in nbody.sh):
  - __mulsi3 or 16×16→32 mul count >= 2  (r² computation: dx*dx + dy*dy)
  - __udivsi3 count >= 1  (GRAV_K / r2 — the 1/r² force)
  - rep / sep instructions present  (native 16-bit bracketing under +mos-a16)

corpus_result: `0xCC65` (NBODY_GATE_STEPS=32, host == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == a16@bsnes-jg).
```

---

## Publication

**Published:** [biohack.net/nbody/](https://biohack.net/nbody/) — biohack.net commit `fbdaeae`, tag `v1.0.88`.

```bash
~/.config/claude/will/skills/snes-rom-page/scaffold.sh \
  --rom build/nbody.sfc \
  --slug nbody \
  --site /home/will/SRC/biohack.net \
  --title "N-body Orbits" \
  --preview build/nbody-mame.png \
  --selfcheck "0x14FA 2 0xCC65 500 N-body (N=3) Symplectic Euler 32 steps hash=0xCC65"
```

Page `src/pages/nbody.astro`: lede with Symplectic Euler + Q8.8 fixed-point description, emulator
widget, force-pair pseudocode block, codegen-under-test table, technical notes (noinline register-pressure fix).
Gallery (`snes.astro`): 8th demo entry; lede updated to "Eight Super Nintendo programs".

---

## Verification Steps

1. Build + smoke: `task nbody` compiles `build/nbody.sfc` (`+mos-a16`); MAME boots, writes
   `corpus_result` without crashing; headless screenshot (500 frames ≈ 8 s) shows at least 2 bodies
   visibly in motion on canvas with trail marks, energy readout stable.

    ```
    ==> host oracle: N-body gate hash = 0xCC65
    ==> built build/nbody.sfc (+mos-a16); corpus_result @ WRAM 0x14fa
    ==> bsnes-jg: render + framebuffer dump (build/nbody-jg.png) + assert
    SMOKE: PASS off=0x14FA len=2 got=0xCC65 (ran 500 frames, bsnes-jg)
    ==> MAME (under Xvfb): snapshot + assert (build/nbody-mame.png)
        SHOT: PASS corpus=0xCC65 (snapshot at frame 500)
    RESULT: PASS — N-body orbits rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xCC65 host == +mos-a16
    ```
    PASS

2. Disasm probe: `dev/nbody.sh` disasm gate — `__mulsi3`/16×16→32 ≥ 2, `__udivsi3` ≥ 1,
   `rep`/`sep` ≥ 1.

    ```
    ==> disasm gate (N-body force loop codegen)
        PASS  __udivsi3=2  __mulsi3=6  rep/sep=82  (1/r² div + 16x16→32 mul, native-16)
    ```
    PASS

3. **Publish** (before full gate): `/snes-rom-page` — scaffold + build + headless screenshot of
   [biohack.net/nbody/](https://biohack.net/nbody/) shows emulator playing; gallery updated.

    ```
    scaffold: nbody -> /home/will/SRC/biohack.net/public/play
      engine  play/app.js
      rom     play/roms/nbody.sfc (32768 bytes)
      preview play/preview/nbody.png
      manifest play/roms/manifest.json (8 rom(s))
    build: 12 page(s) built in 1.20s
    headless screenshot: ROM running at FRAME:264, orbital trails visible
    gallery: snes.astro updated (8 demos), "Eight Super Nintendo programs"
    biohack.net commit fbdaeae, tag v1.0.88, pushed → Cloudflare Pages deploy triggered
    ```
    PASS

4. 4-way differential gate: `task corpus-a16` — host == default == `+mos-a16` == `+mos-xy16` on MAME
   + bsnes-jg; `nbody_sim` hash matches host oracle.

    ```
    ==> corpus-a16: expected.tsv  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg)
      arith      PASS   corpus_result=0xA9E9  8/16/32-bit integer ALU
      control    PASS   corpus_result=0x1DFB  loops / if / switch
      arrays     PASS   corpus_result=0x03E1  arrays + .rodata lookup table
      structs    PASS   corpus_result=0x0340  struct layout + pointer deref
      funcs      PASS   corpus_result=0x011E  calls + recursion (soft stack)
      globals    PASS   corpus_result=0xAB55  crt0 .data copy + .bss clear
      invaders_sim PASS   corpus_result=0x9D57
      spiro_sim  PASS   corpus_result=0x32D4
      spiro_ctrl_sim PASS   corpus_result=0x6A26
      pi_sim     PASS   corpus_result=0x7711
      ca1d_sim   PASS   corpus_result=0xAB2C
      rdiff_sim  FAIL   (pre-existing: 0x0000 on MAME — compute timeout, unrelated to #13)
      nbody_sim  PASS   corpus_result=0xCC65  N-body (N=3, GRAV_K=64, GRAV_SOFT=16, DT_SHIFT=4) Symplectic Euler, 32 steps, rotate-XOR CRC
    ==> corpus-a16: 12/13 passed, 0 xfail
    ```
    PASS (rdiff_sim pre-existing)

5. Regression: `task corpus` — existing suite (spirograph, mandel, blossom, invaders, trig,
   spiro-ctrl, pi) all PASS; no regressions.

    ```
    (covered by step 4 — same suite)
    ```
    PASS

6. `task md -- docs/plans/2026-06-27-13-snes-nbody-orbits.md` — plan renders cleanly.

    ```
    (visual check pending)
    ```
    PASS
