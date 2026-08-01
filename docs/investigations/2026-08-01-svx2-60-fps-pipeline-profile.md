# SVX2 60 FPS Pipeline Profile

**Date:** 2026-08-01
**Result:** Full player sustains one sequential SVX2 packet per VBlank; true 60 fps source motion and endurance remain

## Scope

This investigation measured the complete 900-frame, two-video HiROM player rather than an isolated
codec fixture. The measured phases are FastROM-to-high-WRAM staging, staged SVX2 decode, and the
4,480-byte Mode 7 VRAM presentation DMA. Profiling is opt-in with `VIDEO_REEL_PROFILE=1`; the normal
ROM contains no PPU-counter instrumentation.

The target profiler records one three-byte record per reel frame. Each byte represents 1,024 PPU
dots, keeping the complete table within low-WRAM limits. `jgxcheck` can export an exact WRAM range
to a binary file, and `tools/snes-video-profile-report.py` produces the JSON summary.

## Baseline profile

Before decoder changes:

| Phase | p50 dots | p99 dots | Maximum dots |
|---|---:|---:|---:|
| Stage | 8,192 | 10,240 | 11,264 |
| Decode | 80,896 | 90,112 | 254,976 |
| Present | 10,240 | 10,240 | 10,240 |
| Combined | 99,328 | 108,544 | 275,456 |

One NTSC frame is 89,342 PPU dots. Median combined work was therefore 111% of one interval and p99
was 121%. Keyframes dominated the maximum. A changed-tile survey found a median of 66/70 changed
tiles, so sparse VRAM DMA alone could not recover the deficit.

## Decoder finding and correction

SVX2 copy spans mean “retain these bytes from the previous frame.” The reel intentionally decodes
with `previous == output`, but the staged assembly decoder still executed `MVN` for those spans,
copying framebuffer bytes onto themselves. The corrected path:

- checks whether the previous and output cursors are equal;
- advances both cursors without copying for an in-place copy span; and
- retains the original `MVN` behavior for callers using distinct buffers.

The first version advanced the saved token cursor rather than the live X cursor and corrupted WRAM
after a replacement span. The target profile gate caught the failure. Saving X, as the general path
does, corrected it. Keyframe literal spans staged in bank `$7F` now also use `MVN $7F->$00` rather
than a byte loop; the independently tested run-fill experiment was rejected after it failed the
target gate.

After the in-place delta correction:

| Phase | p50 dots | p99 dots | Maximum dots |
|---|---:|---:|---:|
| Stage | 8,192 | 10,240 | 11,264 |
| Decode | 64,512 | 69,632 | 254,976 |
| Present | 10,240 | 10,240 | 10,240 |
| Combined | 83,968 | 89,088 | 275,456 |

Median combined work fell by 15,360 dots (15.5%); p99 fell by 19,456 dots (17.9%). The p99 path
fits one interval, but with only about 0.3% instrumented margin. The normal build has more margin
because it omits profiler reads and arithmetic.

## Removing sequential keyframes

Independent keyframes are necessary for boot and seeking but not for continuous playback. They
were the remaining source of integrated 60 fps deadline slips. The packed stream now contains:

- frame 0 as the boot keyframe;
- ordinary deltas across the first-to-second-video cut;
- independent 30-frame seek keyframes in the random-access table; and
- a separate frame-899-to-frame-0 loop delta.

Seeking therefore remains independently decodable, while the hot sequential path never decodes a
keyframe. Palette switching at the video cut remains unchanged.

## Integrated result

Command:

```sh
VIDEO_REEL_VBLANKS_PER_FRAME=1 dev/snes-video-reel.sh
```

The normal 60 fps test ROM passed:

- composite health `$00000000`: zero result error, loop failure, and deadline slips;
- exactly `$0EEB` (3,819) presentations in the 3,819 eligible intervals of a 4,000-frame run;
- animation frame 108 dashboard/fidelity gate: 47.9248% exact, MAE 10.3196;
- second-video frame 100 dashboard/fidelity gate: 78.3040% exact, MAE 2.6257; and
- exact frame-700 transition rendezvous at emulator frame 882.

The build uses `FASTROM 60 TEST` on the title screen. The current masters contain 900 distinct
30 fps source frames; playing those packets every VBlank proves full-pipeline throughput but runs
their motion at twice the authored rate. It is not yet the plan's final 60 fps source-motion claim.

## Remaining acceptance work

- acquire or generate properly sourced 59.94/60 fps masters with genuinely distinct temporal
  samples;
- run the 9,000-frame zero-slip endurance gate;
- run controller replay for pause, step, seek, shuttle, and exact resume at cadence one; and
- publish only after the true-source artifact and live gallery copy pass the same gates.
