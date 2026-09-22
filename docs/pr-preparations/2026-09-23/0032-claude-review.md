# Patch 0032 — independent review (Claude)

Review of Codex's fix for register-named assembly symbols, 2026‑09‑23, on the
pinned llvm-mos revision `742d554bf08042b8df93d791c335260fadd16643`. Scope: the
C++ change and its vendor variant, the three tests, the PR draft, and the
recorded validation. Not maintainer feedback.

**Verdict: ready to post, no changes needed.** The mechanism is the standard
one (X86's `populateReservedIdentifiers` fills the same `MCAsmInfo` set the
same way), the set is consulted case-insensitively upstream
(`MCAsmInfo::isValidUnquotedName` lowercases the query, and the vendor variant
lowercases in its override), and the parser is untouched, so quoted operands
were already accepted. Beyond Codex's evidence I probed the shapes it had not
covered and ran the print/assemble round trip over the whole corpus rather than
the 61 files: all clean. One pre-existing defect surfaced next to the patch and
is filed separately.

## What I verified myself

| Claim | How | Result |
|---|---|---|
| Register-named *functions* are quoted in call and branch operands | C probe with functions `c`, `v`, `p`, `z` and globals `X`, `sP`, `Rc0`, `nz`, array `a`; `llc -S` on the 0032 build | `jsr "c"`, `jsr "v"`, `jsr "p"`, `jsr "z"`, `lda "sP"`, `adc "X"`, `adc "Rc0"`, `adc "nz"`, `sbc "a",x`; `.globl "X"` / `"X":` / `.size "X", 1` |
| Uppercase and mixed-case spellings are quoted | same probe | yes (`"X"`, `"sP"`, `"Rc0"`) |
| Quoted symbols inside address modifiers round-trip | probe with zero-page globals `y`, `rs1[]` and 16-bit `s`, `c`, on `mos6502` and `mosw65816` | `lda mos8("y")`, `lda mos8("rs1"),x`, `ldx #mos16lo("c")`, `ldx #mos16hi("c")`, `ldx "s"+1`; the assembler accepts all of them |
| The parser is unchanged | the quoted `.s` through the **pre-0032** `llvm-mc` | identical object |
| Object identity | `llvm-mc` output vs `llc -filetype=obj` for the probes | identical (except the zero-page case below, which is pre-existing) |
| Suites, assertion build, stacked on 0030+0031+0011 | `test/CodeGen/MOS` + `test/MC/MOS` | 135 pass, 1 unsupported, 0 fail (the three new tests included) |
| Applies to upstream | `git apply --check` on the pinned tree and on the newer `~/llvm-mos` clone | clean |

## Full-corpus round trip

gcc `c-torture/execute`, 1,390 files × `-O0/-O2/-Os` (4,170 compilations,
79 of which `llc` itself rejects, pre-existing): `llc -S` on the 0032 build,
reassembled with the 0032 `llvm-mc`, compared with `llc -filetype=obj`.

| | |
|---|---|
| assembler failures | **0** (61 among the previously compared pairs before 0032, all register-name collisions) |
| compilations whose text changed with 0032 | 1,078, quoting only |
| reassembled object identical to the direct object | 3,978 |
| reassembled object differs | 113, all **symbol-table order only**: every non-symbol-table section's bytes, every relocation (by offset, type, symbol name, addend) and the sorted symbol set are identical |

So the patch makes every generated assembly file in the corpus reassemble, and
changes nothing in any object. The 113 are the same benign `.symtab` ordering
Codex saw in two of the 61.

## Pre-existing defect found next to it (not 0032's)

For `rs1[i]` with `rs1` in `.zp.bss`, the direct object encodes `lda abs,x`
(`0xBD`, `R_MOS_ADDR16`) but the printer emits `lda mos8("rs1"),x`, which
reassembles as `lda zp,x` (`0xB5`, `R_MOS_ADDR8`): one byte shorter and, at the
page edge, semantically different (`zp,x` wraps). Same result with
non-register names and with the pristine `llc` and pristine integrated
assembler, so it is an upstream printer-versus-object-emitter disagreement
about zero-page-indexed symbol operands. Filed as a `[T4]` TODO item; it does
not appear in the torture corpus (no zero-page globals there).

## Notes on the draft

Accurate. Two things worth adding, done: the full-corpus round-trip figures
above, and my attribution.

Artifacts under `build/0030-claude-review/`: `roundtrip.py`,
`roundtrip-results.json`, `roundtrip-nonidentical.json`, `rt/` (assembly of
every compilation), `llc-0032`, `llvm-mc-0032`, `llc-before-0032`,
`llvm-mc-before-0032`, `lit-0032.json`; probes in the session scratchpad
(`probe.c`, `probe2.c`, `probe2c.c` and their outputs).
