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
below 60. The functional high-WRAM/ring-refill integration caveat above still applies.

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
