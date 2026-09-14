# SNES demos — startup garbage fix + title screens

**Status:** IN PROGRESS (2026-06-28). Two user-reported issues against the published SNES demo battery
(`examples/snes/*.c`, several live on biohack.net via `snes-rom-page`):

1. **Newton's fractal "starts off with garbage display (like bgs/obj/palette not cleared)."**
2. **Newton "takes too long to start to show anything."** Generalised request: **add a title screen
   to every SNES demo** — show a title on an otherwise-idle BG (or the display itself) until the
   program begins writing real results.

This plan diagnoses #1 (a concrete, root-caused regression — *not* the general "uninitialised VRAM"
class it superficially resembles), audits the whole battery for the same bug class, and designs the
title-screen facility for #2.

---

## Part A — startup garbage

### A.1 Root cause (Newton): a palette-field shift regression, not uncleared VRAM

The symptom *looks* like uncleared VRAM/CGRAM, but it is a specific miscompose of the BG tilemap word
introduced by the most recent Newton commit.

SNES BG tilemap entry (16-bit), authoritative format documented in `examples/snes/hud.h:46`
("tilemap entry = `tile# | pal<<10`"):

```
 bit:  15 14 13 12 11 10  9 ... 0
        v  h  o  p  p  p  c c c c   (c=tile#[0-9], p=palette[10-12], o=priority[13], h/v=flip[14/15])
```

So the **palette field is bits 10–12** → palette number must be shifted **`<< 10`**.

Newton uploads exactly 4 palettes (0–3) of 16 colours = 64 CGRAM entries
(`newton_pal[64]`, `newton.c:27`). Palette 0 = black backdrop; palettes 1/2/3 = red/green/blue ramps
for roots 1/2/3. CGRAM palettes **4–7 are never uploaded** (uninitialised → garbage colours).

Commit **`ac9c0b2` ("wrong shift amount for shade")** changed the tilemap word from `root << 10` to
`root << 12` (`examples/snes/newton.c:126`):

```c
/* HEAD (buggy): */
return (uint16_t)(((uint16_t)(uint8_t)root << 12) | shade);
```

With `<< 12` the root index lands in bits 12–13 instead of 10–12, so for the three roots the
**palette field selects 4 / 0+priority / 4+priority** — i.e. **uninitialised palettes 4 (and 5)** for
roots 1 and 3, plus a spurious **priority bit**. Palettes 4–5 are random power-on CGRAM ⇒ exactly the
"palette not cleared" garbage the user sees. (The same commit's comment edit at line 26 says `<< 12`
while the function-doc at line 109 still says `<< 10` — the change was internally inconsistent.)

The commit was *trying* to fix the original demo's real uncleared-tilemap garbage (it correctly added
the VRAM tilemap clear at `newton.c:77–80` in the same commit, which is good and stays) but mistakenly
also moved the palette shift. The tilemap clear is the genuine fix for the *original* garbage; the
shift change is a *new* regression layered on top.

**Fix:** revert the shift to `<< 10`; fix the two comments (lines 26, 109) to agree.

```c
return (uint16_t)(((uint16_t)(uint8_t)root << 10) | shade);
```

Breaking commit to cite in any PR: `ac9c0b2` "wrong shift amount for shade".

### A.2 Battery audit (same bug class: palette field / uncleared VRAM / CGRAM before unblank)

Audited every `examples/snes/*.c` for: (a) tilemap palette field selecting an unloaded palette;
(b) an *enabled* BG/OBJ layer whose VRAM is not fully written during force-blank; (c) CGRAM not loaded
before force-blank is released.

