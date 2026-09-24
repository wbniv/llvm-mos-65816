# Toolchain pin bootstrap proof — 2026-09-24

**TODO item:** "Prove the toolchain pin with one clean bootstrap" (`[T2]`).

**Claim being tested:** `dev/toolchain.sh` (commit `67cd5542`) pins `LLVM_MOS_PIN =
8be0546128a55e78c63ca571d466aa72a782cd36` and applies the tracked `patches/llvm-mos/*.patch` stack to a
FRESH `vendor/`. That pin was justified by reading `dev/regen-patch.sh` (0002 is regenerated against the
live vendor HEAD, which is that SHA) — never by actually running the bootstrap. This proves it end to end.

**Verdict: NO — the committed patch stack does not apply cleanly against the pin.**
`0035-clang-prefetch-int16-operands.patch` fails on a fresh checkout at `8be0546`. `dev/run.sh toolchain`
from a clean clone exits non-zero before ever reaching the `cmake configure`/build step, so no artifact
comparison (item 2 of the task) is possible — there is no `clang-23` to hash or run.

## Set-up

| Step | Command | Result |
|---|---|---|
| Worktree off `main` tip | `git -C /home/will/llvm-mos-65816 worktree add -b wt/321-pin-bootstrap /home/will/llvm-mos-65816-pin-bootstrap main` | Created at `46ea814b` (main tip at start of this run) |
| ccache warm (hardlink, not a rebuild shortcut) | `mkdir -p build && cp -al $MAIN/build/.ccache build/.ccache` | 949 MB hardlinked; ccache writes new entries atomically so sharing is safe. **This does not affect the finding below** — the failure is a `git apply` rejection before any compiler invocation, so ccache never enters into it. |
| Pre-flight: no other toolchain build running | `pgrep -f "[d]ev/run.sh toolchain"`, `pgrep -f "[c]ake --build /work/build/llvm-mos"` | Both empty before launch |
| Docker image | `docker image inspect llvm-mos-65816-dev` | Present (`sha256:863ab74…`, built 2026-09-14) — reused, not rebuilt |

## 1. The bootstrap run

