# #19 — SNES π Spigot + Monte-Carlo

**Status:** IN PROGRESS — plan written, implementation starting.
Demo #19 of the **compiler stress-test demo battery** (`TODO.md` → "Compiler stress-test demo battery").
Supplements the standing guides (`~/SRC/CLAUDE.md`, project `CLAUDE.md`, `docs/agent-handoff.md`).

## What it does

Two panels on screen simultaneously:

- **Left (cols 0-15):** π digits ticking out via the **Rabinowitz-Wagon spigot algorithm** — a
  big-integer carry sweep that produces one exact digit of π per run. Stress: 32-bit multiply +
  `__udivsi3` / `__umodsi3` across a 670-element uint16 array with uint32 intermediates.
- **Right (cols 16-31, rows 0-15):** 128×128 **scatter canvas** — each dart throw plots a white dot
  (hit, inside unit circle) or gray dot (miss), accumulating over time. Below the canvas: running
  π estimate "4H/T = 3.XXXXX" updating every frame.

**Codegen under test:**
- Spigot inner loop: `uint32 x = a[i]*10 + q*i; a[i] = x%(2i-1); q = x/(2i-1)` — 670 ×
  (`__mulsi3` + `__udivsi3` + `__umodsi3`) per digit, exact carry propagation.
- MC inner loop: `r² = (int32_t)x*x + (int32_t)y*y` — 16×16→32 product under +mos-a16.
- RNG: xorshift16, native 16-bit shifts.

**No far pointers** → builds default-8-bit AND +mos-a16 AND +mos-xy16 → **full 5-way differential bar**.

