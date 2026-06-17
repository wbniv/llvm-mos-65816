# Upstream issue draft — `__attribute__((reentrant))` cannot force the soft (reentrant) stack

> **Status: NOT filed.** Draft of an upstream llvm-mos *issue* (a design question / latent footgun, **not** a
> miscompile for ordinary C). Per the soft-stack plan this is filed as an **issue only — no fork patch is
> carried** (the safe behaviour for ordinary code is already correct). Surfaced while building #321
> soft-stack fuzzer coverage, but **independent of #321**.
> See [soft-stack plan §P3](plans/2026-06-16-321-soft-stack-spill-coverage.md).

| | |
|---|---|
| **Project** | [`llvm-mos/llvm-mos`](https://github.com/llvm-mos/llvm-mos) (clang front end + LLVM MOS backend) |
| **Kind** | latent footgun / design question — not a miscompile for ordinary (single-activation) C |
| **Components** | `clang/lib/CodeGen/CodeGenModule.cpp`, `llvm/lib/Target/MOS/MOSNonReentrant.cpp`, `llvm/lib/Target/MOS/MOSFrameLowering.cpp` |
| **Verified against** | current vendor tree (rolling `main`) — cited by symbol/quote since line numbers drift |
| **Fork patch** | **none, intentionally** — issue only |
| **File it** | `gh issue create --repo llvm-mos/llvm-mos --title "<title below>" --body-file <this file, status block stripped>` |

---

## Title

```
[MOS] __attribute__((reentrant)) is a no-op for non-recursive functions — cannot force the soft stack
```

## Summary

clang accepts `__attribute__((reentrant))` and it correctly opts a function **out of** the `-fnonreentrant`
global default. But it **cannot force an individual, otherwise-non-recursive function onto the reentrant
(soft) stack**: the MOS `nonreentrant` pass re-derives the `nonreentrant` attribute from `norecurse` and
re-stamps the function regardless of the source attribute. A user who marks a function `reentrant` because
they know it can re-enter through a path the IR call graph cannot see — an inline-asm-installed ISR, a
hand-rolled coroutine / manual stack switch, or `longjmp` re-entry — silently gets a **static** frame, which
the second activation clobbers. No diagnostic; runtime data corruption.

## Mechanism

Walk a non-recursive function `f` marked `__attribute__((reentrant))` through the pipeline:

**1. clang — `reentrant` emits no positive IR marker, it only suppresses the default.**
`CodeGenModule.cpp`, the `nonreentrant` lowering:

```cpp
if (D->hasAttr<NonReentrantAttr>() ||
    (CodeGenOpts.AssumeNonReentrant && !D->hasAttr<ReentrantAttr>()))
  B.addAttribute("nonreentrant");
```

`ReentrantAttr` appears only as `!D->hasAttr<ReentrantAttr>()`, gating the `-fnonreentrant`
(`AssumeNonReentrant`) default. After clang, `f` has **no** `nonreentrant` IR attribute — and no positive
`reentrant` marker either. So far it looks like `f` will get a soft frame.

**2. LLVM infers `norecurse`.** `f` is provably non-recursive, so `f->doesNotRecurse()` becomes true (via
the standard FunctionAttrs inference, and reaffirmed by this pass's own bottom-up SCC walk / `callsSelf`).

**3. `MOSNonReentrant` re-stamps `nonreentrant`.** `MOSNonReentrantImpl::run()`, the final loop:

```cpp
// Make all norecurse functions that were not determined to be reentrant as
// nonreentrant.
for (Function &F : M.functions())
  if (F.doesNotRecurse() && !Reentrant.contains(CG[&F]))
    F.addFnAttr("nonreentrant");
```

The `Reentrant` set is seeded **only** from interrupt reachability, `interrupt-norecurse`/`main`, and
libcalls (earlier in the same `run()`), **never** from a source-level `reentrant` attribute. So `f`
(norecurse, not in `Reentrant`) has `nonreentrant` **re-added** here.

**4. Frame lowering picks the static frame.** `MOSFrameLowering::usesStaticStack`:

```cpp
bool MOSFrameLowering::usesStaticStack(const MachineFunction &MF) const {
  return MF.getSubtarget<MOSSubtarget>().staticStack() &&
         !MF.getFunction().hasOptNone() &&
         MF.getFunction().hasFnAttribute("nonreentrant");
}
```

`f` now has `nonreentrant`, so it gets a **static** frame. The `reentrant` attribute had no effect.

## Why it matters — and why it is *not* a miscompile for ordinary C

For ordinary C this is **safe**: a provably single-activation (`norecurse`) function is fine with a static
frame even when labelled `reentrant`, because the static frame is never live twice. The footgun is for
functions that genuinely re-enter through a mechanism LLVM's call-graph analysis cannot observe, so it still
proves `norecurse`:

- an **interrupt handler installed via inline asm** (no `interrupt` attribute / IR edge),
- a **hand-rolled coroutine or manual stack switch**,
- **`longjmp` back into a frame** that is still notionally active.

The user reaches for `__attribute__((reentrant))` to request a reentrant frame for exactly these cases, the
attribute is silently a no-op, and the static frame is clobbered on re-entry — runtime corruption with no
diagnostic.

The other soft-stack triggers all work today: genuine recursion and mutual recursion defeat `norecurse`,
`interrupt` reachability seeds `Reentrant`, and `-O0`/`optnone` fails the `!hasOptNone()` guard. `reentrant`
is the one documented-looking lever that does **not**.

## Question for maintainers

Is this intended — i.e. is `reentrant` meant purely as "opt out of `-fnonreentrant`", with "force a soft
frame on an otherwise-`norecurse` function" simply unsupported? Or should `reentrant` force the reentrant
stack? If the front-end attribute is accepted, the silent no-op is at least a documentation gap; at most a
small backend fix.

## Sketch of a fix (only if `reentrant` should force the soft stack)

Localized, two parts:

1. **clang** — emit a positive IR marker for the attribute (near the `nonreentrant` lowering in
   `CodeGenModule.cpp`):

   ```cpp
   if (D->hasAttr<ReentrantAttr>())
     B.addAttribute("reentrant");
   ```

2. **`MOSNonReentrant`** — seed `Reentrant` from it, so the re-stamp loop skips such functions. Near the top
   of `MOSNonReentrantImpl::run()`:

   ```cpp
   for (Function &F : M.functions())
     if (F.hasFnAttribute("reentrant"))
       Reentrant.insert(CG[&F]);
   ```

   (Equivalently, add `&& !F.hasFnAttribute("reentrant")` to the final stamping condition.)

Marking a single-activation function `reentrant` then merely costs a soft frame it does not strictly need —
the safe direction (never the reverse, which would clobber). This is a sketch for discussion, not a
submitted patch.

## Provenance

Found while building differential-fuzzer coverage of the WDC 65816 16-bit-accumulator (`+mos-a16`)
soft-stack spill path. We needed the fuzzer to land generated functions on the soft stack; `reentrant`
could not do it, so we used genuine recursion as the trigger instead — which is what surfaced this.
Recording it upstream so it is not re-discovered from scratch.
