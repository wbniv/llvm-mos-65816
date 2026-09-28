# XY16 `vlastack_sim`: stale X-writer replay in `MOSInsertREPSEP`

**Status, 2026-09-28: fixed locally in patch `0002`; original XY16 input returns `0xD77B` on both emulators.** The [canonical record](../defects/mos-xy16-stale-x-writer-reload.json) retains the immutable failing baseline and the [matching-input candidate receipt](../defects/evidence/2026-09-28-xy16-x-preserve/candidate-run.json). The repaired compiler is installed in `build/llvm-mos-install` and preserved in `build/xy16-x-preserve/candidate-install`.

## Historical baseline and diagnosis (before the repair)

The `vlastack_sim` oracle is `0xD77B`. The preserved pre-gate `+mos-xy16 -Os` ROM returns `0xD3BD` on MAME and bsnes-jg. The same result occurred with carry scheduling `off`, `always` and `gated`; default and A16 returned the oracle. The [September 27 receipt](../defects/evidence/2026-09-27-competing-carry-gate/vlastack-observation.json) records those runs. Replaying the exact [pre-gate ROM](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/rom.sfc) on bsnes-jg at frame 1200 returns the same mismatch; a rebuild from byte-identical preserved source produced the identical ROM hash. The replay's [log](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/bsnes.log) has a nonzero assertion exit. This is the same failing input, not a reduction.

## First divergence

The [A16](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/a16.wram.gz) and [XY16](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/xy16.wram.gz) WRAM captures have identical `vs_totalruns`, `vs_rowoff[]` and `vs_rle[]`. In A16, `vs_nruns[]` is `12, 12, 11, 12, 9, ...` and matches the 24 stream header bytes. In XY16, every `vs_nruns[]` entry is `8`; the later prefix sums and pixels then diverge. The [XY16 map](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/rom.map) places `vs_rle` at `$087c`, `vs_nruns` at `$0204`, and `vs_rowoff` at `$084c`. The XY16 indexed load reads `$087c + $0204 = $0a80`, whose captured byte is `0x08`. The [A16 map](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/a16.map) is preserved alongside its capture.

## Instruction-level cause

The [pre-`mos-insert-rep-sep` MIR](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/pre-repsep.mir) has one 16-bit `LDXImag16 $rs1` holding the stream offset, followed by byte writes to `$rc2` and `$rc3` for the `vs_nruns` destination pointer, then `LDAbsXIdx @vs_rle`. At this point the index value remains in X across the Y writes. The [post-pass MIR](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/post-repsep.mir) inserts `SEP #$10` for those Y instructions and `REP #$10` before the indexed read. Because narrowing X clears its high byte, `MOSInsertREPSEP::placeIntraBlock` clones the prior X writer after that REP. Its source `$rs1` aliases `$rc2:$rc3`, which now holds the `vs_nruns` pointer. The cloned load therefore replaces the correct index with `$0204`.

The [linked object disassembly](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/rom-lto.dis) and non-LTO [assembly](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/baseline/original-xy16.s) show the same sequence:

```asm
rep #$10
ldx __rc2             ; row offset
sep #$10
ldy #<vs_nruns
sty __rc2
ldy #>vs_nruns
sty __rc3             ; __rc2:__rc3 now holds $0204
rep #$10
ldx __rc2             ; inserted replay reads $0204
lda vs_rle,x          ; reads $0a80, not the row header
```

The earlier [in-place-memmove investigation](2026-06-29-xy16-inplace-memmove-16bit-index-miscompile.md) records the writer-cloning repair for a high-byte-loss case. That repair is present in patch `0002`, the live source and the preserved compiler. This input exposes a different requirement of that repair: replay is valid only if the writer's source still contains the same value. The [prior-work audit](../defects/evidence/2026-09-28-vlastack-xy16-stale-reload/prior-work-audit.md) also distinguishes the near-Y and soft-stack-spill defects. The VLA path still forms, but its dynamic allocation is downstream of the wrong run count and is not established as the cause of this mismatch.

## Repair requirement recorded before implementation