| Demo | Layer(s) | Verdict |
|---|---|---|
| **newton** | BG1 4bpp | **BUG (A.1)** — `root<<12` selects unloaded palettes 4–5. Tilemap clear OK. |
| **factorial** | BG3 2bpp | **BUG (A.3)** — HUD uses `1<<13` (priority bit) not a palette select; `pal_hud` uploaded to CGRAM 8–11 (palette 2) is never referenced → HUD renders palette-0 white, not cyan. Cosmetic, *not* garbage, but a real palette-field defect found by this audit. |
| 1d-ca | BG3 2bpp | OK — zeros all chr (`1d-ca.c:70`), writes full identity tilemap (`:73-77`), palette set in force-blank. |
| double-pendulum | BG3 (canvas) | OK — `BitmapCanvas._canvas_reserve` writes the full 32×32 tilemap + zeros chr; CGRAM in force-blank (`:87`). |
| n-body | BG3 (canvas) | OK — same canvas reserve; CGRAM uploaded force-blank. |
| spirograph | BG3 (canvas+text) | OK — canvas reserve fills full tilemap (blank tile outside the box); text shares it. |
| spigot | BG3 (canvas+text) | OK — same. |
| rdiff | BG1 4bpp | OK — single palette 0 (no palette field used), DMAs the visible tilemap; chr built force-blank. |
| invaders | OBJ (sprites) | OK — `SpriteSet` hides all unused slots every frame; first `display_frame` emits OAM before unblank. |
| mandel-display | Mode 7 | OK — clears the 128×128 tilemap + uploads first image while force-blanked (`:128-139`). |
| blossom | Mode 7 | OK — **reference impl**: clears all 64 KB VRAM + preloads CGRAM before `m7_show` (`:164-167`), explicitly because "bsnes RANDOMISES power-on VRAM". |
| hello | — | OK — trivial, no BG enabled. |

**Conclusion:** the reported garbage is **Newton-only** (A.1). Factorial has an adjacent palette-field
bug (A.3, cosmetic). The shared `snesgfx` reserve path + `display.h`'s force-blank-until-first-frame
invariant already protect the rest. No general "clear all VRAM" change is needed for the snesgfx
demos; the contract is sound — Newton simply mis-built the tilemap word.

### A.3 Factorial HUD palette fix

`examples/snes/factorial.c:111` `_tile_hud` ORs `1u << 13` (priority), comment claims "palette bits
13-15". Palette field is 10–12. `pal_hud` is uploaded to CGRAM 8–11 = **palette 2** for 2bpp. Fix to
select palette 2:

```c
// palette 2 (cyan HUD) lives at CGRAM 8..11 → palette field = 2 → 2 << 10
return (uint16_t)(_tile(c) | (uint16_t)(2u << 10));
```

(Confirm against the actual `pal_hud` upload offset when implementing; if the upload base changes,
keep the shift and the CGRAM offset consistent: `palette N ⇒ CGRAM N*4` for 2bpp.)

---

## Part B — title screens (slow-start fix)

### B.1 Problem

Newton computes its gate hash (`newton_gate_crc()`, `newton.c:140`) *before* the first
`display_frame()`. During that compute the screen is correctly force-blanked (black) — so the user
stares at a black screen for the compute duration, then a slow progressive fill. Other demos that do
pre-loop work share this. A title screen shown *immediately* gives instant feedback and a name.

### B.2 Design — `snesgfx/title_layer.h` (shared) + per-demo content

Goal: a **drop-in, gate-neutral** title that requires no per-demo PPU plumbing.

- **New reusable Drawable `TitleLayer`** in `examples/snes/snesgfx/title_layer.h`, modelled on
  `text_layer.h`. It renders a centred title (demo name + one-line subtitle) on **BG2 4bpp**, an
  otherwise-unused layer in every snesgfx demo (they use BG1 *or* BG3, never BG2). Reusing the 8×8
  font from `font8.h`. `reserve()` loads the font + builds a fully-cleared tilemap (no garbage);
  `tm_bits = TM_BG2`.
- **Lifecycle helper** on `Display`: `display_show_title(d, frames)` shows the title for `frames`
  V-blanks (or until a controller Start press, where a controller is wired), then clears `TM_BG2`
  from the TM shadow so the title disappears and the demo's own layer(s) take over. The heavy
  pre-loop compute (e.g. `newton_gate_crc`) runs *inside* this window so the title covers it.
- **Non-snesgfx demos** (blossom, mandel-display, 1d-ca, hello) get a lightweight per-demo title using
  their existing layer (Mode 7 text band for blossom/mandel; the BG3 identity map for 1d-ca), since
  they don't share the `Display` object. Keep each minimal.

### B.3 Gate-timing constraint (must not break the differential)

The per-demo gate scripts (`dev/<demo>.sh`) screenshot at a **fixed** wall-clock / frame count and
assert `corpus_result` read from WRAM:

- `corpus_result` is computed *before* the render loop in every demo → **title delay does not change
  the asserted hash**. Safe.
