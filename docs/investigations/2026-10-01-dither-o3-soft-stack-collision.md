# Dither `-O3` never writes its gate CRC: the soft stack overwrites static data

**Status 2026‑10‑01: confirmed, root-caused, not fixed.** Canonical record: [`snes-soft-stack-static-data-collision`](../defects/snes-soft-stack-static-data-collision.json). Evidence: [`evidence/2026-10-01-snes-soft-stack-collision/`](../defects/evidence/2026-10-01-snes-soft-stack-collision/README.md). Original sighting: the [o2-large `-O2` speed-gate run](../defects/evidence/2026-09-30-native-width-pressure-sets/o2-large/README.md#observed-not-acted-on) (`o3-dither/report.txt`).

Attribution: Claude Code 2.1.286, model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort (T4 agent definition; the effort is not readable from session metadata); session [session_01Skyq488smgqkyyzHrcCX7F](https://claude.ai/code/session_01Skyq488smgqkyyzHrcCX7F).

## Verdict

**There is no miscompile.** The `-O3` code is correct: the same instruction stream, with only its data moved, passes on bsnes-jg and MAME in both modes. The program does not fit.

At `-O3`, `main` needs a 313‑byte soft-stack frame (353 B with `+mos-a16`). The SNES platform leaves 82 B between the end of static data (`__heap_start = $1FAE`) and the top of the soft stack (`__stack = $2000`). Nothing checks that the two meet, so the frame silently overlaps the gate's own output buffer and the static stack. The gate loop then overwrites its own spilled loop counter and livelocks.

The demo source is clean. It has no undefined behaviour that `-O3` could exploit: the host oracle and the whole demo pass at `gcc -O3` under ASan and UBSan with the `-O2` results, and the layout experiment rules out a code-dependent cause.

## Mechanism

1. **Memory budget.** `.bss` + `.noinit` occupy `$0200-$1FAD`: `App` 6,747 B, `TitleLayer` 140 B, `corpus_result`, `dither_gate_crc.out` 576 B, and a 132‑byte static stack. The soft stack starts at `$2000` and grows down into the same `ram` region (`platforms/snes/link.ld`: "soft stack grows down from $2000; bss/heap up").
2. **`-O3` moves 264 B of arrays into `main`.** The pre-link inliner at the `-O3` threshold of 250 inlines `dither_gate_crc` and its three fully unrolled `ds_dither(24, 24, …)` calls into `main`. That is opt-bisect pass 4016, `inline on (main)`. At `-O2` the same three call sites cost 235–245 against a threshold of 225, so `ds_dither` stays out of line with a static-stack frame. Each inlined copy brings `ecur[66]` and `enext[66]`; stack coloring merges them into two 132‑byte slots.
3. **`main` cannot use the static stack.** `MOSNonReentrant` treats every indirect call as able to reach every externally callable function. `main` has external linkage and makes 7 indirect calls (the inlined `Display`/`Drawable` dispatch), so it is never marked `norecurse`, and `MOSFrameLowering::usesStaticStack` puts its frame on the soft stack. This holds at `-O2` too, where the frame is empty.
4. **Collision.** The frame is `[$1EC7, $2000)`: 49 B of spill slots, then `enext`, then `ecur`. It overlaps `dither_gate_crc.out[478..575]` and the whole `.noinit` static stack.
5. **Livelock.** While dithering row 21, the stores to `out[522]`, `out[524]` and `out[525]` overwrite the spilled row counter `y` (`SP+46`), the `y*11` accumulator (`SP+44`) and the row pointer's low byte (`SP+47`). The counter falls back to 2 or 3, and the loop climbs back into the slots about 9 rows later. `y` never reaches 24, and the `corpus_result` store after the gate never executes. The tracer at the outer-loop latch shows this directly (`logs/latch.log`).

Placing the frame on the static stack makes the same program fail the link with `.noinit … overflowed by 181 bytes`. The soft stack's identical need is invisible to the linker. The same class of fault was fixed on 2026‑09‑25 in rdiff ([`e3bb5a62`](https://github.com/wbniv/llvm-mos-65816/commit/e3bb5a6259e638c9c9a5aaed95c160d43221096b)) by shrinking that demo, with no record or guard.

## Where it reproduces

| Toolchain | `-O2` | `-O3` |
|---|---|---|
| Installed project toolchain (`clang-23` `254624ba…`), default and `+mos-a16`, bsnes-jg and MAME | PASS | FAIL (0x0000) |
| Upstream llc `06bc967d2668` (`2f5c1768…`) on our precodegen IR | PASS | FAIL |
| Unpatched upstream clang `742d554bf080` (`b48000f5…`), full build with our SNES SDK, bsnes-jg and MAME | not run | FAIL; the reordered layout passes |

The upstream coverage is complete for the compiler: frontend, pre-link `-O3`, LTO and codegen. It does not cover the SDK, because upstream llvm-mos-sdk has no SNES platform. The llc variants in the pressure-set work, the `-O0`/`-O2`/`-O3` codegen replays and `-verify-machineinstrs` (clean) all agree that the backend output is not the cause.

## Proposed fix (not implemented)

The defect is a missing resource contract on our SNES platform, not a code-generation bug. None of `0002`, the #320/#321 patches or generic LLVM is at fault.

1. **Detect it in the gate (test infrastructure, ours).** The bsnes-jg probe already hooks every instruction. It could record the lowest soft stack pointer (`__rc0/__rc1`) and fail when it falls below `__heap_start`. That would catch every silent overlap in every demo and configuration, rdiff's included, without guessing a reserve size. Location: `dev/jgxcheck.cpp`, or a `jgxcycles`-style probe in the differential scripts.
2. **Make it a link-time contract (SDK platform, ours; relevant to the upstream SNES target).** Reserve soft-stack space in `platforms/snes*/link.ld` with `PROVIDE(__soft_stack_min = N)` and assert `__heap_start + __soft_stack_min <= __stack`, following the near-code budget contract in `c9cfa6a0`. A fixed reserve only catches frames larger than N. Any N of 83 B or more also rejects today's passing `-O2` dither build, which has 82 B of headroom, so choosing N is a policy call. The open upstream SNES target, [llvm-mos-sdk#415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415) (head `e6a5c17c`), has no such check either: its `link.ld` sets `__stack = 0x0200`, so there the soft stack grows down into page 1, which also holds the hardware stack. The contract belongs in whichever SNES target is reconciled (TODO: "Reconcile SNES platform work with llvm-mos-sdk#415").
3. **Upstream enhancement, optional (MOS backend, `MOSNonReentrant.cpp`).** An indirect call can reach `main` only if its address is taken. Excluding a non-address-taken `main` from the calls-external → external-calling edge would put `main`'s frame on the static stack, and this failure would become the loud `.noinit` overflow above. That is a design discussion for llvm-mos, since C permits calling `main`. It is not a correctness bug in the present analysis, which is conservative.
4. **Per-program guard available today (source).** Declaring `__attribute__((nonreentrant)) int main(void)` asserts that `main` is not re-entered and puts its frame on the static stack. `dither.c` then still builds and passes at `-O2`, and fails loudly at `-O3` with the same 181‑byte `.noinit` overflow (`logs/nonreentrant-main.log`). This protects only `main`'s own frame, and only in programs that adopt it.
5. **The demo.** Whichever guard is chosen, `dither.c` at `-O3` needs more low WRAM than the platform has: 231 B more with the frame on the soft stack, and 181 B more with it on the static stack. It fits only if static data shrinks, for example `dither_gate_crc.out`, or `ds_dither` stays out of line. That is a change to the demo's resource use, not to its gate.

**Decision needed.** Choose among 1, 2 and 4 (or a combination), and whether dither at `-O3` should fit or be declared unsupported. That is a platform policy choice for the user.
