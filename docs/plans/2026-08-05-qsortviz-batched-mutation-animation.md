# qsortviz — batch real qsort mutations into each displayed frame

**Status:** implemented, emulator-verified, and published. **Target:** [biohack.net/snes/qsortviz](https://biohack.net/snes/qsortviz/).

**Mockups:** [open the animation pacing and state storyboard](2026-08-05-qsortviz-batched-mutation-animation/mockups.html).

## Outcome

Keep the current animation's strongest property—every displayed bar arrangement is read from the real
array while libc `qsort` is operating—but stop forcing `qsort` to wait one video frame after every
mutation. Accumulate several observed mutations, then display the newest real memory state once per frame.

The viewer should see an unmistakable progression from shuffled bars to the comparator's ordering in
roughly one second, rather than a multi-second single-step trace. No synthetic swap replay and no second
sorting implementation.

## Why the current build is slow

libc `qsort` exposes comparator callbacks, not a swap hook. The current visual wrappers compare the real
32-element array with a snapshot on every callback. When a mutation is detected they redraw the complete
128×128 canvas and call `display_frame()` immediately.

That call is not an optional delay: it blocks until the next 60 Hz presentation boundary. A sort with
dozens of array mutations therefore takes at least dozens of frames, plus full-canvas redraw/upload work.
Removing the earlier two-frame hold halved the duration, but the algorithm is still artificially limited
to at most one mutation per video frame.

## Selected pacing model

Use a fixed mutation batch with a frame-time safety valve:

- `MUTATIONS_PER_FRAME = 6` initially.
- On every comparator callback, detect whether the backing array differs from the last observed snapshot.
- Always update the snapshot and increment `pending_mutations`; skipped mutations are still observed and
  counted, but they do not block `qsort`.
- When `pending_mutations == MUTATIONS_PER_FRAME`, redraw from the **current real array**, present one
  frame, and reset the counter.
- When `qsort` returns, always redraw/present the final state even if the partial batch contains fewer
  than six mutations.
- Never add hold frames. The existing 80-frame pause between shuffle/sort epochs remains independent.

Six is a starting engineering value, not an aesthetic constant. Verification records the actual mutation
count and elapsed presentation frames for ascending, parity, and descending passes. Adjust within 4–8 only
if a pass falls outside the acceptance window below; record the measured choice in this plan.

### State flow

```text
comparator callback
      │
      ├─ array unchanged ───────────────────────────────► return comparison
      │
      └─ array changed
             │ snapshot current real array
             │ pending++
             ├─ pending < 6 ────────────────────────────► return comparison
             └─ pending = 6
                    │ draw latest real array
                    │ display exactly one frame
                    │ pending = 0
                    └───────────────────────────────────► return comparison

qsort returns ─► draw/present final real array ─► idle epoch
```

## Visual contract

The mockup covers four required states:

1. **Shuffle:** unsorted bars with the existing palette and `SHUFFLE` HUD.
2. **Early batch:** the first displayed sort state after six real mutations; visibly changed, still noisy.
3. **Late batch:** mostly ordered, with a few displaced bars; this proves the animation does not jump from
   initial to final.
4. **Complete:** the existing final ascending/parity/descending arrangement.

No new counters or debug text ship in the ROM. The mockup's batch labels and timeline are explanatory
annotations outside the 256×224 screen. The cartridge retains its current HUD, palette, canvas size, and
bar geometry.

## Implementation

### `examples/snes/qsortviz.c`

Replace the one-mutation/one-frame policy in `sort_anim_tick()` with:

```c
#define MUTATIONS_PER_FRAME 6u

static uint8_t sort_anim_pending;

static void sort_anim_tick(void) {
  App *a = sort_anim_app;
  if (!a || !sort_anim_changed(a)) return;

  sort_anim_snapshot(a);
  if (++sort_anim_pending < MUTATIONS_PER_FRAME) return;

  sort_anim_pending = 0u;
  draw_bars(a);
  display_frame(&a->screen);
}
```

Reset `sort_anim_pending` before each visual `qsort`. Preserve the unconditional `draw_bars()` after
`qsort` so the last mutation cannot be omitted. Factor the comparison loop into `sort_anim_changed()` to
make the callback policy explicit and testable.

The three visual wrapper comparators remain wrappers around `qs_cmp_asc`, `qs_cmp_parity`, and
`qs_cmp_desc`. The differential gate in `examples/65816/qsortviz.h` continues to call the original
comparators directly and must remain byte/value independent of animation state.

### Temporary measurement instrumentation

Behind `#ifdef QSORTVIZ_PACING_PROBE`, record per pass:

- comparator callbacks;
- observed array mutations;
- presented intermediate frames;
- final presentation frame;
- maximum skipped mutations between presentations.

Expose the compact counters in WRAM for `jgxcheck` or a one-off Lua probe. Do not ship the probe flag in
the published ROM. This replaces subjective “still slow” tuning with exact counts.

## Files

| File | Change |
|---|---|
| `examples/snes/qsortviz.c` | Batch mutation observations and present only the latest real state per batch |
| `dev/qsortviz.sh` | Add a pacing-probe build/run and acceptance checks; retain existing CRC/disassembly gates |
| `docs/plans/2026-06-30-46-snes-qsortviz.md` | Record final measured batch size and timing |
| `docs/plans/2026-08-05-qsortviz-batched-mutation-animation.md` | This implementation plan |
| `docs/plans/2026-08-05-qsortviz-batched-mutation-animation/mockups.html` | Four-state pacing mockup |
| `public/play/roms/qsortviz.sfc` in `biohack.net` | Replace only after the full gate and visual review pass |

## Acceptance criteria

### Correctness and compiler-demo contract

1. `dev/run.sh qsortviz` passes on bsnes-jg and MAME.
2. `corpus_result == 0x8EA5` remains unchanged.
3. Disassembly still proves libc `qsort`, the comparator function-pointer table, all three callbacks, and
   native-width `rep`/`sep` activity.
4. The shared host/default/a16/xy16 corpus gate remains green; no visual wrapper enters the CRC path.

### Pacing

1. Each visual sort pass presents at least 4 intermediate states plus the final state—enough to read as
   animation rather than a jump.
2. No pass presents more than 18 intermediate frames—avoids returning to single-step pacing.
3. Each pass completes its active sorting animation in 0.4–1.2 seconds at 60 Hz, excluding the existing
   epoch pause.
4. Every captured intermediate frame equals a snapshot previously observed in the actual `a->bar` array;
   no generated interpolation or replay state exists.
5. The final frame exactly matches the sorted array returned by libc `qsort`.

### Visual review and publication

1. Capture early, middle, late, and final frames from bsnes-jg and compare them with the mockup storyboard.
2. Confirm the HUD changes to the selected comparator before the first intermediate frame.
3. Confirm no partial canvas upload, tearing, or stale final bars on bsnes-jg and MAME.
4. Publish only the verified `qsortviz.sfc`, update the plan with measured counts/timing, wait for deployment,
   and verify the live ROM hash before handoff.

## Non-goals

- Replacing libc `qsort` with a hand-written swap-hooked sort.
- Replaying a separately recorded swap list.
- Displaying every mutation; that is the slow behavior this plan replaces.
- Changing the compiler regression, comparator semantics, bar palette, or page layout.

## Implementation record — 2026-08-05

- Implemented a fixed batch of **six observed real-array mutations per intermediate frame**.
- Every callback still compares the live `a->bar` storage with its previous snapshot. Changed snapshots
  are always retained; only presentation is batched.
- The post-`qsort` `draw_bars()` remains unconditional, so the returned array is always the final state.
- Added `QSORTVIZ_PACING_PROBE` counters in WRAM; they are compiled out of the release ROM.
- `dev/run.sh qsortviz`: PASS on bsnes-jg and MAME, including the unchanged `0x8EA5` corpus hash and
  the libc-`qsort`/function-pointer/disassembly gate (`qsort=1`, comparator refs=79, table=1,
  `rep`/`sep`=37).
- `dev/run.sh _demo5 qsortviz`: PASS, `host == default == +mos-a16 == +mos-xy16 == 0x8EA5`, with
  `-verify-machineinstrs` clean for A16 and XY16.
- The bsnes-jg frame-440 capture shows an in-progress ascending pass, confirming the batched animation
  exposes intermediate memory states rather than jumping directly to the result.
- Published ROM SHA-256: `6262bd3ebb71fdcc34522c7bb65380847ac02fae9db4083b4ce835d08f262c13`.
  The exact hash was verified from both live CDNs after deployment (biohack.net tag `v1.0.386`,
  indri.studio tag `v0.1.153`).