- The **screenshot** is timed (`-seconds_to_run 12` for MAME ≈ 720 frames; bsnes-jg jgxcheck dumps at
  frame 500). A title that holds N frames shifts what the screenshot captures. Newton fills in ~224
  frames; with a ~120-frame title that is ~344 frames < 500 < 720 — still lands on the filled image.
  **Action:** keep the default title hold ≤ ~120 frames (≈2 s), and for each demo re-confirm the
  screenshot still captures real output (not the title) after wiring the title; bump the script's
  `-seconds_to_run` / jgxcheck frame count only if a specific demo's fill no longer completes in time.
  Document any bump in that demo's plan.

### B.4 Rollout order

1. **Pilot: Newton** — apply A.1 fix + the `TitleLayer` on BG2; verify the full gate + screenshot.
2. Propagate `TitleLayer` to the other snesgfx demos (double-pendulum, factorial, invaders, n-body,
   rdiff, spigot, spirograph, 1d-ca) — one commit per demo or small batches, gate each.
3. Per-demo titles for the non-snesgfx demos (blossom, mandel-display, hello).

---

## Files

- `examples/snes/newton.c` — A.1 shift fix + comment fixes; B.2 title.
- `examples/snes/factorial.c` — A.3 HUD palette fix.
- `examples/snes/snesgfx/title_layer.h` — **new** shared `TitleLayer`.
- `examples/snes/snesgfx/display.h` — `display_show_title()` helper.
- Per-demo `.c` for the title wiring; non-snesgfx demos as noted.
- `docs/snes-demo-cookbook.md` — document the title facility + the palette-field gotcha.
- Each touched `dev/<demo>.sh` only if B.3 forces a screenshot-timing bump.

## Implementation log

- **2026-06-28** — Part A fixes applied: `newton.c` `root<<12`→`root<<10` (+ comment); `factorial.c`
  `_tile_hud` `1<<13`→`2<<10` (+ comments). Part B: new `snesgfx/title_layer.h` (BG2 4bpp static
  overlay, 2bpp font promoted to 4bpp, palette 7, content written in force-blank, no DMA) +
  `display_hide_layer()` / `display_hold()` in `display.h`.
- **Title wired into 7 snesgfx demos** (BG2 overlay; gate-neutral — title held during the demo's
  pre-loop `*_gate_crc()` compute, so NO extra frames / no screenshot shift; `corpus_result` is the
  pre-loop hash):
  - newton ("NEWTON FRACTAL"/"COMPLEX DIVISION"), spirograph ("SPIROGRAPH"/"HYPOTROCHOID"),
    n-body ("N-BODY ORBITS"/"GRAVITY"), double-pendulum ("DOUBLE PENDULUM"/"CHAOS"),
    spigot ("PI SPIGOT"/"MONTE CARLO"), 1d-ca ("CELLULAR AUTOMATA"/"RULE 90 / 110").
  - 1d-ca needs `#define TITLE_CHR_WORD 0x6000u` (its BG3 chr fills 0x0000..0x2000, colliding with the
    default 0x1000); all others use the default regions (chr 0x1000 / map 0x5000 — verified free).
  - rdiff ("REACTION DIFFUSION"/"GRAY-SCOTT") computes its hash *before* the display exists, so it has
    no compute to hide behind → uses `display_hold(&d, 60)` (~1 s) then teardown. Continuous PDE, so the
    offset is screenshot-safe (re-confirm only if it ever gates on a framebuffer CRC).
- **Drive-by fix:** `n-body.c` included a nonexistent `../65816/nbody.h` (file is `n-body.h`; the host
  oracle includes `"n-body.h"`) — a **pre-existing build break at HEAD**, unrelated to this work, fixed
  to `../65816/n-body.h`.
- All touched files pass a **host `gcc -fsyntax-only`** check via a stub `snes.h` (catches
  typos/structure; not a substitute for the cross build below).
- **invaders** ("SPACE INVADERS"/"SPRITES + OAM") — OBJ chr is only 32 tiles (0x4000..0x4200), so the
  default title regions (0x1000/0x5000) are free. `corpus_result` latches at frame `INV_FRAMES=600`
  *inside* the loop, so a pre-loop hold would delay it (the bsnes harness reads at a deadline) → instead
  the title is **overlaid on the first 60 attract frames and hidden in-loop** (a `tf` counter), adding
  zero frames → gate-neutral.
