# Cartridge-size canary — the unstable backdrop is power-on entropy, not a capture artifact

Supplement to [`2026-07-30-exhirom-video-boundary-test.md`](2026-07-30-exhirom-video-boundary-test.md)
(Phase 0–1). Closes hold (1) on the ExHiROM TODO item: *"backdrop verdict renders inconsistently per
config/frame while the WRAM oracle is fully deterministic; 3-hypothesis budget spent, root cause
unknown — publish would look broken."*

## Verdict

**Root cause: the ROM leaves most of the PPU uninitialised, and bsnes-jg randomises exactly that
state at every power-on from a `clock()` seed.** It is a real ROM defect, not a harness artifact.

```
vendor/bsnes-jg/src/settings.hpp:72   unsigned entropy = 1;   // 0 = None, 1 = Low, 2 = High
vendor/bsnes-jg/src/system.cpp:396    random.entropy((Random::Entropy)configuration.entropy);
vendor/bsnes-jg/src/random.cpp:45     static void seed() { uint32_t seed = (uint32_t)clock(); ... }
```

At the default (Low), `System::power()` reseeds from `clock()`, so **every run of the same ROM powers
on with different state**: WRAM (`cpu.cpp:1169`) and — decisively for anything that looks at the
picture — PPU registers the ROM never wrote: per-BG tiledata/screen address, tile size, the BG and
OBJ *enable* bits, mosaic, window enables, interlace, colour math (`ppu.cpp:1336-1343`, `1621-1627`,
`1692+`).

That is precisely the reported signature. The WRAM oracle is deterministic because the ROM *computes*
it; the backdrop is not, because the ROM *inherits* it. The wrong colours seen in captures
(`#8CFFCE`, `#003A00`, `#EF20B5`, `#7A2000`, black) are a random colour-math enable adding or
subtracting a random fixed colour from a correct green backdrop, and a random window mask clipping
it to black.

`paint()` zeroed `TM`, `TS` and `BGMODE` — 3 of the ~48 registers that matter. The SDK already ships
the complete remedy, and its doc comment already names this exact failure mode:

```
build/install/mos-platform/snes/include/snes_ppu.h:330
  /* Force-blank the screen and reset the PPU CONTROL registers to a known-zero state ...
     SNES power-on leaves these indeterminate — bsnes-jg randomises them — so a program that
     configures only the registers it "uses" renders nondeterministically (a random mosaic,
     window mask, or colour-math enable corrupts the picture differently each boot). */
  static inline void snes_ppu_reset_blank(void)
```

### The recorded "red herring" was itself the red herring

`cartsize-canary.c` note 3 and the TODO item both record a *repo-wide harness finding* — that
`jgxcheck` PNG dumps of static-picture ROMs capture stale/partial frames, "proven against known-good
`hello.c`: green at 700 frames, mixed at 1100, 100% black at 1800". Those three numbers are three
separate **runs**, not three frames of one run. Under a pinned power-on `hello.c` is solid green at
every one of them. That claim is withdrawn; the source note and the TODO entry are corrected.

## Design

Two independent problems, two fixes; neither substitutes for the other.

1. **Reproducible measurement** — `JGX_ENTROPY` on `jgxcheck` (`0` = None). A picture gate that
   cannot re-run to the same bytes is not a gate.
2. **A ROM that does not depend on power-on state** — call `snes_ppu_reset_blank()` at boot. Real
   hardware powers on indeterminate, and the site's WASM player is this same bsnes-jg core at its
   default entropy, so this is what the published pages actually need.

*Rejected:* pinning entropy alone. It makes the gate green while leaving the published ROM rendering
a random picture in the visitor's browser — the exact "publish would look broken" risk on hold.

*Rejected:* per-frame PNG re-dumps to study settling (O(frames²), ~9 s per sample, and it samples
rather than covers). `JGX_FRAMESCAN` fingerprints the same buffer once per frame in one run — O(frames)
— and prints only the frames where the picture changed.

## Regression guard

The gate asserts the picture is **byte-identical under entropy None, Low and High**. That is the test
that would have caught this: it fails on any register the ROM depends on but does not set, and it is
insensitive to which random value happens to come up.

## Mockups

No visible surface of our own: the change makes an existing screen (a flat backdrop verdict) render
the colour it already intended, and adds no new UI. Evidence is the captured PNGs in §Verification.

## Verification

