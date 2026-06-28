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
   (paste output)
   ```
   PASS/FAIL:

2. **Factorial HUD renders cyan (palette 2), digits white, no priority artefact.**
   `dev/run.sh factorial` (or its driver) — PASS + screenshot shows cyan HUD row.

   ```
   (paste output)
   ```
   PASS/FAIL:

3. **Title screen shows immediately, then yields to the demo; gate still PASSes.**
   For Newton: `dev/run.sh newton` — RESULT: PASS; confirm `build/newton-mame.png` captures the
   filled fractal (title already dismissed by the screenshot frame), not the title.

   ```
   (paste output)
   ```
   PASS/FAIL:

4. **Whole battery regression — every demo's differential gate still GREEN after title wiring.**
   Run each `dev/run.sh <demo>` (newton, factorial, spirograph, pi/spigot, invaders, n-body,
   double-pendulum, 1d-ca, rdiff, blossom, mandel-shot) and confirm RESULT: PASS unchanged.

   ```
   (paste output per demo)
   ```
   PASS/FAIL:

5. **`-verify-machineinstrs` clean** for any demo whose corpus slice changed (none expected — these
   are display-only edits): `dev/run.sh corpus-a16`.

   ```
   (paste output)
   ```
   PASS/FAIL:

## Notes / risks

- A.1 is a confident revert backed by `hud.h:46` and the SNES tilemap spec; low risk. It is the only
  change strictly required to clear the user's reported garbage and can ship alone (Part B is additive).
- The screenshots are the real evidence here (visual bug) — do not mark `[verify]` complete on hash
  PASS alone; eyeball `build/*-{jg,mame}.png`.
- Investigation/measurement (if any title-timing tuning is needed) belongs on a `throwaway/` worktree
  per the project worktree rule, not on `main`'s working copy.
</content>
</invoke>
