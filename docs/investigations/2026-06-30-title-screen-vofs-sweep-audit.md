# Title screen BG2VOFS sweep — rebuild & publish audit

**Date:** 2026-06-30  
**Scope:** All 35 published SNES demos rebuilt with the new `title_layer.h` (BG2VOFS eased
animation + mixed 8×8/16×16 font) and re-published to biohack.net v1.0.151.

## What changed

`examples/snes/snesgfx/title_layer.h` was rewritten (`6acb5b4`):
- Fly-in now drives `REG_BG2VOFS` via `upq_push_scroll` — pixel-smooth, zero VRAM traffic
- Line0 = 8×8 font (category/subtitle); line1 = 16×16 pixel-doubled (demo name)
- Ease-in: exponential decay (~35 frames); hold; fast ease-out: quadratic accel (≤ 6 frames)
- `title_begin16` aliased to `title_begin` — all call sites unchanged

## All-green gate results

| Preview | Demo | Task | Hash | bsnes‑jg | MAME |
|---|---|---|---|---|---|
| <img src="https://biohack.net/play/preview/1d-ca.png" width="96"> | 1D Cellular Automaton | `1d-ca` | 0xAB2C | PASS | PASS |
| <img src="https://biohack.net/play/preview/avalanche.png" width="96"> | 64-bit Avalanche | `avalanche` | 0x27EA | PASS | PASS |
| <img src="https://biohack.net/play/preview/bhut.png" width="96"> | Barnes-Hut Galaxy | `bhut` | 0xEF0B | PASS | PASS |
| <img src="https://biohack.net/play/preview/blossom.png" width="96"> | Blossom (Hopalong) | `blossom` | 0x9047 | PASS | PASS |
| <img src="https://biohack.net/play/preview/boids.png" width="96"> | Boids Flock | `boids` | 0xA8AB | PASS | PASS |
| <img src="https://biohack.net/play/preview/buddhabrot.png" width="96"> | Buddhabrot | `buddha` | 0x7C31 | PASS | PASS |
| <img src="https://biohack.net/play/preview/burning-ship.png" width="96"> | Burning Ship | `burning-ship` | 0x6F2D | PASS | PASS |
| <img src="https://biohack.net/play/preview/cardioid.png" width="96"> | Cardioid Times-Table | `cardioid` | 0x523B | PASS | PASS |
| <img src="https://biohack.net/play/preview/cordic.png" width="96"> | CORDIC Rotator | `cordic` | 0x4D41 | PASS | PASS |
| <img src="https://biohack.net/play/preview/doom-fire.png" width="96"> | Doom Fire | `doom-fire` | 0x3C59 | PASS | PASS |
| <img src="https://biohack.net/play/preview/double-pendulum.png" width="96"> | Double Pendulum | `double-pendulum` | 0xE859 | PASS | PASS |
| <img src="https://biohack.net/play/preview/epicycles.png" width="96"> | Fourier Epicycles | `epicycles` | 0x4F6C | PASS | PASS |
| <img src="https://biohack.net/play/preview/factorial.png" width="96"> | Factorial | `factorial` | 0x772F | PASS | PASS |
| <img src="https://biohack.net/play/preview/fft.png" width="96"> | FFT Spectrum | `fft` | 0x6D7A | PASS | PASS |
| <img src="https://biohack.net/play/preview/fn-plot.png" width="96"> | fn-plot | `fn-plot` | 0x2EBE | PASS | PASS |
| <img src="https://biohack.net/play/preview/harmonograph.png" width="96"> | Harmonograph | `harmonograph` | 0x0EBB | PASS | PASS |
| <img src="https://biohack.net/play/preview/hilbert.png" width="96"> | Hilbert Curve | `hilbert` | 0x5999 | PASS | PASS |
| <img src="https://biohack.net/play/preview/space-invaders.png" width="96"> | Space Invaders | `dev/run.sh invaders` | 0x9D57 | PASS | SKIP¹ |
| <img src="https://biohack.net/play/preview/julia.png" width="96"> | Julia Set | `julia` | 0x3490 | PASS | PASS |
| <img src="https://biohack.net/play/preview/life.png" width="96"> | Conway's Life | `life` | 0xDDF1 | PASS | PASS |
| <img src="https://biohack.net/play/preview/lsystem.png" width="96"> | L-System Plant | `lsystem` | 0x79C3 | PASS | PASS |
| <img src="https://biohack.net/play/preview/mandel-float.png" width="96"> | Soft-Float Mandelbrot | `mandel-float` | 0x4169 | PASS | SKIP¹ |
| <img src="https://biohack.net/play/preview/maze.png" width="96"> | Maze Gen+Solve | `maze` | 0x0749 | PASS | PASS |
| <img src="https://biohack.net/play/preview/n-body.png" width="96"> | N-Body Orbits | `n-body` | 0xCC65 | PASS | PASS |
| <img src="https://biohack.net/play/preview/newton.png" width="96"> | Newton Fractal | `newton` | 0x4D8B | PASS | PASS |
| <img src="https://biohack.net/play/preview/raycaster.png" width="96"> | Raycaster Maze | `raycaster` | 0xB200 | PASS | PASS |
| <img src="https://biohack.net/play/preview/rdiff.png" width="96"> | React-Diffusion | `rdiff` | 0x5555 | PASS | PASS |
| <img src="https://biohack.net/play/preview/sort-race.png" width="96"> | Sorting Race | `sort-race` | 0xB28F | PASS | PASS |
| <img src="https://biohack.net/play/preview/spigot.png" width="96"> | π Spigot + MC | `pi` | 0x7711 | PASS | PASS |
| <img src="https://biohack.net/play/preview/spirograph.png" width="96"> | Spirograph | `spirograph` | 0x32D4 | PASS | PASS |
| <img src="https://biohack.net/play/preview/tea.png" width="96"> | TEA Cipher | `tea` | 0xDF0E | PASS | PASS |
| <img src="https://biohack.net/play/preview/truchet.png" width="96"> | Truchet Bitfields | `truchet` | 0xB3E6 | PASS | PASS |
| <img src="https://biohack.net/play/preview/turtle-vm.png" width="96"> | Bytecode VM Turtle | `turtle-vm` | 0x4007 | PASS | PASS |
| <img src="https://biohack.net/play/preview/vaprintf.png" width="96"> | va_arg Lissajous | `vaprintf` | 0xE1F3 | PASS | PASS |
| <img src="https://biohack.net/play/preview/3d-wireframe.png" width="96"> | 3-D Wireframe | `dev/run.sh wireframe` | 0xE737 | PASS | PASS |

