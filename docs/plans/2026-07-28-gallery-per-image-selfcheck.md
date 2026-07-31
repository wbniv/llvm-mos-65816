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

- **The button (site manifest):** assert **the artwork the gallery is currently displaying**.
  *(Will's call, 2026‑07‑31 — supersedes the original "first artwork only".)*
- **The full 62-work corpus:** stays exactly where it belongs, in `dev/lzss-gallery.sh`, which
  already drives its own `FRAMES` independently of the manifest. **No coverage is lost** — it moves
  from a check nobody could run to one that already runs offline.

Why the change matters: a visitor who has browsed to *Water Lilies* and presses **Verify fidelity**
is making a claim about *Water Lilies*. A button hard-wired to work 0 would answer a question the
visitor did not ask, and would keep reporting "verified" no matter how far they navigated — which
is the same category of mistake as the whole-corpus assertion this plan replaced: a check whose
subject is not the thing on screen.

> **This respecification is NOT implemented.** The verification recorded below was performed against
> the superseded work‑0 design, and it stands as evidence that the *codec* is correct — but the
> button itself now needs the mechanism worked out (below) and is queued as this item's next phase.

## Design

The ROM already publishes per-work state (`record_result()`), so no ROM change is needed:

| symbol | addr | meaning |
|---|---|---|
| `gallery_progress` | `0x471` | count of completed works |
| `gallery_last_z` | `0x473` | **compressed size of the work that just finished** (uint16) |
| `gallery_last_work` | `0x475` | index of that work |
| `gallery_last_ok` | `0x476` | 1 if that work passed every stage |

> **These addresses are link addresses — they move.** The table above was re-measured 2026‑07‑31
> from `build/lzss-gallery.map`; an earlier revision listed them one to two bytes lower
> (`0x470`/`0x471`/`0x473`/`0x474`), and wiring the button from those stale values would have
> asserted `gallery_progress` instead of `gallery_last_z`. **Always read the symbol out of the map
> of the exact ROM being shipped** — never copy an address out of this document.

The superseded work‑0 design asserted **`gallery_last_z == 0x3BC9`** (15305 — work 0's
`compressed_bytes` from the host oracle `report.json`). That is a genuine correctness claim, not a
liveness ping: reaching it requires the ROM to have decoded the LZSS stream, recompressed it, and
produced *exactly* the byte count the host compressor produces. A miscompile in the codec moves it.

> **UNBLOCKED 2026‑07‑31 — the ROM now produces exactly 15305.** The `0x3B96` (15254) reading was
> the `decode_bank7e` A‑clobber; with the fix landed on `main` (`2932bcf`) a 12 000‑frame run reads
> `gallery_last_z = 0x3BC9` with `gallery_last_ok = 1`. Raw output under *Verification* below.

### Design notes for "currently displayed" — mechanism not yet chosen

**The core obstacle: one manifest entry can only assert one static value.** The manifest's
`off`/`len`/`want`/`frames` tuple is a single constant comparison — the player powers on, runs
`frames`, reads `len` bytes at `off`, and compares to `want`. "Whatever is on screen right now" is
by definition not a constant, so *something* has to bridge that. Two ways:

**(a) Player-side oracle table.** Ship the 62 `compressed_bytes` values from
`assets/snes/lzss-gallery/derived/report.json` to the player, and have the ROM publish the
**displayed-work index**. The button reads the index, looks up the expected size, and compares
against the ROM's reported size for that work.
*Cost:* the manifest schema grows from a scalar `want` to a keyed table, and the player needs a
lookup path it does not have today. *Benefit:* the oracle stays host-computed and independent —
the ROM never gets to assert its own correctness, which is what makes the check meaningful.

**(b) ROM-side check-on-display.** The ROM verifies the work it is displaying and publishes a
uniform pass/fail byte plus the work id. The button asserts the constant "pass", and shows the id.
*Cost:* the ROM becomes its own judge, so a codec bug that is symmetric between decode and repack
could self-certify; the independent host oracle drops out of the loop. Needs a ROM change.
*Benefit:* the manifest stays a scalar comparison — no player or schema change at all.

**What the ROM would have to publish either way.** The existing trio is the wrong state:
`gallery_last_work` / `gallery_last_z` / `gallery_last_ok` describe the **last *processed*** work —
the decode/repack pipeline's cursor, written by `record_result()` as the benchmark sweeps forward.
The **browsing cursor** — which artwork the viewer has navigated to and is looking at — is separate
state that the ROM does not currently expose. A "currently displayed" button needs that cursor
published (and, for (a), the per-work repacked size retained for the displayed work rather than
overwritten by the sweep, since `record_result()` rewrites `gallery_last_z` on every completed
work).

> The link-address warning above applies to every one of these symbols: whatever the ROM ends up
> publishing, its address must be read from the shipped ROM's `.map`, never copied from this
> document. `dev/sync-manifest-offsets.py` resyncs `off` via `selfcheck.symbol`.

Rejected alternatives:

- **Assert the *first* artwork only (work 0)** — the original decision here, superseded by Will on
  2026‑07‑31: it verifies a work the visitor may not be looking at, and reports "verified"
  regardless of where they have navigated. Retained as the fallback if the mechanism above proves
  disproportionate to the value.
- `gallery_progress >= 1` — reachable without the output being *right*; a liveness ping, not a gate.
- `gallery_last_ok == 1` — correct but a 1-byte value, far weaker evidence than a 16-bit length that
  must match an independently computed oracle. Worth adding as a second assertion if the manifest
  ever supports more than one field per demo. (Note this is close to mechanism (b), and carries the
  same self-certification caveat.)
- Keeping `corpus_result` and raising `frames` to ~710 000 — the unusable-button case above.

`frames` becomes "long enough that the displayed work has been verified", measured rather than
guessed — under the superseded work‑0 design that was 12 000, measured below.

## Steps

1. ~~Measure the frame at which work 0 completes (`gallery_progress` becomes 1); add margin.~~
   **Done 2026‑07‑31** — work 0 is complete well before 12 000 frames (`progress = 1`,
   `last_ok = 1`); 12 000 is the measured budget with margin.
2. **RESPECIFIED 2026‑07‑31, not implemented.** Choose mechanism (a) or (b) from *Design notes for
   "currently displayed"*, publish the browsing cursor from the ROM, and wire the button to the
   displayed work.

   > The superseded work‑0 wiring, kept because it is measured and ready if the fallback is taken:
   > `off` = the map's `gallery_last_z` (`0x473` in the 2026‑07‑31 build — re-read it),
   > `len 2`, `want 0x3BC9`, `frames 12000`, `"symbol": "gallery_last_z"`.

3. Verify the new selfcheck passes headlessly before publishing.
4. Republish (biohack.net only — indri.studio has no `public/play/roms/manifest.json`).
5. ~~Record the full-corpus expectation in `dev/lzss-gallery.sh`~~ **Done** — the all-62-work
   `GALLERY_BENCH_ONLY` decode gate (`0x5CF0` all-pass / `0xA50F` any-failure) landed with the fix.

> **The `"symbol"` field is mandatory here, not decorative.** `dev/sync-manifest-offsets.py`
> rewrites every selfcheck's `off` to the freshly rebuilt ROM's link address, and it used to
> resolve **`corpus_result` for every demo unconditionally**. Pointing this button at
> `gallery_last_z` without teaching that script would have let the next republish silently rewrite
> `off` back to `corpus_result`'s address — the button would then assert `0x3BC9` against the
> whole-corpus field and fail for visitors. The script now honours an optional
> `selfcheck.symbol`, defaulting to `corpus_result`, so existing entries are unaffected.
>
> Consequence for sequencing: **the manifest edit must land together with the republished ROM.**
> `sync-manifest-offsets.py` deliberately refuses to trust a map unless `build/<slug>.sfc` is
> byte-identical to the shipped ROM, so the button cannot be wired before the gallery ROM is
> rebuilt from the fix and published.

## Verification

> **Scope of this evidence.** Steps 1–2 below were run against the **superseded work‑0 design**.
> They remain valid as proof that the *codec* and the *repack differential* are correct — which is
> what unblocked this plan — but they are not a validation of the respecified
> "currently displayed" button, which is unimplemented.

1. `gallery_last_z` reads `0x3BC9` at the chosen frame (raw jgxcheck output pasted below).

```
SMOKE: PASS off=0x473 len=2 got=0x3BC9 (ran 12000 frames, bsnes-jg)
jgxcheck: WRAM @0x46F: 00 00 01 01 C9 3B 00 01 00 46 00 00 00 00 00 00
                             ^^    ^^^^^ ^^ ^^
                       progress=1  last_z  |  last_ok=1
                                   0x3BC9  last_work=0
```

**PASS** — 15305 is exactly `report.json[0].compressed_bytes` for `great-wave`, and
`gallery_last_ok = 1` means that work cleared every stage (far decode, stage, near decode, both
`fold_far` checksums, and the byte-exact repack).

2. The value is *not* yet set materially earlier (i.e. the frame budget is genuinely needed, not
   passing by accident on a zeroed field).

**PASS** — `corpus_result` is still `0x0000` in the same dump, so the field being asserted is
distinct from the whole-corpus latch and is written only when work 0 actually completes. The
pre-fix ROM reached this same field and reported `0x3B96`/`ok=0`, which is what makes this a
correctness assertion rather than a liveness ping: a broken codec moves the number.

3. `dev/verify-web-roms.sh --only lzss-gallery` passes.

**NOT RUN — blocked on the republish.** The shipped `~/biohack.net/public/play/roms/lzss-gallery.sfc`
is still the pre-fix ROM, so this check would assert the new value against the old binary. It runs
once the gallery ROM is rebuilt and published.

4. Live check after deploy: both sites serve the new manifest and the button passes in-page.

**NOT RUN — blocked on the republish.** (Scope correction: only biohack.net has a
`public/play/roms/manifest.json`; indri.studio has none.)

### Added 2026‑07‑31 — the works 0–3 repack differential (the gate this plan was blocked on)

Visual ROM built from `main` after the fix landed, 40 000 frames, bsnes-jg, one 2568-byte WRAM dump
decoding `gallery_failed[62]` @ `0xdf9` and `gallery_done[62]` @ `0xe37`:

```
SMOKE: PASS off=0x471 len=1 got=0x04 (ran 40000 frames, bsnes-jg)

gallery_progress = 4      gallery_last_work = 3
gallery_last_z   = 15234 (0x3B82)   == basket-apples' embedded lz_len
gallery_last_ok  = 1

done[k]   : 111100000000...      done   = [0, 1, 2, 3]
failed[k] : 000000000000...      failed = []
```

**PASS** — against the recorded pre-fix observation `failed = [0, 2, 3]`. All four works now pass
their own decode → repack → byte-compare.

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

### Open question — ANSWERED 2026‑07‑31: demo bug

> Three of four works failing a byte-exact differential is either a genuine miscompile in the far
> decode / LZSS path (which is exactly the class this demo exists to catch) or a demo-level buffer
> bug.

**It was the demo — a hand-written assembly ABI violation, not a `+mos-a16` miscompile.** The
codegen is correct throughout; it faithfully implemented the A:X argument convention that the
thunk then violated. Re-verified independently before landing (`2932bcf`):

- **The ABI, read off the shipped ROMs.** Caller `benchmark_near_decode` ends
  `ldx $9 (__rc9) / lda $8 (__rc8) / jsr decode_bank7e`; callee `decode_near` opens
  `sta $28 / stx $29`. So `slen` genuinely travels in `A:X`, low byte in A. The pre-fix thunk sat
  between them executing `lda #$7e`, destroying A before the callee read it.
- **The model predicts rather than describes.** `slen_effective = (lz_len & 0xFF00) | 0x7E` fails
  exactly when `(lz_len & 0xFF) > $7E`. That forecasts **29 of 62** works corpus-wide (matching the
  independently reported count) and reproduces the per-work outcome for works 0–3 — `FAIL, pass,
  FAIL, FAIL`, **4/4 correct**. For work 0 it predicts the decode starves at `sp = 15230`, matching
  the recorded host trace exactly.
- **The gate discriminates.** Rebuilt from source, 62 works, bsnes-jg, 30 000 frames:
  fixed ROM → `corpus_result 0x5CF0` (all pass); pre-fix control → `0xA50F` (failure latched).

The "timing-dependent" clue was a red herring, as the banner at the top of this document records.

Note: the `decode_near` / `FB_A`‑`FB_B` / NMI‑DBR machinery that a later handoff described as
uncommitted work-in-progress was **already committed on `main`**; the only uncommitted delta was
the 31-line thunk fix itself.

Note: `dev/lzss-gallery.sh`'s offline gate is being raised 200000 → 700000 in parallel by another
worker (uncommitted at the time of writing), with an independently measured ~10k frames/work that
agrees with the ~9.1k measured here. That fixes the *budget*, not this correctness failure.

## Note on scope

This does not fix, and does not claim to fix, the two pre-existing gate failures found on
2026-07-28: `lzss-gallery`'s selfcheck (this plan) and `lsystem`'s BLANKSCAN (one frame with a
transient black band at the top — force-blank bleed, still unexamined). Neither was introduced by
that day's republish.
