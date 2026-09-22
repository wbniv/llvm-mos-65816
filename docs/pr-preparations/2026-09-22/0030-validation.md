# Patch 0030: physical copy reuse and kill flags

- [x] Reproduce the original C failure with the saved upstream compiler.
- [x] Isolate the first failing pass and reduce the mechanism to three instructions.
- [x] Implement the liveness repair and add focused regression coverage.
- [x] Compare each regression case against the saved baseline.
- [x] Verify the original input at six optimization levels and compare assembly.
- [x] Run the complete MOS CodeGen suite with assertions enabled.
- [x] Verify standalone patch application and local source integration.
- [x] Complete local compiler rebuild, installation, and integration checks.
- [x] Review the final submission and check current upstream applicability: [independent review](0030-claude-review.md) (sixth MIR case, c-torture differential; upstream `main` identical to the pinned base).
- [x] Audit the independent review against saved artifacts and rerun the exact
  standalone patch's six MIR cases and MOS suites: [audit](0030-review-audit.md).
- [x] Claude's updated attribution records CLI `2.1.278`, model
  `claude-fable-5-1`, and `high` reasoning effort.
- [ ] Publish the standalone PR.

Patch: [0030-mos-copy-phys-reg-liveness.patch](../../../patches/llvm-mos/0030-mos-copy-phys-reg-liveness.patch).
Proposed submission: [PR draft](../../upstream-copy-phys-reg-liveness-pr.md) ·
[browser preview with patch](0030-pr-preview.html).
Original input: [newton-step.c](../../investigations/repro/upstream-issues-2026-09-22/newton-step.c).
The earlier [issue draft](../../upstream-newton-6502-postra-issue.md) is superseded
by this fix.

## Diagnosis

The saved Clang at `742d554bf08042b8df93d791c335260fadd16643` rejects the original
C input at `-O0 -mllvm -verify-machineinstrs`. Stopping the backend immediately
before `postrapseudos` produces verified MIR; running that pass alone reproduces
the undefined `$y` diagnostic.

In the original function's block 62, copy expansion turns an imaginary-register
copy into a store directly from Y. `getRegWithVal` proves that Y still contains
the required value, but does not update a preceding indexed load's `killed $y`
operand. The load does not overwrite Y, so the reuse is valid. The physical
value's live range must extend through the newly introduced store.

The focused MIR reduces this to an initial copy from Y, an indexed load that
kills Y, and a copy of the saved value to another imaginary register. The test
also preserves a kill on the pointer to ensure that unrelated liveness is not
changed. Additional cases cover A reuse for an X-to-Y copy, subregister overlap,
a kill on the establishing copy, and rejection of a clobbered value.

The implementation uses `clearRegisterKills(Reg, TRI)` on the range beginning
with the establishing copy and ending just before the insertion point. Existing
clobber checks determine whether reuse is legal; the additional walk only
repairs liveness after a reusable register has been selected. No physical
instructions or register-selection rules are changed.

The separate C reduction reaches 14 lines but retains an early return and
unreachable arithmetic, making it a less useful explanation than the three
instruction MIR sequence. It is retained as an investigation artifact, not used
as the submitted regression or as runtime evidence.

## Isolated build and evidence

The initial validation below used `build/newton-postra-src` at the pinned
upstream revision plus only 0030. That directory and its build have since been
reused for a separate follow-up and no longer identify a 0030-only candidate.
The saved `build/0030-claude-review/llc-0030-only` binary and the fresh test tree
under `build/0030-review-audit/source` provide the standalone review evidence;
see the [audit and binary hashes](0030-review-audit.md). The original results
below describe the five-case patch before the independent review's sixth case.

`build/newton-postra-build` is a separate Release build with assertions enabled,
copied from the existing X86/ARM/AArch64/MOS build to reuse its compiled objects.
The generic two-address object was rebuilt from pristine source, and the MOS
instruction-info object was rebuilt with this fix. Only MOS tests were run for
0030; the other compiled backends provide no additional validation claim.

The build retains its configured container paths. Use these additional mounts
alongside the repository's `/work` mount:

