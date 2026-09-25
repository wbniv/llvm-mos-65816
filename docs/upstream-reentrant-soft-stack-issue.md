# Reentrant attribute: opt-out or a forced reentrant frame?

**Assessment updated 2026-09-25. Not posted; no fix proposed until the contract is agreed.**
Target: `llvm-mos/llvm-mos` (clang attribute lowering and MOSNonReentrant).

## Proposed issue title

`[MOS] Clarify whether __attribute__((reentrant)) must prevent inferred nonreentrant allocation`

## Confirmed behavior

The attribute cancels the `-fnonreentrant` default in clang. It does not emit a
positive `reentrant` IR attribute. Later, `MOSNonReentrant` can add `nonreentrant`
when it proves the function does not recurse and does not classify it as interrupt
reachable. Thus the attribute does not force a soft-stack frame for an otherwise
provably non-reentrant function.

The saved upstream source inspected on 2026-09-22 confirms both steps:

- [CodeGenModule.cpp](https://github.com/llvm-mos/llvm-mos/blob/742d554bf08042b8df93d791c335260fadd16643/clang/lib/CodeGen/CodeGenModule.cpp):
  `ReentrantAttr` suppresses `AssumeNonReentrant`; there is no positive marker.
- [MOSNonReentrant.cpp](https://github.com/llvm-mos/llvm-mos/blob/742d554bf08042b8df93d791c335260fadd16643/llvm/lib/Target/MOS/MOSNonReentrant.cpp):
  the final loop adds `nonreentrant` to `doesNotRecurse()` functions outside its
  reentrant set.
- [Attr.td](https://github.com/llvm-mos/llvm-mos/blob/742d554bf08042b8df93d791c335260fadd16643/clang/include/clang/Basic/Attr.td):
  the attribute is explicitly classified `Undocumented`.

[Original issue #248](https://github.com/llvm-mos/llvm-mos/issues/248) motivated a
per-function opt-out from a translation-unit assumption. That history supports
asking about intent before declaring the present behavior a compiler defect.

## Small reproducer

[reentrant.c](investigations/repro/upstream-issues-2026-09-20/reentrant.c) has two
otherwise-identical functions with volatile local arrays, one annotated reentrant.

```sh
mos-clang --target=mos -mcpu=mos6502 -O1 -fnonreentrant \
  -S -emit-llvm reentrant.c -o reentrant.ll
opt -passes=mos-nonreentrant,verify -S reentrant.ll -o reentrant-after.ll
```

The September 22 experiment uses the
[saved unpatched upstream Clang and opt](upstream-reference-build.md), both built
at `742d554bf080`. Clang emits `norecurse` on both functions; only the unannotated
function initially has `nonreentrant`. Running the pass adds `nonreentrant` to
the annotated function too; both functions then share the same attribute set.
No IR editing or downstream frontend is needed for this result. The reference
build has assertions disabled; the `verify` pass checks the resulting IR.
The emitted IR is saved in `build/upstream-ready-2026-09-22/reentrant.ll` and
`reentrant-after.ll`.

## Current local reproduction (2026-09-25, OpenAI Codex)

The rebuilt project compiler reproduces the same behavior for mos6502 and
mosw65816, with and without `-fnonreentrant`. The frontend opt-out is effective;
`mos-nonreentrant` subsequently marks both leaf functions nonreentrant. An
end-to-end mos6502 assembly check gives them the same four-byte static frame.
This refreshes the local behavior evidence, not the intended semantic contract.
[Full evidence](investigations/2026-09-25-older-defect-recheck.md) ·
[structured status](defects/reentrant-attribute-contract.json).
No issue was posted. Earlier investigation attribution is retained.

## What this does and does not establish

This proves the attribute is not a force-soft-stack switch. It does **not** prove
miscompilation of an ordinary C program, or that compiler-visible interrupts are
mishandled. The pass explicitly models interrupt reachability and conservatively
handles possible recursive calls.

A custom interrupt/coroutine mechanism invisible to that analysis is a motivating
use case for asking about a stronger contract, not a demonstrated supported-program
reproducer. Standard `longjmp` unwinds activations; it is not evidence of simultaneous
re-entry into the same active frame. No runtime-corruption claim is made here.

## Question and possible follow-up

Is the intended contract only to opt out of `-fnonreentrant`, allowing later proof
of non-reentrancy? If so, document that meaning and how users should describe custom
re-entry. If it must prohibit static allocation, preserve a positive marker and
respect it through analysis/frame selection, with frontend and backend tests.

The behavior of callees and zero-page allocation also needs agreement. Merely
skipping the final stamping condition may not supply the entire requested contract.
This is why the next artifact is a semantics report; a fix PR or documentation PR
can follow the answer.