Command: `BUILD_JOBS=6 dev/run.sh toolchain` run from `/home/will/llvm-mos-65816-pin-bootstrap` (own
`vendor/` and `build/`, per `docs/howto-feature-worktree.md` — the container bind-mounts the worktree root
as `/work`, so the shared main tree's `vendor/`/`build/` are never touched).

- **Exit status:** 1 (`rc=1`, appended by the launcher wrapper).
- **Wall clock:** 98 seconds (`start_epoch=1790217956` → `end_epoch=1790218054`, both from `date -u +%s`
  bracketing the call in the launcher) — the Docker image was cached, so this is almost entirely the `git
  fetch` + patch-apply loop, not a build.
- **Fetch line:** `==> fetch llvm-mos @ 8be0546128a5 into vendor/ (gitignored, shallow, pinned)` — no
  "shallow fetch … refused" line followed, so the shallow-fetch-by-SHA path succeeded directly. **The
  full-fetch fallback branch remains untested** (GitHub did not refuse the SHA, so the fallback never ran).
- **Pin check:** `git -C vendor/llvm-mos rev-parse HEAD` → `8be0546128a55e78c63ca571d466aa72a782cd36` —
  **matches `LLVM_MOS_PIN` exactly.** The fetch+checkout half of the claim holds.

### Per-patch yes/no (in the order the *committed* `dev/toolchain.sh` lists them)

| # | Patch | Applied? |
|---|---|---|
| 1 | `0001-320-far-addrspace` | ✅ yes |
| 2 | `0002-321-accum16` | ✅ yes |
| 3 | `0010-coalesce-rotate-ac` | ✅ yes |
| 4 | `0018-320-imag32-spill` | ✅ yes |
| 5 | `0019-mos-branch-range-diagnostic` | ✅ yes |
| 6 | `0020-mos-65816-block-move-bank-order` | ✅ yes |
| 7 | `0021-mos-zp-alloc-deterministic` | ✅ yes |
| 8 | `0006-320-packed24` (path-filtered) | ✅ yes |
| 9 | `0029-llvm-twoaddr-physreg-reschedule` | ✅ yes |
| 10 | `0033-llvm-spill-hoist-no-new-vregs` | ✅ yes |
| 11 | `0035-clang-prefetch-int16-operands` | ❌ **NO — `git apply` rejected** |
| 12–25 | `0037`, `0040`, `0041`, `0003`, `0022`, `0023`, `0024`, `0025`, `0030`, `0031`, `0032`, `0034`, `0036`, `0038` | **not attempted** — `set -euo pipefail` propagated `git apply`'s failure and the script aborted at patch 11 |

Raw failure (`git -C vendor/llvm-mos apply patches/llvm-mos/0035-clang-prefetch-int16-operands.patch`):

```
error: patch failed: clang/lib/CodeGen/CGBuiltin.cpp:4096
error: clang/lib/CodeGen/CGBuiltin.cpp: patch does not apply
```

**Root cause.** The patch's context lines assume `CodeGenFunction::EmitBuiltinExpr`'s
`Builtin::BI__builtin_prefetch` case already went through an upstream Clang refactor that introduced
`unsigned ICEArguments = …` and `EmitScalarOrConstFoldImmArg(...)`. At the pin `8be0546`, that case is still
the older shape (`EmitScalarExpr(E->getArg(1))` directly, no `ICEArguments`, one-line `// FIXME:` comment
still present) — confirmed by `grep -n BI__builtin_prefetch` on the fresh checkout, which puts the case at
line 3960, not the patch's expected 4096, with the older body:

```c
  case Builtin::BI__builtin_prefetch: {
    Value *Locality, *RW, *Address = EmitScalarExpr(E->getArg(0));
    // FIXME: Technically these constants should of type 'int', yes?
    RW = (E->getNumArgs() > 1) ? EmitScalarExpr(E->getArg(1)) :
      llvm::ConstantInt::get(Int32Ty, 0);
    Locality = (E->getNumArgs() > 2) ? EmitScalarExpr(E->getArg(2)) :
      llvm::ConstantInt::get(Int32Ty, 3);
```

So `0035` was generated (or last verified) against a **later** upstream Clang than the pin — the same
class of problem the `dev/toolchain.sh` header comment already calls out for `0002` (`build/upstream-
reference/742d554…` being a newer reference than the pin), except here it hit a *standalone* patch that
has no equivalent "regen against live vendor HEAD" step protecting it.

**Corroborating evidence, not a fix.** The main working copy's shared `vendor/llvm-mos` (also checked out
at `8be0546128a55e78c63ca571d466aa72a782cd36`) already carries a *working* version of this hunk — the
`Builder.CreateIntCast(RW, Int32Ty, …)` / `Builder.CreateIntCast(Locality, Int32Ty, …)` lines are present —
but built on the **old** `EmitScalarExpr` base, not the `ICEArguments`/`EmitScalarOrConstFoldImmArg` base
the tracked `0035` patch file expects:

```c
  case Builtin::BI__builtin_prefetch: {
    Value *Locality, *RW, *Address = EmitScalarExpr(E->getArg(0));
    RW = (E->getNumArgs() > 1) ? EmitScalarExpr(E->getArg(1)) :
      llvm::ConstantInt::get(Int32Ty, 0);
    Locality = (E->getNumArgs() > 2) ? EmitScalarExpr(E->getArg(2)) :
      llvm::ConstantInt::get(Int32Ty, 3);
    // The rw and locality arguments keep the type of the promoted C expression
    // (16-bit int, long, long long, ...), but the intrinsic takes i32.
    RW = Builder.CreateIntCast(RW, Int32Ty, /*isSigned=*/false);
    Locality = Builder.CreateIntCast(Locality, Int32Ty, /*isSigned=*/false);
```

