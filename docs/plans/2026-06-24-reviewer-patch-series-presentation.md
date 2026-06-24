# Reviewer-facing presentation of the 0001–0008 patch series

## Context

The #320/#321 work is a large patch stack (`patches/llvm-mos/0001`–`0008`, ~7 k diff lines) headed for
upstream submission. The bottleneck is no longer code — it is making the series **cheap for a maintainer to
review**. This task builds the presentation layer: a reviewer's map of the stack, an LLVM primer for readers
who know compiler construction but not LLVM, an upstream-PR accounting, and two small platform/source
refinements surfaced while writing it. Companion to [`agent-handoff.md`](../agent-handoff.md) and the
[ROADMAP](../ROADMAP.md); the exhaustive upstream queue stays
[`upstream-contribution-status.md`](../upstream-contribution-status.md).

## What was built

1. **[`docs/65816-patch-series-review-guide.md`](../65816-patch-series-review-guide.md)** — the reviewer's
   map: the one gating invariant (everything opt-in/gated, default 8-bit byte-identical), per-patch
   **need / patch / proof**, dependency + milestone-sequencing + pass-pipeline + gantt-timeline diagrams,
   and Appendices **A** testing setup · **B** SNES platform · **C** dead ends/spikes · **D** upstream bug-fix
   status. GitHub-linked: all 8 patches + 17 repo artifacts.
2. **[`docs/llvm-primer-for-65816-review.md`](../llvm-primer-for-65816-review.md)** — front-end → IR →
   backend → MC; LLVM IR + address spaces; TableGen; the GlobalISel pipeline (legalize/select/regbanks/
   combiner); MachineIR + RA (coalescer/scavenger/spills); calling conventions; MC layer; clang; DWARF; and a
   glossary of every LLVM term the guide drops. Cross-linked from the guide's Audience note.
3. **Appendix D + [`dev/upstream-status.sh`](../../dev/upstream-status.sh)** — a reviewer-facing table of the
   upstream bug-fix PRs that touch the stack (`0003`→PR #562, `0008`→#561/PR #563) + the deferred scavenger
   issue, with a one-command live refresh; the tracker stays the single source of truth (cross-linked both ways).
4. **Platform refinements** (surfaced while documenting the SNES target, both ROM-byte-neutral):
   - `platforms/snes/clang.cfg` defaults to **`-mcpu=mosw65816`** (the SNES CPU *is* a 65816 — the one-line
     change asiekierka flagged on sdk#415). `snes-far` inherits via `@mos-snes.cfg`.
   - `platforms/snes/crt0.c` `.init.50` preamble rewritten from hand-encoded **`.byte`** to plain **65816
     mnemonics**, built `-mcpu=mosw65816 -fno-lto` (module-level inline asm under `-flto` doesn't receive the
     `W65816` feature — the original reason for `.byte`).
5. **Renderer fix (separate repo, `python-tui-lib` `0134f1c`)** — `md-to-html.sh`'s inline-link regex now
   allows balanced brackets in link text, so `<sup>[[Cxx]](#a)</sup>` footnotes render as real links
   (CommonMark behavior); + 2 reproducer tests.

## Verification

1. **`-mcpu=mosw65816` platform default leaves the M0 baseline intact.**

   ```
   ==> corpus: 7/7 passed
   SMOKE: PASS addr=0x7E0020 len=1 got=0x42 (ran 60 ticks)
   ```
   PASS.

2. **crt0 mnemonics assemble byte-identically to the old `.byte` form.**

   ```
   === ROMs byte-identical vs the .byte version? ===
   YES — byte-identical (mnemonics == old .byte)
   ==> corpus: 7/7 passed
   ==> smoke PASS
   ```
   PASS (isolated assemble of the preamble also reproduces `ldx #$01ff` → `a2 ff 01`).

3. **`md-to-html` renderer fix — full suite green, footnotes now link.**

   ```
   2 passed, 71 deselected in 0.58s          # the 2 new footnote/bracket reproducers
   73 passed in 14.16s                       # full tests/test_md_to_html.py
   ```
   PASS.

4. **Review-guide structure is sound.**

   ```
   fences: 36 -> BALANCED
   markdown footnotes <sup>[[: 14   pure-HTML footnotes: 0
   github.com/wbniv links: 30
   Appendix D heading: 1   TOC links to Appendix D: 3   C19 footnote: 1
   ```
   PASS.

5. **Upstream accounting matches GitHub (live `gh`, 2026-06-24).**

   ```
   issue #561 OPEN
   PR #562 OPEN
   PR #563 OPEN
   #540 MERGED merged=2026-01-26T22:23:07Z
   revert-540 branches: 0    (fork now has only the 3 active PR/queue branches)
   ```
   PASS.

## Notes / out of scope

- The codegen itself is unchanged — this task is documentation + two ROM-byte-neutral platform refinements.
- GitHub links in the guide resolve only once `main` is pushed (origin was behind during authoring; merged +
  pushed at the close of this task).
- Posting the upstream artifacts remains **user-triggered** (the tracker holds the `gh` commands).
