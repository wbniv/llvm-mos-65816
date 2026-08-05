# Atomic command-line option rendering

**Date:** 2026-08-04  
**Status:** complete

## Rule

A command-line option token beginning with `-` or `--` is atomic. Renderers must never insert a
line break between its leading dash and parameter name, or anywhere else inside that option token.
If the surrounding line is too narrow, the complete token moves to the next line or overflows its
container; it is never fragmented.

## Scope

1. Reproduce the observed `-<br>motorola-integers=false` failure in the shared Markdown-to-HTML
   renderer.
2. Classify whitespace-free inline-code tokens matching `^-{1,2}\S+$` as command-line options.
3. Give that class an explicit non-breaking CSS contract that wins over table-cell and long-token
   wrapping rules: `white-space: nowrap`, `overflow-wrap: normal`, `word-break: normal`, and
   `hyphens: none`.
4. Add renderer regressions for single-dash, double-dash, assignment-valued, and table-contained
   options, plus a control proving ordinary long hashes/paths may still wrap.
5. Sweep the generated preview and documentation sources for option tokens that bypass inline-code
   markup or acquire break-enabling classes.
6. Re-render the `$` PR preview and verify its HTML contains one atomic option element with no
   inserted break opportunity.

## Completion record

- Shared renderer now assigns `class="cli"` when an inline-code span is an option or contains any
  whitespace-delimited option token. This covers both `-option=value` and complete command spans
  such as `llvm-mc -triple mos -show-encoding`.
- `code.cli` explicitly sets `white-space: nowrap`, `overflow-wrap: normal`, `word-break: normal`,
  and `hyphens: none`; CLI classification takes precedence over the long-token `.brk` class.
- Added regression coverage for single-dash, double-dash, assignment-valued, deliberately long,
  table-contained, and whole-command cases.
- Renderer suite: **128 passed, 1 deselected**. The deselected pre-existing
  `test_direct_gif_rejects_false_signature` failure concerns the script's unrelated aggregate exit
  status after rejecting a malformed GIF; the atomic-option tests and all other renderer tests pass.
- Source sweep found the `$` PR preview's option spellings inside inline-code spans. The regenerated
  HTML now emits `class="cli"` for every `-motorola-integers` occurrence and for the full
  `llvm-mc -triple mos` command span, with no CLI token receiving `class="brk"` or authored `<br>`.
