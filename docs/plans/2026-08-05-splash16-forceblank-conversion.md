# Finish the force-blank conversion: `snesgfx/splash.h` + `splash16` — NULL RESULT

**Date:** 2026-08-05
**Item:** TODO `[T3] Finish the force-blank conversion: snesgfx/splash.h + splash16 in title_layer.h`
**Predecessor:** [Mode 7 splash force-blank floor](2026-08-05-mode7-splash-forceblank-floor.md) (the settled contract)
**Status:** **DONE — option (A), deleted.** No conversion was possible; the dead surface was removed instead.

> **Coordinator decision (2026-08-05): (A) delete.** Rationale recorded: it is our own demo-library
> surface (not upstream-shipped), it has zero consumers, it was superseded twice (`b6ef256`, `8ac159f`),
> the zero-ROM-byte impact is provable without a rebuild, and leaving the dead surface in place keeps
> regenerating stale work items. Execution record at the bottom of this file.

---

## Verdict in one line

Both conversion targets have **zero consumers anywhere in the tree**. The conversion the item
describes — "lands across every `splash.h`/`splash16` consumer's `main()`" — has an empty domain, and
the before/after force-blank measurement the brief asks for cannot be taken because no ROM contains
either code path.

## Consumer enumeration (the deliverable the item asked for first)

Enumerated with `git grep` over the whole tree excluding `docs/` and frozen `*.patch` artifacts:

| Symbol | Definition | Call sites | Includes |
|---|---|---|---|
| `splash_show()` | `examples/snes/snesgfx/splash.h:44` | **0** | **0** — nothing `#include`s `snesgfx/splash.h` |
| `_splash_line()` | `examples/snes/snesgfx/splash.h:29` | 2, both inside `splash.h` | — |
| `splash16()` | `examples/snes/snesgfx/title_layer.h:506` | **0** | (header is included by ~125 demos; the function is never called) |

The only non-definition references in the tree are non-executing:

- `dev/title-charset.sh:74` — `splash16` is one alternative in the call-site scanning regex. It matches nothing today and costs nothing.
- `dev/snes-display-quality-baseline.json` — **11 recorded entries** for `splash.h` (10 `ppu-write`, 1 `force-blank` at line 70). These describe dead code.
- `TODO.md:599`, `TODO.md:2132` — historical Done line and the deferral-audit fingerprint that produced this item.

### Why they are unreferenced — the history

Both were superseded by the very system that replaced them, and the "Still to convert" line in
`docs/agent-handoff.md:192` has been stale ever since:

- `splash_show()` — the pre-`title_layer.h` splash. Its call sites (`julia`, `buddha`, `blossom`,
  `mandel-display`, `mandel-float`, `avalanche`) were introduced in `8f87929` and removed in
  `b6ef256` *feat(snesgfx): counter-sliding title screen*, which replaced it with the BG2 `TitleLayer`.
- `splash16()` — the Mode-7 drop-in. Its last call sites were removed in
  `8ac159f` *fix(snes): align title effects with display modes*, which moved the Mode-7 demos onto
  `m7splash_begin`/`m7splash_end` — i.e. onto the exact path that was converted yesterday.

So the Mode 7 splash work did not leave "the remaining half" behind. It converted the *live* path and
what remains are the two **predecessors** of that path.

## Per-demo impact table

Empty by construction. For completeness, the twelve demos `dev/m7blank.sh` discovers via
`grep -l m7splash` all reach the title through `m7splash_*` — none through `splash16` or `splash_show`.

| Demo | Uses `splash16` / `splash_show` | Force-blank frames before | after |
|---|---|---|---|
| *(none)* | — | — | — |

## Are the two helpers even non-conforming?

Checked against the contract at `examples/snes/snesgfx/m7title.h:22-58`, and **neither is**:

- `splash16` (`title_layer.h:506-512`) ends with `REG_INIDISP = 0x80` for the caller's Mode-7/VRAM
  setup — structurally identical to `m7splash_end()`, which the contract explicitly blesses. Rule 2
  (only PPU registers and DMA between `end()` and the release) is a constraint on the **caller**.
