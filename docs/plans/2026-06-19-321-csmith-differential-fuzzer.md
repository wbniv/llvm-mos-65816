# Replace the random fuzzer's *generator* with Csmith (keep the engine; builtin selectable)

**Date:** 2026-06-19 · **Status:** Phase 0 DONE — **GO** (see *Phase 0 — RESULT*); Phase 1 next.
**Issue:** #321, ROADMAP M2 (Test Bench / CI — strengthen the *random* correctness axis).
**Required reading:**
[Tier-1 fuzzer + engine](2026-06-15-321-tier1-broaden-corpus.md) ·
[corpus-a16 differential gate (the default-as-oracle precedent)](2026-06-19-321-corpus-a16-differential-mode.md) ·
[c-torture external suite (the shared external-program harness this reuses)](2026-06-19-321-c-torture-execute-differential-suite.md).

## Context — why

We have three home-grown correctness nets: the 6-program corpus, ~50 `a16*` micro-tests, and the random
differential fuzzer `tools/a16_fuzz.py`. All three test *the shapes we thought to write*. The c-torture suite
(Phase-0 landed, `8085d2a`) adds a large **externally-authored** body of real C. The remaining gap on the
*random* axis is that our generator is a hand-rolled AST walker over a fixed operator set — far weaker than the
field-standard generators. The user's ask: **replace our fuzzer with the best off-the-shelf one.**

Decision: **Csmith** as the primary random generator, **keep the builtin generator selectable**
(`--gen builtin`) with Csmith the `dev/run.sh fuzz` default. **Yarpgen is deferred to a follow-up TODO** — it's
sharper at the `-O1/-Os` optimization bugs we actually hit, but can't be aimed at this target without surgery
(see Follow-ups).

### Why Csmith over Yarpgen (for *this* target)
Three things gate viability on a freestanding, 16-bit-`int`, ~7.5 KB-RAM, no-stdout SNES; Csmith wins all:
1. **Overridable result hook.** Csmith reports via `platform_main_end(crc, flag)` — redefine it to write the
   checksum into `corpus_result`. Csmith *ships* an MSP430 platform header that does exactly this. Yarpgen
   bakes a literal `printf(hash)` into generated code — no hook → needs post-processing/patching.
2. **16-bit-`int` soundness (the correctness linchpin).** Csmith has a first-class target-width mechanism
   (`platform.info`: `integer size = 2` / `pointer size = 2`) and its `safe_math` guards are *type-parametric*
   (clamp against the passed-in `INT16_MIN/MAX`), so output is UB-free **at the target's actual 16-bit width**.
   Its shipped MSP430 model is byte-identical to ours — verified against the target compiler:
   `__SIZEOF_INT__=2`, `__SIZEOF_LONG__=4`, `__SIZEOF_POINTER__=2`, `__INT_MAX__=32767`. Yarpgen has no
   documented int-width config → would emit UB-at-16-bit programs → spurious failures that poison the gate.
3. **Size knobs.** Csmith's `--max-funcs/--max-array-*/--max-expr-complexity` + `--no-*` make programs that fit
   7.5 KB RAM. Yarpgen has none.

License (BSD-2 vs Apache-2.0) and seed-determinism are a wash.

## The correctness linchpin — read before doubting the oracle

An off-the-shelf generator has no Python oracle and the host (x86, 32-bit `int`) can never be the reference.
So the Csmith path uses **default-build-as-oracle**, which the engine already supports
(`evaluate(src, expected=None, …)` → `ref = got_default`, `tools/a16_fuzz.py:922`): the **default `+mos` build
on MAME is the trusted reference**; `+mos-a16` and `+mos-xy16` must produce the identical `corpus_result`
(+ the bsnes-jg leg on a16). This is sound **only because** all three builds share 16-bit `int` **and** Csmith
is configured (`platform.info` `integer size = 2`) with `safe_math` kept, so the program is UB-free at that
width. The oracle and the config are two halves of one correctness argument — **Phase 0 proves it before any
harness lands.**

