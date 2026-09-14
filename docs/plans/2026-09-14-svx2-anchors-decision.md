# SVX2 plan anchors — restore-or-retire decision

**Date:** 2026‑09‑14
**Status:** Decided and executed; verification recorded below
**TODO:** `[T4] svx2 plan anchors invalidated by successor work — restore-or-retire decision`, and the
dependent `[verify T3] svx2-animated-video-cartridge — BLOCKED on the [T4] decision`
**Parent plan:** [`2026-07-31-svx2-animated-video-cartridge.md`](2026-07-31-svx2-animated-video-cartridge.md)
**Also touches:** [`2026-08-01-svx2-cut-aware-dashboard-labels.md`](2026-08-01-svx2-cut-aware-dashboard-labels.md)
(anchor (c))

No visible surface — this change is a C preprocessor guard, two host-side tools and plan text; there is
nothing to mock up.

## Problem

The 2026‑08‑03 verification run of the svx2 animated-cartridge plan found that successor work had
invalidated three of the plan's anchors, so the run could neither pass nor honestly fail:

- **(a)** the plan's "first cartridge" — the 4‑frame 32 KiB LoROM integration fixture — no longer
  compiles on `main` (`VIDEO_REEL_HIROM_BASE_BANK` undeclared);
- **(b)** gate 7 ("the exact verified ROM is the file published in the gallery") has no truthful
  reading: three different images exist (the plan's recorded LoROM `825e3848…`, the 4 MiB HiROM the
  gate builds, the 8 MiB ExHiROM `c3d7cd9e…` the gallery serves);
- **(c)** the cut-aware-labels plan's 1,800‑frame 59.94 fps cartridge (cuts 600/1200) has no asset
  recipe in the tree.

## What `main` actually does (traced, not assumed)

