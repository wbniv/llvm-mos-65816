# jgxcheck timeline captures are nondeterministic by default — make determinism explicit

TODO item (~line 1010): "`dev/jgxcheck` timeline captures are nondeterministic by default — make
determinism explicit." Found by the 121-badges verification: `jgxcheck.cpp:394` leaves
`configuration.entropy` at bsnes-jg's default *Low* whenever the caller doesn't pass `JGX_ENTROPY`,
and `Random::seed()` seeds that from `clock()` — the same frame rendered fully black on one run and
85% non-black on the next; all 121 timeline captures had to be redone with `JGX_ENTROPY=0`. Root
cause already diagnosed by
[`docs/plans/2026-08-01-cartsize-canary-display-nondeterminism.md`](2026-08-01-cartsize-canary-display-nondeterminism.md):
`System::power()` reseeds PPU/VRAM/CGRAM/OAM state from `clock()` at entropy Low/High; WRAM stays
deterministic because it's computed by the ROM, but anything reading the picture is not.

## Problem

`dev/jgxcheck.cpp:394`:

```cpp
if (const char *e = getenv("JGX_ENTROPY")) SuperFamicom::configuration.entropy = (unsigned)atoi(e);
```

`JGX_ENTROPY` (0=None, 1=Low, 2=High) already exists as an override, and five call sites already use
it correctly: `dev/cartsize-canary.sh`, `dev/seamdemo.sh`, `dev/apollo-reel.sh`, `dev/bootblank.sh`,
`dev/m7blank.sh`. But when the variable is **unset**, `configuration.entropy` keeps whatever
`SuperFamicom::settings.hpp:72` default-constructed it to — `1` (Low) — which reseeds from `clock()`
on every `Bsnes::power()`. Roughly 150 other `dev/*.sh` gates call `jgxcheck` without ever touching
`JGX_ENTROPY`, so every one of them boots with clock-seeded PPU state by accident, not by choice. Most
of those gates only assert a computed WRAM value (unaffected by PPU randomness in a correctly-behaved
ROM), so the defect has stayed latent — until a script actually captures or compares a frame (the
121-badges timeline work), where it surfaces exactly as the TODO item describes.

## Design choice — flip the default, keep the existing env var

Three shapes were on the table: a new opt-in flag, a new env var, or changing what the *existing*
`JGX_ENTROPY` var defaults to when absent.

**Chosen: change the default.** `JGX_ENTROPY` unset now means entropy **None (0)**, not bsnes-jg's
Low. The override mechanism doesn't change — `JGX_ENTROPY=0/1/2` still means exactly what it always
meant, and every one of the five call sites that already sets it explicitly is a no-op change (they
already pass a literal value, so flipping the *implicit* default cannot affect them). This is the only
one of the three shapes that fixes the ~150 silent call sites for free.

**Rejected: a new env var** (e.g. `JGX_DETERMINISTIC=1`) that call sites opt into. This inverts the
fix's leverage — it would require editing every existing `jgxcheck` call site to add the new var,
which is the exact "150 accidental non-set" surface the TODO item is about, and any call site an
author forgets stays nondeterministic. A default flip needs zero call-site edits to become safe.

**Rejected: a new CLI flag** on `jgxcheck` itself. Same leverage problem as the new env var (every
call site would need updating), plus it collides with the harness's positional-argument CLI
(`jgxcheck <rom> <datadir> <off> <len> <want> [frames] [out.png]` — no flag syntax exists today) for
no benefit over an env var the harness already parses this way.

**Rejected: patch the default in `vendor/bsnes-jg/src/settings.hpp`.** That's foreign vendor code
(gitignored, re-fetched from a pinned upstream release by `dev/xcheck.sh`); changing bsnes-jg's own
default would silently change the *engine's* real-world default (including the WASM player embedded
on the live site, which intentionally boots at Low/clock-seeded — real hardware powers on
indeterminate). The fix belongs entirely in our own harness (`jgxcheck.cpp`), which already reads
`settings.hpp` only to *override* the value per-run, never to redefine bsnes-jg's shipped default.

### The one call site that deliberately wants entropy live