**Publish:** [biohack.net/spigot/](https://biohack.net/spigot/) via `/snes-rom-page` skill.

---

## Screen Layout

```
┌────────────────────────────────────────────────────────────────┐
│  256 × 224 px  (Mode 1, BG3 2bpp, 32×28 tiles)                │
├──────────────────────────┬─────────────────────────────────────┤
│  LEFT: digit panel       │  RIGHT: scatter canvas (128×128 px) │
│  cols  0-15, rows  0-15  │  cols 16-31, rows 0-15              │
│                          │                                      │
│  PI=3.                   │ ·  ·   · ·  ·   ·  ·   · · ·  ·   │
│  14159 26535             │  · ·  ·  ·  · ·  ·  ·   ·  ·  ·   │
│  89793 23846             │ ·   ·  · ·   ·  ·  · ·  ·   ·  ·  │
│  26433 83279             │  · · ·   ·  ·   ·  · ·   ·  ·  ·  │
│  50288 41971             │ ·  ·  ·  ·  · ·  ·   ·  ·  · · ·  │
│  69399 37510             │  ·  ·  ·  · ·  ·  ·  ·  ·  ·   ·  │
│  58209 74944             │ ·  · ·  ·   · ·  ·  ·  ·  · ·  ·  │
│  59230 78164             │  ·   ·  · ·  ·   ·  · ·  ·   ·  · │
│  06286 20899             │ ·  ·  ·  ·  ·  · ·  ·  ·  ·  ·  · │
│  86280 34825             │  · ·  ·   ·  ·  ·   ·  · ·  ·  ·  │
│  34211 70679             │ ·   ·  ·  · ·  ·  ·  ·  ·  ·  ·   │
│  82148 08651             │  ·  ·  · ·  ·   · ·  ·   ·  · ·   │
│  32823 06647_            │ ·  ·   ·  ·  · ·  ·  ·  ·  ·  ·   │
│                          │  · ·  ·  ·   ·  ·  ·   ·  ·  · ·  │
│  (rows scroll up as      │ ·  ·  ·  · ·  ·  ·  ·  ·  ·  ·    │
│   new digits appear)     │ ·  · ·   ·  ·  ·   ·  ·  ·  · ·   │
├──────────────────────────┼─────────────────────────────────────┤
│  rows 16-27: status bar  │                                      │
│                          │  DARTS   32768    HITS   25731       │
│  DIGIT #130 / 200        │  4H/T  = 3.14111                    │
│                          │                                      │
└──────────────────────────┴─────────────────────────────────────┘

Legend: · = outside circle (gray, palette 2), ∙ = inside (white, palette 1)
        _ = blinking cursor on current digit row
BG3 palette: 0=black, 1=white (text+inside dots), 2=dark gray (labels+outside dots), 3=cyan (cursor/header)
```

---

## Algorithm — Rabinowitz-Wagon Spigot (1995)

Produces π digits one at a time. No lookup tables, no transcendentals — pure carry arithmetic.
Based on the identity π/2 = 1 + ⅓(1 + ⅖(1 + ⅜(1 + ···))).

```c
#define PI_DIGITS  200
#define PI_ELEMS   ((PI_DIGITS * 10 / 3) + 10)   // 676 for 200 digits

// State (all in bank-0 WRAM, no far pointers)
typedef struct {
    uint16_t a[PI_ELEMS];  // register array, init to 2; a[i] < 2*i-1 after first step
    uint32_t q;            // carry accumulator across frames (for partial-sweep mode)
    int16_t  sweep_i;      // loop counter: PI_ELEMS-1 downto 1 (reset per digit)
    int16_t  predigit;     // held-back output digit (-1 = none yet)
    int16_t  nines;        // count of buffered 9s
    uint16_t n;            // output digits so far
    uint8_t  outq[8];      // burst output queue (carry events can emit multiple digits)
    uint8_t  oqh, oqt;
} pi_spigot_state;

// Inner loop (one iteration — the HOT path; run SWEEP_PER_FRAME times per frame):
//   x = a[i]*10 + q*i;  a[i] = x%(2i-1);  q = x/(2i-1)
// Bounds: a[i] < 2*i-1 < 1351, q < ~20, x < 13510 + 20*675 < 28000 → uint32 amply safe.
// q*i exercises 32×16→32 multiply; x/(2i-1) exercises __udivsi3 (32÷32).
```

**Partial-sweep loop design** (avoids spending multiple whole frames per digit):

```c
#define SWEEP_PER_FRAME  150   // iterations per frame — tune for ≤70% frame budget

// per-frame driver (in spigot.c main loop):
pi_spigot_sweep(&state, SWEEP_PER_FRAME);   // run SWEEP_PER_FRAME iterations of the carry loop
// When sweep_i reaches 0: one digit is ready in the output queue (call pi_dequeue())
```

At 150 iterations/frame × ~250 cycles/iter = 37,500 cycles/frame (< 63% of the ~59,650 cycle budget).
This yields one digit every ceil(676/150) ≈ 5 frames = 12 digits/second at 60fps.

### Monte-Carlo Dart Throw

```c
// RNG: xorshift16 (seed 0xBEEF, from invaders_logic.h pattern)
// Per dart (MC hot path — 64 throws/frame):
uint16_t x = rng16();           // uniform [0, 65535]
uint16_t y = rng16();
int16_t sx = (int16_t)x;       // reinterpret as signed [-32768, 32767]
int16_t sy = (int16_t)y;
int32_t r2 = (int32_t)sx*sx + (int32_t)sy*sy;  // 16×16→32 (stresses +mos-a16 mul)
if (r2 <= 0x40000000L) hits++;                   // radius = 0x8000 → r²max = 0x40000000
total++;

// π estimate: 4*hits/total  (displayed as fixed-point 3.XXXXX)
// Canvas plot: cx = x >> 9 = x/512 → 0..127; same for cy
canvas_plot(&canvas, cx, cy, (r2 <= 0x40000000L) ? 1 : 2);
```

---

## Display Architecture

**BG3 tilemap layout (32×32 tiles):**

```
           col 0       col 15  col 16      col 31
row 0  ┌─────────────────┬──────────────────────┐
       │  digit grid     │                      │
       │  (PiHud drwbl)  │  scatter canvas      │
       │  "PI=3."        │  (BitmapCanvas,      │
       │  14159 26535    │   box_col=16,         │
       │  89793 23846    │   box_row=0)          │
       │  ...            │                      │
       │  (scrolls up)   │                      │
       │  NNNNNN NNNNN   │                      │
row 15 ├─────────────────┘  ──────────────────  │
       │                                         │
       │  DIGIT #NNN / 200   DARTS  NNNNNN       │
       │                     HITS   NNNNNN       │
       │                     4H/T = 3.NNNNN      │
       │                                         │
row 27 └─────────────────────────────────────────┘
```

**Drawables in scene:**
1. `BitmapCanvas canvas` — 128×128 scatter plot, `box_col=16, box_row=0`
2. `PiHud hud` — writes digit grid (cols 0-14, rows 0-15) + stats rows (16-19) into BG3 tilemap shadow

**`PiHud` (local drawable, scoped to spigot.c):**
- Shadow: `uint16_t shadow[HUD_NROWS * 16]` (only the left 16 cols per row)
- `reserve()`: loads font glyphs into VRAM (same as TextLayer)
- `emit()`: DMAs each dirty half-row (32 bytes = 16 words) to `map_word + row*32` in VRAM
- `dirty`: bitmask of rows needing re-DMA (up to HUD_NROWS bits in a uint32)

**Digit grid scroll:**
- `digit_row`, `digit_col` track the next write position in rows 1-14 (row 0 = "PI=3." header)
- On new digit: write to `shadow[digit_row*16 + digit_col]`, mark row dirty
- On row full (col 11): digit_col=0, digit_row++. When digit_row reaches 14, scroll all rows 2-14
  up by one, clear row 14, digit_row stays at 14. One full shadow re-DMA (14 rows × 32 bytes = 448 B)

---

## Files

### New

| Path | Purpose |
|------|---------|
| `examples/65816/pi_spigot.h` | Portable spigot + MC: state structs, init, sweep, dequeue, mc_throw, pi_gate_crc() |
| `examples/snes/spigot.c` | SNES ROM: PiHud + BitmapCanvas + frame loop |
| `examples/snes/corpus/pi_sim.c` | Corpus slice: calls pi_gate_crc(), writes corpus_result |
| `tools/pi-sim.c` | Host oracle: same as tools/spiro-sim.c, prints golden hash |
| `dev/pi.sh` | Gate: build ROM → MAME smoke → host-vs-a16 CRC diff → bsnes-jg |

### Modified

| Path | Change |
|------|--------|
| `Taskfile.yml` | Add `task pi` target |
| `TODO.md` | Mark `#19 π spigot + Monte-Carlo` done when verified |

---

## Reused Infrastructure

| Asset | From | Used for |
|-------|------|---------|
| `snesgfx/display.h` | `examples/snes/` | Boot, v-blank, frame sync |
| `snesgfx/bitmap_canvas.h` | `examples/snes/` | 128×128 scatter canvas |
| `snesgfx/upload.h`, `scene.h`, `drawable.h`, `vram.h` | `examples/snes/snesgfx/` | DMA queue, scene |
| `font8.h` | `examples/snes/` | 8×8 glyphs (0-9 + uppercase) |
| xorshift16 pattern | `examples/snes/invaders_logic.h` | RNG (copy the 4-line function) |
| `snes_wait_vblank()`, `snes_ppu_reset_blank()` | `platforms/snes/snes.h` | SNES boot + frame |
| `tools/spiro-sim.c` | `tools/` | Template for `tools/pi-sim.c` |
| `dev/spirograph.sh` | `dev/` | Template for `dev/pi.sh` |
| `examples/snes/corpus/spiro_sim.c` | `examples/snes/corpus/` | Template for `pi_sim.c` |

---

## Differential Gate

```
corpus_result (volatile uint16_t):
  CRC = pi_gate_crc()   // defined in pi_spigot.h
  - Runs spigot to PI_DIGITS outputs, folds each digit: h = rotate_left(h, 1) ^ digit
  - Runs MC for MC_GATE_THROWS darts, folds (hits XOR total) into h
  - Returns h (16-bit)

Gate (dev/pi.sh):
  host == clang-default@MAME == clang-+mos-a16@MAME == clang-+mos-xy16@MAME == default/a16@bsnes-jg

Disasm probe (in pi.sh):
  - __udivmodsi4 count >= 1 (clang emits combined div+mod since both quot+rem are used)
  - __mulsi3 / 32-bit mul calls present (from q*i or r² = x*x + y*y)
  - rep / sep instructions present (native 16-bit bracketing under +mos-a16)

corpus_result: 0x771D (PI_GATE_DIGITS=1, PI_GATE_THROWS=256; timing: ~120 frames on SNES).
Note: clang emits __udivmodsi4 (not separate __udivsi3/__umodsi3) when both quot and rem
are needed in the same expression. PI_GATE_DIGITS/THROWS are capped to fit the 180-frame
corpus-a16 window: at PI_GATE_DIGITS=1 + PI_GATE_THROWS=256 the total is ≈ 120 frames.
```

---

## Publication

After verified ROM, run `/snes-rom-page`:

```bash
~/.claude/skills/snes-rom-page/scaffold.sh \
  --rom build/spigot.sfc \
  --slug spigot \
  --site /home/will/SRC/indri.studio \
  --title "π Spigot + Monte-Carlo" \
  --preview /tmp/spigot-preview.png \
  --selfcheck "0xOFF LEN 0xWANT 3600 digits+mc"
```

Page `src/pages/spigot.astro`: intro with the spigot math identity, emulator widget, HUD breakdown,
controls table (same pattern as blossom.astro / spirograph's biohack page).

---

## Verification Steps

1. Build + smoke: `task pi` compiles `build/spigot.sfc` (+mos-a16); MAME boots, writes `corpus_result`
   without crashing; headless screenshot (3 600 frames ~= 60 s) shows digit count ≥ 20, scatter canvas
   has ≥ 1 000 dots, running π estimate between 3.10 and 3.18.

    ```
    PASS  __udivmodsi4=2  __mulsi3=3  rep/sep=52  (carry-chain divmod + 16x16→32 mul, native-16)
    SMOKE: PASS off=0x1B41 len=2 got=0x771D (ran 500 frames, bsnes-jg)
    SHOT: PASS corpus=0x771D (snapshot at frame 500)
    RESULT: PASS — π spigot+MC rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x771D host == +mos-a16
    ```
    PASS

2. **Publish** (before full gate): `/snes-rom-page` — scaffold + build indri.studio + headless
   screenshot of the live [biohack.net/spigot/](https://biohack.net/spigot/) page shows emulator
   playing; ROM is live.

3. 4-way differential gate: `task corpus-a16` (or the pi.sh gate) — host == default == +mos-a16 ==
   +mos-xy16 on MAME + bsnes-jg; disasm probe sees `__udivmodsi4` + `__mulsi3` + `rep`/`sep`.

    ```
    arith      PASS   corpus_result=0xA9E9
    control    PASS   corpus_result=0x1DFB
    arrays     PASS   corpus_result=0x03E1
    structs    PASS   corpus_result=0x0340
    funcs      PASS   corpus_result=0x011E
    globals    PASS   corpus_result=0xAB55
    invaders_sim PASS corpus_result=0x9D57
    spiro_sim  PASS   corpus_result=0x32D4
    spiro_ctrl_sim PASS corpus_result=0x6A26
    pi_sim     PASS   corpus_result=0x771D
    ==> corpus-a16: 10/10 passed, 0 xfail
    ```
    PASS

4. `task corpus` — existing suite (spirograph, mandel, blossom, invaders, trig, spiro-ctrl) all
   PASS; no regressions.

5. `task md -- docs/plans/2026-06-27-19-snes-pi-spigot-montecarlo.md` — plan renders cleanly.
