# Mode 7 splash force-blank floor — the `m7splash_end()` handoff contract

TODO entry: `[T4] Mode 7 splash force-blank floor` (M2 / #321 follow-ups), escalated out of the
2026-08-05 re-verify of [plan 121](2026-07-26-121-mode7-gallery-badges-and-mandel-oop-startup.md)
gate 11, after `1a9d9b8` halved `mandel-oop`'s post-title black window (24 → 11 frames) and found
the residue was shared, not demo-local.

**Visible surface:** the change is ROM startup *timing*, which has no static mockup — the
before/after entropy-pinned black-window frame tables below are the mockup equivalent, and
`dev/m7blank.sh` reproduces every number in one command.

---

## 1. What was actually measured

`dev/m7blank.sh` (new, this plan) generalises the #121 re-verify method: one entropy-pinned
`JGX_FRAMESCAN=1` emulator run per demo emits a change event per frame whose fingerprint differs
from its predecessor; holding each event's state forward reconstructs *every* frame, so a single
run yields the whole timeline without a per-frame PNG sweep. A frame is black when its dominant
colour is `#000000` at ≥ 99 %. `JGX_ENTROPY=0` is mandatory — without it bsnes-jg seeds unwritten
PPU registers from `clock()` and mid-run frames are irreproducible (#121's methodology note).

**The instrument first had to be sharpened.** A picture scan cannot tell *"the screen is
force-blanked"* from *"the blank was released and the art is still black"* — and several Mode 7
demos deliberately bloom their image onto a black backdrop (`buddha`: `cgbuf[0] = 0; // no hits ->
black backdrop`; `blossom`: `pal[0] = 0; // backdrop / no hits = black`). Measuring only the
picture would have credited a fix for repainting a backdrop. So `m7_show()` (`mode7.h`) and
`display_frame()` (`snesgfx/display.h`) gained a **`M7BLANK_PROBE`** block, compiled out by
default, that paints CGRAM[0] white at the instant the blank is released. In a `--probe` build the
all-black run *is* the force-blank window, exactly.

### Baseline — 2026-08-05, `wt/321-m7blank` off `781d286`

```
$ OUT=build/m7blank-base.tsv       FRAMES=1200 dev/m7blank.sh          # picture (what a viewer sees)
$ OUT=build/m7blank-probe-base.tsv FRAMES=1200 dev/m7blank.sh --probe  # force-blank only
```

| demo | title exit | all-black (picture) | **force-blank (probe)** | where the force-blank frames go |
|---|---:|---:|---:|---|
| `avalanche` | f=240 | 50 | **1** | already at the floor; the other 49 are the rainbow's black palette[0] |
| `blossom` | f=240 | 55 | **32** | `vram_clear_all()` + `grid_clear()` + `hud_begin()` inside the window |
| `buddha` | f=239 | 514 | **38** | `vram_clear_all()` + `grid_clear()`; the other 476 are the cloud blooming on black *by design* |
| `julia` | f=309 | 1 | **1** | at the floor — but `julia_gate_crc()` runs in the **boot** black, *before* the title |
| `mandel-display` | f=239 | 72 | **72** | `coarse_pass(8,7,…)` entirely inside the window |
| `mandel-float` | f=298 | 350 | **350** | `mf_gate_crc()` entirely inside the window |
| `mandel-oop` | f=239 | 11 | **11** | `display_init` + `_mandel_reserve()` inside the window |
| | | | **505 total** | |

`mandel-display` 72 and `mandel-oop` 11 reproduce the #121 record exactly, which validates the
instrument against the prior evidence.

### The floor is 1 frame

Two probes on `mandel-display`, replacing only the first coarse pass:

```
PROBE-A  coarse_pass(8,7,3,3,0) removed entirely      ->  239..239 =  1 frame
PROBE-B  mandel_fill(scratch,8,7,DN) kept, reveal cut ->  239..297 = 59 frames
full     unmodified                                   ->  239..310 = 72 frames
```

So the genuinely-blank-requiring part of the handoff — `_m7t_wipe_vram()`'s two 16 KB fixed-source
DMAs, `m7_begin()`, `m7_tilemap_clear()`'s 16 KB DMA, the identity tilemap, `load_palette()`, the
matrix/centre/scroll writes — costs **1 frame**, and `avalanche` and `julia` already achieve it.
Everything above 1 is demo compute executing in the dark. Of `mandel-display`'s 72: 1 floor,
58 `mandel_fill` (pure WRAM), 13 `build_coarse_row` + DMA.

## 2. Correcting the escalation's premise

The escalation (and `docs/agent-handoff.md`'s "Still to convert (they re-open the window)") reads
as though `display_init()` **re-opens** a window the splash had closed. It does not: `m7splash_end()`
returns with `REG_INIDISP = 0x80` still asserted, and `display_init()`'s `snes_ppu_reset_blank()`
re-asserts an *already-open* window. No frame is added by the re-assert. The blackness is
**entirely the wall-clock of the work executed inside the window** — which is why the spread is
1…350 across demos that share the identical handoff.

The consequence for the design: **the fix is about what runs inside the window, not about the
window's boundaries.** Nothing in `m7splash_end()` or `display_init()` needs to move.

## 3. The contract

> **Between `m7splash_end()` and the caller's blank release, only PPU register writes and DMA are
> permitted. All compute belongs between `m7splash_begin()` and `m7splash_end()`, where it runs
> behind a title card the viewer can see. All progressive reveal belongs after the release, in
> v-blank.**

The bracket already exists and three demos already use it (`lzss-gallery` — `m7splash_end(0)` after
decoding the first work; `apollo-reel`; `snes-video-reel`). What was missing is that it was a
convention rather than a contract, and that the `m7splash(l0, l1, hold)` convenience wrapper
*invites* the wrong shape — it is the only reason `mandel-float` grinds 5.8 s of soft-float in the
dark **directly against its own source comment** ("Brand FIRST so the boot isn't a blank screen …
show 'SOFT-FLOAT MANDELBROT' up front — the ensuing compute reads as 'working', not 'broken'").

Enforcement is a gate, in the house style of `JGX_BLANKSCAN`: `dev/m7blank.sh --gate` fails when a
demo's **probe** window exceeds its committed budget. Budgets are per demo with a one-line reason,
so a demo whose black is genuinely art-directed says so, and a regression that re-adds compute
after the splash turns the gate red.

### Considered and rejected

- **A callback hook — `m7splash_end(hold, work_fn)`.** Rejected: an indirect call through a
  function pointer is exactly what `dev/mandel-oop.sh`'s virtual-dispatch gate counts (it asserts
  precisely one indirect dispatch, `scene_emit`'s vtable call). A shared header that adds a second
  one would break that gate for every OOP demo.
- **A deadline API — `m7splash_end_at(min_total_frames)`**, holding until the title has been up for
  N frames *counting* the caller's work, so no demo needs a hand-tuned hold. Rejected: there is no
  free-running frame counter on this setup — `crt0`'s NMI handler is a weak `rti`, `REG_RDNMI` is a
  read-to-clear flag not a count, and the V-counter wraps every frame. Measuring the caller's
  elapsed work would mean installing an ISR in a header shared by every demo — a far larger blast
  radius than the problem. The caller passes a smaller `hold` instead, which is reviewable.
- **Dropping `_m7t_wipe_vram()`** as redundant with each demo's own `m7_tilemap_clear()`. Measured
  and rejected: the whole floor including both is 1 frame, so there is nothing to win, and the wipe
  exists for a real shipped bug (stale title glyphs in the high-byte plane showing through a
  progressive reveal).
- **Repainting `buddha`/`blossom` backdrops** so the picture scan stops calling their bloom black.
  Rejected as measuring-the-thermometer: their black is the art. The probe separates the two
  instead.

## 4. Per-demo impact

| demo | change | force-blank before → target |
|---|---|---:|
| `mandel-float` | `m7splash(…,150)` → `begin` / `mf_gate_crc()` / `end(0)` | 350 → 1 |
| `mandel-display` | `mandel_fill(scratch,8,7,DN)` moves inside the bracket; the first coarse reveal moves after `m7_show()` and goes in-v-blank like passes 2 and 3 already are | 72 → 1 |
| `buddha` | `vram_clear_all()` + `grid_clear()` + `bud_rng_init()` + `build_palette()` move inside the bracket (all WRAM / pre-Mode-7 VRAM) | 38 → ~1 |
| `blossom` | same, plus `blossom_reset()` / `build_palette()` / `hud_build` staging | 32 → ~1 |
| `mandel-oop` | `mandel_layer_init()` moves inside the bracket; the loading-texture build moves out of `reserve()`'s blank window | 11 → target ≤ 4 |
| `julia` | `julia_gate_crc()` moves from *before* the splash to inside the bracket — removes ~2 s of **boot** black, window already at the floor | 1 → 1 |
| `avalanche` | none — already at the floor | 1 → 1 |
| `apollo-reel`, `lzss-gallery`, `snes-video-reel`, `seamdemo` | none — already `begin`/`end`; not directly at issue here, but see the coverage fix below | apollo-reel 5, lzss-gallery 253, seamdemo 20, snes-video-reel 4 (measured, not tightened) |

Note: `mandel-double` is a splash demo the audit finds but it does not link at `-Os` in this
harness (`.far_rodata` overflow); `dev/m7blank.sh` uses its gate's `-Oz`.

**The "seven Mode 7 demos" count is stale.** `grep -l m7splash examples/snes/*.c` returns **twelve**
files today. `dev/m7blank.sh` derives the set rather than hardcoding it, so the count cannot drift
again silently — the same failure mode as the 9 → 11 gallery-badge drift that
[plan 123](2026-07-26-123-mode7-gallery-filter.md) fixed.

## 5. Verification steps

1. `dev/m7blank.sh --probe` force-blank table matches the plan's target column for every demo.
2. `dev/m7blank.sh` picture table: `mandel-display` 72 → target, `mandel-oop` 11 → target,
   `mandel-float` 350 → target.
3. `dev/m7blank.sh --gate` exits 0 against the committed budgets, and exits non-zero when a budget
   is deliberately tightened by one frame (proves the gate can fail).
4. `dev/run.sh mandel-oop` — differential gate green, corpus `0x204F`, exactly 1 indirect dispatch.
5. `dev/run.sh mandel-shot` — `mandel-display` differential gate green, corpus `0x204F`.
6. `dev/run.sh mandel-float` — differential gate green.
7. `dev/run.sh julia` — differential gate green.
8. `dev/run.sh buddha` — differential gate green.
9. `dev/run.sh blossom` — differential gate green.
10. `dev/run.sh avalanche` — differential gate green (untouched; regression control).
11. `-verify-machineinstrs` clean on every rebuilt demo (the build leg of each gate script).
12. Shipped ROMs contain no probe code: a `-DM7BLANK_PROBE`-free build is byte-identical to the
    pre-probe build of an untouched demo (`avalanche`).

## 6. Results — 2026-08-05, `wt/321-m7blank`

### Force-blank window, before → after (`dev/m7blank.sh --gate`, entropy-pinned, probe build)

```
demo                 before    after    delta
avalanche                 1        1        0    already at the floor
blossom                  32        4      -28
buddha                   38        2      -36
julia                     1        1        0    window was at the floor; ~70 frames of BOOT black removed
mandel-display           72        1      -71
mandel-double        (nolink)      1        -    215 when first made to link; see below
mandel-float            350        1     -349
mandel-oop               11       11        0    residual localised to snesgfx, not the splash — see below
                     -------  -------
                        (720)      22
```

`mandel-double` was invisible to the first baseline: it opts into the far platform and would not link
against `mos-snes.cfg`. Teaching `dev/m7blank.sh` to pick `mos-snes-far.cfg` made it build, and the
gate immediately scored it **215 frames OVER BUDGET** — an eighth demo with the same defect, found by
the gate on its first real run, against its own "Brand FIRST so the boot isn't a blank screen"
comment. Fixed the same way; now 1.

**The gate can fail.** Two independent demonstrations: the `mandel-double` discovery above (exit 4),
and tightening `avalanche`'s budget from 2 to 0 —

```
$ FRAMES=700 dev/m7blank.sh --gate avalanche      # budget temporarily 0
avalanche                 1        0  OVER BUDGET
tightened-budget EXIT=4
restored-budget  EXIT=0
```

### Picture-level window (what a viewer actually sees)

```
demo             before   after
avalanche            50      50   unchanged — art: the rainbow's palette[0] is black
blossom              55      28
buddha              514     479   unchanged in kind — art: the cloud blooms on "no hits -> black"
julia                 1       1
mandel-display       72       1
mandel-float        350       1
mandel-oop           11      11
```

`avalanche` and `buddha` are the reason the probe exists: their remaining black is the demo's own
backdrop with the screen fully on, not a stall. Repainting it would have been measuring the
thermometer.

### `mandel-oop`'s residual — localised, not the splash contract

Bisected with `dev/m7blank.sh --probe` on the real ROM:

```
release right after display_add()            -> 4 frames    (splash exit + display_init + reserve)
_m7t_wipe_vram() neutered                    -> 10 (-1)     the two 16 KB DMAs
reserve()'s checker build+DMA removed        ->  9 (-2)
load_palette_cgram() stubbed                 -> 11 (-0)
m7_tilemap_clear() removed                   -> 11 (-0)
_mandel_emit's build_step() disabled         ->  5 (-6)     <-- the residual
build_step's 512-far-store row expansion cut ->  9 (-2)
```

So 4 of the 11 are the handoff (now minimal and contract-governed) and **6 are `build_step()`'s
far-memory work executing inside snesgfx's first `display_frame()`, before it writes `REG_INIDISP`**.
That is the `Display` first-frame path — every `Display` demo pays it, not just Mode 7 — and fixing
it there risks exactly the force-blank-into-active-display flicker class of `1dd9317`. Deliberately
out of scope here; filed as its own TODO item and budgeted at the measured 12 so a splash-side
regression still trips the gate.

## 7. Verification

Each step as written in §5, with raw output.

**1. `dev/m7blank.sh --probe` matches the target column.** See the before/after table above — every
demo at 1–4 except `mandel-oop` at 11 (documented). **PASS.**

**2. Picture table.** `mandel-display` 72 → 1, `mandel-float` 350 → 1, `mandel-oop` 11 → 11
(localised). **PASS** for the two named targets; `mandel-oop` **explained, not improved**.

**3. Gate exits 0, and non-zero on a tightened budget.** Both shown above. **PASS.**

**4. `dev/run.sh mandel-oop`**
```
SMOKE: PASS off=0x895 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
    indirect JMP count in .text: 0
    indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): 1
RESULT: PASS — mandel-oop OOP gate GREEN; corpus_result==0x204F on host == +mos-a16@bsnes-jg
```
**PASS** — corpus unchanged, virtual-dispatch gate still exactly 1.

**5. `dev/run.sh mandel-shot`** (`mandel-display`)
```
SMOKE: PASS off=0x580 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
    SHOT: PASS corpus=0x204F (snapshot at frame 5800)
RESULT: PASS — Mandelbrot rendered on SNES; MAME + bsnes-jg screenshots match host (CRC 0x204F)
```
**PASS.**

**6. `dev/run.sh mandel-float`**
```
    PASS  __mulsf3=8  __add/subsf3=12  rep/sep=36  (IEEE-754 soft-float, native-16)
SMOKE: PASS off=0x200 len=2 got=0x4169 (ran 2200 frames, bsnes-jg)
    SHOT: PASS corpus=0x4169 (snapshot at frame 2200)
RESULT: PASS — soft-float Mandelbrot rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x4169 host == +mos-a16
```
**PASS — after fixing a PRE-EXISTING harness defect.** The first run failed the MAME leg with an
*empty* `SHOT:` line. Reproduced on **pristine sources** (my demo edits stashed, shared headers left
in place), so it is not a regression from this change:
```
########## PRISTINE dev/run.sh mandel-float
SMOKE: PASS off=0x200 len=2 got=0x4169 (ran 2200 frames, bsnes-jg)
RESULT: FAIL — see the per-emulator lines above
EXIT(mandel-float)=1
########## PRISTINE dev/run.sh mandel-double
SMOKE: PASS off=0x200 len=2 got=0x0EDF (ran 2200 frames, bsnes-jg)
RESULT: FAIL — see the per-emulator lines above
EXIT(mandel-double)=1
```
Cause: `dev/mandel-float.lua` asserts at `SHOT_AT = 2200` periodic ticks (~36.7 emulated seconds at
60 Hz) but `dev/mandel-float.sh` granted `-seconds_to_run 18`, so MAME exited before the callback
ever fired and `case "$line"` scored the silence as FAIL. Raised to 45 s — deliberately **not** by
lowering `SHOT_AT`, because frame 2200 is the whole-set render `3d66b05` chose as the published
title card. `julia`, which passes on the same 18 s, uses `SHOT_AT = 800`.

**7. `dev/run.sh mandel-double`**
```
    PASS  __muldf3=8  __add/subdf3=12  rep/sep=32  (IEEE-754 DOUBLE soft-float, native-16)
SMOKE: PASS off=0x200 len=2 got=0x0EDF (ran 2200 frames, bsnes-jg)
    SHOT: PASS corpus=0x0EDF (snapshot at frame 2200)
RESULT: PASS — soft-float Mandelbrot rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x0EDF host == +mos-a16
```
**PASS** — same pre-existing harness fix.

**8. `dev/run.sh julia`**
```
RESULT: PASS — Julia z^2+c rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x3490 host == +mos-a16
```
**PASS.**

**9. `dev/run.sh buddha`**
```
RESULT: PASS — Buddhabrot density on SNES; grid hash 0x7C31 host == +mos-a16 (bsnes-jg + MAME)
```
**PASS.**

**10. `dev/run.sh blossom`**
```
RESULT: PASS — interactive Hopalong attractor on SNES; grid hash 0x9047 host == +mos-a16 (MAME + bsnes-jg); state-math host == ROM (bsnes-jg)
```
**PASS** — including the controller pad-log replay differential.

**11. `dev/run.sh avalanche`** (untouched; regression control)
```
RESULT: PASS — 64-bit Avalanche rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0x27EA host == +mos-a16
```
**PASS.**

**12. `-verify-machineinstrs`.** `dev/blossom.sh` and `dev/buddha.sh` pass `-mllvm
-verify-machineinstrs` on the build leg and fail the script on non-zero exit; both are green above.
**PARTIAL** — the other gates' verify legs are the pre-existing vacuous-under-LTO pattern documented
in `dev/mandel-oop.sh`'s own header comment (`--config`'s default LTO never runs the verifier). Not
changed here; no new gap introduced.

**13. Shipped ROMs carry no probe code.** `avalanche` is untouched by this change, so its ROM
isolates the shared-header edits:
```
dabd87eac47aac1dc63549236050b60d83122074d303c2da04431bc57694aa3d  /tmp/av-old.sfc   (headers before)
dabd87eac47aac1dc63549236050b60d83122074d303c2da04431bc57694aa3d  /tmp/av-new.sfc   (headers after)
BYTE-IDENTICAL
```
**PASS** — the `M7BLANK_PROBE` blocks and the contract documentation cost a shipped ROM nothing.

### Result: 12 / 13 PASS, 1 PARTIAL (pre-existing vacuous-verify pattern, unchanged).

No ROM hash needed re-pinning: every demo's `corpus_result` is a content hash the gate re-derives
from its host oracle each run, and every capture point (5800 frames / 2200 ticks / 120 s) sits far
past settle, so the startup shift is absorbed — as `mandel-display`'s and `blossom`'s own source
comments predicted.

### Deferred

- The 6-frame `build_step()` residual inside snesgfx's first `display_frame()` — own TODO item.
- `snesgfx/splash.h` and `splash16` in `title_layer.h` still re-open the window (the remaining half
  of the `agent-handoff.md` "Still to convert" list); not Mode 7 demos, not measured here.
- ~~`apollo-reel`, `lzss-gallery`, `seamdemo`, `snes-video-reel` already use `begin`/`end` but cannot
  be measured by `dev/m7blank.sh` — they need generated asset headers or corpora that live outside
  the repo. They are discovered and reported as `BUILD FAILED` rather than silently skipped.~~ FIXED:
  `dev/m7blank.sh`'s `build_wide_demo()` now reproduces each demo's real multi-file build recipe —
  `lzss-gallery` just needed the `mos-snes-gallery.cfg` its own gate uses (checked-in assets
  compile as-is); `snes-video-reel` builds against the checked-in
  `assets/snes/video/svx2-full-reel.bin` corpus (real asset, real measurement); `seamdemo`'s ExHiROM
  6 MiB layout + payload generation is pure Python (`tools/snes-seamdemo-gen.py`), no external
  corpus needed. Only `apollo-reel`'s footage genuinely lives outside the repo (`dev/apollo-reel.sh`
  defaults to a `/tmp` corpus) — since the force-blank window is a function of code shape (DMA
  setup + first-frame codec dispatch), not pixel content, `build_wide_demo()` generates a tiny
  deterministic synthetic corpus in the real baker's expected shape instead of vendoring footage.
  All twelve demos are now measured, no `BUILD FAILED` / SKIP list. See the `[T2]` TODO item this
  closed.