`dev/bootblank.sh --firstframe` (the `--firstframe` SAFETY GATE) captures a demo's first visible
frame **twice**, with **no** `JGX_ENTROPY` set today, specifically *because* it wants bsnes-jg's
power-on randomisation: if a demo's first frame depends only on `reserve()`'s output and not on
uninitialised VRAM/CGRAM/OAM, the two random draws render identically; if the demo has a paint-before-
emit ordering bug, they render differently and the gate catches it (exit 5). Flipping jgxcheck's
default to None would make this gate vacuously pass — both draws would be the same deterministic
boot, defeating its entire purpose. Fix: give it an **explicit** `JGX_ENTROPY=1` (Low — bsnes-jg's own
real default, matching what real hardware and the site's WASM player expose) so the comparison keeps
testing what it was built to test.

## Files changed

- `dev/jgxcheck.cpp:394` — default `configuration.entropy` to `0` (None) instead of leaving bsnes-jg's
  built-in `1` (Low) when `JGX_ENTROPY` is unset.
- `dev/bootblank.sh` — the `--firstframe` two-capture loop gets an explicit `JGX_ENTROPY=1` so it keeps
  exercising real power-on randomness after the harness default flips.

No demo source changes; no `vendor/` changes; no oracle values change (WRAM asserts are the same
computed bytes regardless of entropy in a correct ROM — that's the whole point of the split this plan
preserves).

## Mockups

No visible surface — this changes a host CLI harness's default seed behaviour, not any rendered page,
UI, or document. Evidence is captured hash/PNG output in §Verification, not a mockup.

## Verification

1. Rebuild `jgxcheck` from the changed source and confirm two back-to-back timeline captures of the
   same ROM are byte-identical with the new default (no `JGX_ENTROPY` set).

    ```
    $ build/jgxcheck build/hello.sfc vendor/bsnes-jg/Database 0x0 2 0x0000 700 /tmp/hello-run1.png
    jgxcheck: wrote /tmp/hello-run1.png (256x224 from native 512x240, yoff=0)
    SMOKE: FAIL off=0x0 len=2 got=0x2000 want=0x0000
    $ sha256sum /tmp/hello-run1.png
    7a93d23c7da476079e53f9c8796ddeeeaa84e2f9c693fd01fac635c2e5679dd3  /tmp/hello-run1.png
    $ build/jgxcheck build/hello.sfc vendor/bsnes-jg/Database 0x0 2 0x0000 700 /tmp/hello-run2.png
    jgxcheck: wrote /tmp/hello-run2.png (256x224 from native 512x240, yoff=0)
    SMOKE: FAIL off=0x0 len=2 got=0x2000 want=0x0000
    $ sha256sum /tmp/hello-run2.png
    7a93d23c7da476079e53f9c8796ddeeeaa84e2f9c693fd01fac635c2e5679dd3  /tmp/hello-run2.png
    $ cmp /tmp/hello-run1.png /tmp/hello-run2.png && echo BYTE-IDENTICAL
    BYTE-IDENTICAL
    ```

    (`SMOKE: FAIL` is the arbitrary WRAM assert used to drive the capture — irrelevant to this
    check, which is about the PNG bytes, not the assert.) Also repeated 8x at 700 frames with the
    same result: `distinct hashes: 1` (expect 1). **PASS.**

2. At least three existing gates that use `jgxcheck` (via `dev/run.sh`) still PASS with unchanged
   oracle hashes after the default flip.

    ```
    $ dev/run.sh a16abs
    ==> MAME: assert corpus_result == 0x5A3D (0x5A3C copied via g, +1)
    SMOKE: PASS addr=0x7E0204 len=2 got=0x5A3D (ran 60 ticks)
    ==> bsnes-jg: assert corpus_result == 0x5A3D (independent confirmation)
      SMOKE: PASS off=0x204 len=2 got=0x5A3D (ran 180 frames, bsnes-jg)
    RESULT: PASS — native 16-bit absolute load/store (lda abs/sta abs) copies 0x5A3C; both emulators read 0x5A3D
    EXIT=0

    $ dev/run.sh absdiff
    ==> host oracle: absdiff gate hash = 0x3482
        PASS: u8, s16, and u32 absolute-difference bodies selected and verified
    SMOKE: PASS off=0x13F7 len=2 got=0x3482 (ran 360 frames, bsnes-jg)
    SMOKE: PASS off=0x13F7 len=2 got=0x3482 (ran 360 frames, bsnes-jg)
    SMOKE: PASS off=0x13F7 len=2 got=0x3482 (ran 360 frames, bsnes-jg)
    RESULT: PASS — Motion-Detect Difference Field; host == default == a16 == xy16 == 0x3482
    EXIT=0

    $ dev/run.sh xy16inplace
        CAP=1700 default = 0x90AA
        SMOKE: PASS off=0x8A4 len=2 got=0x90AA (ran 600 frames, bsnes-jg)
        CAP=1700 a16 = 0x90AA
        SMOKE: PASS off=0x8A4 len=2 got=0x90AA (ran 600 frames, bsnes-jg)
        CAP=1700 xy16 = 0x90AA
        SMOKE: PASS off=0x8A4 len=2 got=0x90AA (ran 600 frames, bsnes-jg)
        CAP=200 default = 0xDEBD
        SMOKE: PASS off=0x2C8 len=2 got=0xDEBD (ran 600 frames, bsnes-jg)
        CAP=200 a16 = 0xDEBD
        SMOKE: PASS off=0x2C8 len=2 got=0xDEBD (ran 600 frames, bsnes-jg)
        CAP=200 xy16 = 0xDEBD
        SMOKE: PASS off=0x2C8 len=2 got=0xDEBD (ran 600 frames, bsnes-jg)
        -verify xy16 clean
    RESULT: PASS — in-place memmove/memcpy over a 16-bit-indexed buffer: default==a16==xy16 on bsnes-jg (CAP 1700 & 200), -verify clean
    EXIT=0
    ```

    All three hashes (`0x5A3D`, `0x3482`, `0x90AA`/`0xDEBD`) are the literal `WANT`/oracle constants
    baked into each script — unchanged from before this fix. None of these three scripts ever set
    `JGX_ENTROPY`, so they are exactly the population the default flip touches. **PASS.**

3. `dev/bootblank.sh --firstframe` still exercises live entropy (two draws can still legitimately
   differ) after its explicit `JGX_ENTROPY=1`, and does not silently degrade into a same-boot no-op
   comparison.

    End-to-end run of the actual gate (not just the isolated mechanism), two demos:

    ```
    $ dev/bootblank.sh --firstframe mandel-oop life
    demo                  blank  note
    ------------------------------------------------
    mandel-oop             f=51  NONDETERMINISTIC first visible frame
    life                  f=301  ok (fe3ca7395583965d)

    FAIL: 1 demo(s) have a nondeterministic first visible frame — a layer is showing
          VRAM that no reserve() wrote. See snesgfx/display.h display_add()'s contract.
    ```

    The gate still discriminates a real mix of outcomes (one NONDETERMINISTIC, one ok) — proof it is
    still comparing two *live* entropy draws, not two identical pinned boots (which would report
    every demo "ok" vacuously). `mandel-oop`'s flagged nondeterminism matches the pre-existing,
    already-tracked defect (TODO: "Convert the seven Mode-7 demo `main()`s off the re-opened boot
    force-blank" names `mandel-oop` explicitly), not a regression from this change.

    Direct proof of the underlying mechanism, isolated from any one demo's robustness: raw WRAM at
    an address `hello.sfc` never writes (`0x1000`), frame 1, 4 runs each.

    ```
    === JGX_ENTROPY=1 (Low, explicit — what --firstframe now passes) ===
    got=0xF911
    got=0x1C1C
    got=0x6A9C
    got=0x0606
    === default (JGX_ENTROPY unset) ===
    got=0x0000
    got=0x0000
    got=0x0000
    got=0x0000
    ```

    Explicit `JGX_ENTROPY=1` still reseeds from `clock()` every run (four distinct values); the new
    default is pinned (`0x0000` every run). `--firstframe`'s two-draw comparison therefore still
    compares two *live* random draws, exactly as designed — it was not turned into a vacuous
    same-boot comparison. (Separately, `hello.c`'s own first-visible-frame PNG came back
    byte-identical across 8 runs at `JGX_ENTROPY=1`/700 frames — that demo has since picked up
    `snes_ppu_reset_blank()`, which is the gate correctly reporting a *fixed* demo, not the gate
    losing its teeth: WRAM proves the entropy channel is still live independent of any one demo's
    robustness.) **PASS.**

4. The five call sites that already pass `JGX_ENTROPY` explicitly (`cartsize-canary.sh`, `seamdemo.sh`,
   `apollo-reel.sh`, `bootblank.sh` main scan, `m7blank.sh`) are unaffected — spot-check one entropy
   sweep gate still produces the pre-fix hash.

    By inspection: the old code (`if (getenv) config.entropy = atoi(getenv)`) and the new code
    (`config.entropy = getenv ? atoi(getenv) : 0`) agree in every case where `getenv` is non-NULL —
    the ternary only changes behaviour when the variable is absent. So any call site that already
    passes a literal value is provably a no-op change. Spot-checked live anyway:

    ```
    $ dev/m7blank.sh mandel-oop
    demo                  first     last   frames note
    ---------------------------------------------------------------
    mandel-oop              239      243        5

    wrote build/m7blank.tsv
    ```

    `5` frames matches the pre-fix figure already on record in `docs/agent-handoff.md`'s
    `wt/display-first-frame-optin` row ("`mandel-oop` ... 5 → 5 post-title frames"). `m7blank.sh`
    pins `JGX_ENTROPY=0` explicitly (line 255), so it is one of the five unaffected call sites.
    **PASS.**

5. (Not in the original scope but load-bearing.) The full regression corpus still passes after the
   rebuild, confirming the default flip doesn't perturb any WRAM-based gate:

    ```
    $ dev/run.sh corpus
    [... build phase: all corpus programs + host oracles built ...]
    ==> corpus: run expected.tsv (MAME settle=1000, backstop=20s)
      hello      PASS  sentinel=0x42  liveness: main runs (the smoke ROM)
      arith      PASS  corpus_result=0xA9E9  8/16/32-bit integer ALU
      [... 61 more programs, every one PASS ...]
      nmitally_sim PASS  corpus_result=0xBCE6  #123 VBlank Interrupt Tally arithmetic gate ...
    ==> corpus: 63/63 passed
    ```

    **PASS.** All 63 corpus programs (none of which set `JGX_ENTROPY`) produced the same oracle
    hashes as before the fix.
