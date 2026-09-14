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

## Verification record — 2026‑09‑14: `dev/svx2-emulator-validation.sh` reshaped (`wt/svx2-anchors`)

**Why the gate changed.** The script compared the whole rebuilt 8 MiB image byte-for-byte to the published
`c3d7cd9e…`. That comparison includes compiler output, so it can only pass on the exact toolchain that built
`v1.0.360`; today's `main` (`clang-23` built 2026‑08‑05, six `patches/llvm-mos/` commits since 2026‑08‑03)
fails it while every functional gate passes. The reshaped gate follows the policy set by the Mode 7 gallery
reconciliation ([`2026-09-14-m7-gallery-web-reconcile.md`](2026-09-14-m7-gallery-web-reconcile.md), decision
row 2): *the gate compares against the last publication record; a rebuild that differs is scored by why —
demo-source drift → republish, toolchain-only drift → accepted divergence.* Three checks now, none of them a
whole-ROM `cmp`:

1. the deployed ROM matches the SHA-256 in **Published result** above;
2. **asset contract** — the rebuild's packed stream regions (file `$010000–$3FFFFF` and `$410000–`) are
   byte-identical to the deployed ROM;
3. **code contract** — the rebuild passes every functional gate of `dev/snes-video-artemis-apollo.sh`
   (`0x0B06` presentations in 3,000, seam offsets, transport replays, `0x2327` in 9,177 with zero slips,
   composite health zero).

The rebuilt whole-ROM SHA-256 is still printed. When it differs from the record the script classifies the
code-window divergence: it asks the preprocessor (`-MM`) for the ROM's tracked compile inputs and runs
`git log f61472a..HEAD -- <inputs>`; no commits → `ACCEPTED DIVERGENCE (toolchain drift)`, otherwise
`DIVERGENCE (demo-source drift)` naming the commits, with the policy's action (a user-triggered republish)
stated. Both exit 0 — the pass/fail of the gate is checks 1–3, as in the reconciliation's row 2, where the
republish is a separate staged step.

**Decomposition measured before reshaping** (publication commit's sources rebuilt with today's toolchain,
same header + stream; scratch A/B, not a tracked script):

```
S0 (f61472a sources, today's toolchain): ecfa53f8f4943cc4
S1 (HEAD sources,    today's toolchain): 17c2cf03e630ddf5
P  (published v1.0.360):                 c3d7cd9e76d840f7
S0 vs P : code=19712 streamA=0 mirror=19716 streamB=0
S0 vs S1: code=17183 streamA=0 mirror=17187 streamB=0
S1 vs P : code=18797 streamA=0 mirror=18801 streamB=0
```

`S0 ≠ P` → toolchain drift is real. `S0 ≠ S1` → source drift is also real: of the commits after `f61472a`,
`8eca83a` (shared FPS gauge; `snes-video-reel.c`, `video_fps.h`) and `ff35036` (Mode 7 splash contract) touch
this ROM's actual compile inputs; `304f3c3` and the `snesgfx` first-frame commits do not; `09fb433` touches
`snes-video-reel.c` but is byte-neutral for this build (A/B identical `17c2cf03…`). So on 2026‑09‑14 the
divergence is **mixed**, and the policy row's (a) applies: the published ROM predates two source changes to
its player. Neither is a behavioural change on this reel by the gates' own measure (t0 = 178 unchanged, gauge
60.0, all cadence/seam/transport gates green), but the record is stale until a republish refreshes it — that
republish is user-triggered and was not done here.

**Raw output, 2026‑09‑14 run** (`wt/svx2-anchors`, toolchain as-built, no rebuild):

