# SVX2 Artemis 2× + Apollo 59.94p ExHiROM reel

**Date:** 2026-08-02
**Status:** Complete
**Supersedes:** [SVX2 native-60-fps ExHiROM seam reel](2026-08-02-svx2-native-60fps-exhirom-seam-reel.md)

## Outcome

Replace the technically correct but visually weak XRISM reel with the stronger launch imagery the
cartridge previously showed:

1. NASA SVS Artemis I pre-launch through launch animation;
2. NASA SVS Artemis I return-to-Earth animation; and
3. NASA Apollo 11 daylight launch footage.

The two Artemis animations are authored at `30000/1001` progressive frames per second and play at
two source frames per SNES second-field pair: 300 source frames occupy five seconds each at the
cartridge's one-frame-per-VBlank cadence. The dashboard and web page must label these sections
plainly as `2X`; they are intentionally fast, not claimed as native 60p.

The Apollo source is NASA's ~59.94-fps `~large.mp4` derivative. Preserve all 600 temporal samples
from the selected ten-second interval and present them at one per VBlank. Do not derive this leg
from NASA's 15p mobile copy or discard alternating source frames.

## Sources and timeline

| Reel frames | Display duration | Source | Source interval | Dashboard |
|---:|---:|---|---:|---|
| 0–299 | 5 s | NASA SVS 14191 `Pre-launch_through_launch.webm`, 30000/1001p | 00:35–00:45 | `SVS LAUNCH / 2X` |
| 300–599 | 5 s | NASA SVS 14191 `Return_to_Earth.webm`, 30000/1001p | 00:56–01:06 | `SVS RETURN / 2X` |
| 600–1199 | 10 s | NASA Images Apollo 11 press-site `~large.mp4`, ~59.94p | 00:56:50–00:57:00 | `APOLLO 11 / 60P` |

Total: 1,200 displayed frames and 20 seconds per loop. The first two legs intentionally run at 2×
their authored motion; the third runs at its source temporal rate.

## Provenance

- Artemis animations: [NASA SVS item 14191](https://svs.gsfc.nasa.gov/14191/).
- Apollo footage: [NASA Images item KSC-19690716-MH-NAS01-0001-Apollo_11_Launch_President_Johnson_Jack_King_Narration_Press_Site-B_1372](https://images.nasa.gov/details/KSC-19690716-MH-NAS01-0001-Apollo_11_Launch_President_Johnson_Jack_King_Narration_Press_Site-B_1372).
- Record the exact source and extracted-clip SHA-256 values beside the vendored assets.
- Discard audio. The selected picture interval contains the vehicle, exhaust, smoke, sky, and
  horizon and excludes the earlier burned-in countdown/camera overlay.

## Reproducible conversion

- [x] Verify both Artemis masters and their recorded SHA-256 values.
- [x] Verify Artemis is progressive `30000/1001`, never describe it as native 60p.
- [x] Verify the Apollo large master is approximately `60000/1001` progressive with 600 distinct
  temporal samples in the ten-second extraction.
- [x] Vendor the three compact source excerpts, not the 2.20-GiB hour-long Apollo master.
- [x] Scale each selected source frame directly to 80×45 with Lanczos, pad to 80×56, and concatenate
  in timeline order without optical-flow interpolation.
- [x] Learn one deterministic 222-colour content palette over all 1,200 frames; reserve entries
  0/1 for dashboard black/white.
- [x] Require zero unintended adjacent duplicates after quantization. Any legitimate source hold
  must be identified and documented rather than silently accepted.
- [x] Encode SVX2 with 60-frame seek keyframes and a delta-coded loop.

## ExHiROM stress layout

Retain the 64-Mbit (8-MiB) Fast ExHiROM cartridge even if the compressed stream would fit in a
smaller image. Keep bank `$C0` as the FastROM code mirror and place frame 600—the cut from 2×
animation to native-59.94 Apollo—exactly at logical stream offset `$3F0000`. Thus ordinary playback,
forward seek, and reverse seek all exercise the region-A/file-`$410000` seam on a meaningful cut.

- [x] Assert frame 599 starts below `$3F0000`, frame 600 starts exactly at `$3F0000`, and frame 601
  starts above it.
- [x] Host-decode and target-capture frames 599 and 600 byte/pixel correctly.
- [x] Replay transport in both directions across the seam with zero deadline damage.

## Player and dashboard

- [x] Generate the three segment labels above and change them atomically with their cut frames.
- [x] Dashboard duration is `00:20.0`; loop time resets to `00:00.0` on frame 0.
- [x] Dashboard cadence remains nominal `FPS 60.0` because one packet is presented each VBlank.
- [x] One-second seek advances 60 displayed frames in every segment. This is display-time seeking;
  it deliberately advances two seconds of authored Artemis animation during either 2× leg.
- [x] Preserve pause/resume, single-frame step, and 2×/4×/8× shuttle behavior.

## Gates

- [x] Host round-trip every sequential packet, seek keyframe, and loop delta.
- [x] Verify exact source indices, frame count, cut table, palette reservation, and stream extents.
- [x] Inspect ExHiROM map mode `$35`, 64-Mbit size byte, reset vector, checksum, and complement.
- [x] Pass two full loops with composite health zero.
- [x] Present exactly 9,000 eligible frames with zero deadline slips or decode errors.
- [x] Pass dashboard and fidelity checks in all three sections and on both seam-adjacent frames.
- [x] Pass scripted pause, step, resume, ±1-second seek, shuttle, and bidirectional seam crossings.
- [x] Build the website, replay its manifest self-check, and pass blank-scan.

## Publication

- [x] Replace the public XRISM ROM and page—not merely add another hidden artifact.
- [x] State the mixed cadence honestly: two 29.97p animations at 2×, one Apollo segment at ~59.94p.
- [x] Describe the cartridge as 64 Mbit (8 MiB) Fast ExHiROM, 1,200 frames, 20 seconds.
- [x] Publish only the exact gated ROM and verify the downloaded live SHA-256.
- [x] Record toolchain commit, site commit, release tag, checksum, and live verification here.

## Published result

- Toolchain implementation: `f61472a`; blank-scan corpus-threshold follow-up: `3e8bcca`.
- Site commit: `2345332`; release: `v1.0.360`; deployment workflow `30761621847` passed.
- ROM SHA-256: `c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2`.
- The downloaded live ROM matched that hash, and the live page exposed the same hash plus the
  1,200-frame, 20-second mixed-cadence description.
- `pytest -q tests/test_snes_video_codec.py`: 24 passed. The site manifest replay passed 4,000
  frames, composite health zero, and blank-scan with the reel's five-row threshold. Four rows was
  a measured false positive caused by a stable four-row change in naturally black Artemis source
  imagery; the ordinary threshold remains unchanged for every other ROM.

## Acceptance

The reel is accepted when it restores the launch/return spectacle, preserves genuine ~59.94 motion
where NASA provides it, labels intentional 2× material without ambiguity, and retains every source,
codec, ExHiROM seam, dashboard, transport, endurance, and live-publication gate. The XRISM reel is
then retained only in repository history, not as the public default.
