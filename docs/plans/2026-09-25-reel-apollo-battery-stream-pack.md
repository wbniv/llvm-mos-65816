# The battery's two video ROMs carry no video stream — the real cause of the reel/apollo "entropy" defect

TODO: Test Bench / CI — "`snes-video-reel` and `apollo-reel` are entropy-sensitive AFTER the title" (T4).

## Context

`dev/title-entropy.sh` passes at frame 60 and fails at 100/200 on the `snes-video-reel` and `apollo-reel`
ROMs that `dev/build.sh`'s example battery produces. Two earlier readings were wrong: the T2 recipe
(`snes_ppu_reset_blank()` in `setup_display()`) had zero effect, and the escalation's "BG3 HUD / HDMA" and
"Mode-7 wrap seam" symptoms are downstream damage, not mechanisms.

**Measured root cause (2026‑09‑25, bsnes-jg with a seeded-entropy + per-instruction trace harness):**
neither battery ROM contains its packed SVX2 video stream, so the fast decoder is fed bytes that are not a
stream and its output pointer runs off the end of the framebuffer across bank `$00` — WRAM mirror, then the
PPU/CPU I/O registers. What that stray write sweep does depends on the power-on WRAM/PPU state, which is
exactly what `JGX_ENTROPY=1` randomises.

- **apollo-reel** (`battery-config: snes-hirom`): the ROM is linked, but the post-link
  `tools/snes-video-pack-hirom.py` step that `dev/apollo-reel.sh` runs is absent, so the stream bank `$C1` is
  all zeros. The staged "packet" at `$7F:2000` is zeros; zero tokens are 1-byte literals that consume
  2 source bytes per output byte, so the key decoder reads past the 4,387-byte staged packet into
  never-written `$7F` WRAM. At entropy 0 that is more zeros (harmless, black picture); at entropy 1 it is
  random, and the first non-zero byte (at `X=$3123`, identical instruction count across seeds) sends the
  decoder's MVN run-fill out of bounds. Every seed diverges → 8/8 at frame 200.
- **snes-video-reel** (no config marker): the checked-in `snes-video-reel-assets.h` is the 900-frame
  `--packed-far` HiROM header for the checked-in 2.36 MB `assets/snes/video/svx2-full-reel.bin`, but the
  battery links it as a **32 KiB LoROM** with no stream. The stage DMA reads bank `$C1`, which is open bus
  — one constant byte, whatever the bus last carried (`$4C` in the `+mos-a16` battery build, `$8A` in a
  non-a16 build of the same source). `$4C` is a 77-byte literal token, so 4,480 output bytes need more
  source than the 3,650-byte staged packet holds and the decoder again runs into never-written `$7F` WRAM.
  At entropy 0 that is zeros and the frame completes (a solid-black picture); under entropy a random run
  token overshoots the output end, the kernel's end test never matches, and the MVN sweeps bank `$00`.
  Whether a given power-on produces such a token is a coin toss → ~20–35 % of seeds differ at frame 100.
  (In the non-a16 build, `$8A` is a 119-byte run token and 4,480 is not a multiple of 119, so that build
  sweeps even at entropy 0.)

**The shipped ROMs are clean.** `dev/title-entropy.sh --runs 8 --frames 60,100,200,400` PASSes on the
published `apollo-daylight.sfc` (biohack.net and indri.studio) and `svx2-fastrom-video.sfc`, and on a
battery apollo ROM with the stream packed in by hand. This is a build-recipe defect in the battery, not
uninitialised display state in the demos.

## Approach

Give the battery contract the missing post-link hook, and declare it in the two sources:

- `dev/build.sh`: new `// battery-post: COMMAND` marker — runs after the link and **before** the checksum
  (the pack changes the ROM size and contents), from `$ROOT`, with `$ROM`, `$MAP`, `$ROOT`, `$BUILD`,
  `$INSTALL`, `$GEN` exported. Repeatable, in source order, continue-on-error like `battery-prep`.
- `examples/snes/apollo-reel.c`: `battery-post:` packs `$GEN/apollo-reel-stream.bin` (the synthetic
  12-frame stream its `battery-prep` already bakes).
- `examples/snes/snes-video-reel.c`: `battery-config: snes-hirom`, `battery-post:` packs the checked-in
  `assets/snes/video/svx2-full-reel.bin`, `battery-checksum: --hirom --fastrom` — the same recipe
  `dev/snes-video-reel.sh` uses with the checked-in assets, so the battery ROM is the gate's ROM.

Rejected: leaving the battery ROMs link-only and documenting "don't run them". They sit in `build/` next to
every runnable ROM, and a whole-battery runtime sweep is exactly how this false defect was filed. Also
rejected: hardening the decoder's end test (`bcc` instead of an equality test) — the kernel is right for
every well-formed stream, and defensive code for a malformed-input case that only an incomplete build
produces is the wrong fix.