```text
build/newton-postra-src   -> /work/build/register-exhaustion-src
build/newton-postra-build -> /work/build/0029-cross-target-build
```

The saved unmodified Clang emits IR independently at each optimization level.
The baseline and candidate `llc` then compile the same IR; `-Os` and `-Oz` use
backend optimization level 2 with the size attributes supplied by Clang. The
candidate contains `llc` and `opt`, not a separately rebuilt upstream Clang.

| Check | Baseline | Candidate |
| --- | --- | --- |
| Y reuse after an indexed-load kill | Verifier rejects | Verifier and FileCheck pass |
| A reuse after a store kill | Verifier rejects | Verifier and FileCheck pass |
| Overlapping subregister kill | Verifier passes; FileCheck rejects stale kill | Verifier and FileCheck pass |
| Kill on establishing copy | Verifier rejects | Verifier and FileCheck pass |
| Clobbered-value control | Verifier and FileCheck pass | Verifier and FileCheck pass |
| Original C-derived IR, `-O0`, object emission with verifier | Rejects stale Y kill | Pass |
| Same input, `-O1/-O2/-O3/-Os/-Oz`, objects with verifier | All pass | All pass |
| Assembly comparison at all six optimization levels | Identical to candidate | Identical to baseline |
| Complete MOS CodeGen suite | Not rerun | 84 pass, one unsupported |

The unsupported test is `getchar-regression.ll`, explicitly disabled by its
existing `UNSUPPORTED: target={{.*}}` directive. The CodeGen suite needs only
`llc`, `opt`, and FileCheck; lit's notices about other unbuilt tools did not
affect this suite. MC and non-MOS suites were not run for this MOS codegen change.

The subsequent standalone audit adds the sixth case and reruns MOS CodeGen
(84 pass, one unsupported) and MC (46 pass). Non-MOS suites remain untested for
0030. The audit also corrects the independent review's corpus totals: 1,656
files attempted, 1,390 accepted by Clang at each level, 4,170 backend
comparisons. Of these, 4,070 pass with identical assembly, 20 are repaired,
76 fail on both sides, and four assertion-only differences reproduce on the
pristine assertion-enabled compiler. Full accounting and artifact paths are
in the [review audit](0030-review-audit.md).

The evidence supports a liveness-metadata defect in the original reproducer.
No emulator run or runtime-miscompilation claim is included.

Artifacts under `build/newton-postra/`:

- `diagnose.py`, `diagnosis.json`, `before.mir`, `after.mir`: baseline and pass isolation.
- `reduce-c.py`, `reduced.c`: additional C reduction.
- `validate.py`, `validation.json`: exact commands, per-case results, and hashes.
- `*.out.mir`, `*.checks.log`, `*.log`: baseline/candidate outputs and diagnostics.
- `original.O*.ll`, `baseline.O*.s`, `candidate.O*.s`: IR inputs and assembly comparisons.
- `codegen-lit.json`, `codegen-suite.log`: full MOS CodeGen results.
- `manifest.json`, `patch-check/`: exact patch hash and a fresh pristine-source application.

The patch applies cleanly to the local vendor tree and reverse-applies cleanly
after integration. `dev/toolchain.sh` applies it independently;
`dev/regen-patch.sh` excludes its MOS source change from the aggregate feature
patch during regeneration. Existing unrelated work is retained.

The local Clang, LLD, and `llc` were rebuilt, and Clang/LLD were installed into
`build/llvm-mos-install`. The installed compiler passes 24 verifier-enabled
C-to-object checks: six optimization levels across the four existing local
target configurations. The integrated MIR regression also passes its verifier
and all five FileCheck cases. These integration results are separate from the
isolated upstream evidence used in the PR draft. Commands and results are in
`local-validate.py`, `downstream-matrix.json`, `downstream.*.log`, and
`local-regression.*` under `build/newton-postra/`.

The new source and regression comments pass the repository's history-wording
check. Added source lines and integration script syntax also pass their checks.
AI attribution includes the tool, model, and effort recorded in this session:
Codex CLI `0.155.1`, `gpt-6-astra`, and `xhigh`.
