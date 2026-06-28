# 2026-06-28 — Re-verify the "LTO + `+mos-a16` bitmask-loop early-exit" diagnosis (#321 upstream item 11)

**Status:** ✅ RESOLVED (2026-06-28) — **draft issue is a MISDIAGNOSIS** (Outcome A). The `cmp #$10` is the
`q->n < UPQ_MAX_JOBS` queue-full exit, proven by a controlled `-D` override (constant tracked the macro
`0x10`→`0x14`). The row-skip claim is false. A *secondary* hypothesis (real 32-bit `== 0` miscompile under
LTO behind the original stall) remains OPEN — blocked on a runnable LTO build (see Results §Step 4).
**Supplements:** the standing project guide (`CLAUDE.md`) + `docs/agent-handoff.md` (build/disasm mechanics).
**Touches:** `docs/321-upstream-lto-a16-bitmask-loop-early-exit-issue.md` (the draft issue under test),
`docs/upstream-contribution-status.md` item 11, `TODO.md` Upstream section. **No `vendor/` / compiler change.**

## Why this plan exists

While resuming the "compiler bug a SNES demo manifested" diagnosis, a re-read of the source cast strong
doubt on the **root-cause hypothesis already written into the draft upstream issue** (`2c31f1c`). Before that
issue is posted (posting is user-triggered), the diagnosis must be verified or corrected. Posting a wrong
root cause against `llvm-mos` would burn maintainer trust — exactly what `CLAUDE.md` ("Every anomaly has a
concrete cause", "Don't guess — explain the gap", `PRs cite the breaking commit`) is there to prevent.

## The draft's claim (under test)

`docs/321-upstream-lto-a16-bitmask-loop-early-exit-issue.md` asserts an **LTO + `+mos-a16` miscompile**:
`_fact_emit`'s loop over `(uint32_t)1u << r` generates `cmp r,#16; bcc normal; jmp rts`, so the function
**exits at the first `r >= 16` iteration, skipping rows 16–27**. The disassembly annotation labels stack
slot `$2c` as "loop counter r" and reads the `cmp #$10` as a shift-amount split (r<16 native-16 fast path
vs r>=16 32-bit `__ashlsi3` path mis-lowered to a tail-jump to `rts`).

## The competing hypothesis (this plan's claim)

The `cmp #$10; bcc; jmp rts` is **correct codegen for the loop's second guard, `q->n < UPQ_MAX_JOBS`**, not a
shift-amount miscompile. Evidence (static, `examples/snes/`):

- The loop is `for (uint8_t r = 0; r < FACT_NROWS && q->n < UPQ_MAX_JOBS; r++)` (`factorial.c:79`).
- `FACT_NROWS = 28 = 0x1C`; `UPQ_MAX_JOBS = 16 = 0x10` (`snesgfx/upload.h:15`). The constant in `cmp #$10`
  is **16, matching `UPQ_MAX_JOBS`, not 28**. If the compared value were `r` (bounded by `FACT_NROWS`),
  the constant would be `0x1C`.
- Exiting the loop once the upload queue holds 16 jobs is the **documented per-vblank DMA budget**
  (`factorial.c:12`: "capped DMA (≤ UPQ_MAX_JOBS rows / V-blank)"). 28 rows flush over **2 frames**
  (0–15, then 16–27). So `$2c` is almost certainly **`q->n`**, and the `jmp rts` is the intended exit.
- **Corroborating tell:** the fix that actually stopped the stall (`3ab028e`) lives in `main()` — swapping
  the `dirty_rows == 0` sentinel for a delay counter. If `_fact_emit` genuinely never processed rows 16–27,
  that main-loop change could **not** have fixed it (those rows would still never DMA). That it worked is
  consistent with `_fact_emit` being correct, and the real stall being a **timing/logic bug** around the
  32-bit `dirty_rows == 0` gate being read mid-flush while the 28 rows drain across two frames.

## What we cannot yet conclude

This is static reasoning only — there is **no built toolchain** in this checkout. We have NOT re-disassembled
under LTO. Two open questions:
1. In the LTO `_fact_emit`, does `$2c` hold `q->n` or `r`?
2. Was the original `dirty_rows == 0` an actual 32-bit-zero-compare miscompile, or only a timing bug?

## Verification (the decisive experiment)

`UPQ_MAX_JOBS` is `#ifndef`-guarded, so it can be overridden at compile time with `-D` — **no edit to the hot
shared `main` working tree**. If `cmp #$10` tracks the macro, the compared value is `q->n`.

Driver/scripts (host-side, toolchain is an x86 Linux binary once built):
`/tmp/mos-verify-driver.sh` (waits for toolchain → `dev/run.sh build` → runs the experiment) and
`/tmp/verify-fact-emit.sh` (the two-variant disasm). Durable copies to be saved to `dev/` only if the verdict
warrants keeping the probe.

### Step 1 — Build the toolchain + SNES SDK

```
dev/run.sh toolchain            # full LLVM/clang build (no warm build/ exists)
MOS_TOOLCHAIN=$PWD/build/llvm-mos-install dev/run.sh build   # SNES SDK + mos-snes.cfg
```
Expected: `build/llvm-mos-install/bin/mos-clang` exists; `clang-23` mtime is fresh (stale-symlink gotcha).

> _paste raw output here; PASS/FAIL_

### Step 2 — Disassemble `_fact_emit` (default, UPQ_MAX_JOBS=16) under the LTO SNES config

```
build/llvm-mos-install/bin/mos-clang --config build/install/bin/mos-snes.cfg -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-a16 -Os -o /tmp/fact_a.sfc examples/snes/factorial.c
build/llvm-mos-install/bin/llvm-objdump -d --mcpu=mosw65816 /tmp/fact_a.sfc.elf \
  | awk '/<_fact_emit>:/{f=1} f{print} f&&/rts/{exit}'
```
Expected if this plan is right: a `cmp #$10` guard exists, AND a separate `cmp #$1c` (r < 28) is present, AND
the `(uint32_t)1u << r` body (byte-test / shift / `__ashlsi3`) is reached for the in-range path — i.e. no row
is structurally skipped.

> _paste raw output here; PASS/FAIL_

### Step 3 — Controlled override: rebuild with `-DUPQ_MAX_JOBS=20` (0x14) and re-disassemble

```
/tmp/verify-fact-emit.sh        # builds both variants, diffs the cmp constants
```
**Decision rule:**
- `cmp #$10` → `cmp #$14`  ⇒ constant == `UPQ_MAX_JOBS` ⇒ `$2c` is **`q->n`** ⇒ **draft hypothesis WRONG**
  (the `jmp rts` is the correct queue-full exit). Proceed to "Outcome A".
- `cmp #$10` unchanged ⇒ constant tied to the shift ⇒ draft hypothesis stands. Proceed to "Outcome B".

> _paste raw output here; PASS/FAIL_

### Step 4 — Resolve the *real* stall (only if Step 3 ⇒ draft WRONG)

Reconstruct the pre-`3ab028e` `main()` gate and confirm whether the stall was the `dirty_rows == 0` timing
bug (gate read mid-flush across the 2-frame drain) vs an actual 32-bit zero-compare miscompile. Build the
minimal isolation (host-oracle + on-console) needed to attribute it. Capture the true root cause.

> _paste raw output here; PASS/FAIL_

## Outcomes

**Outcome A — draft is wrong (expected).**
- Rewrite/retract `docs/321-upstream-lto-a16-bitmask-loop-early-exit-issue.md`: it is a **misdiagnosis**, not
  an upstream bug. Record the corrected analysis (correct `q->n` exit; real cause = the `dirty_rows`
  timing/logic gate).
- Demote item 11 in `docs/upstream-contribution-status.md` to "retracted — misdiagnosis" with the evidence,
  and update the `TODO.md` Upstream pointer. **Do not post the issue.**
- Keep the `3ab028e` workaround (the delay counter is still the right design), but correct its code comment
  if it cites a nonexistent compiler miscompile.
- If Step 4 finds a genuine residual compiler defect (e.g. the 32-bit zero-compare), spin a **fresh, correct**
  issue from that — with a real minimal reproducer, not the factorial demo.

**Outcome B — draft is right.**
- Keep the issue; strengthen it with the controlled-override evidence (constant did NOT track the macro) and a
  reduced standalone reproducer that miscompiles under `-flto` and is correct under `-fno-lto`.

## Verification status

- [x] Step 1 — toolchain built (SDK build crashed on the unrelated far-memops yak; worked around)
- [x] Step 2 — `_fact_emit` disassembled
- [x] Step 3 — controlled `UPQ_MAX_JOBS` override (the decisive bit) — **draft DISPROVEN**
- [ ] Step 4 — real stall root-cause **OPEN** (blocked on a runnable LTO build)

## Results (2026-06-28)

### Step 1 — toolchain built; SDK build blocked by an unrelated crash

`dev/run.sh toolchain` built clean (`mos-clang` = clang 23.0.0git `c798c3141`, `+mos-a16` accepted, `vendor/`
patches 0001–0014 present). `dev/run.sh build` (SNES SDK) then **crashed** — but on a *different* bug:

```
fatal error: error in backend: unable to legalize instruction:
  %12:_(p2) = G_PTR_ADD %7:_, %11:_(s16) (in function: __memset_far)
```

`__memset_far` is `platforms/snes/mem-far.c` (the #320 far-memset runtime). Its own header note says the far
`ptr[i]` is "a 32-bit G_PTR_ADD that only legalizes **under a16**" — so this is a build-config/legalization gap
in the **snes-far** platform, orthogonal to the factorial question. It killed the whole SDK build (no install,
no usable `mos-snes.cfg`). **Worked around** by compiling `factorial.c` to an object directly from the source
include dirs (no link / no LTO needed for the structural question). PASS (toolchain) / blocked (SDK install).

### Steps 2–3 — the decisive controlled experiment

Compiled `examples/snes/factorial.c` (`+mos-a16 -Os -c`) at `UPQ_MAX_JOBS` = 16 (default) and = 20 (`-D`
override; the macro is `#ifndef`-guarded so no file edit), disassembled `_fact_emit`:

```
VARIANT A (UPQ_MAX_JOBS=16=0x10):   cpy #$10      ← q->n < UPQ_MAX_JOBS guard
                                    cpy #$1c      ← r  < FACT_NROWS (28) guard
VARIANT B (UPQ_MAX_JOBS=20=0x14):   cpy #$14      ← TRACKED the macro (16→20)
                                    cpy #$1c      ← UNCHANGED (r bound is independent)
```

**Decision rule fired:** `cmp/cpy #$10` → `#$14` ⇒ the constant **is** `UPQ_MAX_JOBS` ⇒ the compared value is
**`q->n`**, not the shift counter `r`. The `jmp rts` the draft flagged is the **correct queue-full loop exit**
(per-vblank DMA budget: ≤16 jobs/frame; 28 rows flush over 2 frames). The real `r < 28` bound (`cpy #$1c`) is
present and untouched. **The draft's "shift-amount split skips rows 16–27" root cause is FALSE.** PASS.

(Note: in the standalone non-LTO compile `q->n` lives in `Y` (`cpy`); under the full LTO program it was spilled
to ZP slot `$2c` and read via `lda $2c; cmp #$10` — the disasm annotation that labeled `$2c` as "loop counter
r" was the original error. Same variable: `q->n`. The committed `factorial.c`/`upload.h` were verified
unchanged by the working-tree's cosmetic HUD-palette edits, so the experiment reflects the real demo.)

### Step 4 — the *actual* stall: OPEN

With `_fact_emit` proven correct, the original `dirty_rows == 0` gate **should** reach 0 in 2 frames and
advance every ~2 frames — so a permanent stall at n=1 implies the 32-bit `== 0` compare (or the `1u<<r`
clear) genuinely misfired under **LTO**, OR a frame-ordering subtlety. The standalone **non-LTO** codegen of
the drain+`==0` pattern is **correct** (`cpx #$1c` bound, `__ashlsi3`-style call for `1u<<r`, proper rep/sep
32-bit AND-NOT). The bug — if real — is LTO-only, and reproducing it needs a runnable/linkable LTO build,
which the far-memops SDK crash currently blocks. **Unverified; do not assert a compiler cause.** Options to
close it: (a) fix/skip the snes-far platform so `dev/run.sh build` completes → faithful LTO factorial build;
(b) build a standalone LTO harness (freestanding link) for the minimal reproducer.
