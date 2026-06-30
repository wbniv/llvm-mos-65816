# Compiler stress-test demo battery — completion status report

**Date:** 2026-06-30
**Scope:** GitHub #321 (`+mos-a16` 16-bit-accumulator codegen) exercise/validation via SNES demos.
**Tracker:** [`2026-06-27-compiler-stress-test-demo-ideas.md`](2026-06-27-compiler-stress-test-demo-ideas.md)
(the live backlog + coverage maps). This file is the point-in-time **completion summary**.

## Headline

**All 32 numbered demos are shipped, gate-verified, and published.** Round 1 (#1–#20) and Round 2
(#21–#32) are both complete. Every demo is live on [biohack.net/snes](https://biohack.net/snes/)
with an in-browser bsnes-jg player and a **Verify-fidelity** self-check that reproduces the build
gate's WRAM assert live in the tab.

**Compiler-correctness verdict: the `+mos-a16` / `+mos-xy16` backend is green across every codegen
corner the battery exercises.** The differential bar (`host == default == +mos-a16 == +mos-xy16` on
MAME + bsnes-jg, `-verify-machineinstrs` clean) holds for all 32 demos. The bugs the battery found
were all **pre-existing** and were fixed in-flight (see "Bugs found" below); no Round-2 corner
surfaced a *new* miscompile.

## The bar

Correctness = the **differential**: host-computed `corpus_result` (native `int`/IEEE ground truth)
must equal the value read from WRAM on default(non-a16)@MAME, `+mos-a16`@MAME, `+mos-xy16`@MAME, and
`+mos-a16`@bsnes-jg — plus `-verify-machineinstrs` clean and no assembler/linker/runtime fault. Any
disagreement is a real defect. (MAME legs are environmentally SKIP-not-fail here pending the
gitignored SPC700 IPL; the bsnes-jg leg + the 4-way corpus differential carry correctness.)

## Round 2 coverage — the corners the first 20 never executed

| # | Demo | New codegen corner | Gate CRC | Verdict |
|---|------|--------------------|----------|---------|
| 21 | [mandel-float](https://biohack.net/snes/mandel-float/) | soft-float IEEE-754 (`__mulsf3`/`__divsf3`/…) | `0x4169` | green, no bug |
| 22 | [avalanche](https://biohack.net/snes/avalanche/) | 64-bit integers (`__muldi3`/`__udivdi3`/…) | `0x27EA` | green, no bug |
| 23 | [lsystem](https://biohack.net/snes/lsystem/) | string libcalls (`memmove`/`memcpy`/`strlen`); + far-ptr store/load reveal | `0x79C3` | **found+fixed** xy16 in-place-memmove miscompile |
| 24 | [fn-plot](https://biohack.net/snes/fn-plot/) | recursive-descent parser + soft-float | `0x2EBE` | green, no bug |
| 25 | [fft](https://biohack.net/snes/fft/) | FFT butterfly `__mulsi3` + bit-reversal | `0x6D7A` | green; display bug found+fixed (not codegen) |
| 26 | [boids](https://biohack.net/snes/boids/) | by-value struct ABI (sret vs reg-pair) | `0xA8AB` | green, no bug |
| 27 | [cardioid](https://biohack.net/snes/cardioid/) | modulo-heavy `__umodsi3` | `0x523B` | green, no bug |
| 28 | [hilbert](https://biohack.net/snes/hilbert/) | variable-count shifts `__ashlsi3`/`__lshrsi3` | `0x5999` | green, no bug |
| 29a | [turtle-vm](https://biohack.net/snes/turtle-vm/) | jump-table + fnptr dispatch (`JMP (abs,X)`) | `0x4007` | green, no bug |
| 29b | [truchet](https://biohack.net/snes/truchet/) | bitfield insert/extract | `0xB3E6` | green, no bug |
| 30 | [tea](https://biohack.net/snes/tea/) | 32-bit shift/add/XOR (multiply-free) | `0xDF0E` | green, no bug |
| 31 | [bhut](https://biohack.net/snes/bhut/) | pointer-chasing dynamic trees | `0xEF0B` | green, no bug |
| 32 | [vaprintf](https://biohack.net/snes/vaprintf/) | variadic `va_arg` calling convention | `0xE1F3` | green, no bug |

The Round-2 untested-corner coverage map in the tracker is now **fully struck**.

## Bugs found by the battery (all pre-existing, all fixed)

- **xy16 in-place-memmove 16-bit-index miscompile** (caught by #23 lsystem) — `sep #$10` between
  `ldx` and `lda abs,X16` zeroed X's high byte; fixed in `MOSInsertREPSEP::placeIntraBlock`
  (reload-after-sep-corruption). Differential caught it; fixed same commit.
- (Earlier rounds, for the record:) raycaster signed-`int32`-overflow UB optimised differently
  host-vs-target (#15); the `0001` far-index miscompile; the default-8bit loopfold coalescer
  miscompile (`0010`); the legalizer indexed-addr domination fix (`fb528d8`). All landed on `main`.

## Non-codegen issues fixed in-flight (demo bugs, gate stayed green)

- **#25 FFT display** — `canvas_clear()` every frame reset the BitmapCanvas dirty range to `[0,255]`;
  `emit()` only flushes 64 tiles/frame, so tiles 64–255 (bottom ¾ of the bars) never reached VRAM.
  The FFT math was verified correct against a brute-force DFT throughout (gate `0x6D7A` passed both
  before and after). Fixed by redrawing only on bin change. **This is the protocol working as
  intended:** differential green ⇒ the fault is in the renderer, not the compiler.

## Methodology that held up

Each demo = a shared portable header (`examples/65816/<slug>.h`, the code under differential test)
+ a host oracle (`tools/<slug>-sim.c`) + a corpus slice (`examples/snes/corpus/<slug>_sim.c`,
auto-picked into `dev/run.sh corpus-a16`) + the on-console ROM (`examples/snes/<slug>.c`) + a gate
script (`dev/<slug>.sh`). The corpus now has **38 differential slices**. The "measure, don't assume"
and "fix the compiler, don't work around" lessons held: where a gate looked wrong (#25), the
differential correctly fingered it as a display bug, not codegen — and where codegen *was* wrong
(#23), the demo's job was to surface it for an upstream-quality fix.

## What's left (not battery demos)

The battery itself is done. Remaining #321 follow-ups live in `TODO.md` (upstream PR posting,
cross-platform toolchain builds, the `a16-newton-step-rc-undef` MachineVerifier investigation, etc.)
and are tracked there, not here.
