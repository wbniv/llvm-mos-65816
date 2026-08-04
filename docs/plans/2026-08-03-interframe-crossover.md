# Where interframe coding stops paying — measure the crossover, then decide

**Date:** 2026-08-03 · **Status:** P0 / P0b / P1 MEASURED 2026-08-04, P2 DECIDED 2026-08-04 —
confirming run on the shipped Apollo corpus done 2026-08-04 (direction confirms, magnitude short of
the P0b prediction; see [P2 confirming run](#confirming-run-2026-08-04-does-the-win-hold-on-the-shipped-corpus))
**Item:** TODO `[T4]` · **Visible surface:** none until a decision is taken — no mockups.

**Measurement tool:** [`tools/snes-video-crossover.py`](../../tools/snes-video-crossover.py).
**Headline:** on hard content **96.16%** of frames want a keyframe — but the cadence budget at
60 fps is **0.84%** of frames, and the shipped `K=120` policy already spends all of it, so a chooser
can buy **430 B on 2.1 MB (0.02%)**. Switching that same footage from Floyd to **Bayer** dither buys
**270,314 B (10.06 points)** at zero cadence cost. See [Results](#results-2026-08-04) and the
[recommendation](#recommendation-p2-input--the-decision-itself-stays-open).

## The observation

Three corpora, packed both ways, all recorded:

| corpus | interframe SVX2 (shipping) | intraframe LZSS (comparison only) | who wins |
|---|---:|---:|---|
| Artemis I night launch, Floyd | 766,569 (57.04%) | 747,548 (55.62%) | LZSS by 1.42 pts |
| Artemis I night launch, Bayer | 450,170 (33.49%) | 710,618 (52.87%) | **SVX2 by 19.38 pts** |
| Apollo 11, static tracking cut, Floyd | 837,686 (62.33%) | 801,766 (59.66%) | LZSS by 2.67 pts |
| Apollo 11, **recut** (cropped, 2× speed), Floyd | 1,070,154 (79.62%) | 877,809 | **LZSS by 14.31 pts** |

The trend is monotone in how much consecutive frames resemble each other. SVX2 codes replacement
and copy spans against the previous frame; when film grain and fast motion decorrelate neighbours,
those spans buy less than LZSS's within-frame compression recovers. The recut — cropped to the
action and played at 2× — is the extreme, and the gap there is **5× wider** than on the static cut
of the *same source footage*.

## Why this is not simply "switch codecs"

The shipping decision was anchored on throughput, not size: **LZSS decodes ~27× too slow** (2.1–2.3
fps vs SVX2's 60+). Nothing in the table above changes that, and this plan does not reopen it.

The interesting question is narrower: **SVX2 already contains an intraframe path** — its keyframes.
And the Apollo recut measured keyframe interval K=15 versus K=120 as a **3,233-byte spread across an
8× range**, i.e. on hard content a keyframe costs about what a delta costs. So the chooser might
need no new codec at all: emit a keyframe wherever it beats the delta, using a decode path that is
already fast enough and already shipping.

## The tension that makes this a real design question

Size and time trade in **opposite** directions:

- A keyframe on hard content is often **smaller** than the delta (that is the whole observation).
- A keyframe costs **1.12 VBlanks** to decode (post-specialization, FastROM) against ~1.0 for a
  delta, so it occupies a 2-VBlank slot under the current cadence policy.

So the naive rule — "per frame, emit whichever is smaller" — is wrong: it minimizes bytes while
silently spending the frame budget, and a stream that chooses keyframes often stops presenting 60.
The correct framing is **constrained**: minimize bytes subject to holding the cadence. That is a
scheduling problem (how many 2-VBlank slots can a 600-VBlank window absorb), not a codec problem.

## Phases

> **Status 2026-08-04:** P0 ✅, P0b ✅ (extended with the dither experiment it called for), P1 ✅ —
> all measured, results in [Results (2026-08-04)](#results-2026-08-04). P2 remains open; a
> [recommendation](#recommendation-p2-input--the-decision-itself-stays-open) is on file, the decision
> is not. P3 is unstarted and, on the recommendation, should not start.

**P0 — measure the crossover per frame, not per corpus.** Everything above is a whole-corpus
aggregate, which hides the distribution. For each frame of each corpus, record `size(delta)` and
`size(keyframe)`; the encoder computes both already or can be made to. Deliver: the fraction of
frames where keyframe < delta, and by how much, per corpus and per dither. If that fraction is
small and concentrated (e.g. only at shot cuts), a chooser is not worth building and this closes
with a recorded answer.

**P0b — a second frame rate — ✅ ANSWERED 2026-08-03, and it reshapes the question.** The Apollo
true-60 work re-derived this exact interval at three temporal spacings:

| frame spacing | LZSS | SVX2 K=120 | LZSS ahead |
|---|---:|---:|---:|
| 1/15 s (the 30 fps cut) | 65.31% | 79.62% | 14.31 pts |
| 1/30 s (59.94 fps, ships) | 65.51% | 78.91% | **13.40 pts** |
| 1/59.94 s (real-time control) | 67.93% | 78.06% | 10.13 pts |

Halving the temporal gap recovers **0.91 points**; quartering it, 4.18. So the hypothesis behind
this phase — "frames closer together will resemble each other more and delta coding will recover" —
is **true but almost irrelevant at achievable frame rates**. The reason is the important part: the
residual between consecutive frames here is **Floyd–Steinberg dither noise, which is decorrelated
no matter how close the frames are**. The crossover is a property of the *dither*, not of the
footage or the frame rate, and it cannot be escaped by shooting or sampling faster.

That redirects P0. The per-frame question is no longer only "delta or keyframe" but "how much of
each delta is dither noise" — which suggests a cheap prior experiment: re-pack one corpus with an
*ordered* (Bayer) dither, which is deterministic and frame-stable, and see whether SVX2's advantage
returns. The recorded Artemis Bayer row already hints at it (SVX2 ahead by 19.38 points there,
its largest win anywhere in the table).

**P1 — the cadence model.** Given a per-frame chooser and a target rate, how many keyframe slots fit
in a 600-VBlank window before the stream slips? Existing measurements to build on: hardest stream
slice 674/600 slow ROM and 754/600 FastROM, keyframe 1.12 VBlanks, current policy K=120 →
59.50 fps effective. Output: the maximum keyframe fraction at 60 fps and at 30 fps.

**P2 — decide, and record the decision either way.** Build the chooser only if P0's distribution and
P1's budget overlap enough to matter. A recorded "not worth it, here is the number" is a perfectly
good outcome and cheaper than discovering it in an implementation.

**P3 — implement, if P2 says so.** Encoder-side selection + a stream flag per packet; the decoder
already handles both packet kinds, so this should be small. Re-gate byte-correctness and cadence on
every corpus, not just the one that motivated it.

## Results (2026-08-04)

Measured with [`tools/snes-video-crossover.py`](../../tools/snes-video-crossover.py), which reports,
for every frame of a tile corpus, `size(delta)` and `size(keyframe)` including the 2-byte container
prefix, then evaluates the constrained chooser of P1.

### The structural finding that makes the analysis tractable

**Per-frame packet costs are independent of every other frame's choice.** SVX2 is lossless, so the
decoded previous frame equals the source previous frame whichever packet kind was emitted for it;
frame *i*'s delta is coded against the same bytes either way. The tool establishes this rather than
assuming it — it decodes *both* packet kinds for every frame and checks each against the source.

Consequence: "minimise bytes subject to a keyframe budget" is a **top-*m* selection**, not a dynamic
program over reconstruction state. Take every forced keyframe, then spend the remaining budget on the
frames with the largest `delta − key`. This is worth recording because it removes the main
implementation risk a chooser would otherwise carry.

### Corpus availability — what could and could not be re-derived

| corpus | status |
|---|---|
| Artemis I night launch, Floyd, 300 f | **on disk, SHA-matched** — `build/real-video-floyd.tiles`, `2a42494…d154b`, matches the benchmark doc |
| Apollo v2 recut (30 fps) and v3 (59.94 fps) | **gone.** Both need 20 s of the 2.37 GB Apollo master, which is deliberately not vendored; the vendored `apollo11-daylight-5994p.mp4` excerpt is only 10.01 s |
| Apollo **real-time control**, 600 f | **re-derived** from the vendored excerpt. The excerpt is a re-encode, so the RGB24 SHA does not match (`0db7a75b…` vs recorded `cb0bc845…`) — but every codec aggregate lands within **0.08 points** of the record (table below), so the per-frame distribution derived from it is trustworthy |
| Artemis Bayer, 300 f | **not reproducible** — the Artemis source `mp4` is not vendored and no RGB24 survived |

Aggregate reconciliation for the re-derived real-time control corpus, against the numbers recorded in
[`real-video-codec-benchmark.md`](2026-07-30-lzss-gallery-exhirom-video-boundary-test/real-video-codec-benchmark.md):

| variant | recorded | re-derived | drift |
|---|---:|---:|---:|
| raw blocks | 2,737,200 (101.83%) | 2,737,200 (101.83%) | 0 |
| scanline PackBits | 2,035,958 (75.74%) | 2,035,913 (75.74%) | −45 B |
| gallery LZSS | 1,826,062 (67.93%) | 1,828,138 (68.01%) | +0.08 pt |
| xor-PackBits K=120 | 2,095,363 (77.95%) | 2,097,086 (78.02%) | +0.07 pt |
| full SVC1 K=120 | 2,094,365 (77.92%) | 2,095,930 (77.97%) | +0.05 pt |
| **SVX2 K=120** | **2,098,219 (78.06%)** | **2,099,896 (78.12%)** | **+0.06 pt** |

The recorded LZSS-ahead figure for this point is 10.13 pts; the re-derivation gives 10.11 pts.

### P0 — the per-frame crossover distribution

| corpus | frames | keyframe smaller than delta | mean `delta − key` | total saving available |
|---|---:|---:|---:|---:|
| **Apollo real-time control, Floyd** (hard) | 600 | **576 / 599 = 96.16%** | **+101.5 B** | 61,170 B (2.28% of raw) |
| Artemis apollo mixed reel (shipped, 1200 f) | 1200 | 238 / 1199 = 19.85% | −97.7 B | 31,447 B (0.58%) |
| Artemis I night launch, Floyd (easy) | 300 | 15 / 299 = 5.02% | −144.8 B | 618 B (0.05%) |
| Artemis 59.94 real camera (`real-5994`) | 600 | 4 / 599 = 0.67% | −758.6 B | 291 B (0.01%) |
| **Apollo real-time control, BAYER** (same footage) | 600 | **2 / 599 = 0.33%** | **−527.9 B** | 72 B (0.00%) |
| XRISM native 60 (CG) | 1800 | 2 / 1799 = 0.11% | −216.5 B | 719 B (0.01%) |

**P0's stated closing condition does not fire.** The plan said: *"If that fraction is small and
concentrated (e.g. only at shot cuts), a chooser is not worth building and this closes with a
recorded answer."* On hard content the fraction is neither small nor concentrated — 96.16% of frames,
in **19 runs with a longest run of 265 consecutive frames**, on a shot that contains no cuts at all.
It is a *sustained regime*, not an event. The top 1% of frames carry only 2.2% of the total saving.

So the chooser is not killed by P0. It is killed by P1.

### P0b — the second frame-rate point, and the dither experiment it redirected to

The three-frame-rate table above the fold stands as recorded; nothing here overwrites it. What this
run adds is the experiment that table pointed at: **re-pack the identical footage with an ordered
(Bayer) dither**, which is deterministic and frame-stable, and see whether SVX2's advantage returns.

Same 600 frames, same crop, same sampling, `K=120` — only the dither differs:

| dither | gallery LZSS (intraframe, ~2.2 fps decode) | SVX2 (interframe, 60 fps decode) | winner | PSNR |
|---|---:|---:|---|---:|
| Floyd–Steinberg | 1,828,138 (68.01%) | 2,099,896 (78.12%) | LZSS by 10.11 pts | 31.66 dB |
| **Bayer 8 × 8** | 1,932,623 (71.90%) | **1,829,582 (68.06%)** | **SVX2 by 3.84 pts** | 31.42 dB |

**The crossover is a property of the dither, and it is fully reversible.** Bayer moves SVX2 from
78.12% to 68.06% of raw — **270,314 B, 10.06 points** — on byte-identical footage, and simultaneously
makes LZSS *worse* (68.01% → 71.90%), because a fixed threshold matrix holds background pixel indices
stable between frames while error diffusion re-randomises them. The keyframe-favouring frame fraction
collapses from 96.16% to 0.33%.

Note where that lands: **SVX2 + Bayer (68.06%) matches the best size any codec reached on this
footage** — LZSS + Floyd's 68.01% — while decoding ~27× faster and needing no code change at all.
The quality cost measured on this corpus is **0.24 dB** (31.66 → 31.42); the benchmark doc records
0.06 dB on the uncropped v1 interval, against 2.49 dB on the smooth night leg. Real film grain
already looks like dither noise, so on exactly the content where the crossover appears, Bayer is
close to free.

### P1 — the cadence model

Model, calibrated against the two recorded operating points before use. Costs in VBlanks per packet:
keyframe `600/537 = 1.117` (staged specialization, Option C), delta `600/674 = 0.890` slow ROM and
`600/754 = 0.796` FastROM (hardest stream slice). The shipped schedule decodes one packet per
interval and does not split a decode across intervals, so a packet costing more than one VBlank
consumes **two slots** and anything under one consumes **one**. With `φ` the keyframe fraction:

```math
\text{effective fps} = 60 \cdot \frac{N}{2m + (N-m)} = \frac{60}{1 + \varphi}
```

**Maximum keyframe fraction, by the rate you insist on holding:**

| hold at least | φ ≤ | i.e. one keyframe per |
|---|---:|---:|
| exact 60 fps | **0%** | never |
| 59.94 fps (NTSC nominal) | 0.1001% | 999 frames |
| **59.50 fps (what `K=120` ships)** | **0.8403%** | **119 frames** |
| 59.00 fps | 1.6949% | 59 frames |
| 58.00 fps | 3.4483% | 29 frames |
| 55.00 fps | 9.0909% | 11 frames |
| 30.00 fps | 100% | every frame |

**The shipped `K=120` policy already spends the entire 60 fps keyframe budget.** At 59.50 fps the
budget is one keyframe per 119 frames, and `K=120` emits one per 120. A chooser at 60 fps therefore
has **no keyframes to spend** — every keyframe it adds beyond the seek grid comes straight off the
frame rate. At 30 fps the picture inverts completely: each frame owns a 2-VBlank slot, both packet
kinds fit inside one (1.117 ≤ 2, 0.890 ≤ 2), and φ ≤ 100% — the chooser is entirely unconstrained.

**What the chooser actually buys, on the hardest corpus** (Apollo real-time control, Floyd, 600 f;
baseline `K=120` = 2,099,896 B):

| budget φ | keyframes | bytes | saving vs `K=120` | effective fps |
|---:|---:|---:|---:|---:|
| 0% | 0 | 2,100,315 | −419 B | 59.90 |
| **0.833% (the 59.50 fps budget)** | **4** | **2,099,466** | **430 B (0.02%)** | **59.60** |
| 1% | 6 | 2,098,956 | 940 B (0.04%) | 59.41 |
| 5% | 30 | 2,093,824 | 6,072 B (0.29%) | 57.14 |
| 10% | 60 | 2,088,419 | 11,477 B (0.55%) | 54.55 |
| 100% (all-intraframe) | 600 | 2,039,145 | 60,751 B (2.89%) | 30.59 |

Read the last row carefully: **even spending every frame as a keyframe — halving the frame rate —
recovers only 2.89% of bytes**, against the 10.11 points LZSS is ahead by. SVX2's keyframes are a
PackBits coder over the whole frame; they are not a competitive intraframe coder, so the "the chooser
might need no new codec at all" hope in the plan body does not survive contact with the numbers.

### P1b — the free chooser, measured because it costs no cadence at all

One variant genuinely costs nothing in VBlanks: keep the **same keyframe count** as fixed-`K`, but
place each window's keyframe on the frame where a keyframe helps most, instead of on the grid. Same
φ, same fps, same decoder; the price is that the seek gap becomes variable rather than exactly `K`.

| corpus | `K` | fixed-`K` bytes | best-placement bytes | saving | worst seek gap |
|---|---:|---:|---:|---:|---:|
| Apollo real-time control, Floyd | 120 | 2,099,896 | 2,099,391 | 505 B (0.02%) | 205 frames |
| Apollo real-time control, Bayer | 120 | 1,829,582 | 1,828,101 | 1,481 B (0.08%) | 198 frames |
| Artemis night launch, Floyd | 60 | 766,569 | 765,807 | 762 B (0.10%) | 98 frames |
| Artemis apollo mixed reel (shipped) | 120 | 3,235,506 | 3,230,938 | 4,568 B (0.14%) | 200 frames |

At most 0.14%, in exchange for a seek gap that nearly doubles. Not worth the transport risk.

## Explicit non-goals

- Not reopening the codec choice. LZSS stays a comparison baseline.
- Not adding a new intraframe coder. If SVX2's keyframes are not competitive enough, that is a P2
  finding, not licence to write a third codec.
- No interpolation, no re-timing, no content changes — this is a coding-decision question measured
  on corpora that already exist.

## Verification

Steps 1-4 run 2026-08-04 on `throwaway/interframe-crossover`. Step 5 (the confirming run) ran
2026-08-04 directly on `main`, using the shared `build/` toolchain read-only (no rebuild) — it is
measurement against the actual shipped corpus artifact, not a spike, so it belongs where the corpus
identity (`dev/apollo-reel.sh`'s `RGB_SHA`) is checked in.

1. P0 emits a per-frame table for every corpus/dither already recorded; totals reconcile to the
   aggregate byte counts in the benchmark doc (a re-derivation that disagrees with the recorded
   totals is a bug in the measurement, not a finding).

    ```
    $ PYTHONPATH=tools python3 tools/snes-video-crossover.py \
          build/real-video-floyd.tiles --label "Artemis I night launch, Floyd (300 f)"
    == Artemis I night launch, Floyd (300 f) ==
    corpus          /home/will/llvm-mos-65816/build/real-video-floyd.tiles
    sha256          2a4249437c3253c87c1ad9b0dfb4da31c19e6cc497fea51ac603cba6548d154b
    frames          300   raw 1,344,000 B

    -- P0: per-frame crossover (frames 1..N-1; frame 0 is forced key) --
    keyframe smaller than delta       15 / 299 = 5.02%
    delta   - key   mean              -144.8 B
    delta   - key   median            -127.0 B
    delta   - key   p05               -345.0 B
    delta   - key   p25               -194.0 B
    delta   - key   p75                -64.0 B
    delta   - key   p95                  6.0 B
    delta   - key   min / max         -1,493 / 161 B
    total available saving               618 B (0.05% of raw)
      concentrated? top 1% of frames (2) carry 37.9% of it
      contiguity: 12 runs of keyframe-favouring frames, longest 3, mean 1.2

    -- reconciliation: fixed-K totals (must match the benchmark doc) --
    K=15      768,739 B  (57.20% of raw)  keyframes   20  effective 56.25 fps
    K=30      767,263 B  (57.09% of raw)  keyframes   10  effective 58.06 fps
    K=60      766,569 B  (57.04% of raw)  keyframes    5  effective 59.02 fps
    K=120     766,314 B  (57.02% of raw)  keyframes    3  effective 59.41 fps
    ```

    **PASS, partially.** `K=60 → 766,569 B (57.04%)` is byte-exact against the benchmark doc's
    recorded `svx2-replacement-copy ki=60 packed=766569 (57.04%)`, on a corpus whose SHA-256 also
    matches the record. That is a clean reconciliation and it validates the tool.

    It is **not** "every corpus/dither already recorded", and the shortfall is a provenance fact
    rather than a measurement bug: the Apollo v2/v3 tile corpora and the Artemis Bayer corpus are
    gone and cannot be rebuilt, because both need source masters that are deliberately not vendored
    (the Apollo master is 2.37 GB). The vendored 10.01 s Apollo excerpt is a re-encode, so the
    **real-time control** corpus re-derives to within 0.08 points on every variant but not
    byte-exactly — see the reconciliation table in [Results](#results-2026-08-04). Recorded plainly
    rather than papered over.

2. P0b's 59.94 fps point is recorded beside the 30 fps one, not replacing it.

    **PASS.** The three-frame-rate table (1/15 s, 1/30 s, 1/59.94 s) in the P0b phase section is
    untouched; the 2026-08-04 work adds the Bayer dither experiment *below* it as a new subsection,
    and the [Results](#results-2026-08-04) section states explicitly that nothing above is
    overwritten.

3. P1's cadence model reproduces the two known operating points (K=120 → 59.50 fps effective;
   keyframe = 1.12 VBlanks) before being trusted for a prediction.

    ```
    -- P1 model calibration against the two recorded operating points --
    keyframe cost   600/537 = 1.1173 VBlanks  (recorded 1.12)  slots=2
    delta slow ROM  600/674 = 0.8902 VBlanks  (674/600)      slots=1
    delta FastROM   600/754 = 0.7958 VBlanks  (754/600)      slots=1

    check 1: the K policy must reproduce the recorded K=120 -> 59.50 fps
      K=15   phi= 6.667%  effective 56.25 fps
      K=30   phi= 3.333%  effective 58.06 fps
      K=60   phi= 1.667%  effective 59.02 fps
      K=120  phi= 0.833%  effective 59.50 fps
      K=240  phi= 0.417%  effective 59.75 fps

    check 2: maximum keyframe fraction phi that holds a floor;  fps = 60/(1+phi)
      hold >= 60.00 fps exact 60             phi <=   0.0000%   = 1 keyframe per inf frames
      hold >= 59.94 fps NTSC 59.94           phi <=   0.1001%   = 1 keyframe per 999.0 frames
      hold >= 59.50 fps shipped K=120 floor  phi <=   0.8403%   = 1 keyframe per 119.0 frames
      hold >= 59.00 fps                      phi <=   1.6949%   = 1 keyframe per 59.0 frames
      hold >= 58.00 fps                      phi <=   3.4483%   = 1 keyframe per 29.0 frames
      hold >= 55.00 fps                      phi <=   9.0909%   = 1 keyframe per 11.0 frames
      hold >= 30.00 fps 30 fps slot          phi <= 100.0000%   = 1 keyframe per 1.0 frames

    check 3: at a 30 fps presentation each frame owns a 2-VBlank slot
      keyframe 1.117 <= 2 fits;  delta 0.890 <= 2 fits  => phi <= 100%, unconstrained
    ```

    **PASS.** Both anchors reproduce: the keyframe cost derives to 1.1173 VBlanks from the recorded
    `537 per 600 VBlanks`, matching the recorded 1.12; and `K=120 → 59.50 fps` falls out of the model
    without fitting. Only then is the φ table used for prediction.

4. P2's decision is written down with the numbers that drove it, whichever way it goes.

    **PASS.** The decision is recorded in [P2 decision](#p2-decision-2026-08-04) below: don't build
    the chooser, adopt `--dither bayer` as a per-corpus flag. The confirming run required by that
    decision is step 5.

5. **Confirming run (2026-08-04): `--dither bayer` on the actual shipped Apollo corpus**, not the
   reconstruction P0b used. `dev/apollo-reel.sh` (as of `bc66ad5`) hardcodes the shipped corpus's
   `RGB_SHA` — a byte-identical match to a scratchpad copy is the strongest available proof this is
   the real thing, since the master `.mp4` (`assets/snes/video/apollo11-daylight-5994p.mp4`) is
   vendored but the intermediate `.rgb`/`.tiles` are not.

    ```
    $ sha256sum apollo-daylight.rgb
    aa29061311e022e8bafb0e013c09da5ea11d4c9114df4732f9b1452157573cad
    $ grep RGB_SHA dev/apollo-reel.sh
    RGB_SHA=${APOLLO_REEL_RGB_SHA:-aa29061311e022e8bafb0e013c09da5ea11d4c9114df4732f9b1452157573cad}
    ```

    **PASS.** SHA-256 match — this is the corpus `dev/apollo-reel.sh` actually bakes into the
    published ROM.

    Re-packed with `tools/snes-video-pack.py --rgb24 --dither floyd --keyframe-interval 120`
    (`apollo-reel.sh`'s own `KEYFRAME=120` default) as a recipe check before touching Bayer at all:

    ```
    $ sha256sum apollo-v3/apollo-daylight-floyd.tiles apollo-confirm/apollo-daylight-floyd.tiles
    08c24756b982fec8703d5959cf8b6af06e8981beef1a6bdc55edd20c1675ce10  apollo-v3/apollo-daylight-floyd.tiles
    08c24756b982fec8703d5959cf8b6af06e8981beef1a6bdc55edd20c1675ce10  apollo-confirm/apollo-daylight-floyd.tiles
    $ sha256sum apollo-v3/apollo-daylight-floyd.pal apollo-confirm/apollo-daylight-floyd.pal
    9d03a6d40db385e782bda34f5beddd95420e76c7293c2e9e236d905e422e27a0  apollo-v3/apollo-daylight-floyd.pal
    9d03a6d40db385e782bda34f5beddd95420e76c7293c2e9e236d905e422e27a0  apollo-confirm/apollo-daylight-floyd.pal
    ```

    **PASS.** Byte-identical quantized tiles and palette against the shipped v3 artifact — the
    recipe (`--dither floyd --keyframe-interval 120`) exactly reproduces what shipped, so running
    the same recipe with `--dither bayer` on this RGB is a true apples-to-apples confirming
    measurement, not a fresh reconstruction. (The `.svx2` bytes differ, because `apollo-reel.sh`
    packs the final stream through `snes-video-reel-assets.py --packed-far
    --dashboard-palette-fixup`, not `snes-video-pack.py` directly — irrelevant here since
    `snes-video-crossover.py` operates on `.tiles`, not the packed-far container.)

    `tools/snes-video-crossover.py --fixed-k 120` on both dithers of the shipped corpus:

    ```
    == Apollo SHIPPED v3 corpus, floyd ==
    frames          600   raw 2,688,000 B
    keyframe smaller than delta      596 / 599 = 99.50%
    K=120   2,121,044 B  (78.91% of raw)  keyframes    5  effective 59.50 fps

    == Apollo SHIPPED v3 corpus, bayer ==
    frames          600   raw 2,688,000 B
    keyframe smaller than delta       15 / 599 =  2.50%
    K=120   1,946,651 B  (72.42% of raw)  keyframes    5  effective 59.50 fps
    ```

    Quality cost, measured directly (standalone PSNR check against the source RGB24, same
    BGR555→RGB gamma-corrected palette math as `tools/snes-video-screenshot-check.py`, all 600
    frames, no resampling):

    ```
    floyd: frames=600 mse=92.2473  psnr=28.48 dB
    bayer: frames=600 mse=103.1680 psnr=28.00 dB
    ```

    **PARTIAL — direction confirms, magnitude does not.** Bayer still wins substantially on the
    shipped corpus: **78.91% → 72.42% of raw, a 6.49-point / 174,393 B saving**, at a **0.48 dB**
    PSNR cost — small next to the smooth night-launch leg's recorded 2.49 dB, and the
    keyframe-favouring pathology still collapses (99.50% → 2.50% of frames, matching the P0b
    mechanism exactly). But the P0b prediction was **10.06 points / 270,314 B** (78.12% → 68.06%)
    at 0.24 dB — this run recovers only **~65% of the predicted point-gap** (6.49 of 10.06) and
    **~65% of the predicted bytes** (174,393 of 270,314), while the PSNR cost is about **double**
    the prediction (0.48 vs 0.24 dB). The two corpora are not the same footage: P0b's
    "real-time control" corpus is `--start 0 --duration 10.01 --fps 60000/1001` (true 1:1 60 fps
    sampling, no speed change); the shipped v3 corpus is `--start 3410 --duration 20.02
    --fps 30000/1001` (the 2× playback recut, 30 fps sampling of a different 20 s interval). Per
    this run's constraints, that gap is recorded as a finding, not tuned away — no parameter was
    adjusted to chase the predicted number. **No change to the P2 decision below**: Bayer is still
    a clear net win on this hard-content corpus (6.49 pts for 0.48 dB is a good trade), just a
    smaller one than the reconstruction suggested, which matters for calibrating expectations on
    *other* corpora, not for this one's decision.

    Not measured: the smooth-leg PSNR cost was **not re-derived** here — the Artemis I night-launch
    source `.mp4` is not vendored and no RGB24 copy survives (established in
    [Corpus availability](#corpus-availability--what-could-and-could-not-be-re-derived) above), so
    there is no corpus to re-run it on. The 2.49 dB figure this run cites is the one already on
    file in
    [`real-video-codec-benchmark.md`](2026-07-30-lzss-gallery-exhirom-video-boundary-test/real-video-codec-benchmark.md#L80-81).

### Reproducing this run

```
git worktree add -b throwaway/interframe-crossover ../llvm-mos-65816-crossover main
tools/snes-video-rgb24-convert.sh --start 0 --duration 10.01 --fps 60000/1001 \
    --crop 'iw/2:ih/2:iw/4:ih/3' \
    assets/snes/video/apollo11-daylight-5994p.mp4 build/apollo-rt-control.rgb
for d in floyd bayer; do
  PYTHONPATH=tools python3 tools/snes-video-pack.py --rgb24 --dither $d \
      --keyframe-interval 120 --tiles-output build/apollo-rt-$d.tiles \
      --palette-output build/apollo-rt-$d.pal build/apollo-rt-control.rgb build/apollo-rt-$d.bin
  PYTHONPATH=tools python3 tools/snes-video-crossover.py build/apollo-rt-$d.tiles --label "apollo-$d"
done
```

Intermediate `.rgb`/`.tiles` are large and stay out of git; only the tool and this record are kept.

### Reproducing the confirming run (step 5, shipped corpus)

```
# RGB corpus per dev/apollo-reel.sh's own recipe (its header comment + $RGB_SHA):
tools/snes-video-rgb24-convert.sh --start 3410 --duration 20.02 --fps 30000/1001 \
    --crop 'iw/2:ih/2:iw/4:ih/3' \
    assets/snes/video/apollo11-daylight-5994p.mp4 apollo-daylight.rgb
sha256sum apollo-daylight.rgb   # must be aa29061311e022e8bafb0e013c09da5ea11d4c9114df4732f9b1452157573cad

for d in floyd bayer; do
  PYTHONPATH=tools python3 tools/snes-video-pack.py --rgb24 --dither $d \
      --keyframe-interval 120 --tiles-output apollo-daylight-$d.tiles \
      --palette-output apollo-daylight-$d.pal apollo-daylight.rgb apollo-daylight-$d.svx2
  PYTHONPATH=tools python3 tools/snes-video-crossover.py apollo-daylight-$d.tiles \
      --label "apollo-$d" --fixed-k 120
  python3 tools/snes-video-psnr-check.py apollo-daylight.rgb \
      apollo-daylight-$d.tiles apollo-daylight-$d.pal
done
```

Same tool, same `--keyframe-interval 120`, only the corpus changes (the shipped v3 recut instead of
the P0b reconstruction) — this is what makes the two runs comparable.

## RECOMMENDATION (P2 input — the decision itself stays open)

**Do not build the per-frame codec chooser. Instead, make the dither a per-corpus encoder choice and
select Bayer for grain-rich content.**

The chooser fails on arithmetic, not on principle, and it fails for a different reason than P0
anticipated. P0 expected to find the keyframe-favouring frames rare and clustered at shot cuts; they
are neither — on hard content **96.16%** of frames prefer a keyframe, sustained across runs of up to
265 frames on a shot with no cuts. The distribution is as favourable as it could possibly be. What
kills the chooser is P1: at 60 fps the entire keyframe budget is **0.84% of frames**, the shipped
`K=120` seek grid already consumes all of it, and so the chooser's realisable saving on the hardest
corpus is **430 B out of 2,099,896 B — 0.02%**. Even the unconstrained limit, every frame emitted as
a keyframe at 30.59 fps, recovers only **2.89%**, because SVX2's keyframes are whole-frame PackBits
and are simply not a competitive intraframe coder. The plan's hope that "the chooser might need no
new codec at all" is the thing the measurement refutes.

Against that, the dither experiment the plan itself proposed as a cheap prior turns out to be the
whole answer. On byte-identical footage, Bayer takes SVX2 from 78.12% to **68.06%** of raw —
**270,314 B, 10.06 points, roughly 630× what the affordable chooser can buy** — at zero cadence cost,
zero decoder change, zero encoder complexity, and no seek-granularity regression. It lands SVX2 level
with the best size *any* measured codec achieves on this footage (LZSS + Floyd at 68.01%) while
decoding ~27× faster, which retires the LZSS-beats-SVX2 inversion outright rather than narrowing it.
The cost is **0.24 dB** PSNR on this corpus (0.06 dB on the v1 interval) — because real film grain
already resembles dither noise, so error diffusion buys almost nothing on exactly the content where
the crossover appears. That trade is not close.

Two caveats the decision should weigh, both pointing at scope rather than direction. First, Bayer is
*not* a global default: on the smooth night-launch leg it costs 2.49 dB, which is a real visible
price, so this should be a per-corpus encoder flag chosen on measured grain, not a blanket switch —
the existing `--dither` argument already provides the mechanism, so the "build" here is a selection
rule plus a recorded threshold, not a feature. Second, the Bayer number was measured on a *re-derived*
corpus; it reconciles to within 0.08 points on every variant, which is ample for a 10-point effect,
but if the decision turns on it, the confirming step is to re-run `--dither bayer` on the actual
shipped Apollo corpus during the next encode rather than on this reconstruction.

If P2 nonetheless wants a chooser, the honest framing is that it is a **30 fps feature**: at a 30 fps
presentation every frame owns a 2-VBlank slot, both packet kinds fit, φ ≤ 100%, and the full 2.89% is
available. At 60 fps there is no budget to spend.

## P2 decision (2026-08-04)

**Don't build the chooser.** The numbers force it: at 60 fps the cadence budget (φ ≤ 0.8403%) is
already fully spent by the `K=120` seek grid, leaving a realisable chooser saving of 430 B on a
2.1 MB corpus (0.02%); even the all-keyframe ceiling (2.89% at 30.59 fps) is dwarfed by what
dithering buys for free. The chooser is recorded as a 30 fps-only feature with no current customer.

**Adopt the dither lever instead:** per-corpus `--dither bayer` on measured grain (not a blanket
switch — it costs 2.49 dB on the smooth night leg). Follow-up tracked in `TODO.md`: confirm the
10.06-point win on the actual shipped Apollo corpus at the next encode, then record the selection
threshold. Decision made at the orchestrator tier on the strength of the P0/P1 evidence above;
reopen only if a 30 fps presentation ever becomes a shipping target.

## Confirming run (2026-08-04): does the win hold on the shipped corpus?

Full measurement and raw output is [Verification step 5](#verification); summary here for anyone
reading only the decision:

| corpus | dither | SVX2 K=120 | % of raw | PSNR | keyframe-favouring frames |
|---|---|---:|---:|---:|---:|
| P0b reconstruction (predicted) | Floyd | 2,099,896 B | 78.12% | 31.66 dB | 96.16% |
| P0b reconstruction (predicted) | Bayer | 1,829,582 B | 68.06% | 31.42 dB | 0.33% |
| **shipped v3 corpus (measured)** | Floyd | 2,121,044 B | 78.91% | 28.48 dB | 99.50% |
| **shipped v3 corpus (measured)** | Bayer | 1,946,651 B | 72.42% | 28.00 dB | 2.50% |

**Direction confirms; magnitude does not — recorded as-is, not tuned.** The shipped corpus is a
different clip (2× recut, different interval — see step 5) from the P0b reconstruction, and it
gives a **6.49-point / 174,393 B** win at **0.48 dB** cost, against a predicted **10.06-point /
270,314 B** win at **0.24 dB**. Bayer is still unambiguously worth it here (roughly 65% of the
predicted saving, at roughly double the predicted quality cost, still 5× cheaper than the smooth
leg's 2.49 dB) — but anyone budgeting bytes off the P0b number for *other* corpora should expect
figures in this range, not the reconstruction's, since the reconstruction and the shipped clip
are not the same footage.

### Selection rule: when to flip `--dither bayer` per corpus

No global grain metric was built (out of scope for a measurement-only confirming run) — the rule
is procedural, using tools already in the repo, and both anchor points now come from *measured*
runs rather than one measured and one predicted:

1. **Encode the candidate corpus both ways** — `tools/snes-video-pack.py --rgb24 --dither floyd`
   and `--dither bayer`, same `--keyframe-interval` as the ship config — and diff the `.svx2` sizes.
   A same-footage A/B is cheap (two encodes) and removes any need to eyeball "how grainy does this
   look."
2. **Check the PSNR cost** with [`tools/snes-video-psnr-check.py`](../../tools/snes-video-psnr-check.py)
   (new in this run — palette-aware, decodes the tiles+palette pair back to RGB with the same gamma
   math `snes-video-screenshot-check.py` uses and diffs it against the source RGB24; no tool
   previously existed to reproduce the PSNR figures this plan already cited). Three recorded
   operating points bound the decision:
   - **≤0.5 dB cost** (Apollo hard content, real film grain: 0.24–0.48 dB measured) → **flip to
     Bayer**. The size win (6.5–10 points here) dominates a quality cost this small; SVX2's
     interframe delta was fighting dither noise, not signal, and Bayer removes the noise.
   - **≥2 dB cost** (Artemis smooth night launch: 2.49 dB) → **stay Floyd**. The size win exists
     there too (recorded in the [top table](#the-observation): 57.04% → 33.49%, huge) but the
     visible banding on already-smooth, already-denoised footage is a real quality regression, not
     a rounding error — Floyd's error diffusion is doing real work on genuinely smooth gradients.
   - **Between 0.5 and 2 dB**: no corpus has landed here yet. Treat it as a size-vs-quality judgment
     call at publish time, not an automatic flip, until a corpus in that band is measured.
3. **The underlying signal, if a cheaper proxy is ever wanted**: Bayer's win tracks the
   keyframe-favouring-frame fraction collapsing (Floyd 96–99.5% → Bayer 0.3–2.5% on Apollo; no
   equivalent measurement survives for Artemis, corpus gone). That fraction is a byproduct of
   `tools/snes-video-crossover.py`'s P0 output, already computed in step 1 above, so it is not an
   extra measurement — just a number to read off a report already being generated. A high fraction
   under Floyd (footage where interframe deltas are mostly fighting dither noise rather than real
   motion) is what makes Bayer worth trying at all; smooth footage with a low Floyd fraction has
   little to gain and more to lose.
