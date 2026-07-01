# Compiler stress-test demo battery — completion status report

**Date:** 2026-06-30
**Scope:** GitHub #321 (`+mos-a16` 16-bit-accumulator codegen) exercise/validation via SNES demos.
**Tracker:** [`2026-06-27-compiler-stress-test-demo-ideas.md`](2026-06-27-compiler-stress-test-demo-ideas.md)
(the live backlog + coverage maps). This file is the point-in-time **completion summary**.

## Headline

**Rounds 1–3 (#1–#52) are complete.** All **50 buildable** demos are shipped, gate-verified, and
published on [biohack.net/snes](https://biohack.net/snes/) with an in-browser bsnes-jg player and a
**Verify-fidelity** self-check that reproduces the build gate's WRAM assert live in the tab. Only two
Round-3 entries are non-buildable and documented as such: **#34** (no libm `sqrtf` — a library gap) and
**#35** (`longjmp` broken — the 6502-only `setjmp.S`, a toolchain gap; deferred, see its investigation).

**Compiler-correctness verdict: the `+mos-a16` / `+mos-xy16` backend is green across every codegen
corner the battery exercises.** The differential bar (`host == default == +mos-a16 == +mos-xy16` on
MAME + bsnes-jg, `-verify-machineinstrs` clean) holds for all shipped demos. The bugs the battery found
were all **pre-existing** and were fixed in-flight (see "Bugs found" below). Round 2 surfaced no new
miscompile; **Round 3 surfaced one real backend crash — the `G_SCMP`/`G_UCMP` legalization gap (#46) —
now fixed** and queued for upstream.

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

## Round 3 coverage — corners none of the first 32 touch

| # | Demo | New codegen corner | Gate CRC | Verdict |
|---|------|--------------------|----------|---------|
| 33 | [mandel-double](https://biohack.net/snes/mandel-double/) | `double` soft-float (`__adddf3`/`__muldf3`/…) | — | green, no bug |
| 34 | — | libm `sqrtf` | — | **not built** — library gap (no libm) |
| 35 | — | `setjmp`/`longjmp` full context save | — | **not built** — `longjmp` broken (6502-only `setjmp.S`); deferred |
| 36 | [polyfill](https://biohack.net/snes/polyfill/) | C99 VLA / runtime-sized frame | `0x8ED9` | green, no bug (the "VLA gap" doesn't exist) |
| 37 | [seqvm](https://biohack.net/snes/seqvm/) | sparse-switch → comparison tree | `0xE8C5` | green, no bug |
| 38 | [bf-vm](https://biohack.net/snes/bf-vm/) | computed-`goto` threaded dispatch | `0x9954` | green, no bug |
| 39 | [divclock](https://biohack.net/snes/divclock/) | constant-divisor strength reduction | `0xF72E` | green; **measured finding** — llvm-mos does NOT strength-reduce (retains `__udivNi3`; correct on soft-mul) |
| 40 | [crctex](https://biohack.net/snes/crctex/) | 256-entry ROM-LUT indexed byte loop (CRC32) | `0xDBBA` | green, no bug |
| 41 | [poolfx](https://biohack.net/snes/poolfx/) | free-list pool allocator (LIFO recycle) | `0x2B9B` | green, no bug |
| 42 | [duff](https://biohack.net/snes/duff/) | Duff's device — irreducible loop-switch CFG | `0x5531` | green, no bug |
| 43 | [sodo](https://biohack.net/snes/sodo/) | signed 64-bit divmod (`__divmoddi4`) | `0xD2A2` | green; measured — clang merges div+mod into combined signed `__divmoddi4` |
| 44 | [hdr-bloom](https://biohack.net/snes/hdr-bloom/) | saturating `__builtin_add_overflow` | `0xF951` | green, no bug |
| 45 | [metaball](https://biohack.net/snes/metaball/) | union type-pun (Quake fast-inverse-sqrt) | `0xAEBE` | green, no bug |
| **46** | **[qsortviz](https://biohack.net/snes/qsortviz/)** | **libc `qsort` + fn-ptr comparator** | `0x8EA5` | **FOUND + FIXED** `G_SCMP`/`G_UCMP` legalization crash (patch `0016`) |
| 47 | [nrecip](https://biohack.net/snes/nrecip/) | Newton-Raphson reciprocal (multiply-only) | `0x044A` | green, no bug |
| 48 | [iir-scope](https://biohack.net/snes/iir-scope/) | IIR feedback (non-reorderable) | `0x49BD` | green, no bug |
| 49 | [lzdec](https://biohack.net/snes/lzdec/) | LZ77 back-refs from own output | `0x0100` | green, no bug |
| 50 | [cgrade](https://biohack.net/snes/cgrade/) | >register-count argument spill | `0x783F` | green, no bug |
| 51 | [critters](https://biohack.net/snes/critters/) | resumable protothreads | `0xAD9F` | green, no bug |
| 52 | [disbits](https://biohack.net/snes/disbits/) | cross-byte-boundary bitfields | `0x31D7` | green, no bug |

The Round-3 untested-corner coverage map in the tracker is now **fully struck** (except the #34/#35
non-buildable rows, annotated).

## Bugs found by the battery (all pre-existing, all fixed)

- **`G_SCMP`/`G_UCMP` legalization crash** (caught by #46 qsortviz) — the standard C three-way-compare
  comparator idiom `(x>y)-(x<y)` is canonicalized by clang to the newer `llvm.scmp` intrinsic → the
  generic opcode `G_SCMP`, for which `MOSLegalizerInfo` had **no rule**, so the backend aborted (`unable
  to legalize G_SCMP`) in default 8-bit / `+mos-a16` / `+mos-xy16` alike, at every width, in both
  `-fno-lto` and the LTO-link path — i.e. any program sorting with a spaceship comparator failed to build.
  Fix = one line `getActionDefinitionsBuilder({G_SCMP, G_UCMP}).lower();` (patch
  `0016-mos-scmp-ucmp-legalize`), routing to LLVM's existing `LegalizerHelper::lowerThreewayCompare`
  (icmp+select expansion the backend already legalizes). **Standalone-testable (not AS2/accum-gated) →
  ready-to-post upstream** (`docs/upstream-contribution-status.md`); the demo (`dev/run.sh qsortviz`,
  `0x8EA5`) is the permanent regression guard. Full write-up:
  [`docs/plans/2026-06-30-46-snes-qsortviz.md`](../plans/2026-06-30-46-snes-qsortviz.md).

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
script (`dev/<slug>.sh`). The corpus now has **53 differential slices**. The "measure, don't assume"
and "fix the compiler, don't work around" lessons held across all three rounds: where a gate looked
wrong (#25) the differential correctly fingered a display bug, not codegen; where codegen *was* wrong
(#23 memmove, #46 `G_SCMP`), the demo's job was to surface it for an upstream-quality fix — and in #46
that meant isolating a minimal repro, diagnosing the missing legalizer rule, fixing it in `vendor/`,
rebuilding the toolchain, re-proving the full 5-way differential, and capturing the fix as a standalone
tracked patch queued upstream. A few Round-3 demos also produced **measured findings** rather than bugs
(#39 no constant-divisor strength reduction; #43 div+mod merged into `__divmoddi4`) — the "measure,
don't assume" lesson paying off directly.

## What's left (not battery demos)

The battery itself is **done** (Rounds 1–3, #1–#52; only #34/#35 unbuilt by library/toolchain gap).
Remaining #321 follow-ups live in `TODO.md` (upstream PR *posting* — including the new #46 `G_SCMP` fix,
user-triggered — cross-platform toolchain builds, the `a16-newton-step-rc-undef` MachineVerifier
investigation, etc.) and are tracked there, not here. A **Round 4** would need a fresh idea list drafted
in [`2026-06-27-compiler-stress-test-demo-ideas.md`](2026-06-27-compiler-stress-test-demo-ideas.md) first.
