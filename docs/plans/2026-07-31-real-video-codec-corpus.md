# Real-video corpus for the SVC1/SVX codec benchmark

**Date:** 2026-07-31 · **Status:** COMPLETE 2026-07-31 ·
**Parent:** [2026-07-30-exhirom-video-boundary-test.md](2026-07-30-exhirom-video-boundary-test.md)
(§Codec selection) · **Prior result:**
[artemis-codec-benchmark.md](2026-07-30-lzss-gallery-exhirom-video-boundary-test/artemis-codec-benchmark.md)

## Context

The entire codec benchmark corpus to date is **CG animation** (NASA SVS 14191 — the Artemis I
launch/return *animations*). Every measured ratio, and the provisional SVX1-beats-SVC1-beats-LZSS
ordering, is conditioned on clean synthetic imagery: flat regions, noise-free backgrounds,
frame-coherent pixels. Real camera footage violates those assumptions — film grain / sensor noise
decorrelates consecutive frames, so XOR deltas densify and unchanged-block predicates stop firing.

User direction (2026-07-31): *add an actual video to the corpus, not just a computer animation
video, and re-evaluate everything with the actual video too; suspicion — we may need to keep 2
codecs (one for video, one for animation).*

A second, pipeline-level confound must be separated from the codec question: the converter
Floyd–Steinberg-dithers each frame independently. FS error diffusion is spatially serial — tiny
per-pixel noise reroutes the whole frame's error cascade, producing large index churn even in
static regions. An ordered (Bayer) dither is position-deterministic and stabilizes indices across
frames. **The re-evaluation therefore sweeps dither × codec**, or we risk concluding "video needs
another codec" when the truth is "video needs another dither."

The corpus work began as a measurement-only change. Its throughput follow-up now also has a
visible proof ROM: it decodes one corpus frame, verifies all 4,480 bytes, presents it through
Mode 7, and holds the verified image for inspection.

## Source selection

**Primary: real Artemis I launch camera footage** (NASA, images.nasa.gov / NASA content —
US-public-domain, item-level review required per the parent plan's provenance rules). Thematically
ideal: the same mission as the animation corpus, so the eventual reel can cut animation ↔ real
footage of the same event.

**Fallback (parent plan's own shortlist): #16 Apollo 11 Saturn V launch** (real 16/35 mm film —
maximal grain stress), then #25 SDO solar flare.

Provenance record (exact URL, retrieval date, SHA-256, interval, modifications, rights statement)
goes into the results doc per the parent plan's checklist. Same hard exclusions apply (no
narration/score/third-party material; no protected-identifier frames).

## Method

1. Download the master; record SHA-256 + provenance. Select a ~10 s interval (≈300 frames) with
   large-scale motion and no slate/captions; eyeball the frames before committing.
2. Same conversion as the animation corpus (`ffmpeg`): retime to 30 fps (no optical flow), Lanczos
   to 80 × 45, pad 5+6 black rows → 80 × 56, RGB24 concatenated.
3. **Separate corpus, separate palette** — the real-video corpus learns its own 223-color
   median-cut palette (we are comparing codecs per content type, not building the final reel; a
   shared cross-content palette would degrade both and confound the measurement).
4. Run the full existing sweep on the real-video corpus via `tools/snes-video-pack.py --rgb24
   --benchmark` (raw / changed / +motion / XOR+PackBits / full SVC1 / SVX1 at 15/30/60/120,
   scanline PackBits + gallery-LZSS comparisons).
5. **Dither axis:** add an ordered-dither (Bayer) option to `quantize_rgb24` and run the sweep on
   both dithers × both corpora (animation corpus is reproducible from `/tmp` intermediates /
   re-derivable from the recorded masters; RGB24 SHA `9794f29f…` verified present).
