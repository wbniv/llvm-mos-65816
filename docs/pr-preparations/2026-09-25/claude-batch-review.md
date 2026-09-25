# Independent review of the September 24–25 Claude batch

Reviewed by OpenAI Codex on 2026-09-25, starting at repository `2ded248f`;
vendor pin `8be0546128a55e78c63ca571d466aa72a782cd36`.
The checkout already contained unrelated tracked edits and untracked PR drafts.
Those were preserved. No upstream publication or SNES platform submission was made.

## Findings and changes

| Finding | Disposition |
|---|---|
| **0043 incompletely closes silent truncation.** `=a` rejects i16, but `={a}`, `={x}`, `={y}`, and `={rc0}` still accept it and manufacture a zero high byte. A C register variable with source constraint `r` reaches this path. | Extended explicit-register lookup with a width check; kept valid named pairs, flag extension, and untyped clobbers. Expanded the lit test. Corrected the draft's IR-only claim. |
| **0047 introduces an unintended expression modifier.** Adding `addrasciz` to the shared modifier table makes `lda addrasciz(symbol)` valid and emits `R_MOS_ADDR_ASCIZ` at its one-byte operand. The directive-only claim was false. | Removed the modifier-table and integer-evaluation edits. Kept the raw-text directive path. Added all-width object round trips and a negative instruction-operand test. |
| **0046 leaves table omissions undetectable.** An explicitly bounded array silently value-initializes a missing final row. | Retained Claude's missing row and added inferred array size plus a static assertion against the enum count. This protects count, not ordering. |
| **The lit refresh list is incomplete on a clean build.** The earlier validation notes explicitly needed `llvm-readelf`, `count`, and `llvm-config` as extra build steps. | Added them to both refresh paths and their help/reference text. Building llvm-readobj alone does not create its llvm-readelf alias target. |
| **The positive rcundef gate can skip a missing mandatory witness.** Its failure-report pipeline can also exit before printing useful diagnostics under `pipefail`. | Missing fixtures now fail; the failure branch prints the compiler diagnostic without a filtering pipeline that can fail on a nonmatching message. |
| **The [dp],Y plan overclaims profitability.** Its own default-scheduler measurements show +13 B and +8 B. Returning false without mutation proves fallback behavior, not a bound on successful matches. | Corrected the plan and implementation commentary. The existing scheduler follow-up remains open; neither a scheduler repair nor a reliable profitability gate is established by this review. |
| **Several new comments narrate history.** Examples include 0040's virtual-register incident narrative, 0045's discovery aside, the far-index test, and rdiff/video comments. | Reworded them around current contracts and input shapes. The investigation and attribution remain in docs and commit history. |

### 0043: independently reproduced C entry point

```c
unsigned short f(void) {
  register unsigned short v __asm__("a");
  __asm__("lda #42" : "=r"(v));
  return v;
}
```

Command: `build/llvm-mos-install/bin/mos-clang -mcpu=mos6502 -Os -S named-reg.c`.
With the initial 0043 artifact this succeeds, emitting `lda #42; ldx #0; rts`.
With the revision it rejects the unsatisfiable operand. The backend currently
uses a fatal GlobalISel translation diagnostic; improving that diagnostic is
separate work. The expanded IR test checks twelve rejected cases and six valid
functions, including named byte/pair/flag registers and clobbers.

### 0047: why the extra changes are unnecessary

`MOSMCELFStreamer::emitValueImpl` detects `VK_ADDR_ASCIZ` and passes its
**subexpression** to `emitMosAddrAsciz`. Thus the object path unwraps the
marker before fixup evaluation. The revised text path prints the directive
before constructing that marker. Neither path needs to evaluate or print the
marker as a general expression.

The initial patched assembler accepts this input:

```asm
lda addrasciz(target)
.byte 204
target:
```

Its object contains `.text` bytes `a5 30 cc` and an `R_MOS_ADDR_ASCIZ`
relocation at offset 1, rather than a binary address relocation. The revision
rejects it with `unknown modifier 'addrasciz'`. This is an observed invalid
relocation, not a claim that the probe demonstrated a buffer overrun.

The initial report's `.byte 56` for the constant eight is not evidence of
undefined behavior: 56 is the ASCII code for `8`. The text-streamer crash is
real, but that observation did not justify changing integer evaluation.

## Validation performed in this review

| Check | Result |
|---|---|
| Toolchain rebuild and install | PASS; revised C example rejects |
| Full MOS CodeGen + MC before review | 164 tests: 158 pass, 2 unsupported, 4 fail |
| Full MOS CodeGen + MC after review | 166 tests: 160 pass, 2 unsupported, the **same four failures** |
| Updated `inline-asm-physreg-width.ll` | PASS, including named-register cases which fail against initial 0043 |
| `addr-asciz.s`, `addr-asciz-roundtrip.s`, `addr-asciz-invalid-modifier.s` | PASS; all eight widths, forward constants, label differences, and byte-for-byte object comparison |
| Revised 0043/0046/0047 apply checks against files from the exact pristine vendor pin | PASS independently, including 0047 without 0039 |
| `dev/regen-patch.sh` | PASS: reapplied MOS directory and focused tests equal live vendor; 0002's diff is comment-only |
| `dev/run.sh roundtrip` | Default 95 identical / 23 skipped; a16 118 identical; xy16 118 identical; **0 divergent** |
| `dev/rcundef.sh` | 34 compiler/verifier combinations pass |
| `dev/known-issues.sh` | PASS with 0 active repro legs; this is not additional correctness coverage |
| `dev/farbank.sh` | Host, a16@MAME and a16@bsnes-jg all `0x00010000`; six b7 loads exercise Y=1,2,3 across two bank boundaries |
| Video battery | Existing stale ROMs fail the stream-presence test; rebuilding the two programs with the existing battery loop packs both streams successfully |
| `dev/battery-video-selfcheck.sh` | Both packed streams match; both ROMs pass 8 entropy runs at each of frames 60, 100, and 200 (48 comparisons) |
| Shell syntax, comment-history scan, and whitespace | PASS |

