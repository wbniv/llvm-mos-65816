# PR #578 — compile-time cost of the fixed-point liveness recompute

**Status: DONE 2026‑09‑14** — measured; verdict "not measurable in practice" (+0.79 % instructions
corpus-wide, worst file +2.4 %, on-CPU time unchanged). See [§Results](#results--20260914).
No visible-surface change (compiler-internal timing measurement only).

## Why

The revised #578 fix (`docs/pr-revisions/2026-09-13/`, head `b4749221bf37`) inserts a
`fullyRecomputeLiveIns(Blocks)` call in `MOSCopyOpt::runOnMachineFunction` between copy
forwarding and dead-copy cleanup. That helper iterates to a fixed point, so its cost is
O(blocks × iterations-to-converge) per function rather than the single post-order pass it
replaces. The bundle's validation covers correctness (lit suite, red/green, bsnes runtime CRC)
but never quantified compile time. Codex flagged this as the remaining unquantified limitation
before publication. It is secondary to a demonstrated miscompile, but a maintainer could
reasonably ask, and a bounded measurement is cheap.

## Question

Does the fixed-point recompute add measurable compile time on realistic inputs, and if so, how
much and on which functions?

## Method

Compare two `llc` binaries that differ **only** in `MOSCopyOpt.cpp`'s 8-line hunk:

| Binary | Source |
|---|---|
| `llc-prefix` | `b4749221bf37` with `MOSCopyOpt.cpp` reverted to the submitted head `edc9bbd23b71` (the file the fix replaces; its `shouldCoalesce` guard removal is in a different file and does not affect this pass) |
| `llc-postfix` | `b4749221bf37` as-is |

Both built from the same `/tmp/llvm-mos-review-build` tree (Release, assertions on), so
everything except the one hunk is bit-identical.

**Inputs:** the 222 corpus IR files already generated for the #578 byte-identity sweep
(`examples/65816/*.c` and `examples/65816/torture/*.c`, two feature variants each, IR from the
fork's clang); 176 of them compile at `-O2` on the upstream-based `llc`, the other 46 hit
fork-only legalization and abort identically on both binaries and are excluded. Plus the three
largest inputs individually (`k_trig16x`, `k_trig16`, `a16cmpaudit`) as the loop-heavy stress
cases.

**Metric — primary: retired user-space instructions** (`perf stat -e instructions:u`). This
is the right metric for "does the algorithm do more work": it is deterministic to within a few
hundredths of a percent and **immune to machine load**, which matters because at measurement
time the host was running a separate investigation (the build-nondeterminism Phase 0 loaded
arm) at load average ~18 on 8 cores. Wall-clock and even CPU-time would be dominated by that
contention.

`perf` is not installed on the host and `kernel.perf_event_paranoid=4` blocks unprivileged
access, so the counter is read inside a `--privileged` `ubuntu:26.04` container
(`linux-tools-7.0.0-31-generic`, matching the host kernel), which holds `CAP_PERFMON` and
bypasses the sysctl. Verified working before the run (`/bin/true` → ~130k instructions:u).

**Metric — secondary: user CPU seconds** (`perf stat`'s `user` field), reported for scale but
not load-immune; interpret with the load caveat.

**Interleaving:** for each input, run `prefix` then `postfix` back to back, so both see the same
ambient conditions. Instruction counts don't need this, but it costs nothing and protects the
CPU-time secondary.

**Repetitions:** N=3 per input per binary for the full corpus (instruction counts are stable
enough that more is waste); N=10 per binary for the three large inputs.

**Report:** per-binary corpus-wide total instructions and the postfix/prefix ratio; per-file
ratio distribution (min, median, max, and the top-5 files by absolute delta); the three large
inputs individually with their N=10 min/median. A ratio within 1.00–1.01 corpus-wide with no
file above ~1.05 means "not measurable in practice"; anything larger gets its file named and
the function count/loop shape noted.

## Files

| File | Purpose |
|---|---|
| this plan | method + results |
| `dev/bench-578-liveness.sh` (throwaway, scratchpad) | the harness; promoted to `dev/` only if the result is surprising enough to warrant re-running later |
| `docs/pr-revisions/2026-09-13/validation.md` | one paragraph with the headline numbers, so the bundle's evidence is complete before publish |
| `docs/pr-revisions/2026-09-13/578-body.md` | one sentence on compile-time cost in the Validation line, if and only if the number is worth a maintainer's attention either way |

## Verification steps

1. `llc-prefix` fails `copy-opt-loop.mir` (both prefixes) and `llc-postfix` passes it — proves
   the two binaries are the intended pair.
2. Corpus run completes with the same 176-file compile set on both binaries (no asymmetric
   failures).
3. Instruction-count ratio and distribution recorded below.
4. Large-input N=10 results recorded below.
5. `validation.md` and (if warranted) `578-body.md` updated; bundle checksums regenerated.

## Results — 2026‑09‑14

**Verdict: not measurable in practice.** The fixed-point recompute adds **+0.79 % retired
instructions corpus-wide**, median **+0.17 %** per file, worst case **+2.4 %** on the two most
loop-dense kernels. On-CPU time is unchanged within noise (ratio 0.9989). No maintainer will see
this in a build.

Run: 176 corpus files × 2 binaries × 3 reps, plus 4 large inputs × 2 × 10, all under
`perf stat -e instructions:u,task-clock:u` in a `--privileged ubuntu:26.04` container, interleaved
A/B. Host load average ~18 throughout (the build-nondeterminism Phase 0 loaded arm was running),
which is why instruction counts are the headline and task-clock is secondary.

### Step 1 — binary pair identity: PASS

```
llc-prefix : copy-opt-loop.mir COPY prefix  -> FAILS  (bb.3 live-ins lack $a)
llc-postfix: copy-opt-loop.mir COPY prefix  -> passes
```

### Step 2 — same compile set on both binaries: PASS

```
176 files compiled on both; 46 failed on both (fork-only far-pointer legalization, plus the
pre-existing k_trig16x RA crash); asymmetric failures: 0
```

### Step 3 — corpus instruction counts

```
total instructions  prefix=6,547,285,927  postfix=6,599,034,714  ratio=1.00790  delta=+51,748,787
total task-clock ms prefix=3919           postfix=3915           ratio=0.9989   (load-sensitive)
per-file ratio: min=0.99511  median=1.00167  max=1.02383
files with ratio > 1.01: 15 of 176
instruction-count rep-to-rep spread: median 0.30 %, max 1.34 %   (metric noise floor)

top-5 by absolute delta:
  a16cmpaudit.a16   prefix=672,808,010  postfix=683,264,749  ratio=1.01554  +10,456,739
  a16cmpaudit.a8    prefix=673,217,645  postfix=682,948,784  ratio=1.01445   +9,731,139
  k_trig16.a8       prefix=300,049,161  postfix=307,200,158  ratio=1.02383   +7,150,997
  k_trig16.a16      prefix=300,100,933  postfix=307,219,939  ratio=1.02372   +7,119,006
  a16s32.a8         prefix= 91,801,179  postfix= 93,472,231  ratio=1.01820   +1,671,052
noise floor (most negative): mixedwidth-probe.a16 0.99654, far_tail.a8 0.99511, a16ret.a16 0.99594
```

The per-file noise floor is ~1.3 %, so individual ratios below that are not individually
meaningful; the corpus total and the top files are well above it and reproduce at N=10 below.

### Step 4 — large inputs, N=10 per side

```
a16cmpaudit.a16   prefix=673,343,410  postfix=683,141,107  ratio=1.01455  clk 177->179 ms
a16cmpaudit.a8    prefix=673,354,036  postfix=683,150,549  ratio=1.01455  clk 181->181 ms
k_trig16.a16      prefix=300,094,102  postfix=307,410,355  ratio=1.02438  clk  98->101 ms
k_trig16.a8       prefix=300,104,875  postfix=307,212,063  ratio=1.02368  clk  96-> 97 ms
```

`k_trig16x` (the single largest input) is excluded: it does not compile on either binary
(pre-existing upstream RA crash, unrelated). The worst measured case is therefore `k_trig16`, a
loop-dense trig kernel, at +2.4 % instructions and +2 ms on-CPU.

### Step 5 — recorded

`validation.md` gained the headline paragraph; `578-body.md`'s Validation line gained one
sentence. Bundle checksums regenerated. Harness kept in the session scratchpad
(`bench/bench-578-liveness.sh`, `bench/analyze.py`, `bench/results.csv`) — not promoted to
`dev/`, since the result needs no re-running.