6. Contact sheet for the real corpus (same generator).
7. Results doc `real-video-codec-benchmark.md` in the same bundle dir, table format matching
   artemis-codec-benchmark.md, plus a cross-corpus comparison section and a **codec-count
   recommendation** with the decision criterion: does the best single codec's cross-content loss
   exceed the cost of a second decoder (ROM bytes + a second cycle-verification matrix)? Note the
   near-free path if intraframe LZSS wins on real video: the gallery LZSS decoder already exists
   and is target-proven.

## Verification

1. Provenance: results doc records source URL, SHA-256, interval, and rights note; masters'
   SHA-256 reproduced by `sha256sum`.
2. Pipeline integrity: animation corpus re-run reproduces the recorded table (SVX1@60 =
   1,494,441 B; SVC1@60 = 1,581,592 B; LZSS = 1,527,674 B) before any real-video numbers are
   quoted — proves the harness didn't drift.
3. Real-video sweep: full table produced for both dithers; every variant's decoder round-trips
   (decoded CRC == encoder CRC) on the real corpus.
4. Ordered-dither animation sweep completes (the 2×2 matrix is full).
5. Results doc + contact sheet created; parent plan §Codec selection updated with a pointer;
   TODO updated.

**PASS (2026-07-31):** all five gates completed. Provenance and hashes are recorded in the results
document; the animation/Floyd rerun reproduced all three prior byte totals; every dither/codec
combination round-tripped; both contact sheets and the cross-corpus decision table are present.
The subsequent target proof additionally passes 17 host tests, its 4,480-byte bsnes-jg fidelity
gate, and the pixel-identical visible-render comparison recorded below.

## Result

Completed in
[real-video-codec-benchmark.md](2026-07-30-lzss-gallery-exhirom-video-boundary-test/real-video-codec-benchmark.md).
SVX1 wins all four corpus × dither size cells, but its target delta path reaches only 15.6 fps.
The follow-up SVX2 replacement/copy format costs +2.29–4.54 ratio points and reaches 60.8–69.4 fps
with full-frame byte correctness. One shipping codec remains sufficient: SVX2 with Floyd–Steinberg
as the quality-first default and Bayer as an explicit size-optimized option.

The visible FastROM proof initially rendered corrupted pixels even though its decoded-WRAM gate
passed. A temporary assembly DMA setup appeared to implicate compiler lowering of
`(uint8_t)(uintptr_t)output`, but pass-by-pass inspection disproved that diagnosis: instruction
selection materialized the correct relocation, spilled the low byte before the decoder call, and
reloaded it afterward. The handwritten `svx_decode_payload_asm` had reused `__rc0` as its source
cursor without preserving it; `__rc0` is llvm-mos's software-stack pointer while the caller has a
frame, so the post-call spill reload addressed unrelated memory. The decoder now saves/restores
`__rc0`, and presentation is back in ordinary C—there is no compiler workaround. bsnes-jg passes
the 4,480-byte fidelity gate and produces the same 256 × 224 render (SHA-256
`d0bd439a2a8909f2905ae3000e037b17f180ccdc365e7b6bf7f460b1d9c04c92`) as the temporary
known-good assembly presentation path.

The next independent integration step is also complete: SVX2 now consumes the compressed payload
actually staged at `$7F:2009`. The functional FastROM pipeline reaches 607/648 decodes per 600
VBlanks (60.7/64.8 fps) for the median/worst packets with the same 4,480-byte gate. This work found
and fixed an llvm-mos MC encoder defect: distinct-bank `MVN`/`MVP` operands were emitted in assembly
syntax order instead of the hardware's reversed destination,source byte order. The rebuilt MC lit
regression and the mnemonic-using ROM both pass.

Both benchmark corpora are integrated by
[`2026-07-31-svx2-full-artemis-reel.md`](2026-07-31-svx2-full-artemis-reel.md): 600 animation
frames followed by 300 real-camera frames, with independent keyframes. The benchmark retains a
separate palette per corpus for fair codec measurement; the shipping reel learns one shared
palette across all 900 frames so playback needs no runtime CGRAM transition. Its combined
2,311,832-byte stream fits a standard 4 MiB HiROM; ExHiROM remains a distinct boundary test.
