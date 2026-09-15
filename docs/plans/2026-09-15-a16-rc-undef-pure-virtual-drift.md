# `a16-rc-undef-ra-pure-virtual` — why its repros drifted, and the retire-vs-tighten call

**Date:** 2026‑09‑15 · **TODO:** the `[wip T4]` note under *Cluster G #118* in `TODO.md`
(`<!-- agent:a88d3cf98160f056b -->`) · **Related:**
[cause #1/#2 plan](2026-06-29-a16-rc-undef-ra-machineverifier-fix.md) ·
[#118 xy16 fix](2026-09-15-fix-xy16-spill-reload-clobbers-store-value.md) ·
[XPASS guard](2026-06-21-321-known-issues-xpass-guard.md)

## Verdict, up front

**Do NOT retire `a16-rc-undef-ra-pure-virtual`. The RA hazard is unchanged and live.**

The drift is **not** a compiler fix. It is a **source** change to one repro file plus a **stale
`KNOWN_ISSUE_REPROS` row** left behind when cause #1 was retired on 2026‑06‑30. The fix is to
re‑point the guard at repros that still fire, not to drop the entry.

## Visible surface

The only visible surface is `dev/run.sh known-issues` terminal output; before/after transcripts are
in §Verification. No UI, page, or document — mockup section dropped.

## 1. What was claimed to have drifted

The `#118` agent flagged, without investigating: `lsystem_sim.c -Os` and `newton_sim.c -Os` now
verify **clean**; only `newton_sim.c -O1` still reproduces.

Confirmed on a toolchain proven fresh (no `vendor/llvm-mos` source is newer than
`build/llvm-mos-install/bin/clang-23`; `MOSRegisterInfo.cpp` 12:06 < `clang-23` 12:20, and `faaabec`
was committed at 12:42 off that build — so the `#118` fix **is** in the binary under test):

| file | fn | a16 | xy16 |
|---|---|---|---|
| `lsystem_sim.c` | `main` | clean at ‑O0/‑O1/‑O2/‑O3/‑Os/‑Oz | clean at all |
| `newton_sim.c` | `newton_gate_crc` | **FAIL at ‑O1 only** | **FAIL at ‑O1 only** |
| `rcundef.c` | `newton_step` | clean at all | clean at all |

## 2. Diagnosis

### 2a. `newton_sim.c -Os` is not drift at all

It has verified clean at `-Os` **since 2026‑06‑30** — that is the *documented* outcome of the
cause‑#1 coalescer fix (`f1af264`). The `KNOWN_ISSUES` comment block already says so verbatim:
*"newton_sim.c now verifies CLEAN at ‑Os (the battery's level)"*. And `newton_gate_crc` at `-O1`
still reproduces cause #2 exactly as documented — so **nothing about newton changed today**.

### 2b. `lsystem_sim.c` drifted because the **source** changed, not the compiler

The decisive counterfactual: feed the **pre‑`903de3e` `lsystem_sim.c`** to **today's** compiler.

```
OLD-lsystem    a16   -O1  FAIL  fn=main  operand 1: killed renamable $rc11
OLD-lsystem    a16   -O2  FAIL  fn=main  operand 1: killed renamable $rc11
OLD-lsystem    a16   -O3  FAIL  fn=main  operand 1: killed renamable $rc11
OLD-lsystem    a16   -Os  FAIL  fn=main  operand 1: killed renamable $rc11
OLD-lsystem    xy16  -O1..-Os  FAIL (same, $rc11)
```

Identical to the 2026‑06‑29 record (`main`, `$rc11`, both features). The **only** difference
between the reproducing and non‑reproducing input is a two‑character source edit from
`903de3e` (2026‑08‑01, *"give every reachable idle loop a forward‑progress‑proof body (wai idiom)"*,
a 214‑file hygiene sweep):

```diff
 int main(void) {
     corpus_result = lsystem_gate_crc();
-    for (;;) {}
+    for (;;) __asm__ volatile("wai");
```

The `wai` inline‑asm body pins the infinite loop, which changes `main`'s inline/CFG shape enough
that the vulnerable live range is no longer formed there. Reduction confirms the mechanism is
about `lsystem_gate_crc`'s **body**, not about `main`:

| variant | result |
|---|---|
| `main` + bare `for(;;){}` | **FAIL** `main` `$rc11`, ‑O1/‑O2/‑O3/‑Os, both legs |
| `main` + plain `return 0;`, no loop | **FAIL** `main` `$rc11`, ‑O1/‑O2/‑O3/‑Os, both legs |
| `main` + `__builtin_unreachable()` | **FAIL** `lsystem_gate_crc` `$rc11`, both legs |
| `main` + `for(;;) __asm__ volatile("wai")` (shipping) | clean |
| `noreturn` wrapper + `wai` loop | clean |

**Conclusion: the underlying RA hazard is unchanged.** A 2026‑08‑01 idle‑loop hygiene commit
happened to reshape the one function the XFAIL named as its primary witness.

### 2c. Candidates ruled out

- **`faaabec` (#118 `PHA16`/`PLA16` bracket in `expandLDSTStk`) — NOT the cause.** The old
  lsystem source reproduces *with* `faaabec` in the compiler, and reproduces under `+mos-a16`,
  where the X16/Y16 soft‑stack spill path that fix touches never fires at all.
- **Any other backend commit since 2026‑06‑29 (incl. `3500adb` deterministic ZP allocation,
  `2bfe4f3` Imag32 atomic rename) — NOT the cause.** Same counterfactual: the current compiler
  still reproduces the old source. No compiler change relieved it.
- **Not the `a16-regalloc-pressure` pattern.** That one *was* a pressure artifact relieved by
  unrelated codegen advances (`pr15296.c`, promoted to a positive gate). This is the opposite: the
  compiler is unchanged in the relevant respect and the input moved.

### 2d. The real bug: the guard's own bookkeeping was stale, and CI never said so

`f1af264` removed `KNOWN_ISSUES["a16-newton-step-rc-undef"]` but **left its `KNOWN_ISSUE_REPROS`
row**, so the table names a kid that no longer exists, pointed at a file that verifies clean at the
one level (`-Os`) the guard hardcodes. The guard has therefore been **red since 2026‑06‑30** — and
its ACTION line tells you to drop an entry that is already gone:

```
ACTION: drop KNOWN_ISSUES['a16-newton-step-rc-undef'] (and its KNOWN_ISSUE_REPROS row) …
```

It went unnoticed because `smoke.yml` (which runs the step unconditionally) **last ran
2026‑06‑19** — eleven days before the row went stale:

```
completed  success  snes-smoke  main  workflow_dispatch  27823207476  2026-06-19T11:32:47Z
```

### 2e. Cause #2 is live in the shipping battery *today*

A sweep of all 117 corpus slices at `-Os` (the battery's level, `--config mos-snes.cfg`) finds one
current in‑tree witness:

```
trimerge_sim.c   xy16:RCUNDEF   — main:  renamable $x16 = LDXImag16 killed renamable $rs1  (×3)
```

All operands imaginary (`$rs1`, an Imag16 **pair**) → classifies as `a16-rc-undef-ra-pure-virtual`.
`+mos-a16` is clean; `+mos-xy16` fails at both `-O1` and `-Os`. Plus the many demo witnesses already
recorded in `TODO.md` (#33 mandel‑double, #69 gouraud, #71 msquares, #123 nmitally). The entry is
load‑bearing, not vestigial.

## 3. The change

Design chosen: **keep the entry; make the guard's repro set durable and level‑explicit.**

Rejected alternative: point the row back at `lsystem_sim.c` with the bare `for(;;){}` restored.
That would revert a deliberate correctness fix (`903de3e`) in a *runnable* corpus gate to satisfy a
*verify‑only* guard — and would break again the next time anyone touches that file.

1. **New hermetic repro `examples/65816/rcundef2.c`.** The reduced non‑loop form from §2b:
   `main` calls `lsystem_gate_crc()` and returns. It lives in `examples/65816/` (compiler
   micro‑tests) rather than `examples/snes/corpus/` (runnable demo slices), so no demo‑hygiene sweep
   owns it, and it contains **no idle loop at all** for a future `wai` sweep to reshape — the exact
   drift mechanism that broke the last one. Reproduces `a16-rc-undef-ra-pure-virtual` at
   `-O1/-O2/-O3/-Os` under **both** `+mos-a16` and `+mos-xy16`.
2. **`KNOWN_ISSUE_REPROS` rows carry an explicit opt level** (3‑tuple, `-Os` default preserved for
   `verify_machineinstrs`'s other callers), and the guard prints it. A guard pinned to one level is
   precisely what let a level‑sensitive drift hide; now the level it tested is in the output.
3. **Two rows, both verified to fail on both legs** (the both‑legs invariant from `b78a2d5` is
   preserved, not weakened):
   - `examples/65816/rcundef2.c` @ `-Os` — durable primary.
   - `examples/snes/corpus/newton_sim.c` @ `-O1` — second independent witness, different function
     (`newton_gate_crc`), still in tree.

   `trimerge_sim.c` is **not** a row: it fails under `+mos-xy16` only, and adding per‑leg rows would
   erode the both‑legs hardening. It is recorded in the comment block as the battery‑level witness.
4. **Stale prose corrected** in the `KNOWN_ISSUES` cause‑#2 comment, `dev/rcundef.sh`'s cause‑#2
   note (claimed lsystem fails "all levels"), and `dev/run.sh`'s help text (claimed the table is
   "Currently VACUOUS — KNOWN_ISSUE_REPROS is empty").

The `#118` `DISCRIMINATOR` block and `_is_rc_undef_pure_virtual` are **untouched**.

`lsystem_sim.c` is deliberately **not** promoted to a positive `-verify` gate: its cleanliness is an
incidental property of an unrelated hygiene edit, not a guarantee the compiler owes. Encoding it as
a contract would turn a future harmless reshape into a false regression.

5. **Upstream artifact corrected in the same commit** (per `CLAUDE.md`). The
   `rc-undef-ra-pure-virtual` **issue is READY TO POST and user-triggered**, and its Reproduction
   section named `lsystem_sim.c` — which verifies clean today. Posting it unchanged would have
   handed upstream a repro that does not reproduce. Re-surveyed and rewritten as a witness table
   led by `examples/snes/seqvm.c` `draw_frame`, the issue's own "second manifestation", which
   **still reproduces exactly as documented** (2 errors, `$rc3` + `$rc5`, `-O1`/`-O2`/`-Os`, both
   features, clean at `-Oz` under `+mos-a16`), plus an explicit note explaining the lsystem
   withdrawal so a reader does not mistake it for evidence of a fix.
   `docs/upstream-contribution-status.md` row 13 updated to match. **Nothing was posted.**

   `seqvm.c` is *not* added as a `KNOWN_ISSUE_REPROS` row despite failing on both legs at `-Os`: it
   `#include`s SDK headers and so needs `--config mos-snes.cfg`, which would cost the guard its
   "toolchain-only, no SDK/emulator/secret" property — it runs in CI *before* `dev/run.sh build`.

## 4. Verification

**0. Toolchain freshness** (the documented stale-`clang-23` gotcha).

```
$ find vendor/llvm-mos -newer build/llvm-mos-install/bin/clang-23 \( -name '*.cpp' -o -name '*.h' -o -name '*.td' \)
(empty)
$ ls -la --time-style=full-iso build/llvm-mos-install/bin/clang-23
-rwxr-xr-x 1 will will 124812368 2026-09-15 12:20:57 build/llvm-mos-install/bin/clang-23
$ ls -la --time-style=full-iso vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp
-rw-r--r-- 1 will will     59880 2026-09-15 12:06:18 …/MOSRegisterInfo.cpp
$ git log -1 --format='%h %cI' faaabec
faaabec 2026-09-15T12:42:40+07:00
```

**PASS** — no vendor source is newer than the binary; the `#118` fix is in the compiler under test.

**1. `dev/run.sh known-issues` — before.**

```
==> known-issues XPASS guard: each KNOWN_ISSUES repro must still crash verify (+mos-a16 AND +mos-xy16)
  examples/snes/corpus/newton_sim.c +mos-a16   XPASS — verifies CLEAN (issue [a16-newton-step-rc-undef] no longer reproduces)
  examples/snes/corpus/newton_sim.c +mos-xy16  XPASS — verifies CLEAN (issue [a16-newton-step-rc-undef] no longer reproduces)

XPASS: 2 known-issue repro/leg(s) NO LONGER REPRODUCE — the deferred bug looks FIXED:
  - examples/snes/corpus/newton_sim.c verifies clean under +mos-a16
  - examples/snes/corpus/newton_sim.c verifies clean under +mos-xy16
ACTION: drop KNOWN_ISSUES['a16-newton-step-rc-undef'] (and its KNOWN_ISSUE_REPROS row) in tools/a16_fuzz.py,
        then promote the repro to a POSITIVE gate (host==default==+mos-a16==+mos-xy16).
RESULT: FAIL — known-issue guard tripped (see ACTION/DRIFT above)
```

**RED, as reported** — and the ACTION names an entry that has not existed since `f1af264`.

**2. Repro matrix, today's compiler, today's sources.**

```
lsystem_sim.c  a16  -O0/-O1/-O2/-O3/-Os/-Oz   CLEAN
lsystem_sim.c  xy16 -O0/-O1/-O2/-O3/-Os/-Oz   CLEAN
newton_sim.c   a16  -O1   FAIL  fn=newton_gate_crc  $rc5, $rc2, $rc4
newton_sim.c   a16  -O0/-O2/-O3/-Os/-Oz        CLEAN
newton_sim.c   xy16 -O1   FAIL  fn=newton_gate_crc  $rc5, $rc2, $rc4
newton_sim.c   xy16 -O0/-O2/-O3/-Os/-Oz        CLEAN
rcundef.c      a16  all                        CLEAN
rcundef.c      xy16 all                        CLEAN
```

**PASS (drift confirmed as reported).**

**3. Counterfactual — pre-`903de3e` sources, today's compiler.** The decisive step.

```
OLD-lsystem    a16   -O0  CLEAN
OLD-lsystem    a16   -O1  FAIL fn=main ops=killed renamable $rc11
OLD-lsystem    a16   -O2  FAIL fn=main ops=killed renamable $rc11
OLD-lsystem    a16   -O3  FAIL fn=main ops=killed renamable $rc11
OLD-lsystem    a16   -Os  FAIL fn=main ops=killed renamable $rc11
OLD-lsystem    xy16  -O0  CLEAN
OLD-lsystem    xy16  -O1  FAIL fn=main ops=killed renamable $rc11
OLD-lsystem    xy16  -O2  FAIL fn=main ops=killed renamable $rc11
OLD-lsystem    xy16  -O3  FAIL fn=main ops=killed renamable $rc11
OLD-lsystem    xy16  -Os  FAIL fn=main ops=killed renamable $rc11
OLD-newton     a16   -O1  FAIL fn=newton_gate_crc ops=$rc5,$rc2,$rc4
OLD-newton     a16   -O0/-O2/-O3/-Os  CLEAN
OLD-newton     xy16  -O1  FAIL fn=newton_gate_crc ops=$rc5,$rc2,$rc4
OLD-newton     xy16  -O0/-O2/-O3/-Os  CLEAN
```

**PASS — the hazard is UNCHANGED.** Only the source moved. (`newton_sim.c` is identical
old-vs-new in behaviour, confirming its `-Os` cleanliness predates today and is the cause-#1 fix.)

**3b. Live battery witness** — all 117 corpus slices, `-Os`, `--config mos-snes.cfg`:

```
  trimerge_sim.c                     xy16:RCUNDEF
scanned 117 corpus slices; 1 with verify failures at -Os

*** Bad machine code: Using an undefined physical register ***
- function:    main
- instruction: renamable $x16 = LDXImag16 killed renamable $rs1
- operand 1:   killed renamable $rs1          (×3)

  trimerge a16   -O1  CLEAN      trimerge xy16  -O1  FAIL
  trimerge a16   -Os  CLEAN      trimerge xy16  -Os  FAIL
```

**PASS — cause #2 is live at the battery's own level today.**

**3c. The upstream issue's own lead repro, `seqvm.c` `draw_frame`** — unchanged since 2026‑08‑02:

```
  seqvm a16   -O1  FAIL n=2 fn=draw_frame ops=killed renamable $rc3, killed renamable $rc5
  seqvm a16   -O2  FAIL n=2 fn=draw_frame ops=killed renamable $rc3, killed renamable $rc5
  seqvm a16   -Os  FAIL n=2 fn=draw_frame ops=killed renamable $rc3, killed renamable $rc5
  seqvm a16   -Oz  CLEAN
  seqvm xy16  -O1  FAIL n=2 fn=draw_frame ops=killed renamable $rc3, killed renamable $rc5
  seqvm xy16  -O2  FAIL n=2 fn=draw_frame ops=killed renamable $rc3, killed renamable $rc5
  seqvm xy16  -Os  FAIL n=2 fn=draw_frame ops=killed renamable $rc3, killed renamable $rc5
  seqvm xy16  -Oz  FAIL n=2 fn=draw_frame ops=renamable $rc2
```

**PASS** — matches the issue body's recorded "2 errors `$rc3` bb.2 / `$rc5` bb.5 at `-Os`, clean
`-Oz`" verbatim. Independent confirmation that nothing about cause #2 has changed.

**4. `rcundef2.c` matrix + classifier kid.**

```
  V2 a16   -O0  CLEAN
  V2 a16   -O1  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 a16   -O2  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 a16   -O3  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 a16   -Os  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 a16   -Oz  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 xy16  -O0  CLEAN
  V2 xy16  -O1  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 xy16  -O2  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 xy16  -O3  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 xy16  -Os  FAIL classify=a16-rc-undef-ra-pure-virtual
  V2 xy16  -Oz  CLEAN
```

**PASS** — fires on both legs at the guard's `-Os` row and classifies as the right kid.

**5. `dev/run.sh known-issues` — after.**

```
==> known-issues XPASS guard: each KNOWN_ISSUES repro must still crash verify (+mos-a16 AND +mos-xy16, at the row's own -O level)
  examples/65816/rcundef2.c      -Os  +mos-a16   xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)
  examples/65816/rcundef2.c      -Os  +mos-xy16  xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)
  examples/snes/corpus/newton_sim.c -O1  +mos-a16   xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)
  examples/snes/corpus/newton_sim.c -O1  +mos-xy16  xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)

RESULT: PASS — 4/4 known-issue legs still reproduce (XFAIL regression guard intact)
```

**PASS.**

**6. Negative tests — the guard must still trip loudly.** Four injected failure modes, run against
the real `cmd_known_issues`:

```
### NEG-1: a row whose repro verifies CLEAN (simulated fix) ###
  examples/65816/rcundef.c       -Os  +mos-a16   XPASS — verifies CLEAN (issue [a16-rc-undef-ra-pure-virtual] no longer reproduces)
  examples/65816/rcundef.c       -Os  +mos-xy16  XPASS — verifies CLEAN (issue [a16-rc-undef-ra-pure-virtual] no longer reproduces)
ACTION for [a16-rc-undef-ra-pure-virtual] — prove WHICH of these two it is before touching anything:
        (a) the defect is genuinely FIXED -> drop KNOWN_ISSUES[...] and its rows, promote to a POSITIVE gate.
        (b) the REPRO drifted while the defect is untouched -> KEEP the entry and re-point the row.
            The test: feed the PREVIOUS revision of the repro source to TODAY's compiler.
RESULT: FAIL — known-issue guard tripped        exit=1

### NEG-2: a row naming a RETIRED kid (the 2026-06-30 bookkeeping bug) ###
  examples/snes/corpus/newton_sim.c -O1        DRIFT — kid [a16-newton-step-rc-undef] is not in KNOWN_ISSUES (retired entry left a stale row)
RESULT: FAIL — known-issue guard tripped        exit=1

### NEG-3: level drift — the right repro at the WRONG level ###
  examples/snes/corpus/newton_sim.c -Os  +mos-a16   XPASS — verifies CLEAN …
RESULT: FAIL — known-issue guard tripped        exit=1

### NEG-4: missing source ###
  examples/65816/nope.c          -Os        MISSING SOURCE (…/examples/65816/nope.c)
RESULT: FAIL — known-issue guard tripped        exit=1
```

**PASS 4/4** — including NEG‑2, the exact bookkeeping bug that went unnoticed for 2.5 months and is
now caught as DRIFT rather than degenerating into an impossible ACTION.

**7. `dev/run.sh rcundef`** — cause-#1 positive gate.

```
    rcundef.c a16 -O0  -verify clean
    rcundef.c a16 -O1  -verify clean
    rcundef.c a16 -Os  -verify clean
    rcundef.c xy16 -O0  -verify clean
    rcundef.c xy16 -O1  -verify clean
    rcundef.c xy16 -Os  -verify clean
    newton_sim.c a16 -O0  -verify clean
    newton_sim.c a16 -Os  -verify clean
    newton_sim.c xy16 -O0  -verify clean
    newton_sim.c xy16 -Os  -verify clean

RESULT: PASS — rcundef (a16+xy16, all -O) + newton (-Os) -verify clean; coalescer rc-undef (cause #1) fixed
```

**PASS.**

**8. `dev/run.sh build`** — 261 expected.

```
==> built 261 program(s)
==> not programs, excluded by contract (3): snes-video-codec snes-video-dma snes-video-stream
```

**PASS — 261, baseline held.**

**9. `dev/run.sh corpus`** — 66/66 expected.

```
==> corpus: 66/66 passed
rc=0
```

**PASS.**

**10. `dev/run.sh corpus-a16`** — 65/65 expected.

```
  huffman_sim  PASS   corpus_result=0xE8E4
  perlin_sim   PASS   corpus_result=0xA72D
  gouraud_sim  PASS   corpus_result=0xC5E9   (trips the a16/xy16 -verify rc-undef XFAIL; code bit-exact correct)
  dither_sim   PASS   corpus_result=0x80C4
  msquares_sim PASS   corpus_result=0x86A7   (trips the a16/xy16 -verify rc-undef XFAIL; code correct)
  grid3d_sim   PASS   corpus_result=0xFCDE
  setjmp_sim   PASS   corpus_result=0x2007
  nmitally_sim PASS   corpus_result=0xBCE6
  backtrack_sim PASS  corpus_result=0x7336
  csrjmp_sim   PASS   corpus_result=0xADD8
  retryjmp_sim PASS   corpus_result=0x3388
==> corpus-a16: 65/65 passed, 0 xfail
rc=0
```

**PASS — 65/65, baseline held.** (Note `gouraud_sim`/`msquares_sim` still annotate the rc-undef
XFAIL while passing the 4-way differential — the entry doing exactly the job it is kept for.)

**11. `dev/run.sh known-issues` — final, after the full sweep.**

```
==> known-issues XPASS guard: each KNOWN_ISSUES repro must still crash verify (+mos-a16 AND +mos-xy16, at the row's own -O level)
  examples/65816/rcundef2.c      -Os  +mos-a16   xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)
  examples/65816/rcundef2.c      -Os  +mos-xy16  xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)
  examples/snes/corpus/newton_sim.c -O1  +mos-a16   xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)
  examples/snes/corpus/newton_sim.c -O1  +mos-xy16  xfail [a16-rc-undef-ra-pure-virtual] (still reproduces)

RESULT: PASS — 4/4 known-issue legs still reproduce (XFAIL regression guard intact)
```

**PASS.**

## 5. Residual risk

- **The repro is still a C file, so it can still drift.** `rcundef2.c` is minimal and loop-free and
  lives in the compiler test-suite dir, but it `#include`s `examples/65816/lsystem.h`, which is
  shared with the live demo and is actively maintained. If that header changes, the repro may stop
  firing. That now fails **loudly** as an XPASS with a printed "prove which of (a)/(b)" procedure
  rather than reading as an all-clear — which is the property that was missing. A genuinely
  drift-proof guard would be a checked-in pre-RA `.mir` + `llc -run-pass=greedy` lit test; that is
  strictly better and is the obvious follow-up, but it needs the `llc`-staleness workaround from
  `docs/agent-handoff.md` and is a larger change than this fix warranted.
- **`-Oz` asymmetry is unexplained.** `rcundef2.c` fails at `-Oz` under `+mos-a16` but is clean
  under `+mos-xy16`; `seqvm.c` is the reverse. Not investigated — the guard rows use `-Os`/`-O1`
  where both legs agree, so nothing depends on it.
- **The count "2.5 months red" rests on `gh run list` for `smoke.yml`**, which shows no run after
  2026‑06‑19. If the step ran under a different workflow I did not find, the window is shorter. The
  substantive claim — that the row named a retired kid — is independent of that.
