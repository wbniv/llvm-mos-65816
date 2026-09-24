# Patch 0041: multi-register register operands in GlobalISel inline asm

Found 2026‑09‑24 in the c-torture triage (order 4 in the
[triage table](../../upstream-pending-work.md#backend-failure-triage-gcc-c-torture-2026-09-23)):
`asm("" : "=r"(i) : "0"(x))` aborts the compiler in `InlineAsmLowering` for 6 compilations
(`20030222-1.c`, `pr52286.c` at `-O0`/`-O2`/`-Os`). [Plan](../../plans/2026-09-24-gisel-tied-inline-asm.md).

- [x] Root cause: generic `InlineAsmLowering` assumes every register operand occupies exactly one
  register. MOS maps `"r"` to `Imag16` for `i16` and to 8-bit `Imag8` otherwise, so a `long` needs
  four registers and a `long long` eight. The reported assertion (`NumOpRegs == 1`) is one of three
  faces of the gap: the **tied** input asserts, the **plain** input asserts on the older vendor base
  and soft-bails on current `main`, and the **output** soft-bails
  (*"Output operands with multiple defining registers are not supported yet"*). Relaxing the
  assertion alone is worthless — the same statement's output is equally multi-register, so both
  torture files would still fail to compile.
- [x] Layer: generic `InlineAsmLowering`, not a MOS hook. The assertion reproduces on **AArch64** at
  plain `-O0`, where GlobalISel is the default and `"r"` selects `GPR32common` for any non-64-bit
  type, so `i128` needs two registers.
- [x] Semantics pinned by SelectionDAG, not guessed: for the same IR, `llc -global-isel=0` emits one
  flag word carrying the register count plus `setMatchingOp`, followed by that many uses each tied to
  its def (`reguse tiedto:$0, %6(tied-def 3), %7(tied-def 4)`), with the value laid out least
  significant piece first. `MachineInstr::findTiedOperandIdx` already resolves inline-asm ties by
  operand-group index delta, so nothing below the lowering needed changing.
- [x] Fix: merge a multi-register output with `G_MERGE_VALUES` before the existing size adjustment;
  narrow/extend a multi-register input to the registers' combined width and split it with a shift and
  a truncate per piece (what `getCopyToParts` does); emit one `RegUse` flag with the def's register
  count and tie each use to its def. Both assertions are replaced by the soft bail-out the rest of
  the function uses, and the new paths bail (never assert) on a big-endian data layout, a non-scalar
  value, mixed register widths, or a value not in a single vreg.
- [x] `G_UNMERGE_VALUES` was tried first and rejected: AArch64 declares a scalar-to-scalar unmerge
  legal but cannot select it (`// TODO: Handle other unmerges into GPRs and from scalars to scalars`
  in `AArch64InstructionSelector::selectUnmergeValues`), so `tied128`/`in128` died at instruction
  selection at every `-O` level. The shift form works on both targets and leaves MOS assembly
  **byte-identical** to the unmerge form at `-O0` and `-O2`.
- [x] Tests: `llvm/test/CodeGen/MOS/inline-asm-multi-register.ll` (tied / plain input / output on
  `i32`, plus the `20030222-1.c` shape) and
  `llvm/test/CodeGen/AArch64/GlobalISel/inline-asm-multi-register.ll` (the same three forms on `i128`
  plus the early-clobber case moved out of `arm64-fallback.ll`).
- [x] Two existing AArch64 tests encoded the removed limitation and are updated in the same patch:
  `GlobalISel/arm64-fallback.ll` loses `inline_asm_multi_reg_input` (it no longer falls back), and
  `build-pair-isel.ll` gains a `-global-isel=0` RUN line so the SelectionDAG `BUILD_PAIR` coverage it
  was written for survives, alongside regenerated GlobalISel checks.
- [x] Patch `patches/llvm-mos/0041-llvm-gisel-inline-asm-multi-register.patch`, registered in
  `dev/toolchain.sh` after 0040. No `dev/regen-patch.sh` entry: every file it touches is outside
  `llvm/lib/Target/MOS/`, which is all `STANDALONE_MOSDIR` and 0002's mirror cover, and `TESTRELS` is
  an explicit allow-list (same treatment as 0037).
- [x] Suites, corpus differential, project toolchain rebuilt, emulator gate.

## Builds

| Name | Host directory | `llc` sha256 |
|---|---|---|
| before | `build/0041-inlineasm-build/llc-before-0041` | `9e9a103ec0874e40531e2e51a707a650a81d2b032d699b2afd3f7dd1a2245fcf` |
| after | `build/0041-inlineasm-build/llc-0041` | `38ae5c6aa8cc91e2fd61912cfae42252e68b1178afdcd4117489499d0d7d9660` |

`build/0041-inlineasm-{src,build}` is a copy of the `newton-postra-{src,build}` pair — llvm-mos
`742d554bf08042b8df93d791c335260fadd16643` (#590) with patches 0011 and 0030–0038 committed,
`CMAKE_BUILD_TYPE=Release`, `LLVM_ENABLE_ASSERTIONS=ON`,
`LLVM_TARGETS_TO_BUILD=X86;ARM;AArch64` plus experimental MOS. It is driven through
`dev/container.sh` with **both directories bind-mounted at the container paths its CMake cache was
configured with** (`/work/build/register-exhaustion-src` and `/work/build/newton-postra-build`), so
nothing is reconfigured and the original pair is never written to. Read a table row naming
`newton-postra-build` inside this build's logs as that mount, not as the other agent's directory.

Project toolchain: `build/llvm-mos-install/bin/clang-23`, sha256
`532e6f2bb8490043a3585839acedcbd698618721d7951f8f9ccc0baa4533b4fd`, rebuilt from
`vendor/llvm-mos` (base `8be0546`, #563) by `dev/run.sh toolchain` at 04:34 UTC.

## Results

| Check | Result |
|---|---|
| MOS test on `llc-before-0041` / `llc-0041`, each RUN line | FAIL ×3 / PASS ×3 |
| AArch64 test on `llc-before-0041` / `llc-0041`, each RUN line | FAIL ×2 / PASS ×2 |
| The 2 torture files at `-O0`/`-O2`/`-Os` × `mos6502` / `mosw65816` / `mosw65816 +mos-a16`, through the rebuilt `mos-clang` with `-verify-machineinstrs` | 18/18 clean |
| The same 2 files plus `mos.ll` at `-O0`/`-O2` × `mos6502` / `mos65c02` / `mosw65816` on `llc-0041` with the verifier | 18/18 clean |
| c-torture, all 1,656 `execute` files, IR through `llc -O2`, `llc-before-0041` vs `llc-0041` (`diff0041`) | 2 repaired (`20030222-1`, `pr52286`); 0 newly failing; 0 changed; 1,385 ok/ok pairs all byte-identical; 3 fail on both sides (`20050604-1`, `20060420-1`: `<4 x s32>` `G_FADD`; `multi-ix`: frame over 32 KiB); 266 had no IR (the frontend rejects them) |
| MOS CodeGen + MC, `llc-0041` | 145 tests: 144 pass, 1 unsupported, 0 fail |
| X86 + ARM + AArch64 CodeGen suites, `llc-0041` | 11,461 tests: 11,438 pass, 23 expectedly fail, **0 fail** |
| `dev/run.sh torture --tests 20030222-1.c pr52286.c` (four-way runtime gate) | 2 PASS, 0 FAIL, 0 SKIP, 0 XFAIL |
| `dev/run.sh corpus-a16` after the project toolchain rebuild | `79/79 passed, 0 xfail` — 79 verdict rows, 0 FAIL, 0 XFAIL (host == default == `+mos-a16` == `+mos-xy16` on MAME and bsnes-jg) |

`20030222-1.c` is the asymmetric case and the reason the runtime gate matters: it feeds a
`long long` through an eight-register tied group and reads the result back as the low `int`, and its
own `main` aborts if it gets the wrong half. A reversed piece order cancels out in a round trip but
not here. Both files now `PASS all variants PASS (0x600D)` — host == default@MAME ==
`+mos-a16`@MAME == `+mos-xy16`@MAME == `+mos-a16`@bsnes-jg — so they move from
`examples/65816/torture/unsupported.tsv` (bucketed `link-other` with the assertion's crash banner)
into `inscope.tsv`.

**The generator confirms the two moved rows.** They were first moved by hand, on the incorrect
assumption that re-running the filter would rewrite unrelated rows; it does not — it is idempotent.
`tools/torture_filter.py --opt=-Os` was therefore re-run over all 1,779 tests and diffed against the
committed manifests (`regen-tsv-0041.log`):

- `inscope.tsv`: **byte-identical** — 1,299 rows, including `20030222-1.c`, `pr52286.c` and the
  `ashrdi-1.c` row patch 0040 added.
- `unsupported.tsv`: identical 480 test names in identical order with identical buckets
  (`builtins-multifile` 55, `compile-error` 170, `dg-require-unsupported` 58, `link-other` 15,
  `region-overflow` 1, `undefined-symbol` 181), and both `link-other` rows for the two repaired
  tests correctly absent.

The committed files are kept rather than replaced, because the regenerated `unsupported.tsv` differs
in the **diagnostic column only**, on 136 rows, and only as an artifact of where it was run:
`_first()` truncates the raw diagnostic line with `ls[:200]` *before* `sanitize()` strips the repo
root, so the surviving text is `200 - len(FUZZ_ROOT) - …` characters. This run used a scratch root
104 characters long instead of the canonical 25, and 174 (the longest committed diagnostic) − 79 (the
root-length delta) = 95, which is exactly the length every differing regenerated row has. **This is
a real if minor reproducibility wart in the tool** — the third column of a committed manifest depends
on the absolute checkout path, which is what `sanitize()`'s own docstring ("so the committed manifest
is portable + deterministic") sets out to prevent. Not fixed here; flagged for whoever owns the
filter. It does not affect the scope decision, which is the column that matters and which matched
exactly.

The filter was run rooted at a scratch `FUZZ_ROOT` (symlinks to the shared `vendor/` and `build/`,
a copy of `_shim.c`) rather than in the shared checkout, so no tracked file outside this worktree
was written.

Piece order was checked directly rather than inferred. On AArch64, where `$0` in the asm template
names an operand's **first** register:

```text
; %r = call i128 asm "mov $0, #7", "=r"()
GlobalISel:      mov x0, #7 ; bfi x0, x8, #32, #32     -> the 7 lands in the LOW half
SelectionDAG:    mov x8, #7 ; orr x0, x8, x9, lsl #32  -> same
; call void asm "str $0, [sp, #-16]!", "r"(i128 %x)
GlobalISel and SelectionDAG emit identical assembly.
```

**Binary-to-patch correspondence.** After the table above was produced, a final comment pass changed
three comment lines — one in `InlineAsmLowering.cpp`
(`// We want to tie the input to the def registers that follow the flag.`, replacing a singular
"next operand") and two block comments in the AArch64 test, dropping historical narrative that
`dev/check-comment-history.py` rejects. The `.cpp` delta cannot affect codegen, so the differential
and the emulator gates stand. The AArch64 **test file** did change, so its RUN lines were re-run in
its final form against the same binaries: FAIL ×2 on `llc-before-0041`, PASS ×2 on `llc-0041`. A
scan of every added line in the final patch for the checker's history-narrative patterns reports 0
hits. The helper block is byte-identical in `build/0041-inlineasm-src` and in `vendor/llvm-mos`; the
73-line difference between the two copies of the file is entirely their different llvm-mos bases
(`emitInlineAsmError`, `OpInfo.RegClass`, `Tmp1Reg`/`LLT::scalar` spelling) and touches none of the
new code.

Artifacts under `build/0041-inlineasm-build/`: `diff0041.sh` / `diff0041/results-O2.txt` /
`diff0041-O2.log`, `lit-mos-0041.txt`, `lit-crosstarget-0041b.txt` (and the pre-test-update
`lit-crosstarget-0041.txt`, whose 2 failures are the two AArch64 tests this patch updates),
`build41*.log`, `toolchain-0041.log`, `torture-0041.log`, `corpus-a16-0041.log`.
The [llvm/llvm-project submission variant](0041-llvm-project.patch) carries the generic source
change and the three AArch64 test files. Current-main applicability remains to be checked before
submission, as for 0037.

Assisted-by: Claude Code CLI using Claude Opus 5 (1M context) (`claude-opus-5[1m]`, `high`
reasoning effort) for diagnosis, design, implementation, tests, and validation.
