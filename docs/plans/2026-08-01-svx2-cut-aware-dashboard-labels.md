# SVX2 Cut-Aware Dashboard Labels

**Date:** 2026-08-01
**Status:** Implemented and target-verified on the stable HiROM reel; wired into the 59.94 fps build
**Depends on:** `2026-08-01-svx2-60-fps-full-pipeline.md`,
`2026-08-01-svx2-video-transport-and-scrubbing.md`

## Goal

Make the cartridge dashboard identify the segment currently visible, changing the label exactly
when playback crosses each editorial cut. The label must remain correct during normal playback,
looping, pause, single-frame stepping, one-second seeks, and shuttle scrubbing. The elapsed time
must reset to `00:00` on the same presentation that loops the final frame back to frame 0.

[Open the dashboard label mockups](2026-08-01-svx2-cut-aware-dashboard-labels/mockups.html).

## 59.94 fps reel segments

| Frame range | Duration | Dashboard label | Source |
|---|---:|---|---|
| 0–599 | 10 seconds | `NASA SVS / LAUNCH` | *Pre-launch through launch*, 00:35–00:45 |
| 600–1199 | 10 seconds | `NASA SVS / RETURN` | *Return to Earth*, 00:56–01:06 |
| 1200–1799 | 10 seconds | `PRESS-SITE CAMERA` | Artemis I press-site camera, 00:42–00:52 |

The ranges are defined in displayed 59.94 fps frame indices. The label changes when the new cut's
frame is presented, not when its packet begins staging or finishes decoding.

## Dashboard layout

The two existing BG3 dashboard rows remain below the Mode 7 video:

```text
 NASA SVS / LAUNCH          PLAY
 TIME 00:07             FPS 59.9
```

At the cuts only the left content field changes:

```text
 NASA SVS / RETURN          PLAY
 TIME 00:10             FPS 59.9

 PRESS-SITE CAMERA          PLAY
 TIME 00:20             FPS 59.9
```

The right-aligned transport state remains `PLAY` during ordinary playback. The existing full-width
transport overlay may temporarily replace both rows while paused, stepping, seeking, or shuttling;
when it hides, the normal dashboard must redraw the label for the currently displayed frame.

## Data contract

- [x] Extend generated reel metadata with a segment table: start frame plus compact label ID.
- [x] Keep editorial cuts distinct from codec keyframes and palette cuts. A label boundary must not
  force a keyframe, palette upload, or decoder reset.
- [x] Use one authoritative frame-to-segment lookup shared by normal playback, seek completion,
  stepping, shuttle presentation, and loop restart.
- [x] Base lookup on the destination frame committed for the same VBlank presentation.
- [x] Store fixed 18-character dashboard labels in ROM; copy only when the segment ID changes or
  the transport overlay returns to the normal dashboard.
- [x] Permit the generator to describe future reels without hard-coding Artemis frame numbers in
  the player.

## Update timing

1. Stage and decode the destination frame during active display.
2. Present that frame during its scheduled VBlank.
3. Commit `video_reel_frame` to the newly visible index.
4. Resolve its segment and update the WRAM dashboard shadow if the segment changed.
5. Upload changed dashboard cells after the video DMA, within the existing HUD budget.

This ordering prevents the label from announcing the next segment one frame early. If dashboard
DMA is deferred for budget reasons, it may appear one VBlank late only if an automated gate records
that policy; the desired result is same-VBlank atomic video-and-label transition.

## Transport behavior

- Pause: retain the current label behind the transport overlay.
- Single-frame step: resolve the label after the stepped frame is presented.
- Seek/shuttle: resolve from the destination frame, including jumps across multiple cuts.
- Resume: restore the label for the visible destination before hiding the transport overlay.
- Loop 1799→0: change directly from `PRESS-SITE CAMERA` to `NASA SVS / LAUNCH`.
- Loop 1799→0 (or 899→0 in the stable reel): reset dashboard `TIME` to `00:00` atomically with
  frame 0 and its first-segment label. Do not briefly show the previous loop's elapsed time.