This means whoever landed `0035` in the live vendor tree adapted it by hand to the pin's actual base, and
the **tracked patch file was never regenerated** to match that hand-adaptation — so it silently stopped
being reproducible from `patches/llvm-mos/` alone. This is a factual observation from diffing the two
trees, not a diagnosis of *when* it drifted; no further root-causing was done (out of this task's remit —
see Escalation below).

### Note on `dev/toolchain.sh` itself

The **committed** `dev/toolchain.sh` (the one this proof ran, via the worktree's clean checkout of `main`
tip `46ea814b`) applies exactly the 25 patches listed above, in that order — confirmed by
`grep -n apply_patch dev/toolchain.sh` against the worktree copy. The *live, uncommitted* copy in the main
working tree (`/home/will/llvm-mos-65816`, flagged `M dev/toolchain.sh` in this session's git status) has
an in-flight, unrelated edit from another agent that additionally calls
`apply_patch 0028-llvm-virtregrewriter-undef-lane-identity-copy` between `0006` and `0029` — that line is
**not part of what was tested here** (correctly: the worktree is a clean checkout of the committed
script, per the task's own instructions to test the committed pin/stack, not another worker's WIP).

## 2. Artifact comparison — blocked, not performed

Not run. `cmake configure`/`build` never started (the script aborted at the patch-apply loop), so
`build/llvm-mos-install/bin/clang-23` does not exist in the worktree. There is nothing to `sha256sum`
against `$MAIN/build/llvm-mos-install/bin/clang-23`, and no compiler to run the corpus/torture
assembly-equivalence sweep with. This is a direct consequence of the finding in §1, not a separate gap.

`vendor/llvm-mos` status in the worktree: `git status --short` shows only the patch-stack's modifications
(the 10 applied patches) plus the untracked new files those patches add — no unexpected changes. HEAD is
detached at the pin (`8be0546128a55e78c63ca571d466aa72a782cd36`), as `dev/toolchain.sh` intends for a fresh
clone.

## 3. Untested branch

The shallow-fetch fallback (`git fetch` without `--depth 1` when GitHub refuses `uploadpack.allowAnySHA1InWant`
for the pinned SHA) did not run — the shallow fetch of the pinned SHA succeeded directly. Still untested,
as noted in the task.

## Escalation

**ESCALATE: this needs a T3/T4 dispatch** — `0035-clang-prefetch-int16-operands.patch` does not apply to a
fresh `vendor/` at the current pin (`8be0546128a55e78c63ca571d466aa72a782cd36`); the tracked patch file was
generated/validated against a later upstream Clang than the pin and was never regenerated to match how it
was actually integrated into the shared, hand-adapted `vendor/llvm-mos`. Fixing this requires a design
decision this task's remit explicitly excludes ("if any `apply_patch` fails … do not try to fix the
patch"): either (a) regenerate `0035` against the pin's actual `EmitScalarExpr` base (mirroring what's
live in `vendor/`), or (b) move `LLVM_MOS_PIN` forward to a SHA that already carries the
`EmitScalarOrConstFoldImmArg` refactor `0035` assumes, which then requires re-verifying the *entire*
25-patch stack against the new base (per `dev/toolchain.sh`'s own warning about moving the pin not being a
one-liner). Until one of those lands, **`dev/toolchain.sh` cannot bootstrap a working compiler from a
fresh `vendor/` at all** — the reproducibility promise ("a clean build reproduces our compiler") is
currently false for anything past patch 10 of 25.

## Bottom line

| Claim | Verdict |
|---|---|
| Fresh `vendor/` fetches and checks out exactly the pinned SHA | ✅ yes |
| The tracked patch stack applies cleanly on top of that SHA | ❌ **no** — fails at patch 11/25 (`0035`) |
| A clean bootstrap produces a working `clang-23`/`lld` | ❌ no — never reached (blocked by the above) |
| Installed `clang-23` matches the shared build's `clang-23` (sha256) | not applicable — no artifact was produced |
| Corpus/torture `-S` assembly equivalence at `-Os` for `mos6502` and `mosw65816+mos-a16` | not applicable — no compiler was produced |