- `git log -S reel_stream_bank -- examples/snes/snes-video-reel.c` → **`d6030cf`** ("feat(snes):
  restore cut-aware video dashboard", 2026‑08‑02). That commit hoisted the bank arithmetic out of three
  `#ifdef`‑guarded call sites into an **unguarded** helper `reel_stream_bank()`. The suspected
  `bd344a1` introduced the macro but kept every use inside `#ifdef VIDEO_REEL_PACKED_FAR`; it did not
  break the small path. All three callers of the helper (`stage_frame`'s packed branch,
  `stage_seek_keyframe`, `stage_loop_delta`) live inside `PACKED_FAR` / `SEEK_COUNT` / `LOOP_DELTA`
  blocks, and `tools/snes-video-reel-assets.py` emits all three macros only on `--packed-far`.
- `dev/snes-video-reel.sh` still carries the whole `FRAMES <= 4` LoROM configuration (`mos-snes.cfg`,
  `--fastrom` checksum, 1,200‑VBlank gate window, `screenshot_frame=0`), and `snes-video-reel.c` still
  carries the `#if VIDEO_REEL_FRAME_COUNT <= 4u` boot-validation and `reel_packets[]` staging. Only the
  helper's placement broke the path.
- The fixture's **input** — `/tmp/real-shared.tiles` + `/tmp/artemis-shared.pal` — is gone and has no
  recipe anywhere in the tree (`grep -rn real-shared dev/ tools/ docs/` hits only the script's default).
  The real-camera master is not vendored. The only durable record of those frames is the checked-in
  900‑frame `examples/snes/snes-video-reel-assets.h` + `assets/snes/video/svx2-full-reel.bin` pair, whose
  frames 600–899 are the `PRESS-SITE CAMERA` segment.
- The gallery's `svx2-fastrom-video.sfc` is `c3d7cd9e…` / `v1.0.360`, owned by
  [`2026-08-02-svx2-artemis-2x-apollo-60p-reel.md`](2026-08-02-svx2-artemis-2x-apollo-60p-reel.md) and
  gated byte-for-byte by `dev/svx2-emulator-validation.sh` (download → SHA → rebuild via
  `dev/snes-video-artemis-apollo.sh` → `cmp`).
- The 1,800‑frame cadence‑1 **Artemis** cartridge (`FIRST_FRAMES=1200 FRAMES=600`, the auto-label branch
  at `dev/snes-video-reel.sh:51-54`) was never published; its own plan calls it unpublishable pending a
  low-WRAM corruption, and it was superseded by two published ExHiROM cartridges that both have complete
  in-tree recipes (`dev/snes-video-native60.sh` — 1,800 XRISM frames, cuts 600/1200;
  `dev/snes-video-artemis-apollo.sh` — 1,200 frames). Its input tiles were the same vanished `/tmp`
  intermediates as (a).

## Decision table

| Anchor | Decision | Rationale |
|---|---|---|
| **(a)** 4‑frame LoROM first cartridge uncompilable | **RESTORE** | The break is placement, not design: wrap `reel_stream_bank()` in `#ifdef VIDEO_REEL_PACKED_FAR` (`examples/snes/snes-video-reel.c`). Two lines, and the truthful shape — a 32 KiB LoROM has no HiROM base bank, so an `#ifndef` numeric default would compile a function that computes a meaningless bank; guarding it out matches the generator, which only emits the macro alongside the stream. The fixture is still what the plan's gates 1–6 are written against, and `dev/snes-video-reel.sh` still knows how to gate it. Because its input had no recipe, the restore also adds one: `tools/snes-video-reel-extract.py` inverts the packed-far generator (decodes frames 600–603 from the checked-in header + stream, CRC-checked against `reel_frame_crcs[]`) and `dev/snes-video-lorom-fixture.sh` is the one-command gate. The generator line it produces — `frames=4 packets=2877 seek=0 loop=828 padding=0 total=3705 max=897` — is byte-identical to the 2026‑08‑03 record's, so the recovered frames are the fixture's original content. |
| **(b)** Gate 7 has no truthful reading / which ROM this plan owns | **RETIRE gate 7 here; the plan owns the LoROM fixture** | The plan's own Goal names the LoROM as "a small, ordinary LoROM integration fixture" whose job is to prove multi-frame SVX2 playback before the large reels; the published-ROM property moved with the successors by design (LoROM `v1.0.317` → HiROM → ExHiROM `v1.0.360`), and the gallery serves exactly one SVX2 ROM. Making gate 7 pass here would mean either re-publishing a 32 KiB fixture over the shipping cartridge or having two plans assert ownership of one URL. So: gates 1–6 are read against the restored LoROM fixture (recorded below), gate 7 is struck with a pointer to `dev/svx2-emulator-validation.sh` under the artemis‑2x‑apollo plan as the sole owner of "published == gated", and the implementation record's `825e3848…` / `v1.0.317` figures are marked historical. |
| **(c)** 1,800‑frame Artemis cadence‑1 cartridge (cuts 600/1200) has no asset recipe | **RETIRE** | Restoring means re-deriving 1,200 frame-doubled animation frames plus 600 real-camera frames whose master is not vendored and whose selection interval is not recorded — that is re-engineering an asset path for an artifact nobody ships and whose plan declared it unpublishable. The cut-aware-labels gates were already reproduced 8/8 on the 900‑frame reel (cuts 300/600, same three labels), and the property they test (label follows segment on the same presentation) is exercised at cuts 600/1200 by the published native‑60 XRISM cartridge's recipe. The `dev/snes-video-reel.sh:51-54` auto-label branch is left in place: it is harmless and is the only in-tree record of that configuration's labels. |

Rejected alternative for (a): `#ifndef VIDEO_REEL_HIROM_BASE_BANK` / `#define … 0x80u` — compiles, but
lies (it declares a bank the LoROM fixture does not have) and would silently mask a future generator
regression that dropped the macro from a packed-far header. Rejected alternative for the fixture input:
ffmpeg from the vendored `Pre-launch_through_launch.webm` — reproducible, but changes the fixture's content
from the plan's "press-site camera frames" to animation and adds a host `ffmpeg` dependency the extractor
does not need.

## Changes

- `examples/snes/snes-video-reel.c` — `reel_stream_bank()` wrapped in `#ifdef VIDEO_REEL_PACKED_FAR`.
- `tools/snes-video-reel-extract.py` — new; inverts `--packed-far` reels to tiles + palette.
- `dev/snes-video-lorom-fixture.sh` — new; extract frames 600–603 → `dev/snes-video-reel.sh` LoROM gate
  → `snes-checksum.py --fastrom --inspect`.
- `tests/test_snes_video_codec.py::test_reel_extract_inverts_packed_far_generator` — regression guard for
  the extractor (round trip through the real generator; corrupt stream is a hard error).
- `docs/plans/2026-07-31-svx2-animated-video-cartridge.md` — verification record 2026‑09‑14 (preliminary
  now PASS, gates 1–6 on the LoROM fixture, gate 7 retired), implementation-record figures marked
  historical, corrected culprit commit.
- `docs/plans/2026-08-01-svx2-cut-aware-dashboard-labels.md` — anchor (c) retired with reason + date.

## Cadence-gate defect found on the way (and its fix)

The restored fixture compiled but failed `dev/snes-video-reel.sh`'s cadence gate at every cadence with
zero slips and zero CRC failures (composite health had already passed):

```
cadence 1: SMOKE: FAIL off=0x2F len=2 got=0x031D want=0x0319
cadence 2: SMOKE: FAIL off=0x2F len=2 got=0x018F want=0x018D
cadence 3: SMOKE: FAIL off=0x2F len=2 got=0x010A want=0x0109
```

Measured t0 (first VBlank with `presented_total == 1`, `JGX_POLL`) = **404 at all three cadences**, and
`1 + floor((1200 − 404)/CADENCE)` = 797 / 399 / 266 = `0x31D / 0x18F / 0x10A` — exactly the observed
counts. The stored literals `0x319/0x18D/0x109` (793/397/265) are exactly the t0 = 408 values; they were
written by `4e93daa` and, unlike the 900‑frame sibling that `b1afb9c` corrected, never re-derived. So this
is the `b1afb9c` class of defect — a stale hardcoded t0 — not a dropped frame. Three hypotheses, in order:
(1) dropped/duplicated presentations — refuted by slips = 0, CRC failures = 0, composite health = 0;
(2) stale constants — confirmed by one measured t0 predicting all three cadences; (3) *why* t0 moved
408 → 404 — the boot path's C is textually identical between `4e93daa` and HEAD (same 4‑frame
bit-serial-CRC validation loop, same `m7splash_end(30u)`), while the compiler moved on (12 commits under
`patches/llvm-mos/` in between), so codegen speed of the validation loop is the plausible variable.
That last step is **not verified** — it would need the 2026‑07‑31 toolchain rebuilt; stated as the gap.

Fix (`dev/snes-video-reel.sh`): the gate now **measures t0 in-run** and derives the expectation, asserting
t0 only to within ±16 of a documented per-path reference (a real boot-path regression — validation
re-enabled, title stuck — moves t0 by hundreds; codegen drift moves it by a handful). The FPS-gauge early
probe became `t0 + 60 + 8` (just past the first 60‑VBlank window) instead of a fixed 400, which had been
reading the *third* window on the 900‑frame path and `00.0` on the fixture. `VIDEO_REEL_EXPECTED_PRESENTED`
stays as the explicit override (`dev/snes-video-artemis-apollo.sh` uses it) and keeps the historical fixed
probe. Rejected alternative: re-derive the three literals to t0 = 404 with a comment, as `b1afb9c` did —
identical outcome today, but it re-arms the same trap for the next codegen change.

## Verification

### 1. Before: the LoROM fixture fails to compile on unmodified `main` (`294bc8c`) with the recovered tiles.

```
$ PYTHONPATH=tools python3 tools/snes-video-reel-extract.py examples/snes/snes-video-reel-assets.h \
    assets/snes/video/svx2-full-reel.bin --start 600 --frames 4 \
    --tiles-output build/lorom-fixture.tiles --palette-output build/lorom-fixture.pal
extracted frames 600..603 (decoded from keyframe 0) -> build/lorom-fixture.tiles (17920 bytes); palette -> build/lorom-fixture.pal
$ VIDEO_REEL_TILES=build/lorom-fixture.tiles VIDEO_REEL_PALETTE=build/lorom-fixture.pal \
  VIDEO_REEL_FRAMES=4 VIDEO_REEL_FIRST_FRAMES=0 dev/snes-video-reel.sh
frames=4 packets=2877 seek=0 loop=828 padding=0 total=3705 max=897
/home/will/llvm-mos-65816-svx2-anchors/examples/snes/snes-video-reel.c:287:20: error: use of undeclared identifier 'VIDEO_REEL_HIROM_BASE_BANK'
  287 |   return (uint8_t)(VIDEO_REEL_HIROM_BASE_BANK + (uint8_t)(offset >> 16));
      |                    ^~~~~~~~~~~~~~~~~~~~~~~~~~
1 error generated.
exit=1
```

**PASS** (the failure reproduces, with the generator line byte-identical to the 2026‑08‑03 record).

### 2. After: `dev/snes-video-lorom-fixture.sh` builds and gates the 4‑frame LoROM.

```
$ dev/snes-video-lorom-fixture.sh
==> recover fixture frames 600..603 from the checked-in reel
extracted frames 600..603 (decoded from keyframe 0) -> /home/will/llvm-mos-65816-svx2-anchors/build/lorom-fixture.tiles (17920 bytes); palette -> /home/will/llvm-mos-65816-svx2-anchors/build/lorom-fixture.pal
==> build + gate the 4-frame LoROM fixture
frames=4 packets=2877 seek=0 loop=828 padding=0 total=3705 max=897
jgxcheck: wrote /home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.png (256x224 from native 512x240, yoff=0)
cadence gate: first present at VBlank 404 (reference 404); expecting 0x18f presentations in 1200
displayed FPS gauge: 30.0 at VBlank 472 and 1200
jgxcheck: JGX_POLL matched at frame 411 of 1200 budgeted
DASHBOARD: PASS ink_pixels=420
FIDELITY: PASS frame=0 exact=93.0542% mae=1.3092
SMOKE: PASS off=0x207 len=4 got=0x00000000 (ran 1200 frames, bsnes-jg)
SMOKE: PASS off=0x2F len=2 got=0x018F (ran 1200 frames, bsnes-jg)
ROM=/home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.sfc
==> LoROM header + checksum
/home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.sfc
mapping           : lorom (fast ROM), map mode $30
file length       : 32768 bytes (0x8000, 0 Mbit / 32 KiB)
[…]
checksum stored   : $A5C9   complement $5A36
checksum recomputed: $A5C9 (mirrored image) / $A5C9 (multiplier formula)
bsnes-jg heuristic: detects lorom  lorom=14  hirom=0  exlorom=0  exhirom=0

PASS: header, size, decomposition, vectors and checksum all agree.
exit=0
```

**PASS.** (Full checksum inspection is in the parent plan's record, gate 6.)

### 3. The packed-far path is unaffected: default `dev/snes-video-reel.sh` (900‑frame HiROM from the checked-in header + stream) still builds and gates.

```
$ dev/snes-video-reel.sh
using checked-in full reel asset
packed 2360380 stream bytes at file $010000; ROM=4194304 bytes
jgxcheck: wrote /home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.png (256x224 from native 512x240, yoff=0)
cadence gate: first present at VBlank 179 (reference 179); expecting 0x777 presentations in 4000
displayed FPS gauge: 30.0 at VBlank 247 and 4000
jgxcheck: JGX_POLL matched at frame 1977 of 4000 budgeted
jgxcheck: JGX_POLL matched at frame 1977 of 4000 budgeted
jgxcheck: JGX_POLL matched at frame 799 of 4000 budgeted
jgxcheck: wrote /home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel-cut-one.png (256x224 from native 512x240, yoff=0)
jgxcheck: JGX_POLL matched at frame 1399 of 4000 budgeted
jgxcheck: wrote /home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel-cut-two.png (256x224 from native 512x240, yoff=0)
jgxcheck: JGX_POLL matched at frame 395 of 4000 budgeted
jgxcheck: wrote /home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.png (256x224 from native 512x240, yoff=0)
SMOKE: PASS off=0x205 len=4 got=0x00000000 (ran 4000 frames, bsnes-jg)
SMOKE: PASS off=0x31 len=2 got=0x0777 (ran 4000 frames, bsnes-jg)
ROM=/home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.sfc
exit=0
```

**PASS** — the measured t0 = 179 and derived `0x777` reproduce `b1afb9c`'s hand-derived figures with no
literal in the script; the gauge now reads 30.0 in its *first* window (VBlank 247). Note: this run used
the checked-in header + stream fallback (`/tmp` tiles absent), on which the script skips the fidelity leg
(`check_tiles` missing) — pre-existing behaviour of that fallback, unchanged here.

### 4. `python3 -m pytest tests/test_snes_video_codec.py -q`

```
.........................                                                [100%]
25 passed in 12.41s
```

**PASS** — 24 existing + `test_reel_extract_inverts_packed_far_generator`.

### 5. Gate 7 re-pointed: `dev/svx2-emulator-validation.sh` proves the published `v1.0.360` is byte-identical to the gated rebuild.

```
$ dev/svx2-emulator-validation.sh
/tmp/svx2-emulator-validation/svx2-fastrom-video-v1.0.360-c3d7cd9e….sfc.download: OK
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
PASS: ExHiROM cut offsets 0x3ef147, 0x3f0000, 0x3f0f0c
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
/home/will/llvm-mos-65816-svx2-anchors/build/svx2-video-reel.sfc: FAILED
sha256sum: WARNING: 1 computed checksum did NOT match
exit=1
```

**FAIL — and not caused by this change.** Every emulator gate of the successor's full run passes (this
also exercises the `VIDEO_REEL_EXPECTED_PRESENTED` override path of the reshaped cadence gate: fixed
probe at 400, `0x0B06` in 3,000), but the rebuilt 8 MiB image is `17c2cf03…`, not the published
`c3d7cd9e…`. Localised:

```
$ # A/B: HEAD's snes-video-reel.c vs this branch's, same generated header, same flags
HEAD: 17c2cf03e630ddf5 size=8388608
MINE: 17c2cf03e630ddf5 size=8388608
A/B: byte-identical (guard changes nothing)
$ cmp -l <published v1.0.360> build/svx2-video-reel.sfc | <partition by ROM region>
code(0-0xFFFF)=18797 streamA(0x10000-0x3FFFFF)=0 code-mirror(0x400000-0x40FFFF)=18801 streamB(0x410000+)=0
$ git log --oneline --since=2026-08-03 -- patches/llvm-mos/ | wc -l
6
$ ls -l --time-style=+%F build/llvm-mos-install/bin/clang-23
2026-08-05
```

The 5,802,443‑byte packed video stream is byte-identical to the published ROM — the asset pipeline
reproduces exactly — and every one of the 37,598 differing bytes is in the 64 KiB FastROM code window
or its ExHiROM mirror. The installed compiler post-dates the release (`clang-23` built 2026‑08‑05;
six `patches/llvm-mos/` commits since 2026‑08‑03), so `dev/svx2-emulator-validation.sh`'s `cmp` can only
pass on the exact toolchain that built `v1.0.360`. That gate belongs to
[`2026-08-02-svx2-artemis-2x-apollo-60p-reel.md`](2026-08-02-svx2-artemis-2x-apollo-60p-reel.md) and is
left as-is here; the decision it needs (pin/record the release toolchain, or split the gate into
"stream byte-identical + code functionally gated", or re-publish from the current toolchain) is a
product call — escalated in the report. For *this* plan the finding confirms the retirement of gate 7:
"published == gated" cannot be re-derived by any plan without that decision.

## Result

Steps 1–4 **PASS**; step 5 **FAIL** for a reason outside this change (toolchain drift vs the published
release), documented above. The `[verify T3] svx2-animated-video-cartridge` item is unblocked: the parent
plan's gates 1–6 PASS on the restored LoROM fixture and gate 7 is retired.

## Residual risk

- The ±16‑VBlank `t0` tolerance is a judgment call; a boot-path regression smaller than that would pass
  the cadence gate (it would still have to present the exact derived count with zero slips). What would
  confirm it: watching `cadence gate: first present at VBlank N` across the next few toolchain rebuilds.
- Why t0 moved 408 → 404 is attributed to codegen, not proven (needs the 2026‑07‑31 toolchain).
- `dev/snes-video-reel.sh`'s checked-in-fallback path skips the fidelity leg when `/tmp` tiles are absent
  (pre-existing); the 900‑frame run above therefore has no `FIDELITY:` line.