1. `bash dev/run.sh cartsize-canary` — all three configurations PASS (`canary_status=0`, oracles
   `0x48EE` / `0xA274` / `0x29B9`), including the new entropy-sweep step.

    ```
    ######## hirom4 — hirom 4M ########
    SMOKE: PASS off=0x53 len=2 got=0x48EE (ran 1800 frames, bsnes-jg)
      canary_status: SMOKE: PASS off=0x200 len=2 got=0x0000 (ran 1800 frames, bsnes-jg)
    ==> 6b) picture is independent of power-on entropy (None/Low/High x2)
      PASS: one picture across all six boots (11D41DC5:#00FF28)
    ######## exhirom6 — exhirom 6M ########
    SMOKE: PASS off=0x4C len=2 got=0xA274 (ran 1800 frames, bsnes-jg)
      canary_status: SMOKE: PASS off=0x200 len=2 got=0x0000 (ran 1800 frames, bsnes-jg)
    ==> 6b) picture is independent of power-on entropy (None/Low/High x2)
      PASS: one picture across all six boots (11D41DC5:#00FF28)
    ######## exhirom8 — exhirom 8M ########
    SMOKE: PASS off=0x43 len=2 got=0x29B9 (ran 1800 frames, bsnes-jg)
      canary_status: SMOKE: PASS off=0x200 len=2 got=0x0000 (ran 1800 frames, bsnes-jg)
    ==> 6b) picture is independent of power-on entropy (None/Low/High x2)
      PASS: one picture across all six boots (11D41DC5:#00FF28)

    RESULT: PASS — every decoded window, accepted mirror and cross-bank/cross-device span of the
    HiROM 4 MiB and ExHiROM 6/8 MiB canary cartridges reads the modelled byte, bsnes-jg confirmed
    (MAME skipped)
    ```

    **PASS.** All three configurations agree with the recorded oracles, and all three settle on the
    *same* picture hash `11D41DC5` (`#00FF28`, the green verdict) across six boots each. MAME leg
    skipped — the SPC700 IPL is still absent (`dev/roms/s_smp/spc700.rom`), unchanged blocker.

2. Repeated-capture determinism at a fixed frame count — the pre-fix (published) ROMs versus the
   fixed build. 8 runs per config at 700 frames.

    ```
    === PUBLISHED (pre-fix) ROMs, JGX_ENTROPY=1 (Low = bsnes-jg default) ===
      hirom-4m    3 distinct picture(s) in 8 runs
      exhirom-6m  5 distinct picture(s) in 8 runs
      exhirom-8m  7 distinct picture(s) in 8 runs
          observed finals: #000000, #00FF28, #04FF3A, #EF20B5, #7A2000
    === PUBLISHED (pre-fix) ROMs, JGX_ENTROPY=0 (None = pinned) ===
      hirom-4m    1 distinct picture in 8 runs   x8 final=#00FF28 hash=11D41DC5
      exhirom-6m  1 distinct picture in 8 runs   x8 final=#00FF28 hash=11D41DC5
      exhirom-8m  1 distinct picture in 8 runs   x8 final=#00FF28 hash=11D41DC5

    === FIXED ROM (hirom4), 6 runs each at the RANDOM settings ===
      JGX_ENTROPY=1 (Low):  1 distinct picture in 6 runs  x6 final=#00FF28 hash=11D41DC5
      JGX_ENTROPY=2 (High): 1 distinct picture in 6 runs  x6 final=#00FF28 hash=11D41DC5
    ```

    **PASS.** Pre-fix, the picture is a function of the power-on seed; pinning the seed collapses it
    to one. Post-fix, the picture is the same single hash under Low *and* High — and it is the very
    hash the pinned power-on produced, i.e. the ROM now renders its intended frame from any
    power-on state.

3. The live-page symptom, reproduced and then eliminated. The user reported the published 6 MiB page
   in Chrome showing a persistent dark-blue field split by a black **vertical** column ≈9 px wide at
   x ≈ 82 (`Screenshot_20260801_073558.png`). A vertical band that is not tile-aligned, over a
   backdrop with no tiles uploaded, is a PPU **window** clipping to black — one of the register
   groups left uninitialised. 24 boots of each ROM at 200 frames (inside the canary work, so the
   field is the "running" blue):

    ```
    PUBLISHED 6 MiB, JGX_ENTROPY=1:
      pub-11  field=#0A1971  black band at x=232..255 (w=24)
      pub-12  field=#0A1971  black band at x=32..69   (w=38)
      pub-19  field=#0A1971  black band at x=221..255 (w=35)
      pub-8   field=#DEFFFF  black band at x=2..12    (w=11)
      4/24 runs show a vertical black band over the running field

    FIXED 6 MiB, JGX_ENTROPY=1:
      0/24 runs show a vertical black band
      field colours across 24 boots: {'#0A1971': 24}
    ```

    **PASS.** The reported artifact reproduces at ~1 boot in 6 on the published ROM, at a random
    position and width each time — matching a random window register, and matching the user's
    single sample. The fixed ROM shows it in none of 24 boots and renders one identical field.
    `#0A1971` is exactly `SNES_RGB(2, 4, 14)`, the ROM's intended "running" blue.

