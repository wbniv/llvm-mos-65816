# `lzss-gallery` repack self-check failures — root cause: `decode_bank7e` clobbers an A-passed argument

Closes the investigation opened in
[`2026-07-28-gallery-per-image-selfcheck.md`](2026-07-28-gallery-per-image-selfcheck.md)
("3 of the first 4 artworks fail their own repack differential").

**Verdict: demo bug, not a compiler miscompile.** The `+mos-a16` codegen is correct throughout —
both LZSS decoders and the compressor are byte-exact. The defect is in the demo's own
hand-written assembly thunk.

**No visible surface.** The demo's rendering, timing and layout are unchanged; the only
behavioural difference is that the on-target self-check now passes. No mockups.

## Root cause

`decode_bank7e` enters the *near* decoder with `DB=$7E`:

```asm
decode_bank7e:
  php
  sep #$20        ; $e2 $20
  phb             ; $8b
  lda #$7e        ; <-- CLOBBERS A
  pha
  plb             ; $ab   -> DB = $7E
  jsr decode_near
  plb             ; $ab
  plp
  rts
```

The MOS calling convention hands `decode_near`'s **second parameter, `slen`, in `A:X`**
(low byte in `A`, high byte in `X`). Confirmed from the shipped ROM — `benchmark_near_decode`
ends in:

```
e2 20      sep #$20
a6 09      ldx __rc9      ; hi(a->lz_len)
a5 08      lda __rc8      ; lo(a->lz_len)
20 7b 82   jsr decode_bank7e
```

and `decode_near`'s entry is `85 08 / 86 09` (`sta __rc8 / stx __rc9`) with **no** `rep #$20` —
i.e. the a16 ABI ambient is `M=1` and the `sep` in the thunk is correct; the `lda #$7e` is not.

So the callee saw

```
slen_effective = (a->lz_len & 0xFF00) | 0x7E
```

* `(lz_len & 0xFF) > $7E` → `slen` **shrinks**. `decode_near` runs out of source early,
  returns 0, and leaves the tail of `FB_A` as never-written WRAM. **29 of the 62 works.**
* `(lz_len & 0xFF) <= $7E` → `slen` **grows**. The decode still terminates on `dp == want`
  at the true end of the stream, so the work passes. **33 of the 62 works.**

That rule reproduces the observed verdicts exactly — `failed: [0, 2, 3]`, `passed: [1]`:

| k | work | `lz_len` | `& 0xFF` | effective `slen` | predicted | observed |
|---|------|---------:|---------:|-----------------:|-----------|----------|
| 0 | great-wave    | 15305 | `0xC9` | 15230 | FAIL | FAIL |
| 1 | grande-jatte  | 14879 | `0x1F` | 14974 | PASS | PASS |
| 2 | water-lilies  | 14986 | `0x8A` | 14974 | FAIL | FAIL |
| 3 | basket-apples | 15234 | `0x82` | 15230 | FAIL | FAIL |

### Why the reported symptoms looked the way they did

* **"Recompresses to 15254 vs 15305."** `compress_far` is fed `FB_A`, which is correct for
  bytes `0..15561` and un-decoded WRAM for `15562..15703`. Its output is byte-identical to the
  embedded stream for the first 15228 bytes and only then diverges — strong positive evidence
  that the compressor is *not* miscompiled.
* **"99.7% of the expected size."** Only the last 142 of 15704 input bytes were wrong.
* **"Timing-dependent — `last_z` drifted 0x3B96 → 0x3B98."** Not timing. bsnes-jg randomises
  the WRAM power-on fill per run, and the un-decoded tail of `FB_A` *is* that fill, so it feeds
  different bytes into the compressor on each run. The truncation itself is perfectly
  deterministic: two runs at the same frame count both gave
  `FB_A ndiff=142, first=15562`.
* **Which condition in `unpack_slide` fails:** `benchmark_near_decode`'s `near_ok`. `||`
  short-circuits, so the two `fold_far` checksum tests are never even reached. `FB_B`
  (the *far* decoder, `decode_far`) is **byte-perfect** — `ndiff=0` against the source `.idx`.

## The fix

`examples/snes/lzss-gallery.c` — set `DB` without touching the accumulator, using `PEA`
(the same discipline the NMI already used with `PHK`/`PLB`):

```asm
decode_bank7e:
  php
  phb                 ; $8b
  pea $7e7e           ; $f4 $7e $7e  - two $7E bytes, A untouched
  plb                 ; $ab -> DB = $7E
  plb                 ; $ab -> drop the duplicate $7E
  jsr decode_near
  plb                 ; $ab -> restore caller's DB
  plp
  rts
```