¹ MAME SKIP: no SPC700 IPL ROM (`dev/roms/s_smp/spc700.rom` — gitignored Nintendo content).
Pre-existing non-blocker; bsnes-jg is the gate emulator.

**35/35 bsnes-jg PASS. All corpus hashes unchanged vs. pre-sweep (title screen is pre-loop,
gate-neutral by design).**

## URL audit

All 35 demos are served from `biohack.net/snes/<slug>/`. The old non-`/snes/` references in
TODO.md (`/1d-ca/`, `/double-pendulum/`, `/spigot/`, `/spirograph/`, `/blossom/`) are stale
history — the Astro site has no pages at those paths (they 404). No redirect rules needed; the
pages were always canonical at `/snes/`.

## ROM name remapping (build/ → biohack.net roms/)

| build/ | biohack.net roms/ |
|---|---|
| `buddha.sfc` | `buddhabrot.sfc` |
| `invaders.sfc` | `space-invaders.sfc` |
| `wireframe.sfc` | `3d-wireframe.sfc` |

All others copy verbatim.

## Tasks without Taskfile entries

`wireframe` and `invaders` have no `task <name>` shortcut — build via `dev/run.sh wireframe` /
`dev/run.sh invaders` directly.

## Published

biohack.net **v1.0.151** (`dace7e9`). All 35 ROM files updated. Deploy triggered via
`git push origin master v1.0.151`.

