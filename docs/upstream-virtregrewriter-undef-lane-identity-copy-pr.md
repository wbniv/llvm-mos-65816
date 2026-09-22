# [CodeGen] Preserve undef-lane definitions in rewritten identity copies

## Summary

Keep a rewritten identity `COPY` as a `KILL` when its virtual source has an
undefined lane.

This was encountered while compiling C torture tests packaged as SNES demos with
our downstream-only `+mos-a16` / `+mos-xy16` features: the
[L-System Plant demo](https://biohack.net/snes/lsystem/), with a compiler reproducer
in `rcundef2.c`, and the
[Newton Fractal demo](https://biohack.net/snes/newton/), whose corpus witness is
`newton_sim.c`. These pages show the originating applications; the saved compiler
inputs and verifier diagnostics establish the failure. The compiler-generated
MIR from the L-system witness exhibits the verifier failure. The small regression
below is a deliberately constructed MIR model of that mechanism which also fails
on unmodified upstream MOS.

Register allocation can assign the source and destination of a full-register
copy to the same physical register. `VirtRegRewriter` normally deletes the
resulting identity copy. If the source has an undefined lane, deleting the copy
also removes the destination's liveness definition for that lane. A later
physical read then has no reaching definition, and MachineVerifier reports
`Using an undefined physical register`.

For example, the regression assigns both `%1` and `%2` to `$rs1`:

```mir
undef %1.sublo:imag16 = COPY %0
%2:imag16 = COPY %1
%3:gpr = COPY %2.sublo
%4:gpr = COPY %2.subhi
```

Before rewriting, the full copy defines `%2` at both extracts. After allocation,
the copy is `$rs1 = COPY $rs1`. Removing it leaves the `$rc3` extract undefined.

## Fix

Make `rewriteInstruction(MachineInstr &MI)` own the operand rewrite and
identity-copy cleanup. Before replacing virtual registers, it records whether a
`COPY` source has any lane without a live subrange at the instruction. After
rewriting, it retains a resulting physical identity copy as a `KILL` when that
definition is needed.

The lane information stays local to the instruction transformation; no extra
boolean parameter or persistent pass state is needed. The helper preserves the
existing handling for explicitly undef sources and implicit definitions, along
with copy-bundle ordering, deferred-allocation guards, and index bookkeeping.
The `KILL` preserves liveness information and emits no machine code.

## Test

Add a stock-MOS MIR regression that runs `greedy,virtregrewriter` with
MachineVerifier enabled. It checks that the allocated identity copy becomes
`$rs1 = KILL $rs1` and that both byte extracts verify.

The natural C-code trigger is established for the downstream native-width
compiler. For stock upstream, the evidence is this MIR-level reproducer; we have
not established a C program whose ordinary stock-upstream compilation produces
the same pattern. The test isolates the rewriter's liveness contract without
requiring the downstream features. It is not presented as an unchanged,
automatically reduced output of the C frontend.

A companion MIR test covers defined identity-copy removal, explicit undef and
implicit-definition preservation, parallel-copy bundle ordering, a defined
source subregister, and a non-identity copy with a partially undefined source.

Validation:

- On upstream `742d554bf080`, the regression fails without the patch and passes
  with it. The six companion copy-contract cases also pass on the unpatched base.
- MOS CodeGen suite: 85 passed, one explicitly unsupported test.
- Downstream undef-lane verifier gate: 34 configurations pass across four C
  witnesses under `+mos-a16` and `+mos-xy16`.
- Compared with the boolean-parameter version of the fix, 24 native-width corpus
  inputs produce byte-identical post-rewrite MIR and final assembly.

Validation performed September 21, 2026. The compiler builds contain only MOS;
no all-target LLVM suite result is claimed.
