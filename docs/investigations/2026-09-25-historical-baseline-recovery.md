# Historical shift and inline-bitboard baseline recovery

**Subsequent repair:** [patch 0055](2026-09-25-shift-inlineasm-fixes.md) fixes the
captured native-width shift trigger. The failing inputs, binaries, and measured
baseline results below remain preserved. The linked follow-up records the
matching-input success, runtime checks, and implementation attribution.

OpenAI Codex CLI 0.157.0 (`codex-tui`), model `gpt-6-astra`, `xhigh`
reasoning effort: source recovery, reconstructed compiler comparison, validation,
and this record. No new compiler fix was authored in this investigation.
Earlier contributor credits remain in the linked reports and patch records.

**These C failures are not reproduced on the saved, unpatched upstream build.**
They involve the fork's native 16-bit modes. Upstream revision
`742d554bf08042b8df93d791c335260fadd16643` accepts both recovered inputs for
`mos6502` and default `mosw65816`, at `-Os -fno-lto` with
`-mllvm -verify-machineinstrs`. It explicitly ignores `+mos-a16` and
`+mos-xy16` as unrecognized features; that invocation is not native-mode coverage.
These results concern this published source revision, built locally, not an
upstream release binary or a claim about the latest upstream revision.

| Input/configuration | Preserved current fork | Reconstructed fork without 0028 | Unpatched upstream `742d554bf080` |
|---|---|---|---|
| Recovered variable-shift caller, default `mosw65816` | Pass | Not tested | Pass |
| Same caller, a16 / a16+xy16 | `G_ANYEXT s8 -> s64` legalization failure | Not tested | Features unsupported |
| Recovered inline-bitboard caller, default `mosw65816` | Pass | Not tested | Pass |
| Same inline caller, a16 | Pass, host/bsnes-jg `0x479E` | Four undefined physical-register errors | Feature unsupported |
| Same inline caller, a16+xy16 | Pass, host/bsnes-jg `0x479E` | Not tested | Features unsupported |
| Both recovered callers, `mos6502` | Not tested in this recovery | Not tested | Pass |

The current status records are [narrow shifts](../defects/shift64-narrow-count.json)
and [inline bitboard](../defects/bitboard-inline-register-pressure.json).
The shift is **confirmed on the captured fork**, awaiting a repair. The recovered
inline-bitboard trigger is **fixed by existing patch 0028**, established by a
comparison with only that compiler source change. Neither C input establishes an
upstream failure. Patch 0028's independent upstream MIR evidence remains in the
[plain-6502 investigation](2026-09-22-0028-plain-6502-reachability.md).

## Recovered historical evidence

The August Codex transcript retains the source additions, successive workarounds,
and both failing compiler diagnostics. The recovered discovery attribution is
OpenAI Codex CLI 0.146.0 (`codex-tui`), model `gpt-5.6-sol`; reasoning effort is
**unknown**, because the saved session settings contain null rather than an
explicit level. This identifies the recovered session, without replacing other
contributors' recorded credits.

The [provenance manifest](../defects/evidence/2026-09-25-historical-recovery/provenance.json)
records the session path, hash, exact JSONL line numbers, and session metadata.
[Selected original records](../defects/evidence/2026-09-25-historical-recovery/session-excerpts.jsonl)
and decoded `patch-*.txt` payloads preserve the evidence. Their timestamps are
August 4 UTC; the historical documents use August 3.

- `shift-stage/` replays source patches at lines 437, 453, and 465, before the
  constant-shift one-hot workaround. Line 470 records the original LTO ROM-link
  failure: `G_ANYEXT` extending an `s8` register to `s64` in `bitboard64_step`.
  This is the recovered failing program; the standalone narrow-shift fixture
  was added later, and its presence alone does not prove it failed historically.
- `inline-stage/` additionally applies lines 475 and 480, retaining the
  constant-shift loop but keeping the three bit-count operations inline.
  Line 485 records the non-LTO `-Os +mos-a16` object compile and four verifier
  errors after Virtual Register Rewriter. The historical log was already
  truncated by the original tool; the retained tail includes all four errors,
  compiler revision, and command.
- Applying the later noinline workaround at line 490 produces a header
  byte-for-byte identical to the first committed version at
  `e8ccda890c972856cf68dfd01cb5a792c5106b9f`.
  [Replay validation](../defects/evidence/2026-09-25-historical-recovery/source-replay-validation.json)
  records both hashes. The historical authored source is recovered through
  replay, not claimed to be the original crash-preprocessed translation unit.

The original August compiler binary, complete dirty compiler tree, crash `.c`
and `.sh` files, and complete LTO link inputs remain unavailable. All `.i`,
`.ll`, and `.mir` files in `replay/` were freshly generated on September 25.
The current failure baseline and the reconstructed comparison must not be
misidentified as the August toolchain.

## Shift: failing baseline captured

The recovered full caller fails on the preserved current fork at `-Os`, a16,
without LTO, with the same `G_ANYEXT s8 -> s64` signature. Its preprocessed input,
optimized LLVM IR, MIR before legalization, complete diagnostics, and commands
are retained. The original report used an LTO link; the new non-LTO failure
provides a smaller boundary at which to diagnose the backend.

