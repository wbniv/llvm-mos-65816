# Independent 0038 submission review

September 26, 2026. **Implementation approved, with exact current-main isolated
compilation and suite validation assigned to the preparation coordinator.**
This reviewer did not build a compiler or execute a new ROM. Nothing was
posted, pushed, or changed in the shared vendor/source/build trees.

The reviewed [posting patch](0038-llvm-mos.patch) targets MOS main
`7bd67c0ae4e8bb65a3f980912bf201df22131e34` and applies with ordinary
`git apply --check`; no reduced-context option is needed. It contains the
existing implementation, two clarified comments, the two original regression
files, and an additional stock-6502 MIR depth regression. No new implementation
blocker was established. The [PR body](0038-pr-body.md) preserves the separate
SPC700 limitation and distinguishes historical results from current validation.

## Prior-work reconciliation

Searched structured defects, the original plan and draft, TODO/upstream
summaries, preparation records, Git history, standalone patches, `0002`, live
vendor source, and current MOS main for `0038`, `returnaddress`, `frameaddress`,
`ReturnAddressByte`, and `MOSLowerReturnAddress`.

- Commit `2adc7e7799d8146321f62cac26507f6c1eff7909` implements this repair.
  The [original plan](../../plans/2026-09-23-return-frame-address.md),
  [validation](../2026-09-23/0038-validation.md), and
  [draft](../../upstream-return-frame-address-pr.md) describe the same mechanism.
- Commit `2799c55c` reconciles the SPC700 crash with the already-existing 0003
  patch. That observation is not a separate 0038 defect.
- The [September 25 batch review](../2026-09-25/claude-batch-review.md) states
  that its scope included 0038–0048, but does not supply an exact 0038 packet
  verdict/hash or standalone refreshed validation. This record supplies the
  focused independent review instead of assuming that broad scope establishes
  final-package readiness.
- Live vendor source contains the repair; `0002` does not. It remains a
  standalone carried patch. Current MOS main has neither the legalization
  cases nor the late return-address pass.
- No canonical structured record specifically for these intrinsics was found.
  This review is a readiness audit of an already-established repair, not a new
  defect or a replacement failing baseline. Any later historical migration
  should cite this reconciliation and keep the original evidence intact.

## Source review

The fixed frame object at offset zero denotes the incoming software-stack
pointer. Existing frame-index lowering adds the fixed stack size and uses the
frame-pointer register when variable-sized objects require one. Avoiding
`setFrameAddressIsTaken` therefore does not lose the dynamic-frame base; it
avoids forcing a frame pointer just to name a fixed boundary. Static-stack
locals need not be adjacent to this address, consistent with the historical
runtime qualification.

Return-address lowering records `isReturnAddressTaken`, keeps both byte reads
side-effecting, and reserves accumulator/X clobbers before register allocation.
The late pass runs after frame lowering, both scavenger passes, and the late
optimizer. Its forward CFG propagation assigns one entry depth per reachable
block, checks equal incoming depths, includes local pushes before each read,
and treats a completed call as balanced. Balanced loop back edges preserve the
same depth. It changes no CFG edge. The ABI's generated register pushes are
byte-width operations; the wider fixed stack pushes already listed contribute
two bytes. Unmodeled cross-statement inline-assembly stack manipulation is not
promised by this contract.

The selected 6502/SPC700 pseudo has explicit accumulator and scratch-X outputs;
the 65816 stack-relative form needs only the accumulator. The byte ordering and
JSR return-word increment agree with the documented calling convention, while
SPC700 omits that increment. Higher levels return zero; only the return-address
intrinsic is zeroed in an interrupt handler. The 16-bit result deliberately does
not retain a JSL bank byte.

Two posting-only comment changes describe current contracts accurately:
`MOSInstrPseudos.td` says depth at **each read**, not only at the entry block;
the byte-push comment describes 8-bit code-generated operations without naming
the downstream-only `MOSInsertREPSEP` pass. All other source additions are
unchanged from carried patch SHA-256
`f89d933259bed96a6b2381c89b5d0223d052e8f9d48e1a9ca4a10687e401e881`.
Code/test comments were checked against `AGENTS.md`'s current-contract rule.

## Independent retained-binary replays

Executed `python3 build/post-ready-review-mos/0038/replay.py`. The harness retains
commands, inputs, tool versions/hashes, exit status, assembly, diagnostics, and
FileCheck results under its `replay/` directory. It does not rebuild or modify
any compiler. Four original RUN configurations:

