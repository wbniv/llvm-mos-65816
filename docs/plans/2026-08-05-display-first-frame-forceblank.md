# `snesgfx` Display — force-blank held across the first `scene_emit()`

TODO entry: `[T4] snesgfx Display: 6 frames of force-blank inside the FIRST display_frame()`
(M2 / #321), escalated out of
[the Mode 7 splash floor plan](2026-08-05-mode7-splash-forceblank-floor.md), which localised
`mandel-oop`'s residual 11-frame window to 4 frames of splash handoff plus ~6 inside the first
`display_frame()`.

**Visible surface:** ROM startup timing. The before/after frame tables below are the mockup
equivalent; `dev/bootblank.sh` and `dev/m7blank.sh` reproduce every number in one command.

---

## 1. The defect, precisely

`display_frame()` releases the boot force-blank at its **end**:

```
scene_emit()      <-- application compute, unbounded, screen still OFF
wait_vblank()
upq_flush()
REG_INIDISP = bright        <-- the release
```

On the first call this sequences the release behind an arbitrary amount of application compute.
The screen is off for the whole of it, even though `reserve()` has already written the content
that frame will show — `display_add()`'s own contract is that `reserve()` bulk-writes VRAM inside
the boot window and "MUST be called before the first `display_frame()`".

## 2. Correcting the dispatched premise — measured

The TODO text (which I wrote) claimed "Every `Display` demo pays it". **That is false, and the
measurement says so.** New tool `dev/bootblank.sh` measures the boot force-blank window — frame 1
to the release — for every demo that constructs a `Display`, using the `M7BLANK_PROBE` instrument
from the splash plan so the measured black run is the force-blank window and not a demo's black art.

Baseline, 117 demos measured (5 of 122 do not link in this harness):

```
total boot force-blank frames: 2660
distribution (frames: demos):
  7:1  8:2  9:2  12:3  13:60  14:15  15:8  16:3  17:2  18:2  19:1  20:3  21:1  22:1
  25:1  30:1  35:1  45:1  47:1  50:1  55:1  72:1  92:1  106:1  111:1  203:1  362:1
top: life 362, modexp256 203, rdiff 111, ucmprank 106, pcooker 92, truchet 72, doom-fire 55
```

The mode is **13 frames across 60 demos**, and that 13 is `reserve()` — bulk VRAM/CGRAM writes that
genuinely require the blank. Spiking the fix and re-measuring all 117 shows what the first
`scene_emit()` actually costs:

```
13 of 117 demos changed, 1 frame each; total 2660 -> 2647
borrowlad -1  burning-ship -1  doom-fire -1  harmonograph -1  hdr-bloom -1  iir-scope -1
life -1  lsystem -1  msquares -1  newton -1  rdiff -1  sodo -1  spirograph -1
```

So the first emit costs **at most one frame for every demo in the tree except `mandel-oop`**, whose
`_mandel_emit` → `build_step()` is an unusually expensive first emit (8 escape-time cells + a
512-far-store row expansion + `build_chr_row()`'s 512 far loads + a 512-byte queue copy).

`mandel-oop` does not appear in the `bootblank` delta because its boot black is the pre-title
ramp, which `display_frame()` never touches. Its window is the **post-title** one, and that is
where the 6 frames are:

```
$ dev/m7blank.sh --probe mandel-oop
BASE     mandel-oop   239..249 = 11
SPIKE-F  mandel-oop   239..243 =  5
```

**Honest framing of the value.** The measured saving today is 6 frames on one demo plus 13 frames
spread over 13 others — not "122 demos × 6". What the change actually buys is the **invariant**:
application compute can no longer sit inside the boot force-blank window, the same contract the
splash plan established for the other window. The splash work found demos grinding 350 frames in
the dark against their own source comments; an expensive `emit()` is the same trap on the other
side of the boundary, and nothing currently prevents it.

## 3. Design

```c
static inline void display_frame(Display *d) {
  if (d->shown) scene_emit(&d->scene, &d->q);
  (void)REG_RDNMI;
  snes_wait_vblank();
  upq_flush(&d->q);
  ...
  REG_INIDISP = (uint8_t)(d->bright & 0x0Fu);
  d->shown = 1;
}
```

The first `display_frame()` becomes *release-only*: sync to a clean v-blank, flush an empty queue,
drop the blank. The screen comes up showing exactly what `reserve()` painted — which is what
`reserve()` is for ("install a small deterministic loading texture"). The application's first emit
runs on the next call, with the screen **on**.

### Why this cannot regress the `1dd9317` flicker class

`1dd9317` was: `display_frame` **asserted** force-blank around the DMA so an over-long transfer
would "succeed at any vcounter"; when the flush outran v-blank, the release landed in active
display and blanked the top scanlines.

1. **The change adds no `REG_INIDISP` write and removes none.** There is still exactly one write in
   `display_frame`, at the same place, with the same `& 0x0Fu` mask that makes the force-blank bit
   unrepresentable. The flicker needs a *force-blank assertion*; the diff introduces no way to
   produce one.
2. **It does not move the release relative to `upq_flush`.** The release still happens after the
   flush, inside the v-blank the frame waited for. The timing relationship the bug was about is
   untouched.
3. **It strictly *reduces* work before the release on the first frame.** The v-blank budget
   argument is unchanged for every subsequent frame, and the first frame now flushes an empty
   queue — the least possible DMA, so it cannot overrun.
4. **The enforced invariant still holds byte-for-byte.** `dev/snes-display-quality.py` asserts the
   token order `scene_emit(&d->scene, &d->q);` → `snes_wait_vblank();` → `upq_flush(&d->q);` →
   `REG_INIDISP = (uint8_t)(d->bright & 0x0Fu);`. Wrapping `scene_emit` in an `if` leaves all four
   tokens in place and in order. **This is why the design is a guard rather than a reorder** — see
   the rejected alternatives.

### Considered and rejected

- **Release before `scene_emit` (an early `wait_vblank` + `REG_INIDISP` block at the top).** Would
  save the same frames *and* land the emit's content on frame 1 instead of frame 2. Rejected: any
  such block puts a `snes_wait_vblank();` and a `REG_INIDISP` write textually before `scene_emit`,
  which breaks `snes-display-quality.py`'s order invariant. That invariant *is* the encoded
  `1dd9317` lesson; a design that requires rewriting the guard protecting the exact regression class
  I was told not to regress is the wrong design, and the extra frame it buys is one frame.
- **Fix `_mandel_emit` instead (skip `build_step` on the first call).** Zero shared-header risk and
  gets `mandel-oop` 11 → 5. Rejected as the *primary* fix because it leaves the trap armed for the
  next demo; but it is the fallback if the safety verification below finds a regression.
- **An opt-in `Display` flag.** Dead code — a safety property nobody enables is not a property.

### The one real risk, and how it is tested

Under this change the first visible frame shows `reserve()` content only. A layer whose content is
written **solely by `emit()`** would show whatever VRAM held before — and bsnes-jg randomises
power-on VRAM. `_text_reserve` is exactly such a layer: it loads the font but never writes the text
tilemap. It is saved by `_canvas_reserve`, which writes all 32×32 BG3 tilemap entries (blank outside
the canvas box) — but only if a `BitmapCanvas` is added first, which nothing enforces.

So the safety property to verify is: **the first visible frame must not depend on uninitialised
VRAM.** That is directly testable — bsnes-jg's default entropy randomises power-on VRAM, so a frame
that reads it is *nondeterministic across runs at default entropy*, while a frame that does not is
byte-identical. `dev/bootblank.sh --firstframe` captures each demo's first visible frame twice at
default entropy and compares. Run before and after, so a pre-existing nondeterminism is not
misreported as a regression.

## 4. Verification steps

1. `dev/bootblank.sh --firstframe` across all Display demos, with Option F applied — establishes
   whether the shared change is safe. **This is the step that decided the design.**
2. `dev/m7blank.sh --probe mandel-oop`: 11 → 5.
3. `dev/m7blank.sh --gate` passes for the whole splash set with `mandel-oop` tightened 12 → 6.
4. `dev/run.sh mandel-oop` — differential gate green, corpus `0x204F`, exactly 1 indirect dispatch.
5. `python3 dev/snes-display-quality.py` — order invariant + budgets valid, no new findings.
6. `snesgfx/display.h` is byte-identical to `main` (Option F reverted; nothing shared changed).

## 5. Results — 2026-08-05, `wt/321-dispfirst`

### The design hits the target

```
$ dev/m7blank.sh --probe mandel-oop
BASE      mandel-oop   239..249 = 11
OPTION-F  mandel-oop   239..243 =  5     <- the dispatched target (4 splash handoff + 1)
```

### …and the predicted risk is real, demonstrated on `newton`

`dev/bootblank.sh --firstframe` runs each demo's first visible frame **twice at bsnes-jg's default
(power-on-randomising) entropy** and compares. A frame that reads uninitialised VRAM is
nondeterministic; a correct one is byte-identical.

```
BASELINE  newton   f=9  ok (b82b8d53408b0678)
OPTION-F  newton   f=8  NONDETERMINISTIC first visible frame
```

Reproduced by hand on the emitted ROM, outside the harness — same ROM, same frame, two runs:

```
$ build/jgxcheck build/bootblank/newton-ff.sfc … 8 /tmp/g1.png ; sha256sum
61a4760acbbad1b7…
$ build/jgxcheck build/bootblank/newton-ff.sfc … 8 /tmp/g2.png ; sha256sum
b2978bd36044e945…
```

`newton` adds a single demo-local drawable whose `reserve()` does not paint everything its `emit()`
writes. With the emit skipped, the first visible frame shows power-on VRAM. This is exactly the
failure mode §3 predicted, and it is a **visible one-frame garbage flash**, not a timing nicety.

The instrument needed one correction to be trustworthy: the release frame is derived from a
`M7BLANK_PROBE` build, but the compared captures must come from a **probe-free** rebuild — the
probe writes CGRAM[0] itself and would mask the very dependence being tested. An earlier run that
appeared to clear `newton` was comparing a stale baseline ROM; the finding above is after that fix
and reproduces on every rerun.

### The zero-risk alternative reaches the same number

Skipping only `mandel-oop`'s own first `build_step()` — a demo-local change, no shared header —
measures identically:

```
ALT-J  mandel-oop   239..243 = 5
```

### Where that leaves the decision

|  | Option F (shared `display.h`) | Option J (demo-local) |
|---|---|---|
| `mandel-oop` | 11 → 5 | 11 → 5 |
| other 116 Display demos | −13 frames total (1 each on 13) | 0 |
| establishes the invariant | yes | no |
| known breakage | `newton` first frame reads uninitialised VRAM; full sweep pending | none |
| blast radius | 122 demos | 1 demo |

Option F's benefit outside `mandel-oop` is **13 frames across 117 demos**. Its cost is a one-frame
garbage flash on every demo whose drawable paints from `emit()` rather than `reserve()`. That
inverts the usual calculus for this repo ("a blanket change that regresses common shapes to win a
sub-case is wrong; gate it"), so Option F is only correct if the offending `reserve()`s are also
fixed — and fixing them is a change to each demo's drawable contract, which is the escalation
boundary this work was dispatched with.

### The full sweep, and why Option F is architecturally wrong here — not merely risky

`dev/bootblank.sh --firstframe` across all 117 measurable Display demos, with Option F applied:

```
FAIL: 6 demo(s) have a nondeterministic first visible frame
  burning-ship  doom-fire  hdr-bloom  mandel-oop  multibase  rdiff
```

`mandel-oop`'s entry is an **instrument artifact, not a regression**: its sampled frame lands inside
the `m7splash` animation, which plan 121 already documents as entropy-sensitive ("mandel-oop leaves
some PPU state unset during the title/loading window"). Re-running the baseline three times flags it
3/3, so it fails without the change too. A single earlier baseline run that showed `ok` was luck —
the gate compares two random draws, so it can coincide. **Caveat on the instrument:** it is sound for
non-splash demos, stochastic for splash demos, and a stricter version would use more than two runs.

That leaves five real regressions, and reading the code gives the mechanism exactly:

```c
/* examples/snes/newton.c — _newton_emit */
if (!l->pal_sent) {
    upq_push_cgram(q, 0u, newton_pal, 0x00u, (uint16_t)sizeof newton_pal);
    l->pal_sent = 1u;
}
```

`_newton_reserve` is careful — it zeroes the BG1 tilemap *and* writes its 16 chr tiles, with a
comment explaining why. What it does not do is load CGRAM, because **snesgfx routes CGRAM through
the UploadQueue**, and the queue is driven by `emit()`. So the palette arrives on the first emit,
guarded by a `pal_sent` latch.

That idiom is not incidental: **119 of the 122 Display demos call `upq_push_cgram`.** A release-only
first frame therefore renders them with power-on CGRAM. Only the handful whose first visible frame
is uniformly black regardless of palette escape detection.

So Option F does not need "a few `reserve()`s fixed". It needs the palette moved out of the queue
and into `reserve()` across the demo set — i.e. a change to the `reserve()`/`emit()` split that
snesgfx deliberately chose, for 119 demos. That is squarely the escalation boundary this work was
dispatched with ("per-demo contracts beyond the reveal timing"), and the benefit being bought is
13 frames spread over 117 demos.

### What landed

**Option J**, demo-local, in `_mandel_emit`. `mandel-oop` is one of the three demos that does *not*
depend on the queue for its first palette — `_mandel_reserve` calls `load_palette_cgram()`, writing
CGRAM directly under force-blank — which is exactly why the skip is safe there and unsafe generally.

```
$ dev/m7blank.sh --probe mandel-oop
  before  239..249 = 11
  after   239..243 =  5      <- dispatched target met
```

`dev/m7blank.sh`'s `mandel-oop` budget tightened 12 → 6.

### Recommendation to the coordinator

Option F is **not** worth pursuing as specified. If the invariant is still wanted, the shape that
would work is a per-drawable opt-in — a `Drawable` flag a `reserve()` sets to assert "I painted
everything my first frame shows", with `display_frame` taking the early release only when every
drawable in the scene asserts it. Safe by default, no demo regresses, and drawables adopt it as
their palettes move out of the queue. That is a new design, not this one, and it should be ranked
on its own.
