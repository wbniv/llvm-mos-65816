# SPC700 strong copy hint outside the allocation order: upstream packet (2026‑10‑10)

**Status:** prepared, not posted. No branch has been pushed and no PR opened. Posting is user-triggered, and the packet should get an independent review first.

Attribution: Claude Code 2.1.296, `t4-opus-high` agent, model Claude Opus 5.5 (`claude-opus-5-5`), high reasoning effort (agent definition); session [session_012Tm5osWxSMUvv28Uw7nudx](https://claude.ai/code/session_012Tm5osWxSMUvv28Uw7nudx).

## What it is

| Item | Value |
|---|---|
| Destination | `llvm-mos/llvm-mos` `main` at `0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63` (the current tip, checked with `gh api repos/llvm-mos/llvm-mos/commits/main` on 2026‑10‑10) |
| Patch | [`0001-MOS-Keep-strong-copy-hints-inside-the-allocation-order.patch`](0001-MOS-Keep-strong-copy-hints-inside-the-allocation-order.patch), one commit: `MOSRegisterInfo.cpp` (+6/−2) and the new `llvm/test/CodeGen/MOS/regalloc-spc700.mir` |
| Local commit | `5e81aef50cd4` on branch `mos-spc700-strong-hint-order` in `build/spc700-hint/main-source`, a sparse worktree of `vendor/llvm-mos-0f031168a7cc`; parent `0f031168a7cc` |
| PR title | `[MOS] Keep strong copy hints inside the allocation order` |
| PR body | [`pr-body.md`](pr-body.md), one physical line per paragraph |
| Dependencies | None. #584, needed for the end-to-end IR runs on the older `06bc967d`, is already in `main`. |
| Formatter | `clang-format` from the pin build reports no change on the edited lines (699–708) |
| Defect record | [`mos-spc700-hint-outside-order`](../../../defects/mos-spc700-hint-outside-order.json); [plan](../../../plans/2026-10-10-spc700-hint-outside-order.md); [06bc967d evidence](../../../defects/evidence/2026-10-10-spc700-hint-repair/README.md) |

Breaking change: [`93d338b079d4`](https://github.com/llvm-mos/llvm-mos/commit/93d338b079d4c158794a9a0e74b53bbe90721205) (part of [#448](https://github.com/llvm-mos/llvm-mos/pull/448), 2024‑03‑02) lets SPC700 `LDImm` define `Anyi8`. That brought the reserved `RC17`, which [#357](https://github.com/llvm-mos/llvm-mos/pull/357) uses for the indirect-call thunk, into the constant's class. This was identified by reading the diffs, not by bisection.

## Destination validation (assertions on)

Build: `build/spc700-hint/build`, Release with assertions, MOS target only (`LLVM_TARGETS_TO_BUILD=""`, `LLVM_EXPERIMENTAL_TARGETS_TO_BUILD=MOS`). Run through `dev/container.sh` with `build/spc700-hint/main-source` mounted at `/work/build/register-exhaustion-src` and the build at `/work/build/0029-cross-target-build`, the paths in its CMake cache.

| `llc` | Source | SHA‑256 |
|---|---|---|
| `build/spc700-hint/llc/up-0f031168` | `0f031168a7cc`, clean | `d8fa72014a0c6d55fbcb381c60931b76801b233b97f379ef80411d5be773a18a` |
| `build/spc700-hint/llc/fix-0f031168` | + this patch | `9b17ce381b16334ad538f3ba429fb4314d40ada4f12325227425a027f7d658ac` |

| Check | Unrepaired | Repaired |
|---|---|---|
| `regalloc-spc700.mir`, `-run-pass=greedy,virtregrewriter -verify-machineinstrs` ([up](evidence/mir-up-0f031168.log), [fix](evidence/mir-fix-0f031168.log)) | exit 134, `Target hint is outside allocation order` | exit 0 |
| Reduced `boids-reduced.ll -O2 -verify-machineinstrs` ([up](evidence/reduced-up-0f031168.log), [fix](evidence/reduced-fix-0f031168.log)) | exit 134, same assertion | exit 0 |
| Record input `boids.ll -O2 -disable-spill-hoist -verify-machineinstrs` ([up](evidence/boids-disable-spill-hoist-up-0f031168.log), [fix](evidence/boids-disable-spill-hoist-fix-0f031168.log)) | exit 134, same assertion | exit 0 |
| Record input `boids.ll -O2`, no `-disable-spill-hoist` ([fix](evidence/boids-fix-0f031168.log)) | (assertion) | exit 134 in `@_title_emit`: the separate spill-hoist defect (`0033`) that clang avoids |
| MOS lit `CodeGen/MOS` + `MC/MOS` ([up](evidence/lit-up-0f031168.log), [fix](evidence/lit-fix-0f031168.log)) | 138 passed, 1 unsupported, 1 failed (`regalloc-spc700.mir`) | 139 passed, 1 unsupported |

Corpus check on the same two compilers ([summary](evidence/census-summary.txt); rows in `evidence/upmain-nsh.tsv` and `evidence/fixmain-nsh.tsv`; per-CPU exit codes in `evidence/xcpu-*.rc`). It covers the 52 default-mode IRs, `mosspc700`, `-verify-machineinstrs -disable-spill-hoist`, at `-O0` to `-O3`, with `-Os` and `-Oz` run as optsize and minsize attribute copies at `-O2`:

- 18 inputs abort with the assertion at each of `-O1`, `-O2`, `-O3`, `-Os` and `-Oz`, and all of them compile with the repair (90 outcomes). No other outcome changes, and the 177 input/level pairs that compiled before give byte-identical assembly.
- `mos6502`, `mos65c02`, `mos65ce02`, `moshuc6280` (19 inputs compile) and `mosw65816` (46) at `-O2`: identical exit codes and assembly.
- Failures shared by both compilers, unrelated to this change: 5 far-pointer legalization errors, one Loop Strength Reduction assertion, and `-O0`/`-Oz` machine-verifier errors.

## Reviewer commands

From an llvm-mos checkout at `0f031168a7cc` with this patch applied and an assertions build in `build/`:

```sh
build/bin/llvm-lit -v llvm/test/CodeGen/MOS/regalloc-spc700.mir
build/bin/llvm-lit llvm/test/CodeGen/MOS llvm/test/MC/MOS
# red: restore only the source file, keep the new test
git checkout HEAD~1 -- llvm/lib/Target/MOS/MOSRegisterInfo.cpp && ninja -C build llc && build/bin/llvm-lit -v llvm/test/CodeGen/MOS/regalloc-spc700.mir
git checkout HEAD -- llvm/lib/Target/MOS/MOSRegisterInfo.cpp
```

## Post command (only when the user asks)

```sh
git -C <llvm-mos clone> fetch origin main
git -C <llvm-mos clone> switch -c mos-spc700-strong-hint-order 0f031168a7cc8e81b7b40c0ec0b1f7b3c90b8a63
git -C <llvm-mos clone> am docs/pr-preparations/2026-10-10/spc700-hint-order/0001-MOS-Keep-strong-copy-hints-inside-the-allocation-order.patch
git -C <llvm-mos clone> push wbniv mos-spc700-strong-hint-order
gh pr create --repo llvm-mos/llvm-mos --head wbniv:mos-spc700-strong-hint-order \
  --title "[MOS] Keep strong copy hints inside the allocation order" \
  --body-file docs/pr-preparations/2026-10-10/spc700-hint-order/pr-body.md
```

Before posting, read the live upstream `main` again. Rebase if it has moved, and rerun the first two reviewer commands.
