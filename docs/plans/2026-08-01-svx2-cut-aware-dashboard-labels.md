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

## Deliverables

- generated segment metadata for all three Artemis cuts;
- a cut-aware dashboard renderer integrated with transport restoration;
- screenshot and controller-replay gates at both cuts and loop restart;
- updated cartridge/gallery documentation naming the visible segment; and
- a published ROM whose page explains each label and source interval.
