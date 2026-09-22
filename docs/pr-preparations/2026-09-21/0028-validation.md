# Patch 0028 — per-instruction rewriter validation

Validation date: 2026-09-21. Implementation, current-upstream regression checks,
and downstream validation are complete. The PR remains unposted.
Provenance clarified 2026-09-22. A separate
[plain-6502 reachability search](../../investigations/2026-09-22-0028-plain-6502-reachability.md)
on that date found no ordinary C trigger for 0028.
Publication is held until we are ready to open #320/#321. The
[implementation comparison](../../plans/2026-09-21-0028-local-identity-copy-state.md#publication-hold-and-implementation-choice--2026-09-22)
records the smaller boolean-parameter alternative and the pending submission
choice. This report describes validation of the implemented refactor.

## Reproducer provenance

The failure originated in real C compiled by the downstream native-width
compiler. The witnesses include the L-system C torture test, retained through the
small wrapper [rcundef2.c](../../../examples/65816/rcundef2.c), and the
[Newton-fractal corpus program](../../../examples/snes/corpus/newton_sim.c),
under `+mos-a16` / `+mos-xy16`.

Originating applications: [L-System Plant](https://biohack.net/snes/lsystem/) and
[Newton Fractal](https://biohack.net/snes/newton/). Both demo pages returned HTTP
200 and their page titles matched the applications when checked September 22.
They illustrate the programs behind the compiler witnesses; they are not frozen
failing compiler inputs or evidence of a stock-upstream C trigger. The native-width
feature flags are downstream extensions, absent from upstream `742d554bf080`.

| Evidence | What it establishes |
|---|---|
| `build/undef-lane/rcundef2.mir` | Saved compiler-generated MIR whose `source_filename` is `examples/65816/rcundef2.c`; retains the L-system program's IR and machine functions |
| `build/undef-lane/baseline.log` | Running `greedy,virtregrewriter` on that captured MIR fails verification on the `$rc11` read |
| `build/undef-lane/interesting.py`, `reduce.log`, and `reduced.mir` | An automated reduction investigation of the captured failure; the saved reduced file remains substantially larger than the eight-instruction test |
| `build/undef-lane/tiny.mir` and the submitted regression | Deliberately constructed small model of the identity-copy/undef-lane mechanism, verified to fail on stock upstream and pass with the fix |

The eight-instruction regression is not documented as the unchanged final output
of the automated reducer. Its provenance is a real downstream failure followed
by a constructed MIR isolation of the mechanism.

**Reachability limit:** no C reproducer has been established whose ordinary
stock-upstream compilation produces this pattern. Current-upstream validation
establishes the failure and fix at MIR level. The natural C-code trigger is
established for our downstream compiler with native-width features.

The source header in `rcundef2.c` still contains an older allocator-interference
diagnosis and obsolete expected-failure instructions. Those are historical
annotations, not the current diagnosis or test expectation; the current
assessment and positive verifier gate are recorded here and in
[the investigation](../../upstream-rc-undef-ra-pure-virtual-issue.md).

## Implementation

`rewriteInstruction(MachineInstr &MI)` owns lane detection, operand rewriting,
implicit operands, bundle expansion, and identity-copy cleanup. The undef-lane
predicate is local. `handleIdentityCopy` and its boolean parameter are removed.
The outer traversal retains `make_early_inc_range`, block debug dumps, and final
physical-register live-range invalidation.

The extraction preserves the existing deferred-allocation guard, identity-copy
statistics, index removal, and bundle erasure. Three temporary vectors now have
instruction scope. The optimized downstream object contains no out-of-line
`rewriteInstruction` symbol; the compiler inlines it into the rewriter.

## Source and build provenance

- Upstream `main`, fetched September 21:
  `742d554bf08042b8df93d791c335260fadd16643`.
- Downstream vendor base: `8be0546128a55e78c63ca571d466aa72a782cd36`, with the
  repository's existing patch stack and local native-width changes.
- Comparison baseline: saved downstream `llc` implementing the boolean-parameter
  version of patch 0028. Its source and patch are saved in
  `build/0028-refactor/VirtRegMap.bool.cpp` and `bool-parameter.patch`.
- Fresh upstream source: `build/0028-upstream-src`. The upstream build uses this
  checkout mounted at `/work/build/upstream-src` in the development container,
  matching the existing CMake build's source path. Its original scratch source
  checkout is not used for the new upstream results.
- Downstream `llc` and `clang` rebuilt in `build/llvm-mos`; the `clang` component
  is installed into `build/llvm-mos-install`.

On September 22, `build/0028-upstream-src` and `build/upstream-llc` were returned
to the unpatched revision to build the
[permanent upstream reference](../../upstream-reference-build.md). The tested
patched `llc` was preserved separately as `build/0028-6502/llc-patched`; the
submission patch and review worktree retain the implementation. Use the saved
reference for baseline checks rather than assuming the current incremental build
still contains 0028.

The [upstream submission patch](0028-upstream.patch) targets `742d554bf080`.
The [carried patch](../../../patches/llvm-mos/0028-llvm-virtregrewriter-undef-lane-identity-copy.patch)
targets the older vendor pin. Current upstream already passes `MI` explicitly to
`readsUndefSubreg`; the vendor implementation obtains it from `MO.getParent()`.
Each artifact preserves its base's existing API. The extracted helper bodies
are identical after normalizing that one pre-existing call-signature difference.
Both artifacts round-trip to the corresponding tested source and test files.

## Current-upstream checks

The freshly built, unpatched `742d554bf080` compiler rejects the reduced test
with `Using an undefined physical register`, on the `$rc3` read. The same
baseline passes all six companion copy-contract cases.

After applying the upstream submission patch and rebuilding `llc` and `opt`,
the MOS CodeGen suite reports:

```text
Total Discovered Tests: 86
  Unsupported:  1 (1.16%)
  Passed     : 85 (98.84%)
```

Both new MIR tests pass. The unsupported test is `getchar-regression.ll`, which
explicitly declares `UNSUPPORTED: target={{.*}}` in upstream source.

Focused regression command, using the baseline or patched `llc` as appropriate:

```sh
llc -mtriple=mos -run-pass=greedy,virtregrewriter -verify-machineinstrs \
  virtregrewriter-undef-lane-identity-copy.mir -o - |
  FileCheck virtregrewriter-undef-lane-identity-copy.mir
```

Suite command in the development container with the fresh source mounted at
the build's configured source path:

```sh
python3 /work/build/upstream-src/llvm/utils/lit/lit.py -sv \
  /work/build/upstream-llc/test/CodeGen/MOS
```

Local logs: `build/0028-refactor/upstream-unfixed.log`,
`upstream-baseline-build.log`, `upstream-patched-build.log`, and
`upstream-codegen.log`.

## Focused behavior comparison

Both the saved boolean-parameter compiler and refactored downstream compiler pass
MachineVerifier and FileCheck on the original undef-lane regression and the six
functions in `virtregrewriter-copy-liveness.mir`:

| Contract | Expected behavior |
|---|---|
| Partly undef virtual source allocated to an identity copy | Retain `$rs1 = KILL $rs1`; subsequent byte extracts verify |
| Defined physical identity copy | Remove the redundant copy |
| Explicitly undef identity-copy source | Keep the destination definition as a `KILL` |
| Identity copy with an implicit super-register definition | Preserve the additional definition on the `KILL` |
| Parallel physical-copy bundle | Save the incoming value before overwriting its register |
| Defined source subregister with an undef sibling | Remove the redundant defined-lane copy without introducing a `KILL` |
| Non-identity copy with a partly undef source | Keep the real copy; the source remains live across a fixed destination clobber |

The complete post-rewrite MIR outputs of both test files are byte-identical
between the two downstream compilers. The refactor does not change the
undef-lane detection algorithm.

## Downstream witnesses and corpus

The normal installed-toolchain `dev/rcundef.sh` gate passes **34/34** compilation
configurations, with `-verify-machineinstrs`:

- `rcundef.c`: `-O0/-O1/-Os`, under `+mos-a16` and `+mos-xy16`.
- `rcundef2.c` and `newton_sim.c`: `-O0/-O1/-O2/-O3/-Os/-Oz`, under both modes.
- `trimerge_sim.c`: `-O1/-Os`, under both modes.

For a separate comparison, twelve sources were compiled to IR at `-Os` in both
native-width modes: **24 inputs**. Both compiler versions produced byte-identical
post-`virtregrewriter` MIR and final assembly with MachineVerifier enabled.
The sources were `rcundef2.c`, `newton_sim.c`, `trimerge_sim.c`, `pi_sim.c`,
`maze_sim.c`, `bitshuffle_sim.c`, `factorial_sim.c`, `adpcm_sim.c`,
`strcmprace_sim.c`, `arith.c`, `arrays.c`, and `invaders_sim.c`.
Frontend compilation used the repository SDK's common include directory.

These are compiler/verifier and output-equivalence checks; no new emulator run
is claimed. Local scripts, MIR outputs, assembly outputs, and logs are under
`build/0028-refactor/`.

## Compile-time check

The same 24 IR inputs were compiled with alternating binary order. One warm-up
round was discarded; medians use child user plus system CPU time per corpus run.

| Measurement | Boolean-parameter version | Local-state helper | Change |
|---|---:|---:|---:|
| Full code generation, upstream build running; 7 measured rounds | 1.660153 s | 1.689106 s | +1.74% |
| Stop after rewriter, upstream build paused; 11 measured rounds | 1.084543 s | 1.060243 s | -2.24% |

The second run did not reproduce the apparent slowdown. These timings do not
establish a performance improvement or rule out very small costs; results are
subject to scheduling and frequency noise. They provide no consistent evidence
of a slowdown from this extraction. [Inputs and raw timings](0028-timing.json).

## Scope limits

The available compiler builds contain only the MOS target. ARM, AArch64, and
AMDGPU rewriter tests cannot run with them, including the target-specific
deferred-allocation coverage. The deferred-allocation guard and its ordering were
preserved by source inspection. No all-target LLVM suite result is claimed.

New and moved source/test comments were checked with the repository's comment
history checker functions and reviewed for the current-contract rule.
