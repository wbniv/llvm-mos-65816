# Finish the force-blank conversion: `snesgfx/splash.h` + `splash16` — NULL RESULT

**Date:** 2026-08-05
**Item:** TODO `[T3] Finish the force-blank conversion: snesgfx/splash.h + splash16 in title_layer.h`
**Predecessor:** [Mode 7 splash force-blank floor](2026-08-05-mode7-splash-forceblank-floor.md) (the settled contract)
**Status:** **BLOCKED on a keep-or-delete decision.** No code change proposed; no conversion is possible.

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