The frozen tools, resource headers, vendor diff, patch archive, and CMake cache
are under `build/defect-baselines/2026-09-25-historical-recovery/`.
[Captured identity](../defects/evidence/2026-09-25-historical-recovery/captured-identity.json)
records hashes and the fork's underlying `8be0546128a55e78c63ca571d466aa72a782cd36`
pin. This is a patched vendor tree, not an unmodified upstream compiler.

The [frontend configuration matrix](../defects/evidence/2026-09-25-historical-recovery/replay/frontend-mode-matrix.json)
shows default mode passing and a16/xy16 failing. The retained earlier
`mode-matrix.json` applies backend flags to IR already carrying `+mos-a16`;
its row labeled default does not remove that attribute and is not default-mode
evidence. Likewise, `*-preprocessed.log` used the invalid driver language name
`c-cpp-output`; only the subsequent `*-preprocessed-valid.log` runs using
`cpp-output` are valid compiler reproductions.

## Inline bitboard: causal comparison with patch 0028

The recovered inline input passes on the current fork. To establish why, the
comparison build replaces only `VirtRegMap.cpp` with its pristine source at the
fork's upstream pin, recompiles that object, and relinks against the same other
fork libraries. The
[source check](../defects/evidence/2026-09-25-historical-recovery/causal-source-check.json)
verifies that applying exactly patch 0028 to that source yields the current
source byte-for-byte. The reconstructed failing binary is copied to the frozen
baseline directory as `bin/llc-without-0028`.

Both compilers consume the **same captured LLVM IR**. The reconstructed baseline
reports the same four register/block pairs as the historical log: `$rc13` in
`bb.0`, `$rc2` in `bb.3` and `bb.11`, and `$rc7` in `bb.10`, all copied to `$x`.
The current compiler passes. MIR before greedy allocation is byte-identical;
after Virtual Register Rewriter, the current output differs by five `KILL`
instructions preserving the destination definitions of identity copies.

A full-register copy defines destination lanes even when some source lanes have
no live value. Erasing the identity copy loses those physical-register
definitions. Patch 0028 retains the necessary liveness information with `KILL`.
The matching IR and MIR comparison establish a backend repair, rather than a
frontend transformation that merely avoids the trigger.

The [regression runner](../../dev/recheck-historical-bitboard.py) verifies both
the recovered C entry point and the retained backend input. The captured IR
contains `ctpop.i64`, `cttz.i64`, and `ctlz.i64` inside `bitboard64_step`.
For runtime validation, the recovered probe executes once and its volatile
result is consumed. The host and both a16/xy16 objects linked into SNES ROMs
produce **`0x479E`** on bsnes-jg after 480 frames. This one-probe oracle differs
from the full tour's historical `0xC074`.
[Runtime commands and results](../defects/evidence/2026-09-25-historical-recovery/bitboard-probe-runtime.log)
and ROM/map hashes are retained. The initial missing-linker attempt is preserved
separately and is not a compiler-defect observation.

The published [Bitboard Knight Tour](https://biohack.net/snes/bitboard64/) and
[Limb-Seam Barrel](https://biohack.net/snes/shift64seam/) remain supporting demo
evidence from the original reports. This investigation neither republishes them
nor claims those deployed ROMs contain these newly compiled probes.

## Clean upstream comparison and replay

The saved [upstream reference](../upstream-reference-build.md) passed its full
checksum verification. Its recorded Docker image is no longer present locally;
wrapper attempts therefore failed before invoking a compiler. The same saved
binaries were then executed natively on the host. This execution-environment
difference and host identity are recorded in
[upstream-host-runs.json](../defects/evidence/2026-09-25-historical-recovery/upstream-host-runs.json).
All four supported C compilations passed; their freshly preprocessed inputs,
IR, commands, and logs are retained. The unsupported-feature warning is retained
as a separate observation, not counted as a fifth passing configuration.

From the repository root, the discriminating backend checks are:

```sh
build/defect-baselines/2026-09-25-historical-recovery/bin/llc-without-0028 \
  -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs \
  docs/defects/evidence/2026-09-25-historical-recovery/replay/inline-stage.ll \
  -o /dev/null
build/defect-baselines/2026-09-25-historical-recovery/bin/llc \
  -mcpu=mosw65816 -mattr=+mos-a16 -O2 -verify-machineinstrs \
  docs/defects/evidence/2026-09-25-historical-recovery/replay/inline-stage.ll \
  -o /dev/null
python3 dev/recheck-historical-bitboard.py
```

The first command must fail with the four recorded verifier errors; the second
and the C/backend regression runner must pass. Raw baseline binaries are local,
gitignored artifacts; preserve them when cleaning build outputs. The JSON
records hash the retained inputs, logs, and identities. The
[earlier recheck](2026-09-25-older-defect-recheck.md) remains a valid record of its
passing inputs, but its missing-evidence assessment is superseded by this work.
The copied capture scripts document the commands used and write to their recorded
output paths; use a new evidence directory for another capture. The regression
runner above reads retained evidence and places temporary outputs separately.
