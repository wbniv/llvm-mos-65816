# Dither `-O3`: the soft stack overwrites static data

Canonical record: [`snes-soft-stack-static-data-collision`](../../snes-soft-stack-static-data-collision.json). Investigation: [2026‑10‑01 dither `-O3` soft-stack collision](../../../investigations/2026-10-01-dither-o3-soft-stack-collision.md). Prior-work audit: [`prior-work-audit.md`](prior-work-audit.md).

Attribution: Claude Code 2.1.286 (`claude --version`), model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort (T4 design-and-build agent definition; the effort is not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F). No compiler, `vendor/` or patch change was made.

## Identity

Every run used the worktree `/home/will/llvm-mos-65816-o3dither` (branch `wt/o3-dither-defect` off `origin/main` `0b8298a9`), whose `build/llvm-mos-install` and `build/install` are hardlinks of `/home/will/llvm-mos-65816/build/…`.

| Tool | Path | sha256 |
|---|---|---|
| clang-23 (installed) | `build/llvm-mos-install/bin/clang-23` | `254624ba26462f49b4c875b16eda3a1d10d7b766dd80175ec69b64bc96485b0c` |
| lld (installed) | `build/llvm-mos-install/bin/lld` | `c89b04cb2fb93cd3959ce8a1251ca1a967eb550b1d03e5dbdc81bf12f25323a4` |
| llc (installed) | `build/llvm-mos-install/bin/llc` | `cf5355d392bd37cdce2606c6bb19465db68a63e8ffa911613fabc474ffa2d5f7` |
| SDK config | `build/install/bin/mos-snes.cfg` | `f12c5b6aecb6cf483a505d2edc338886028ea9c93f0ae638b0ee237398012205` |
| SNES linker script | `build/install/mos-platform/snes/lib/link.ld` | `9eb48681d0088e3766fb49541a0eb31e571859c33eeb9711e90adb453308a048` |
| Upstream llc (`06bc967d2668`) | `/home/will/llvm-mos-65816/build/pressure-sets/llc/321-00` | `2f5c17683f93825767f9d4888ab6a15c929e9508ef2817c3267f9199e14d39a7` (equals `frozen-llc.sha256`) |
| Upstream clang (unpatched `742d554bf080`) | `/home/will/llvm-mos-65816/build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/clang-23` | `b48000f510c8769ea48709c09d985c32d3933e64856ace67fc8fe861b30497aa` |
| bsnes-jg gate | `build/jgxcheck` | `4c9a88d21a6098b4f0a4443aebf03a75c7f6fd5f8b7dee18a4ac5f4d76e7006f` |
| MAME 0.285 | `/usr/games/mame` in image `llvm-mos-65816-dev` `sha256:e7c17fd1…` | `b8de871c99effd28e90c426b811694811bcb533741189f93ad63a962621ae40c` |
| llvm-dis (reading only) | `/home/will/llvm-mos-65816/build/llvm-mos/bin/llvm-dis` | `461791d2dce7308dc937d2355956cbbbe368178d7706e069d738b6b1d7d9a9dd` |

Input: `examples/snes/dither.c` (git blob `1be807bc`, copy in [`input/`](input/), with `dither.h` and the preprocessed `dither.O3.i`). Expected: `corpus_result == 0x80C4` (host oracle `tools/dither-sim.c`).

## Reproduce

[`tools/reproduce.sh`](tools/reproduce.sh) (`-h` lists the subcommands) drove every run below. The logs in [`logs/`](logs/) are the raw output; `OUT` was a scratch directory. Each compiler and linker ran under `ulimit -c 0; ulimit -v 2000000` and `timeout`, with at most 3 jobs.

```sh
E=docs/defects/evidence/2026-10-01-snes-soft-stack-collision
$E/tools/reproduce.sh gate OUT O3 default stock        # baseline: exit 1, got=0x0000
$E/tools/reproduce.sh gate OUT O3 default reorder      # same code, data moved: exit 0
$E/tools/reproduce.sh code-identity OUT O3 default     # 9573 instructions, 0 differ
dev/container.sh -v OUT:OUT -- bash $E/tools/reproduce.sh mame OUT
```

## Results

### Differential (bsnes-jg frame 600, MAME frame 900)

| Build | host | default @ bsnes-jg | default @ MAME | `+mos-a16` @ MAME | `+mos-a16` @ bsnes-jg | main soft-stack frame | ROM sha256 (default / a16) |
|---|---|---|---|---|---|---|---|
| `-O2`, stock layout | 0x80C4 | 0x80C4 | 0x80C4 | 0x80C4 | 0x80C4 | 0 B / 2 B | `fc1de17a…` / `ddd0449d…` |
| `-O3`, stock layout | 0x80C4 | **0x0000** | **0x0000** | **0x0000** | **0x0000** | 313 B / 353 B | `ffdc0ff1…` / `f467cfd8…` |
| `-O3`, reordered data | 0x80C4 | 0x80C4 | 0x80C4 | 0x80C4 | 0x80C4 | 313 B / 353 B | `622b8699…` / `8d7711db…` |

The four stock ROM hashes equal the report's. `-verify-machineinstrs` on the `-O3` precodegen module is clean in both modes (`logs/verify-*.log`). The host oracle is also clean at `-O3` under ASan and UBSan, both for `dither-sim.c` (0x80C4) and for the whole demo through the o2-large host harness (0x21FF and 0x15CC, equal to its `-O2` oracle; `logs/host.log`).

