# Multi-register register operands in GlobalISel inline asm (patch 0041)

**TODO entry:** `## Open` → *M2 / upstream* → `[T4] GlobalISel inline asm asserts on a
multi-register tied operand (20030222-1.c: asm("" : "=r"(i) : "0"(x)); 6 compilations)`, i.e.
order 4 of the [c-torture backend-failure triage](../upstream-pending-work.md#backend-failure-triage-gcc-c-torture-2026-09-23).

**No visible surface.** This is a codegen/IR-translator change; there is no UI, rendered page,
CLI output or generated document, so the plan carries no mockups.

---

## 1. The reported failure

`llc -O2 -mcpu=mosw65816` on the IR of `vendor/c-torture/execute/20030222-1.c` and
`vendor/c-torture/execute/pr52286.c` aborts in the IR translator:

```
llc: .../llvm/lib/CodeGen/GlobalISel/InlineAsmLowering.cpp:424:
  bool llvm::InlineAsmLowering::lowerInlineAsm(...) const:
  Assertion `NumOpRegs == 1 && "Wrong flag: multi-register tied operands "
  "not supported in GlobalISel inline asm"' failed.
```

Six c-torture compilations (2 files × `-O0`/`-O2`/`-Os`). Confirmed by the dispatching session to
be a latent limitation, not a regression: both files fail identically on the pre- and post-0040
compilers and sit in the "fails on both sides" bucket of the 1,656-file differential.

## 2. What the triage assumed, and what is actually true

The triage line says *"shape-specific (a simple `int` case compiles)"*. That is true but
misleading, and the reason matters for the design.

`MOSTargetLowering::getRegForInlineAsmConstraint` maps `"r"` to **`Imag16`** for `MVT::i16` and to
**`Imag8`** otherwise, and `getNumRegistersForInlineAsm` special-cases `i16` to 1 register. So on
MOS:

| C type | MVT | `"r"` register class | registers |
|---|---|---|---|
| `char` | `i8` | `Imag8` | 1 |
| `int` | `i16` | `Imag16` | 1 |
| `long` | `i32` | `Imag8` | **4** |
| `long long` | `i64` | `Imag8` | **8** |

A "simple `int` case" compiles because `int` is one register on MOS, not because the failing
shape is exotic. The two torture files use a `long`/`long long` value; `20030222-1.c`'s output is
an `int` but Clang widens the output type to the tied input's `i64`
(`%2 = call i64 asm "", "=r,0"(i64 %0)`), so the tied group is 8 registers.

**Three separate crash/bail sites, one root cause.** Generic `InlineAsmLowering` assumes every
register operand occupies exactly one register. Measured on
`build/0040-ra-build/bin/llc` (live vendor state, assertions on):

| Shape (MOS, `long` = `i32`) | Today |
|---|---|
| `asm("" : "=r"(l))` — direct output | `LLVM ERROR: unable to translate instruction: call` (soft bail: *"Output operands with multiple defining registers are not supported yet"*) |
| `asm("" :: "r"(l))` — plain input | **assert** `NumRegs == SourceRegs.size()` |
| `asm("" : "=r"(l) : "0"(l))` — tied | **assert** `NumOpRegs == 1` |

So the reported assertion is one of three faces of the same gap, and — decisively for the design —
**fixing only the tied assertion would be worthless**: the same asm also has a multi-register
*output*, which would then take the soft bail and still fail to compile. The item cannot be closed
by relaxing one assertion.

**Not MOS-specific.** The same assertion fires on **AArch64** for `i128` with `"r"`, at plain
`-O0` (AArch64 defaults to GlobalISel there), on `build/newton-postra-build/bin/llc`:

```
$ llc -O0 -mtriple=aarch64-linux-gnu aa.ll -o -
  Assertion `NumOpRegs == 1 && "Wrong flag: multi-register tied operands ..."' failed.
  ... 2. Running pass 'IRTranslator' on function '@tied128'
```

This is a generic `llvm/llvm-project` GlobalISel defect that MOS reaches for `long`.

## 3. The semantics to implement, pinned by SelectionDAG

SelectionDAG has handled this since forever, via `RegsForValue`. The reference output — same IR,
same target, `-global-isel=0` — defines exactly what to build:

```
; define i128 @tied128(i128 %x) { %1 = call i128 asm "", "=r,0"(i128 %x) ... }
INLINEASM &"", attdialect,
  regdef:GPR32common, def %4, def %5,
  reguse tiedto:$0, %6(tied-def 3), %7(tied-def 4)
```

and the assembly around it:

```
tied128:  mov  w8, w0          ; %6 <- bits  0..31   (least significant piece first)
          lsr  x9, x0, #32
          mov  w10, w9         ; %7 <- bits 32..63
          //APP … //NO_APP
          orr  x0, x8, x9, lsl #32   ; result = merge(def0 low, def1 high)
```

Four facts fall out, and they are the whole contract:

1. One flag word with `NumOperandRegisters = N` and `setMatchingOp(DefIdx)`, followed by N use
   registers, **each individually tied** to the corresponding def operand. `MachineInstr`
   already supports this: `findTiedOperandIdx` walks the inline-asm group descriptors and ties by
   index delta, which is the path SelectionDAG relies on. No MI-layer change is needed.
2. Piece order is **least-significant first** (little-endian). `getCopyToParts`/`getCopyFromParts`
   swap for a big-endian data layout.
3. The piece width is the operand's register class width; the value is **truncated** when it is
   wider than `N × pieceWidth` (AArch64 `i128` → 2 × 32 bits: the high half is simply dropped, the
   result's high half left undef) and extended when narrower.
4. The output side is the mirror image: merge the N defs least-significant-first into one wide
   value, then apply the existing truncate/extend-to-result-type logic.

## 4. Design

Add two small helpers to `llvm/lib/CodeGen/GlobalISel/InlineAsmLowering.cpp` and route the three
sites through them.

- **`buildMergeFromAsmRegs(...)`** — N register-class registers → one generic vreg of
  `LLT::scalar(N × pieceBits)`: copy each into a generic piece register, then
  `G_MERGE_VALUES` in operand order (`Regs[0]` = least significant).
- **`buildSplitToAsmRegs(...)`** — one value → N register-class registers: truncate/`G_ANYEXT`
  the source to `LLT::scalar(N × pieceBits)`, `G_UNMERGE_VALUES` it, copy piece *i* into
  `Regs[i]`.

Then:

- **Output** (`ResRegs` loop): when `OpInfo.Regs.size() > 1`, merge first and feed the merged wide
  register into the *existing* truncate / zero-extend / copy code unchanged. The existing
  single-register path is untouched.
- **Plain register input**: when `OpInfo.Regs.size() > 1`, split into the registers and add all N
  after one `Flag(RegUse, N)`; otherwise the existing `buildAnyextOrCopy` path, unchanged.
- **Tied input**: drop the `NumOpRegs == 1` assertion. Create N vregs in the def's register class,
  split the source into them, emit `Flag(RegUse, N).setMatchingOp(DefIdx)`, add the N registers and
  `tieOperands(DefRegIdx + i, UseIdx + i)` for each. `N == 1` reduces to exactly today's code.

**Guard rails — every unsupported shape becomes a soft `return false`, never an abort.** Both
assertions are removed and replaced by early `return false` with an `LLVM_DEBUG` reason, joining
the bail-out style the rest of the function already uses (which surfaces as
`unable to translate instruction: call`, a diagnostic, not a crash). The helpers bail on:

- a non-little-endian `DataLayout` (the piece order above is only proven for little-endian);
- a non-scalar source/result value (vectors, pointers, aggregates);
- pieces of unequal width, or a zero/odd total width;
- `GetOrCreateVRegs(value).size() != 1`.

So the change can only ever turn an abort into a diagnostic or into working code — it cannot make
a previously-compiling shape compile differently, because every new code path is behind
`Regs.size() > 1`, which today reaches an assert or a bail.

### The alternative rejected

*Replace the two assertions with the same soft `return false` the output path already uses, and
stop there* — a six-line, zero-risk diagnostic-only change. Rejected because it does not close the
item: the multi-register **output** in the very same statement still bails, so `20030222-1.c` and
`pr52286.c` remain uncompilable, only with a tidier message; and the semantics that make the real
fix risky are fully pinned down by the SelectionDAG reference above, so the risk is testable rather
than speculative.

## 5. Why a wrong turn is detectable here

The stated hazard is a *silent* inline-asm miscompile. Two properties make it loud instead:

- A symmetric ordering error (split reversed *and* merge reversed) cancels out in a round trip, so
  a round-trip test alone would not catch it. **`20030222-1.c` is exactly the asymmetric test** —
  it reads an `i64` in and takes the `int` low half out, and its own `main` aborts if it gets the
  high half. That is the same property the gcc test was written for ("we used to get it wrong on
  big-endian machines").
- Both torture files carry runtime checks and run under `dev/run.sh torture`'s four-way gate
  (host == default@MAME == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg).

## 6. Build

Upstream `dev/toolchain.sh` clones llvm-mos `main` **unpinned**, so `patches/llvm-mos/*.patch`
must apply to current `main`, which is newer than the local `vendor/llvm-mos` (8be0546, #563).
Current `main` (742d554, #590) already reworked this file (`emitInlineAsmError`, a per-operand
`RegClass`), so — as for 0037 — the patch is authored against the newer base and the local
`vendor/` tree is edited to match for the emulator gate.

- Development/validation build: `build/0041-inlineasm-{src,build}`, a copy of the
  `newton-postra-{src,build}` pair (newer llvm-mos base, patches 0011 + 0030–0038 committed,
  `LLVM_ENABLE_ASSERTIONS=ON`, `LLVM_TARGETS_TO_BUILD=X86;ARM;AArch64` + experimental MOS).
  Driven in the container with both directories bind-mounted at the paths its CMake cache was
  configured with, so nothing is reconfigured and the other agent's `newton-postra-*` pair is
  untouched:

  ```
  dev/container.sh \
    -v "$ROOT/build/0041-inlineasm-src:/work/build/register-exhaustion-src" \
    -v "$ROOT/build/0041-inlineasm-build:/work/build/newton-postra-build" \
    -- cmake --build /work/build/newton-postra-build --target llc --parallel 8
  ```

- `llc-before-0041` is the copied binary; `llc-0041` is the rebuild.
- Separately, the same edit goes into `/home/will/llvm-mos-65816/vendor/llvm-mos/` and the project
  toolchain is rebuilt with `dev/run.sh toolchain` for the corpus/emulator gate. `dev/run.sh
  toolchain` does **not** rebuild `build/llvm-mos/bin/llc`; build that target explicitly before
  trusting any lit run against it.

`InlineAsmLowering.cpp` and the two lit tests are outside `llvm/lib/Target/MOS/`, so `0041` needs
**no** `dev/regen-patch.sh` entry (`STANDALONE_MOSDIR` covers only the MOS directory and `TESTRELS`
is an explicit allow-list) — to be re-verified against the final file list.

## 7. Verification steps

1. `llc-before-0041` vs `llc-0041` on the new MOS lit test — FAIL before, PASS after, each RUN line.
2. Same for the new AArch64 GlobalISel lit test.
3. `20030222-1.c` and `pr52286.c` compiled end-to-end by the rebuilt project `mos-clang` at
   `-O0`/`-O2`/`-Os` × `mos6502` / `mosw65816` / `mosw65816 +mos-a16`, with
   `-mllvm -verify-machineinstrs`: 18 clean compilations.
4. Disassembly check that the tied group round-trips the *low* piece for `20030222-1.c`'s
   `ll_to_int` (the asymmetric case).
5. c-torture codegen differential, `llc-before-0041` vs `llc-0041` over the whole
   `vendor/c-torture/execute` corpus at `-O2`: expect *N* repaired, **0** newly failing, and every
   ok/ok pair byte-identical. (`build/0041-inlineasm-build/diff0041.sh`, copied from
   `build/0040-ra-build/diff0040.sh` and re-pointed; the original is not edited.)
6. MOS CodeGen + MC lit suites on `llc-0041`.
7. AArch64 + ARM + X86 CodeGen lit suites on `llc-0041` (generic change, cross-target reach).
8. Project toolchain rebuild from `vendor/` + `dev/run.sh corpus-a16` four-way emulator gate.
9. `dev/run.sh torture` over the two repaired files (runtime differential) — only if no other
   corpus/torture run is in flight.
10. `patches/llvm-mos/0041-*.patch` applies to a pristine current-`main` llvm-mos
    (`git apply --check` against `~/llvm-mos`), and is registered in `dev/toolchain.sh`.

## 8. Deliverables

- `llvm/lib/CodeGen/GlobalISel/InlineAsmLowering.cpp` (generic).
- `llvm/test/CodeGen/MOS/inline-asm-multi-register.ll`.
- `llvm/test/CodeGen/AArch64/GlobalISel/inline-asm-multi-register.ll`.
- `patches/llvm-mos/0041-llvm-gisel-inline-asm-multi-register.patch`, registered in
  `dev/toolchain.sh` after 0037.
- `docs/pr-preparations/2026-09-24/0041-validation.md` (shaped like the 0037 record).
- `docs/upstream-gisel-inline-asm-multi-register-pr.md` + a row in
  `docs/upstream-contribution-status.md`.
- Triage table row 4 and the `TODO.md` item body updated to done-style (tier marker untouched).

---

## 9. Verification (run 2026‑09‑24)

Binaries: `build/0041-inlineasm-build/llc-before-0041`
(`9e9a103ec0874e40531e2e51a707a650a81d2b032d699b2afd3f7dd1a2245fcf`) and `llc-0041`
(`38ae5c6aa8cc91e2fd61912cfae42252e68b1178afdcd4117489499d0d7d9660`); project toolchain
`build/llvm-mos-install/bin/clang-23`
(`532e6f2bb8490043a3585839acedcbd698618721d7951f8f9ccc0baa4533b4fd`).

**1. `llc-before-0041` vs `llc-0041` on the new MOS lit test — FAIL before, PASS after, each RUN line.**

```text
-- llc-before-0041 --
RUN 1: FAIL  -- llc -mtriple=mos -mcpu=mos6502 -O2 -stop-after=irtranslator < %s | FileCheck %s
RUN 2: FAIL  -- llc -mtriple=mos -mcpu=mos6502 -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM
RUN 3: FAIL  -- llc -mtriple=mos -mcpu=mos6502 -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM
-- llc-0041 --
RUN 1: PASS  -- llc -mtriple=mos -mcpu=mos6502 -O2 -stop-after=irtranslator < %s | FileCheck %s
RUN 2: PASS  -- llc -mtriple=mos -mcpu=mos6502 -O2 -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM
RUN 3: PASS  -- llc -mtriple=mos -mcpu=mos6502 -O0 -verify-machineinstrs < %s | FileCheck %s --check-prefix=ASM
```

**PASS.**

**2. Same for the new AArch64 GlobalISel lit test.**

```text
-- llc-before-0041 --
RUN 1: FAIL  -- llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 -stop-after=irtranslator < %s | FileCheck %s
RUN 2: FAIL  -- llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 < %s | FileCheck %s --check-prefix=ASM
-- llc-0041 --
RUN 1: PASS  -- llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 -stop-after=irtranslator < %s | FileCheck %s
RUN 2: PASS  -- llc -mtriple=aarch64-linux-gnu -global-isel -global-isel-abort=1 -O0 < %s | FileCheck %s --check-prefix=ASM
```

**PASS.** (These RUN lines were re-run after the test gained the `multi_reg_input` case moved out of
`arm64-fallback.ll`; the four affected tests then pass together — see step 7.)

**3. `20030222-1.c` and `pr52286.c` compiled end-to-end by the rebuilt project `mos-clang` at
`-O0`/`-O2`/`-Os` × `mos6502` / `mosw65816` / `mosw65816 +mos-a16`, with
`-mllvm -verify-machineinstrs`: 18 clean compilations.**

```text
PASS  20030222-1 -O0 mos6502            PASS  pr52286 -O0 mos6502
PASS  20030222-1 -O0 mosw65816          PASS  pr52286 -O0 mosw65816
PASS  20030222-1 -O0 mosw65816 +mos-a16 PASS  pr52286 -O0 mosw65816 +mos-a16
PASS  20030222-1 -O2 mos6502            PASS  pr52286 -O2 mos6502
PASS  20030222-1 -O2 mosw65816          PASS  pr52286 -O2 mosw65816
PASS  20030222-1 -O2 mosw65816 +mos-a16 PASS  pr52286 -O2 mosw65816 +mos-a16
PASS  20030222-1 -Os mos6502            PASS  pr52286 -Os mos6502
PASS  20030222-1 -Os mosw65816          PASS  pr52286 -Os mosw65816
PASS  20030222-1 -Os mosw65816 +mos-a16 PASS  pr52286 -Os mosw65816 +mos-a16
== 18 pass / 0 fail ==
```

**PASS.**

**4. Disassembly check that the tied group round-trips the *low* piece for `20030222-1.c`'s
`ll_to_int` (the asymmetric case).**

`llc-0041 -O2 -mcpu=mos6502` on the same shape (`i64` tied group, result read back as `i16`):

```text
ll_to_int:                              ; @ll_to_int
	sta	__rc10        ; A  = byte 0 of the long long argument
	stx	__rc11        ; X  = byte 1
	;APP
	;NO_APP
	lda	__rc10
	ldy	#0
	sta	(__rc8),y     ; low  byte of the int stored first
	iny
	lda	__rc11
	sta	(__rc8),y     ; high byte
	rts
```

Cross-checked on AArch64, where `$0` in the template names the operand's first register:

```text
; %r = call i128 asm "mov $0, #7", "=r"()
GlobalISel:   mov x0, #7 ; bfi x0, x8, #32, #32     -> the 7 lands in the LOW half
SelectionDAG: mov x8, #7 ; mov w8, w8 ; orr x0, x8, x9, lsl #32   -> same
```

**PASS.**

**5. c-torture codegen differential, `llc-before-0041` vs `llc-0041` over the whole
`vendor/c-torture/execute` corpus at `-O2`: expect *N* repaired, 0 newly failing, and every ok/ok
pair byte-identical.**

```text
== totals (O2) ==
   1385 SAME
    266 NO-IR
      4 line
      3 BOTH-FAIL
      2 REPAIRED
== repaired ==
20030222-1 REPAIRED rb=134
pr52286 REPAIRED rb=134
== broken ==
(none)
== changed ==
(none)
```

**PASS.** (`4 line` is bash's `Aborted (core dumped)` job notice leaking into the results file, not a
result; 1385 + 266 + 3 + 2 = 1,656 files. The 3 `BOTH-FAIL` are unrelated and pre-existing:
`20050604-1` and `20060420-1` are `<4 x s32> G_FADD` legalization, `multi-ix` is
`Stack pointer decrement too large: 40444`. `NO-IR` = files the pinned Clang rejects.)

**6. MOS CodeGen + MC lit suites on `llc-0041`.**

```text
Total Discovered Tests: 145
  Unsupported:   1 (0.69%)
  Passed     : 144 (99.31%)
```

**PASS.**

**7. AArch64 + ARM + X86 CodeGen lit suites on `llc-0041` (generic change, cross-target reach).**

First run, before the two affected upstream tests were updated:

```text
Failed Tests (2):
  LLVM :: CodeGen/AArch64/GlobalISel/arm64-fallback.ll
  LLVM :: CodeGen/AArch64/build-pair-isel.ll
Total Discovered Tests: 11461
  Passed           : 11436 (99.78%)
  Expectedly Failed:    23 (0.20%)
  Failed           :     2 (0.02%)
```

Both encode the limitation this patch removes: `arm64-fallback.ll` asserted that
`inline_asm_multi_reg_input` falls back (it no longer does — the only change in the whole fallback
set), and `build-pair-isel.ll` captured the SelectionDAG output that GlobalISel used to fall back
to. After updating them (drop the fallback case, split the RUN line into GlobalISel and
SelectionDAG, move an equivalent positive case into the new test):

```text
Total Discovered Tests: 11461
  Passed           : 11438 (99.80%)
  Expectedly Failed:    23 (0.20%)
```

**PASS** — 0 failures.

**8. Project toolchain rebuild from `vendor/` + `dev/run.sh corpus-a16` four-way emulator gate.**

Rebuild took (`clang-23` mtime advanced 03:22 → 04:34, size 124 828 136 → 124 831 104 bytes, and
`buildSplitToAsmRegs`/`buildMergeFromAsmRegs` are present in the binary).

```text
==> corpus-a16: expected.tsv  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg; settle=1000)
  arith      PASS   corpus_result=0xA9E9  8/16/32-bit integer ALU
  …
==> corpus-a16: 79/79 passed, 0 xfail
```

79 verdict rows, 0 FAIL, 0 XFAIL. **PASS.**

**9. `dev/run.sh torture` over the two repaired files (runtime differential).**

```text
==> torture-run: 2 test(s), -Os, explicit, default==+mos-a16==+mos-xy16 (MAME + bsnes-jg)
     20030222-1.c           PASS  all variants PASS (0x600D)
     pr52286.c              PASS  all variants PASS (0x600D)
==> torture-run: 2 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 2)
```

**PASS.** Both rows therefore move from `examples/65816/torture/unsupported.tsv` (bucketed
`link-other` with the assertion's crash banner) to `inscope.tsv`.

**10. `patches/llvm-mos/0041-*.patch` applies to a pristine current-`main` llvm-mos
(`git apply --check` against `~/llvm-mos`), and is registered in `dev/toolchain.sh`.**

```text
=== ~/llvm-mos HEAD file == 742d554 file? ===
IDENTICAL to ~/llvm-mos working tree
=== apply 0037 then 0041 onto pristine 742d554 ===
0037 applied
0041 APPLIES CLEANLY on main+0037
```

`dev/toolchain.sh` gains `apply_patch 0041-llvm-gisel-inline-asm-multi-register` after 0040.
No `dev/regen-patch.sh` entry is needed and none was added: `STANDALONE_MOSDIR` lists only patches
with `llvm/lib/Target/MOS/` hunks and `TESTRELS` is an explicit allow-list, and every file 0041
touches is outside that directory.

**PASS.**