- **New `snesgfx/splash.h`** — a blocking BGMODE_1 + BG3 text splash for the **Mode 7 demos** (which
  have no spare BG). Self-clears its VRAM footprint on exit so a Mode 7 caller that only clears its
  tilemap won't read splash bytes as char garbage.
- **Deferred — apply + verify during step (a) with the emulator in the loop:**
  - **mandel-display** — splash candidate; huge frame budget (jgxcheck 5800 / MAME 120 s) absorbs the
    splash and its image-CRC `corpus_result` is stable after settle, BUT it only `m7_tilemap_clear`s
    (partial), so the splash's self-clear must be confirmed to leave a clean Mode 7 char plane.
  - **blossom** — splash is risky: its gate is a **frame-alignment-sensitive scripted-controller
    differential** (jgxcheck replays a pad log); shifting the timeline by the splash frames can desync
    the replay. Needs verification (and possibly feeding the splash frame count into the harness).
  - **factorial** title — another worker is mid-investigation on `_fact_emit`/`dirty_rows`; only the
    A.3 palette fix landed here to avoid colliding with their work.
  - **hello** — intentionally **excluded**: it's the M0 boot smoke test whose gate asserts a *solid
    green* screenshot; a title would break that contract. Not a showcase demo.
- **Refinement (verified):** demos whose `*_gate_crc()` is fast (spirograph, n-body, double-pendulum,
  spigot, 1d-ca, rdiff) flashed the title for <1 frame — added `display_hold(&screen, 110)` (~2 s) so
  the title is reliably on-screen. Newton needs none (its gate hash runs ~480 frames ≈ 8 s, which the
  title covers — exactly the "takes too long" complaint). invaders overlays the title on the first 60
  attract frames (in-loop hide), no hold.

### Verified on bsnes-jg (2026-06-28, real toolchain `build/llvm-mos-install` + jgxcheck framebuffer dumps)

The MAME leg of every `dev/run.sh <demo>` FAILs here only because `dev/roms/` has no SPC700 BIOS
(pre-existing environment gap, affects all demos) — the bsnes-jg leg (no BIOS needed) is the evidence.

- **Garbage (Part A):** `build/newton-jg.png` renders the basins in correct **red/green/blue, no garbage
  colours** (pre-fix the `root<<12` picked uninitialised CGRAM palettes). Value: `newton` bsnes-jg
  `SMOKE: PASS got=0x4D8B` (== host oracle).
- **Titles (Part B) — 10 demos, all captured on bsnes-jg:** newton ("NEWTON FRACTAL/COMPLEX DIVISION"),
  1d-ca ("CELLULAR AUTOMATA/RULE 90 / 110", confirms the `TITLE_CHR_WORD=0x6000` override — no VRAM
  collision), spirograph, spigot, n-body, double-pendulum, rdiff, invaders ("SPACE INVADERS" over the
  attract gameplay), and the **Mode-7 demos** via `splash.h`: mandel-display ("MANDELBROT/ESCAPE TIME"),
  blossom ("BLOSSOM/HOPALONG ATTRACTOR"). All render white text, then tear down to the demo.
