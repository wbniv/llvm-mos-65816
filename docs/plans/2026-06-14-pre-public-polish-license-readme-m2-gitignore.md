# Plan: Pre-public polish — LICENSE, README M2, .gitignore

## Context

The repo is about to go public. Three quick items need to land first:
1. A LICENSE file is required for a public LLVM-derivative fork.
2. The README Status section still says "M0 — in progress" dated 2026-06-14; the project is actually mid-M2 with +mos-a16 codegen working.
3. `docs/transcripts/` is untracked but not gitignored — accidental-commit risk.

## Changes

### 1. `LICENSE` — Apache-2.0

Create `/home/will/SRC/llvm-mos-65816/LICENSE` with the standard Apache-2.0 text (same license as llvm-mos upstream).

### 2. `NOTICE`

Create `/home/will/SRC/llvm-mos-65816/NOTICE` with:
```
llvm-mos-65816
Copyright 2026 Will Norris

This project includes patches derived from llvm-mos and LLVM.
llvm-mos is copyright its contributors; LLVM is copyright its contributors.
Both are licensed under the Apache License, Version 2.0 with LLVM Exceptions.
Original sources: https://github.com/llvm-mos/llvm-mos
```

### 3. README Status section rewrite

Replace the entire `## Status` section (lines 23–34) with an accurate M2 snapshot:

```markdown
## Status

**M0 — SNES test bench: complete.** Valid bootable LoROM `.sfc` from C, 7/7 corpus
tests green in CI, dual-emulator (MAME + bsnes-jg) differential.

**M1 — Far pointers: substantially complete.** 24-bit absolute-long load/store working
across banks; far calls (JSL/RTL) deferred pending upstream ABI blessing.

**M2 — 16-bit accumulator codegen: in progress.** `+mos-a16` enables the 65816's
native 16-bit accumulator mode. Implemented and differential-verified on both emulators:
full s16 ALU (add/sub/bitwise/shifts/cmp/inc/dec), constant-immediate folds,
indirect and absolute load/store, cross-block REP/SEP mode-tracking, A16-threading
(post-RA store/reload elimination), equality-as-value peephole. 40/40 corpus, 31
micro-tests, 6 realistic kernels, 2 combinatorial tests, 50/50 fuzz. CI green.
**In progress:** s32 (`long`/`int32_t`) support; XY16 (`+mos-xy16`).

See [docs/ROADMAP.md](docs/ROADMAP.md) for the full plan and
[docs/INVESTIGATION.md](docs/INVESTIGATION.md) for upstream status and contribution rationale.
```

### 4. `.gitignore` — add transcripts

Append to `.gitignore`:
```
# Internal session transcripts (never commit).
docs/transcripts/
```

## Commit

Stage `LICENSE`, `NOTICE`, `README.md`, `.gitignore` — all four files, nothing else.
Commit message: `repo: add Apache-2.0 LICENSE, NOTICE, refresh README to M2, gitignore transcripts`

## Verification

- `grep -c "Apache" LICENSE` → non-zero
- `head -3 NOTICE` → shows project name + copyright
- `grep "M2" README.md` → hits the new Status section
- `grep "transcripts" .gitignore` → present
- `git diff --cached --name-only` → exactly `LICENSE NOTICE README.md .gitignore`
