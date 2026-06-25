# Validating the `coalesce-rotate-Ac` fix — more tests, minimality, and no-regression evidence

**Companion to** the root-cause record
[`2026-06-25-default8-65816-loopfold-miscompile.md`](2026-06-25-default8-65816-loopfold-miscompile.md)
and the fix plan
[`../plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md`](../plans/2026-06-25-default8-loopfold-miscompile-reduce-and-fix.md).
The fix is `patches/llvm-mos/0010-coalesce-rotate-ac.patch`
(`MOSRegisterInfo::shouldCoalesce`); upstream PR body
[`../upstream-coalesce-rotate-ac-pr.md`](../upstream-coalesce-rotate-ac-pr.md).

This doc answers three questions the fix raises:
1. **How do we test this more — produce other programs that fail under the old code but are correct under the new?**
2. **Is the patch the minimum required?**
3. **Does it break anything else?**

## 0. The bug in one paragraph

Default-8bit (no `+mos-a16`) `mosw65816` codegen. The register coalescer merges two
shift/rotate-referenced values into the **A-only `Ac`** class (`def Ac : MOSReg8Class<(add A)>`).
A rotate (`ASL`/`LSR`/`ROL`/`ROR`) can only touch the accumulator, so an `Ac` value is pinned to
`A` for its whole live range. In an inlined CRC16 bit loop the high byte is loop-carried across the
bit-15 test (`lda __rc2`, which clobbers `A`); pinned to A-only, it has nowhere to go on the skip
(no-XOR) path and is stranded in `Y` while the back-edge `ROL` reads a **stale `A`** — a silent
miscompile (`-verify-machineinstrs` / `-verify-coalescing` both clean). Fix: refuse that coalesce.

## 1. Producing more fail-before / pass-after programs

### Method — isolate the coalescer change with two backends, one frontend

The fix lives entirely in codegen (the coalescer), so the cleanest differential keeps the
**frontend output fixed** and swaps only the backend:

1. `mos-clang --config mos-snes.cfg -Os -Wl,--lto-emit-llvm` → a self-contained **post-LTO
   bitcode** module (the same shape as the canonical `pl.ll` repro; small programs must go through
   `--lto-emit-llvm`, not `-S -emit-llvm`, so the runtime is folded in and the native object links
   without the #320 far-datalayout clash).
2. **baseline** `llc` (fork tree with the fix reverted) → `.o`; **fixed** `llc` (committed) → `.o`.
3. Link each through `mos-clang --config` → SNES ROM; read `corpus_result` on bsnes-jg.
4. **host reference**: the same `compute()` built with the native `cc`.
5. A program is **fail-before / pass-after** iff `baseline ≠ host` **and** `fixed == host`.

Harness + generator: `/tmp/crc-fuzz/{run.sh, gen}` (reproducible; the two `llc`s are
`build/llvm-mos-asserts/bin/llc` with the fix on/off). The generator emits CRC folds parameterised
by **poly** (`0x1021/0x8005/0xA001/0x8408`), **direction** (left `ROL` / reflected right `ROR`),
**interleaved-accumulator count** (1–4, the register-pressure knob) and **indexing** (array-indexed
vs local byte).

### Results

**Two complementary sweeps:**

**(a) Synthetic single-function CRC fuzzer — 96 programs, 0 reproduced.** A standalone `compute()`
(even with 4 interleaved accumulators + a volatile-MMIO write loop + a separate rolling-hash loop,
across 4 polys × 2 directions × indexing) compiles to **identical correct** results on both backends.
This is itself a finding: the bug is **narrow** — a bare CRC, however parameterised, does not push the
coalescer to pick the `Ac` join. It needs the broader register pressure of a real program with the
fold embedded among other live state.

**(b) Mutations of the known-reproducing `min.c` — 4/4 reproduced, each confirmed correct after.**
Varying the CRC **polynomial** in the embedded `zoom_crc16_byte` (the real demo's fold context) keeps
the trigger and gives genuine fail-before / pass-after programs. The "pass-after" value is verified
**correct** against the independent `+mos-a16` oracle (which the bug never affected):

| program | baseline (old) | fixed (new) | `+mos-a16` oracle | verdict |
|---|---|---|---|---|
| `min.c` poly `0x1021` | `0x7BCB` | `0x860E` | `0x860E` | **fail-before / pass-after** ✓ |
| `min.c` poly `0x8005` | `0x019D` | `0x5966` | `0x5966` | **fail-before / pass-after** ✓ |
| `min.c` poly `0x8408` | `0x0B00` | `0xE4F0` | `0xE4F0` | **fail-before / pass-after** ✓ |
| `min.c` poly `0xA001` | `0x50AD` | `0x6B5D` | `0x6B5D` | **fail-before / pass-after** ✓ |

So the most reliable way to mint more triggering programs is to **mutate a known-reproducing one**
(`min.c` — the 43-line cvise repro) rather than synthesise from scratch: the surrounding pressure that
opens the `Ac` join is preserved.

### Why it takes pressure (and the general recipe for a triggering program)

A bare single CRC loop does **not** reproduce — its high byte is allocated to memory or a GPR and
never coalesced into `Ac`. The trigger needs **enough simultaneously-live values that the allocator
coalesces the rotate-carried high byte into A-only `Ac`** and that value is **loop-carried across an
A-clobber** (the bit test). The reliable recipe, confirmed by the reproducing cases:
- an inlined rotate-through-carry bit loop (CRC, or any `x = cond ? (x<<1)^k : (x<<1)` over 8 steps),
- whose carried value is 16-bit (so the high byte is a separate rotate operand), and
- enough surrounding live state (multiple interleaved accumulators, or the demo's MMIO/array
  pressure) to push the coalescer to pick the `Ac` join.

## 2. Is the patch minimal?

Tested four conditions on the canonical `pl.ll` repro (env-toggled in `shouldCoalesce`, one rebuild),
measuring: does it fix (`zoom_crc` `0x7BCB`→`0x860E`), how many joins it refuses, and the resulting
`.text` size:

| condition | zoom_crc | joins refused | `.text` | verdict |
|---|---|---|---|---|
| _none_ (baseline) | `0x7BCB` ✗ | 0 | 0x589 | the bug |
| **`NewRC==Ac` ∧ both operands rotate-referenced** (committed) | **`0x860E` ✓** | **30** | **0x5b7** | **correct + minimal** |
| `NewRC==Ac` ∧ *either* operand rotate-referenced | `0x454E` ✗ | 63 | 0x5a0 | **wrong** — over-refusing introduces a *different* miscompile |
| both rotate-referenced, *drop* `NewRC==Ac` | `0x860E` ✓ | 74 | 0x5b7 | correct but refuses 2.5× more for no gain |
| `NewRC==Ac` only, *drop* rotate check | `0x860E` ✓ | 477 | 0x6fd | correct but +372 B bloat (refuses ~all `Ac` joins) |

Each clause is load-bearing:
- **`both` (not `either`)** is required for *correctness*: relaxing to `either` refuses an extra join
  that *should* happen and yields a new wrong value (`0x454E`). The fix must be precise, not just
  conservative — over-refusal is not "safe".
- **`NewRC==Ac`** is required for *minimality*: it is exactly the A-only narrowing class; dropping it
  refuses 74 vs 30 joins with identical output.
- **the rotate check** is required to avoid pessimisation: dropping it refuses 477 joins (+372 B).

So the committed condition is the tightest that is both correct and non-pessimising.

## 3. Does it break anything else?

The fix is generic default-8bit codegen, so the differential gates (host == default == `+mos-a16`,
and on the torture set also `== +mos-xy16`) are the regression guard:

| gate | result |
|---|---|
| `dev/run.sh corpus` | **7/7 PASS** (host == default == `+mos-a16`) |
| `dev/run.sh torture` (c-torture) | **30/30 PASS, 0 FAIL** (default == a16 == xy16, MAME + bsnes-jg) |
| `dev/run.sh fuzz --gen csmith` seeds 1–60 | **54/60 PASS, 0 mismatch / 0 crash / 0 error** (6 benign `corpus_result GC'd` skips) |
| `dev/run.sh fuzz --gen csmith` seeds 101–200 | **88/100 PASS, 0 mismatch / 0 crash / 0 error** (12 benign skips) — **142/160 total, 0 mismatch** |
| a16 micro-tests (`a16`, `a16loop`, `a16loadfold`) | **PASS** (unaffected — fix is default-8bit) |
| xy16 micro-tests (`xy16basic`, `xy16ops`, `xy16spill`) | **PASS** (unaffected) |
| `-verify-machineinstrs` (fixed codegen, `pl.ll`) | **clean** |
| the original repro `dev/loopfold-repro.sh loop` | **PASS** `0xF56C` (was FAIL `0xE60E`) |

The fix only ever **refuses** a coalesce for the precise `NewRC==Ac` ∧ both-operands-rotate-referenced
class; every other join is untouched, so no allocation outside that class can change. Note the
minimality table's caution: *over*-refusing (the `either` variant) is **not** automatically safe — it
introduced a different miscompile (`0x454E`) by suppressing a join that should happen. That is exactly
why the condition is pinned to the narrowest set that fixes the bug, and why the regression suite
(corpus / torture / csmith) is the acceptance gate rather than the refusal count alone. It is carried as
a **separate** patch `0010` (not folded into the `+mos-a16` patch `0002`), so the #321 feature stack is
untouched.

## Reproduce

```sh
# baseline llc (fix reverted) — built once into /tmp/llc-baseline:
#   revert MOSRegisterInfo.cpp -> ninja -C build/llvm-mos-asserts llc -> cp to /tmp/llc-baseline
# fixed llc = build/llvm-mos-asserts/bin/llc (committed)
bash /tmp/crc-fuzz/run.sh          # the CRC differential fuzzer (Section 1)
dev/loopfold-repro.sh loop         # the original repro -> PASS 0xF56C
dev/run.sh corpus && dev/run.sh torture && dev/run.sh fuzz --gen csmith 60
```
