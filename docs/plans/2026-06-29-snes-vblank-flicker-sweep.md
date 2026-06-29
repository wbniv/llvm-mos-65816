# SNES demo VBLANK / flicker sweep + display fixes

**Status:** DONE + PUBLISHED (2026-06-29). Swept all 23 SNES demos for the rule *"all PPU
writes (VRAM/CGRAM/OAM) and DMA happen only during V-blank or force-blank"*; fixed the three
real defects found and republished the affected demos to biohack.net (`v1.0.121`).

Supplements the standing guides (`~/SRC/CLAUDE.md`, project `CLAUDE.md`,
[`docs/agent-handoff.md`](../agent-handoff.md)). Related: the per-demo plans for
[#7 doom-fire](2026-06-28-7-snes-doom-fire.md), [#8 rdiff](2026-06-27-8-snes-rdiff-gray-scott.md),
[#6 1d-ca](2026-06-27-6-snes-rule90-110-1d-ca.md).

## Context

User reported doom-fire looking wrong ("flicker" → on closer look, **the display refresh is
halved**) and two rdiff issues (a poor website card; the on-screen title text obscured by the
diffusion), and asked for a sweep of every demo to ensure DMA/video updates happen only in
V-blank (HBLANK ok for HDMA) — i.e. no flicker.

## The pipeline invariant (what makes a demo safe by construction)

`snesgfx/display.h` `display_frame()` is the access window:

```
scene_emit();          // builds the UploadQueue — WRAM only, any scanline
snes_wait_vblank();    // block until v-blank begins
REG_INIDISP = 0x80;    // force-blank
upq_flush();           // the ONLY code that writes PPU data ports — DMA here
REG_INIDISP = INIDISP_ON;
```

So a demo that routes everything through `Display` + drawable `reserve()`/`emit()` is
flicker-safe: `reserve()` runs under the boot force-blank, `emit()` only enqueues to WRAM, and
the flush is bracketed by `wait_vblank` + force-blank. **`emit()` must touch WRAM only** — it
runs *before* `wait_vblank` (active display).

## Sweep results (all 23 demos)

| Class | Demos | Verdict |
|-------|-------|---------|
| `Display`-pipeline | burning-ship, cordic, double-pendulum, epicycles, factorial, harmonograph, invaders, life, maze, n-body, newton, raycaster, sort-race, spigot, spirograph | **SAFE** by construction |
| Hand-rolled Mode-7 | blossom, buddha, julia, mandel-display | **SAFE** — *deliberately* vblank-timed bounded DMA (one ~1 KB Mode-7 tile-row/frame) with **no** force-blank to avoid a brightness flash (see `mandel-display.c:14`) |
| minimal test | hello.c | benign (boot-time CGRAM write, no animation) |
| **defects** | doom-fire, rdiff, 1d-ca | **FIXED** (below) |

## The three fixes

1. **doom-fire — halved refresh.** `_fire_emit` uploaded only 14 of 28 tilemap rows per frame
   (alternating halves) while `fire_step` advanced the whole grid every frame → each half
   refreshed at 30 Hz, out of phase. **Fix:** full-grid `FireLayer.shadow[FIRE_H*FIRE_W]` and one
   1792 B DMA per frame (fits one NTSC v-blank with wide margin) → consistent 60 Hz.

2. **rdiff — title text buried.** In Mode 1 **BG1 (the diffusion grid) outranks BG2 (the
   title)**; rdiff seeded its whole opaque field *before* the title hold, so the spots covered the
   text. **Fix:** seed the field *after* `display_hide_layer()` so BG1 is transparent (tile 0)
   while the title shows. Documented the BG1>BG2 priority caveat in `snesgfx/title_layer.h`. Card
   capture bumped to 2000 frames so the Turing pattern is developed (was a half-empty 500-frame
   shot, the "2 blue dots" website card).

3. **1d-ca — scroll tear.** `REG_BG3VOFS` (a scroll latch) was poked in `_cad_emit()`, which runs
   *before* `wait_vblank` (active display) → a moving tear. **Fix:** added a vblank-applied
   `upq_push_scroll()` register-poke primitive to `snesgfx/upload.h` (a `UPQ_REG` job that
   `upq_flush()` writes twice during the v-blank window) and routed the scroll through it.

Also hardened the MAME leg of every `dev/<slug>.sh` gate script with the SPC700-IPL skip-guard
(absent IPL → SKIP, not FAIL; bsnes-jg + disasm still gate).

## Differential gate — verification

ROMs rebuilt from committed source in a clean worktree (reproducible; the main working tree was
mid foreign refactor, which shifts WRAM layout — see *Reproducibility note*). All RESULT PASS,
host == `+mos-a16` on bsnes-jg, disasm gates green, MAME SKIP (no SPC700 IPL in this env).

```
doom-fire: built (+mos-a16); corpus_result @ WRAM 0x22
  PASS  eor=6  asl/lsr=8  rep/sep=21
  SMOKE: PASS off=0x22 len=2 got=0x3C59 (ran 500 frames, bsnes-jg)
  RESULT: PASS — corpus hash 0x3C59 host == +mos-a16

rdiff: built (+mos-a16); corpus_result @ WRAM 0x20
  PASS  __mulsi3=6  rep/sep=55
  SMOKE: PASS off=0x20 len=2 got=0x5555 (ran 2000 frames, bsnes-jg)
  RESULT: PASS — corpus hash 0x5555 host == +mos-a16

1d-ca: built (+mos-a16); corpus_result @ WRAM 0x27
  PASS  shifts=7  bools=10  bad_mul=0  bad_div=0
  SMOKE: PASS off=0x27 len=2 got=0xAB2C (ran 400 frames, bsnes-jg)
  RESULT: PASS — corpus hash 0xAB2C host == +mos-a16
```

PASS — all three differentially clean; the display fixes do not touch the gate math.

## Reproducibility note (hot-tree)

The main working tree was being actively refactored by another worker (migrating every demo to a
new `title_begin`/`title_end` title API, uncommitted), which shifted demo WRAM layouts — a
main-tree build reported doom-fire `corpus_result` at `0x302`, but a clean worktree at committed
HEAD gives `0x22`. **Builds for publishing must come from a clean checkout of committed source**
(here: a hardlinked-toolchain worktree per [`docs/howto-feature-worktree.md`](../howto-feature-worktree.md)),
not from the churning main tree, or the verify-fidelity offset will be wrong.

## Publication

Republished the three ROMs + developed preview cards to biohack.net, tag `v1.0.121` (deploy
success). Verify-fidelity offsets updated to the clean-build layout (hashes unchanged):

| Demo | URL | off | want |
|------|-----|-----|------|
| doom-fire | [/snes/doom-fire/](https://biohack.net/snes/doom-fire/) | `0x22` | `0x3C59` |
| rdiff | [/snes/rdiff/](https://biohack.net/snes/rdiff/) | `0x20` | `0x5555` |
| 1d-ca | [/snes/1d-ca/](https://biohack.net/snes/1d-ca/) | `0x27` | `0xAB2C` |

Live manifest + ROM sha verified against the committed builds. Engine/`app.js` left untouched (a
re-scaffold would have regressed the live Fullscreen button).

## Verification — ROM render check without Chrome

The page boots the **same bsnes-jg WASM core** the gate trusts, so a **bsnes-jg screenshot of the
ROM is sufficient** to verify it renders — no Chrome headless shot needed. Chrome only adds a
page-*shell* check (centering/clipping), which is per-page and unchanged on a ROM-only republish.
The `snes-rom-page` skill's verify step was updated to say so.

## Files

| File | Change |
|------|--------|
| `examples/snes/doom-fire.c` | full-grid tilemap upload (60 Hz) |
| `examples/snes/rdiff.c` | seed field after title hold (BG1>BG2 z-order) |
| `examples/snes/1d-ca.c` | scroll via `upq_push_scroll` (vblank) |
| `examples/snes/snesgfx/upload.h` | `UPQ_REG` + `upq_push_scroll()` register-poke |
| `examples/snes/snesgfx/title_layer.h` | BG1>BG2 priority caveat (rides with a concurrent refactor) |
| `dev/*.sh` (13 gate scripts) | SPC700-IPL skip-guard |
| `.claude/skills/snes-rom-page/SKILL.md` | bsnes-jg render ⇒ ROM verified; Chrome optional |

## Verification steps

1. `dev/run.sh doom-fire` — RESULT PASS, `0x3C59`. ✓ (raw above)
2. `dev/run.sh rdiff` — RESULT PASS, `0x5555`. ✓
3. `dev/run.sh 1d-ca` — RESULT PASS, `0xAB2C`. ✓
4. Republish `v1.0.121` — GitHub Actions deploy success; live manifest off/want + ROM sha match. ✓
5. `task md -- docs/plans/2026-06-29-snes-vblank-flicker-sweep.md` renders cleanly.
