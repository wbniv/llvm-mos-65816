# SVX2 FastROM animated video — bsnes-jg validation

**Verdict:** `PASS`

**Execution date:** 2026-08-03

## Artifact identity

| Field | Value |
|---|---|
| Public URL | `https://biohack.net/play/roms/svx2-fastrom-video.sfc` |
| Release | `v1.0.360` |
| SHA-256 | `c3d7cd9e76d840f77d98aed96806ee2fb5268409a5ca6bcd81f9b1dc1bceefa2` |
| Size | 8,388,608 bytes (64 Mbit) |
| Mapping | Fast ExHiROM, map mode `$35` |

`dev/svx2-emulator-validation.sh` downloads and freezes the public file, runs the authoritative
build-and-emulator gate, then requires the rebuilt ROM to have the same hash and be byte-identical
to the download.

## Emulator method

The acceptance run used the repository's deterministic bsnes-jg harness through
`dev/snes-video-artemis-apollo.sh`. It rebuilt the 1,200-frame Artemis-at-2x plus Apollo-at-60p
reel from hash-pinned sources, generated the ExHiROM image, polled exact WRAM state, captured exact
frames, replayed controller input, and ran a 9,000-presentation soak after the 178-field title.

## Results

| Gate | Result |
|---|---|
| quantized source | PASS: 1,200 frames, 1,200 unique, zero adjacent holds |
| packed ROM | PASS: 8 MiB Fast ExHiROM |
| composite health at 3,000 fields | PASS: `0x00000000` |
| expected presentations at 3,000 fields | PASS: `0x0B06` |
| frame 599 packet offset | PASS: `$3EF147` |
| frame 600 packet offset | PASS: `$3F0000` |
| frame 601 packet offset | PASS: `$3F0F0C` |
| exact frame 599 rendezvous | PASS: dashboard and image fidelity |
| exact frame 600 rendezvous | PASS: dashboard and image fidelity |
| pause, step, resume | PASS: four deterministic seek decodes; final state PLAY |
| forward seam crossing | PASS: exact frame `$027D` |
| reverse seam crossing | PASS: exact frame `$0239` |
| 9,000-presentation soak | PASS: presented `0x2327`, deadline slips `0x0000` |
| soak composite health | PASS: `0x00000000` at 9,177 emulator fields |

The captured seam images are `build/svx2-mixed60-seam-frame599.png` and
`build/svx2-mixed60-seam-frame600.png`. The cut/dashboard captures are
`build/svx2-video-reel-cut-one.png`, `build/svx2-video-reel-cut-two.png`, and
`build/svx2-video-reel.png`.

## Interpretation

The presentation sequence advances exactly once per emulated NTSC field after the title, with no
deadline slip, duplicate source frame, composite-health failure, or damage at the `$3F0000`
ExHiROM seam. Controller replay proves pause/step/resume and both seam-crossing directions. Because
bsnes-jg supplies deterministic console fields directly, capture-device frame-rate drift is not
part of this measurement.

No physical-hardware claim is made or required by this emulator validation.