Regression guard: `dev/battery-video-selfcheck.sh` — (1) deterministic: the ROM's bytes at the stream's
HiROM file offset (from the header's `VIDEO_REEL_HIROM_BASE_BANK`) equal the packed stream; (2) behavioural:
`dev/title-entropy.sh` at 60/100/200. It fails on today's battery ROMs and passes once they carry their
streams. The ROMs' own playback-health words were tried first and rejected as a detector: without the
boot-time self-test they only mean "looped twice", and both stream-less `+mos-a16` battery ROMs satisfy
that at entropy 0 (and a `JGX_POLL` for 0 matches at frame 1, since entropy 0 powers WRAM on zeroed).

No visible surface change: this fixes a build recipe; the demos' pictures are the already-published ones.

## Verification

1. Reproduce on both battery-recipe ROMs: `dev/title-entropy.sh <rom> --runs 8 --frames 60,100,200`
   (frame 60 PASS; apollo FAIL at 200, reel FAIL at 100 or 200).
2. The regression guard fails on the unfixed battery ROMs: `dev/battery-video-selfcheck.sh --build <dir>`.
3. Rebuild both via the battery recipe with the fix; the guard passes, and `dev/title-entropy.sh` PASSes
   at 60/100/200 on both (8 runs).
4. The battery `snes-video-reel.sfc` is byte-identical to `dev/snes-video-reel.sh`'s checked-in-asset ROM
   recipe (same sources, cfg, pack, checksum).
5. Both demos' normal gates still pass: `dev/snes-video-reel.sh` (checked-in assets) and the apollo
   whole-loop self-test on the synthetic corpus.
6. Byte/cycle cost: none in the demo code (no source change beyond build markers); ROM size only.

### Verification results (2026‑09‑25)

Builds: the **real** `dev/build.sh` battery loop (its `marker()`-to-end section, run host-side over a scratch
`ROOT` holding only these two demos + their companion TUs, toolchain `build/llvm-mos-install` = this
checkout's). "Before" = `HEAD` (`b8e8c479`) `dev/build.sh` + sources; "after" = this change.

| ROM | before sha256 | after sha256 |
|---|---|---|
| `apollo-reel.sfc` | `46b1e0f645d04873…` (512 KiB) | `09c30735a3ace089…` (1 MiB) |
| `snes-video-reel.sfc` | `a035d4988f492d36…` (32 KiB LoROM) | `01a7e074235c3308…` (4 MiB HiROM) |

1. Reproduce on both battery-recipe ROMs: `dev/title-entropy.sh <rom> --runs 8 --frames 60,100,200`
   (frame 60 PASS; apollo FAIL at 200, reel FAIL at 100 or 200).

    ```
    ==> title-entropy: apollo-reel.sfc — 8 entropy-1 runs per frame vs the entropy-0 reference
      frame   60: PASS  8/8 entropy-1 runs == entropy-0 7c1f93cd248e
      frame  100: PASS  8/8 entropy-1 runs == entropy-0 d001febf8222
      frame  200: FAIL  8/8 entropy-1 runs differ from entropy-0 f6c37d6c6473
    TITLE-ENTROPY: FAIL
    ==> title-entropy: snes-video-reel.sfc — 8 entropy-1 runs per frame vs the entropy-0 reference
      frame   60: PASS  8/8 entropy-1 runs == entropy-0 ffa7948accce
      frame  100: FAIL  3/8 entropy-1 runs differ from entropy-0 fe3ca7395583
      frame  200: FAIL  1/8 entropy-1 runs differ from entropy-0 fe3ca7395583
    TITLE-ENTROPY: FAIL
    ```

    **PASS** (reproduced) — same entropy-0 references as the 2026‑07‑26 plan's record (`f6c37d6c6473`,
    `fe3ca7395583`). Mechanism, from a seeded-entropy bsnes-jg build with a per-instruction trace hook
    (scratch only, not committed), on these exact ROMs: execution is identical across seeds up to the key
    decoder's entry (`svx_decode_payload_wram_key_asm`, instruction 2,510,892 for apollo, 1,365,716 for the
    reel). The staged packet at `$7F:2000` is all `$00` (apollo) / all `$4C` open bus (reel). At frame 200,
    seed 0 is in ordinary decode (apollo `00:8122`, `Y=$0822`, inside the `$0202..$1381` framebuffer) while
    seed 3 is in the overlapping-MVN run fill with the output pointer far outside it — apollo `00:809E`
    `Y=$420B` (the CPU I/O page), reel `C0:80C6` `Y=$A8F3`.

2. The regression guard fails on the unfixed battery ROMs: `dev/battery-video-selfcheck.sh --build <dir>`.

    ```
      apollo-reel: FAIL  stream ABSENT — file $010000 (+63046 bytes) != battroot-before/build/battery/apollo-reel/apollo-reel-stream.bin (ROM is 524288 bytes)
      snes-video-reel: FAIL  stream ABSENT — file $010000 (+2360380 bytes) != assets/snes/video/svx2-full-reel.bin (ROM is 32768 bytes)
    BATTERY-VIDEO-SELFCHECK: FAIL
    ```

    **PASS** (fails as it must; `--no-entropy` shown — the entropy leg's failure is step 1's output).