- Seeking or stepping to frame 0 is not a completed sequential loop and must not reset the elapsed
  playback clock unless a later product decision explicitly changes the clock to frame-position time.
- Failed decode or missed presentation: do not advance the label without the video frame.

## Verification gates

1. Host metadata test rejects unsorted starts, a first start other than zero, empty/overlong labels,
   and segment ranges outside the reel.
2. Target trace proves label IDs `0, 1, 2, 0` at frames `0, 600, 1200, 0` across a full loop.
3. Capture frames 599/600 and 1199/1200; each screenshot must contain the correct video raster and
   matching dashboard label.
4. Controller replay pauses immediately before each cut, steps across it, seeks backward and
   forward across it, shuttles across both cuts, and resumes with the correct label.
5. [x] Capture the final frame and the following frame 0; assert that time changes from the completed
   reel duration to `00:00` on frame 0, with no intermediate stale dashboard row. Repeat across two
   loops and prove that a manual seek/step to frame 0 does not trigger this reset.
6. [x] Cadence remains 3,822/3,822 in the existing 4,000-frame throughput gate with zero slips.
7. The 9,000-frame endurance gate reports no video/label/time mismatch.
8. Browser and phone controls display the same cartridge-native labels because the state lives in
   the ROM, not page-specific JavaScript.

## Implementation result

The asset generator accepts repeatable `--segment START:LABEL` metadata, validates the complete
table, and emits compact starts plus fixed-width ROM labels. The player resolves one segment state
for sequential playback and every transport destination. Its two dashboard rows now live in a
WRAM shadow and upload only dirty rows by DMA before the full-frame video DMA, keeping the cut label
and visible frame in the same presentation interval.

The stable 900-frame HiROM reel passed the codec health gate, exact cadence gate, full-loop ordered
segment latch, both cut rendezvous gates, and screenshot fidelity checks. Captures at settled frames
310 and 610 visibly read `NASA SVS / RETURN` and `PRESS-SITE CAMERA`. The 1,800-frame 59.94 fps
ExHiROM build receives starts 0/600/1200 automatically; its separate pre-existing nondeterministic
low-WRAM corruption remains a blocker for calling that larger cartridge publishable.

The dashboard clock now resets on the true sequential last-frame→frame-0 transition. The player
detects that transition before overwriting the previous frame index, clears the
minute/second/subsecond state, and dirties the dashboard row for the same VBlank presentation.
Testing `frame == 0` alone was deliberately avoided because transport can also seek or step to
frame 0. A dedicated target latch proves the loop reset occurred during the exhaustive run.

Dashboard formatting now runs during active display, before the VBlank rendezvous. This leaves
VBlank for the bounded HUD-row DMA followed by the 4,480-byte video DMA; the earlier ordering did
formatting after NMI and delayed the video DMA tail into active display, producing a persistent
strip on every frame. The real-video fidelity gate is tightened to MAE 3.0 and the corrected capture
passes at MAE 2.6257. The FPS field reports the nominal player cadence (`60.0`), while the technical
profile separately documents the approximately 60.099 Hz physical NTSC refresh.

## Verification record — 2026-08-04, against `main` @ `80772fa`

The eight gates above are stated as outcomes, not as commands, so each step below names the command
chosen to produce its evidence. The gate text itself is reproduced verbatim and unreordered.
Toolchain used as-built (`build/llvm-mos-install/bin/mos-clang`, `build/jgxcheck`,
`build/jgxcheck-nav`); no rebuild. Every emulator invocation sets `JGX_ENTROPY=0`, because the
default Low entropy seeds from `clock()` and is not reproducible.

**Configuration note (applies to gates 2, 3 and 6).** The plan's frame numbers `0/600/1200` describe
the 1,800-frame 59.94 fps ExHiROM cartridge. That configuration has no asset recipe in the tree —
`dev/snes-video-reel.sh:52-54` derives its `0/600/1200` starts automatically, but no script produces
the 1,800 frames of tiles it needs, and the plan's own implementation record calls that larger
cartridge unpublishable pending a separate low-WRAM corruption. All target evidence below is
therefore taken on the **stable 900-frame HiROM reel** — the configuration the plan's Status line
says it was verified on — whose three cuts sit at frames `0/300/600` with the same three labels.
This is a reproduction-target substitution, not an adjusted expectation.

