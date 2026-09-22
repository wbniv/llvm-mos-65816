# Patch 0032: register-named symbols in generated assembly

Validated September 23, 2026. The standalone fix is prepared and the local
compiler is rebuilt and installed. Independent review: [0032-claude-review.md](0032-claude-review.md) (ready to post). Publication remains.

- Upstream patch: [0032-mos-quote-register-named-symbols.patch](../../../patches/llvm-mos/0032-mos-quote-register-named-symbols.patch).
- [Proposed PR description](../../upstream-register-named-symbols-pr.md).
- [Reduced C input](../../investigations/repro/upstream-issues-2026-09-23/register-named-globals.c).
- Saved commands, binaries, assembly, objects, logs, and JSON evidence:
  `build/asm-symbol-roundtrip/` (ignored build artifacts).

## Reduction and cause

The smallest rejected assembly is `lda x` (also `lda s` or `lda y`). A C
producer is `unsigned char x; unsigned char f(void) { return x; }`.

`MOSAsmParser::tryParseRegisterToken` recognizes register spellings before a
general address expression. A quoted identifier does not match those tokens,
so `lda "x"` is valid. `MOSInstPrinter` delegates symbol printing to the MC
expression printer, but `MOSMCAsmInfo` does not reserve register spellings.
The printer therefore emits the ambiguous unquoted identifier.

The defect includes silent misassembly: `asl "a"` initially selects a memory
instruction (provisional opcode `0x06` with an address fixup), but unpatched
printing emits `asl a`, which reassembles as accumulator opcode `0x0a`.
Object relaxation can select absolute memory opcode `0x0e`; the regression
compares complete objects so it checks the final result as well as printing.

The fix marks register spellings as reserved identifiers. A `StringSet` owns
the lowercase strings referenced by `MCAsmInfo`'s reserved-name set. Both
prefixed names and aliases are covered. The parser itself is unchanged;
existing ambiguous `.s` files need to be regenerated or have symbol uses quoted.

## 6502 versus 65816

These results were measured with the unpatched and patched MC binaries:

| Input | 6502 | 65816 |
|---|---|---|
| `lda s`, `lda x`, `lda y` | Rejected | Rejected |
| `lda "x",x` | Unpatched printing loses quotes; reassembly fails | Same |
| `asl "a"` | Unpatched round trip selects the accumulator opcode | Same |
| `lda "s",s` | Unsupported addressing mode | Unpatched printing loses quotes; reassembly fails |
| `lda ("s",s),y` | Unsupported addressing mode | Already reassembles correctly: parentheses select expression parsing |

The patch preserves quoted symbols in every supported form above. Bare
register operands, including `asl a`, remain valid. Evidence:
`cpu-comparison.json` and the two new MC tests.

## Standalone upstream validation

Base: `742d554bf08042b8df93d791c335260fadd16643`. The isolated source was
restored to this revision before applying 0032. Assertions are enabled.
The copied build's `MOSInstrInfo.cpp` and `MOSRegisterInfo.cpp` objects were
rebuilt from the pristine source, excluding the copy-expansion and scavenger
changes from this standalone result.

| Check | Result |
|---|---|
| Fresh patch application and comparison with tested files | Exact match for all six files |
| MOS CodeGen suite | 84 pass, one existing unsupported |
| MOS MC suite | 48 pass |
| New regression files against unpatched output | All three fail their FileCheck expectations |
| Reduced C, two CPUs × `-O0` / `-O2` / `-Os` | Six verifier passes; all direct/reassembled objects identical |
| Generated register-name sweep | 2,622 spellings on each CPU; direct/reassembled objects identical |

The sweep collects register names from the generated assembler matcher, adds
operand-token aliases and uppercase variants, and exercises each as a quoted
memory symbol. Evidence: `lit-0032.json`, `baseline-tests.json`,
`reduced-upstream.json`, and `all-register-spellings.json`.

## The original 61 corpus failures

These are the exact 61 file/optimization pairs excluded from the 0031 size
comparison. The baseline is the saved assertion-enabled 0030+0031 compiler.
The candidate adds only 0032 to that stack. `corpus.py` recompiles the original
C files to IR with the pinned upstream Clang, runs both backends with
`-verify-machineinstrs`, and compares assembly and objects.

- All 61 regenerated baseline assemblies match the previously saved files.
- All 61 baselines fail reassembly; all 61 candidates succeed.
- All backend runs pass verification. Direct objects are byte-identical in
  all 61 before/after comparisons.
- Assembly differs only in symbol quoting and the resulting comment alignment.
- 59 reassembled objects are byte-identical to direct output. For
  `pr42721.O0` and `pr47337.O0`, only unreferenced `__do_*` runtime symbols are
  reordered in `.symtab`. Sorting the symbol-table records makes the entire
  files byte-identical; section bytes and relocation records are unchanged.

Evidence: `corpus-results.json`, `corpus.log`, and per-case artifacts under
`corpus/`. This replay holds 0030/0031 constant; 0032 does not depend on them.

## Local integration

The vendor compiler at `8be0546128a55e78c63ca571d466aa72a782cd36`
predates upstream's reserved-identifier API and still has
the virtual `MCAsmInfo::isValidUnquotedName` hook. The separate
[vendor compatibility patch](../../../patches/llvm-mos/0032-mos-quote-register-named-symbols-vendor.patch)
uses that hook and the same lowercase name set. It carries the same tests.
The upstream submission uses only the main 0032 patch.

`dev/toolchain.sh` applies the vendor variant; `dev/regen-patch.sh` lists it
among standalone MOS patches so regenerating 0002 does not absorb it. The
vendor source is patched; `clang`, `llc`, and `llvm-mc` were rebuilt, and the
Clang and MC components installed into `build/llvm-mos-install`.

The installed compiler passes 12 verifier/assembly/object comparisons: plain
6502, plain 65816, local accumulator-16, and local accumulator/index-16 modes,
each at `-O0`, `-O2`, and `-Os`. This platform-stack evidence is separate from
the standalone upstream validation. See `integration.py` and `integration.json`.

The local MC suite plus the two affected CodeGen tests reports 46 passes and
one existing failure in `addressing-modes-65816.s`: `lda addr24` expects
automatic long addressing but selects an absolute instruction. The saved
pre-change Clang integrated assembler produces a byte-identical object and
fails the same check. This is unrelated to symbol quoting and remains outside
0032. Evidence: `lit-vendor.json`, `vendor-existing-failure.json`, and
`addressing-modes-65816.baseline.log`.

## Artifact identity

| Artifact | SHA-256 |
|---|---|
| Upstream patch | `1dad44009485886f8902d75af69a73226bab28336d62d150b141b8731ed77895` |
| Vendor patch | `61c74a6936ebdf9ff472c7857c68b8ee69a83ee14d86f831fccd7bd35e526bca` |
| `llc-0032` | `b4387c7983e2a8e907983417c2db19f5586625884098c62e729a2a4f78ae081b` |
| `llvm-mc-0032` | `8da6f103b900b0b5d7b12748bc6d301a326c247ab6b3520e85e30fc4175c46f6` |
| `llc-0030-0031-0032` | `1520492786ecdb6487a4389719fcee78cd03c6d80fd7d6602680131b85970d97` |

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`,
`xhigh` reasoning effort) for diagnosis, implementation, tests, validation,
local integration, and documentation.