We **keep the builtin generator** because it is the *only* net providing the independent 4-way
`host == default == a16 == xy16` oracle (its Python `expected()`), which catches a bug present in **both**
default and a16 — a dimension default-as-oracle structurally cannot. It also emits tiny, delta-reducible,
target-tuned programs (the kind that found F3 and the xy16 hang).

## What we reuse (do not reimplement)

| Reuse | From | How |
|---|---|---|
| `evaluate(src, expected=None, …)` | `tools/a16_fuzz.py:863` | verify-machineinstrs(a16+xy16) → compile default/a16/xy16 → run MAME(+bsnes) → assert agree. A Csmith `.c` is just another `src` with `expected=None`. |
| `compile_rom` / `run_mame` / `run_bsnes` / `map_lookup` | `tools/a16_fuzz.py:698/757/776/749` | toolchain + emulator orchestration. |
| `KNOWN_ISSUES` / `classify_known` / `triage` / `triage_file` | `tools/a16_fuzz.py:800/828/841/969` | XFAIL classification + failure artifacts. |
| `classify(stderr)` host-side link filter | `tools/torture_filter.py` (tracked, `8085d2a`) | bucket a generated program `region-overflow` / `compile-error` → SKIP+count (no silent drop). |
| `_shim.c` reporting convention | `examples/65816/torture/_shim.c` | model for the `corpus_result` + `for(;;){}` adapter. |
| fetch-pinned-tarball → build-into-gitignored-`vendor/` | `dev/xcheck.sh:38-52`, `dev/fetch-torture.sh` | idiom for `dev/fetch-csmith.sh`. |

## File layout (new files; one additive engine tweak)

- **`dev/fetch-csmith.sh`** *(new)* — clone Csmith at a pinned tag, sha256-verify, build from source
  (cmake + m4) into gitignored `vendor/csmith` (binary + `runtime/`). Mirrors `dev/xcheck.sh`'s build-if-missing.
  `set -euo pipefail`, `-h/--help`.
- **`examples/65816/csmith/csmith_snes.h`** *(new)* — freestanding adapter: `#define NO_PRINTF` + neutralize
  `printf/putchar`; `#include <stdint.h>` (SDK freestanding header already gives `int16_t=int`,
  `int32_t=long`); override `platform_main_begin(){}` and
  `platform_main_end(uint32_t crc,int){ corpus_result = (unsigned short)(crc ^ (crc>>16)); for(;;){} }`;
  declare `volatile unsigned short corpus_result;`. Modeled on Csmith's `platform_msp430.h`.
- **`examples/65816/csmith/platform.info`** *(new)* — exactly `integer size = 2` / `pointer size = 2`
  (the UB-correctness linchpin; Csmith reads it from CWD by name → the runner must `cd` here or copy it into
  the gen tempdir).
- **`tools/csmith_run.py`** *(new)* — `import a16_fuzz as E`; per seed: invoke `csmith -s SEED <profile>`,
  force-include the adapter, host-only pre-filter via `torture_filter.classify`, then `E.evaluate(src,
  expected=None, …)`. Loop + stats mirror `cmd_run` (`a16_fuzz.py:1008`). No toolchain/emulator code duplicated.
- **`dev/csmith.sh`** *(new, optional)* — thin `dev/run.sh csmith [N] [seed]` entry (build-if-missing csmith,
  bios check, then `csmith_run.py`); or fold entirely into `dev/fuzz.sh`.
- **`tools/a16_fuzz.py`** *(edit — additive)* — add optional `cflags=()` to `compile_rom`,
  `verify_machineinstrs`, and `evaluate` (thread to the three `compile_rom` calls + the verify call), so the
  Csmith runner can pass `-include …/csmith_snes.h -I vendor/csmith/runtime`. Default-empty → every existing
  caller (corpus-a16, kernels, builtin `run`) is byte-for-byte unchanged. *Fallback if we want zero shared-code
  churn:* have `csmith_run.py` emit a self-contained wrapper TU with absolute `#include`s — Phase 1 picks
  whichever the Csmith runtime supports cleanly.