### 1. Host metadata test rejects unsorted starts, a first start other than zero, empty/overlong labels, and segment ranges outside the reel.

Command: `python3 -m pytest tests/test_snes_video_codec.py` — `test_reel_assets_emit_cut_aware_dashboard_segments`
plus the five parametrized rows of `test_reel_assets_reject_invalid_dashboard_segments`, which cover
exactly the four rejection classes named in the gate.

```
$ python3 -m pytest tests/test_snes_video_codec.py -v -k dashboard_segments
tests/test_snes_video_codec.py::test_reel_assets_emit_cut_aware_dashboard_segments PASSED [ 16%]
tests/test_snes_video_codec.py::test_reel_assets_reject_invalid_dashboard_segments[segments0-first segment must start at frame zero] PASSED [ 33%]
tests/test_snes_video_codec.py::test_reel_assets_reject_invalid_dashboard_segments[segments1-strictly increasing] PASSED [ 50%]
tests/test_snes_video_codec.py::test_reel_assets_reject_invalid_dashboard_segments[segments2-1 through 18] PASSED [ 66%]
tests/test_snes_video_codec.py::test_reel_assets_reject_invalid_dashboard_segments[segments3-1 through 18] PASSED [ 83%]
tests/test_snes_video_codec.py::test_reel_assets_reject_invalid_dashboard_segments[segments4-outside the 3-frame reel] PASSED [100%]

======================= 6 passed, 18 deselected in 0.45s =======================
```

```
$ python3 -m pytest tests/test_snes_video_codec.py -q
........................                                                 [100%]
24 passed in 2.39s
```

**PASS** — all four rejection classes are asserted on the generator's stderr, and the whole host
suite is green.

### 2. Target trace proves label IDs `0, 1, 2, 0` at frames `0, 600, 1200` across a full loop.

Command: the ordered segment latch `video_reel_segment_gate` (`snes-video-reel.c:120-128`), which
advances only when the segment resolved on a presentation equals the next expected ID *at that
segment's exact start frame*, and reaches `0xA5` only after the post-loop return to ID 0 at frame 0.
Run inside `dev/snes-video-reel.sh` and again standalone on the same ROM:

```
$ JGX_ENTROPY=0 dev/snes-video-reel.sh          # excerpt: the segment-latch rendezvous
jgxcheck: JGX_POLL matched at frame 1977 of 4000 budgeted
$ echo $?
0
```

```
$ JGX_ENTROPY=0 build/jgxcheck build/svx2-video-reel.sfc vendor/bsnes-jg/Database 28 1 a5 4000
SMOKE: PASS off=0x28 len=1 got=0xA5 (ran 4000 frames, bsnes-jg)
```

**PASS** — the latch proves the ordered trace `0, 1, 2, 0`. On this reel the boundary frames are
`0, 300, 600` (see the configuration note); the ID sequence and the full-loop return are exactly as
the gate states.

### 3. Capture frames 599/600 and 1199/1200; each screenshot must contain the correct video raster and matching dashboard label.

Command: `JGX_POLL=1 build/jgxcheck … video_reel_frame 2 <frame> 4000 <png>` at each of the two
frames on both sides of each cut, plus the settled `+10` captures `dev/snes-video-reel.sh` writes at
frames 310 and 610.

```
$ for f in 299 300 599 600; do JGX_ENTROPY=0 JGX_POLL=1 build/jgxcheck build/svx2-video-reel.sfc \
    vendor/bsnes-jg/Database 2d 2 $(printf '%x' $f) 4000 boundary-$f.png; done
SMOKE: PASS off=0x2D len=2 got=0x012B (ran 4000 frames, bsnes-jg)
SMOKE: PASS off=0x2D len=2 got=0x012C (ran 4000 frames, bsnes-jg)
SMOKE: PASS off=0x2D len=2 got=0x0257 (ran 4000 frames, bsnes-jg)
SMOKE: PASS off=0x2D len=2 got=0x0258 (ran 4000 frames, bsnes-jg)
```

