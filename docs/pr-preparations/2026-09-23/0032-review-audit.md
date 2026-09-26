# Audit of Claude's review of patch 0032

September 23, 2026. Reviewed the [independent review](0032-claude-review.md),
both patch variants, the proposed PR description, the full-corpus runner and
saved results, the frozen binaries, and the scratchpad probes.

**Verdict: no implementation defect found in 0032.** Claude's conclusion about
the fix holds. The PR evidence and the separate zero-page defect report needed
corrections; those are now reflected in the draft, review, and trackers.
The two patch files are unchanged.

## Findings and corrections

1. **The full-corpus baseline was not 61 assembly failures.** That number came
   from the earlier set of 435 changed copy-expansion pairs. Reassembling every
   saved baseline output establishes **821 failures among 4,091 emitted files**,
   all repaired by 0032. The PR draft now distinguishes that full result from
   the earlier 61-case replay.
2. **The 79 backend failures must remain visible.** Of 1,390 frontend-accepted
   files at three optimization levels, 4,170 reach the backend and 4,091 emit
   assembly. Zero assembler failures applies to those emitted files. The full
   runner also omits `-verify-machineinstrs`; verifier evidence comes from the
   separate suites and targeted runs. The draft now states these limits and
   identifies the copy-expansion/scavenger changes held constant in this run.
3. **The zero-page defect's direct relocation was reported incorrectly.** Both
   objects use `R_MOS_ADDR8`. Direct output has opcode `0xBD` (absolute indexed),
   while reassembly has `0xB5` (zero-page indexed). The discrepancy is real and
   predates 0032, but the different page-wrap rules alone do not prove a
   valid-C runtime miscompile. The TODO and review now preserve that distinction.
4. **The saved probe IR was CPU-specific.** All three scratchpad IR files have
   `"target-cpu"="mos6502"` on their functions. Reusing them with a 65816 command
   line does not establish a consistent 65816 pipeline. I regenerated each
   probe from C separately for each CPU. Function-name quoting and the separate
   zero-page mismatch reproduce with matching frontend/backend/assembler CPUs.

Application to the local newer clone was independently checked at
`c44aaa95aa724ea45a24357eb04483f03c9edb95`. This is a local revision check, not
a fresh query of remote upstream `main`; the trackers now say so.

## Counts and object comparisons

The saved full-corpus JSON contains 1,656 attempted source files: 266 are
rejected by the frontend at each level, leaving 1,390 accepted files.
The frozen baseline is byte-identical to the preceding 0011 differential's
candidate. All 4,091 saved baseline assemblies match that earlier run's hashes,
and the 79 failed file/optimization pairs match its failure set exactly.

| Optimization | Backend failures | Emitted assembly | Baseline assembler failures | Patched assembler failures |
|---|---:|---:|---:|---:|
| `-O0` | 25 | 1,365 | 284 | 0 |
| `-O2` | 29 | 1,361 | 269 | 0 |
| `-Os` | 25 | 1,365 | 268 | 0 |
| Total | 79 | 4,091 | 821 | 0 |

I inspected all 4,091 saved assembly pairs and independently confirmed the
1,078 changed pairs differ only in identifier quotes and comment alignment.
The other 3,013 are byte-identical. Of those 1,078 changed pairs, 821 baseline
assemblies fail; the remaining 257 assemble to byte-identical objects before
and after the quoting change. The corpus does not add a silent-opcode-change
example; the focused `asl "a"` regression covers that failure mode.

The saved full-run results report 3,978 byte-identical direct/reassembled
objects and 113 nonidentical objects. I regenerated **all 113** from C using
the frozen baseline and candidate tools, with explicit exit-status checks:

- Regenerated candidate assembly matches every saved assembly exactly.
- Direct baseline and candidate objects are byte-identical in all 113.
- The pre-0032 assembler accepts the quoted output and produces the same object
  as the patched assembler in all 113.
- Only `.symtab` bytes differ between direct and reassembled output. Masking
  those bytes makes the entire objects identical, including ELF headers and
  section metadata. Every other section's contents, symbol values after sorting, and
  relocations decoded by offset/type/symbol name/addend are identical.

These replays independently validate the classification in Claude's
`roundtrip-nonidentical.json`. I did not regenerate all 3,978 already-identical
direct objects; their count comes from the saved full-run results.

## Code, tests, and probes

The current upstream patch still has SHA-256
`1dad44009485886f8902d75af69a73226bab28336d62d150b141b8731ed77895`.
The lowercase name storage has the lifetime required by the non-owning
reserved-identifier entries. Register aliases and prefixed names are covered,
and the vendor implementation uses its older virtual hook correctly. No
parser changes or dependency on the other fixes are introduced.

The recorded standalone suite remains 84 CodeGen passes, 48 MC passes, and one
unsupported test. Claude's saved stacked-suite JSON contains 87 CodeGen passes,
48 MC passes, and the same unsupported test: 135 passes with 0011, 0030, and
0031 also present. These are different configurations, not conflicting counts.

Fresh CPU-specific versions of the call/case probe pass MachineVerifier and
produce byte-identical direct/reassembled objects on both `mos6502` and
`mosw65816`, including when using the pre-0032 assembler. The modifier probe
parses correctly; its indexed zero-page access retains the unrelated mismatch.

The [minimal non-register-name zero-page input](../../investigations/repro/upstream-issues-2026-09-23/zero-page-indexed-symbol.c)
reproduces that mismatch with both pristine and 0032-only backends on both CPUs.
All four combinations verify, emit `0xBD` directly and `0xB5` through assembly,
and use `R_MOS_ADDR8` in both objects. Determining the intended addressing
contract and fixing this separate discrepancy remain future work.

**Follow-up, September 23:** that investigation is complete in
[patch 0036](0036-validation.md). The whole-object zero-page contract permits
the compact form; section-aware opcode selection and the corrected store
address check repair all 27 C-case mismatches. The fix is installed and awaits
independent review. A separate numeric `mos16(constant)` parser-width defect
remains open.

## Reproduction artifacts

Audit scripts and outputs are under `build/0032-review-audit/`:

- `audit-assembly.py`, `baseline-assembly.json`: all 4,091 baseline assemblies.
- `accepted-baseline.py`, `accepted-baseline.json`: the 257 accepted changed pairs.
- `replay.py`, `replay.json`, `replay/`: all 113 object-difference replays.
- `probes-fresh.json`, `*.fresh.*`: matching-CPU probe compilations.
- `zero-page-reduced.json`, `zero-page.*`: the reduced independent defect.
- `newer-apply.json`: application check at the named local revision.
- `baseline-provenance.json`: binary identity, assembly hashes, and failure-set
  correspondence with the earlier verifier-enabled baseline run.

The frozen review compiler hashes are:

| Artifact in `build/0030-claude-review/` | SHA-256 |
|---|---|
| `llc-before-0032` | `a1e94512271b745b9b2343def2bf03cce9ab8ed0bf1e9ca9d12cb193f93db320` |
| `llc-0032` | `25a83a8834b974544f8a9d8d63d169b283005beb70849b69bbe8a4aa511c419b` |
| `llvm-mc-before-0032` | `ce6392596b1f8c65827b37fd5ff8ddb2b151b6e25e8422427526f4e8911a31d3` |
| `llvm-mc-0032` | `8da6f103b900b0b5d7b12748bc6d301a326c247ab6b3520e85e30fc4175c46f6` |

Assisted-by: OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`,
`xhigh` reasoning effort) for this audit, independent replays, the reduced
zero-page input, and corrections to the submission evidence.