`PEA`/`PLB` are width-independent, so the `sep #$20` the old one-byte `pha`/`plb` pairing
required is gone as well. Rejected alternative: `pha` / `lda #$7e` / `pha` / `plb` / `pla`.
It works, but leaves "A carries an argument here" as an implicit invariant that the next
edit can break again; `PEA` removes the hazard structurally.

## Regression guards

`dev/lzss-gallery.sh` gains two, because every existing cheap check passed while this was
broken (host oracle, link, header audit, and `QUICK=1` which only asserts
`gallery_progress == 0`):

1. **`decode_bank7e` ABI audit** (instant, static) — requires `f4 7e 7e` in the thunk and
   rejects any `a9` (`LDA #imm`) in it. Mirrors the existing NMI opcode audit.
2. **Fast single-work self-check gate** (~3 min, vs ~2.5 h for the 62-work corpus) — builds a
   probe ROM with `GALLERY_START` set to the **first work whose `(lz_len & 0xFF) > 0x7E`**
   (read from `report.json`, so a corpus regeneration cannot silently move the gate off the
   failing class) and asserts `gallery_last_ok == 1`. This fails on the pre-fix ROM and passes
   on the fixed one.

## Verification

1. Host round-trip oracle: `lzss_compress(lzss_decode(lz)) == lz` for all 62 works.

```
great-wave.idx    raw=15704 lz=15305 dec_ok=1 recomp=15305 IDENTICAL firstdiff=-1
grande-jatte.idx  raw=14400 lz=14879 dec_ok=1 recomp=14879 IDENTICAL firstdiff=-1
water-lilies.idx  raw=15000 lz=14986 dec_ok=1 recomp=14986 IDENTICAL firstdiff=-1
basket-apples.idx raw=15792 lz=15234 dec_ok=1 recomp=15234 IDENTICAL firstdiff=-1
...
IDENTICAL: 62    DIFFERS: 0
```

**PASS** — the reference codec is idempotent on every asset, so the assets and the oracle
agree and the divergence is target-side.

2. Pre-fix WRAM evidence on the shipped ROM (`JGX_WRAM_DUMP=0 JGX_WRAM_DUMP_LEN=59392`,
   9000 frames, two independent runs):

```
corpus_result=0x0000 progress=1 last_z=15255 last_work=0 last_ok=0
done   : 1000...      failed : 1000...
FB_A(near-decode) vs idx: len=15704 ndiff=142 first=15562 last=15703
FB_B(far-decode)  vs idx: len=15704 ndiff=0
PACK vs great-wave.lz   : len=15305 ndiff=25  first=15228

FB_A tail (142 B) distinct values: [0x6b, 0x6f, 0x94]      <- never written
above-FB_A (0xE558..): 94 94 94 94 6b 6b 6b 6b 94 94 ...   <- same untouched fill
above-FB_B (0x5D58..): 6b 6b 6b 6b 94 94 94 94 6b 6b ...

host trace of the correct decode: at dp=15562, sp=15230
                          15230 == (15305 & 0xFF00) | 0x7E
run a: last_z=15255  FB_A ndiff=142 first=15562  FB_B ndiff=0
run b: last_z=15256  FB_A ndiff=142 first=15562  FB_B ndiff=0
```

**PASS** — the far decoder is byte-perfect; the near decoder stops exactly where the
clobbered `slen` runs out. `last_z` jitters only because the un-decoded tail is
randomised power-on WRAM; the truncation is identical in both runs.

3. Post-fix static audit (the new guard, run against both ROMs):

```
pre-fix : FATAL - decode_bank7e must use PEA $7E7E;
          got 08 e2 20 8b a9 7e 48 ab 20 89 82 ab 28 60   (exit 1 -- correctly rejected)
post-fix: PASS (A-safe PEA/PLB;
          got 08 8b f4 7e 7e ab ab 20 8a 82 ab 28 60)     (exit 0)
```

**PASS** — the guard discriminates; it is not vacuous.

4. Post-fix behavioural, work 0 (`great-wave`, low byte `0xC9` — a pre-fix failure),
   12000 frames:

```
SMOKE: PASS off=0x476 len=1 got=0x01 (ran 12000 frames, bsnes-jg)
corpus_result=0x0000 progress=1 last_z=15305 last_work=0 last_ok=1
done: [0]   failed: []
```

`last_z == 15305 == lz_len`, so the on-target `exact_stream` (all 15305 bytes),
`verify_decode` (second decode + checksum) and `verify_bytes` (all 15704 bytes,
`FB_A` vs `FB_B`) all passed. By 12000 frames the buffers already hold work 1, and
all three are byte-identical to its assets:

```
work1 grande-jatte FB_A vs idx: ndiff=0   BYTE-IDENTICAL
work1 grande-jatte FB_B vs idx: ndiff=0   BYTE-IDENTICAL
work1 grande-jatte PACK vs lz : ndiff=0   BYTE-IDENTICAL
```

