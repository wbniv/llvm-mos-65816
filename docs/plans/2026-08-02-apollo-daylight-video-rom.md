# Apollo 11 daylight launch — the hard-content video cartridge

**Date:** 2026-08-02 · **Status:** IN PROGRESS — ROM + gate built, gate green; publication pending
one open doubt (below)
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

---

## Results (2026-08-02, `dev/apollo-reel.sh`)

**Status: SHIPPED — [live at biohack.net/snes/apollo-daylight/](https://biohack.net/snes/apollo-daylight/).**
Deliverables landed as `examples/snes/apollo-reel.c`, `examples/snes/apollo-reel-fast.s`,
`dev/apollo-reel.sh`, and three opt-in flags on the existing `tools/snes-video-reel-assets.py`.
Commits: `c1a667f` (llvm-mos-65816), `ad87374` + tag `v1.0.357` (biohack.net). Full gate output below.

### Open questions, answered

**1. Capacity / mapping — ordinary HiROM, comfortably.** The packed stream is **848,527 B**
(837,028 sequential delta packets + 8,465 seek keyframes + 3,034 loop delta), against the Artemis
reel's 2,360,380 B. Apollo is *denser per frame* (2,790 B/frame vs 2,622, +6.4%) but only a third
as long, so the whole cartridge is **1,048,576 B = 8 Mbit HiROM** — code in bank `$C0`, stream from
`$C1`. HiROM's `$C1`–`$FF` holds 4,128,768 B, so the stream uses 13 of 63 available banks.
**No ExHiROM path is needed and none was used.**

**2. Keyframe policy — Option A K=120 stands, unchanged.** Measured seek-keyframe cost at three
intervals:

| K | seek keyframes | seek bytes | B/keyframe | total stream |
|---:|---:|---:|---:|---:|
| 30 | 10 | 28,112 | 2,811 | 868,174 |
| 60 | 5 | 14,055 | 2,811 | 854,117 |
| **120** | **3** | **8,465** | **2,822** | **848,527** |

An Apollo seek keyframe costs **2,822 B vs the Artemis reel's 2,793 B — +1.0%**, i.e. essentially
unchanged: a PackBits keyframe is near-incompressible on both. Nothing here argues for moving K,
and larger K is strictly smaller in this structure, so K=120 was kept.

*Note on an apparent conflict:* the benchmark doc's keyframe sweep concludes "keep the existing
60-frame interval." That sweep measures a **different structure** — keyframes interleaved *inside*
the sequential stream (where a larger interval trades against delta drift). The reel/Apollo emitter
puts only frame 0 in the sequential stream and keeps seek keyframes in a **separate table**, so
raising K only removes table entries and is monotonically smaller. Both statements are correct
about their own structure.

**3. Asset emitter — extends cleanly; no sibling needed.** `tools/snes-video-reel-assets.py` gained
three opt-in flags and no new file: `--frame-checks` (per-frame Fletcher16 + the final decoded
frame, for the whole-loop gate), `--dashboard-palette-fixup` (the Apollo corpus quantizer used
palette entry 1 for near-white `0x77ff`; the flag rewrites entries 0/1 to the HUD's black/white —
**tiles and stream are untouched**, display colour only), and `--palette-output` (writes the
effective palette for the screenshot checker). Behaviour-preservation was proven, not assumed:
old-vs-new emitter on identical input produced a **byte-identical header and stream**.

### Cadence, next to the Artemis figures

| ROM | content | presented / 600 VBlanks | deadline slips |
|---|---|---:|---:|
| Artemis reel (baseline) | night launch, smoothed | 674/600 hardest slice | 0 |
| **Apollo, slow ROM** | **daylight film grain** | **300 / 600** | **0** |
| **Apollo, FastROM** | **daylight film grain** | **300 / 600** | **0** |

**No regression.** At the 2-VBlank cadence both builds present exactly 300 frames per 600 VBlanks —
a locked 30 fps — with zero deadline slips. The +5.29 ratio points of hard-content cost land as
cartridge bytes, not dropped frames: a larger packet still stages and decodes inside the 2-VBlank
budget. (The Artemis 674/600 figure is its 1-VBlank/60 fps slice and is not the same operating
point; the like-for-like statement is that neither content slips at its target cadence.)

Boot-time note, measured: the whole-loop validation pass costs ~2,200 VBlanks on FastROM and
~2,400 on slow ROM for 301 checked decodes. The C Fletcher loop (4,480 iterations/frame over WRAM)
dominates, which is why FastROM barely helps — it is a one-time boot cost, not a playback cost.

### Raw gate output

```
==> 1) asset bake reproduces the recorded corpus SHA-256
  PASS: RGB24 corpus a78c4c8c96ba7a00e99475b9545466b21cd12a041597d867994318a33f514080
frames=300 packets=837028 seek=8465 loop=3034 total=848527 max=3034
  tiles  sha256 fe7df9734b2419cc53784eb246e4dde62b4a6c898becb4a6fb307fbfbb1dd931
  stream sha256 e15f0b2ea933bbef6f58549e17dd496ebefa74d31510140637d4be78da06abaa
  stream bytes  848527

==> 2) whole-loop byte-correct decode (all 300 frames + loop delta)
  PASS: slow corpus gate: SMOKE: PASS off=0x2B len=1 got=0x00 (ran 6000 frames, bsnes-jg)
  PASS: slow composite health: SMOKE: PASS off=0x2C len=4 got=0x00000000 (ran 6000 frames, bsnes-jg)
  PASS: fastrom corpus gate: SMOKE: PASS off=0x2B len=1 got=0x00 (ran 6000 frames, bsnes-jg)
  PASS: fastrom composite health: SMOKE: PASS off=0x2C len=4 got=0x00000000 (ran 6000 frames, bsnes-jg)

==> 2b) negative control: one flipped stream byte must FAIL the gate
  flipped stream byte 400000: 0x78 -> 0x79
  PASS: corrupted stream rejected: SMOKE: FAIL off=0x2B len=1 got=0x02 want=0x00

==> 3) cadence: presented frames per 600 VBlanks
  build       presented    vblanks     per600      slips
  slow              300        600        300          0
  fastrom           300        600        300          0
  (reported, not gated — a slower number on this content is the measurement)

==> 4a) -verify-machineinstrs clean
  PASS: no verifier complaints

==> 4b) picture is independent of power-on entropy (None/Low/High x2)
  PASS: one picture across all six boots (A414FAD1:#000000)

==> 5) frame capture
  PASS: captured frame 150: SMOKE: PASS off=0x36 len=2 got=0x0096 (ran 6000 frames, bsnes-jg)

ROM=build/apollo-daylight.sfc
ROM_SHA256=262f62e7db3cdecbd0d3622bddebaeb4c0ad5ed1542efbeb78933ae38b09df3c
GATE: PASS
```

**Steps 1–4: PASS.**

### Step 5 — published page live; served ROM sha matches the gate-verified binary

Verified the CI-only way (per the `site-builds-are-ci-only` memory: a host `pnpm build` is void as
evidence in either direction, so the evidence is the deploy-run conclusion plus live fetches).

```
$ gh run list --workflow deploy.yml --limit 2
completed  success  feat(snes): publish the Apollo 11 daylight-launch video cartridge  Deploy site  v1.0.357  push  30760109164  2m46s  2026-08-02T18:00:04Z
completed  success  feat(snes): publish native 60fps ExHiROM reel                      Deploy site  v1.0.356  push  30759485452  2m50s  2026-08-02T17:42:48Z

$ curl -fsSL https://biohack.net/play/roms/apollo-daylight.sfc | sha256sum
262f62e7db3cdecbd0d3622bddebaeb4c0ad5ed1542efbeb78933ae38b09df3c
$ sha256sum build/apollo-daylight.sfc
262f62e7db3cdecbd0d3622bddebaeb4c0ad5ed1542efbeb78933ae38b09df3c
MATCH — the served ROM is the gate-verified binary (1,048,576 B)

page   /snes/apollo-daylight/  HTTP 200   <title>Apollo 11 Daylight Launch — bioHACK•NET</title>
preview                        HTTP 200
manifest roms: 120             apollo entry present: True
selfcheck: {"off":"0x2C","len":4,"want":"0x00000000","frames":4000}
category rendered: Video Playback
```

Live URL: **[https://biohack.net/snes/apollo-daylight/](https://biohack.net/snes/apollo-daylight/)**.
Filed under **Video Playback**, not
Cartridge & Mapping Tests — that shelf is for mapper canaries; this is content. The collection
(120 entries) and `roms/manifest.json` (120 roms) moved together, so the build-time count guard
passed. The page's **Verify fidelity** button runs the build gate's own assert; the negative-control
ROM fails that same assert (`got=0xFFFFFFFF want=0x00000000`), so the button is not decorative.

**Step 5: PASS.**

Incidental fix shipped alongside: `public/play/ENGINE_VERSION` recorded per-file hashes that had
drifted from the committed core files. CI gates that manifest only by its *version string* (which
was already correct), so this was never a failing gate — just an inaccurate record.
`bsnes-jg-player sync --check public/play` now reports a clean match against
`@wbniv/bsnes-jg-player@1.0.0`.

### Picture is real, not a green-gate-on-a-blank-screen

`dom=#000000` in the entropy fingerprint prompted an explicit check, because a black-dominant
picture would be a red flag on a *daylight* clip. Three frames captured well into playback:

| probe | unique colours | black (video region) | mean non-black RGB |
|---|---:|---:|---|
| frame 30 | 151 | 41.7% | (114, 156, 163) |
| frame 150 | 152 | 41.7% | (96, 124, 119) |
| frame 260 | 157 | 41.2% | (74, 112, 119) |

Pairwise over the 256×192 video region: **54.8–57.8% of pixels differ** between probes, mean |Δ|
12.9–29.6. The picture is bright blue-teal with real motion, and visibly progresses (flame grows,
rocket climbs, HUD clock advances 00:05 → 00:08). `dom=#000000` is simply the Mode 7 letterbox
border, which is the most common single colour in a 256×224 raster holding an inset video.
**Not a vacuous gate.**

### Post-publication defect: the shipped ROM booted to 37 seconds of black (FIXED)

**Reported by the user against the live page: "no title screen, no video, always black."** They were
right, and every gate above had passed anyway — this is the important part.

Root cause was a design error in this ROM, not in the codec. The first cut ran `validate_loop()`
**force-blanked, ahead of the title screen**. That pass is a bit-serial Fletcher sweep over 301
decoded frames and costs ~2,200 VBlanks, so the cartridge showed a **100% black screen for its
first 36.6 s**. Measured on the shipped binary:

```
VBlank    60 (~ 1.0s): black=100.0%  unique_colours=  1  BLACK SCREEN
VBlank   900 (~15.0s): black=100.0%  unique_colours=  1  BLACK SCREEN
VBlank  1800 (~30.0s): black=100.0%  unique_colours=  1  BLACK SCREEN
VBlank  2200 (~36.6s): black=  3.6%  unique_colours=  4  has picture
VBlank  2400 (~39.9s): black= 48.8%  unique_colours=138  has picture
```

`snes-video-reel.c` warns about exactly this and I did not heed it: *"Exhaustive round-trip and
target CRC validation belongs to the build gate … so the title remains an introduction rather than
a loading screen."*

**Why the gate missed it:** every WRAM assert ran with a 3,000–6,000 VBlank budget and only ever
sampled the *end* state. Nothing looked at the screen during the first minute. A gate that only
inspects the destination cannot see a broken journey.

**Fix.** Boot validation is now `-DAPOLLO_REEL_SELFTEST`, built and gated by `dev/apollo-reel.sh`
but never shipped. The published ROM goes straight to the title. New boot timeline:

```
VBlank  30 (~0.5s): black=100.0% colours=  1  BLACK (normal power-on)
VBlank  60 (~1.0s): black=  3.6% colours=  4  title card
VBlank 180 (~3.0s): black= 49.4% colours=158  video playing
```

The whole-loop byte-correct requirement is **undiminished** — it is still proven on bsnes-jg, on
both slow and FastROM self-test builds, with the same negative control. Only its *location* moved,
from the shipped cartridge to the gate, which is where the plan's own bar ("byte-correct decode …
on bsnes-jg") always placed it.

**Regression guard, shipped in the same commit as the fix.** `dev/apollo-reel.sh` step 6 renders the
*published* ROM at VBlank 180 and fails if the frame is ≥98% black or has ≤2 distinct colours. It
reproduces the defect on the old binary and passes on the new one. Two page claims that the fix
falsified were also corrected rather than left standing: the manifest `selfcheck` label (which said
the button ran the whole-loop check) and the page's "Before a single pixel is shown…" paragraph.

### Recut to interval v2 — the shipped clip was visually static (FIXED)

The v1 interval passed every gate and was still the wrong clip: **a tracking shot**. The camera
follows the rocket, so at 80×56 the subject barely moves and the demo looked frozen. Measured at the
RGB24 stage, v1 had 3–4× less motion than any other corpus in the battery (mean|Δ| 0.93 vs
2.88–3.93). The gate could not have caught this — "is this interesting to watch" is not a
correctness property — but it is a real defect in a demo whose job is to be watched.

Recut per the authorized parameters, using the **same master and the same colour segment**, cropped
to the action and sampled below source rate so playback is 2×:

```
tools/snes-video-rgb24-convert.sh --start 3410 --duration 20 --fps 15 \
    --crop 'iw/2:ih/2:iw/4:ih/3' <master>.mp4 apollo-daylight.rgb
```

`--crop` and sub-source `--fps` were **added to that script** rather than hand-run, because
reproducibility is exactly why the script exists. RGB24 SHA-256 `2779e079…10f5` (300 frames,
4,032,000 B).

Motion, confirmed to survive quantization, dithering and packing all the way to the console — three
frames captured from the running ROM, pairwise over the 256×192 video region:

| | v1 (shipped) | v2 (recut) |
|---|---:|---:|
| mean\|Δ\|, frame 30 vs 150 | 23.69 | **50.81** |
| mean\|Δ\|, frame 150 vs 260 | 12.91 | **30.34** |
| % pixels differing | 54.8–57.8% | **78.7–80.0%** |
| black in video region (letterbox) | 41.7% | **20.0%** |

The crop also halved the letterbox, so the picture fills more of the screen.

**The content got much harder, which is the point.** SVX2 now compresses to **79.62%** of raw
(v1: 62.33%; Artemis night launch: 57.04%). Both intervals are recorded side by side in the
benchmark doc — the v1 numbers were not overwritten. Two findings worth carrying:

- The keyframe-interval ordering **inverts**: on v2, shorter K wins (K=15 → 1,066,921 vs
  K=120 → 1,070,154), because a delta packet on genuinely moving content costs about as much as a
  fresh keyframe. The spread is still only 3,233 B across an 8× range of K, so K=120 stays.
- The LZSS-beats-SVX2 inversion v1 hinted at (2.67 points) becomes a **14.31-point** gap
  (877,809 vs 1,070,154). Within-frame compression decisively beats between-frame compression once
  frames stop resembling each other. The codec decision is unaffected — it was speed-anchored, and
  LZSS is still ~27× too slow.

**Cadence is unchanged: 300/600 VBlanks, zero slips, on both slow ROM and FastROM.** Even a
near-worst-case 3,696-byte packet stages and decodes inside the 2-VBlank budget. The cartridge grew
to **16 Mbit (2 MiB)** Fast HiROM for the 1,083,714-byte stream; still ordinary HiROM, still no
ExHiROM.

### Deviations from the plan

- **The plan cites "the reel's whole-loop Fletcher check" as precedent; the reel has no such
  check.** `snes-video-reel.c` only CRCs a whole loop when `FRAME_COUNT <= 4`, and explicitly
  delegates exhaustive validation to the build gate. The real precedent is the **bench** ROM
  (`examples/snes/snes-video-codec-bench.c` `validate_stream()` + `tools/snes-video-bench-assets.py`
  `frame_check()`). This ROM follows the bench's mechanism and mirrors its Fletcher byte for byte.
- **No transport controls.** The reel's pause/step/shuttle transport was not carried over; this is
  a measurement cartridge and the plan asked only for looping playback. The dashboard (title, clock,
  live FPS, slip indicator) is kept.
- **No `technical` block on the published page.** The site schema makes `technical` all-or-nothing
  (it requires per-codec decode *rates* and profile *phases*). Those were not measured for this
  ROM, so rather than fabricate them the block was omitted and the real measured figures were put
  in the page prose instead.


## Progress (2026-08-02)

`examples/snes/apollo-reel.c` and `dev/apollo-reel.sh` are written and the gate reports green.

**Open doubt, being settled before publication:** the gate's entropy probe reported a dominant
picture colour of `#000000`. For a *daylight* clip — bright sky, smoke, exhaust flame — a
black-dominant frame is suspicious, and "gate green, screen blank" is a failure mode this project
has already been bitten by (the cartsize canary's entropy step passed vacuously for weeks against a
stale `jgxcheck`, and #138's producer would now be skipped silently by its own fix). So the picture
is being proven directly — frames sampled well into playback, checked for non-black content and for
*differing from each other over time* — before anything is published. If it is blank or static,
that is the finding and it outranks shipping the demo.

Still owed at close: the three open questions answered numerically, the cadence table (presented
frames per 600 VBlanks, slow and FastROM, beside the Artemis figures), and the negative-control
result.


## Follow-up: the master is 59.94 fps — true-60 is available (2026-08-03)

The shipped cartridge presents at **30 fps** (300 frames, 2 VBlanks each, zero slips). That was
never a decoder limit: `ffprobe` on the master gives **59.9401 fps**
(`r_frame_rate=220999/3687`, 1280×720, 217,855 frames), and both corpora built from it retime
59.94→30 by *discarding every other frame*. The temporal resolution is being thrown away at
conversion time, not lost to the console.

**Decision (user, 2026-08-03): fix the existing cartridge — do not add a second ROM.** Same slug,
same page, same ROM identity; the 30 fps stream is replaced by the 59.94 fps one. Two demos that
differ only in frame rate would split the story and double the maintenance for no gain, and the
30 fps version has no independent reason to exist once the source's real rate is available.
Rebuild in place from material already on disk:

| piece | state |
|---|---|
| ≥59.94 fps master | **have it** — same file, same provenance, no new acquisition |
| (and more, found 2026-08-03) | `assets/snes/video/` now holds a whole shelf of true-60 masters another session staged: `apollo11-daylight-5994p.mp4`, three Artemis II `1080p60` cuts (exactly 60/1 fps, 1920×1080) and `XRISM_360_4k_60fps_h264.mp4`. The "no true-60 content" claim was doubly wrong. |
| decoder headroom at the 1-VBlank operating point | **have it** — hardest slice 674/600 slow ROM, 754/600 FastROM |
| interval + framing | **have it** — t=3410, cropped, the climbing-plume shot, motion-validated |
| capacity | **the open question** — see below |

**Capacity is the one thing that needs deciding.** 300 frames pack to 1,083,714 B and sit in a
2 MiB Fast HiROM using 17 of 63 banks. 600 frames land near ~2.1 MB of stream, which no longer
fits a 2 MiB image: it wants 4 MiB HiROM or the ExHiROM path (both now proven by the cartridge-size
canaries and the ordinary-ROM matrix). Compute it properly before choosing — the ratio on
doubled-rate frames will not be exactly 2× the 30 fps stream, because consecutive frames at 59.94
resemble each other *more*, which is the one thing that favours the delta codec on this content.

That last point ties directly to the open crossover item: at 30 fps this footage made intraframe
LZSS beat interframe SVX2 by 14.31 points; at 59.94 fps the frames are half as far apart, so the
delta path should claw some of that back. Measuring both rates on the same interval would put a
second point on that curve for free.

Also note: at true 60 the current **2× speed-up becomes unnecessary** — the same interval plays at
real-time ascent speed with full temporal resolution, which is likely a better watch than the
sped-up version. Whether to keep the 2× (yielding a 20 s real-time span in 10 s of playback, now
at full temporal resolution) or drop it (10 s of real-time ascent) is a look-and-feel call to make
with frames in front of you, not in advance.

### What "fix in place" requires

1. Re-derive the corpus at `fps=59.94` (equivalently `60000/1001`) from the **same** interval and
   crop, via the extended `tools/snes-video-rgb24-convert.sh`; record the new SHA-256 alongside the
   30 fps one — the 30 fps ratios stay in the benchmark doc as a *second data point at a different
   rate*, not overwritten.
2. Repack Floyd, re-measure the ratio, and decide capacity from the measured stream size (2 MiB is
   already ruled out for a naive doubling; do not assume 4 MiB without the number).
3. Rebuild the ROM at whatever mapping the size demands, re-gate in full: whole-loop byte-correct
   decode, negative control, entropy fingerprint, the VBlank-180 black-screen guard, and the
   cadence table at the **1-VBlank** operating point — the metric that decides whether it really
   presents 60.
4. Republish over the same slug; update the page prose (it currently describes 2× speed and 30 fps)
   and the manifest's selfcheck if the oracle moves. Verify live sha == gate-verified binary.
5. If the measured cadence does **not** hold 60 with the harder per-frame budget, that is the
   finding — report it and keep the 30 fps cartridge live rather than shipping a slipping one.

---

## Results: fixed in place at true 59.94 fps (2026-08-03)

**Status: the cadence holds. 600 presented frames per 600 VBlanks, ZERO deadline slips, on slow ROM
*and* FastROM.** The cartridge is republished over the same slug, same page, same identity; no
second ROM exists.

### 1. Corpus re-derived at 59.94 fps

`tools/snes-video-rgb24-convert.sh` needed **no extension** — its `--fps` is passed straight through
to ffmpeg's `fps` filter and already accepts an exact NTSC fraction, and `--duration` already accepts
a fractional value. Both were exercised rather than assumed:

```
tools/snes-video-rgb24-convert.sh --start 3410 --duration 20.02 --fps 30000/1001 \
    --crop 'iw/2:ih/2:iw/4:ih/3' /tmp/apollo11-press-site-large.mp4 apollo-daylight.rgb
filter: fps=30000/1001,crop=iw/2:ih/2:iw/4:ih/3,scale=80:45:flags=lanczos,pad=80:56:0:5:black,format=rgb24
wrote apollo-daylight.rgb: 600 frames, 8064000 bytes
```

Exactly 600 frames, no trimming needed. RGB24 SHA-256
`aa29061311e022e8bafb0e013c09da5ea11d4c9114df4732f9b1452157573cad`, recorded in the benchmark doc
**alongside** v2's `2779e079…10f5`, which is untouched. The script's usage text now documents that
fractional NTSC rates are accepted, so the next person does not have to discover it.

### 2. Speed treatment: the 2× is KEPT

Decided with frames in front of me, not in advance. Both candidates were built and measured at the
RGB24 stage:

| candidate | sampling | frames | mean\|Δ\| consecutive | first-vs-last mean\|Δ\| |
|---|---|---:|---:|---:|
| v2, currently shipped | 15 fps over 20 s | 300 | 4.27 | 57.67 |
| **A — keep 2×** (chosen) | **29.97 fps over 20.02 s** | **600** | **2.82** | **58.72** |
| B — drop 2×, real time | 59.94 fps over 10.01 s | 600 | 1.62 | 42.73 |

**Chosen: A.** Two reasons, both about the defect this demo has already been bitten by. First,
dropping the 2× cuts the on-screen travel by 26 % (58.72 → 42.73) — the viewer sees the rocket climb
half as far in the same 10 s of playback. Second, consecutive-frame motion falls to **1.62**, heading
back toward the **0.93** that made the v1 tracking shot unwatchable at 80×56 and forced the recut;
2.82 sits inside the 2.88–3.93 band of every healthy corpus in the battery. True 60 is worth spending
on *smoothness*, which is what it is for — not on quietly undoing the recut that fixed a real defect.
Keeping the 2× also means this is the **identical shot at the identical pace** as the published
version, which is what "fix in place" should mean: the same demo, better.

### 3. Packed size, and the mapping computed from it

```
frames=600 packets=2120365 seek=17042 loop=3673 padding=0 total=2141080 max=3685
stream sha256 95f1e0e4acf1b8d1c1b41de6a30f52876470c76eddaccd4d75f6b16588c6a8b6
```

**2,141,080 B** — not the naive 2 × 1,083,714 = 2,167,428, but only 1.2 % under it. The predicted
"frames resemble each other more at 59.94" effect is **real but nearly negligible** (see the
crossover measurement below); it does not change a mapping decision.

| mapping | verdict |
|---|---|
| 2 MiB Fast HiROM (what shipped) | **ruled out** — 0x10000 + 2,141,080 = 2,206,616 B > 2,097,152 |
| **4 MiB Fast HiROM** | **chosen** — image exactly 4,194,304 B, stream uses **33 of the 63 banks** `$C1`–`$FF` |
| ExHiROM | **not needed** — nothing here exceeds ordinary HiROM's 4 MiB reach |

Header verified rather than assumed: map mode `$31`, ROM-size byte `$0C`, single 32 Mbit device at
`$000000`, canonical window `$C0`–`$FF:0000-FFFF`, no addressing holes, stored checksum `$DF0B` ==
recomputed `$DF0B`.

Keyframe policy **K = 120 stands**, now buying 2.0 s of seek granularity instead of 4.0 s. The sweep
inverts as it did on v2 (K=15 → 2,115,279 vs K=120 → 2,121,044) but spans only 5,765 B over an 8×
range, which does not argue for a change.

### 4. Full gate output (`dev/apollo-reel.sh`, 59.94 fps build)

```
==> 1) asset bake reproduces the recorded corpus SHA-256
  PASS: RGB24 corpus aa29061311e022e8bafb0e013c09da5ea11d4c9114df4732f9b1452157573cad
frames=600 packets=2120365 seek=17042 loop=3673 padding=0 total=2141080 max=3685
  tiles  sha256 08c24756b982fec8703d5959cf8b6af06e8981beef1a6bdc55edd20c1675ce10
  stream sha256 95f1e0e4acf1b8d1c1b41de6a30f52876470c76eddaccd4d75f6b16588c6a8b6
  stream bytes  2141080

==> 2) whole-loop byte-correct decode (all 600 frames + loop delta)
     [self-test builds; the published ROMs skip this boot pass by design]
  PASS: slow corpus gate: SMOKE: PASS off=0x2B len=1 got=0x00 (ran 9000 frames, bsnes-jg)
  PASS: fastrom corpus gate: SMOKE: PASS off=0x2B len=1 got=0x00 (ran 9000 frames, bsnes-jg)
  PASS: slow (published) composite health: SMOKE: PASS off=0x2C len=4 got=0x00000000 (ran 9000 frames, bsnes-jg)
  PASS: fastrom (published) composite health: SMOKE: PASS off=0x2C len=4 got=0x00000000 (ran 9000 frames, bsnes-jg)

==> 2b) negative control: one flipped stream byte must FAIL the gate
  flipped stream byte 400000: 0x2d -> 0x2c
  PASS: corrupted stream rejected: SMOKE: FAIL off=0x2B len=1 got=0x02 want=0x00

==> 3) cadence: presented frames per 600 VBlanks (1-VBlank operating point)
  build       presented    vblanks     per600      slips
  slow              600        600        600          0
  fastrom           600        600        600          0
  (reported, not gated — a slower number on this content is the measurement)

==> 4a) -verify-machineinstrs clean
  PASS: no verifier complaints

==> 4b) picture is independent of power-on entropy (None/Low/High x2)
  PASS: one picture across all six boots (8B506DC5:#000000)

==> 6) REGRESSION GUARD: the published ROM shows a picture promptly
  at VBlank 180 (~3.0s): black=30.8%  unique_colours=103
  PASS: picture is up well before the first loop completes

==> 5) frame capture
jgxcheck: JGX_POLL matched at frame 328 of 9000 budgeted
  PASS: captured frame 96: SMOKE: PASS off=0x36 len=2 got=0x0096 (ran 9000 frames, bsnes-jg)

SLOW_ROM=build/apollo-daylight-slow.sfc
ROM=build/apollo-daylight.sfc
ROM_SHA256=bf62a2992546f87f8ec4d46de1c14a30bdfdd5a553f0e114dfb1beea961ecdbe
GATE: PASS
```

### 5. Cadence at the 1-VBlank operating point — the metric that decided this

| ROM | content | operating point | presented / 600 VBlanks | slips |
|---|---|---|---:|---:|
| Apollo v2 (previous ship) | daylight film grain | 2 VBlank | 300 / 600 (30 fps) | 0 |
| **Apollo v3, slow ROM** | **daylight film grain** | **1 VBlank** | **600 / 600 (59.94 fps)** | **0** |
| **Apollo v3, FastROM** | **daylight film grain** | **1 VBlank** | **600 / 600 (59.94 fps)** | **0** |
| ring-refill bench, hardest slice | Artemis night launch | 1 VBlank | 674 / 600 slow, 754 / 600 Fast | — |

**Slow ROM clears it too.** The mean packet here is 3,534 B against the bench's hardest-slice
3,290 B (+7.4 %) and the worst is 3,685 B, and the player still lands every frame with a full window
to spare — consistent with the post-merge re-baseline's 674/600 headroom on slow ROM. FastROM is a
margin lever, not a prerequisite, exactly as the 60 fps plan concluded. The published build stays
FastROM anyway; the slow build is the control that proves the margin is real.

Picture proven on the running ROM, not inferred — three frames captured from the published binary,
pairwise over the 256×192 video region:

| | v2 (30 fps) | **v3 (59.94 fps)** |
|---|---:|---:|
| mean\|Δ\|, frames 60 vs 300 | 50.81 | **50.03** |
| mean\|Δ\|, frames 300 vs 540 | 30.34 | **30.06** |
| % pixels differing | 78.7–80.0 % | **78.6–79.7 %** |
| black in video region (letterbox) | 20.0 % | **20.3 %** |

Identical within noise, which is the point: the shot and its pacing are unchanged, only the temporal
resolution doubled.

### 6. Free measurement: LZSS vs SVX2 at 59.94 fps

Recorded in full in the benchmark doc. The crossover item asked whether closer-together frames let
interframe SVX2 claw back its deficit to intraframe LZSS. **Second point on the curve: barely.**

| corpus | frame spacing | LZSS | SVX2 K=120 | LZSS advantage |
|---|---|---:|---:|---:|
| v2, 30 fps | 1/15 s | 65.31 % | 79.62 % | 14.31 pts |
| **v3, 59.94 fps (ships)** | **1/30 s** | **65.51 %** | **78.91 %** | **13.40 pts** |
| real-time control | 1/59.94 s | 67.93 % | 78.06 % | 10.13 pts |

Halving the temporal gap recovers **0.91 points**; quartering it recovers 4.18. The residual between
consecutive frames on this content is dominated by **Floyd–Steinberg dither noise, which is
decorrelated no matter how close the frames are** — so the crossover is not reachable by frame rate.
That is a property of the dither, not the footage, and it is the same mechanism that makes keyframe
interval nearly free here. The codec decision is untouched: LZSS is still ~27× too slow.

### Deviations from the plan

- **The plan said to extend `tools/snes-video-rgb24-convert.sh` if it lacked a source-fps option.**
  It did not lack one — `--fps` already forwards any ffmpeg rate expression. Rather than add a
  redundant flag, its usage text was corrected to say so. No behaviour change.
- **`APOLLO_REEL_GATE_FRAMES` raised 6,000 → 9,000.** The self-test build now Fletcher-checks 601
  frames instead of 301, roughly doubling the boot validation pass on the slow build. This is a gate
  budget, not a shipped artefact.

### 7. Published over the same slug — evidence

Verified the CI-only way (per the `site-builds-are-ci-only` memory): the deploy-run conclusion plus
live fetches, never a host build.

```
$ gh run list --workflow deploy.yml --limit 2
completed  success  feat(snes): republish the Apollo cartridge at true 59.94 fps  Deploy site  v1.0.363  push  30819885405  2m39s  2026-08-03T13:51:20Z
completed  success  feat(snes): recut Apollo to a shot that actually moves        Deploy site  v1.0.362  push  30819526870  2m45s  2026-08-03T13:46:39Z

$ curl -fsSL https://biohack.net/play/roms/apollo-daylight.sfc | sha256sum
bf62a2992546f87f8ec4d46de1c14a30bdfdd5a553f0e114dfb1beea961ecdbe
$ sha256sum build/apollo-daylight.sfc
bf62a2992546f87f8ec4d46de1c14a30bdfdd5a553f0e114dfb1beea961ecdbe
MATCH — the served ROM is the gate-verified binary (4,194,304 B)

page   /snes/apollo-daylight/  HTTP 200   <title>Apollo 11 Daylight Launch — bioHACK•NET</title>
manifest roms: 120   (collection entries: 120 — the count guard's two halves moved together)
selfcheck: {"off":"0x2C","len":4,"want":"0x00000000","frames":2000}
```

Same slug, same page, same URL: **[https://biohack.net/snes/apollo-daylight/](https://biohack.net/snes/apollo-daylight/)**.
No second ROM was created. The WRAM oracle did not move (`$002C`), so only the selfcheck *label*
changed; the manifest and the content JSON were committed together.

Page prose rewritten off the new measurements — it described 2× at 30 fps and a 2 MiB image — and
gained a section on the frame-rate experiment, since "we doubled the frame rate and the delta codec
barely noticed" is the most interesting thing this rebuild produced.

Commits: `e275733` (llvm-mos-65816), `73aec47` + tag `v1.0.363` (biohack.net).

### 8. Post-publication defect: the FPS gauge read 59.1 then 60.1 (FIXED)

**Reported by the user against the live page.** Neither number was a cadence problem —
`apollo_reel_deadline_slips` is 0 and the gate measures a flat 600/600 — but a gauge that reads
59.1 and then 60.1 on a cartridge billed as 59.94 fps looks exactly like a stutter the hardware
never had. Two separate causes, both arithmetic:

**59.1, once at startup — an off-by-one in the sampler.** The loop ran `dashboard_update()` *then*
`present_frame()`, and the FPS sample lived inside `dashboard_update()`, so it latched
`apollo_reel_presented_total` **before** the frame it was about to send. The first window therefore
counted `dp=59` over `dv=60`: `(59*601+30)/60 = 591` → `"59.1"`. Every later window has both
endpoints shifted equally and reads `dp=60`, which is why it appeared exactly once. Fixed by
splitting `fps_sample()` out and calling it *after* `present_frame()`.

**60.1, steady state — an accurate number that answers the wrong question.** The scale constant 601
is the NTSC VBlank rate (60.0988 Hz) ×10, so one frame per VBlank really is 60.1 presents per wall
second. True, and useless: it invites "why does the 59.94 fps demo say 60.1?" forever. Rescaled to
600, so the HUD now reports **frames per 600 VBlanks with one decimal — deliberately the same
measurement the gate's cadence table reports**, and the two can no longer disagree. One frame per
VBlank reads 60.0. (The 59.94 belongs to the *source*; the gauge measures the *presentation*.)

Verified by reading the `dashboard_fps` string straight out of WRAM `$0020` on the built ROM at six
points, rather than by squinting at a screenshot:

```
VBlank   100  got=0x302E3030  "00.0"   (not yet sampled)
VBlank   160  got=0x302E3030  "00.0"
VBlank   300  got=0x302E3036  "60.0"
VBlank   700  got=0x302E3036  "60.0"   (past the first loop wrap)
VBlank  1400  got=0x302E3036  "60.0"
VBlank  2600  got=0x302E3036  "60.0"
```

No 59.1, no 60.1. The leading `"00.0"` is left deliberately — it means "not measured yet" for the
first second of playback, and seeding it with a number the ROM has not measured is precisely the
kind of decorative gauge this project avoids.

Re-gated in full (nothing carried over): whole-loop byte-correct decode on both self-test builds,
negative control rejected, 600/600 with zero slips on slow ROM and FastROM, `-verify-machineinstrs`
clean, one picture across six entropy boots, VBlank-180 black-screen guard PASS. The stream is
byte-identical (`95f1e0e4…`); only the HUD arithmetic moved. New ROM sha256
`a74142914170bec0a3bdce060928581ef2d979b426f011a552ce42b90441eda4`.
