# Gallery "Verify fidelity" — assert ONE image, not the whole 62-work corpus

**Status:** planned 2026-07-28, user-directed ("make the button per image, not entire gallery").
Blocks [#137](2026-07-27-137-lzss-gallery-new-repack-visualization.md) step 6.

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

### Leading hypothesis (unproven)

Not a codec miscompile — **the buffer being compressed is not a clean decode of asset 0.**
`repack_slide` compresses `FB_A`, and two details in the main loop point at `FB_A` being wrong
rather than the compressor being wrong:

1. The loop is entered with `decoded = 1` (`lzss-gallery.c:1190`), so the **first** work skips
   `unpack_slide` entirely — work 0's `FB_A` is whatever the title/prepare path left behind, not a
   fresh decode.
2. `record_result` rewrites `gallery_last_z` on **every** completed work, but `gallery_progress`
   only increments when `gallery_done[k]` is still clear. So the same `k` can be recorded twice
   with `progress` unchanged — which is the missing explanation for the previously unexplained
   drift `0x3B96` (frame 9000) → `0x3B98` (frame 12000) while `progress` stayed at 1.

Two different compressed lengths for the same artwork is the strongest evidence here: a
deterministic compressor over identical input cannot produce both, so the *input* is varying.

Stopped at the repo's three-hypothesis limit. Next probe would be to read `gallery_last_ok` /
`last_z` across the first two full work cycles, and to check whether work 0 passes when it is
reached on the *second* pass (i.e. after a real `unpack_slide`), which would confirm (1) directly.

## Note on scope

This does not fix, and does not claim to fix, the two pre-existing gate failures found on
2026-07-28: `lzss-gallery`'s selfcheck (this plan) and `lsystem`'s BLANKSCAN (one frame with a
transient black band at the top — force-blank bleed, still unexamined). Neither was introduced by
that day's republish.