3. Rebuild both via the battery recipe with the fix; the guard passes, and `dev/title-entropy.sh` PASSes
   at 60/100/200 on both (8 runs).

    ```
      apollo-reel: PASS  stream present — 63046 bytes at file $010000 == battroot/build/battery/apollo-reel/apollo-reel-stream.bin
        ==> title-entropy: apollo-reel.sfc — 8 entropy-1 runs per frame vs the entropy-0 reference
          frame   60: PASS  8/8 entropy-1 runs == entropy-0 7c1f93cd248e
          frame  100: PASS  8/8 entropy-1 runs == entropy-0 d001febf8222
          frame  200: PASS  8/8 entropy-1 runs == entropy-0 1e6cada10eb8
        TITLE-ENTROPY: PASS
      snes-video-reel: PASS  stream present — 2360380 bytes at file $010000 == assets/snes/video/svx2-full-reel.bin
        ==> title-entropy: snes-video-reel.sfc — 8 entropy-1 runs per frame vs the entropy-0 reference
          frame   60: PASS  8/8 entropy-1 runs == entropy-0 ffa7948accce
          frame  100: PASS  8/8 entropy-1 runs == entropy-0 df63954c7004
          frame  200: PASS  8/8 entropy-1 runs == entropy-0 e50d9142b753
        TITLE-ENTROPY: PASS
    BATTERY-VIDEO-SELFCHECK: PASS
    ```

    **PASS.** Also PASS at 60/100/200/400 × 8 on the published `apollo-daylight.sfc` (biohack.net `94de6a37…`,
    indri.studio `a7414291…`) and `svx2-fastrom-video.sfc` (`d71382c8…`) — the shipped ROMs never had the
    defect.

4. The battery `snes-video-reel.sfc` is byte-identical to `dev/snes-video-reel.sh`'s checked-in-asset ROM
   recipe (same sources, cfg, pack, checksum).

    ```
    01a7e074235c33080f47db630aceddd63cc2e260b93e020bf90526a0d050abff  build/svx2-video-reel.sfc
    01a7e074235c33080f47db630aceddd63cc2e260b93e020bf90526a0d050abff  battroot/build/snes-video-reel.sfc
    IDENTICAL
    ```

    **PASS.**

5. Both demos' normal gates still pass: `dev/snes-video-reel.sh` (checked-in assets) and the apollo
   whole-loop self-test on the synthetic corpus.

    ```
    $ VIDEO_REEL_TILES=/nonexistent VIDEO_REEL_PALETTE=/nonexistent dev/snes-video-reel.sh
    using checked-in full reel asset
    packed 2360380 stream bytes at file $010000; ROM=4194304 bytes
    cadence gate: first present at VBlank 179 (reference 179); expecting 0x777 presentations in 4000
    displayed FPS gauge: 30.0 at VBlank 247 and 4000
    ...
    SMOKE: PASS off=0x205 len=4 got=0x00000000 (ran 4000 frames, bsnes-jg)
    SMOKE: PASS off=0x31 len=2 got=0x0777 (ran 4000 frames, bsnes-jg)
    ```

    ```
    $ # apollo-reel.c -DAPOLLO_REEL_SELFTEST, battery recipe + battery-post pack, synthetic 12-frame corpus
    corpus_result@2b health@2c
    SMOKE: PASS off=0x2B len=1 got=0x00 (ran 800 frames, bsnes-jg)
    SMOKE: PASS off=0x2C len=4 got=0x00000000 (ran 800 frames, bsnes-jg)
    -- negative control: same ROM without the stream pack
    SMOKE: FAIL off=0x2B len=1 got=0x02 want=0x00
    ```

    **PASS.** `dev/apollo-reel.sh` itself cannot run: its real-camera corpus defaults to a dead scratchpad
    path (`…/a18c5d7f-…/scratchpad/apollo-v3`, absent). Its whole-loop byte-correctness leg was run on the
    synthetic corpus instead (all 12 frames + loop delta byte-correct; the stream-less ROM fails it with
    `corpus_result = 2`, a frame-check mismatch). No apollo code changed — see step 6.

6. Byte/cycle cost: none in the demo code (no source change beyond build markers); ROM size only.

    ```
    bank-0 code/header diffs: ['0xffd7', '0xffdc', '0xffdd', '0xffde', '0xffdf']
    ```

    **PASS.** apollo's code bank is byte-identical before/after; only the header's ROM-size byte and
    checksum differ. The reel's battery ROM moves from a 32 KiB LoROM to the 4 MiB HiROM cartridge its gate
    has always built (step 4). Zero cycles in either program.