| Configuration | Historical pre-repair | Clean current-main baseline | Historical repaired compiler |
|---|---|---|---|
| 6502 O0, return/frame-address | Unsupported intrinsic, nonzero exit | Same legalization failure | MachineVerifier and FileCheck pass |
| 6502 O2, return/frame-address | Unsupported intrinsic, nonzero exit | Same legalization failure | MachineVerifier and FileCheck pass |
| 65816 O2, return/frame-address | Unsupported intrinsic, nonzero exit | Same legalization failure | MachineVerifier and FileCheck pass |
| SPC700 O2, return-address | Unsupported intrinsic, nonzero exit | Same legalization failure | MachineVerifier and FileCheck pass |

The new `return-address-depth.mir` also passes on the preserved assertions-on
repaired compiler. It starts after selection, pushes a byte in a predecessor,
reads the low byte, temporarily pushes another byte, reads the high byte, and
balances that temporary push before a loop back edge. The checked indexed-load
offsets are 258 and 260. The final predecessor push is popped on exit. This
checks the CFG/local-depth algorithm directly; it is not another frontend test.

Additional read-only probes in `additional-controls.ll` compile with machine
verification on the historical repaired compiler at O2 for 6502 and 65816.
The dynamically allocated frame returns `__rc30:__rc31`, the saved incoming
software-stack base, before restoring it. Return-address low/high-byte and
sign-branch probes produced no new blocker on those targets.

### SPC700: preserve the existing limitation

The additional SPC700 sign comparison crashes in the historical compiler's
late optimizer, before return-address expansion. Its captured pre-late MIR
contains `$rc2 = LDImm 0` and `$rc3 = LDImm 0`, the non-GPR destination shape
handled by existing patch 0003. The unchanged original 0038 SPC700 test passes.

To reconcile this observation, `reconcile-spc.py` replays 0003's existing
`late-opt-spc700.mir` on the identified binaries: both historical baseline and
historical candidate exit with signal 11; the integrated compiler carrying
0003 exits zero. The integrated compiler also passes the additional 0038
control. An ordinary signed-argument-only IR control passes all three builds
and does not exercise the same late-optimizer instruction shape; it is not
used as a failing baseline. Current MOS main still lacks the non-GPR guard.

This is corroboration of the already-recorded 0003 limitation, not a new
compiler failure report, a new fix, or proof that current-main 0038 alone makes
every SPC700 use work. No extra compiler changes were made or bundled.

## Evidence identities and handoff

Historical candidate `llc-0038` reports an optimized build with assertions;
its source stack is recorded in the original validation as `742d554` plus
0011/0030–0037, then 0038. It is not described as a fresh 0038-only current-main
build. The clean current-main baseline below is the coordinator's preserved
0039 baseline snapshot, before any prerequisite patch.

```text
0220a0f083728dca77bae8985a330e5a33a135b13d60fc580d5c604f253336a8  0038-llvm-mos.patch
6b5cfbb41c42f201ca9cf6330d9b3dc25cddfef6b0cde0c4881f490ee76d5989  historical llc-final
e849c7a80e79a81525a8d382788e19033ee4efe7a303b4df37351f62f6b0c3f5  historical llc-0038
f215e4d24f07a5e6720de665f5fdbda4b6b537aac021c55bbe14678f53af8331  current-main baseline llc
f965b29659e9fc708b595f705393b3bcabf3d414e1acac14217e97c22b57d445  integrated llc with 0003
e2b1d925943838c0ec5be58fecc106da97c77ed40d4408fc31c3f25108fb69be  replay/receipt.json
2b8af2f43feae70e01b01f3f53f158ad3b490e924707a488e7723399c8e8b172  additional/receipt.json
3b967317415ff36d9d110be1e807dfd60cf20fb4858cf28d6d890165dcc42489  spc-reconciliation/receipt.json
```

The helper scripts, additional source/MIR, commands/logs, and replay outputs
are retained under `build/post-ready-review-mos/0038/`; the coordinator should
archive the small evidence files with the final validation bundle. Existing
September 23 torture/corpus/emulator evidence remains dated evidence, including
its two explicitly explained skips. It was read, not rerun. The coordinator
owns final exact-packet compilation, suite execution, summary/dependency
registration, and inventory refresh.

## Attribution

Independent review, extraction, added MIR regression, replay harnesses, and
this record: **OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`,
`xhigh` reasoning effort**, agent `/root/review_mos`; verified own session
`01a0db96-e0ef-75e2-89ad-2939c4954446` and turn context. Original contributor
credit remains as recorded in the linked draft: Claude Code CLI 2.1.278,
Claude Fable 5.1 (`claude-fable-5-1`), `high` reasoning effort. This review does
not claim authorship of that implementation or its earlier validation.