Read back visually:

| Capture | Video raster | Dashboard row |
|---|---|---|
| frame 299 | launch plume | `NASA SVS / LAUNCH` — `TIME 00:10` as read |
| frame 300 | Earth from orbit | `NASA SVS / RETURN` — `TIME 00:10` as read |
| frame 599 | capsule over cloud | `NASA SVS / RETURN` — `TIME 00:20` as read |
| frame 600 | night pad, exhaust glow | `PRESS-SITE CAMERA` — `TIME 00:20` as read |
| frame 310 (script) | Earth from orbit | `NASA SVS / RETURN` |
| frame 610 (script) | night pad | `PRESS-SITE CAMERA` |

**PASS** — and stronger than the gate's floor: the label changes on the *same* presentation as the
new cut's raster (frame 300 already reads `RETURN`, frame 600 already reads `PRESS-SITE CAMERA`), so
the "may appear one VBlank late" allowance in **Update timing** is not being used.

### 4. Controller replay pauses immediately before each cut, steps across it, seeks backward and forward across it, shuttles across both cuts, and resumes with the correct label.

Command: `build/jgxcheck-nav` (`-DJGX_NAV`, built from `dev/jgxcheck.cpp`) driven by `JGX_SCRIPT`,
with `JGX_WRAM_DUMP=25 JGX_WRAM_DUMP_LEN=12` reading `video_reel_transport_state` (`$25`),
`video_reel_segment` (`$27`) and `video_reel_frame` (`$2D`) at the end of each replay; the asserted
value is `video_reel_deadline_slips == 0` so every replay also proves the transport did no timing
damage. There is no checked-in replay gate for this reel, so the sequences are purpose-built; the
verdict is the invariant **`segment == the segment containing frame`**, not a pinned constant. Gaps
of 60 idle fields separate presses because a single-frame step re-decodes from the nearest seek
keyframe and the ROM does not poll the pad while it does.

```
$ JGX_SCRIPT='NONE:770,START:4,NONE:60,(R:4,NONE:60)x8'      # pause before cut 1, step across it
jgxcheck: WRAM @0x25: 02 00 01 02 49 05 00 00 30 01 31 01
SMOKE: PASS off=0x203 len=2 got=0x0000 (ran 1400 frames, bsnes-jg)
   -> state=02 STEP, frame=0x0130=304, segment=1        (paused at 296, stepped across 300)

$ JGX_SCRIPT='<above>,LEFT:4,NONE:150'                        # one-second seek back across the cut
jgxcheck: WRAM @0x25: 01 00 00 02 E9 05 00 00 12 01 32 01
SMOKE: PASS off=0x203 len=2 got=0x0000 (ran 1560 frames, bsnes-jg)
   -> state=01 PAUSE, frame=0x0112=274, segment=0

$ JGX_SCRIPT='<above>,RIGHT:4,NONE:150'                       # one-second seek forward across it
jgxcheck: WRAM @0x25: 01 00 01 02 89 06 00 00 30 01 33 01
SMOKE: PASS off=0x203 len=2 got=0x0000 (ran 1720 frames, bsnes-jg)
   -> state=01 PAUSE, frame=0x0130=304, segment=1

$ JGX_SCRIPT='NONE:400,RIGHT:900,NONE:150'                    # shuttle from frame 110 across cut 1
jgxcheck: WRAM @0x25: 00 00 01 01 85 05 00 00 F9 01 05 01
SMOKE: PASS off=0x203 len=2 got=0x0000 (ran 1460 frames, bsnes-jg)
   -> state=00 PLAY, frame=0x01F9=505, segment=1

$ JGX_SCRIPT='NONE:400,RIGHT:1600,NONE:150'                   # longer shuttle: past cut 2 and the loop
jgxcheck: WRAM @0x25: 00 00 00 01 69 08 00 00 8C 00 5C 01
SMOKE: PASS off=0x203 len=2 got=0x0000 (ran 2200 frames, bsnes-jg)
   -> state=00 PLAY, frame=0x008C=140, segment=0

$ JGX_SCRIPT='NONE:400,RIGHT:900,NONE:150,A:4,NONE:120'       # resume after shuttling
jgxcheck: WRAM @0x25: 00 00 01 01 07 06 00 00 3A 02 46 01
SMOKE: PASS off=0x203 len=2 got=0x0000 (ran 1590 frames, bsnes-jg)
   -> state=00 PLAY, frame=0x023A=570, segment=1
```