```
$ dev/svx2-emulator-validation.sh
/tmp/svx2-emulator-validation/svx2-fastrom-video-v1.0.360-c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2.sfc.download: OK
1. deployed ROM == publication record (v1.0.360, c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2): PASS
==> 1,200-frame mixed reel: Artemis source frames at 2x, Apollo source frames at 59.94p
==> shared 222-colour content palette; entries 0/1 reserved for HUD
  PASS: 1200 quantized frames; 1200 unique; adjacent holds=[]
frames=1200 packets=3232607 seek=58207 loop=3757 padding=2507872 total=3294571 max=3852
mirrored FastROM code at file $000000-$00FFFF; packed 5802443 stream bytes at $010000-$3FFFFF then $410000; ROM=8388608 bytes
displayed FPS gauge: 60.0 at VBlank 400 and 3000
DASHBOARD: PASS ink_pixels=453
FIDELITY: PASS frame=115 exact=49.4751% mae=10.8723
SMOKE: PASS off=0x206 len=4 got=0x00000000 (ran 3000 frames, bsnes-jg)
SMOKE: PASS off=0x30 len=2 got=0x0B06 (ran 3000 frames, bsnes-jg)
ROM=/home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.sfc
  PASS: ExHiROM cut offsets 0x3ef147, 0x3f0000, 0x3f0f0c
==> exact ExHiROM cut frames
SMOKE: PASS off=0x2E len=2 got=0x0257 (ran 1600 frames, bsnes-jg)
DASHBOARD: PASS ink_pixels=459
FIDELITY: PASS frame=599 exact=41.3432% mae=19.5811
SMOKE: PASS off=0x2E len=2 got=0x0258 (ran 1600 frames, bsnes-jg)
DASHBOARD: PASS ink_pixels=450
FIDELITY: PASS frame=600 exact=60.2946% mae=8.8276
==> deterministic transport and bidirectional seam crossings
SMOKE: PASS off=0x204 len=1 got=0x04 (ran 376 frames, bsnes-jg)
SMOKE: PASS off=0x26 len=1 got=0x00 (ran 376 frames, bsnes-jg)
SMOKE: PASS off=0x2E len=2 got=0x027D (ran 775 frames, bsnes-jg)
SMOKE: PASS off=0x2E len=2 got=0x0239 (ran 825 frames, bsnes-jg)
==> 9,000 exact presentations after the 178-field title
SMOKE: PASS off=0x30 len=2 got=0x2327 (ran 9177 frames, bsnes-jg)
SMOKE: PASS off=0x202 len=2 got=0x0000 (ran 9177 frames, bsnes-jg)
SMOKE: PASS off=0x206 len=4 got=0x00000000 (ran 9177 frames, bsnes-jg)
ROM=/home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.sfc
3. functional gates (dev/snes-video-artemis-apollo.sh): PASS
2. asset contract: packed stream regions byte-identical to the deployed ROM: PASS
rebuilt ROM SHA-256: 17c2cf03e630ddf509dbdc56bd860b91853a1628ee9a712f202f65d769434cd1
DIVERGENCE (demo-source drift): published c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2 vs built 17c2cf03e630ddf509dbdc56bd860b91853a1628ee9a712f202f65d769434cd1; stream identical; code differs (18797 bytes in $000000-$00FFFF); commits after f61472a touching the compile inputs:
    09fb433 svx2: restore the LoROM fixture, retire stale plan anchors, measure t0 in the cadence gate
    ff35036 fix(321): Mode 7 splash handoff contract — post-title force-blank 720 -> 22 frames
    8eca83a refactor(snes): one shared FPS gauge, and gate the number it displays
RESULT: PASS — public v1.0.360 matches its publication record; rebuild passes every functional gate; policy row 2(a): the divergence is demo-source drift, whose action is a user-triggered republish (refresh the publication record when it lands)
exit=0
```

## Acceptance

The reel is accepted when it restores the launch/return spectacle, preserves genuine ~59.94 motion
where NASA provides it, labels intentional 2× material without ambiguity, and retains every source,
codec, ExHiROM seam, dashboard, transport, endurance, and live-publication gate. The XRISM reel is
then retained only in repository history, not as the public default.
