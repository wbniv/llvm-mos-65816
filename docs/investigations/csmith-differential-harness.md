# Csmith differential fuzzer — what it is, where it lives, how it runs on MAME, what's still open

**What:** the repo already has a complete **Csmith** random-program differential-testing harness wired onto
the MAME (+ bsnes-jg) emulator bench. It generates UB-free random C, compiles each program three ways
(`default` / `+mos-a16` / `+mos-xy16`), runs them on-console, and asserts they all agree — turning random C
into a backend-codegen bug finder.

**Why this note exists:** the facts are scattered across `dev/csmith.sh`, `tools/csmith_run.py`,
`tools/a16_fuzz.py`, the adapter under `examples/65816/csmith/`, the CI yaml, the
[execution plan](../plans/2026-06-19-321-csmith-differential-fuzzer.md), and a `TODO.md` item — so the
next person asking *"should we add Csmith differential testing?"* (or being tempted to build it) has one
place that says **it's already done**, shows how it works end-to-end, and lists the genuinely-open
follow-ups. It also records the strategic questions that motivated it.

> **TL;DR — it already exists.** Built on `wt/321-csmith`, merged
> [`dd5616b`](https://github.com/wbniv/llvm-mos-65816/commit/dd5616b) (2026-06-19, Phases 0–4); CI wired
> [`e865dff`](https://github.com/wbniv/llvm-mos-65816/commit/e865dff) (2026-06-21, Phase 5). Run it with
> **`dev/run.sh fuzz [--gen csmith|builtin] [N] [seed]`** — Csmith is the **default** generator. Do **not**
> re-implement it.

---

## 0. Origin — the two questions that motivated this

This harness is the concrete answer to two strategic questions about the project (a from-source llvm-mos
fork adding native 16-bit-accumulator 65816 codegen). They're recorded here because the *second* one is
exactly what Csmith delivers.

### Q1. Why write a C compiler at all, when [WDC816CC](https://wdc65xx.com/65xxtools-2/wdc816cc-with-optimizer/) is free and "ANSI-C99-validated (Plum Hall)"?

Because "free" there means *gratis*, not *libre*, and none of what makes WDC816CC free meets this project's
goals:

- **It's license-restricted to WDC silicon — which the SNES isn't.** WDC's terms restrict the tools to
  "ONLY … WDC 65xx technology." The SNES CPU is a **Ricoh 5A22** (a 65816 core fabbed by Ricoh, not a WDC
  part), as are the Apple IIGS, SA-1, etc. — so for this project's actual target it's arguably off-limits by
  its own license.
- **It's a closed binary — you can't do the one thing this project *is*.** The whole thesis here (see the
  [three governing lessons](../../CLAUDE.md)) is *measuring bytes and shaving them* — building the real
  codegen shape, diffing the disasm, gating native 16-bit ops to fire only where they win. You cannot do
  that to a compiler whose source you don't have. WDC816CC has a peephole "optimizer"; it has no SSA
  pipeline, no LLVM-grade register allocation, none of llvm-mos's whole-program / static-stack model — and
  even if it did, the `+mos-a16` feature is *our* code.
- **Language + ecosystem.** WDC816CC is a C99-ish dialect with its own memory models, calling convention,
  object format, and assembler. llvm-mos hands you modern **Clang**: C17/C++, real diagnostics,
  `clangd`/`clang-tidy`/`clang-format`, LTO, a maintained upstream. A frozen freeware binary (its docs are
  dated 2013) gives none of that.

WDC816CC is a legitimate, purpose-built tool — it's just a fundamentally different artifact (a vendor-locked
binary) from an open, extensible, optimizing toolchain. (We're not the first to want the latter:
[a prior llvm-65816 attempt](https://github.com/jeremysrand/llvm-65816) exists.)

### Q2. How do we get "Plum Hall–validated" (or similar)?

"Validated (Plum Hall)" means "we licensed Plum Hall's commercial
[C Validation Suite](https://plumhall.com/newsite/stec1.html) (C‑VS) and it passes." It's a proprietary
conformance suite — **now owned by [Solid Sands](https://plumhall.com/newsite/suites.html)** (who also make
SuperTest) — priced by quote, not a government badge. To *literally* replicate WDC's line you'd buy C‑VS and
run it.

But the key realization: **Plum Hall tests the C *front end* — and ours is upstream Clang**, already among
the most conformance-tested front ends in existence. We inherit that. The novel, *unproven* surface in this
project is the **65816 *backend* / codegen**, which a language-conformance suite barely touches. So the
validation that's actually worth something here is **execution-based differential testing on-target** — which
is exactly the project's standing bar (`host == default@MAME == +mos-a16@MAME == +mos-a16@bsnes-jg`). Scaled
up with free, open, *reproducible* suites, that's a stronger story for an open compiler than a one-line
proprietary badge (anyone can re-run it):

- **[Csmith](https://github.com/csmith-project/csmith)** — random UB-free C + differential testing; the gold
  standard for **wrong-code / backend** bugs (found 325+ in GCC & Clang). **← this is the subject of this
  document, and it is already built.**
- **GCC `c-torture/execute`**, **llvm-test-suite** (SingleSource), **[c-testsuite](https://github.com/c-testsuite/c-testsuite)** — execution suites we already run or can wire to the same bench (c-torture is live: `dev/run.sh torture`).

If a *formal certificate* is ever required (safety/marketing/customer mandate), the commercial routes are
Plum Hall C‑VS, Solid Sands SuperTest, or Perennial CVSA — but that's a **procurement** decision, and it
mostly re-validates the Clang front end we already inherit. The engineering answer is the open differential
bench below.

---

## 1. The differential it implements

For each generated program the harness runs a **4-way** oracle and requires all legs to produce the identical
16-bit result:

| Leg | Build flags | Emulator | Role |
|---|---|---|---|
| `default@MAME` | none (`-mcpu=mosw65816`) | MAME | **the oracle** |
| `+mos-a16@MAME` | `+mos-a16` | MAME | must match the oracle |
| `+mos-xy16@MAME` | `+mos-xy16` (implies `+mos-a16`) | MAME | independent X-flag lattice |
| `+mos-a16@bsnes-jg` | `+mos-a16` | bsnes-jg | cross-emulator fidelity (skipped if `build/jgxcheck` absent) |

The trusted reference is the **DEFAULT build**, not a host-computed value. In `tools/a16_fuzz.py`
(`evaluate`), Csmith passes `expected=None`, so:

```python
ref = expected if expected is not None else got_default     # tools/a16_fuzz.py (~L1153)
```

**Why default-as-oracle is sound** (this is the linchpin — see plan §"GO/NO-GO"): Csmith normally assumes
host integer widths, but `examples/65816/csmith/platform.info` pins:

```
integer size = 2
pointer size = 2
```

which **matches the target's 16-bit `int`** (`__SIZEOF_INT__ == 2`). Combined with Csmith's kept
`safe_math` wrappers (the harness deliberately never passes `--no-safe-math`), the generated program is
**UB-free at the target's actual width**. So `default` and `+mos-a16` share the same language semantics, and
any divergence between them is a **real 16-bit-accumulator codegen defect**, not spurious UB. This sidesteps
the host-int-width problem that would otherwise sink a cross-compiler Csmith setup.

---

## 2. End-to-end data flow

| Step | Where | What happens |
|---|---|---|
| **Fetch / build** | `dev/fetch-csmith.sh` | Clone + CMake-Release build into gitignored `vendor/csmith` (`bin/csmith`); resolved commit recorded in `vendor/csmith/PINNED_SHA`. Phase 0 pinned **Csmith 2.4.0** (`0cdc710`). Host-side (needs `g++`/`cmake`/`m4`); no-op once built. |
| **Generate** | `tools/csmith_run.py` (`generate`) | `csmith -s SEED <profile> -o out`, run with **`cwd=examples/65816/csmith/`** so Csmith reads `platform.info`. |
| **Adapt** | `examples/65816/csmith/csmith_snes.h` (force-included) | Pre-defines `PLATFORM_GENERIC_H` to suppress Csmith's printf reporter, `#define`s `printf`/`fprintf` to no-ops, and overrides `platform_main_end(crc, flag)` to fold the 32-bit CRC to 16 bits into a WRAM cell, then halt. |
| **Prefilter** | `tools/csmith_run.py` (`prefilter`) | A fast **DEFAULT** build; non-buildable seeds are **SKIP-and-counted**, never silently dropped. Classifiers (`tools/torture_filter.py`): `compile-error` / `undefined-symbol` / `region-overflow` / `link-other`. |
| **Compile ×3** | `tools/a16_fuzz.py` (`compile_rom`) | `default` / `+mos-a16` / `+mos-xy16`, each `-Os` through the LTO `--config`; `corpus_result`'s WRAM address comes from the linker `-Map`. |
| **Run** | MAME + bsnes-jg | MAME via `dev/smoke.lua` (`-autoboot_script`); bsnes-jg via `dev/jgxcheck.cpp`. Each prints a `SMOKE: … got=0xXXXX` line the runner greps (`GOT_RE`). |
| **Compare / triage** | `tools/a16_fuzz.py` (`evaluate`) | All legs `== ref`. Mismatches/crashes saved to `build/fuzz-triage/csmith-seed-NNNNN.{c,txt}`. |

### The adapter — how the checksum gets out of the SNES

Csmith's generated `main()` ends with `platform_main_end(crc32_context ^ 0xFFFFFFFF, flag)`. On a normal host
that printf's the checksum; on the SNES there's no stdio, so `csmith_snes.h` redirects it to a known WRAM
cell that the emulator harness reads back:

```c
/* examples/65816/csmith/csmith_snes.h */
volatile unsigned short corpus_result;                 /* the WRAM cell the emulator samples */
...
static void platform_main_end(uint32_t crc, int flag) {
  (void)flag;
  corpus_result = (unsigned short)(crc ^ (crc >> 16)); /* 16-bit fold of the 32-bit CRC */
  for (;;) { }                                         /* halt; harness samples corpus_result */
}
```

`dev/smoke.lua` registers an `emu.register_periodic` callback, waits `SMOKE_SETTLE` (default 60) frames for
the init chain + `main()` to land the value, reads `SMOKE_LEN` little-endian bytes from `SMOKE_ADDR` out of
the 65816 program space, and prints `SMOKE: PASS … got=0x…`. The address passed in is the WRAM mirror
`0x7E0000 + <corpus_result VMA>`. The bsnes-jg leg (`jgxcheck`) does the same with a direct WRAM read and a
fixed frame count — it's **deterministic** (no Lua settle window), so unlike the MAME leg it's load-insensitive.

### The generation profile (kept small for 128 KB WRAM)

```python
# tools/csmith_run.py  (CSFLAGS)
--max-funcs 3 --max-block-depth 3 --max-array-dim 1 --max-array-len-per-dim 4
--max-struct-fields 4 --max-expr-complexity 8 --max-pointer-depth 2
--no-bitfields --no-unions --no-packed-struct --no-float --no-longlong --concise
```

Keeps programs ~7.5 KB while retaining **arrays / structs / pointers / volatiles** (the addressing-mode +
register-pressure coverage the a16/xy16 work targets). `safe_math` is **kept** (UB-freeness). `--no-longlong`
drops 64-bit `long long` only — **32-bit `long` (s32) is intentionally still emitted**, which is how the
harness exercised the a16 s32 legalizer (see §5).

---

## 3. How to run it

```sh
dev/run.sh fuzz [--gen csmith|builtin] [N] [seed]   # csmith is the DEFAULT generator
dev/run.sh fuzz --gen csmith 1 11                   # reproduce a single seed (11)
dev/run.sh fuzz --gen csmith 40 1                   # the CI "sampled" run
```

- `--gen csmith` (default) runs **host-side** (`dev/csmith.sh` → `tools/csmith_run.py`); `--gen builtin` is
  the hand-rolled generator that stays in the dev container with its own host-computed oracle.
- **QUIET-box rule applies to the MAME leg.** Concurrent docker/MAME load flakes MAME's settle window → false
  failures that pass on re-run. The bsnes-jg leg is exempt (deterministic).
- Expected shape on seeds 1–50: `~46 PASS, 0 mismatch, 0 crash`, with a handful of **SKIP**
  (`diverged-before-result`, see §6). `0 mismatch` is the bar.

---

## 4. CI

The **`fuzz-csmith`** job in `.github/workflows/smoke.yml`:

- **Host-side** (installs MAME on the runner, builds `vendor/csmith` via `dev/fetch-csmith.sh`),
  `needs: xcheck` so it reuses that job's cached from-source toolchain + SDK + `build/jgxcheck`.
- **`workflow_dispatch` only** today. `mode` input = `sampled` (40 seeds from `sample_seed`, default) or
  `full` (`dev/run.sh fuzz --gen csmith 500 1`); `sample_seed` makes the subset reproducible.
- **Secret-gated**: skips (does not fail) without `SNES_SPC700_ROM_B64` (the SPC700 BIOS), like `corpus-a16`.
- A nightly **`schedule:` block is present but commented** (`cron: '0 7 * * *'`); scheduled runs auto-select
  `mode=full`. It's a one-line uncomment, gated on the repo going public.

Dispatch: `gh workflow run snes-smoke -f mode=full` (or `task ci-watch` to follow a run).

---

## 5. What it has already caught (it's a finder, not a formality)

- **seed 113** — `+mos-a16` `G_MERGE_VALUES` `4×s8 → s32` legalizer **crash**. **FIXED on `main`** (s32 under
  a16 is represented as 2×s16; `legalizeMergeS32FromBytes`).
- **seeds 247 + 445** — `+mos-xy16`-only runtime **mismatch** (a 16-bit index value's high byte zeroed by an
  index-narrowing `sep`). **FIXED**; deeply root-caused in
  [`65816-xy16-index16-highbyte-clobber.md`](65816-xy16-index16-highbyte-clobber.md).

The triaged seeds live as artifacts under `build/fuzz-triage/csmith-seed-*.{c,txt}` (gitignored).

---

## 6. Known SKIP / XFAIL conditions

**SKIP (not a defect — no usable oracle):**

- **`diverged-before-result`** — Csmith's `main()` returned before calling `platform_main_end`, so
  `corpus_result` is unreferenced and `--gc-sections` drops it ("corpus_result not in map" → SKIP).
- **Prefilter SKIPs** — `compile-error` / `undefined-symbol` (missing freestanding libc) / `region-overflow`
  (won't fit SNES RAM/ROM) / `link-other`.

**XFAIL (known, tracked codegen crashes):** `regalloc-out-of-registers`, `scavenger-$p-not-GPR` (upstream
scavenger N/Z liveness), `a16-zp-pressure-overflow`. A new FAIL/CRASH outside these is a real regression.

---

## 7. Genuinely-open follow-ups

These are the *only* open residue — everything above is done. Marked clearly so they're not mistaken for
gaps in the harness itself.

- **Nightly schedule** — the commented `schedule:` block; one-line uncomment when the repo is public.
- **Far-pointer / AS2 / AS3 (packed-24) coverage** — Csmith can't emit address-space-qualified pointers
  (`__far`, packed-24), so those codegen paths are **out of its reach by design**; they stay covered by
  c-torture + the hand-written far corpus (`dev/far_*.sh`, `examples/65816/`). Not a Csmith bug to fix.
- **Permanent regression-seed extraction** — found seeds live only as `build/fuzz-triage/` artifacts, not
  promoted to `examples/65816/*.c` regression fixtures; the differential sweep itself is the current gate.
- **Yarpgen as a second `--gen`** — backlog; the `--gen` seam added here makes it drop-in (it would need its
  baked-in `printf` redirected to `corpus_result`, and carries a 16-bit-int caveat — no `platform.info`
  equivalent).
- **Doc hygiene (not part of this harness):** the `TODO.md` item is still `[wip]` though Phases 0–5 are done —
  a candidate for promotion to `[x]`.

---

## Source map (grep anchors, not line numbers — `vendor/` and tools drift)

| Concern | File · anchor |
|---|---|
| Entry / dispatch | `dev/run.sh` (`GEN=csmith`, `--gen`) · `dev/csmith.sh` |
| Generation + filter | `tools/csmith_run.py` (`CSFLAGS`, `generate`, `prefilter`) |
| Differential engine | `tools/a16_fuzz.py` (`evaluate`, `run_mame`, `run_bsnes`, `ref = expected … else got_default`) |
| SNES adapter | `examples/65816/csmith/csmith_snes.h` (`platform_main_end`, `corpus_result`) · `platform.info` |
| Emulator harnesses | `dev/smoke.lua` (MAME) · `dev/jgxcheck.cpp` (bsnes-jg) |
| Csmith build | `dev/fetch-csmith.sh` (→ `vendor/csmith`, `PINNED_SHA`) |
| CI | `.github/workflows/smoke.yml` (`fuzz-csmith`) |
| Plan / status | [`docs/plans/2026-06-19-321-csmith-differential-fuzzer.md`](../plans/2026-06-19-321-csmith-differential-fuzzer.md) · `TODO.md` |