The four suite failures are `CodeGen/MOS/legalizer.mir`,
`CodeGen/MOS/scavenger-p-undef-6502.ll`, `CodeGen/MOS/shift-rotate.ll`, and
`MC/MOS/addressing-modes-65816.s`. This review does **not** call the full suite green.
The first run of the new invalid-modifier test expected the wrong diagnostic;
correcting its check to the actual `unknown modifier` wording produced the
final result above.

Video rebuilding used the body of `dev/build.sh` from its battery loop onward,
with only the source list narrowed to `apollo-reel.c` and `snes-video-reel.c`;
the installed SDK was reused. Output sizes are 1 MiB and 4 MiB. This checks the
real prep/link/post/checksum logic without claiming a fresh full-SDK rebuild.

Local raw logs: `/tmp/claude-review-{toolchain,lit-before,lit-final,regen,roundtrip,integration,video-build,video-selfcheck}.log`.
The scripts and lit tests above are the durable reproductions; `/tmp` logs are
session evidence and may be removed. The initial pinned-base validation files
retain their original binary hashes; **the revised patches have not been rebuilt
in those isolated validation trees**. Refresh that evidence before posting.

Reviewed artifact SHA-256:

```text
8ffad5b5b6ac9d94dfcf2953d79327b88cba130150350419e30f6f6d9ac0aef6  0043
d42701fa045a3f4c4a3cf73807cfb50e0dc838e51b3bc1b06e95be61d935e442  0046
c6feb148fcc3430cb061ef57b48a2f1bf60fa5e08405157a31ec13d29f3831c4  0047
```

## Scope, critique, and remaining work

The code review covered 0038–0048, the [dp],Y selector and its bank-crossing
gate, recent measurement conclusions, the video post-link change, rdiff's
memory-size change, and the current XFAIL retirement edits. Earlier 0032–0037
review edits were read for context; their prior validation was not rerun wholesale.
This is not a new exhaustive cross-target or c-torture campaign.

- 0040's refusal to delete a scratch-defining reload preserves live intervals;
  no additional implementation defect was established. 0041's splitting/merging
  and tied-group bookkeeping pass the MOS tests. Its AArch64 i128 test explicitly
  preserves SelectionDAG's two-32-bit-register truncation behavior; this is
  parity coverage, not proof that all 128 value bits survive. No new AArch64 run
  was performed here.
- The 0039/0044/0045 width fixes and the far-addressing tests hold on the local
  round-trip corpus. 0044 still needs its standalone PR draft and validation bundle.
- The [dp],Y feature is runtime-validated; its documented size regressions remain
  an optimization defect. The far-scalar and long,X **measurement GO** decisions
  authorize further gated implementation work, not an ungated native-width change.
  Keep the measured A:X return/store losses as negative controls. The pointer-hoist
  NO-GO correctly accounts for 16-bit index wrap; do not infer a no-wrap contract.
- rdiff's smaller grid leaves room for the soft stack. Its small corpus grid does
  not establish the rendered demo's stack high-water mark. This review changes
  comments only and retains Claude's recorded 6000-frame visual evidence; it does
  not claim a new rdiff runtime or stack-depth measurement.
- Fork-native far/codegen work and SNES platform/runtime submission remain subject
  to the [separate platform prerequisites](../../upstream-pending-work.md#snes--separate-platform-track)
  and [reconciliation strategy](../../415-snes-target-reconciliation.md).
  Published [bankwalk](https://biohack.net/snes/bankwalk/) and
  [dpbank](https://biohack.net/snes/dpbank/) demos remain relevant runtime evidence;
  their publication does not imply that the platform is ready to merge upstream.

## Attribution

Will Norris is the recorded commit author. Preserve the original coauthor
trail rather than attributing the whole batch to this review:

- `84d87260` (0043): Claude Opus 5 (1M context).
- `fe54d1b7` (0046): Claude Sonnet 5.
- `6eced8e4` (0047): Claude Fable 5.1.
- The initial 0043/0046/0047 PR preparation credits Claude Sonnet 5.
- `2689b74d` and its plan record the [dp],Y implementation; `66855b98` credits
  Claude Opus 5.5 (1M context) for video stream packing, and `e3bb5a62` credits
  Claude Sonnet 5 for rdiff.

These commits link the [Claude session](https://claude.ai/code/session_017sAprvTwtKFJHKgQmr1qgr).
OpenAI Codex CLI 0.155.1 using GPT-6 Astra (`gpt-6-astra`), `xhigh` reasoning
effort, performed this independent review, the revisions listed above,
local validation, and documentation reconciliation. Earlier upstream author
and demo credits are retained.

Attribution metadata was verified from session
`01a0d69b-5f24-7f10-be74-98413c05de4c`: its session header records CLI version
`0.155.1`, and its turn contexts record `gpt-6-astra` with `xhigh` effort.
These details also qualify the abbreviated Codex credit in commit `6065ebec`.