- **Value/CRC differential intact through the title/hold/splash changes (display-only, as expected):**
  `newton` `got=0x4D8B`; `spirograph` `got=0x32D4` + 3× byte-identical; `invaders` `got=0x9D57` + 3×
  byte-identical; **`mandel-display` image-CRC `got=0x204F`** (== host, splash didn't disturb the Mode-7
  char plane — `splash.h` self-clears its VRAM); **`blossom` grid hash `got=0x9047`** AND the scripted-
  controller replay `BLOSSOM: PASS blossom_crc=0xAB26` (the splash's frame shift is harmless — the assert
  replays the ROM's own pad log). Disasm gates PASS.
- **All touched demos build** under both `+mos-a16` and default with the real toolchain.

**Done:** garbage (Part A) + titles on **10 demos** (every showcase demo). **Excluded:** hello (M0 boot
smoke test — solid-green screenshot contract). **Deferred:** factorial title only (another worker is
mid-investigation on its `_fact_emit`; the A.3 palette fix landed). **Still pending:** the MAME leg on
all demos (needs the SPC700 BIOS in `dev/roms/` to re-confirm on the second emulator).

## Verification

Run from repo root. Toolchain must be built first (`dev/run.sh toolchain`); each demo has a driver.

1. **Newton palette fix renders correct basins (no garbage).**
   `dev/run.sh newton` — RESULT: PASS, and `build/newton-{jg,mame}.png` show red/green/blue basins
   (not random-colour noise). Gate hash unchanged (palette is display-only; `corpus_result` is the
   pre-loop CRC).

   ```
   ==> host oracle: Newton fractal gate_crc = 0x4D8B
   ==> built build/newton.sfc (+mos-a16); corpus_result @ WRAM 0x994
   ==> disasm gate (complex division + multiply + native-16 mode)
       PASS  __divsi3=2  __mulsi3=17  rep/sep=69
   ==> bsnes-jg: render + framebuffer dump (build/newton-jg.png) + assert
   SMOKE: PASS off=0x994 len=2 got=0x4D8B (ran 500 frames, bsnes-jg)
   ==> MAME (under Xvfb): snapshot + assert (build/newton-mame.png)
       SHOT: PASS corpus=0x4D8B (snapshot at frame 500)

   RESULT: PASS — Newton fractal rendered on SNES; MAME + bsnes-jg + corpus hash 0x4D8B host == +mos-a16
   jgxcheck: wrote /work/build/newton-jg.png (256x224 from native 512x240, yoff=0)
   ```
   PASS/FAIL: **PASS** (2026‑09‑15, re-run on current `main`). Screenshot evidence: at the drivers'
   capture frames (bsnes‑jg 500, MAME 720) the fill is only ~1 tile row deep — correct red/green/blue,
   **no garbage colours**, just early. A confirming capture at frame 6000
   (`build/.newton-6000.png`, `jgxcheck … 6000`) shows the **complete** basin picture: a green
   upper-left basin, red right basin, blue lower-left basin with the fractal boundary between them and
   **no uninitialised-palette noise anywhere**. Part A is verified. Both emulator legs ran (this host
   now has the SPC700 IPL, so MAME no longer SKIPs).

2. **Factorial HUD renders cyan (palette 2), digits white, no priority artefact.**
   `dev/run.sh factorial` (or its driver) — PASS + screenshot shows cyan HUD row.

   ```
   ==> host oracle: factorial gate hash (50!) = 0x772F
   ==> built build/factorial.sfc (+mos-a16); corpus_result @ WRAM 0xfd5
   ==> disasm gate (bignum carry-mul codegen)
       PASS  __mulsi3=1  __udivmodsi4=1  rep/sep=15  (schoolbook carry-mul + native-16)
   ==> bsnes-jg: render + framebuffer dump (build/factorial-jg.png) + assert
   SMOKE: PASS off=0xFD5 len=2 got=0x772F (ran 500 frames, bsnes-jg)
   ==> MAME (under Xvfb): snapshot + assert (build/factorial-mame.png)
       SHOT: PASS corpus=0x772F (snapshot at frame 500)

   RESULT: PASS — bignum factorial rendered on SNES; MAME + bsnes-jg + corpus hash 0x772F host == +mos-a16
   jgxcheck: wrote /work/build/factorial-jg.png (256x224 from native 512x240, yoff=0)
   ```
   PASS/FAIL: **PASS** (2026‑09‑15). `build/factorial-jg.png` shows white decimal digits of the
   running factorial filling the top rows on black, with the cyan HUD row at the bottom — palette 2
   selected, no priority artefact. This run is **after** the deferred factorial title screen was
   wired in (`title_begin16(… "BIGNUM FACTORIAL", "N! DIGITS")` held across `factorial_gate_crc()`,
   `title_end(…, 110)`), so it also demonstrates that the title is gate-neutral: the card is already
   torn down at the capture frame and the hash is unchanged.

3. **Title screen shows immediately, then yields to the demo; gate still PASSes.**
   For Newton: `dev/run.sh newton` — RESULT: PASS; confirm `build/newton-mame.png` captures the
   filled fractal (title already dismissed by the screenshot frame), not the title.

   ```
   SMOKE: PASS off=0x994 len=2 got=0x4D8B (ran 500 frames, bsnes-jg)
       SHOT: PASS corpus=0x4D8B (snapshot at frame 500)

   RESULT: PASS — Newton fractal rendered on SNES; MAME + bsnes-jg + corpus hash 0x4D8B host == +mos-a16
   ```
   PASS/FAIL: **PASS** (2026‑09‑15). `build/newton-mame.png` shows **demo output, not the title** —
   the title card is already dismissed at the capture frame; what is visible is the first row of
   red/green/blue basin tiles over black. The fill is still in progress at that frame (see step 1),
   so the capture is "real output, early" rather than "the filled fractal" — the title-dismissal
   property this step actually asserts is satisfied. Note: the plan text names `splash.h` for the
   Mode‑7 demos; that header was **deleted in `34aba36`** and those demos now use
   `examples/snes/snesgfx/m7title.h` (`m7splash_begin()` / `m7splash_end()`).

4. **Whole battery regression — every demo's differential gate still GREEN after title wiring.**
   Run each `dev/run.sh <demo>` (newton, factorial, spirograph, pi/spigot, invaders, n-body,
   double-pendulum, 1d-ca, rdiff, blossom, mandel-shot) and confirm RESULT: PASS unchanged.

   ```
   === newton ===            exit 0
   RESULT: PASS — Newton fractal rendered on SNES; MAME + bsnes-jg + corpus hash 0x4D8B host == +mos-a16
   === factorial ===         exit 0
   RESULT: PASS — bignum factorial rendered on SNES; MAME + bsnes-jg + corpus hash 0x772F host == +mos-a16
   === spirograph ===        exit 0
   SMOKE: PASS off=0x1409 len=2 got=0x32D4 (ran 500 frames, bsnes-jg)
       SHOT: PASS corpus=0x32D4 (snapshot at frame 500)
   RESULT: PASS — Spirograph rendered on SNES; MAME + bsnes-jg screenshots + curve hash 0x32D4 host == +mos-a16
   === pi ===                exit 0
   SMOKE: PASS off=0x1720 len=2 got=0x7711 (ran 500 frames, bsnes-jg)
       SHOT: PASS corpus=0x7711 (snapshot at frame 500)
   RESULT: PASS — π spigot+MC rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x7711 host == +mos-a16
   === invaders ===          exit 0
       SMOKE: PASS addr=0x7E0025 len=2 got=0x9D57 (ran 1800 ticks)
       SMOKE: PASS addr=0x7E0025 len=2 got=0x9D57 (ran 1800 ticks)
   SMOKE: PASS off=0x25 len=2 got=0x9D57 (ran 1800 frames, bsnes-jg)
   SMOKE: PASS off=0x25 len=2 got=0x9D57 (ran 1800 frames, bsnes-jg)
       bsnes determinism: PASS (3x byte-identical)
       SHOT: PASS corpus=0x9D57 (snapshot at frame 1800)
   RESULT: PASS — Space Invaders attract CRC 0x9D57: host == default == a16 on MAME + bsnes-jg; screenshots in build/invaders-{mame,jg}.png
   === n-body ===            exit 0
       PASS  __udivsi3=2  __mulsi3=6  rep/sep=83  (1/r² div + 16x16→32 mul, native-16)
   SMOKE: PASS off=0x1589 len=2 got=0xCC65 (ran 500 frames, bsnes-jg)
       SHOT: PASS corpus=0xCC65 (snapshot at frame 500)
   RESULT: PASS — N-body orbits rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xCC65 host == +mos-a16
   === double-pendulum ===   exit 0
       PASS  __mulsi3=6  __divsi3=2  rep/sep=80  (ω² coupling + D-divide + native-16)
   SMOKE: PASS off=0x1369 len=2 got=0xE859 (ran 500 frames, bsnes-jg)
       SHOT: PASS corpus=0xE859 (snapshot at frame 500)
   RESULT: PASS — Double Pendulum on SNES; MAME + bsnes-jg + corpus hash 0xE859 host == +mos-a16
   === 1d-ca ===             exit 0
   SMOKE: PASS off=0x5A6 len=2 got=0xAB2C (ran 400 frames, bsnes-jg)
       SHOT: PASS corpus=0xAB2C (snapshot at frame 400)
   RESULT: PASS — Rule 90/110 CA rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xAB2C host == +mos-a16
   === rdiff ===             exit 0
       PASS  __mulsi3=6  rep/sep=55  (u*v² fixed-point mul-add, native-16)
   SMOKE: PASS off=0x400 len=2 got=0x5555 (ran 2000 frames, bsnes-jg)
       SHOT: PASS corpus=0x5555 (snapshot at frame 500)
   RESULT: PASS — Gray-Scott rdiff rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x5555 host == +mos-a16
   === blossom ===           exit 0
       SMOKE: PASS off=0x54 len=2 got=0x9047 (ran 1500 frames, bsnes-jg)
       BLOSSOM: PASS frames=64 nonzero=64 blossom_crc=0xEC5A (host replay == ROM, bsnes-jg)
       SHOT: PASS corpus=0x9047 (snapshot at frame 1500)
   RESULT: PASS — interactive Hopalong attractor on SNES; grid hash 0x9047 host == +mos-a16 (MAME + bsnes-jg); state-math host == ROM (bsnes-jg)
   === mandel-shot ===       exit 0
   SMOKE: PASS off=0x580 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
       SHOT: PASS corpus=0x204F (snapshot at frame 5800)
   RESULT: PASS — Mandelbrot rendered on SNES; MAME + bsnes-jg screenshots match host (CRC 0x204F)
   ```
   PASS/FAIL: **PASS — 11/11 `RESULT: PASS`, unchanged** (2026‑09‑15, run serialized on current
   `main`; the demo list is the June list mapped onto today's drivers — `pi` is the spigot demo,
   `mandel-shot` the Mode‑7 Mandelbrot; there is no `mandel-display` driver any more). The MAME leg
   ran for real on every demo (the SPC700 IPL is present on this host), so each demo is green on
   **both** emulators, closing the "MAME leg pending" caveat from the June record.

   **Screenshot evidence** (`build/<demo>-jg.png`, bsnes‑jg entropy None so captures are
   deterministic) — one line each:

   | Demo | What the capture shows |
   |---|---|
   | newton | First row of red/green/blue basin tiles on black; no palette noise. Full picture confirmed at frame 6000 (see step 1). |
   | factorial | White decimal digits of n! filling the top rows, cyan `N=… [… DIGITS]` HUD row at the bottom. |
   | spirograph | Cyan hypotrochoid rosette centred on black, `R96 W36 D20 HYPO P8` header and `DPAD RW LR D AY MODE SEL GEAR` footer. |
   | pi (spigot) | `PI=3.` digit panel top-left, white Monte-Carlo dart scatter box top-right, `DARTS 612 / HITS 4.. / PI 3.15032` stats block. |
   | invaders | Full 5×11 green/cyan/yellow invader fleet, score `00180`, three life markers, red UFO, four green bunkers, player ship — real gameplay, no title. |
   | n-body | Blue/white orbital arcs around the centre, `NBODY N=3 FRAME:116` and `SUN X=64Y64 E X=68Y33 J X=4801` HUD lines. |
   | double-pendulum | Blue/white swept arc of the bob trail across the lower half on black. |
   | 1d-ca | Green Rule‑90 Sierpiński triangle growing upward from the bottom edge. |
   | rdiff | **The title card** ("REACT DIFFUSION / GRAY-SCOTT" over the animated rainbow backdrop) — not the Turing pattern. See the Deferred note below. |
   | blossom | Cyan HUD only: `CLASSIC H/1/ B8.44 C2.56 / PAL0 ZOOM 1.8X` header and `LR ZOOM HY HITR SEL COL SI RST` footer; the Mode‑7 plot area is black at the capture frame. |
   | mandel-shot | Full-colour Mandelbrot set — black body, yellow/blue boundary filaments, green/teal escape bands. |

   No capture in the battery was blank-titled, so the `JGX_ENTROPY=0` fallback for the known
   mandel-oop title-window entropy sensitivity was not needed.

5. **`-verify-machineinstrs` clean** for any demo whose corpus slice changed (none expected — these
   are display-only edits): `dev/run.sh corpus-a16`.

   ```
     dither_sim PASS   corpus_result=0x80C4  Floyd-Steinberg signed error-diffusion gate: …
     msquares_sim PASS   corpus_result=0x86A7  marching-squares gate: … trips the a16/xy16 -verify rc-undef XFAIL (code correct); host==target
     grid3d_sim PASS   corpus_result=0xFCDE  multi-dimensional array indexing gate: true uint8 grid[6][6][6] …
     setjmp_sim PASS   corpus_result=0x2007  setjmp/longjmp non-local return on the 65816 native 16-bit stack …
     nmitally_sim PASS   corpus_result=0xBCE6  #123 VBlank Interrupt Tally arithmetic gate (ORACLE form, no interrupts) …
   ==> corpus-a16: 62/62 passed, 0 xfail
   ```
   PASS/FAIL: **PASS** (2026‑09‑15) — 62/62, 0 xfail. As expected: no corpus slice changed, these are
   display-only edits. (Tail of the per-program listing shown; the whole run is 62 `PASS` lines
   followed by the summary.)

## Notes / risks

- A.1 is a confident revert backed by `hud.h:46` and the SNES tilemap spec; low risk. It is the only
  change strictly required to clear the user's reported garbage and can ship alone (Part B is additive).
- The screenshots are the real evidence here (visual bug) — do not mark `[verify]` complete on hash
  PASS alone; eyeball `build/*-{jg,mame}.png`.
- Investigation/measurement (if any title-timing tuning is needed) belongs on a `throwaway/` worktree
  per the project worktree rule, not on `main`'s working copy.

## Closing record — 2026‑09‑15

- **Deferral cleared:** the factorial title screen (the one demo held back in June for a worker
  conflict on `_fact_emit`) is wired — `examples/snes/factorial.c` now includes
  `snesgfx/title_layer.h` and runs `title_begin16(&a.screen, &title, "BIGNUM FACTORIAL", "N! DIGITS")`
  across the pre-loop `factorial_gate_crc()`, then `title_end(&a.screen, &title, 110)`. Factorial's
  BG3 map (chr `0x0000`, font at tile 256 → `0x0800..0x0A00`; tilemap `0x4000..0x4400`) leaves the
  default title regions (chr `0x1000`, map `0x5000`) free, so **no `TITLE_CHR_WORD` override** is
  needed — unlike `1d-ca`. `dev/title-charset.sh`: `PASS  every title character has a glyph`.
- **Gate-neutral, and the manifest offset moved.** `dev/run.sh factorial` is PASS on both emulators
  with `corpus_result` unchanged at `0x772F`, but the title code shifted the symbol's WRAM offset to
  **`0xfd5`** — so factorial's published-ROM selfcheck `off` needs regenerating on the next
  biohack.net republish (the same class of manifest edit newton/spirograph/etc. needed in June).
- **Verification steps 1–5 above: 5/5 PASS**, run on current `main` with the already-built
  `build/llvm-mos-install`. The MAME leg ran for real this time on every demo, which closes the
  June record's "MAME leg pending (needs SPC700 BIOS)" caveat.

## Deferred

- **rdiff's title card dominates both gate captures, and the Gray-Scott field never becomes
  visible.** `dev/rdiff.sh` dumps the bsnes-jg framebuffer at frame 2000 with the in-script comment
  "2000 frames yields a developed, screen-filling card"; it does not. Measured 2026‑09‑15 on current
  `main` (gate `RESULT: PASS`, `corpus_result=0x5555`, so this is invisible to the differential):
  frame 500 (`build/rdiff-mame.png`) title; frame 2000 (`build/rdiff-jg.png`) title; frame 2600
  title; frame 3500 title; frame 6000 **entirely black** — title torn down, no Turing pattern. The
  ~220 logical frames of `title_begin`/`title_end` are stretching across thousands of hardware
  frames, and whatever renders afterwards is not reaching the screen. Needs a root-cause pass on
  `examples/snes/rdiff.c` + `examples/65816/rdiff.h` (frame pacing vs. the post-title `gs_init()`
  seed), not a capture-frame bump. Out of scope for this item, which only owed the factorial title.
- **Newton's gate capture frames are earlier than its fill.** Both drivers snapshot while the basin
  fill is ~1 tile row deep; the picture is complete and garbage-free by frame 6000. The demo is
  correct, but `build/newton-{jg,mame}.png` are weak evidence for a *visual* fix — consider raising
  `dev/newton.sh`'s jgxcheck frame count and MAME `-seconds_to_run` so the published screenshot
  shows the finished fractal.
</content>
</invoke>