4. Control — `hello.c`, the 25-line known-good ROM whose captures were the evidence for the
   withdrawn "jgxcheck captures stale frames" claim. It sets CGRAM and `INIDISP` and nothing else.

    ```
    hello.sfc  JGX_ENTROPY=1 Low (bsnes-jg default): 6 distinct picture(s) in 8 runs
         x3 final=#000000 pct=100 | x1 final=#F78430 pct=44 | x1 #000000 pct=50
         x1 #000000 pct=76 | x1 #000000 pct=84 | x1 #000000 pct=82
    hello.sfc  JGX_ENTROPY=0 None (pinned): 1 distinct picture(s) in 8 runs
         x8 final=#00FF00 pct=100 hash=3E8C1DC5
    ```

    **PASS (claim withdrawn).** Same frame count, 8 runs, 6 different pictures — the variance
    attributed to capture timing is power-on state. Pinned, `hello.c` is solid green every time.
    `hello.c` still carries the defect; see §Not fixed here.

## What the live page is, and is not

The site serves the byte-identical ROM tested above — fetched from
[cartsize-exhirom-6m.sfc](https://biohack.net/play/roms/cartsize-exhirom-6m.sfc), `sha256 bffc0b0a1ffc1e7e…`, equal to both
`public/` and `dist/`. It is **not** a stale pre-`92c1b74` build: it carries the `$212C`/`$212D`/`$2105`
stores that commit added (2 sites each, the same count as the fixed build), and it differs from the
fixed build in only 1,352 of 6,291,456 bytes. So "the fix was never republished" is eliminated — the
deployed ROM zeroes the three layer registers and inherits everything else, which is exactly the
state that produces the stripe.

The user then clicked **Verify fidelity** on that live page and got `0xA274 == gate` at 1800 frames.
That confirms the **compute path** end to end in the browser (WASM ExHiROM mapping was previously only
statically argued) — the user-gated manual WASM check is satisfied. It does **not**, however, prove
the paint loop is running, and the distinction matters:

```c
  canary_status = status;
  corpus_result  = h;          // <-- the value Verify fidelity reads, written BEFORE the loop
  uint16_t verdict = ...;
  for (;;) { paint(verdict); corpus_result = h; }
```

`corpus_result` reaches its final value before `paint(verdict)` is ever called, so a correct read is
equally consistent with "the loop is running" and with "the first `paint()` never returned". The
screen colour is measured as `(18, 31, 112)` against `SNES_RGB(2, 4, 14)` = `(16, 33, 115)`: the live
page is showing the **running** blue, i.e. no verdict paint has landed, not a verdict paint that
came out wrong.

**Open, and deliberately not guessed at:** locally, 8/8 runs of these same deployed bytes had left the
blue by frame 700, so the never-painting verdict does not reproduce under `jgxcheck`. Either the WASM
player hits a power-on state that hangs `wait_vblank_poll()`, or its run differs from `jgxcheck` in
some other way. Both candidates are confounded by the random power-on, so the cheap next move is to
republish the fixed ROMs and look again: if the page still holds blue against a now-deterministic
picture, that is a separate WASM-path defect, cleanly isolated. Note the fixed ROM's paint loop was
exercised 1,800 frames × 18 boots in the gate without stalling.

## Not fixed here

`snes_ppu_reset_blank()` is missing from four other demos that drive `INIDISP` directly —
`hello.c`, `boids.c`, `lsystem.c`, `turtle-vm.c`. (Everything else reaches the screen through
`snesgfx/display.h`, which already calls it.) Each will render a different picture per boot in the
site's WASM player exactly as the canary did. `lsystem` and `turtle-vm` are two of the ROMs whose
screenshot flakiness motivated the FROZEN-detector work in `d3000d7`, which is suggestive but not
established — none of that is in this change's scope.

The three published cartridge-size pages still serve the **pre-fix** ROMs, so they still render a
random picture per visitor; they need republishing from this build once the branch lands.


## Addendum (2026-08-01, later): gate 6b re-validated non-vacuously

seamdemo P1 found `build/jgxcheck` predated FRAMESCAN, so 6b had nothing to compare (the
script's own `=NONE` guard would have caught it loudly on the next run, but the step had not
re-run since the binary rebuild). With the rebuilt jgxcheck and the `|| true` probe guard added
to `dev/cartsize-canary.sh` (same pattern as `dev/seamdemo.sh`; without it a non-zero probe
exit aborts the whole gate under pipefail), the full gate re-ran:

- 3/3 configs PASS (`0x48EE`/`0xA274`/`0x29B9`, `canary_status=0`), bsnes-jg leg (MAME still
  IPL-gated).
- 6b genuinely comparing: **one picture across all six boots per config, `11D41DC5:#00FF28`**
  — the deterministic green verdict, matching the pre-republish evidence.
- 8 MiB ROM SHA `b4359721…` == the live deployed binary.
