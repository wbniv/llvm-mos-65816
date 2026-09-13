# Per-drawable "first frame is complete" opt-in for snesgfx `Display`

TODO entry: `[wip T3] Per-drawable "first frame is complete" opt-in for snesgfx Display.` (M2 / #321).

Direct successor to [`2026‑08‑05-display-first-frame-forceblank.md`](2026-08-05-display-first-frame-forceblank.md),
which built and **rejected** the blanket form of this change (Option F: make the first
`display_frame()` release‑only for every demo) and closed with the recommendation this plan
implements:

> the shape that would work is a per-drawable opt-in — a `Drawable` flag a `reserve()` sets to
> assert "I painted everything my first frame shows", with `display_frame` taking the early release
> only when every drawable in the scene asserts it. Safe by default, no demo regresses.

**Visible surface:** ROM startup timing only — there is no UI, page, or pane to mock up. The
before/after frame tables and the `--firstframe` determinism result in §5 are the whole visible
surface, and `dev/bootblank.sh` reproduces both in one command.

---

## 1. Context — what the blanket version proved

`display_frame()` releases the boot force-blank as its **last** statement, behind `scene_emit()`.
On the first call that sequences the release behind an arbitrary amount of application compute,
even though `display_add()`'s own contract already had `reserve()` paint that frame's content
inside the boot window.

Making that unconditional regressed five demos. The mechanism is not incidental: **snesgfx routes
CGRAM through the `UploadQueue`**, and the queue is driven by `emit()`, so the
`if (!pal_sent) upq_push_cgram(...)` idiom puts the palette on the *first emit*. 119 of the 122
`Display` demos call `upq_push_cgram`. A release-only first frame renders those with power-on
CGRAM — random at bsnes-jg's default entropy, i.e. a visible one-frame garbage flash.

Moving those palettes out of the queue is a change to the `reserve()`/`emit()` split snesgfx
deliberately chose, across 119 demos. That is the **escalation boundary** and this work does not
cross it. Instead the optimisation becomes opt-in, twice over — per drawable and per demo — and
defaults off in both.

## 2. Design

### 2a. `SNESGFX_FIRST_FRAME_OPTIN` — the compile-time gate, and why it is mandatory

The first cut of this change was **runtime-only**: the field, the AND and the guard compiled into
every `Display` demo unconditionally, with correctness carried entirely by the per-drawable flag.
It was behaviourally invisible — 117/117 demos identical in boot-window length and in first-frame
determinism — and it was still the wrong shape. Totalled from the two trees' link maps across the
121 demos that produce one:

```
net .text:  +4,823 bytes
median:     +39 per demo
117 of 121 grow; only 4 shrink
  (mandel-oop -44 from the deleted latch, modexp256 -35, cordic -34, hdr-bloom -4)
largest:    montorbit +118, life +97, qsortviz +84
```

Against that, the gate fired on **one** demo — `mandel-oop`, which already had its five frames from
a demo-local latch. The runtime-only shape therefore charged ~40 bytes to ~117 demos to buy nothing
yet, which is exactly the pattern `CLAUDE.md` lesson 3 forbids: *a blanket change that regresses
common shapes to win a sub-case is wrong; gate it.* Lesson 3's other half — that a few bytes matter
here because the toolchain multiplies them across every program built — cuts both ways: it is
precisely why spending them for nothing is not a rounding error.

So the feature is **opt-in at compile time as well as per drawable**. A demo that wants it defines

```c
#define SNESGFX_FIRST_FRAME_OPTIN 1   /* BEFORE any snesgfx header */
```

and `drawable.h` defaults it to 0 for everyone else. Every line the feature adds — the `Drawable`
field and its clearing in `drawable_reserve`, `Display.ff_all` and its initialisation, the AND in
`display_add`, the guard in `display_frame`, and `title_layer.h`'s backdrop write — sits inside
`#if SNESGFX_FIRST_FRAME_OPTIN`, so a non-adopting demo preprocesses to the code it compiled before
the feature existed. That is **checked with `cmp` on the emitted ROM**, not asserted: §5 step 2.

Two consequences worth stating:

- **A false assertion is a compile error, not a silent no-op.** A `reserve()` that assigns
  `first_frame_complete` in a translation unit that did not define the macro fails to build,
  because the field is not there. That is the right failure — the claim is meaningless without the
  machinery that reads it, and a silently ignored assertion would be worse than a diagnostic.
- **The four-token order the quality checker enforces survives both configurations.** The guard is
  an `#if`-wrapped `if (...)` sitting *above* a single unconditional
  `scene_emit(&d->scene, &d->q);`, so all four tokens appear once each and in order in the raw file
  — which is what `dev/snes-display-quality.py` scans — and with the macro off the preprocessor
  leaves the bare call exactly as it always was.

### 2b. `drawable.h` — the flag and its default

```c
struct Drawable {
  const DrawableVT *vt;
  uint8_t tm_bits;
#if SNESGFX_FIRST_FRAME_OPTIN
  uint8_t first_frame_complete;
#endif
};

static inline void drawable_reserve(Drawable *d, VramAlloc *va) {
#if SNESGFX_FIRST_FRAME_OPTIN
  d->first_frame_complete = 0;    /* opt-in is OFF unless this reserve() asserts it */
#endif
  d->vt->reserve(d, va);
}
```

Setting it to 1 asserts: *everything my first visible frame shows, I painted myself inside the boot
force-blank — tilemap, chr, AND the CGRAM entries those tiles index (CGRAM[0], the backdrop,
included wherever my area can show it); nothing my first visible frame depends on arrives through
the UploadQueue.*

**Default 0 is guaranteed by construction, not by convention.** Demo drawables are built by ad-hoc
`*_init` functions that assign `base.vt` and `base.tm_bits` field-by-field — they do not zero the
struct, and there is no single constructor to police. Clearing the flag in `drawable_reserve()`
immediately before dispatch makes the default independent of storage class and initialiser style
(static, automatic, designated initialiser, `memset`, ad-hoc): no drawable can opt in by accident,
only by an explicit store in its own `reserve()`.

### 2c. `display.h` — where the AND is computed, and why

`Display` gains `uint8_t ff_all`, initialised to **1** (the AND identity) in `display_init()` and
narrowed in `display_add()`, right after `drawable_reserve()` has run:

```c
d->ff_all = (uint8_t)(d->ff_all & layer->first_frame_complete);
```

`display_add` rather than `display_frame`, deliberately: `display_add` runs **once per drawable for
the life of the program**, `display_frame` runs **every frame**. Re-walking the `Scene` each frame
to recompute an answer that cannot change would put a loop in the per-frame path to serve a
one-shot decision. The AND is monotonic (0 absorbs), so a later `display_add` can only ever *revoke*
the early release, never grant it — the safe direction — and in particular a `late_add` (one that
by definition arrives after the blank is already released) cannot retroactively enable anything.

### 2d. The gate — a guard, never a reorder

```c
static inline void display_frame(Display *d) {
#if SNESGFX_FIRST_FRAME_OPTIN
  if (d->shown || !d->ff_all)
#endif
  scene_emit(&d->scene, &d->q);
  (void)REG_RDNMI;
  snes_wait_vblank();
  upq_flush(&d->q);
  ...
  REG_INIDISP = (uint8_t)(d->bright & 0x0Fu);
  d->shown = 1;
}
```

`dev/snes-display-quality.py` (also the **SNESDQ** commit hook) enforces the token order
emit → wait-v-blank → flush → masked brightness write. That invariant *is* the encoded `1dd9317`
lesson: `display_frame` used to assert force-blank around the DMA, and when the flush outran
v-blank the release landed in active display and blanked the top scanlines. Wrapping the emit in an
`if` leaves all four tokens present and in order. Hoisting the release above the emit would not, and
rewriting the guard that protects the exact regression class this change must not regress is the
wrong move.

The gate adds **no** `REG_INIDISP` write and removes none — still exactly one, same place, same
`& 0x0Fu` mask that makes the force-blank bit unrepresentable — and on the skipped frame it
*reduces* the work before the release (the queue flushed is empty: the least possible DMA, so it
cannot overrun the window).

> **Comment-text gotcha, found the hard way.** `snes-display-quality.py` matches the four tokens
> with `display.find(token)` over the **raw file**, comments included. A comment that quotes
> `snes_wait_vblank();` or `REG_INIDISP = (uint8_t)(d->bright & 0x0Fu);` *above* `display_frame`
> puts those tokens out of order and fails the gate. The comment blocks therefore describe the
> order in prose instead of quoting the calls.

### 2e. Which drawables adopt it

Qualification was read out of the code, not guessed: a drawable qualifies only if its `reserve()`
writes **the layer registers, the whole tilemap it can show, the chr those entries index, and the
CGRAM entries those tiles index**. A survey of all 21 `DrawableVT`s found only five `reserve()`s
that touch CGRAM at all, and two of those turned out not to qualify:

| Drawable | `reserve()` writes CGRAM? | whole tilemap? | verdict |
|---|---|---|---|
| `MandelLayer` (`mandel-oop.c`) | yes — `load_palette_cgram()` | Mode 7 map cleared + identity, chr rows DMA'd | **adopts** |
| `CaDisplay` (`1d-ca.c`) | yes — CGRAM 0..3 incl. backdrop | full 32×32 identity map, all 1024 chr tiles zeroed | **adopts** |
| `LifeGrid` (`life.c`) | yes — CGRAM 0..3 incl. backdrop | full 32×32 map, chr zeroed | **adopts** |
| `TitleLayer` (`snesgfx/title_layer.h`) | palette 7 entries 0..2 — **plus CGRAM[0] under the macro** | yes | **adopts (macro-gated)** |
| `BfHud` (`bf-vm.c`) | **no** (the word only appears in a comment) | yes | no — blank tile indexes power-on CGRAM[0] |
| `TextGrid` (`cpu6502.c`) | yes, CGRAM 0..15 | **no** — the tilemap arrives from `_tg_emit`'s DMA | no |
| everything else (`BitmapCanvas`, `TextLayer`, `SpriteSet`, 14 demo-local) | no | — | no |

**`TitleLayer` needed two lines to qualify, and gets them under the macro.** `_title_reserve` is
otherwise complete — full chr, full tilemap, both text lines, HDMA buffers armed — but the CGRAM it
writes is palette 7 entries 0..2 (`TITLE_PAL == 7`), while its `emit()` writes
`upq_push_cgram(q, 0u, &t->back, ...)`: **CGRAM[0], the global backdrop**, which its own blank
tilemap shows everywhere. Writing CGRAM[0] black in `reserve()` makes the claim true; it matches the
value `title_begin()` starts `t->back` at, so the picture is unchanged and only its determinism
improves. Because it sits under `#if SNESGFX_FIRST_FRAME_OPTIN`, the ~120 demos that include
`title_layer.h` without opting in are byte-for-byte untouched — which is the whole reason this
could be bundled here rather than deferred.

That in turn is what lets `1d-ca` and `life` fire the gate at all: their scenes are
`{demo drawable, TitleLayer}`, so both halves of the AND had to assert.

`mandel-oop` also **loses its demo-local workaround.** `_mandel_emit` carried an Option J
`first_emit_done` latch that skipped the first `build_step()`. With the shared gate that latch is
not merely redundant, it is *wrong*: the gate skips the first `emit()` entirely, so the latch would
not be consumed until frame 2 and would swallow frame 2's compute as well — costing back the frame
the gate just won. It is removed, and its comment block replaced by a pointer to the shared
mechanism that superseded it.

### 2f. What the macro costs the adopters

Only the three adopting demos pay anything, and the numbers are in §5 step 2: `mandel-oop`
**−44 bytes** (the deleted latch more than pays for the gate), `1d-ca` **+71**, `life` **+97**.
Everyone else is byte-identical. `life` buys one frame with its 97 bytes; `1d-ca` buys zero frames
(its first `_cad_emit` is a queued scroll write and two already-clear dirty flags, well under a
frame) and buys the invariant only — recorded plainly here so the coordinator can drop `1d-ca` if
the invariant is not judged worth 71 bytes in that one demo.

## 3. Files

- `examples/snes/snesgfx/drawable.h` — the `SNESGFX_FIRST_FRAME_OPTIN` default, the
  `first_frame_complete` field, the contract comment, `drawable_reserve()` clearing it before
  dispatch. All macro-gated.
- `examples/snes/snesgfx/display.h` — `ff_all` field, init to 1, AND in `display_add`, the
  `if (d->shown || !d->ff_all)` guard in `display_frame`, header + `display_frame` comments. All
  macro-gated.
- `examples/snes/snesgfx/title_layer.h` — macro-gated CGRAM[0] backdrop write + assertion in
  `_title_reserve`.
- `examples/snes/mandel-oop.c` — define the macro; assert in `_mandel_reserve`; remove the Option J
  `first_emit_done` latch from `_mandel_emit` and the struct.
- `examples/snes/1d-ca.c`, `examples/snes/life.c` — define the macro; assert in `_cad_reserve` /
  `_life_reserve`.
- `dev/snes-display-quality-baseline.json` — one new reviewed direct-PPU site (the backdrop write).
- `docs/plans/2026-09-14-display-first-frame-optin.md` (this file), `docs/agent-handoff.md`,
  `TODO.md`.

## 4. Verification steps

Run from the worktree `/home/will/llvm-mos-65816-dispoptin` (branch `wt/display-first-frame-optin`),
with a second detached worktree `/home/will/llvm-mos-65816-dispoptin-base` at the same `main` tip
`22f18cb` supplying the "before" half. Both share `main`'s prebuilt toolchain by hardlink per
[`howto-feature-worktree.md`](../howto-feature-worktree.md), so before and after use the same
compiler, the same harness and the same commit, and the two sweeps run concurrently.

1. `python3 dev/snes-display-quality.py` (and `task snes-display-quality`) — the `display_frame`
   order invariant and the upload budgets still hold in both macro configurations; any new
   direct-PPU site is reviewed and registered, with the baseline diff shown by id, not by line.
2. **ROM byte identity.** Build every `Display` demo in both trees and `cmp` the `.sfc` files (not
   just sizes): every demo that does not define `SNESGFX_FIRST_FRAME_OPTIN` must be byte-identical.
   List the adopters' `.text` deltas.
3. `dev/bootblank.sh --firstframe` over all `Display` demos, before and after: **zero new**
   nondeterministic demos, adopters deterministic.
4. `dev/bootblank.sh` boot force-blank frame counts before and after (unchanged for every
   non-adopter; adopters' gains), plus `dev/m7blank.sh --probe mandel-oop` — which must stay
   `239..243 = 5` **with the Option J latch deleted** — and `dev/m7blank.sh --gate` for the whole
   splash set.
5. `dev/run.sh mandel-oop`, `dev/run.sh life`, `dev/run.sh 1d-ca` — each adopter through its own
   differential gate.

## 5. Verification run — 2026-09-14, `wt/display-first-frame-optin`

**1. `python3 dev/snes-display-quality.py` / `task snes-display-quality`.**
```
$ python3 dev/snes-display-quality.py
SNESDQ: PASS (241 reviewed sensitive access sites; display order and upload budgets valid)

$ task snes-display-quality
task: [snes-display-quality] dev/snes-display-quality.py
SNESDQ: PASS (241 reviewed sensitive access sites; display order and upload budgets valid)
```
The backdrop write is a genuinely new direct-PPU site and the checker caught it
(`FAIL - examples/snes/snesgfx/title_layer.h:315: new ppu-write`). Registered with
`--update-baseline`, then the baseline diffed **by finding id** rather than by line, because the
`line` field of every site below an inserted line churns cosmetically:
```
counts: 223 -> 224
ADDED:
   examples/snes/snesgfx/title_layer.h 315 | REG_CGDATA = 0x00; REG_CGDATA = 0x00;
REMOVED:
```
**PASS** — exactly one new reviewed site, nothing dropped, order invariant intact. (An earlier
attempt also FAILED on the order check because the new comment block quoted the literal tokens
above the code; comment reworded to prose — see 2d.)

**2. ROM byte identity — the result the rework was for.**
```
buildable demos: 117   pre-existing non-linkers: ['bankwalk','farptrcmp','farspill','invaders','seamdemo']
BYTE-IDENTICAL (cmp of the .sfc): 114
CHANGED: 3 ['1d-ca', 'life', 'mandel-oop']
```
Extending the comparison to the 121 demos that emit a link map — the four extra ones write a map
and then fail to link, before and after alike — using the path-normalised map as the artifact:
```
common demos with a link map: 121
IDENTICAL (path-normalised link map): 118
CHANGED: 3 ['1d-ca', 'life', 'mandel-oop']
```
**PASS — 118/118 non-adopters identical, and the only three that move are the three that define
the macro.** Adopter `.text`:
```
mandel-oop   .text  6419 ->  6375  (-44)
1d-ca        .text  8332 ->  8403  (+71)
life         .text  9210 ->  9307  (+97)
```
Net across the whole tree is **+124 bytes in three demos**, against the runtime-only cut's
**+4,823 across 117**.

**3. `dev/bootblank.sh --firstframe`, all 117 measurable Display demos, before and after.**
```
FF BEFORE nondet: ['mandel-oop', 'multibase', 'mvscrl', 'qsortviz']
FF AFTER  nondet: ['multibase']
NEW: []   FIXED: ['mandel-oop', 'mvscrl', 'qsortviz']
```
**PASS on the claim that matters — zero new nondeterministic demos.**

The three that flipped to `ok` are **not** presented as fixes. `mvscrl` and `qsortviz` have
**byte-identical ROMs** (step 2), so nothing about them changed and their flip can only be the
instrument: `--firstframe` compares two random draws, so a stochastic demo coincides some fraction
of the time. That is the caveat the 2026‑08‑05 plan already recorded ("sound for non-splash demos,
stochastic for splash demos; a stricter version would use more than two runs"), now demonstrated on
two demos whose ROMs provably did not move. `mandel-oop`'s flip is plausibly real — its first frame
genuinely is the release-only one now — but it sits in the same run as two known-spurious flips, so
it is reported as indistinguishable from instrument noise rather than claimed.

**4. Boot force-blank frame counts.**
```
$ dev/bootblank.sh        # 117 demos, FRAMES=300, before vs after
demo                 before    after    delta
(0 of 117 changed)
total boot force-blank frames: 2598 -> 2598
```
`life`'s window is longer than the default scan, so it reads 300 (capped) on both sides there.
Re-measured wide enough to see it, alongside the other title-scene adopter:
```
$ FRAMES=500 dev/bootblank.sh 1d-ca life
--- baseline tree ---                --- feature tree ---
1d-ca                    12          1d-ca                    12
life                    362          life                    361
```
`mandel-oop` is absent from the delta by construction — its black window is the **post-title** one,
which `dev/bootblank.sh` does not measure (2026‑08‑05 plan §2):
```
### BEFORE (baseline tree)            ### AFTER (feature tree)
demo          first  last  frames     demo          first  last  frames
mandel-oop      239   243       5     mandel-oop      239   243       5
```
```
$ dev/m7blank.sh --gate          # feature tree, whole splash set
demo               measured   budget  verdict
apollo-reel               5        6  ok
avalanche                 1        2  ok
blossom                   4        5  ok
buddha                    2        3  ok
julia                     1        2  ok
lzss-gallery            153      254  ok
mandel-display            1        2  ok
mandel-double             1        2  ok
mandel-float              1        2  ok
mandel-oop                5        6  ok
seamdemo                 20       21  ok
snes-video-reel           4        5  ok

PASS: every demo is within its post-title force-blank budget.
GATE EXIT=0
```
**PASS, and the `mandel-oop` row is the load-bearing result of the whole change.** It holds 5 frames
*while its demo-local Option J latch is deleted*. The latch was the only thing keeping it at 5; had
the shared gate not fired, removing it would have put the demo straight back to 11. 5 → 5 with the
latch gone is positive proof the scene-wide AND resolved to 1 and the first `scene_emit()` was
skipped. `life`'s 362 → 361 is the same proof for a two-drawable scene that needed `TitleLayer` to
assert. `1d-ca` fires too — same code path, same AND — but gains 0 frames (2f).

**5. Per-adopter differential gates.**
```
$ dev/run.sh mandel-oop
SMOKE: PASS off=0x897 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
    SHOT: PASS corpus=0x204F (snapshot at frame 5800)
    indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): 1
RESULT: PASS — mandel-oop OOP gate GREEN; corpus_result==0x204F on host == +mos-a16@bsnes-jg

$ dev/run.sh life
SMOKE: PASS off=0x1387 len=2 got=0xDDF1 (ran 500 frames, bsnes-jg)
    SHOT: PASS corpus=0xDDF1 (snapshot at frame 400)
RESULT: PASS — Conway's Life rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xDDF1 host == +mos-a16

$ dev/run.sh 1d-ca
SMOKE: PASS off=0x5A6 len=2 got=0xAB2C (ran 400 frames, bsnes-jg)
    SHOT: PASS corpus=0xAB2C (snapshot at frame 400)
RESULT: PASS — Rule 90/110 CA rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xAB2C host == +mos-a16
```
**PASS** — all three adopters green on host == `+mos-a16`@bsnes-jg == `+mos-a16`@MAME against their
committed oracles, and `mandel-oop`'s OOP dispatch gate is still exactly 1 indirect call site.
Deleting the latch and skipping one emit changed nothing any oracle can see.

### Result: 5 / 5 PASS

### What landed, and what did not

Landed: the compile-time macro, the per-drawable flag, the scene-wide AND, the guard, and four
adopting drawables — `MandelLayer`, `CaDisplay`, `LifeGrid`, `TitleLayer` (macro-gated) — across
three adopting demos. `mandel-oop` traded a demo-local latch for the shared mechanism and came out
44 bytes lighter; `life` bought a frame for 97 bytes; `1d-ca` bought the invariant for 71 bytes and
no frames. Every other demo in the tree is byte-identical.

Not landed, deliberately:

- **`BfHud` (`bf-vm`), `TextGrid` (`cpu6502`)**, and the other 14 demo-local drawables plus
  `BitmapCanvas` / `TextLayer` / `SpriteSet`: they genuinely do not qualify (2e). Making them
  qualify means moving palettes out of the UploadQueue, which is the escalation boundary this work
  was dispatched with.
- A stricter `--firstframe`. Step 3 showed two byte-identical demos flipping verdict between runs,
  which is the documented two-draw stochasticity. Raising the draw count would turn the instrument
  into a real gate rather than a strong smoke test. Out of scope here; noted for whoever ranks it.

### History

The first implementation of this plan (commit `59ca122`) was runtime-only and is superseded by the
macro-gated form above; 2a records why, with the measurements that decided it.