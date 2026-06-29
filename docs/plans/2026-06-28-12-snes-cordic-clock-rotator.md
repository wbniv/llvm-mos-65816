# #12 — SNES CORDIC Rotator: sin/cos/atan via shift-add only (no multiply)

**Status:** PLANNED. Demo **#12** of the **compiler stress-test demo battery**.

## Context

Adds demo **#12** to the llvm-mos-65816 compiler stress-test demo battery (GitHub #321 / M2). Each demo
compiles a self-contained chunk of math three ways (`default`, `+mos-a16`, `+mos-xy16`) and asserts
byte-identical results across host + MAME + bsnes-jg — exercising a distinct codegen corner.

Every existing demo (#11 spirograph, #13 n-body, #19 π-spigot, #20 factorial) stresses the **arithmetic
libcall** paths: their disasm gates assert the **presence** of `__mulsi3` / `__udivmodsi4`. #12 is the
deliberate complement: **CORDIC is shift-and-add only — no multiply, no divide**, so under `+mos-a16` it
lowers to pure native-16 ALU code (`rep`/`sep` brackets + constant shifts) with **zero** `__*si3` / `__*hi3`
libcalls. Its gate signature is therefore the **absence** of those libcalls — a genuinely different ALU
profile from everything else in the battery, which is exactly why this demo is worth building.

**Key reuse:** a complete, host-portable, bit-exact Q2.14 CORDIC already lives at `examples/65816/cordic16.h`
(+ generated `cordic16_tables.h`, generator `tools/gen-cordic-tables.py`), written for an earlier trig
spike. We build the rotator **on top of it** and do **not** reimplement CORDIC.

**Visual:** a rotating hand plus a static "vector field" — a ring of unit vectors at evenly-spaced compass
angles (each computed once via `cordic16_sincos`), with the hand sweeping over them; a 2-row HUD shows the
hand angle in degrees and a live `atan2`-recovered self-check of that angle.

## Algorithm

Built on `examples/65816/cordic16.h` (Q2.14: `CORDIC16_ONE`=16384, `CORDIC16_HALFPI`=25736). The core
`cordic16_sincos` converges only for `angle ∈ [-π/2, π/2]`; `cordic16_atan2` needs `x > 0`. A full circle is
covered by **quadrant folding** (a residual in `[0, π/2)` + a 0..3 quadrant index applied as sign/swap) —
pure compare/add/negate, still multiply-free.

```c
#define CORDIC_GATE_N   96u               // ≈ full-circle sweep; ≤120 frames of compute
#define CORDIC_QSTEPS   24                // residual steps per quadrant → 96 = one revolution
#define CORDIC_DSTEP    (CORDIC16_HALFPI / CORDIC_QSTEPS)   // compile-time const Q2.14 increment
typedef struct { int16_t r; uint8_t qd; } rotor;           // residual angle + quadrant 0..3

cordic_fold(h, v)          = rotate-left(h) ^ v             // == pi_fold
rotor_sincos(o, &s, &c):   // pure add/compare — NO multiply
  (c0,s0) = cordic16_sincos(o.r)                            // base (cos,sin) in [0,π/2]
  apply quadrant qd as sign/swap → (c,s)                    // 0:(c,s) 1:(-s,c) 2:(-c,-s) 3:(s,-c)
  o.r += DSTEP; if (o.r >= HALFPI) { o.r -= HALFPI; o.qd++ }
cordic_gate_crc():         // noinline
  for k in 0..GATE_N:
    rotor_sincos → fold s, fold c                           // ROTATION path (shift-add)
    fold cordic16_atan2(base_s, base_c)                     // VECTORING path (shift-add), x>0
```

- **Strictly multiply-free:** rotor advance is add/compare; quadrant fold is sign/swap; `cordic16_sincos` /
  `cordic16_atan2` are unrolled shift-add. The Phase-3 helpers in `cordic16.h` (`tan/asin/sqrt/sinh…`) that
  *do* emit `__mulsi3`/`__divsi3` are `static inline` and **never called here** → not emitted.
- Width discipline: `int16_t`/`uint16_t` only, no bare `int` (host int=32 vs target int=16 would diverge).
- Radius→pixel scaling (`RADIUS * cos >> 14`, a `__mulsi3`) lives **only in the ROM render path**, never in
  this header / the gate → the probed corpus object stays libcall-free.

## Screen layout

```
┌────────────────────────────────────────┐
│  rows 0–25 : BG3 2bpp ROTATOR canvas    │   128×128 px centred star + sweeping hand
│        \  |  /                          │   • outer ring + 12 unit-vector spokes (static)
│         \ | /                           │   • one rotating hand (the only moving element)
│      ----(o)----                        │
│         / | \                           │
│        /  |  \                          │
│  row 26 : ANGLE  137 DEG                │   BG3 TextLayer (co-tenant), HUD bar 0
│  row 27 : ATAN2  137  OK               │   HUD bar 1 — vectoring self-check
└────────────────────────────────────────┘
```

## Display architecture

- **Custom `Rotator` drawable** (modelled on `bitmap_canvas.h` + the `PiHud`/`FactDisplay` dirty pattern),
  in `examples/snes/cordic.c`:
  - `uint8_t face[NTILES*16]` — static background (outer ring + 12 spokes), built **once** in `reserve()`.
  - `uint8_t chr[NTILES*16]` — live buffer = `face` + current hand.
  - Erase-correct moving hand without whole-canvas reflush: each frame copy `face → chr` over the
    **previous** hand's tile range, Bresenham the new hand into `chr`, set dirty `[lo,hi]` = bounding tile
    range of (old ∪ new) hand. The hand moves incrementally, so the dirty range stays small (a few hundred
    bytes/frame, under the 1 536 B/V-blank budget; the rare wrap frame is still bounded by canvas size).
  - Lift `canvas_plot` (2bpp OR set-pixel) + Bresenham from `bitmap_canvas.h`.
- **`TextLayer`** (BG3 co-tenant, `font8.h`) for the 2 HUD rows — same BG3 sharing as spirograph.
- **VRAM (BG3, spigot convention):** chr base word `0x0000` (canvas tiles + font at tile 256), tilemap base
  word `0x4000`. Mode 1, BG3 only.
- **Palette:** BG3 palette 0 = CGRAM[0..3] (2bpp): 0 transparent, 1 ring/spokes dim, 2 hand bright, 3 accent.

## Files

| File | New/Mod | Purpose |
|------|---------|---------|
| `docs/plans/2026-06-28-12-snes-cordic-clock-rotator.md` | new | This plan |
| `examples/65816/cordic.h` | new | Rotor + `cordic_gate_crc`/`cordic_fold` over `cordic16.h` |
| `examples/snes/cordic.c` | new | SNES ROM: `Rotator` drawable + `TextLayer` HUD + frame loop |
| `examples/snes/corpus/cordic_sim.c` | new | HAL-free corpus slice (`corpus_result = cordic_gate_crc()`) |
| `tools/cordic-sim.c` | new | Host oracle (prints `cordic gate_crc = 0xXXXX`) |
| `dev/cordic.sh` | new | 5-section gate script (copy `dev/pi.sh`; **invert §3**) |
| `dev/cordic.lua` | new | MAME snapshot/assert (copy `dev/pi.lua`, relabel) |
| `examples/snes/corpus/expected.tsv` | mod | Add `corpus/cordic_sim.c  corpus_result  0xXXXX  …` row |
| `Taskfile.yml` | mod | Add `cordic:` + `cordic-play:` tasks |
| `TODO.md` | mod | `[wip]` entry under demo battery, then `[x]` at close |
| `docs/investigations/plan-index.md` | mod | One row, `Platform` category |

## Reused infrastructure

| Asset | From | Used for |
|-------|------|----------|
| `cordic16_sincos` / `cordic16_atan2` | `examples/65816/cordic16.h` | The shift-add math core (no libcalls) |
| `CORDIC16_ONE/HALFPI`, `cordic16_atan_tbl` | `examples/65816/cordic16_tables.h` | Q2.14 constants + rotation table |
| `canvas_plot` / Bresenham idiom | `examples/snes/snesgfx/bitmap_canvas.h` | Pixel set + hand line in the custom drawable |
| `TextLayer` + `font8.h` | `examples/snes/snesgfx/text_layer.h` | 2-row angle + atan2 HUD |
| `display.h`/`drawable.h`/`upload.h`/`vram.h` | `examples/snes/snesgfx/` | Frame loop + DMA |
| `pi_fold` rotate-XOR hash + width discipline | `examples/65816/pi_spigot.h` | `cordic_fold` / `cordic_gate_crc` model |
| `spigot.c` PiHud drawable structure | `examples/snes/spigot.c` | `Rotator` drawable model |

## Differential gate

- **`corpus_result`** = `cordic_gate_crc()` at `CORDIC_GATE_N=96` (one revolution; rotation + vectoring folded).
- **Bar: 5-way** — all state is NEAR (small static tables + bank-0 WRAM, no far pointers): `host ==
  default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg`, `-verify-machineinstrs` clean.
- **Disasm probe (`dev/cordic.sh` §3 — INVERTED vs every other demo):**
  - `mul = grep -cE '__mulsi3|__mulhi3|__umulsi3'`  → **expect 0**
  - `div = grep -cE '__divsi3|__udivsi3|__udivmodsi4|__divhi3|__udivhi3'`  → **expect 0**
  - `vsh = grep -cE '__ashrhi3|__lshrhi3|__ashlhi3|__ashrsi3'` (variable-shift libcalls)  → **expect 0**
  - `rs  = grep -cwE 'rep|sep'`  → **expect ≥ 1** (native-16 bracket present)
  - `add = grep -cwE 'adc|sbc'`  → **expect ≥ 16** (the shift-add micro-rotations — positive witness)
  - **PASS** iff `mul==0 && div==0 && vsh==0 && rs≥1 && add≥16` — asserts the demo's identity: *shift-add
    only, zero arithmetic libcalls, native-16.*
  - **Finding:** the atan/atanh tables are **constant-folded into immediate `adc`/`sbc` operands** —
    every rotation index is a compile-time constant, so there is **no rodata table symbol** to grep
    (`cordic16_atan_tbl` count = 0). The immediate shift-add IS the multiply-free signature; the original
    `atan_tbl≥1` probe was wrong (looked for a table the optimizer correctly eliminated) → replaced by the
    robust `adc/sbc` witness.
- **`EXPECT` = `0x4D41`** (host oracle; == bsnes-jg).

## Publication

`/snes-rom-page --rom build/cordic.sfc --slug cordic --site ~/SRC/biohack.net --title "CORDIC Rotator"
--preview build/cordic-mame.png --selfcheck "0x<VMA> 2 0x<EXPECT> 500 cordic"` (VMA from
`awk '$NF=="corpus_result"{print $1; exit}' build/cordic.map`).

## Verification steps

1. Host oracle compiles and prints a plausible CRC.
   ```
   cordic rotator gate  GATE_N=96  QSTEPS=24  DSTEP=1072  gate_crc=0x4D41
   ```
   **PASS** — host oracle = `0x4D41`.

2. ROM builds clean; `tools/snes-checksum.py build/cordic.sfc` exits 0.
   ```
   checksum ok ; corpus_result VMA=0x135d ; build/cordic.sfc = 32768 bytes
   ```
   **PASS** (after the split-bitplane RAM fix — one 4 KB chr buffer, plane 0 = face, plane 1 = hand;
   the original two-buffer design overflowed `.bss` by 863 bytes).

3. Corpus slice host-compiles cleanly (`cc -O2 -I examples -c …/cordic_sim.c`). **PASS**.

4. `dev/run.sh cordic` — **`RESULT: PASS`**:
   ```
   ==> host oracle: CORDIC rotator gate hash = 0x4D41
   ==> built build/cordic.sfc (+mos-a16); corpus_result @ WRAM 0x135d
   ==> disasm gate (multiply-free CORDIC: zero arithmetic libcalls, native-16)
       PASS  mul=0 div=0 vshift=0  rep/sep=252  adc/sbc=143  (shift-add only, no libcalls, native-16)
   SMOKE: PASS off=0x135D len=2 got=0x4D41 (ran 500 frames, bsnes-jg)
       SKIP MAME (no SPC700 IPL at dev/roms/s_smp/spc700.rom — gitignored Nintendo content)
   RESULT: PASS
   ```
   **PASS** for the runnable legs: host == bsnes-jg (`0x4D41`) + the inverted multiply-free disasm gate.
   **MAME SKIPPED** — the gitignored SPC700 IPL is absent in this environment (affects every demo's MAME
   leg, not just this one; the gate now SKIPs rather than silently FAILs). Supply the IPL (or run in CI)
   for the MAME leg.

5. `-mllvm -verify-machineinstrs` clean across all three modes (the part of the 5-way that needs no
   emulator): `default: CLEAN · a16: CLEAN · xy16: CLEAN`. **PASS.** Full runtime 5-way
   (`default@MAME == a16@MAME == xy16@MAME`) is **BIOS-blocked** here → pending CI / the SPC700 IPL.

6. Visual confirmed from the bsnes-jg framebuffer (`build/cordic-jg.png`): dotted ring + 12 spokes
   (CORDIC vector field) + rotating hand, HUD `ANGLE 123 DEG` / `ATAN2 123 OK` (the atan2 self-check
   recovers the hand angle). **PASS.** (Publication via `/snes-rom-page` is batched with the other ROMs.)

7. `task md -- docs/plans/2026-06-28-12-snes-cordic-clock-rotator.md` renders cleanly. _(pending)_

## Risks / watch-items

- **Gate must stay libcall-free.** If `mos-clang` strength-reduces a residual increment into a `__mulhi3`,
  the inverted §3 catches it — fix by keeping the rotor advance a pure add. Never call the Phase-3
  `cordic16_*` helpers (tan/asin/sqrt/sinh…) from the gate.
- **Quadrant fold correctness:** verify the host oracle's swept (sin,cos) trace a clean unit circle (sign
  flips at the right quadrant boundaries) before trusting the CRC.
- **Hand erase:** the face-restore-over-prev-range must run before drawing the new hand, else trails
  accumulate. Validate visually in `cordic-play` and via the MAME/bsnes screenshots.
- **Shared-tree commit discipline:** stage only the new/modified files listed above; never `vendor/`, a
  foreign patch, or `docs/transcripts/`.