The backend must preserve the actual 16-bit X value across an index-width narrowing when a later 16-bit reader needs it. Reloading an earlier writer is safe only with a proven stable source. A correct change needs a matching-input red/green emulator run, a MIR regression that forces the source pair to be overwritten between the original writer and the reader, and relevant width-mode and hard-stack checks. Instrumented source variants changed code generation and are diagnostic only; their passing results are not repair evidence.

Investigation and evidence: OpenAI Codex API agent 0.157.1, exact model ID unknown (GPT-6 family stated by the session), reasoning effort unknown; session 01a0e5a0-9b2c-7c81-9f0b-d154ff8783d9. Earlier contributors retain the attribution recorded in their linked reports.


## Repair and validation, 2026-09-28

`MOSInsertREPSEP` saves the actual X word with `PHX` before the first narrowing, then restores it before a full-width reader. It stops tracking that value on a byte definition or register-mask clobber. A Y operation restoring X/Y width does not discard the pending X value. Arithmetic writers and overwritten imaginary-register sources are not replayed. The [implementation delta](../defects/evidence/2026-09-28-xy16-x-preserve/repair.diff) is carried in `0002` with two MIR regression files.

A normal restore uses `PLX`. When NZ remains live, or the region consumes/produces original hard-stack bytes, stack-relative copies preserve A/P and move the saved X word beneath those bytes. The restore removes exactly that word. Five MIR routines check byte/word pushes and pulls and a comparison whose Z must survive a full-width indexed store. A C caller repeats them 32 times in each of default, A16 and XY16 modes; [all six emulator runs pass](../defects/evidence/2026-09-28-xy16-x-preserve/runtime.log). Opaque stack operations and offsets beyond the 8-bit stack-relative range produce explicit diagnostics. This is an intra-block repair; it does not claim a general cross-block X/Y spill algorithm.

| Unchanged original `vlastack_sim`, XY16 `-Os`, LTO | MAME | bsnes-jg |
| --- | --- | --- |
| Preserved baseline | `0xD3BD` (fail) | `0xD3BD` (fail) |
| Repaired installed compiler | `0xD77B` (pass) | `0xD77B` (pass) |

Both emulator checks sample at 1200 frames/ticks. The [host oracle](../defects/evidence/2026-09-28-xy16-x-preserve/host.log) also returns `0xD77B`; no source workaround was used. The candidate explicitly uses the unchanged ungated carry policy (`always` in the current CLI), and produces the same ROM as the default-policy candidate. [Commands, compiler/linker/emulator identities, ROM and input hashes](../defects/evidence/2026-09-28-xy16-x-preserve/candidate-run.json) identify the tested build. CMake installation rewrites the executable RPATH, so installed and build-directory binary hashes differ; [the build identity](../defects/evidence/2026-09-28-xy16-x-preserve/identity.json) records both locations.

The [focused red/green checks](../defects/evidence/2026-09-28-xy16-x-preserve/checks.json) use the preserved pre-edit `llc` and the repaired `llc`. The original MIR needs only `stack-id: mos-static` normalized to `default` for standalone parsing; the [unmodified parsing diagnostic](../defects/evidence/2026-09-28-xy16-x-preserve/original-mir.log) is retained, and all instructions remain unchanged in the derived replay. The original C compiles with `-verify-machineinstrs`. The [earlier in-place-memmove gate](../defects/evidence/2026-09-28-xy16-x-preserve/xy16inplace.log) remains green in all three modes (`0x90AA` at capacity 1700, `0xDEBD` at capacity 200).

Patch regeneration [round-trips the live MOS source and focused tests](../defects/evidence/2026-09-28-xy16-x-preserve/roundtrip.log). Its standalone exclusion list now also keeps the existing `0068` null-streamer patch separate. The [full MOS suites](../defects/evidence/2026-09-28-xy16-x-preserve/lit.log) report **179 passed, two unsupported, five failed**. All five fail during `opt` startup because `mos-recover-near-nowrap` is registered twice; they do not execute this late machine pass. These failures remain outside this repair, so this is not a full-suite green result.

Run `dev/run.sh xy16xreload` to repeat the original-input and hard-stack gates. The [published Vlastack demo](https://biohack.net/snes/vlastack/) supplies the realistic decoder workload; its published binary is separate from these retained validation ROMs.

Repair, validation and documentation: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e5e8-7760-7383-a39a-629f539d24fa.
