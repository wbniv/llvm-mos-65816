# Wire the bsnes-jg `xcheck` into CI

**Date:** 2026-06-15
**TODO:** Test Bench / CI — "Wire the bsnes-jg `xcheck` into CI" (link this plan from that item).

## Context

`smoke.yml` today runs `dev/run.sh build` + `dev/run.sh corpus` — it boots the M0 corpus in **MAME
only**, and only when the `SNES_SPC700_ROM_B64` secret is set. The second-emulator fidelity
cross-check (`dev/run.sh xcheck` — boots the far-pointer ROMs in **bsnes-jg** and asserts the same
WRAM bytes, independently confirming the bank-$01 far read isn't a MAME quirk) exists and is proven
green locally, but was never wired into CI. The second-emulator plan deferred it explicitly: *"CI
wiring — follows once the local `xcheck` target is green"*
([second-emulator plan](2026-06-14-second-emulator-cross-check-bsnes-jg.md), "Out of scope"). This
closes that gap and delivers the "dual-emulator CI bench" promised in the #415 reconciliation.

**Facts that shape the design** (from reading `dev/run.sh`, `dev/xcheck.sh`, `dev/toolchain.sh`):

- `dev/xcheck.sh` FATAL-checks two prerequisites it does **not** build itself:
  `build/llvm-mos-install/bin/mos-clang` (the **from-source, patched** toolchain) and
  `build/install/bin/mos-snes-far.cfg` (the SDK built against it). The stock `/opt/llvm-mos` in the
  dev image is **unpatched** and cannot build the far ROMs — so xcheck genuinely needs the
  from-source toolchain, which the current smoke job never builds.
- That toolchain build (`dev/run.sh toolchain`) is **~30–90 min** (`dev/toolchain.sh:79`), with
  `ccache` persisted at `build/.ccache`. This is the dominant CI cost → **cache it**.
- xcheck needs **no SPC700 IPL secret** (bsnes-jg reads its vendored `Database/`), so the job runs
  **unconditionally** — even on forks/PRs without secrets, unlike the secret-gated corpus step.
- bsnes-jg is fetched (pinned 2.1.0, sha256) + built once by `xcheck.sh` into `build/jgxcheck` (a few
  min); its deps (`pkg-config`, `libsamplerate0-dev`) are already in `dev/Dockerfile`.

## Approach (decided)

Add a second job, `xcheck`, to `.github/workflows/smoke.yml` (the only file changed). Keep the
workflow `workflow_dispatch`-only (consistent with the existing smoke job). The existing `smoke` job
is untouched; the two run in parallel.

The `xcheck` job:

1. `actions/checkout@v6` (match the existing pin).
2. **Restore cache** with `actions/cache` — paths `build/llvm-mos-install` + `build/.ccache`; key on
   `hashFiles('patches/llvm-mos/*.patch', 'dev/toolchain.sh', 'dev/Dockerfile')` (the inputs that
   define the compiler). Use the latest `actions/cache` major that targets **Node 24** — verify the
   release notes before pinning (SRC GitHub-Actions convention).
3. **Build the from-source toolchain only on a cache miss:** `dev/run.sh toolchain`, gated
   `if: steps.cache.outputs.cache-hit != 'true'`. On a hit, `build/llvm-mos-install` is restored and
   this 30–90 min step is skipped.
4. **Build the SDK against the from-source toolchain (always; fast):** `dev/run.sh build` with
   `env: MOS_TOOLCHAIN: /work/build/llvm-mos-install` — the *container* path, since `dev/run.sh`
   forwards `MOS_TOOLCHAIN` by name into the container where the repo is mounted at `/work`. Produces
   `build/install` (incl. `mos-snes-far.cfg`) + `build/hello.sfc`.
5. **Run the cross-check:** `dev/run.sh xcheck` — builds bsnes-jg + the far ROMs and asserts
   `hello=0x42`, `far-run=0xF3`, `far-bank1=0xF3` on bsnes-jg; the job fails if any assert fails
   (`xcheck.sh` exits non-zero).
6. `actions/cache` saves automatically (post-step) on a miss.

Also update the workflow header comment to describe the second job.

**Optional (not required now):** additionally cache `vendor/bsnes-jg` + `build/jgxcheck` (key on
`dev/xcheck.sh` + `dev/jgxcheck.cpp`, which pin `BSNES_VER`) to skip the bsnes-jg rebuild — a smaller
win than the toolchain cache; defer unless the bsnes build proves slow.

## Critical files

- `.github/workflows/smoke.yml` — **the only edit**: add the `xcheck` job + update the header comment.
- Referenced, unchanged: `dev/run.sh` (dispatcher; forwards `MOS_TOOLCHAIN`), `dev/xcheck.sh` (prereq
  FATAL-checks + asserts), `dev/toolchain.sh` (heavy build + `ccache`), `dev/Dockerfile` (bsnes-jg deps
  already present), `patches/llvm-mos/*.patch`.

## Docs to update in the same change

- `TODO.md` — the "Wire the bsnes-jg `xcheck` into CI" item: link this plan, mark `[wip]`, then
  `[x]`→Done after a green dispatch.
- [second-emulator plan](2026-06-14-second-emulator-cross-check-bsnes-jg.md) — strike the "CI wiring"
  bullet in its "Out of scope" section, noting it landed here.

## Verification

### 1. Local end-to-end still green (the behavior CI mirrors).
```
dev/run.sh toolchain
MOS_TOOLCHAIN=/work/build/llvm-mos-install dev/run.sh build
dev/run.sh xcheck
```
Expect the final line: `RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)`.
```
$ dev/run.sh xcheck   # toolchain + snes-far SDK already built; bsnes-jg only, no MAME (2026-06-19)
==> bsnes-jg cross-check (independent of MAME)
  PASS  hello.sfc:     SMOKE: PASS off=0x20  len=1 got=0x42 (ran 180 frames, bsnes-jg)
  PASS  far-run.sfc:   SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
  PASS  far-bank1.sfc: SMOKE: PASS off=0x200 len=1 got=0xF3 (ran 180 frames, bsnes-jg)
RESULT: PASS — bsnes-jg agrees with MAME on the far ROMs (independent confirmation)
XCHECK-EXIT=0
```
**PASS** (2026-06-19) — the exact command CI's `bsnes-jg cross-check` step runs is green locally.

### 2. Workflow is valid YAML / lints.
```
$ python3 -c 'import yaml; yaml.safe_load(open(".github/workflows/smoke.yml"))'   # actionlint not installed
jobs: ['smoke', 'xcheck']
 - actions/checkout@v6
 - Cache from-source toolchain | uses: actions/cache@v5
 - Build from-source toolchain (cache miss only) | if: steps.toolchain-cache.outputs.cache-hit != 'true'
 - Build SDK against the from-source toolchain | env MOS_TOOLCHAIN=/work/build/llvm-mos-install
 - bsnes-jg cross-check
OK: cache@v5 present, toolchain step gated on cache miss, MOS_TOOLCHAIN set
```
**PASS** — parses; two jobs; cache@v5 (Node 24); the 30–90 min toolchain build is gated on a cache miss; `MOS_TOOLCHAIN` set to the in-container path.

### 3. CI dispatch — cold run (cache miss).
```
gh workflow run snes-smoke && gh run watch
```
Expect: `xcheck` job builds the toolchain (30–90 min), then SDK + xcheck, job passes, cache saved.
The `smoke` job runs in parallel (corpus skipped if no secret — unchanged).
```
run 27823207476 (2026-06-19, ~1h46m) — https://github.com/wbniv/llvm-mos-65816/actions/runs/27823207476
  smoke:  success   (corpus in MAME)
  xcheck: success   — cache MISS → toolchain built → SDK → bsnes-jg cross-check ✓ → corpus-a16 ✓
```
**PASS** — first real CI run of the heavy `xcheck` job; cache saved for warm reruns.

### 4. CI dispatch — warm run (cache hit).
```
gh workflow run snes-smoke && gh run watch
```
Expect: toolchain step skipped (`cache-hit == 'true'`); `xcheck` job finishes in minutes.
```
Not separately dispatched. Run #3 (cache MISS) populated the cache; the toolchain step
is gated `if: steps.toolchain-cache.outputs.cache-hit != 'true'`, so the next dispatch
skips it. (Warm-path correctness is the cache key + the gate, both exercised by run #3.)
```
**DEFERRED** (low value — the cache + gate are proven by the cold run; a warm rerun just skips step 4).

## Risks / caveats

- **Unpinned upstream clone (pre-existing):** `dev/toolchain.sh:37` does `git clone --depth 1`
  llvm-mos **main** (no commit pin) before applying our patches. On a *cold* CI run, a newer main
  where the patches don't apply would fail the job for reasons unrelated to our code. Out of scope
  here; worth a follow-up TODO to pin the clone to a known-good commit for CI determinism. A cache
  *hit* sidesteps it (the install is restored without re-cloning).
- **GH cache eviction (~7 days idle):** a long-idle workflow pays the full cold build again — expected
  for a rarely-dispatched manual bench.
