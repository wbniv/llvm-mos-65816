# SVX2 Video Transport and Shuttle Scrubbing

**Date:** 2026-08-01
**Status:** Planned
**Depends on:** `2026-07-31-svx2-full-artemis-reel.md` and
`2026-07-31-svx2-cartridge-video-dashboard.md`

## Goal

Add responsive cartridge-native playback controls to the two-video SVX2 Artemis reel. The viewer
must be able to pause, resume, step by one frame, seek by one second, and shuttle in either
direction. Whenever playback is paused or a seek is active, the Mode 1 BG3 band below the Mode 7
video becomes a visible transport; normal playback returns to the compact time/FPS dashboard after
a short inactivity delay.

The current published ROM is self-running and has no joypad transport controls. Browser-level
emulator pause is not an adequate substitute because it cannot update cartridge UI, seek media, or
preserve an honest media-time/FPS state.

No *Duck and Cover* or animated turtle material is permitted. The stream remains SVX2, not LZSS.

## Interactive HTML mockups

[Open the interactive transport mockups](2026-08-01-svx2-video-transport-and-scrubbing/mockups.html).

The mockups show normal playback, paused transport, forward/reverse shuttle rates, single-frame
stepping, the frame-600 video boundary, and automatic return to the compact dashboard. The slider
models the transport playhead; the buttons model SNES controller input rather than adding a second
web-only control system.

## Controller contract

| Input | Action | Resulting state |
|---|---|---|
| `Start` | Toggle play/pause | Transport appears on pause; resume continues from the selected frame |
| D-pad `Left` / `Right` tap | Seek −/+ 30 frames (one second) | Preserve the state that existed before the tap |
| D-pad `Left` / `Right` hold | Reverse/forward shuttle | Accelerate through 2×, 4×, then 8×; transport stays visible |
| `L` / `R` | Step −/+ one frame | Enter or remain paused; show the exact selected frame |
| `A` | Resume from transport | Equivalent to Play; useful after stepping or shuttling |

Opposite directions pressed together cancel movement. Seek arithmetic wraps across the complete
900-frame reel, including frame 899→0 and frame 0→899. A controller edge accepted during the title
does not skip validation; input becomes active only after frame zero is presented.

## Browser, keyboard, and phone mapping

The cartridge actions above are the canonical contract. Every web control must inject the same
SNES joypad bits, so browser and phone behavior is exercised by the ROM rather than reimplemented
in JavaScript.

| Action | SNES/gamepad | Desktop keyboard | Phone/tablet |
|---|---|---|---|
| Pause/resume | `Start` | `Enter` or visible Play/Pause button | Large center Play/Pause button |
| Resume after seek | `A` | `X` or visible Play button | Same center Play button |
| Step one frame | `L` / `R` | `Q` / `W` | Previous-frame / next-frame buttons |
| Seek one second | D-pad Left/Right tap | Left/Right arrow tap | Rewind/forward button tap |
| Shuttle | D-pad Left/Right hold | Hold Left/Right arrow | Press and hold rewind/forward |

The existing web player already maps arrows, `Enter`, `X`, `Q`, and `W` to those SNES buttons.
It does **not** currently provide a complete phone controller: its optional canvas touch navigation
supports only short Left/Right taps and forcibly releases them after 120 ms. Extend the shared
player with a ROM-opted transport dock rather than claiming that the current phone experience can
pause, frame-step, or hold a shuttle direction.

The dock sits below the canvas, remains reachable in portrait and landscape/fullscreen, and uses
five targets in this order:

```text
[ |< FRAME ] [ << SEEK/HOLD ] [ PLAY/PAUSE ] [ SEEK/HOLD >> ] [ FRAME >| ]
```

- A quick pointer press/release on `<<` or `>>` is a one-second tap.
- Keeping the pointer down preserves the joypad bit until `pointerup`, `pointercancel`, window blur,
  or page visibility loss; this is what makes 2×/4×/8× shuttle possible on a phone.
- Frame buttons inject `L`/`R`; Play/Pause injects `Start`. The dock label and `aria-pressed` state
  follow cartridge transport telemetry, not an optimistic local toggle.
- Buttons are at least 48 CSS pixels high, have visible focus, work with touch, mouse, keyboard,
  and assistive technology, and suppress browser text selection/scroll only while actively held.
- The cartridge BG3 transport is always the authoritative visible playhead. The web dock is an
  input surface, not a second timeline with potentially divergent time.
- A connected physical controller uses its standard SNES-equivalent buttons when gamepad support
  is added to the shared player; keyboard and touch remain available. Gamepad polling is therefore
  an explicit implementation item, not a claimed current feature.

## On-cartridge transport

The transport reuses the existing two-row, 32-column BG3 dashboard band. It does not cover or
modify source-video pixels.

Normal playback:

```text
 SVX2 VIDEO                 PLAY
 TIME 00:12            FPS 30.0
```

Paused or frame stepping:

```text
 PAUSE  <======|------------->
 00:12.4 / 00:30.0      F 0372
```

Shuttle:

```text
 REV 4X <===|---------------->
 00:08.1 / 00:30.0      F 0243
```

Use only glyphs already present in the cartridge font. The mockup's triangle icons are conceptual;
the ROM may use `PLAY`, `PAUSE`, `REV`, `FWD`, `<`, `>`, `=`, `-`, and `|` for exact pixel clarity.
The bar maps frames 0–899 to a fixed 20-character track. Timecode adds tenths while the transport
is visible so single-frame and shuttle movement are legible.

Show the transport immediately on any transport input. After resuming, retain it for 90 VBlanks
(about 1.5 seconds), then restore the normal dashboard. Keep it visible indefinitely while paused.
Errors and deadline slips override the right-hand state label but do not erase the playhead.

