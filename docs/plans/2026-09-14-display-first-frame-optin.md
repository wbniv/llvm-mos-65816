# Per-drawable "first frame is complete" opt-in for snesgfx `Display`

TODO entry: `[wip T3] Per-drawable "first frame is complete" opt-in for snesgfx Display.` (M2 / #321).

Direct successor to [`2026‑08‑05-display-first-frame-forceblank.md`](2026-08-05-display-first-frame-forceblank.md),
which built and **rejected** the blanket form of this change (Option F: make the first
`display_frame()` release‑only for every demo) and closed with the recommendation this plan
implements verbatim:

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
cross it. Instead the optimisation becomes opt-in, per drawable, and defaults off.

## 2. Design

### 2a. `drawable.h` — the flag and its default

```c
struct Drawable {
  const DrawableVT *vt;
  uint8_t tm_bits;
  uint8_t first_frame_complete;   /* the opt-in */
};

static inline void drawable_reserve(Drawable *d, VramAlloc *va) {
  d->first_frame_complete = 0;    /* opt-in is OFF unless this reserve() asserts it */
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

### 2b. `display.h` — where the AND is computed, and why

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

### 2c. The gate — a guard, never a reorder

```c
static inline void display_frame(Display *d) {
  if (d->shown || !d->ff_all)
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
> puts those tokens out of order and fails the gate. The new comment block therefore describes the
> order in prose instead of quoting the calls.

### 2d. Which drawables adopt it

Qualification was read out of the code, not guessed: a drawable qualifies only if its `reserve()`
writes **the layer registers, the whole tilemap it can show, the chr those entries index, and the
CGRAM entries those tiles index**. A survey of all 21 `DrawableVT`s found only five `reserve()`s
that touch CGRAM at all, and two of those turned out not to qualify:

| Drawable | `reserve()` writes CGRAM? | whole tilemap? | verdict |
|---|---|---|---|
| `MandelLayer` (`mandel-oop.c`) | yes — `load_palette_cgram()` | Mode 7 map cleared + identity, chr rows DMA'd | **adopts** |
| `CaDisplay` (`1d-ca.c`) | yes — CGRAM 0..3 incl. backdrop | full 32×32 identity map, all 1024 chr tiles zeroed | **adopts** |
| `LifeGrid` (`life.c`) | yes — CGRAM 0..3 incl. backdrop | full 32×32 map, chr zeroed | **adopts** |
| `BfHud` (`bf-vm.c`) | **no** (the word only appears in a comment) | yes | no — blank tile indexes power-on CGRAM[0] |
| `TextGrid` (`cpu6502.c`) | yes, CGRAM 0..15 | **no** — the tilemap arrives from `_tg_emit`'s DMA | no |
| `TitleLayer` (`snesgfx/title_layer.h`) | palette 7 entries 0..2 only | yes | **left out — see §2e** |
| everything else (`BitmapCanvas`, `TextLayer`, `SpriteSet`, 14 demo-local) | no | — | no |

`mandel-oop` also **loses its demo-local workaround.** `_mandel_emit` carried an Option J
`first_emit_done` latch that skipped the first `build_step()`. With the shared gate that latch is
not merely redundant, it is *wrong*: the gate skips the first `emit()` entirely, so the latch would
not be consumed until frame 2 and would swallow frame 2's compute as well — costing back the frame
the gate just won. It is removed, and its comment block is replaced by a pointer to the shared
mechanism that superseded it.

### 2e. Why `TitleLayer` is left out (and what would qualify it)

`_title_reserve` is otherwise complete — full chr, full tilemap, both text lines, HDMA buffers
armed — but the CGRAM it writes is **palette 7 entries 0..2** (`TITLE_PAL == 7`). Its `emit()`
writes `upq_push_cgram(q, 0u, &t->back, ...)`: **CGRAM[0], the global backdrop**, which its own
blank tilemap shows everywhere. So `reserve()` does not paint everything the first visible frame
shows, and by the letter of the contract it must not assert.

In practice `title_begin()` sets `d->bright = 0` before the first `display_frame()`, so that frame
is black regardless of CGRAM — but that is a `Display` fact, not a drawable-level one, and the flag
is a claim about the drawable. Two lines in `_title_reserve` writing CGRAM[0] black would make the
claim true and unlock the gate for `1d-ca` and `life` (~1 frame each). That touches a header ~120
demos include, for 2 frames, so it is recorded as a follow-up rather than bundled here. §5 step 6
measures it on a scratch build so the follow-up starts with evidence rather than a hypothesis.

Consequence to be explicit about: **the gate does not fire for `1d-ca` or `life` today**, because
their scenes also hold a `TitleLayer`. Their flags are true statements that currently only
contribute to an AND that another drawable clears — which is exactly the intended "safe by
default" behaviour, and the enabling half of the follow-up.

### 2f. Known cost: the ROM is not byte-identical for non-adopting demos

The gate is a runtime test, so its code is compiled into **every** `Display` demo. Behaviour for a
scene with any non-asserting drawable is identical, but the bytes are not. This is measured and
reported in §5 step 4 rather than claimed away; behavioural safety is instead evidenced by steps 2
and 3 (`--firstframe` determinism unchanged; boot force-blank frame counts unchanged for every
non-adopting demo).

## 3. Files

- `examples/snes/snesgfx/drawable.h` — `first_frame_complete` field, the contract comment,
  `drawable_reserve()` clears it before dispatch.
- `examples/snes/snesgfx/display.h` — `ff_all` field, init to 1, AND in `display_add`, the
  `if (d->shown || !d->ff_all)` guard in `display_frame`, header + `display_frame` comments.
- `examples/snes/mandel-oop.c` — assert in `_mandel_reserve`; remove the Option J
  `first_emit_done` latch from `_mandel_emit` and the struct.
- `examples/snes/1d-ca.c` — assert in `_cad_reserve`.
- `examples/snes/life.c` — assert in `_life_reserve`.
- `docs/plans/2026-09-14-display-first-frame-optin.md` (this file), `TODO.md`.

## 4. Verification steps

Run from the worktree `/home/will/llvm-mos-65816-dispoptin` (branch `wt/display-first-frame-optin`),
which shares `main`'s prebuilt toolchain by hardlink per
[`howto-feature-worktree.md`](../howto-feature-worktree.md).

1. `python3 dev/snes-display-quality.py` — the `display_frame` order invariant and the upload
   budgets still hold, no new sensitive-access findings. Plus whatever `task --list` wraps it in.
2. `dev/bootblank.sh --firstframe` over all `Display` demos, **before and after**: every demo that
   did not adopt must be unchanged, every adopting demo must have a byte-identical first visible
   frame across the two default-entropy runs, and there must be **zero new** nondeterministic
   demos (`mandel-oop`'s splash-window entry is a documented pre-existing instrument artifact).
3. `dev/bootblank.sh` boot force-blank frame counts, before and after: unchanged for every
   non-adopting demo; `-1` or better for the adopters.
4. ROM identity: build every `Display` demo before and after, `sha256` table, and report exactly
   which demos changed (see §2f — this step records the real answer, it does not assume one).
5. `dev/run.sh mandel-oop` — the adopting demo's own differential/fidelity gate: corpus `0x204F`,
   exactly 1 indirect dispatch.
6. Scratch measurement for the §2e follow-up (not landed): with `_title_reserve` additionally
   writing CGRAM[0] black and asserting the flag, `dev/bootblank.sh --firstframe 1d-ca life` must
   stay deterministic and `dev/bootblank.sh 1d-ca life` must drop a frame — evidence that
   `CaDisplay`/`LifeGrid`'s assertions are sound and that the follow-up is worth doing. Reverted
   before commit.

## 5. Verification run — 2026-09-14, `wt/display-first-frame-optin`

Both sides measured on **two hardlink worktrees off the same `main` tip `22f18cb`** — the feature
tree `/home/will/llvm-mos-65816-dispoptin` and a detached baseline tree
`/home/will/llvm-mos-65816-dispoptin-base` — so "before" and "after" are the same toolchain, the
same harness and the same commit, and the two sweeps run concurrently. `dev/bootblank.sh` was
sharded three ways per tree over its own positional demo list (no script change); the bsnes-jg leg
is deterministic and load-insensitive, so sharding cannot move a verdict.

**1. `python3 dev/snes-display-quality.py` (and the Taskfile wrapper `task snes-display-quality`).**
```
$ python3 dev/snes-display-quality.py
SNESDQ: PASS (240 reviewed sensitive access sites; display order and upload budgets valid)

$ task snes-display-quality
task: [snes-display-quality] dev/snes-display-quality.py
SNESDQ: PASS (240 reviewed sensitive access sites; display order and upload budgets valid)
```
**PASS** — the four-token `display_frame` order survives the guard, same 240 sites, no new
findings. (First attempt FAILED: the new comment block quoted the literal tokens above the code,
and the checker's `find()` is over the raw file. Comment reworded to prose; see 2c.)

**2. `dev/bootblank.sh --firstframe`, all 117 measurable Display demos, before and after.**
```
BEFORE nondeterministic: 4  ['mandel-oop', 'multibase', 'mvscrl', 'qsortviz']
AFTER  nondeterministic: 4  ['mandel-oop', 'multibase', 'mvscrl', 'qsortviz']
NEW (regressions): []
FIXED: []
```
**PASS** — byte-identical verdict sets. **Zero new** nondeterministic demos; the four that flag do
so on the **unmodified baseline too**, so none is a regression (`mandel-oop`'s is the instrument
artifact documented in the 2026‑08‑05 plan: its sampled frame lands inside the `m7splash`
animation). Every non-adopting demo keeps a byte-identical first visible frame across two
default-entropy runs, and so does `mandel-oop` — whose first frame is now genuinely the
release-only one.

**3. `dev/bootblank.sh` boot force-blank frame counts, before and after (117 demos, `FRAMES=300`).**
```
demo                 before    after    delta
(0 of 117 demos changed)
total boot force-blank frames: 2598 -> 2598
```
**PASS** for the safety half: not one non-adopting demo moved by a single frame.

`mandel-oop` is absent from that delta by construction — its black window is the **post-title** one,
which `dev/bootblank.sh` does not measure (2026‑08‑05 plan 2). Measured with the right instrument,
on both trees:
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
**PASS, and this is the load-bearing result of the whole change.** `mandel-oop` holds 5 frames
*while its demo-local Option J latch is deleted*. The latch was the only thing keeping it at 5; had
the shared gate not fired, removing it would have put the demo straight back to 11. 5 → 5 with the
latch gone is therefore positive proof the scene-wide AND resolved to 1 and the first
`scene_emit()` was skipped. The mechanism has replaced the workaround at identical cost, which is
the invariant this item was for — not new frames.

**4. ROM identity for non-adopting demos — the one thing that did NOT hold as specified.**
```
buildable: 117   unbuildable (pre-existing, 5): bankwalk farptrcmp farspill invaders seamdemo
byte-identical: 0
changed: 117
```
Baseline hashes were produced twice, once by reverting the headers in the feature tree and once by
building the separate baseline worktree; the two tables are identical, so the comparison is sound
and the result is real.

**Expected, and explained in 2f: this cannot hold.** The gate is a runtime test compiled into every
`Display` demo, so every ROM's bytes shift. What matters is the size of it and whether behaviour
moved. `.text` from the link maps:
```
demo            .text b  .text a   delta
newton            11226    11246     +20
doom-fire          8058     8064      +6
boids             12948    12968     +20
spigot            13944    14005     +61
life               9210     9293     +83     <- adopter (assertion + comment)
1d-ca              8332     8389     +57     <- adopter
mandel-oop         6419     6375     -44     <- adopter (latch deleted)
burning-ship       8800     8848     +48
rdiff             10624    10655     +31
hdr-bloom          8669     8665      -4
```
Tens of bytes, both signs (the negatives are codegen shifting, not code removed). **Behavioural**
safety — which is what "safe by default" actually claims — is carried by steps 2 and 3 instead, and
they are stronger evidence than a hash would have been: 117/117 demos identical in first-visible-frame
determinism *and* identical to the frame in boot force-blank length.

Recorded as a **deviation from the dispatched spec**, not as a pass.

**5. `dev/run.sh mandel-oop` — the adopter's own differential gate.**
```
==> built build/mandel-oop.sfc (+mos-a16, -verify clean); corpus_result @ WRAM 0x897
SMOKE: PASS off=0x897 len=2 got=0x204F (ran 5800 frames, bsnes-jg)
==> MAME (under Xvfb): assert corpus_result
    SHOT: PASS corpus=0x204F (snapshot at frame 5800)
    indirect JMP count in .text: 0
    indirect dispatch call sites (jmp-ind + jsr-ind + jsr __call_indir): 1
RESULT: PASS — mandel-oop OOP gate GREEN; corpus_result==0x204F on host == +mos-a16@bsnes-jg
```
**PASS** — `0x204F` on host == `+mos-a16`@bsnes-jg == `+mos-a16`@MAME, `-verify-machineinstrs`
clean, and the OOP dispatch gate still exactly 1 indirect call site. Deleting the latch changed
nothing the oracle can see.

**6. Scratch probe for the `TitleLayer` follow-up (2e) — applied, measured, reverted.**

With `_title_reserve` additionally writing CGRAM[0] black and asserting the flag (so `1d-ca` and
`life` reach a scene-wide AND of 1):
```
$ dev/bootblank.sh --firstframe 1d-ca life          # probe tree
1d-ca                  f=13  ok (fe3ca7395583965d)
life                  f=301  ok (fe3ca7395583965d)
PASS: every first visible frame is byte-identical across two default-entropy runs.
```
```
$ FRAMES=500 dev/bootblank.sh 1d-ca life
--- baseline tree ---                --- probe tree ---
1d-ca                    12          1d-ca                    12
life                    362          life                    361
```
**PASS** — and it says two useful things. `CaDisplay`'s and `LifeGrid`'s assertions are **sound**:
with the gate actually firing, both demos' first visible frames stay deterministic at default
entropy, which is precisely the test that killed the blanket version. And the follow-up is worth
about **one frame on `life`, zero on `1d-ca`** — `1d-ca`'s first `_cad_emit` is a queued scroll
write plus two clear dirty flags, far under a frame, so the release lands in the same frame either
way. `git diff` confirms `title_layer.h` is byte-identical to `HEAD`; nothing from this probe is
committed.

### Result: 5 / 6 PASS, 1 deviation (step 4, ROM identity — see 2f, cannot hold for a runtime gate)

### What landed, and what did not

Landed: the flag, the scene-wide AND, the guard, and three adopters — `MandelLayer`, `CaDisplay`,
`LifeGrid`. `mandel-oop` is the only one whose scene-wide AND resolves to 1 today, and it traded a
demo-local latch for the shared mechanism at identical cost.

Not landed, deliberately:

- **`TitleLayer`.** Its `reserve()` does not write CGRAM[0], which its own `emit()` owns — 2e. Two
  lines would qualify it and would unlock `life` (−1 frame) and `1d-ca` (−0); step 6 measured both.
  It touches a header ~120 demos include, so it is a follow-up with evidence attached, not a
  bundled extra.
- **`BfHud` (`bf-vm`), `TextGrid` (`cpu6502`)**, and the other 14 demo-local drawables plus
  `BitmapCanvas` / `TextLayer` / `SpriteSet`: they genuinely do not qualify (2d). Making them
  qualify means moving palettes out of the UploadQueue, which is the escalation boundary.
- **ROM-level byte identity for non-adopters** (step 4) — not achievable with a runtime gate.