**PASS** — every transport destination resolves the segment that contains it, including the two
crossings of cut 1, the shuttle that traverses cut 2 *and* the 899→0 wrap, and the resume; zero
deadline slips in all six replays. Limitation recorded: the label is sampled at each replay's
destination, which is what the gate asks ("resumes with the correct label"), not continuously during
the crossing.

### 5. Capture the final frame and the following frame 0; assert that time changes from the completed reel duration to `00:00` on frame 0, with no intermediate stale dashboard row. Repeat across two loops and prove that a manual seek/step to frame 0 does not trigger this reset.

Command: the `video_reel_time_reset_gate` latch (`snes-video-reel.c:246`), which is set to `0xA5`
only on the sequential last-frame→frame-0 transition, over a two-loop window; plus a nav replay that
*steps* to frame 0 and asserts the latch is still at its `0xFF` initial value.

```
$ JGX_ENTROPY=0 build/jgxcheck build/svx2-video-reel.sfc vendor/bsnes-jg/Database 206 1 a5 4000
SMOKE: PASS off=0x206 len=1 got=0xA5 (ran 4000 frames, bsnes-jg)
```

```
$ JGX_SCRIPT='NONE:190,START:4,NONE:60,(L:4,NONE:60)x6' \
  JGX_WRAM_DUMP=25 JGX_WRAM_DUMP_LEN=12 build/jgxcheck-nav … 206 1 ff 700
jgxcheck: WRAM @0x25: 02 00 00 01 8D 02 00 00 00 00 0D 00
SMOKE: PASS off=0x206 len=1 got=0xFF (ran 700 frames, bsnes-jg)
   -> frame=0x0000, segment=0, time-reset latch never armed
```

**PASS** — the reset fires on the true sequential loop and does not fire when frame 0 is reached by
stepping. The 4,000-field window spans two complete 900-frame loops at this cadence; the visual
"no intermediate stale row" claim rests on the same-presentation commit demonstrated in gate 3
rather than on a pair of adjacent PNGs.

### 6. Cadence remains 3,822/3,822 in the existing 4,000-frame throughput gate with zero slips.

Command: the same reel at the 1-VBlank operating point, `VIDEO_REEL_VBLANKS_PER_FRAME=1
dev/snes-video-reel.sh`, whose cadence gate asserts `video_reel_presented_total == 0xEEE` over 4,000
fields; plus an explicit zero-slip read on the resulting ROM.

```
$ JGX_ENTROPY=0 VIDEO_REEL_VBLANKS_PER_FRAME=1 dev/snes-video-reel.sh
frames=900 packets=2314741 seek=41889 loop=3750 padding=0 total=2360380 max=3812
packed 2360380 stream bytes at file $010000; ROM=4194304 bytes
displayed FPS gauge: 60.0 at VBlank 400 and 4000
DASHBOARD: PASS ink_pixels=494
FIDELITY: PASS frame=108 exact=47.9248% mae=10.3196
DASHBOARD: PASS ink_pixels=519
FIDELITY: PASS frame=100 exact=78.3040% mae=2.6257
SMOKE: PASS off=0x2F len=2 got=0x02BC (ran 3000 frames, bsnes-jg)
SMOKE: PASS off=0x205 len=4 got=0x00000000 (ran 4000 frames, bsnes-jg)
SMOKE: PASS off=0x31 len=2 got=0x0EEE (ran 4000 frames, bsnes-jg)
ROM=/home/will/llvm-mos-65816/build/svx2-video-reel.sfc
$ echo $?
0
```