**PASS**

5. Post-fix, first four works (45000 frames) — the three that used to fail now pass:

```
progress=4  last_work=3  last_ok=1  last_z=15234
done   = [0, 1, 2, 3]
failed = []
last_work 3 = basket-apples: embedded lz_len=15234, recompressed z=15234 -> MATCH

  k= 0 great-wave     lz_len=15305 low=0xC9  pre-fix=FAIL  post-fix=PASS
  k= 1 grande-jatte   lz_len=14879 low=0x1F  pre-fix=pass  post-fix=PASS
  k= 2 water-lilies   lz_len=14986 low=0x8A  pre-fix=FAIL  post-fix=PASS
  k= 3 basket-apples  lz_len=15234 low=0x82  pre-fix=FAIL  post-fix=PASS
```

**PASS**

6. The new fast decode gate (`GALLERY_BENCH_ONLY`, all 62 works, 30000 frames), run on both
   the fixed and the pre-fix thunk:

```
bench-fixed  (want 0x5CF0): SMOKE: PASS off=0x24 len=2 got=0x5CF0 (30000 frames, bsnes-jg)
bench-prefix (want 0xA50F): SMOKE: PASS off=0x24 len=2 got=0xA50F (30000 frames, bsnes-jg)
```

**PASS** — all 62 works far-decode, stage, near-decode and checksum clean after the fix
(`0x5CF0`), and the same gate latches the failure verdict (`0xA50F`) on the pre-fix thunk.
This is the check that would have caught the bug, in ~6 min instead of ~2.5 h.

## Not done / follow-ups

* **Not merged to `main`.** The fix lives on this worktree branch. `main`'s
  `dev/lzss-gallery.sh` carries another worker's uncommitted `FRAMES` change (200000 →
  700000); my edits deliberately don't touch that logic, so the merge should be clean, but
  it is someone else's call when to take it.
* **The full 62-work *visual* corpus gate was not re-run** (~2.5 h). Coverage of the codec
  paths for all 62 works comes from the `GALLERY_BENCH_ONLY` gate in step 6 instead; the
  visual ROM was verified over works 0–3 only.

  **2026-07-31 full visual sweep:** now run — `FRAMES=700000 dev/run.sh lzss-gallery` (no
  `GALLERY_BENCH_ONLY`, no `QUICK`; throwaway worktree `throwaway/visual-sweep` off `main`
  HEAD `2343db7`, which carries the fix). The visual jgxcheck leg took 1 h 25 m (700 000
  frames, ~137 fps); whole script ~1 h 31 m:

  ```
  SMOKE: PASS off=0x24 len=2 got=0x5CF0 (ran 30000 frames, bsnes-jg)
  fast decode gate: PASS (all 62 works far-decoded, staged, near-decoded, checksummed)
  ==> corpus_result @ WRAM 0x46f; oracle 0x96D8
  SMOKE: PASS off=0x46F len=2 got=0x96D8 (ran 700000 frames, bsnes-jg)
  cad7bfccffb5bd2e567da62e8b4fc7c8475ec5853d5a1452cf92bb3150e091d6  /work/build/lzss-gallery.sfc
  RESULT: PASS — 62-work LZSS gallery host oracle, relink, header and bsnes-jg gate
  ```

  **PASS** — the presentation ROM's `corpus_result` latched the full 62-work rolling hash
  (`0x96D8`, one `(checksum, compressed_bytes)` fold per work), so every work decoded,
  displayed, repacked and self-checked clean through the *visual* path, not just the
  bench-only codec path. No FROZEN/BLANKSCAN flags: this gate does not arm `JGX_BLANKSCAN`,
  so the known turtle-vm/truchet/lzdec suspected-false-positive detectors were not in play.
  Gotcha found en route: **committed `dev/run.sh` does not forward `FRAMES` into Docker**
  (only `BENCH_FRAMES`/`GALLERY_START`/`GALLERY_RUN_COLOR`; the `${FRAMES:+-e FRAMES}`
  forward exists only as an uncommitted edit in `main`'s dirty tree), so a first attempt
  silently ran the committed 200 000-frame default and reported the known budget-too-short
  symptom `got=0x0000` at ~36 min (≈ 20 of 62 works). The worktree re-run above added the
  forward locally; landing that forward (and the 700 000 default) on `main` is the
  committed-tree fix.
* **Unrelated compiler crash found in passing.** `mos-clang ... -fno-lto -S` on
  `examples/snes/lzss-gallery.c` segfaults in `MOS Late Optimizations` on `@unpack_slide`
  at `-O0` and `-Oz` (clean at `-O1`). The shipped ROM builds with LTO, where the pass does
  not crash, so this does not affect the demo — but it is a real backend bug and is
  **not investigated here**.
