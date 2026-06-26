---
name: sweep-xfails-may-be-stale-build
description: "New XFAILs recorded by a full-suite sweep may be artifacts of a stale/dirty shared build/, not real defects — rebuild from committed patches before trusting them"
metadata: 
  node_type: memory
  type: project
  originSessionId: 33e53a91-504e-49e0-b170-089a9e0ec3b0
---

When a c-torture / csmith / corpus sweep records **new** XFAIL rows, do **not** assume the
defect is real. On this hot multi-agent `main` working copy the shared `build/llvm-mos-install`
is frequently **stale** (not rebuilt from the latest committed patches) or **transiently dirty**
(a concurrent worker's in-flight `vendor/` edits), so the sweep can measure a compiler that
doesn't match the tracked `patches/llvm-mos/*.patch`.

**Before trusting a freshly-recorded XFAIL: rebuild the toolchain from the committed patches
(`dev/run.sh toolchain`, then check `clang-23` mtime advanced — the stale-`clang-23` gotcha) and
re-run the row.** If it XPASSes on the clean build, the XFAIL is stale → de-XFAIL to a positive
gate, record the evidence, no compiler change.

Confirmed pattern (2× as of 2026-06-26):
- `pr15296` `a16-zp-pressure-overflow` — recorded XFAIL no longer reproduced; dropped to a gate.
- `ieee/fp-cmp-8`/`fp-cmp-8l`/`pr38016` `+mos-xy16` "cmove" — recorded by the ieee/ full-vendoring
  sweep (`5f3b316`, 12:02); did NOT reproduce on a clean build. Proof it was never a committed-stack
  defect: the patch stack was **byte-identical at the finding commit and HEAD**, so a clean build
  then == now == passes; the sweep had measured a stale/dirty `build/`. Resolved in `2c07c95`.

**Why:** the source of truth is the patches, never the shared `build/`. A sweep that skips the
rebuild can manufacture phantom XFAILs from another agent's mid-edit `vendor/`.
**How to apply:** treat a batch of new sweep XFAILs as *suspects*; rebuild-from-patches and
re-run each before writing it into `xfails.tsv`/`KNOWN_ISSUES` or opening a fix plan. Verify the
worktree compiler == committed stack (every `vendor/` edit maps to a committed patch; use
`dev/regen-patch.sh` + cross-check delta files). Relates to [[investigations-on-throwaway-branches]]
and [[close-net-negative-findings-not-defer]] (a non-reproducing finding is an answer, not backlog).
