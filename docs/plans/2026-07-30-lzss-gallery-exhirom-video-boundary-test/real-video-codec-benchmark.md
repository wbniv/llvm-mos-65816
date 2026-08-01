# Real-camera video codec benchmark

**Run:** 2026-07-31
**Result:** SVX1 remains the size winner on animation and real camera footage; one decoder is enough

## Real-camera source and provenance

The source is NASA Images item **“Artemis I Launch (Press Site)”**, NASA ID
`Artemis I Launch 2022 CU tracking from Press Site_compressed`. The canonical
[NASA asset collection](https://images-assets.nasa.gov/video/Artemis%20I%20Launch%202022%20CU%20tracking%20from%20Press%20Site_compressed/collection.json)
identifies the downloaded `~large.mp4` derivative. NASA describes it as press-site camera footage
of the November 16, 2022 Artemis I launch from Launch Complex 39B. NASA media-use review remains
governed by the parent plan and the [NASA media guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/).

| Field | Value |
|---|---|
| Retrieved | 2026-07-31 |
| Downloaded file | `Artemis I Launch 2022 CU tracking from Press Site_compressed~large.mp4` |
| Source SHA-256 | `fc97cf25bda929757c3e658a82f8d00440a3d5d6f97f133c8a873a4716efaaf9` |
| Source video | H.264, 1920 × 1080, 30 fps |
| Selected interval | 00:42–00:52; ignition through early ascent |
| Transformation | video stream only; audio discarded; Lanczos 80 × 45; pad 5+6 rows; 30 fps; RGB24 |
| RGB24 corpus | 300 frames, 4,032,000 bytes; SHA-256 `8466093c0920dfcf519ea552dac077f982b3355d0942e98e6292f451dae42a16` |
| Review | no slate or captions in interval; vehicle markings are not readable at 80 × 56 and are not used as branding |

[![Six samples from the real-camera interval](real-video-codec-contact-sheet.png)](real-video-codec-contact-sheet.png)

## Dither method and integrity

Each corpus learns its own fixed 223-color median-cut palette. Floyd–Steinberg diffuses error
independently within every frame. Bayer applies the same fixed 8 × 8 threshold matrix at the same
pixel coordinates in every frame, then maps without error diffusion. Both reserve palette index 0
and 224–255 and round-trip through every measured codec decoder.

| Corpus | Dither | Tile-corpus SHA-256 | Palette SHA-256 | PSNR |
|---|---|---|---|---:|
| animation, 600 frames | Floyd | `5e748771fbe5ccb0fc18198e293d0442ad4014496c29b76063bcce4906eae5ad` | `9efba0c32e0f6ff74161c6f93081b95fa32ac98a43aaa763de641ca2adb2342d` | 33.84 dB |
| animation, 600 frames | Bayer | `9df3ad262c98dd53e73f8163cd1047afa48c836fb17654582eacaaeef6607c04` | same palette | 32.69 dB |
| real camera, 300 frames | Floyd | `2a4249437c3253c87c1ad9b0dfb4da31c19e6cc497fea51ac603cba6548d154b` | `0fe3b1b37265a782d0ce98c7c738cb23f31dc66ad65fd5cc729863ce63f742d7` | 37.32 dB |
| real camera, 300 frames | Bayer | `0fe3c207222c68a62da355abe6559c8e77068c28d3caebee5e52afc7eda05f0c` | same palette | 34.83 dB |

The animation/Floyd rerun exactly reproduces the recorded gates: SVX1@60 = 1,494,441 bytes,
SVC1@60 = 1,581,592 bytes, and gallery LZSS = 1,527,674 bytes.

## Complete 60-frame comparison

Numbers include packet/container overhead. LZSS and scanline PackBits are independent-frame
baselines; “60-frame” applies to the interframe formats.

| Variant | Animation Floyd | Animation Bayer | Real Floyd | Real Bayer |
|---|---:|---:|---:|---:|
| raw blocks | 2,737,200 (101.83%) | 2,737,200 (101.83%) | 1,368,600 (101.83%) | 1,368,600 (101.83%) |
| changed blocks | 2,293,424 (85.32%) | 2,076,208 (77.24%) | 1,100,056 (81.85%) | 1,055,640 (78.54%) |
| motion copy | 2,282,021 (84.90%) | 2,063,293 (76.76%) | 1,095,520 (81.51%) | 1,047,639 (77.95%) |
| block XOR + PackBits | 1,600,671 (59.55%) | 1,286,305 (47.85%) | 764,260 (56.86%) | 478,048 (35.57%) |
| full SVC1 | 1,581,592 (58.84%) | 1,280,669 (47.64%) | 755,658 (56.22%) | 472,226 (35.14%) |
| scanline PackBits | 1,676,088 (62.35%) | 2,284,023 (84.97%) | 820,105 (61.02%) | 1,128,341 (83.95%) |
| gallery LZSS, comparison only | 1,527,674 (56.83%) | 1,612,216 (59.98%) | 747,548 (55.62%) | 710,618 (52.87%) |
| **SVX1 whole-frame XOR + PackBits** | **1,494,441 (55.60%)** | **1,193,415 (44.40%)** | **705,621 (52.50%)** | **419,266 (31.20%)** |
| **SVX2 replacement/copy spans** | **1,593,191 (59.27%)** | **1,258,129 (46.81%)** | **766,569 (57.04%)** | **450,170 (33.49%)** |

## SVX1 keyframe sweep

| Interval | Animation Floyd | Animation Bayer | Real Floyd | Real Bayer |
|---:|---:|---:|---:|---:|
| 15 | 1,503,585 | 1,251,219 | 710,869 | 457,025 |
| 30 | 1,497,055 | 1,212,600 | 707,339 | 431,752 |
| **60** | **1,494,441** | **1,193,415** | **705,621** | **419,266** |
| 120 | 1,493,884 | 1,187,419 | 704,957 | 414,216 |

The 120-frame savings remain too small to justify doubling seek distance; keep 60 frames.

## Decision

Do **not** keep two shipping codecs. SVX1 is the size winner, but its delta decoder fails even the
20 fps target gate. SVX2 trades 2.29–4.54 percentage points of corpus ratio for target-native copy
and replacement spans; it is the smallest tested format that clears measured playback throughput.

Use **SVX2 + Floyd–Steinberg** as the quality-first default. Bayer substantially improves temporal
compression, especially on real footage, but the fixed checker is visible and PSNR falls by
2.49 dB there. Keep Bayer as an explicit size-optimized conversion option, not the default.

## 65816 throughput gate

`dev/snes-video-codec-bench.sh` ran each representative real-camera/Floyd packet for 600 NTSC
frames under bsnes-jg. Each case first decodes once and byte-compares all 4,480 output bytes; only
then does its fixed-time counter run. The raw control uses a native `MVN` block move rather than
compiler `memcpy`.

| Target path | Median packet | Worst-size packet | Approx. frames/s |
|---|---:|---:|---:|
| raw 4,480-byte copy | 876 decodes | — | 87.6 |
| **SVX2 65816 assembly** | **608** | **694** | **60.8–69.4** |
| SVX1 65816 assembly | 156 | 343 | 15.6 delta / 34.3 keyframe |
| SVX1 portable trusted loop | 81 | 112 | 8.1–11.2 |
| gallery LZSS, comparison only | 23 | 21 | 2.1–2.3 |
| SVC1 checked decoder | 6 | 6 | 0.6 |

The decode-only result isolates the codec bottleneck: raw frame movement comfortably exceeds 30
fps, while SVX2 replacement/copy spans reach 60.8–69.4 fps and pass the full 4,480-byte correctness
gate. That clears both the 20 fps shipping threshold (200/600) and 30 fps optimization threshold
(300/600) with more than 2× measured margin. SVX1 remains in the report as the size baseline, not a
shipping decoder. LZSS remains comparison-only: it is far below 20 fps and is not consistently
smaller than SVX2 across dithers.

The follow-up `VIDEO_BENCH_PIPELINE=1` slow-ROM gate charges one bank-contained ROM-to-high-WRAM
`$2180` DMA through the real segment cursor, the assembly decode, and one 4,480-byte WRAM-to-VRAM
DMA on every iteration:

| Slow-ROM pipeline proxy | Packet | Decodes / 600 VBlanks | Approx. frames/s |
|---|---:|---:|---:|
| SVX2 median | 3,127 B | 542 | 54.2 |
| SVX2 worst-size | 3,529 B | 581 | 58.1 |

This is deliberately a timing proxy, not yet a functional staged-input claim: the DMA writes the
packet to `$7F:2000`, but the current bank-0-only assembly decoder consumes the identical ROM copy.
It nevertheless charges the actual segment-cursor setup and both DMA transfers. Slow ROM therefore
**does not meet 60 fps** after staging and presentation, while still clearing 20 and 30 fps. The
next throughput gate is the planned FastROM build; the later far/ring-refill decoder integration
must retain the full-frame byte check.

The FastROM gate sets the LoROM header byte to `$30`, writes `MEMSEL=$01`, long-jumps from reset
bank `$00` to the `$80` execution mirror, and names `$80` as the staging DMA source. The emitted
trampoline is `JML $80:81D0` in the measured median ROM; checking only the header would not have
changed instruction-fetch timing.

| FastROM pipeline proxy | Packet | Decodes / 600 VBlanks | Approx. frames/s |
|---|---:|---:|---:|
| SVX2 median | 3,127 B | **605** | **60.5** |
| SVX2 worst-size | 3,529 B | **647** | **64.7** |

The first FastROM run was mixed: 564/618, exposing that encoded size does not rank decode cost.
The median has 132 commands (62 copy + 70 replacement) versus only 77 in the worst-size packet.
The optimized delta loop removes the per-command remaining-byte subtraction, keeps the count's
high byte zero instead of converting through `XBA`, and uses direct-page encodings for its known
`$00–$08` state rather than the assembler's 24-bit accumulator accesses. This raises FastROM to
**605/647: both representative cases pass 60 fps**, while slow ROM improves to 542/581 but remains
below 60.

The follow-up functional gate now makes the decoder consume the payload staged at `$7F:2009`
rather than its ROM duplicate. A staged-delta specialization reads control bytes with long-indexed
addressing and uses `MVN` directly from bank `$7F` for replacement spans; copy spans still read the
previous frame from bank 0. Avoiding redundant cursor reloads after replacement spans recovers the
last timing margin:

| Functional FastROM pipeline | Packet | Decodes / 600 VBlanks | Approx. frames/s |
|---|---:|---:|---:|
| SVX2 median | 3,127 B | **607** | **60.7** |
| SVX2 worst-size | 3,529 B | **648** | **64.8** |

Both cases therefore retain the full-frame byte gate and clear 60 fps while consuming the staged
high-WRAM payload. A future multi-packet player still needs refill scheduling/ring ownership, but
the codec's functional far-source path and its measured budget are no longer proxies.

This integration exposed an llvm-mos MC bug hidden by every prior same-bank use: 65816 `MVN`/`MVP`
assembly syntax is source,destination, while the instruction bytes encode destination,source. The
TableGen encoder emitted the operands in syntax order. The fix swaps the encoded fields; distinct
bank regression cases now pin `mvn #$7f,#$00` to `[54 00 7f]` and `mvp #$12,#$34` to
`[44 34 12]`. The rebuilt toolchain's MC lit test passes, and the functional ROM uses the mnemonic
rather than raw opcode bytes, so its fidelity/performance gate exercises the fix end to end.

## Visible proof-ROM correction

The first published visible proof had a correct decoded WRAM frame but a corrupted display. The
initial disassembly diagnosis—compiler mishandling of the DMA source-low cast—was wrong. The
compiler had correctly spilled the relocated low byte across the decoder call. The handwritten
`svx_decode_payload_asm` then clobbered `__rc0`, llvm-mos's software-stack pointer, while using it
as its packet cursor; the later spill reload consequently read through a corrupted stack base.

The decoder now preserves/restores `__rc0`, and the proof ROM again uses the original C DMA
register assignments. Under bsnes-jg it passes `corpus_result == 0` after byte-comparing all 4,480
decoded bytes. Its captured 256 × 224 framebuffer has SHA-256
`d0bd439a2a8909f2905ae3000e037b17f180ccdc365e7b6bf7f460b1d9c04c92`, exactly matching the
temporary assembly-DMA reference capture. This was a handwritten-assembly ABI violation, not an
LLVM backend or linker defect.

## Hard-content stressor: Apollo 11 Saturn V daylight launch (2026-08-01)

The Artemis leg above is real camera footage, but it is a **mild** stressor: a night launch is
mostly black frames, and the H.264 `~large` derivative already smooths sensor noise before our
converter ever sees it. Its 31–57% ratios are a best case for "real footage." This section adds
one grain-rich **daylight film** clip — parent-plan candidate #16, Apollo 11 Saturn V launch, real
16 mm KSC tracking-camera film — to calibrate ratio expectations for hard content: heavy film
grain, bright continuous exhaust flame, and a smoke plume with fine, high-frequency edges.

### Harness-drift gate (run before any new number below)

Two independent checks, because the exact intermediate RGB24/tile files behind the 2026-07-31
Artemis numbers no longer exist on disk (they were `/tmp` intermediates, never committed) and the
codec module has changed shape since:

1. **Codec logic, byte for byte.** `tools/snes_video_codec.py` has not changed since the commit
   that produced the recorded numbers (`5038454`, 2026-07-31); `git diff 5038454..HEAD --
   tools/snes_video_codec.py` is empty. `tools/snes-video-pack.py` gained only an additive
   `--tiles-output` flag (`79bb73b`) with no change to `quantize_rgb24`, `encode_xor_frame`,
   `encode_frame`, or `benchmark`.
2. **Bit-exact input, reproduced output.** The real-camera (Artemis) 300-frame Floyd tile corpus
   survived on disk from the concurrent 60 fps work: `build/real-video-floyd.tiles`, SHA-256
   `2a4249437c3253c87c1ad9b0dfb4da31c19e6cc497fea51ac603cba6548d154b` — an exact match for the
   Floyd tile-corpus hash recorded above. Re-running the benchmark on that exact file:

   ```
   $ python3 tools/snes-video-pack.py --benchmark --compare-keyframes 15,30,60,120 \
       build/real-video-floyd.tiles
   scanline-packbits      packed=820105  (61.02%)
   gallery-lzss           packed=747548  (55.62%)
   svx2-replacement-copy  ki=60 packed=766569  (57.04%)
   full-svc1              ki=60 packed=755658  (56.22%)
   xor-packbits (block)   ki=60 packed=764260  (56.86%)
   changed-blocks         ki=60 packed=1105304 -> 1100056 (81.85%)
   motion-copy            ki=60 packed=1095520 (81.51%)
   ```

   Every figure reproduces this document's recorded real-camera/Floyd row exactly. Combined with
   (1), this is bit-exact proof the encoder/decoder implementation has not drifted.

**Gap, stated plainly:** the TODO item asked to reproduce "SVX1@60 = 1,494,441 B" (the *animation*
corpus, whole-frame XOR-delta codec). That specific figure is **structurally unreproducible with
the current tool**, not because of drift: `SVX1` (true whole-frame XOR delta, magic-less) was a
provisional codec that lost the one-codec decision and has since been deleted from
`snes_video_codec.py` — `encode_xor_frame`/`decode_xor_frame` now implement **SVX2** (PackBits
keyframe + replacement/copy-span delta, magic `SVX2`) exclusively. There is no code path left that
produces the old XOR-delta bitstream, so no re-run can print that number. This is expected
post-decision cleanup, not a regression — the shipping decision was already SVX2-only.

A best-effort byte-exact reconstruction of the *animation* RGB24 corpus was also attempted, since
its two NASA masters are re-downloadable: `Pre-launch_through_launch.webm`
(SHA-256 `28f9e843111466b3ce1869975283d71a1779f593974f49d76a6da9683c769a3d`) and
`Return_to_Earth.webm` (SHA-256 `bc0d89e9cf9ca33a3faa2fed6d653c9eddede0458d0ab010c228535621516dc8`)
from [NASA SVS item 14191](https://svs.gsfc.nasa.gov/14191/) — both re-downloaded and their
SHA-256 matched exactly. Three ffmpeg filter-chain orderings (time-based `trim` before retiming,
`fps` before `trim`, and input-side `-ss`/`-t` seeking) each reproduced the correct 600-frame,
8,064,000-byte size but none reproduced the recorded RGB24 SHA-256 `9794f29f…`. The exact filter
graph used on 2026-07-31 was run by hand and never captured in a script, so sub-frame timing
decisions (duplicate/drop placement under 29.97→30 fps retiming) aren't recoverable from prose
alone — this is front-end (video-decode/scaling) nondeterminism, not evidence against (1) or (2)
above. `tools/snes-video-rgb24-convert.sh` (added with this change) now scripts the exact filter
chain used for the Apollo interval below, so the *next* drift check on this corpus has something
to reproduce instead of re-deriving it.

**Gate verdict: PASS**, on the evidence that is actually reproducible (encoder/decoder code
identity + bit-exact real-camera input/output match); the specific SVX1/animation figures quoted
in the TODO item are unreproducible for a documented, non-drift reason.

### Source and provenance

| Field | Value |
|---|---|
| Canonical item | [NASA image/video item `KSC-19690716-MH-NAS01-0001-Apollo_11_Launch_President_Johnson_Jack_King_Narration_Press_Site-B_1372`](https://images.nasa.gov/details/KSC-19690716-MH-NAS01-0001-Apollo_11_Launch_President_Johnson_Jack_King_Narration_Press_Site-B_1372), "Video - Apollo 11 Pre-Launch and Launch" |
| Asset manifest | [images-assets.nasa.gov collection.json](https://images-assets.nasa.gov/video/KSC-19690716-MH-NAS01-0001-Apollo_11_Launch_President_Johnson_Jack_King_Narration_Press_Site-B_1372/collection.json) (found via `images-api.nasa.gov/search?q=Apollo+11+launch&media_type=video`, the documented API fetch path — the `nasa.gov/missions/apollo-11-hd-videos/` page links only montage/comparison clips, not raw launch footage) |
| Creator/agency | NASA, Kennedy Space Center; `photographer: NASA`, `center: KSC`, `date_created: 1969-07-16` |
| Downloaded file | `…Press_Site-B_1372~large.mp4`, 1280×720 H.264, ~59.94 fps, duration 3634.56 s |
| Retrieved | 2026-08-01 |
| Source SHA-256 | `4e7c693a2c6480b4450343bd7482eaac9a758a39240d61f37d4db7b98c1d401b` |
| Selected interval | 00:56:50–00:57:00 (10 s, 300 frames at 30 fps) — post-ignition vertical ascent |
| Rights statement | NASA-produced 1969 KSC archival footage; not subject to copyright for US distribution under [NASA's media guidelines](https://www.nasa.gov/nasa-brand-center/images-and-media/); `photographer: NASA` with no third-party-material note on the item record |
| Review | audio discarded entirely (video stream only), so the title's "Jack King Narration"/President Johnson audio content is moot; the selected interval shows only rocket, exhaust flame, smoke, sky, and ocean horizon — no mission patch, flag, personnel, or on-screen graphic; the burned-in countdown-clock overlay visible earlier in the source (T-minus digits, camera-ID corner tags) falls entirely outside the selected interval |
| Transformation | video stream only; Lanczos 80×45; pad 5+6 rows; retimed 59.94→30 fps (frame selection, no optical flow); RGB24 |
| RGB24 corpus | 300 frames, 4,032,000 bytes; SHA-256 `a78c4c8c96ba7a00e99475b9545466b21cd12a041597d867994318a33f514080` |
| Conversion command | `tools/snes-video-rgb24-convert.sh --start 3410 --duration 10 <master>.mp4 apollo-daylight.rgb` (reproduced the manually-derived file byte for byte) |

Interval choice, why: a 1-second-per-frame scan of the full 60-minute reel located ignition near
t≈00:56:19–00:56:39 (billowing orange/tan smoke, rocket still near the pad) followed immediately by
a clean, unbroken vertical-ascent shot with a bright, continuous exhaust flame against sky/ocean —
exactly the "smoke + vertical motion, grain-rich, daylight" brief. 00:56:50–00:57:00 sits in the
ascent shot, after the countdown-clock overlay and camera-ID tags visible earlier have scrolled out
of frame and before the telephoto camera cuts to a distant, nearly-blank-sky tracking shot later in
the reel.

[![Six samples from the Apollo 11 daylight-launch interval](apollo-daylight-contact-sheet.png)](apollo-daylight-contact-sheet.png)

### Dither, palette, and integrity

Same method as the Artemis leg: the corpus learns its own fixed 223-color median-cut palette
(deterministic, so both dither invocations reproduce the identical palette), then Floyd–Steinberg
or Bayer dithers each frame against it.

| Corpus | Dither | Tile-corpus SHA-256 | Palette SHA-256 | PSNR |
|---|---|---|---|---:|
| Apollo daylight, 300 frames | Floyd | `fe7df9734b2419cc53784eb246e4dde62b4a6c898becb4a6fb307fbfbb1dd931` | `664a63c2f05b9fa53842e0f9c16fdd34a90cd752a68411e23efde8f82e8b459b` | 31.98 dB |
| Apollo daylight, 300 frames | Bayer | `e0475f2cdece29a824680bbbe5c9e3b033914190ab98d262f9ace630db80316a` | same palette | 31.92 dB |

Every dither/codec combination round-tripped: `tools/snes-video-pack.py --benchmark` raises on any
decoded-vs-encoded mismatch, and both runs (Floyd, Bayer) completed and printed their full JSON
report without error, so every listed variant's decoder reproduced its encoder's exact frame bytes.

Note the near-vanished Floyd/Bayer PSNR gap (31.98 vs 31.92 dB, 0.06 dB) versus the Artemis leg's
2.49 dB gap. Real film grain already looks like high-frequency dither noise; Floyd's adaptive error
diffusion buys almost nothing extra once the source itself is this noisy.

### Complete 300-frame comparison

Ratios include packet/container overhead, same convention as the table above. Raw input is
1,344,000 indexed bytes (300 × 4,480).

| Variant | Apollo Floyd | Apollo Bayer | Artemis Floyd (for reference) | Artemis Bayer (for reference) |
|---|---:|---:|---:|---:|
| raw blocks | 1,368,600 (101.83%) | 1,368,600 (101.83%) | 1,368,600 (101.83%) | 1,368,600 (101.83%) |
| changed blocks | 1,105,304 (82.24%) | 1,100,504 (81.88%) | 1,100,056 (81.85%) | 1,055,640 (78.54%) |
| motion copy | 1,104,926 (82.21%) | 1,100,441 (81.88%) | 1,095,520 (81.51%) | 1,047,639 (77.95%) |
| block XOR + PackBits | 831,720 (61.88%) | 709,328 (52.78%) | 764,260 (56.86%) | 478,048 (35.57%) |
| full SVC1 | 827,223 (61.55%) | 705,542 (52.50%) | 755,658 (56.22%) | 472,226 (35.14%) |
| scanline PackBits | 830,562 (61.80%) | 1,108,138 (82.45%) | 820,105 (61.02%) | 1,128,341 (83.95%) |
| gallery LZSS, comparison only | **801,766 (59.66%)** | 839,796 (62.48%) | 747,548 (55.62%) | 710,618 (52.87%) |
| **SVX2 replacement/copy spans (shipping)** | 837,686 (62.33%) | **716,234 (53.29%)** | **766,569 (57.04%)** | **450,170 (33.49%)** |

The headline result: **on grain-rich daylight film, gallery LZSS — an intraframe-only comparison
baseline — is smaller than the shipping interframe SVX2 codec, at the Floyd dither** (801,766 vs.
837,686 bytes, a 35,920-byte / 2.67-point swing). Film grain decorrelates consecutive frames enough
that SVX2's replacement/copy spans buy less than LZSS's spatial (within-frame) compression recovers.
This never happened on the Artemis leg, where SVX2 beat LZSS at both dithers.

### SVX2 keyframe sweep (Apollo daylight)

| Interval | Apollo Floyd | Apollo Bayer |
|---:|---:|---:|
| 15 | 837,899 | 738,691 |
| 30 | 837,811 | 723,492 |
| **60** | **837,686** | **716,234** |
| 120 | 837,693 | 713,334 |

Floyd is nearly flat across every interval (837,899 → 837,686, a 213-byte spread) — on this content,
a delta packet costs almost as much as a fresh keyframe, because grain decorrelation defeats the
"mostly unchanged" assumption a delta encoding depends on. Bayer still shows a real interval effect
(738,691 → 713,334) because its position-fixed dither pattern keeps background/sky pixels index-
stable frame to frame even under grain, unlike Floyd's per-frame-independent error diffusion. Keep
the existing 60-frame interval; nothing here argues for changing it.

### Ratio comparison: hard daylight grain vs. the night leg

Using the shipping codec (SVX2, 60-frame interval) as the basis for comparison:

| Dither | Artemis (night, real camera) | Apollo (daylight, film grain) | Delta |
|---|---:|---:|---:|
| Floyd–Steinberg | 57.04% | 62.33% | **+5.29 points** |
| Bayer | 33.49% | 53.29% | **+19.80 points** |

**Hard daylight grain costs 5.3 ratio points at the quality-first Floyd default, and a dramatic
19.8 points under Bayer.** The night leg's 31–57% figures were indeed a best case: its "real
camera" footage was already mostly black with codec-smoothed grain, closer to clean synthetic
imagery than to hard film content. Bayer's compression advantage — which comes from holding
background pixel indices stable frame to frame — depends on the source itself being low-noise; real
film grain reintroduces per-pixel decorrelation that Bayer's fixed dither pattern cannot suppress,
so most of Bayer's edge over Floyd (23.55 points on the night leg) evaporates to 9.04 points here.

### Does the one-codec/SVX2 decision survive?

**Yes — the decision was speed-anchored, and this content doesn't change the speed numbers.** The
65816-throughput gate above measured SVX2 at 60.8–69.4 fps decode-only (607–648/600 VBlanks
functional-FastROM) versus gallery LZSS at 2.1–2.3 fps — LZSS is roughly 27× too slow to hit even
the 20 fps shipping floor, regardless of which corpus is smaller on disk. This section's numbers
confirm LZSS wins the *size* race on hard grain-rich daylight content at the Floyd dither, but a
codec that decodes at 2 fps was never a shipping candidate; the throughput gap is far larger than
the 2.67-point size gap it would need to close. SVX2 + Floyd–Steinberg remains the shipping choice.
What *does* change is size expectations: budget for **~62% of raw** on hard grain-rich daylight
content at the quality-first Floyd default (not the night leg's ~57%), and treat Bayer's
size-optimized savings as content-dependent — large on smooth/dark footage, modest on real film
grain — rather than a fixed discount.
