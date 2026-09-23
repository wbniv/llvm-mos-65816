# Patch 0035: audit of Claude's analysis, patch, and PR draft

September 23, 2026. Reviewed the existing [validation record](0034-0035-validation.md),
[patch](../../../patches/llvm-mos/0035-clang-prefetch-int16-operands.patch),
[PR draft](../../upstream-clang-prefetch-int16-pr.md), builtin declaration,
Sema range checks, CodeGen, and emitted IR. The casts are correct. The analysis
understates the affected inputs, and the committed regression should cover the
wider-argument case before submission.

## Finding: this is not limited to 16-bit `int` targets

`__builtin_prefetch` has a variadic builtin prototype. Explicit options retain
their promoted integer types; they are not invariably C `int` expressions.
On x86-64, this valid source also produces an invalid intrinsic call:

```c
void f(char *p) { __builtin_prefetch(p, 1L, 2L); }
```

```llvm
call void @llvm.prefetch.p0(ptr %p, i64 1, i64 2, i32 1)
```

The same problem occurs with `long long` arguments on all four tested targets,
and with a locality expression such as `sizeof(char) + 1` when its promoted
type is not 32 bits. Conversely, `long` options already have the correct `i32`
type on the tested 16-bit-`int` targets.

The [intrinsic contract](https://llvm.org/docs/LangRef.html#llvm-prefetch-intrinsic)
requires `i32` options regardless of the C expression's width. `CreateIntCast`
handles both widening and narrowing, so the implementation already fixes the
broader defect. Sema restricts rw to 0–1 and locality to 0–3, making the unsigned
casts value-preserving for accepted constants.

Requested follow-up: add a committed x86-64 regression using `1L`/`2L` or
`1LL`/`2LL`, and the two-argument form with an explicit rw and default locality.
Update the new source/test comments to describe promoted integer expression
types, and remove the contradictory existing `FIXME` asking whether the
intrinsic operands should be C `int`. The PR draft and tracker now describe
the broader scope. No implementation change is required by this finding.

## Independent validation

The patch applies cleanly to pinned source
`742d554bf08042b8df93d791c335260fadd16643`. Its patched `CGBuiltin.cpp` is
byte-identical to the source used for Claude's saved frontend build.
The fixed frontend is `build/register-exhaustion-build/bin/clang`; the baseline
is `build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/clang`.
These checks use `-cc1 -emit-llvm`, isolating frontend emission from the driver
and MOS backend changes. This is not claimed as a newly built standalone Clang.

| Check | Result |
|---|---|
| Eight valid option forms × MOS, MSP430, AVR, x86-64 | 21 invalid baseline modules; all 32 patched modules pass the LLVM verifier |
| Eleven modules already valid on baseline | Patched IR byte-identical |
| Bundled regression on MSP430 | Baseline FileCheck fails; patched passes |
| Bundled regression's x86-64 plain-`int` control | Both pass |
| Existing address-space and poison-argument tests on x86-64 | Both pass before and after |
| Invalid rw, invalid locality, and nonconstant rw, all four targets | All three diagnostics preserved on both frontends |

The eight forms are omitted options, rw-only, explicit integer literals,
promoted `unsigned char`, enum constants, `long`, `long long`, and constant
expressions involving `sizeof`. All patched calls retain their expected values
and use `i32` for rw/locality/cache type. No other target's frontend suite is
claimed as covered by these focused tests.

To inspect the invalid baseline IR, the script uses Clang's
`-disable-llvm-verifier` during emission and then runs `opt -passes=verify
-disable-output` explicitly on every module from both compilers. Normal cc1
verification also rejects the baseline's explicit 16-bit arguments before
writing output. The saved invalid IR is test evidence, not accepted output.

Artifacts: `build/0035-review-audit/`, including `apply-check/`, `probe.py`,
`results.json`, the C inputs, emitted modules, and verifier logs. Hashes:

- Patch: `093b92af2d23f44f5463333f12b5e46a9e7142f602f09a62b60d0c17ed96ac1f`.
- Baseline frontend: `b48000f510c8769ea48709c09d985c32d3933e64856ace67fc8fe861b30497aa`.
- Fixed frontend: `17c93a0c91adcb9fd2f7f95eb90ec35f8342f71f8db1d7667bfd9557c7dc31f2`.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for independent review, expanded frontend validation, and
corrections to the analysis and submission evidence.
