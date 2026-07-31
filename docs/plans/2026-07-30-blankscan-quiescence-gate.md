# BLANKSCAN: require a quiescent baseline — fixes the `lsystem` false positive

**Status:** authored and implemented by a prior session **2026-07-30**, left uncommitted in the
working tree. Independently root-cause-verified and **adopted + committed 2026-07-31** by a later
session, which re-ran the evidence below on the shipped ROM rather than taking it on trust. Closes
the `[T3] lsystem BLANKSCAN` TODO item, which blocks promoting `[T2] Rebuild + republish` to Done.

## Problem

`dev/verify-web-roms.sh` reports one failing demo:

```
BLANKSCAN: frame 1154 has 149 black rows at top (neighbours 143 / 142)
BLANKSCAN: FAIL 1 frame(s) with a transient black band at the top
```

`lsystem` is **not** bleeding force-blank. Measured on the shipped ROM (`build/jgxcheck`, one PNG
per frame, leading-black-rows in BLANKSCAN's own `yoff=8` coordinates):

| blankscan idx | leading_black | total_ink | what is happening |
|---|---|---|---|
| 1145–1150 | 47 | 189 | grown plant, holding (`HOLD_FRAMES 150`) |
| 1151 | 79 | 137 | `canvas_clear()` front sweeping down |
| 1152 | 111 | 41 | |
| 1153 | 143 | 14 | |
| **1154** | **149** | **11** | **flagged** — apex |
| 1155 | 142 | 15 | regrowth overtakes the clear front |
| 1156 | 135 | 18 | |
| 1161 | 108 | 26 | plant regrowing from the trunk |

`total_ink` collapsing 189 → 11 and climbing back is a **wholesale content change** — the opposite
of bleed, whose signature is *the picture unchanged with the top N rows forced black*.

### Why it happens

`lsystem.c:114` is explicit: "grown, hold, then clear and regrow from the trunk". `canvas_clear()`
dirties all 256 canvas tiles, but `bitmap_canvas.h` caps the flush at `CANVAS_FLUSH_TILES 64` per
frame, so the clear reaches VRAM over **4 frames**, sweeping top-down (tiles are row-major). The
regrowth restarts from the trunk at the bottom on the very next frame. Frame 1154 is where the
descending clear front crosses the ascending regrowth — a **local maximum by construction**.

`blank_scan_report` flags any frame exceeding its *higher* neighbour by `>= threshold` (default 4).
That comparison was chosen so the title's gravity exit — a monotonic 0→224 ramp, where every frame
beats its predecessor but none is a local max — is not flagged. An **apex is exactly the case that
survives** that exclusion: two monotone ramps meeting.

### Why no `leading_black`-only rule can fix it

Locally the apex is indistinguishable from real bleed: neighbours 143 and 142 are nearly equal, with
a 6-row excursion between them. That is textbook bleed shape. The transition is only visible over a
**wider window** (47 → 149 → 108 across ±10 frames). Raising the threshold would not help either —
it would have to exceed 6, blinding the check to small genuine bleeds.

Also ruled out as discriminators, against this data:

- *Neighbour dissimilarity* (`|v[i-1] - v[i+1]|` large ⇒ transition): fails — 143 vs 142.
- *Ink change between neighbours*: fails — ink 14 vs 15 at the apex.

## Decision

Flag a spike only when it sits on a **quiescent baseline**. Force-blank bleed is a one-frame
excursion on an otherwise stable picture (a late-released force blank during DMA setup); a spike
embedded in an active transition is not evidence of it.

Concretely, in `blank_scan_report`: for candidate frame `i`, take the window `v[i-W .. i+W]`
excluding `i` itself. Require its spread (`max - min`) to be `< quiet_threshold`. If the
surrounding window is itself sweeping, skip the candidate.

- `W = 5`, `quiet_threshold = 8` (both env-overridable for investigation).
- `lsystem` window excluding 1154: `{111,143,142,135,128,123,115,...}` → spread ≥ 32 → **skipped**.
- A bleed on a static scene: neighbours all ≈ X → spread ≈ 0 → **still flagged**.

### The trade-off, stated plainly

This makes the check **less sensitive during transitions**: a genuine bleed landing inside a wipe,
fade, or scene change will now be missed. That is accepted because bleed is a DMA/v-blank-overrun
phenomenon that shows on otherwise stable frames, and because the alternative — a standing false
FAIL — is worse: it trains us to ignore the gate, which is how a black `truncstair` shipped for
weeks. The cost is recorded here so a future reader does not mistake it for full coverage.

## Steps

1. Add the quiescence guard to `blank_scan_report` in `dev/jgxcheck.cpp`, with `JGX_BLANKSCAN_WIN`
   and `JGX_BLANKSCAN_QUIET` overrides, and report skipped candidates so a suppression is never
   silent.
2. Add a self-test (`JGX_BLANKSCAN_SELFTEST=1`) over synthetic series, since the real signal costs
   ~15 s/frame of emulation to reproduce:
   - bleed on a quiescent baseline → **flagged**
   - the measured `lsystem` V-apex series → **not flagged**
   - the title's monotonic gravity ramp → **not flagged** (existing behaviour preserved)
3. Rebuild `jgxcheck`; confirm `lsystem` passes and its `SMOKE` value is unchanged.
4. Re-run the full `dev/verify-web-roms.sh` sweep: expect 114/114, no newly-silenced demo.

## Verification

1. Self-test passes all three synthetic cases.

```
$ JGX_BLANKSCAN_SELFTEST=1 build/jgxcheck
SELFTEST: bleed on quiescent baseline
BLANKSCAN: frame 6 has 52 black rows at top (neighbours 40 / 40, window spread 0)
BLANKSCAN: FAIL 1 frame(s) with a transient black band at the top
SELFTEST: bleed on quiescent baseline      expect FLAG     got FLAG     PASS

SELFTEST: lsystem clear/regrow apex
BLANKSCAN: frame 8 spike 149 ignored — window spread 96 >= 8 (picture in transition, not force-blank bleed)
BLANKSCAN: PASS 16 frames, no force-blank bleed (threshold 4 rows, 1 transition spike(s) ignored)
SELFTEST: lsystem clear/regrow apex        expect no-flag  got no-flag  PASS

SELFTEST: title gravity ramp (monotonic)
BLANKSCAN: PASS 13 frames, no force-blank bleed (threshold 4 rows, 0 transition spike(s) ignored)
SELFTEST: title gravity ramp (monotonic)   expect no-flag  got no-flag  PASS

SELFTEST: PASS (3 cases, 0 failed)
exit=0
```

**PASS** — and case 1 is the one that matters: the guard still flags a 12-row excursion on flat
shoulders, so sensitivity to actual bleed is intact rather than traded away.

Re-run unchanged at adoption (2026-07-31):

```
$ JGX_BLANKSCAN_SELFTEST=1 build/jgxcheck
SELFTEST: bleed on quiescent baseline
BLANKSCAN: frame 6 has 52 black rows at top (neighbours 40 / 40, window spread 0)
BLANKSCAN: FAIL 1 frame(s) with a transient black band at the top
SELFTEST: bleed on quiescent baseline      expect FLAG     got FLAG     PASS

SELFTEST: lsystem clear/regrow apex
BLANKSCAN: frame 8 spike 149 ignored — window spread 96 >= 8 (picture in transition, not force-blank bleed)
BLANKSCAN: PASS 16 frames, no force-blank bleed (threshold 4 rows, 1 transition spike(s) ignored)
SELFTEST: lsystem clear/regrow apex        expect no-flag  got no-flag  PASS

SELFTEST: title gravity ramp (monotonic)
BLANKSCAN: PASS 13 frames, no force-blank bleed (threshold 4 rows, 0 transition spike(s) ignored)
SELFTEST: title gravity ramp (monotonic)   expect no-flag  got no-flag  PASS

SELFTEST: PASS (3 cases, 0 failed)
exit=0
```

**PASS** (3/3).

2. `lsystem` BLANKSCAN: PASS, `SMOKE` still `0x8073`.

```
$ JGX_BLANKSCAN=1 build/jgxcheck .../lsystem.sfc vendor/bsnes-jg/Database 0x135d 2 0x8073 1200
BLANKSCAN: frame 1154 spike 149 ignored — window spread 96 >= 8 (picture in transition, not force-blank bleed)
BLANKSCAN: PASS 1200 frames, no force-blank bleed (threshold 4 rows, 1 transition spike(s) ignored)
SMOKE: PASS off=0x135D len=2 got=0x8073 (ran 1200 frames, bsnes-jg)
exit=0
```

**PASS** — the previously failing frame is now attributed and skipped, with the reason printed. The
corpus CRC is untouched, confirming this changed only the scan heuristic, not the ROM or its gate.

Re-run against the **shipped site ROM** at adoption (2026-07-31), reproducing frame 1154 exactly:

```
$ JGX_BLANKSCAN=1 build/jgxcheck ~/biohack.net/public/play/roms/lsystem.sfc \
    vendor/bsnes-jg/Database 0x135d 2 0x8073 1200
BLANKSCAN: frame 1154 spike 149 ignored — window spread 96 >= 8 (picture in transition, not force-blank bleed)
BLANKSCAN: PASS 1200 frames, no force-blank bleed (threshold 4 rows, 1 transition spike(s) ignored)
SMOKE: PASS off=0x135D len=2 got=0x8073 (ran 1200 frames, bsnes-jg)
exit=0
```

**PASS** — `SMOKE` still `0x8073`.

2a. End-to-end through the actual gate script (this is what `verify-web-roms.sh` reports, and it
exercises the verdict-line parsing the new informational "spike … ignored" line broke):

```
$ dev/verify-web-roms.sh --only lsystem
  lsystem          PASS  (1200 frames, want 0x8073)

verify-web-roms: 1 passed, 0 failed, 0 missing
ALL PASS — safe to publish
```

**PASS.**

2b. Independent corroboration that `lsystem` cannot be bleeding force-blank at all — the demo
asserts force blank exactly once, at boot, and never inside the frame loop:

```
$ grep -n "INIDISP\|force_blank\|blank" examples/snes/lsystem.c
91:  display_add(&a->screen, (Drawable *)&a->canvas);                    // reserve BG3 (force-blank)
110:  a.screen.bright = INIDISP_ON; a.screen.btgt = INIDISP_ON;          // full brightness from frame 1
```

**PASS** — there is no `INIDISP` write anywhere in the frame loop, so no mechanism exists for a
per-frame blank at frame 1154. This is a detector defect, not a demo defect; no demo-code change
ships with this fix.

3. Full corpus sweep green, with the skip count reported.

_(pending — being satisfied by the **2026-07-31 republish gate run**: the concurrent republish
agent is executing `dev/verify-web-roms.sh` over the whole batch and will record its sweep summary
here when it lands. Expect 114/114, no newly-silenced demo. Deliberately not run a second time in
parallel — two concurrent full sweeps would contend for the same harness.)_

## Visible surface

The only surface is the gate's terminal output; the literal before/after lines are shown above and
in step 1's output rather than as an HTML mockup bundle.