- **`dev/fuzz.sh`** *(edit)* — make it the dispatcher: `dev/run.sh fuzz [--gen csmith|builtin] [N] [seed]`,
  **default `--gen csmith`**. `builtin` → `a16_fuzz.py run` (today's behavior, unchanged); `csmith` →
  build-if-missing `vendor/csmith` then `csmith_run.py`.

## Csmith invocation profile (tune in Phase 0)
`csmith -s SEED` (deterministic) with: `--max-funcs 3 --max-block-depth 3 --max-array-dim 1
--max-array-len-per-dim 4 --max-struct-fields 4 --max-expr-complexity 8 --max-pointer-depth 2 --no-bitfields
--no-unions --no-packed-struct --no-float --no-longlong --concise`. **Keep safe_math** (default; never pass
`--no-safe-math` — it is what makes output width-robust). Keep arrays/structs/pointers/volatiles (they drive
the addressing-mode + register-pressure coverage the a16/xy16 work targets).

## Worktree workflow (implementation isolation)

This work runs on a dedicated worktree, **not** `main`'s working copy — Phase 0 is a GO/NO-GO spike that may
end NO-GO, and `main` is a hot shared tree (concurrent c-torture/DWARF work moved HEAD repeatedly this
session). Setup (done 2026-06-19):

- **Branch `wt/321-csmith` off `main` (`f12a037`)** at `/home/will/SRC/llvm-mos-65816-csmith` — so it carries
  the just-committed c-torture infra (`tools/torture_filter.py`, `examples/65816/torture/_shim.c`) + the engine.
- **Reuse the prebuilt toolchain, don't rebuild.** `dev/run.sh` runs inside Docker mounting a *single* root at
  `/work`, so a worktree needs a self-contained `build/` (symlinks to the sibling main checkout dangle inside
  the container). Solution: **hardlink-copy** (`cp -al` — near-instant, ~zero extra disk, same filesystem) the
  read-only prebuilt bits from main into the worktree: `build/llvm-mos-install`, `build/install`,
  `build/jgxcheck`, `vendor/bsnes-jg`, `dev/roms` (the SPC700 IPL). Harness scratch (`build/fuzz-triage`, ROMs)
  is written fresh → new inodes, isolated from main. Csmith builds fresh into the worktree's gitignored
  `vendor/csmith`.
- **Run from the worktree:** `/home/will/SRC/llvm-mos-65816-csmith/dev/run.sh …` (its `dev/` carries the new
  scripts; the Docker image rebuilds from the worktree's `dev/`, cached). The plan doc itself lives on this
  branch too (moved off main's untracked working copy), so plan + code commit together.
- **Disposition:** GO → merge the durable artifacts (new files + the additive `a16_fuzz.py` tweak + this plan)
  back to `main`; NO-GO → `git worktree remove …-csmith` + `git branch -D wt/321-csmith` (disposable).

## Phases (each lands independently; Phases 0–3 are pure, additive harness — NO `vendor/llvm-mos`/`0002` change)

### Phase 0 — GO/NO-GO spike (gates everything)
1. `dev/fetch-csmith.sh` builds `vendor/csmith`. Create `csmith_snes.h` + `platform.info`.
2. **Spike A:** seeds 1..20 → generate (with `platform.info` present) → compile default/a16/xy16 with the
   adapter → for linkable ones run all three on MAME via `E.evaluate(…, expected=None)`.
   **PASS = 100% `default == a16 == xy16`** (after a determinism re-build of any mismatch). A reproducing
   mismatch is *either* a real a16/xy16 codegen bug (a win) *or* a UB false positive — Spike B disambiguates.
3. **Spike B (oracle-clean check):** measure the mismatch/anomaly rate over ~100 seeds; it must be **near
   zero**. Triage discriminators: determinism re-check; a16-vs-xy16 split (xy16-only divergence ≈ real bug);
   `-O0`-vs-`-Os` cross-check within one feature build. (`-fsanitize=undefined` on-target only *if* llvm-mos
   supports it here — likely not; do not depend on it.)
4. **Decision:** clean rate → GO. High UB rate → first confirm `platform.info` was actually parsed (CWD!),
   then tighten `--max-*`/`--no-*`; if it still leaks, Csmith's 16-bit path has a gap → NO-GO, fall back to the
   builtin generator for breadth and record why.

### Phase 0 — RESULT (2026-06-19): **GO**

Run on `wt/321-csmith`, host-side (MAME on host). Csmith **2.4.0** built via `dev/fetch-csmith.sh` (pinned
`0cdc710`, gitignored `vendor/csmith`); adapter `csmith_snes.h` + `platform.info` (`integer size = 2`) in
place. Spike `/tmp/csmith_spike.py` (throwaway; reuses `a16_fuzz`'s `run_mame`/`map_lookup`/`TOOL`/`CFG`
WITHOUT editing the engine) — generate `csmith -s N <profile>` → compile default/`+mos-a16`/`+mos-xy16` with
the adapter → MAME, compare.

**Sweep, seeds 1–100:**
```
spike: 83 agree, 0 mismatch, 17 skip/fail  (of 100 seeds)
```
- **0 value mismatches across 83 runnable seeds → the default-build-as-oracle differential is SOUND**
  (`platform.info` + type-parametric `safe_math` ⇒ UB-free at 16-bit `int`, no spurious failures). Spike A
  (100% agree) + Spike B (near-zero anomaly) **met decisively. → GO.**
- **9 skip/fail = a REAL new `+mos-a16` finding** (seeds 11/39/49/50/71/83/87/96/100): LTO/`ld.lld` fails with
  `LLVM ERROR: unable to legalize instruction: %a:_(s16),%b:_(s16) = G_UNMERGE_VALUES %c:_(s32) (in main)` —
  splitting a **32-bit `long`** into two s16 halves. The **default build succeeds** on the same program →
  `+mos-a16`-specific legalizer gap, *distinct* from the known `-O1/-Os` RA crashes. Surfaced because Csmith
  emits `long` (s32) that the hand-rolled 16/8-bit generator never did — the payoff, on run one. Repro:
  `cd examples/65816/csmith && ../../../vendor/csmith/bin/csmith -s 11 <profile> -o /tmp/s.c`, then compile
  `+mos-a16`. Disposition: Phase 4 — delta-reduce → `KNOWN_ISSUES` XFAIL (`a16-unmerge-s32`) or fix.
- **8 skip = harness wrinkles, not codegen** (seeds 9/16/30/33/48/58/88/99): `corpus_result` absent from the
  default map — Csmith `main` diverges before the final `platform_main_end`, so `--gc-sections` drops the
  unreferenced cell (no defined result → legitimately SKIP).

**Phase-1 fixes the spike exposed:** (1) `verify_machineinstrs` uses `--target=mos` (no `--config`) →
`csmith.h`'s `#include <math.h>` isn't found; the real runner verifies via `--config` (or skips verify — the
`--config` LTO compile already catches the s32 error as a `CompileError`). (2) classify `corpus_result`-absent
as SKIP. (3) the spike block-buffers stdout → `csmith_run.py` sets line-buffering.

### Phase 1 — runner + single-program reuse
`tools/csmith_run.py` (one seed end-to-end through `E.evaluate`), plus the `compile_rom` `cflags` tweak (or
wrapper-TU fallback). Prove one Csmith program passes the existing `a16_fuzz.py check`-style flow.

### Phase 2 — host-side fit filter + flag profile
Wire `torture_filter.classify` as a fast (no-emulator) pre-filter: oversize/compile-fail seeds are
SKIP+counted (logged, never silently dropped). Freeze the `--max-*`/`--no-*` profile from Phase 0 data.

### Phase 3 — `dev/run.sh fuzz` rewiring + pilot
Implement the `--gen csmith|builtin` dispatch in `dev/fuzz.sh` (default csmith). Pilot:
`dev/run.sh fuzz 30 1` (csmith) green; `dev/run.sh fuzz --gen builtin 50 1` still green.

### Phase 4 — scale + triage
Larger seed sweeps on a quiet box. Delta-reduce any real FAIL into a tracked `examples/65816/*.c` regression
(the F1–F4 precedent) **or** XFAIL via a `KNOWN_ISSUES` entry. **Only here may `vendor/llvm-mos`/`0002` change**
(a fix + its regression test).

### Phase 5 — optional sampled CI
Mirror the `corpus-a16` CI job in `smoke.yml`: a seeded subset per run, secret-gated, SKIP on missing BIOS.

## Verification (run on execution; paste raw output under each step)
1. **Csmith builds + is pinned.** `dev/fetch-csmith.sh` on a clean checkout → builds; second run is a no-op. _(paste)_
2. **Spike A.** seeds 1..20: linkable ones show `default == a16 == xy16` on MAME (+a16 on bsnes). _(paste)_
3. **Spike B.** ~100-seed anomaly rate near-zero; any mismatch triaged real-vs-UB. _(paste)_
4. **A real defect is caught.** Inject a wrong store into one program / a deliberately-broken build → runner reports **FAIL** (not SKIP/PASS). _(paste)_
5. **Oversize → SKIP.** A program that overflows LoRAM → `region-overflow` SKIP with reason, counted. _(paste)_
6. **Default flips to Csmith.** `dev/run.sh fuzz 30 1` runs Csmith; `dev/run.sh fuzz --gen builtin 50 1` runs the old generator. _(paste)_
7. **Non-breaking.** `dev/run.sh corpus` 7/7, `corpus-a16` 5/6+XFAIL, `dev/run.sh fuzz --gen builtin 50 1` green, c-torture path unaffected, `0002` round-trips (no `vendor/llvm-mos` change in Phases 0–3). _(paste)_

## Risks / honest scoping
- **UB under 16-bit int** — the central risk, *designed out* by `platform.info` + safe_math, *measured* by the
  Phase-0 spike. If the spike shows a high UB rate it's NO-GO for the cheap path (see Phase 0.4).
- **16-bit CRC fold** can collide distinct internal states → a real bug can be missed (false negative). Accept
  for a differential gate; a later phase could write the full 32-bit CRC to two `unsigned short` cells.
- **`platform.info` sets int/ptr width only**, not `long`/`long long` independently — fine here (target matches
  Csmith's 32/64 ladder); record as a constraint if a future target diverges.
- **Coverage is the *fitting* subset**, not all of Csmith's space — state counts, never imply full conformance.
- **Hot shared tree** — `tools/a16_fuzz.py` is concurrently evolved (c-torture). The only shared edit is the
  additive `cflags=()` kwarg; stage just our files, verify `git diff --cached --name-only`.

## Follow-ups
- **TODO (Yarpgen):** add a `TODO.md` item — *"vendor Yarpgen as a second random generator behind `--gen
  yarpgen` to target `-O1/-Os` loop/scalar optimization bugs"* — noting the two costs (redirect its baked-in
  `printf` to `corpus_result`; the 16-bit-int caveat, since it has no `platform.info` equivalent). The
  `--gen` seam added here makes this drop-in later.
- **Yarpgen vs the known bug families** — it directly targets the regalloc/loop optimization surface where our
  open XFAILs live (`regalloc-out-of-registers`, `scavenger-p-not-gpr`), so it's the natural next instrument.
- **On approval, also:** add the matching `TODO.md` entry under *Test Bench / CI* for this Csmith work itself.

## References
- Csmith int-width / UB facts: `src/CGOptions.cpp` (`set_platform_specific_options` parses `platform.info`;
  absent → host `sizeof(int)` trap), `runtime/stdint_msp430.h` + `runtime/platform_msp430.h` (16-bit-int
  precedent + no-stdio checksum write), `runtime/safe_math.m4` (type-parametric guards), `runtime/csmith.h`
  (`platform_main_*` hooks, `NO_PRINTF`) — <https://github.com/csmith-project/csmith>.
- Csmith paper: <https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf>.
- Yarpgen (OOPSLA'20): <https://users.cs.utah.edu/~regehr/yarpgen-oopsla20.pdf>.