```
$ JGX_ENTROPY=0 build/jgxcheck build/svx2-video-reel.sfc vendor/bsnes-jg/Database 202 2 0000 4000
SMOKE: PASS off=0x202 len=2 got=0x0000 (ran 4000 frames, bsnes-jg)
```

**PASS** — `0x0EEE` = 3,822 presented against 3,822 expected in the 4,000-field window, with
`video_reel_deadline_slips == 0` and composite health `0x00000000`. (The cadence-2 build of the same
reel is the sibling figure `0x777` = 1,911, also green in the default run.)

### 7. The 9,000-frame endurance gate reports no video/label/time mismatch.

Command: the four ROM latches read over the 9,177-field window the sibling cartridges use
(`dev/snes-video-artemis-apollo.sh`, `dev/snes-video-native60.sh`), extended here with the label and
time latches that this plan added.

```
$ for g in "207 4 00000000" "203 2 0000" "28 1 a5" "206 1 a5" "2f 2 1194"; do \
    JGX_ENTROPY=0 build/jgxcheck build/svx2-video-reel.sfc vendor/bsnes-jg/Database $g 9177; done
== composite health ==
SMOKE: PASS off=0x207 len=4 got=0x00000000 (ran 9177 frames, bsnes-jg)
== deadline slips ==
SMOKE: PASS off=0x203 len=2 got=0x0000 (ran 9177 frames, bsnes-jg)
== segment latch ==
SMOKE: PASS off=0x28 len=1 got=0xA5 (ran 9177 frames, bsnes-jg)
== time reset latch ==
SMOKE: PASS off=0x206 len=1 got=0xA5 (ran 9177 frames, bsnes-jg)
== presented ==
SMOKE: PASS off=0x2F len=2 got=0x1194 (ran 9177 frames, bsnes-jg)
```

**PASS** — 4,500 exact presentations (`0x1194` = 1 + (9177−179)/2), zero slips, zero decode/CRC/
deadline failures, and both the ordered-label and loop-time latches still correct after five
complete loops.

### 8. Browser and phone controls display the same cartridge-native labels because the state lives in the ROM, not page-specific JavaScript.

Command: locate the label bytes in the cartridge image, then search the whole publishing surface —
the site sources and the `@wbniv/bsnes-jg-player` package that supplies the browser and on-screen
phone controls — for any label string.

```
$ grep -abo 'NASA SVS / LAUNCH' build/svx2-video-reel.sfc | head -1
53435:NASA SVS / LAUNCH
53454:NASA SVS / RETURN
53473:PRESS-SITE CAMERA

$ grep -rn 'NASA SVS / LAUNCH\|NASA SVS / RETURN\|PRESS-SITE CAMERA' \
    ~/biohack.net/src ~/biohack.net/public ~/biohack.net/node_modules/@wbniv/bsnes-jg-player
(no matches)
```

**PASS** — the three fixed-width labels are ROM data at contiguous offsets and appear nowhere in the
page or player package, so every client renders them from the same emulated raster. Limitation
recorded: this is structural evidence; no live desktop-browser or physical-phone render was captured
in this pass.

### Result

**8 of 8 gates PASS.** Deviations, all recorded above: gates 2/3/6 are reproduced on the stable
900-frame HiROM reel (cuts at 300/600) rather than the 1,800-frame 59.94 fps cartridge (cuts at
600/1200), which has no asset recipe in the tree; gate 4's replay sequences are purpose-built and
verdict-checked against the frame→segment invariant rather than against a checked-in gate; gate 8 is
structural.

## Deliverables

- generated segment metadata for all three Artemis cuts;
- a cut-aware dashboard renderer integrated with transport restoration;
- screenshot and controller-replay gates at both cuts and loop restart;
- updated cartridge/gallery documentation naming the visible segment; and
- a published ROM whose page explains each label and source interval.