## Seek architecture

The existing delta stream has independent keyframes only at frames 0 and 600. Reverse seeking from
an arbitrary frame would otherwise require replaying as many as 599 deltas, which is not a
responsive transport.

Regenerate the shipping reel with a seek keyframe every 30 frames, while retaining mandatory
keyframes at frames 0 and 600. Emit a compact 30-entry seek table containing the nearest keyframe
packet index and packed-stream offset. A seek performs:

1. choose the keyframe at or before the destination;
2. stage and decode that keyframe into the framebuffer;
3. decode forward at most 29 delta frames;
4. present only the requested destination frame; and
5. reset the playback deadline from the VBlank on which that frame is presented.

The host generator must report the size cost versus the current 2,311,832-byte stream. The result
must remain within the existing 4 MiB Fast HiROM after code, tables, title, and dashboard data. If
one-second keyframes do not fit, measure two-second keyframes before considering a larger mapping;
do not silently degrade to an unbounded replay seek.

During held shuttle, advance a logical cursor every VBlank at the selected rate but cap preview
decodes to ten per second. Always decode and present the exact cursor destination on release. This
keeps the controller and transport responsive without pretending the 65816 can decode arbitrary
reverse deltas in real time.

## Playback and telemetry semantics

- `video_reel_frame` is the selected/presented media frame, including after reverse seeks.
- `video_reel_presented_total` remains a monotonic count of actual VRAM presentations. Seeking does
  not decrement it.
- Add a separate 32-bit `video_reel_media_ticks` field for the displayed media position; derive
  `MM:SS.t` from the selected frame at 30 fps rather than cumulative presentations.
- Paused time does not advance. A seek changes media time immediately after the destination frame
  is successfully presented.
- FPS sampling excludes intentional pause/seek intervals. While the transport is active, display
  `PAUSED`, `STEP`, or the shuttle rate rather than `0.0` or a stale `30.0`.
- Resume starts a fresh 60-VBlank FPS measurement window; show `FPS --` until it completes.
- Seeking is user intent, not a deadline slip. Decoder, DMA, CRC, or staging failures remain fatal
  and retain their existing diagnostic counters.

## State machine

```text
TITLE -> PLAYING <---- Start/A ----> PAUSED
            |                           |
       Left/Right                  L/R step
            v                           v
         SHUTTLE <---- release ---- PAUSED/PLAYING
```

The shuttle state records whether playback was running when the hold began. A tap preserves that
prior state. Releasing a held shuttle restores the prior state after landing on the exact frame;
single-frame shoulder steps intentionally remain paused.

## Implementation steps

- [ ] Add automatic joypad sampling and edge/hold/repeat state without changing NMI decode timing.
- [ ] Add the transport state machine as host-testable pure logic.
- [ ] Regenerate the reel with one-second seek keyframes and emit seek metadata.
- [ ] Implement bounded seek decode and exact frame landing across both reel boundaries.
- [ ] Add play, pause, step, one-second seek, and accelerated shuttle actions.
- [ ] Add the transient BG3 transport and tenths/frame formatting.
- [ ] Make dashboard FPS and time semantics honest across pause, seek, and resume.
- [ ] Add a manifest-opted web transport dock with correct tap-versus-hold pointer semantics,
  keyboard labels, responsive/fullscreen layout, and accessible state.
- [ ] Add standard Gamepad API mapping for D-pad, Start, A, L, and R, clearing held bits on
  disconnect or loss of focus.
- [ ] Extend scripted-input emulator support or add a deterministic target-side input script so
  controls are tested in the real ROM rather than only in host simulation.
- [ ] Update the gallery control legend and preview only after the ROM gates pass.
- [ ] Publish and verify the downloaded live artifact.

## Acceptance gates

1. `Start` pauses within one VBlank and freezes the selected video frame and media time.
2. `Start` or `A` resumes without skipping or duplicating the selected media frame.
3. `L` and `R` land exactly one frame backward/forward and remain paused.
4. D-pad taps land exactly 30 frames away and preserve the prior play/pause state.
5. Held D-pad directions visibly progress through 2×, 4×, and 8× shuttle states; release lands on
   the exact advertised frame.
6. Forward and reverse operations wrap correctly at frames 0, 599/600, and 899.
7. Every seek decodes one keyframe plus at most 29 deltas; a target counter proves the bound.
8. Transport text has intact top scanlines, fits the 32-column BG3 band, and never becomes a solid
   color bar.
9. Normal playback restores the compact dashboard after 90 VBlanks; paused transport never hides.
10. FPS shows state text during interaction, restarts its sample window on resume, and returns near
    `30.0` without counting the pause as poor performance.
11. The existing two-video fidelity, dashboard, blank-scan, decoder, two-loop, cadence, and zero-slip
    gates continue to pass when no controller input is supplied.
12. A full scripted controller trace produces the exact expected final frame, transport state,
    presentation count, and control-state CRC.
13. Desktop keyboard mappings (`Enter`, `X`, `Q`, `W`, and arrows) inject the same joypad bits as
    the visible controls; no browser shortcut fires while a mapped key controls the ROM.
14. Phone tap, long-hold, slide-off, cancellation, rotation, fullscreen, and background/resume tests
    cannot leave a joypad bit stuck, and all five controls retain at least 48-pixel targets.
15. Web transport labels and accessibility state follow target telemetry after reset, seek, and
    errors; JavaScript never claims `PLAY` before the cartridge does.

## Explicit exclusions

- No browser-only transport that leaves the cartridge unaware of playback state.
- No audio controls; the current reel has no audio stream.
- No free-running reverse delta decoder.
- No variable-speed normal playback or frame interpolation.
- No source-video pixels sacrificed for the transport.
- No LZSS video and no excluded footage.
