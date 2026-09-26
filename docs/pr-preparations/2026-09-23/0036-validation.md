# Patch 0036: zero-page indexed globals

Prepared September 23, 2026. [Patch](../../../patches/llvm-mos/0036-mos-zero-page-indexed-globals.patch)
and [PR draft](../../upstream-zero-page-indexed-globals-pr.md). Not posted;
[independently reviewed](0036-claude-review.md): ready to post. The patch applies to pinned upstream
`742d554bf08042b8df93d791c335260fadd16643` without other patches.

## Intended addressing form

The backend's existing `canUseZeroPageIdx` contract assumes a zero-page global
fits wholly within zero page. Valid accesses into that object therefore use
the compact indexed form whenever the CPU provides one. An arbitrary integer
base does not carry this guarantee: adding the index can cross the page.

`lowerOperand` classifies both address-space-1 globals and explicit zero-page
sections as `MO_ZEROPAGE`, producing `mos8(...)` and an `R_MOS_ADDR8` fixup.
The indexed-opcode predicate only classified the address space. This selected
an absolute opcode with a one-byte fixup in direct objects, while the printed
operand selected a zero-page opcode upon reassembly. No valid-C runtime
counterexample was established; the demonstrated defect is inconsistent
instruction selection and size.

The fix adds `MOS::isZeroPageSectionName` to the predicate, resolving aliases
to their aliasee object. It also corrects `STAbsIdx`'s eligibility check from
operand 0 (value) to operand 1 (address). The store defect affects
address-space-1 globals as well as section-placed globals. Accumulator accesses
indexed by Y remain absolute on 6502/65816, which provide no zero-page,Y form.

The original [C reduction](../../investigations/repro/upstream-issues-2026-09-23/zero-page-indexed-symbol.c)
and [0032 audit](0032-review-audit.md) remain the discovery record. Symbol
quoting is independent of this change. Numbers 0034 and 0035 were assigned to
concurrently prepared prefetch fixes; this patch is 0036.

## Standalone validation

Baseline backend: `build/0030-claude-review/llc-pristine-assert`.
Frontend: `build/upstream-reference/742d554bf08042b8df93d791c335260fadd16643/bin/clang`.
Candidate: `build/asm-symbol-work` / `build/asm-symbol-build`, assertions enabled.
Earlier 0030/0031/0032 source changes were removed from this isolated build
before rebuilding; this validation uses 0036 alone.

| Check | Result |
|---|---|
| Apply to materialized pristine upstream source | Clean; applied files exactly match tested source |
| Patch SHA-256 | `0f59ed316257a987aa7a0b56ef0da3f2abfd23ce313f6b55cf025f0c6ea051ad` |
| Three new regressions, pristine backend | All three produce unequal direct/reassembled objects |
| Three new regressions, candidate | All pass, including instruction-byte checks and complete-object comparisons |
| Full MOS CodeGen suite | 86 pass, one unsupported, zero failures |
| Full MOS MC suite | 46 pass, zero failures |
| C matrix, zero-page sections | 27 baseline mismatches; zero candidate mismatches |
| C matrix, ordinary-section controls | 18 byte-identical baseline/candidate direct objects; round trips also identical |

The MIR tests exercise LDA, LDX, LDY, STA, ADC, SBC, AND, EOR, ORA, CMP, ASL,
LSR, ROL, ROR, INC, DEC, and STZ. They cover `.zp.bss`, `.zeropage.data`,
`.directpage`, an alias, address space 1, positive/negative symbol offsets,
ordinary globals, the nonmatching `.zprefix` name, a numeric absolute address,
and accumulator Y-indexed accesses. The common instruction test round-trips
on `mos6502` and `mosw65816`; STZ uses `mos65c02`. The LLVM IR test verifies
the full pipeline for an indexed C-style array read and write.

The C matrix contains five sections (`.zp.bss`, `.zeropage.data`, `.directpage`,
`.zprefix`, `.data`) × three CPUs (`mos6502`, `mos65c02`, `mosw65816`) × three
frontend optimization levels (`-O0`, `-O2`, `-Os`). Each source contains an array
read and write; the value precedes the index in the write's argument list to
exercise STA indexed by X. IR is generated separately for each CPU, preserving
the correct `target-cpu` attributes. `llc` uses `-O0` for `-O0` IR and `-O2`
for both optimized IR variants, always with `-verify-machineinstrs`.

Artifacts under `build/zp-indexed-roundtrip/`:

- `lit.json`: complete standalone CodeGen/MC results.
- `validate.py`, `validation.json`: baseline/candidate regressions and 45-case C
  matrix, with assembly and both object outputs alongside them.
- `apply-check/`, `provenance.json`: pristine application and source checks.
- `local-lit.json`, `local.py`, `local-matrix.json`: local integration checks.
- `numeric-modifier-baseline.json`: separate parser finding below.

The build runs inside `llvm-mos-65816-dev`. The isolated build's configured
paths require mounting `build/asm-symbol-work` at
`/work/build/register-exhaustion-src` and `build/asm-symbol-build` at
`/work/build/0029-cross-target-build`, in addition to the repository at `/work`.
Run `python3 /work/build/register-exhaustion-src/llvm/utils/lit/lit.py -q -j2`
on `/work/build/0029-cross-target-build/test/{CodeGen,MC}/MOS` for the suites.
The two matrix scripts only need the repository mount.

## Local integration

The same patch applies to `vendor/llvm-mos` without adaptation; reverse-apply
checks pass. `dev/toolchain.sh` carries it after the standalone symbol-quoting
patch, and `dev/regen-patch.sh` excludes it from the mirrored feature patch.
The local `clang` and `llc` were rebuilt, and `install-clang` completed. All
three new regressions pass on this release build as well.

The installed compiler also passes 36 C cases: three zero-page sections ×
`-O0`/`-O2`/`-Os` × stock 6502, stock 65816, `+mos-a16`, and `+mos-xy16`.
Each verifies cleanly and has byte-identical direct/reassembled objects. These
local width-mode checks are separate from the upstream PR evidence.
No emulator run or full c-torture differential is claimed for this patch.

## Separate constant-modifier defect

Numeric controls exposed another pre-existing parser problem, reproduced with
the unpatched assembler. The [standalone assembly input](../../investigations/repro/upstream-issues-2026-09-23/explicit-address-width.s)
contains:

| Assembly | Observed bytes | Required absolute,X bytes |
|---|---|---|
| `lda mos16(240),x` | `B5 F0` | `BD F0 00` |
| `lda mos16(4660),x` | `B5 34` | `BD 34 12` |
| `lda 4660,x` | `BD 34 12` | `BD 34 12` |

`MOSOperand::isImmInRange` handles a positive constant inside a modifier by
checking its value against the modifier's width, without also checking the
candidate operand's narrower range. Thus an explicitly 16-bit address can
match a zero-page instruction, even truncating `4660` to `0x34`. Address-context
`mos16` is parsed as `VK_ADDR16`, so the special `Imm16` guard does not prevent
this. This also defeats the existing `wrapAbsoluteIdxBase` protection for small
integer bases. It needs a separate assembler-width fix and tests; 0036 changes
neither that parser nor the handling of integer bases.

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`, `xhigh`
reasoning effort) for investigation, implementation, validation, and the
follow-up audit of the independent review.

**Review complete:** [Claude review](0036-claude-review.md) and
[Codex follow-up audit](0036-review-audit.md). No implementation revision requested;
validation counts corrected. Published SNES demo evidence is included in the
PR with direct links, per Will's clarification; the restriction concerns
premature SNES code/config submission.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`,
`high` reasoning effort) for independent review and integration validation.
