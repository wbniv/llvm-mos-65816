# #124 — LZSS Gallery Priority Navigation + Sprite Chevrons

**Status:** IMPLEMENTED LOCALLY (2026-07-26); publication verification pending. Follow-up to the aspect-preserving maximum-resolution gallery in
[#122](2026-07-26-122-lzss-gallery-maximum-mode7-resolution.md).

## Goal

Add obvious previous/next navigation:

- Left on the joypad immediately selects the previous artwork.
- Right immediately selects the next artwork.
- Persistent left/right sprite chevrons communicate that navigation is available.
- A navigation request has priority over decompression, display holds, recompression, comparison,
  verification, result holds, and Mode 7 transitions.

“Priority” means the program does not finish the current benchmark stage first. It cancels the
current slide's in-progress work, discards partial results, and starts loading the requested slide.

## Interaction

| Input | Result |
|---|---|
| Right press | Cancel current work; select `(index + 1) % asset_count` |
| Left press | Cancel current work; select `(index + asset_count - 1) % asset_count` |
| Left + Right in the same sample | Cancel work but remain on the current slide |
| Held direction | One move only; require release before another move |
| New opposite press while the first request is pending | Latest edge wins |

Use press edges, not level-triggered autorepeat. This prevents a single held direction from racing
through the entire gallery while a new image is loading.

The selected slide becomes visible as quickly as possible:

1. latch the navigation request;
2. set the shared cancellation flag;
3. stop the active codec/check stage at its next cancellation point;
4. suppress `VERIFIED`, timing publication, corpus folding, and failure coloring for the canceled
   slide;
5. force-blank only for the new image's VRAM upload;
6. decode and display the selected image; and
7. begin its benchmark from a clean state.

Do not run the normal spin/zoom transition after a manual navigation request. Manual navigation is
an immediate cut. Automatic carousel advancement retains the Mode 7 spinout.

## Input must preempt CPU-bound codec work

The current gallery compressor and decoder are synchronous CPU-bound loops. Merely checking the
joypad between stages would make input wait tens of seconds. Refactor input capture and codec work
so a press is observed during those loops.

### NMI input capture

Extend the existing minimal frame-clock NMI into a register-safe input hook:

- preserve P, A, X, Y, DBR, and any width state it changes;
- increment the benchmark frame clock;
- sample controller 1 every frame;
- compute new Left/Right press edges from current and previous pad state;
- write only small volatile fields:
  `nav_request`, `nav_cancel`, `pad_now`, and `pad_previous`;
- return with the interrupted accumulator/index width and registers unchanged.

Prefer automatic joypad reading if its completion timing can be made correct. If NMI entry occurs
before auto-read completes, either wait for `$4212` autojoy-busy to clear inside a strictly bounded
path or use a proven manual-latch routine. Do not read half-updated `$4218/$4219`.

The NMI must not call ordinary C code, allocate stack frames, touch codec buffers, write VRAM/OAM,
or perform the slide change itself. It captures intent; the foreground state machine performs the
safe cancellation and switch.

### Cancellation points

Add a cheap `nav_cancel` check at bounded intervals:

- decoder: before each token and inside long overlapping match copies;
- compressor: before every token, every hash-chain candidate, every match byte comparison, and
  every insertion in a multi-byte advance;
- exact compressed-stream comparison: at least every 32 bytes;
- checksum and decoded-byte comparison: at least every 32 bytes;
- display/result holds: every frame;
- automatic spinout: every frame; and
- VRAM tile-row staging: before each tile row.

Worst-case response latency must be less than one video frame after the NMI latches the press. The
64-candidate matcher is not allowed to postpone cancellation until the candidate chain finishes.

Codec functions return a distinct `CANCELED` status, separate from malformed input, output
exhaustion, checksum mismatch, or verification failure. Cancellation is normal user control and
must never make the surround red or poison the corpus oracle.

## Foreground slide state machine

Replace the nested blocking carousel loop with explicit states:

```text
SELECT
  -> DECODE_ROM
  -> UPLOAD_AND_SHOW
  -> VIEW_HOLD
  -> REPACK
  -> GOLDEN_COMPARE
  -> SECOND_DECODE
  -> BYTE_VERIFY
  -> RESULT_HOLD
  -> AUTO_SPINOUT
  -> SELECT(next)
```

Every state can return `CONTINUE`, `DONE`, `FAILED`, or `CANCELED`.

On `CANCELED`:

```text
discard partial stream and stage timers
clear progress/status for the old work
selected_index = requested index
nav_cancel = 0
state = SELECT
```

If navigation arrives during `SELECT`, coalesce it before decoding so rapid alternating taps do
not perform needless intermediate uploads.

The benchmark semantics remain strict:

- only a complete uninterrupted slide contributes timing results;
- only a complete uninterrupted verification contributes to `corpus_result`;
- canceled work is not a zero, failure, or partial sample;
- after manual browsing stops, the selected image starts a fresh full benchmark; and
- the full-corpus self-check becomes valid only after all ten works have completed uninterrupted
  since the last reset.

Track completion with a generated asset-count bitset rather than assuming sequential order.
Browsing 3→2→3 must not double-count work 3.

## Sprite chevrons

Use OBJ sprites rather than a BG layer so the arrows remain visible across both the Mode 7 artwork
and Mode 1 caption portions without consuming artwork tiles or font tilemaps.

### Appearance

- one left chevron at the left screen edge;
- one right chevron at the right screen edge;
- vertically center both within the artwork display region for the current slide;
- 8×16 or 16×16 sprites, whichever produces the clearest silhouette;
- gold/cream face with a dark one-pixel shadow matching the Waldo caption palette;
- no text labels and no animation required;
- move inward enough that all opaque pixels remain inside the 256-pixel screen;
- use horizontal flip so both arrows share one character where practical.

Add a small generated 4bpp OBJ character and 16-color OBJ palette. Do not reuse Mode 7 character
data or depend on a slide's art palette.

### OAM and HDMA

- Allocate fixed OAM entries for left/right arrows.
- Upload their character/palette data once during initialization.
- Update only their Y position when the current slide's artwork region changes.
- Add `TM_OBJ` to both halves of the `$212C` HDMA table:
  Mode 7 region = `BG1 | OBJ`; Mode 1 caption region = `BG2 | BG3 | OBJ`.
- Keep arrows visible during decode, benchmark, verification, and result holds.
- Hide them during the title screen, force-blank upload, and automatic spinout.
- Restore them immediately when the newly selected slide is shown.

Pulse the pressed arrow for 4–6 frames by switching palette entry or sprite tile, but do not delay
navigation to show the pulse.

### HTML mockups

- [Native-screen and 4× sprite-chevron mockups](2026-07-26-124-lzss-gallery-priority-navigation/navigation-chevron-mockups.html)

The mockup covers landscape, square, and portrait artwork regions, the HDMA boundary, edge
placement, horizontal flip reuse, normal and pressed palettes, and a 4× pixel inspection. Treat the
revised 16×16 conventional `‹` silhouette—two plain diagonal strokes, no stem, badge, diamond, or
decorative notches—and three-color palette as the initial implementation target; final emulator
captures remain authoritative.

## Status behavior

When a press is latched, the status row immediately changes to:

- `PREVIOUS...`
- `NEXT...`
- `RESTART...` for simultaneous Left+Right.

This message may appear for only one frame. The newly selected slide then starts at `UNPACK` and
continues through the normal work-based progress meter.

Do not show stale timing or `VERIFIED` from the canceled slide.

## Timing and benchmark accounting

NMI input polling adds fixed per-frame overhead. Re-run every timing measurement after navigation
lands; #122's frame table is no longer directly comparable.

Report:

- NMI cycles with and without a direction edge;
- cancellation latency in frames for every stage;
- uninterrupted decompression/recompression/verification frames;
- interrupted work units discarded;
- count of manual slide changes; and
- final ten-work corpus completion/oracle.

The benchmark remains the program's purpose. Navigation makes the corpus inspectable; it must not
weaken exact stream comparison or turn incomplete samples into benchmark results.

## Implementation record

- Controller 1 is sampled in NMI with a manual `$4016` latch/read sequence; Left/Right edges set a
  foreground cancellation request without touching codec or PPU state.
- Decoder, compressor, stream comparison, byte verification, holds, spinout, and each VRAM
  tile-row upload contain cancellation points.
- Left/Right wrap in both directions, a held direction moves once, and simultaneous Left+Right
  restarts the selected work.
- Manual navigation cuts directly to the requested work and suppresses the automatic spinout.
- Two conventional 16×16 gold chevrons use fixed OBJ entries, one shared graphic plus horizontal
  flip, a dark one-pixel shadow, and remain enabled across both HDMA screen regions.
- Completion is an asset-count bitset. Each successful uninterrupted work replaces its indexed
  sample; after all ten bits are present, the final oracle is folded in canonical corpus order.
  Browsing order therefore cannot double-count a work or change the expected oracle.
- Instrumentation exposes the current asset and canceled-work count in WRAM for scripted emulator
  tests.

Scripted bsnes-jg evidence:

| Sequence | Assertion | Result |
|---|---|---|
| wait 200, tap Right, release | asset 0 → 1 | PASS |
| wait 200, tap Left, release | asset 0 → 9 | PASS |
| wait 200, hold Right 30 frames, release | canceled-work count = 1 | PASS |

The implementation was visually checked in a native 256×224 bsnes-jg capture; the HTML mockup
remains the checked-in design reference for pixel inspection.

## Verification

### Functional matrix

Test Left and Right during:

1. ROM decode;
2. VRAM upload;
3. initial view hold;
4. the first, middle, and last portions of recompression;
5. golden-stream comparison;
6. second decode;
7. byte verification;
8. result hold; and
9. automatic spinout.

For each case assert:

- requested slide appears;
- response is latched within one frame;
- no old work resumes afterward;
- canceled work does not alter its timing/result slot;
- no red failure state appears;
- the new slide starts with clean buffers/state; and
- arrows remain correctly positioned.

### Input sequences

- tap Right through all ten works and wrap 10→1;
- tap Left through all ten and wrap 1→10;
- hold each direction for at least two seconds (one move only);
- alternate Left/Right on consecutive frames;
- press both simultaneously;
- press during force blank;
- browse in a nonsequential order, then allow every work to finish and confirm the final oracle.

### Visual gates

- capture landscape, square, and portrait slides with both arrows;
- verify chevrons do not cover painted content more than their narrow edge footprint;
- verify OBJ remains visible on both sides of the HDMA split;
- verify no sprite garbage, stale OAM, palette collision, or wrap at x=255;
- verify arrows disappear during automatic spinout and return on the next slide; and
- repeat in bsnes-jg and MAME where available.

## Website changes

Update both gallery pages and emulator instructions:

- controls: `← previous artwork · → next artwork`;
- explain that browsing cancels the current measurement and restarts it on the selected work;
- keep the self-check frame budget large enough for an uninterrupted full corpus;
- replace the preview with one that visibly includes both chevrons; and
- update ROM hashes, checksums, offsets, manifests, and live verification.

## Definition of done

- Left/Right navigation wraps correctly across all ten works.
- A press cancels every codec/check/hold/transition stage with sub-frame bounded foreground latency.
- Canceled work never counts as pass, failure, or benchmark data.
- Two sprite chevrons clearly communicate navigation without stealing BG or Mode 7 tile capacity.
- Full-image aspect ratios and #122 maximum-resolution frames remain unchanged.
- An uninterrupted ten-work pass still produces the exact documented host/target oracle.
- Both websites document the controls and serve the exact verified interactive ROM.