### Why it fails

| Step | Evidence |
|---|---|
| Low WRAM leaves 82 B for the soft stack: `.bss` + `.noinit` run from `$0200` to `$1FAD`, and `__stack = $2000` grows down into the same region. | `gate-*.log` layout lines |
| At `-O3` the pre-link inliner (`inline on (main)`, opt-bisect pass 4016 of 5057) inlines `dither_gate_crc` and its three unrolled `ds_dither` calls into `main`, so `main` gains six `[66 x i16]` arrays. At `-O2` the inliner rejects those three `ds_dither` call sites (cost 235–245 against threshold 225, per the remarks) and `ds_dither` stays a call. The `-O3` threshold is 250. | [`logs/pass-bisect.txt`](logs/pass-bisect.txt), `baseline/O3-default/main.prelink.ll` |
| `main` makes 7 indirect calls, so `MOSNonReentrant` never marks it `norecurse`/`nonreentrant`. Its frame goes on the soft stack, not the static stack. Stack coloring merges the arrays to 2 × 132 B, plus 49 B of spill slots: 313 B. | [`logs/nonreentrant.txt`](logs/nonreentrant.txt), `baseline/O3-default/main.frame-objects.txt` |
| `[$1EC7, $2000)` overlaps the last 98 B of `dither_gate_crc.out` and all 132 B of the `.noinit` static stack. | `gate-O3-default-stock.log` |
| The gate's `out[]` stores in row 21 overwrite main's spilled row counter (`SP+46`), the `y*11` accumulator (`SP+44`) and the row pointer's low byte (`SP+47`). The counter falls back to 2 (later 3), the loop climbs back into the slots about 9 rows later, and they are overwritten again. `y` never reaches 24, so `corpus_result` is never written. | [`logs/latch.log`](logs/latch.log) (tracer [`tools/jgxlatch.cpp`](tools/jgxlatch.cpp) at the outer-loop latch PC `$907A`) |

### Causal checks

- **Same code, other layout.** A linker script that differs only in data order ([`tools/reorder-ld.py`](tools/reorder-ld.py)) moves `dither_gate_crc.out`, `corpus_result`, `main.title` and `.noinit` below `main.a`. The frame then overlaps only the tail of `App.out`, which is unused until the first `dither_frame`. The instruction stream is identical after masking `$` operands (9573 and 8839 instructions, `logs/code-identity-*.log`), and every leg passes. The o2-large harness behaves the same way (`logs/harness-O3.log`): the stock layout gives 0x0000 after 3000 frames, the reordered layout gives 0x15CC.
- **Frame placement decides loud or silent.** Adding only `norecurse` to `main` in the `-O3` IR puts its frame on the static stack. The link then fails: `section '.noinit' will not fit in region 'ram': overflowed by 181 bytes` (`logs/norecurse.log`). The soft-stack frame needs the same space but no check sees it. The source-level equivalent, `__attribute__((nonreentrant)) int main(void)` in a copy of `dither.c`, gives the same link error at `-O3`, while `-O2` still builds and passes (`logs/nonreentrant-main.log`).
- **Codegen level is irrelevant.** The installed `llc` at `-O0`, `-O2` and `-O3` on the `-O3` IR all fail (`logs/llc-installed-*.log`). `-O0`'s 865 B frame covers `corpus_result` itself and writes 0x0302.

### Upstream

| Pipeline stage | Tool | Result |
|---|---|---|
| Codegen only: `-O3` precodegen IR from our clang, then link | upstream llc `06bc967d2668` | **FAIL** 0x0000, 315 B frame (`logs/llc-upstream-O3-on-O3ir.log`) |
| Same, `-O2` IR | upstream llc | PASS (`logs/llc-upstream-O2-on-O2ir.log`) |
| Full build: frontend, pre-link `-O3`, LTO, codegen | unpatched upstream clang `742d554bf080` with this repo's SNES SDK | **FAIL** 0x0000 on bsnes-jg and MAME, 314 B frame; the reordered layout passes on both (`logs/upstream-clang-*.log`, `logs/mame.log`) |

Not covered upstream: the SDK itself (libc, crt0, `link.ld`) is this repo's build. Upstream llvm-mos-sdk has no merged SNES platform, and none of its platform scripts reserves or checks a soft-stack size. The open SNES target [llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415) (head `e6a5c17c`) sets `__stack = 0x0200`, so its soft stack grows into page 1 with the hardware stack, also unchecked.

## Files

- `baseline/O3-default/`, `baseline/O3-a16/`: ROM, link map, frontend bitcode, pre-LTO bitcode (`prelink-lto-input.bc`), post-LTO `rom.sfc.0.5.precodegen.bc`, and `main` excerpts of both. `O3-default` also holds `main`'s post-PEI MIR (`main.post-pei.mir.xz`, from the real LTO link with `-mllvm -print-after=prologepilog -mllvm -filter-print-funcs=main`; ROM unchanged, `ffdc0ff1…`) and its frame objects.
- `contrast/O2-default/`: the same files for the passing `-O2` build.
- `logs/`: one log per run, named after its subcommand.