---

## Initialization audit: VRAM / OAM / CGRAM clearing before video-on

**Triggered by:** visible garbage in mandel-double (#33) before the first clean frame.

### What `snes_ppu_reset_blank()` does and does NOT do

`snes_ppu_reset_blank()` (SDK, `snes_ppu.h:338`) enters force-blank (`INIDISP=0x80`) and
zeroes every PPU **control** register from `$2101` to `$2133`. It explicitly **skips** all
data/address ports: `$2104` (OAM data), `$2116/$2117` (VRAM address), `$2118/$2119` (VRAM
data), `$2121` (CGRAM address), `$2122` (CGRAM data).

Result: VRAM, CGRAM (palette), and OAM are **not cleared**. bsnes-jg randomizes VRAM at
power-on to surface exactly this class of bug; real hardware similarly has indeterminate
power-on state.

### Risk by demo class

**BGMODE_1 demos (BitmapCanvas / text-layer / Newton / rdiff etc.):** safe. Their
`_reserve()` implementations write every chr tile and tilemap entry they reference before
`display_add()` enables the layer. The `TitleLayer` does the same. Random VRAM outside the
written regions is never rendered (layers are off until TM is set, palette entries outside
palette 7 are never referenced by the title). **No garbage risk.**

**`invaders.c` (OBJ layer):** safe. `sprite_set_init()` fills the full 544-byte OAM shadow
with `Y=SPR_OFFSCREEN_Y` (sprites hidden off-screen) and `emit()` DMA's all 544 bytes to
hardware OAM every frame, so hardware OAM is clean from frame 1.

**Mode-7 demos — the gap:**

| Demo | `vram_clear_all()` | `m7_tilemap_clear()` | Verdict |
|---|---|---|---|
| `buddha.c` | ✓ (clears all 64 KB) | ✓ | Clean |
| `blossom.c` | ✓ (clears all 64 KB) | ✓ | Clean |
| `julia.c` | ✗ | ✓ | Partial — chr data VRAM not zeroed, but Mode-7 chr upload overwrites it |
| `mandel-float.c` | ✗ | ✓ | Same as julia |
| `mandel-display.c` | ✗ | ✓ | Same as julia |
| `mandel-double.c` | ✗ | ✓ | **Confirmed garbage** (user-observed) |

In Mode 7, VRAM holds interleaved tilemap bytes (even addresses) and chr bytes (odd
addresses). `m7_tilemap_clear()` zeros the tilemap half. The chr half is overwritten by the
DMA upload of the computed image. However there is a window — between enabling video and
completing the first full-image upload — where uninitialized chr bytes can show through as
garbage pixels. `buddha.c` and `blossom.c` avoid this by zeroing all 64 KB upfront.

### Fix for mandel-double

Add a `vram_clear_all()` call immediately after `snes_ppu_reset_blank()`, following the
`buddha.c` pattern:

```c
// mandel-double.c main():
snes_ppu_reset_blank();
vram_clear_all();          // ← add this; wipes random power-on VRAM before first video-on
splash16("DOUBLE-FLOAT", "MANDELBROT", 150);
```

`vram_clear_all()` is a force-blank DMA of 0x00 to all 64 K VRAM words (128 KB); takes one
or two frames at most and is invisible since it runs entirely under force-blank.

### Scope of sweep

This audit covers the 35 published demos. The issue is pre-existing in mandel-double and is
NOT introduced by the title screen BG2VOFS rewrite. The other Mode-7 demos (`julia`,
`mandel-float`) have not been reported as visibly garbage because the chr-byte window is
brief and the tilemap clear + first upload happen quickly; mandel-double's double-precision
compute is slow enough that the window is long. Fix tracked separately.