- `splash_show` (`splash.h:44-74`) asserts blank at exit and then does a `SPLASH_CLEAR_WORDS` (0x4400
  word) VRAM wipe inside it. That is PPU/VRAM work — contract-legal under rule 2, and the largest
  single cost in the function.

In both cases the frames the contract exists to recover live entirely in **caller** code executed
inside the window. With no callers there is no cost to recover and no edit that would change a single
emitted byte of any ROM.

Rot check: `splash.h` is never `#include`d, so it is never type-checked by any build. Compiled
explicitly against the SDK config to confirm it has not bit-rotted — clean (see verification 3).
`splash16` is type-checked by every demo that includes `title_layer.h`.

## The decision this needs (why it is escalated, not landed)

The item's work is not "convert" but "keep or delete", and that is a policy call about the SDK's
example surface, not an implementation detail:

- **(A) Delete** `examples/snes/snesgfx/splash.h` and `splash16` from `title_layer.h`. Also drops the
  `splash16` alternative from `dev/title-charset.sh:74` and the 11 stale `splash.h` rows from
  `dev/snes-display-quality-baseline.json`. Zero ROM bytes change (nothing references them), so every
  demo's differential hash is provably unaffected without a rebuild.
  **Coordination:** the baseline rows overlap the concurrent T1 baseline cleanup — the deletion must
  be sequenced with it, not applied in parallel.
- **(B) Keep** as a documented-dead SDK example. Then the correct follow-up is a one-line docs fix
  (`docs/agent-handoff.md:192` no longer says "Still to convert") plus an "unused" marker on both, so
  the next deferral audit does not regenerate this same item.

Recommendation: **(A)**, with the `agent-handoff.md:192` line rewritten either way. Not taken
unilaterally — deleting a shipped SDK example header is a surface decision, and the baseline rows
belong to another agent's in-flight work.

## Execution record — option (A), 2026-08-05

The T1 baseline cleanup (`9bc0c50`) had landed and `dev/snes-display-quality-baseline.json` was clean,
so the baseline rows were free to edit. Every file below was confirmed clean before editing.

| File | Change |
|---|---|
| `examples/snes/snesgfx/splash.h` | **Deleted** (`git rm`) — 77 lines, `splash_show` + `_splash_line`. |
| `examples/snes/snesgfx/title_layer.h:503` | `splash16()` definition removed; replaced by a tombstone comment pointing at `m7splash_*` and this plan. |
| `dev/title-charset.sh:9,74` | `splash16` dropped from the call-site scanning regex and its doc comment. |
| `dev/snes-display-quality-baseline.json` | **12** rows removed, not 11 — the 11 `splash.h` rows *plus* one that the first pass missed: `b5eacd22175169f73a1a`, the `force-blank` row for `title_layer.h:511` (`REG_INIDISP = 0x80`), which lived **inside** the deleted `splash16` body. Findings 252 → 240. |
| `docs/agent-handoff.md` | The stale "Still to convert" line rewritten to record the resolution, citing both superseding commits. |

**The 12th row is the one lesson here.** The deletion set derived from grep was one row short, because a
baseline entry keyed on `title_layer.h` was describing a line inside the block being deleted. The gate
does *not* fail on an unmatched baseline row, so it would have passed silently with the stale row left
behind — exactly the drift `9bc0c50` had just finished cleaning. It was caught only by the reviewed-site
count dropping by 12 when 11 was expected. **Reconcile the count, not just the exit status.**

## Verification of the deletion

1. Zero remaining references (source, scripts, baseline).

    ```
    $ git grep -n -e 'splash_show' -e 'splash16' -e 'snesgfx/splash\.h' -- . ':!docs/' ':!*.patch' ':!TODO.md'
    examples/snes/snesgfx/title_layer.h:503:/* NOTE: splash16() — the standalone Mode-7 drop-in that wrapped title_begin/title_end and
    examples/snes/snesgfx/title_layer.h:508: * docs/plans/2026-08-05-splash16-forceblank-conversion.md. */
    ```

    **PASS** — the only two hits are the tombstone comment's own prose. No definition, no call, no
    include, no baseline row, no scanner alternative.

2. `dev/title-charset.sh` still passes with the regex alternative removed.

    ```
    $ bash dev/title-charset.sh
    checked 124 title call sites across 138 demo sources
    PASS  every title character has a glyph
    exit=0
    ```

    **PASS** — 124 call sites, unchanged (the removed alternative was matching nothing).

