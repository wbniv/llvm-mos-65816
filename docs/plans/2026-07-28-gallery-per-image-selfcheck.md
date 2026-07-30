# Gallery "Verify fidelity" — assert ONE image, not the whole 62-work corpus

**Status:** planned 2026-07-28, user-directed ("make the button per image, not entire gallery").
Blocks [#137](2026-07-27-137-lzss-gallery-new-repack-visualization.md) step 6.

> **2026-07-30 — the per-work failures investigated below are ROOT-CAUSED AND FIXED.** Not a
> miscompile: the hand-written `decode_bank7e` thunk did `lda #$7e / pha / plb`, and the MOS
> convention passes `decode_near`'s `slen` in `A:X`, so every stream whose `(lz_len & 0xFF) > $7E`
> was truncated to `(lz_len & 0xFF00) | $7E`. 29 of 62 works. Full write-up, evidence and the
> `PEA`-based fix: [`2026-07-30-gallery-near-decode-abi-clobber.md`](2026-07-30-gallery-near-decode-abi-clobber.md).
> The "timing-dependent" clue in *Second-pass probe* was a red herring — bsnes-jg randomises the
> WRAM power-on fill, and the un-decoded tail of `FB_A` *was* that fill, feeding different bytes
> into the compressor each run. The truncation itself is fully deterministic.

## Problem

The site manifest's `selfcheck` is not only the offline gate — **it is what the in-page "Verify
fidelity" button runs in the browser**. For `lzss-gallery` it asserts `corpus_result`, which the ROM
only writes once **all 62 works** have decoded, repacked, byte-compared and folded.

Measured 2026-07-28 (`gallery_progress` @ `0x470` read at 200 000 frames):

```
works completed at 200000 frames: 22 of 62
linear need = 200000 * 62/22 = 563636 frames; +25% margin = 704545
```

So the shipped `frames: 200000` cannot reach the assertion, and the button has been failing. Git
history shows why nobody noticed the drift: **`frames` has never been raised while the corpus grew**
— it was set for the ~26-work corpus and carried forward unchanged through every expansion:

| manifest commit | frames | oracle | corpus |
|---|---|---|---|
| `c62d06d` | 200000 | `0x3D44` | ~26 works |
| `c10912e` | 200000 | `0xBA3A` | + Rijksmuseum |
| `91d58f0` | 200000 | `0x1D8E` | 60 works |
| `47d356f` | 200000 | `0x5CF0` | 62 works |
| `72e1b75` | 200000 | `0x839F` | 223-colour |

**Raising `frames` is the wrong fix.** The correct value (~710 000) is two orders of magnitude above
every other demo — median 500, largest non-gallery 6 000 — and would leave the button spinning for
minutes, reading as a hang. The offline gate wants the whole corpus; a person clicking a button
wants one image.

## Decision — split the two audiences

- **The button (site manifest):** assert the *first artwork* only.
- **The full 62-work corpus:** stays exactly where it belongs, in `dev/lzss-gallery.sh`, which
  already drives its own `FRAMES` independently of the manifest. **No coverage is lost** — it moves
  from a check nobody could run to one that already runs offline.

## Design

The ROM already publishes per-work state (`record_result()`), so no ROM change is needed:

| symbol | addr | meaning |
|---|---|---|
| `gallery_progress` | `0x470` | count of completed works |
| `gallery_last_z` | `0x471` | **compressed size of the work that just finished** (uint16) |
| `gallery_last_work` | `0x473` | index of that work |
| `gallery_last_ok` | `0x474` | 1 if that work passed every stage |

Assert **`gallery_last_z == 0x3BC9`** (15305 — work 0's `compressed_bytes` from the host oracle
`report.json`). That is a genuine correctness claim, not a liveness ping: reaching it requires the
ROM to have decoded the LZSS stream, recompressed it, and produced *exactly* the byte count the host
compressor produces. A miscompile in the codec moves it.

> **BLOCKED — the ROM does not currently produce 15305.** It reports `0x3B96` (15254) with
> `gallery_last_ok = 0`. This assertion cannot be wired until that is explained; asserting a number
> that does not hold is exactly how the present broken selfcheck came about. See *Findings* below.

Rejected alternatives:

- `gallery_progress >= 1` — reachable without the output being *right*; a liveness ping, not a gate.
- `gallery_last_ok == 1` — correct but a 1-byte value, far weaker evidence than a 16-bit length that
  must match an independently computed oracle. Worth adding as a second assertion if the manifest
  ever supports more than one field per demo.
- Keeping `corpus_result` and raising `frames` to ~710 000 — the unusable-button case above.

`frames` becomes "just past the first work's completion", measured rather than guessed.

## Steps

1. Measure the frame at which work 0 completes (`gallery_progress` becomes 1); add margin.
2. Point both site manifests' `lzss-gallery` selfcheck at `off 0x471`, `len 2`, `want 0x3BC9`, with
   the measured `frames`, and label it so the page says it is verifying one artwork.
3. Verify the new selfcheck passes headlessly before publishing.
4. Republish both sites.
5. Record the full-corpus expectation in `dev/lzss-gallery.sh` so the 62-work assertion keeps a home.

## Verification

1. `gallery_last_z` reads `0x3BC9` at the chosen frame (raw jgxcheck output pasted below).
2. The value is *not* yet set materially earlier (i.e. the frame budget is genuinely needed, not
   passing by accident on a zeroed field).
3. `dev/verify-web-roms.sh --only lzss-gallery` passes.
4. Live check after deploy: both sites serve the new manifest and the button passes in-page.

## Findings — 2026-07-28 (why this is blocked)

Reading the intended field produced a blocking result. At frame 9000:

```
gallery_last_work = 0x00     work 0 (great-wave / Hokusai)
gallery_last_ok   = 0x00     FAILED
gallery_last_z    = 0x3B96   15254 bytes
GALLERY_ASSETS[0].lz_len     15305 bytes  (0x3BC9)
```

### Ruled out

- **"The images were never palette-remapped."** They were. Both `3e3f054` (223-colour) and
  `dcc80d9` (221-colour, 2026-07-28 08:10) regenerated `.idx`, `.lz`, `.pal`,
  `examples/snes/lzss-gallery-assets.h` **and** `assets/snes/lzss-gallery/derived/report.json` in
  the same commit. There is no asset-vs-oracle regeneration desync.
- **A stale or mismatched oracle.** The ROM does not consult `report.json`; it compares against its
  own embedded `lz_len`. Those agree: `GALLERY_ASSETS[0]` is `great_wave` at 15305, and
  `report.json[0]` is `great-wave` at 15305. Host side is self-consistent.
- **Comparing the wrong artwork.** `report.json`'s `manifest_order` is 1-based, which raised the
  possibility that ROM index `k=0` was some other painting — but the header's array order matches
  `report.json`'s array order, and **no artwork in the 62-work corpus compresses to 15254**, so
  15254 is not some other entry's correct answer.
- **A truncated/cancelled compress.** `compress_far` returns **0** on `nav_cancel`
  (`lzss-gallery.c:527,533,553`), and `verify_stream` short-circuits on `z==0`. A non-zero 15254 is
  therefore a *complete* compression run, not a partial one.

### Second-pass probe — 2026-07-28 (supersedes the first hypothesis)

An earlier revision of this section claimed work 0 skips `unpack_slide` and repacks a stale `FB_A`.
**That is wrong and is retracted.** Work 0 *is* decoded, by `ok = unpack_slide(a)` behind the title
card (`lzss-gallery.c:1167`), before the loop is entered with `decoded = 1`.

Two probes on the shipped ROM (`build/jgxcheck`, `JGX_WRAM_DUMP`):

**1. Stage counters for work 0, at 9000 frames** (`gallery_*_frames[0]`, one entry per array
non-zero — only work 0 had run):

```
unpack_frames[0] @0x2FA =  127 frames
stage_frames[0]  @0x376 =   52 frames
near_frames[0]   @0x3F2 =  118 frames
```

`unpack_slide` short-circuits with `||`, so reaching `benchmark_near_decode` proves
`benchmark_far_decode` **and** `benchmark_stage` both returned 1 — each of which requires
`!nav_cancel`. **The decode pipeline ran in full; nothing bailed early on spurious input.** The
failure is therefore one of the three data-mismatch conditions: `near_ok`, or either
`fold_far(FB_A/FB_B, raw_len) != a->checksum`.

**2. Per-work verdicts at 40 000 frames** (`gallery_failed[62]` @ `0xdfe`, `gallery_done[62]` @
`0xe3c`, contiguous — one 124-byte dump):

```
done[k]   : 1111000000...      4 works completed
failed[k] : 1011000000...
failed: [0, 2, 3]      passed: [1]
```

**This is not work-0-specific — 3 of the first 4 artworks fail their own repack differential.**
The title-path explanation is dead: works 1–3 decode inside the loop, with the splash long gone.

### What still holds

- `record_result` rewrites `gallery_last_z` on every completed work while `gallery_progress` only
  increments when `gallery_done[k]` is clear, so one `k` can be recorded twice with `progress`
  unchanged — the explanation for the `0x3B96` → `0x3B98` drift.
- 15254 is **99.7%** of 15305. Garbage or zeros would compress to a fraction of that, so `FB_A`
  holds a *nearly* correct image with a small corruption — and the run-to-run drift makes that
  corruption timing-dependent.

### Open question — for direction

Three of four works failing a byte-exact differential is either a genuine miscompile in the far
decode / LZSS path (which is exactly the class this demo exists to catch) or a demo-level buffer
bug. Deciding that needs the host-vs-target comparison run per work, not per corpus. Stopped here
at the repo's three-hypothesis limit rather than guessing further.

Note: `dev/lzss-gallery.sh`'s offline gate is being raised 200000 → 700000 in parallel by another
worker (uncommitted at the time of writing), with an independently measured ~10k frames/work that
agrees with the ~9.1k measured here. That fixes the *budget*, not this correctness failure.

## Note on scope

This does not fix, and does not claim to fix, the two pre-existing gate failures found on
2026-07-28: `lzss-gallery`'s selfcheck (this plan) and `lsystem`'s BLANKSCAN (one frame with a
transient black band at the top — force-blank bleed, still unexamined). Neither was introduced by
that day's republish.
