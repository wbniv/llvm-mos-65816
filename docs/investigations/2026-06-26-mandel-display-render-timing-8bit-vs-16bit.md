# mandel-display render timing — 8-bit vs 16-bit (and far)

**Date:** 2026-06-26 · **Status:** DONE — measured · **Tool:** [`dev/jgxwatch.cpp`](../../dev/jgxwatch.cpp) ·
**Related:** [collapse-the-demos plan](../plans/2026-06-26-collapse-the-snes-mandelbrot-demos-into-one-far-16.md),
commit `ce96744` (the release-test frame-budget fix this measurement motivated).

## TL;DR

**Question:** how long does `examples/snes/mandel-display.c` take to complete its last rendering step
(the canonical 64×56 pass, *before* the steady-state animation) — in 8-bit vs 16-bit?

**Answer** (cycle-accurate bsnes-jg; frame at which `corpus_result` first reaches the final CRC `0x204F`):

| Build | Frames | Time @ 60.0988 Hz | vs 8-bit |
|-------|-------:|------------------:|---------:|
| **8-bit** (near, default target) | **4958** | **82.50 s** | — |
| 16-bit (near, same NEAR memory model) | 5072 | 84.39 s | +114 f / +2.30 % |
| **16-bit far** (current shipped tester) | **5084** | **84.59 s** | +126 f / +2.54 % |

**The 16-bit build is ~2.5 % *slower*, not faster.** That is the expected result for this workload, not a
regression: the Mandelbrot inner loop is **multiply-bound**, and the 65816 has no hardware multiply, so a
16-bit accumulator does not accelerate the software fixed-point multiply — it only adds `rep`/`sep` mode
bracketing. (This is the project's "Lesson 2": measured on `k_mandel`, `+mos-a16` is **+21 % bigger** code on
the same kernel.) The far high-WRAM buffer adds a further **+12 frames (~0.2 %)** over near-16-bit — the small
per-access cost of `sta [dp]`/`lda [dp]` vs absolute `sta`/`lda`.

## Why these three builds

The *current* `mandel-display.c` is **far / `+mos-a16`-only** (its 64×56 escape buffer lives in high WRAM at
`$7E2000`, reached by 24-bit far pointers, which the default-8-bit target can't legalize). So it cannot be
built 8-bit — there is no 8-bit build of the *current* source. To get a clean 8-bit-vs-16-bit comparison we
use the **near** (pre-conversion) source, which builds *both* ways and computes the identical 64×56 N=15
fractal, then add the shipped far build:

- **near-8bit** — the only 8-bit-buildable `mandel-display`; answers "the 8-bit version".
- **near-16bit** — same source, `+mos-a16`; isolates the **accumulator-width** effect (same NEAR memory model).
- **far-16bit** — the current shipped tester; near-16bit **plus** the far-pointer overhead.

The decomposition `8bit → near-16bit → far-16bit` cleanly separates the two effects: accumulator width
(+114 f) and far addressing (+12 f).

## Methodology

**"Render complete" = `corpus_result` first equals `0x204F`.** `corpus_result` is a `volatile uint16_t` in
low WRAM, zero (BSS) at power-on, and written **exactly once** — `corpus_result = crc_fb()` (far build) /
`= crc` (near build) — immediately after the canonical 64×56 pass finishes, just before the animation loop.
So the first frame it reads `0x204F` is precisely "the last rendering step done, before animation". It is a
clean step function (set once, never changed by the animation), so the measurement is unambiguous.

**Measurement tool — [`dev/jgxwatch.cpp`](../../dev/jgxwatch.cpp):** a headless bsnes-jg harness (sibling of
`dev/jgxcheck.cpp`) that runs frame-by-frame and prints the first frame where LEN WRAM bytes at OFFSET ==
WANT. bsnes-jg is cycle-accurate, so **emulated frames == real-hardware frames**, and frames ÷ 60.0988 Hz
(SNES NTSC) == the real seconds a user waits on hardware. One run per build (exits at the match), versus a
~25-run bisection with the fixed-frame `jgxcheck`.

**`corpus_result` WRAM offsets** (from each `.map`, fed to jgxwatch): near builds `0x400`, far build `0x200`
(the far conversion changed the global layout).

## Reproduction

```sh
TOOL=build/llvm-mos-install/bin ; CFG=build/install/bin/mos-snes.cfg ; DB=vendor/bsnes-jg/Database

# (1) the NEAR (pre-far) source builds both ways — pull it from git history:
git show 2b4d631:examples/snes/mandel-display.c > /tmp/near.c
sed -i 's#"../65816/mandel.h"#"mandel.h"#' /tmp/near.c   # so -I resolves the kernel header
INC="-I examples/snes -I examples/65816"

"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Os $INC -Wl,-Map=near8.map  -o near8.sfc  /tmp/near.c
"$TOOL/mos-clang" --config "$CFG" -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
                  -Os $INC -Wl,-Map=near16.map -o near16.sfc /tmp/near.c
python3 tools/snes-checksum.py near8.sfc ; python3 tools/snes-checksum.py near16.sfc

# (2) the FAR shipped build:
dev/run.sh mandel-shot          # -> build/mandel-display.sfc  (corpus_result @ 0x200)

# (3) build jgxwatch and measure the settle frame (cap 80000):
g++ -O2 -std=c++11 -I vendor/bsnes-jg/src -c dev/jgxwatch.cpp -o jgxwatch.o
g++ jgxwatch.o vendor/bsnes-jg/objs/libbsnes.a -lsamplerate -lm -o jgxwatch
./jgxwatch near8.sfc            "$DB" 0x400 2 0x204F 80000   # -> FRAME 4958
./jgxwatch near16.sfc           "$DB" 0x400 2 0x204F 80000   # -> FRAME 5072
./jgxwatch build/mandel-display.sfc "$DB" 0x200 2 0x204F 80000   # -> FRAME 5084
```

## Notes / caveats

- **Includes the coarse previews.** The frame count covers the whole render up to and including the final
  canonical pass (the 8×7 → 16×14 → 32×28 coarse previews, then the 64×56 fill). That is the user-visible
  "time until the picture is fully sharp", which is what was asked.
- **Emulated == real.** bsnes-jg is cycle-accurate; the frame counts are what real SNES hardware produces.
  Reported seconds use NTSC 60.0988 Hz.
- **This is why the publish gate now runs 5800 frames.** The clean-room `release-test` previously sampled
  `corpus_result` at frame **1800** — fine for the old 32×28 grid, but the 64×56 render does not settle until
  frame **5084**, so the gate read the BSS-zero value and FAILed. Commit `ce96744` raised the per-program
  budget to **5800** (~14 % margin over 5084), matching `dev/mandel-shot.sh` and the bsnes-jg-wasm selfcheck.
- **Corroborates Lesson 2.** The ~2.5 % slowdown is consistent with the measured +21 % code-size growth of
  `+mos-a16` on the same fixed-point kernel: native 16-bit ops are not automatically a win when the hot path
  is a software multiply routed through the `Imag16` zero-page pair plus `rep`/`sep` mode switches.
