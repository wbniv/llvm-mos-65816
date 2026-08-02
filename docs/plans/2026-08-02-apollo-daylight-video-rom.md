# Apollo 11 daylight launch — the hard-content video cartridge

**Date:** 2026-08-02 · **Status:** PLANNED
**Provenance:** the codec corpus already exists and is measured — see
[real-video-codec-benchmark.md §Hard-content stressor](2026-07-30-lzss-gallery-exhirom-video-boundary-test/real-video-codec-benchmark.md)
(2026-08-01). This plan turns that measurement into a running cartridge.

## Why this ROM

The published SVX2 reel plays **Artemis I**, a night launch: mostly-black frames whose sensor noise
an H.264 derivative had already smoothed. The Apollo 11 clip is the opposite and was chosen
deliberately as the codec's worst realistic case — 16 mm KSC tracking-camera film, daylight, heavy
grain, bright continuous exhaust against sky. Measured cost of that hardness: **+5.3 ratio points
under Floyd (57.0% → 62.3%), +19.8 under Bayer (33.5% → 53.3%)**.

So this is not a second copy of the reel with different pixels. It is the *hardest* input the
decoder will ever be handed, running at the cadence the 60 fps work established — the case where a
throughput regression shows up first. It also gives the battery a visually distinct piece: the
existing reel is a dark sky; this is smoke, flame and horizon.

## What exists already (do not rebuild)

| Artifact | Where | Note |
|---|---|---|
| RGB24 corpus, 300 frames | scratchpad `apollo-work/apollo-daylight.rgb` | SHA-256 `a78c4c8c…4080`, reproducible via `tools/snes-video-rgb24-convert.sh --start 3410 --duration 10 <master>.mp4` |
| Packed SVX2 + palette + tiles | same dir, `apollo-daylight-{floyd,bayer}.{svx2,pal,tiles,json}` | both dithers already packed and round-trip-verified |
| Decoder + fast kernels | `examples/snes/snes-video-codec.{c,h}`, `snes-video-codec-fast.s` | committed, clean; includes the staged-keyframe specialization (1.12 VBl) |
| Reel ROM as the shape to copy | `examples/snes/snes-video-reel.c` + `dev/snes-video-reel.sh` | committed and clean as of today; **copy the pattern, do not edit these files** |
| Ring refill + 60 fps evidence | [svx2-60fps-ring-refill plan](2026-08-01-svx2-60fps-ring-refill.md) | slow ROM clears 60 fps post-merge (674/600 hardest slice) |

The master `.mp4` is **not** committed (correctly — provenance is recorded, bytes are not). If it is
gone from the scratchpad, the conversion command above regenerates the corpus from the recorded
NASA item; do not substitute a different interval without recording new provenance.

## Deliverables

1. `examples/snes/apollo-reel.c` (name at implementer's discretion) — a video cartridge playing the
   300-frame Apollo interval through the existing SVX2 decoder, looping. Floyd is the shipping
   dither (quality-first default per the codec decision); Bayer stays a size datapoint, not a ship.
2. `tools/apollo-reel-assets.py` or an argument to the existing asset emitter — bake the packed
   stream + palette into a linkable asset header. Prefer extending the existing emitter over a fork.
3. `dev/apollo-reel.sh` — the gate, following `dev/snes-video-reel.sh`'s structure.
4. Publication to biohack.net under the existing video/rendering category (**not** Cartridge &
   Mapping Tests — that shelf is for mapper canaries; this is content).

## Gate (the house bar, plus what this ROM is *for*)

- Byte-correct decode: on-console frame checksum == the host encoder's, over the whole 300-frame
  loop — not just frame 0. The reel's whole-loop Fletcher check is the precedent.
- Cadence: report presented-frames-per-600-VBlanks for slow ROM **and** FastROM, the same metric
  the 60 fps work used, so this content is directly comparable to the Artemis numbers. **Record
  them even if they are worse** — that is the measurement this ROM exists to produce.
- `snes_ppu_reset_blank()` at boot; entropy fingerprint (one picture across None/Low/High × 2).
- `-verify-machineinstrs` clean; the wai idiom for any terminal halt.
- Negative control: flip one stream byte, the gate must fail (a checksum that cannot fail proves
  nothing — the reel's gate does this).

## Open questions for the implementer (report, do not guess)

1. **Capacity/mapping.** 300 frames of hard content at Floyd is larger than the Artemis reel's
   stream. Does it still fit the ordinary LoROM/HiROM budget the reel uses, or does it want the
   ExHiROM path now that the mapper work has landed? Compute it before choosing, and say which.
2. **Keyframe policy.** The decided policy is Option A (scheduled 2-VBlank slots, K=120). If this
   content's keyframes are heavier, report the measured cost rather than silently changing K.
3. Whether the existing asset emitter extends cleanly or genuinely needs a sibling.

## Verification (record per step, raw output + PASS/FAIL)

1. Asset bake reproduces the recorded corpus SHA-256 (or records a new one with provenance).
2. Whole-loop byte-correct decode on bsnes-jg; negative control fails.
3. Cadence table: slow/FastROM, presented frames per 600 VBlanks, next to the Artemis figures.
4. Entropy fingerprint one picture; `-verify` clean.
5. Published page live; served ROM sha matches the gate-verified binary.
