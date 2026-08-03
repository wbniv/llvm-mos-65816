# Where interframe coding stops paying — measure the crossover, then decide

**Date:** 2026-08-03 · **Status:** PLANNED
**Item:** TODO `[T4]` · **Visible surface:** none until a decision is taken — no mockups.

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

## Explicit non-goals

- Not reopening the codec choice. LZSS stays a comparison baseline.
- Not adding a new intraframe coder. If SVX2's keyframes are not competitive enough, that is a P2
  finding, not licence to write a third codec.
- No interpolation, no re-timing, no content changes — this is a coding-decision question measured
  on corpora that already exist.

## Verification

1. P0 emits a per-frame table for every corpus/dither already recorded; totals reconcile to the
   aggregate byte counts in the benchmark doc (a re-derivation that disagrees with the recorded
   totals is a bug in the measurement, not a finding).
2. P0b's 59.94 fps point is recorded beside the 30 fps one, not replacing it.
3. P1's cadence model reproduces the two known operating points (K=120 → 59.50 fps effective;
   keyframe = 1.12 VBlanks) before being trusted for a prediction.
4. P2's decision is written down with the numbers that drove it, whichever way it goes.