3. SNESDQ display-quality gate, baseline 12 rows lighter.

    ```
    $ python3 dev/snes-display-quality.py
    SNESDQ: PASS (240 reviewed sensitive access sites; display order and upload budgets valid)
    ```

    **PASS** — 240 reviewed sites against 240 baseline findings, an exact reconciliation (252 − 12).

4. Canary demo gate proving hashes unmoved — `1d-ca` (a `title_begin16` consumer, so it includes the
   edited `title_layer.h`).

    ```
    $ dev/run.sh 1d-ca
    ==> host oracle: 1-D CA gate hash = 0xAB2C
    ==> disasm gate (ca_step: shift/bool ops, no mul/div, no rep/sep in hot path)
        PASS  shifts=7  bools=10  bad_mul=0  bad_div=0  (pure shift+bool, no helpers)
    SMOKE: PASS off=0x5A3 len=2 got=0xAB2C (ran 400 frames, bsnes-jg)
        SHOT: PASS corpus=0xAB2C (snapshot at frame 400)
    RESULT: PASS — Rule 90/110 CA rendered on SNES; MAME + bsnes-jg screenshots + corpus hash 0xAB2C host == +mos-a16
    exit=0
    ```

    **PASS** — `0xAB2C` on host, bsnes-jg and MAME. Deleting an uncalled `static inline` emits no code,
    as predicted.

## Mockups

No visible surface: the proposed change (either option) alters no rendered output on any ROM.

## Verification

1. Enumerate every reference to both symbols outside `docs/` and frozen patches.

    ```
    $ git grep -n -e 'splash_show' -e 'splash16' -e 'splash\.h' -- . ':!docs/' ':!*.patch' \
        | grep -v '^examples/snes/snesgfx/splash.h'
    TODO.md:231:- [wip T3] **Finish the force-blank conversion: ...
    TODO.md:599:  / `display_hold()` in `display.h` + `snesgfx/splash.h` (BGMODE_1 BG3 splash for Mode-7 demos, self-clears VRAM).
    TODO.md:2132:     - fp:0bcb5b4ecf571ae0 (splash.h / splash16)  -> the [T2] finish-the-conversion item.
    dev/snes-display-quality-baseline.json:1443,1450,1457,1464,1471,1478,1485,1492,1499,1506,1513:  "path": "examples/snes/snesgfx/splash.h",
    dev/title-charset.sh:9,74:   (scanner regex alternative)
    examples/snes/snesgfx/title_layer.h:503,506:  (the definition + its comment)
    ```

    **PASS** — no `#include` of `splash.h`, no call to `splash_show(` or `splash16(` anywhere.

2. Confirm the twelve `m7blank` demos reach the title only through `m7splash_*`.

    ```
    $ grep -rn 'splash' --include=*.c examples/snes/ | grep -v m7splash | grep -v '^.*://'
    (only prose comments: buddha.c:139,140,145  blossom.c:185,188,194  julia.c:143,149
     mandel-float.c:181  mandel-double.c:218  mandel-display.c:117,136,143)
    ```

    **PASS** — every hit is a comment; no call site.

3. Rot check — compile `splash.h` explicitly (it is otherwise never type-checked).

    ```
    $ cat > /tmp/splashtu.c <<'EOF'
    #include "snesgfx/splash.h"
    int main(void){ splash_show("A","B",1); return 0; }
    EOF
    $ build/llvm-mos-install/bin/mos-clang --config build/install/bin/mos-snes.cfg \
        -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 -Os \
        -I examples/snes -c /tmp/splashtu.c -o /tmp/splashtu.o
    exit=0
    ```

    **PASS** — compiles clean, no diagnostics. Unused, not rotted.

4. Before/after force-blank measurement per affected demo (`dev/m7blank.sh --probe`).

    **NOT RUN — inapplicable.** The affected-demo set is empty (verification 1 + 2). Running the probe
    would measure the `m7splash` path, which this item does not touch.

5. Differential gate per affected demo.

    **NOT RUN — inapplicable.** No source file was modified, so no ROM changed and no hash can move.
