# M1 Phase 0 — from-source llvm-mos toolchain + green baseline

**Date:** 2026-06-14 · **Status:** Planned · **Milestone:** M1 prerequisite (gates ROADMAP steps 3–4).
**Builds on:** M0 bench — [smoke loop](2026-06-14-emulator-smoke-loop.md),
[regression corpus](2026-06-14-m0-regression-corpus-5-self-contained-c-programs.md).

## Context

M1 is **[#320](https://github.com/llvm-mos/llvm-mos/issues/320) — 24-bit address space / far
pointers**: the first *real* 65816 codegen, modifying the llvm-mos LLVM backend (C++/TableGen).
Every prior milestone was bench infrastructure built on a **prebuilt, immutable** toolchain
(`dev/Dockerfile` downloads `llvm-mos-linux-main.tar.xz`). You cannot change codegen without
**building llvm-mos from source** — that is the unavoidable, and only *non-design-gated*,
prerequisite for all of M1/M2.

This plan scopes exactly that foundation: stand up a from-source llvm-mos build in the dev
environment, then prove the **M0 regression corpus stays green** when the bench is pointed at the
self-built compiler. That green baseline is what every codegen change is built on and measured
against. The actual #320 data-layout work (below) is a **separate, upstream-coordinated** follow-up —
the [roadmap](../ROADMAP.md) is explicit that the ABI/data-layout design is gated on the maintainers
(@asiekierka / @mysterymath, llvm-mos Discord), so it should not be barreled into here.

## Design — the build foundation

**Persistent dirs, not image layers.** Codegen iteration means editing backend `.cpp`/`.td` and
relinking `clang` repeatedly. Baking the LLVM build into a Docker layer would rebuild it on every
edit. Instead clone + build into the gitignored mounted tree (like `vendor/llvm-mos-sdk` today), so
ninja does fast *incremental* rebuilds:

- `vendor/llvm-mos/` — the llvm-mos monorepo clone (gitignored under existing `/vendor/`).
- `build/llvm-mos/` — the CMake/ninja build tree; `build/llvm-mos-install/` — install prefix
  (both gitignored under existing `/build/`). ccache at `build/.ccache`.

**Official build path** (from the llvm-mos repo README):

```sh
git clone https://github.com/llvm-mos/llvm-mos.git vendor/llvm-mos
cmake -C vendor/llvm-mos/clang/cmake/caches/MOS.cmake -G Ninja \
      -S vendor/llvm-mos/llvm -B build/llvm-mos \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=build/llvm-mos-install \
      -DLLVM_PARALLEL_LINK_JOBS=1 -DLLVM_USE_LINKER=lld -DLLVM_CCACHE_BUILD=On
cmake --build build/llvm-mos -- distribution -j<tuned>
cmake --build build/llvm-mos -- install-distribution
```

The `MOS.cmake` cache sets the target + projects (clang/lld) — no manual `LLVM_TARGETS_TO_BUILD`.
RAM is the binding constraint (14 GiB host), so: **Release** (Debug would OOM), `lld`,
`LLVM_PARALLEL_LINK_JOBS=1`, and compile `-j` tuned down if needed. ccache makes rebuilds cheap.

**Selectable toolchain in the bench.** `dev/build.sh` currently hardcodes `/opt/llvm-mos/bin/mos-clang`.
Generalize to `${MOS_TOOLCHAIN:-/opt/llvm-mos/bin}`; `dev/run.sh` forwards `MOS_TOOLCHAIN` into the
container (same pattern as `SMOKE_WANT`). Then:

- `dev/run.sh corpus` → prebuilt toolchain (today, unchanged default)
- `MOS_TOOLCHAIN=/work/build/llvm-mos-install/bin dev/run.sh build && … corpus` → self-built

**Baseline parity.** The corpus asserts *computed values* (correct C semantics), which are
compiler-version-independent — so the self-built compiler must produce the same **7/7**. That
equivalence is the foundation: we can build the compiler, swap it into the bench, and nothing
regresses. (Pinning the clone to the prebuilt's commit `c798c314` makes it an exact apples-to-apples
baseline; not required for the value check, but tidy — note it.)

## Files

| File | Change |
|------|--------|
| `dev/toolchain.sh` | **NEW** (in-container) — clone llvm-mos, configure with `MOS.cmake`, build+install the `distribution` target into `build/llvm-mos-install` (RAM-tuned) |
| `dev/Dockerfile` | add host build deps for LLVM: `clang lld ccache` (and `zlib1g-dev` if the configure needs it) |
| `dev/build.sh` | use `${MOS_TOOLCHAIN:-/opt/llvm-mos/bin}` instead of the hardcoded path |
| `dev/run.sh` | add the `toolchain` target; forward `MOS_TOOLCHAIN` into the container; usage/help |
| `.gitignore` | already covers `/vendor/` + `/build/` — confirm `build/.ccache`, `build/llvm-mos*` ignored |
| `README.md`, `docs/ROADMAP.md`, `TODO.md` | document the `toolchain` target + M1-Phase-0 baseline |

## Implementation steps

1. **Image deps**: add `clang lld ccache` to `dev/Dockerfile`; rebuild image (cached layers + one new
   apt layer). `dev/run.sh corpus` still 7/7 (regression guard on the prebuilt path).
2. **`dev/toolchain.sh`**: clone (shallow, pinned commit) → configure (MOS cache, Release, RAM-tuned)
   → `cmake --build … distribution` → `install-distribution`. Add `dev/run.sh toolchain`. Run it in
   the background, monitor (first build is long); tune `-j`/link jobs empirically against the 14 GiB
   ceiling. Abort early + adjust if it OOMs.
3. **Selectable toolchain**: `MOS_TOOLCHAIN` in `dev/build.sh` + forwarded by `dev/run.sh`.
4. **Baseline**: `MOS_TOOLCHAIN=…/llvm-mos-install/bin dev/run.sh build` then `… corpus` → **7/7**
   with the self-built compiler (parity with prebuilt).
5. **Incremental check**: touch a backend source file, rebuild → ninja relinks only (fast), confirming
   the iteration loop codegen work needs.
6. **Docs**: README (`toolchain` target + when to use self-built vs prebuilt), ROADMAP (M1 Phase 0
   foundation laid), TODO.

## Verification

1. **Toolchain builds from source** — `dev/run.sh toolchain` then
   `build/llvm-mos-install/bin/mos-clang --version` prints a clang version. (Evidence: version string,
   commit, "built from source".)
2. **Baseline parity (the deliverable)** — `MOS_TOOLCHAIN=…install/bin dev/run.sh build && … corpus`
   → `corpus: 7/7 passed`, identical expected values to the prebuilt run. (Evidence: corpus table.)
3. **Default path unchanged** — plain `dev/run.sh corpus` (prebuilt) still 7/7; `dev/run.sh repro`
   still green. (Evidence: corpus table + `repro OK`.)
4. **Incremental rebuild** — editing one backend file triggers a relink, not a full rebuild.
   (Evidence: ninja build log shows a handful of recompiles.)

## Risks

- **RAM (14 GiB) — primary.** Linking `clang` is memory-hungry. Mitigate: Release build, `lld`,
  `LLVM_PARALLEL_LINK_JOBS=1`, reduce compile `-j` if it swaps. Fallback if it still OOMs: add swap,
  or build on a beefier machine and copy the install tree in (the bench only needs the install dir).
  Step 2 verifies feasibility empirically.
- **Disk** — an LLVM build tree is ~20–40 GB; 84 GB free. Monitor; the tree is gitignored on the
  mounted volume. ccache adds a few GB.
- **First-build time** — 30–90 min on 12 cores. Run in background + monitor; ccache + persistent
  build dir make all later rebuilds fast.
- **Drift from prebuilt** — pin the clone to the prebuilt's commit (`c798c314`) for an exact baseline;
  the corpus value-check holds regardless of version, so this is tidiness not correctness.

## Deferred to a follow-up plan — #320 codegen proper (NOT in this plan)

Once the foundation stands, the actual far-pointer codegen is a separate, **upstream-coordinated**
effort (the roadmap: engage the llvm-mos Discord / @asiekierka before large PRs). Sketch, from
@asiekierka's 2024-03-14 design in [#320](https://github.com/llvm-mos/llvm-mos/issues/320):

- A **five-address-space** LLVM data layout — `0`=32-bit far (default; *cheaper* than 24-bit on the
  65816), `1`=8-bit direct page, `2`=16-bit absolute, `3`=24-bit packed far, `4`=16-bit zero-bank.
- Track near/far data accesses + calls (`JSR` vs `JSL`); registers stay 8-bit (16-bit regs are M2 /
  [#321](https://github.com/llvm-mos/llvm-mos/issues/321)).
- New corpus programs that dereference across ≥2 banks become the M1 regression set (ROADMAP steps
  3–4); disassembly spot-checks that near→`JSR`/far→`JSL` and addrspace→addressing-mode (step 4).

This plan deliberately stops at the foundation: it's the only part that is both tractable now and
independent of the upstream ABI design.
