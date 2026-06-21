# #320 (a) far function pointers — typed `far_fn_t` variable surface (F2 follow-up)

**Date:** 2026-06-21 · **Issue:** #320 (a) · **Worktree:** `wt/320-far-followups`
(`/home/will/SRC/llvm-mos-65816-far-followups`) · **Builds on:** today's F2 (the `far`/`long_call`
function attribute + direct-call rewrite, worktree `285197d`).

## Goal

Let a **stored** far function pointer work in single-file C:

```c
typedef uint8_t (*far_fn_t)(uint8_t) __attribute__((far));
far_fn_t fp = far_leaf;        // fp holds far_leaf's 24-bit address (a p2 / ptr addrspace(2))
corpus_result = fp(0x5A);      // indirect far call -> stash 24-bit target + JSL __call_indir_far
```

Today's F2 only handles a **direct** call to a `far`-attributed function (`far_leaf(0x5A)`). It rides the
function *decl* and intercepts at the call site. The typed-variable surface needs the far-ness to ride the
function-pointer *type* so the variable `fp` is a 32-bit far pointer and the indirect call through it is
rewritten. Both surfaces must end up at the same proven IR:

```
store volatile i32 ptrtoint(<24-bit target>), @__mos_far_target
%r = call <ret> @__call_indir_far(<args>)
```

## Design (recon-validated 2026-06-21)

Carry "far" as a new **bit on the canonical `FunctionType::ExtInfo`** (like `cmseNSCall`). This survives
canonicalization (the AttributedType sugar is stripped by `ConvertType`, but the ExtInfo bit is on the
canonical type), so both `ConvertType` (to size the variable) and the call site (to detect far-ness) can read
it. A far-attributed function-pointer type then lowers to `ptr addrspace(2)` (32-bit, the far data-pointer AS)
— giving `fp` a 4-byte IR slot that holds the full 24-bit address. `fp = far_leaf` materializes the p2 alias
address; `fp(x)` ptrtoints the loaded `fp` into the runtime slot and calls the thunk.

**Why an ExtInfo bit (not a far-fn-ptr value type / not addrspace on the function type):** function types
can't be address-space-qualified (clang forbids it); an addrspacecast AS0→AS2 zero-extends and drops the
bank. The ExtInfo bit is a clang-side flag that drives an IR rewrite, never an AS-qualified function type.

**`getPointerWidthV(AS2)` stays 16 (deferred):** the IR width of a far pointer comes from the datalayout
(`p2:32:8` → 4 bytes), *not* `getPointerWidthV`. A local `fp` used immediately never reads `getPointerWidthV`
(it feeds only C-level `sizeof`/struct-field layout/array strides/debug-info), and pointers are always
ABI-direct (the `>32` indirect threshold is inside `isAggregateTypeForABI`, never reached by a pointer), so
the existing far **data**-pointer tests (far_cast/far_indir/far_store/far_arith) are unaffected. Changing it
to 32 is **future work** needed only when a far pointer is `sizeof`'d, stored as a struct field/array element,
pointer-arithmetic'd, or passed/returned by value — see Layer F.

## Layers

### Layer A — carry the `far` bit on canonical `FunctionType::ExtInfo`
All in `clang/include/clang/AST/TypeBase.h` unless noted. Mirror `cmseNSCall` (the newest flag) verbatim.
- **(blocker)** `FunctionTypeBitfields` (~2029): `unsigned ExtInfo : 14;` → `: 15`. The canonical store
  clips to 14 bits today, so a bit-14 (`0x4000`) flag is silently truncated without this. (NumParams:16
  shares the word; total stays ≤ 64.)
- `ExtInfo` class (~4664): add `enum { FarMask = 0x4000 };`, `bool getFar() const`, `ExtInfo withFar(bool)`
  (clone `withCmseNSCall` ~4749); add a trailing `bool Far=false` param to the 8-arg ctor (~4689) ORing in
  `FarMask`; update the bit-map comment (~4671). Add `bool getFarAttr() const` on `FunctionType` (~4907,
  mirror `getCmseNSCallAttr`).
- **(mandatory serialization)** `clang/include/clang/AST/TypeProperties.td`: add
  `def : Property<"far", Bool> { let Read = [{ node->getExtInfo().getFar() }]; }` in the FunctionType block
  (~300) and pass `far` as the new last arg in **both** Creator blocks (~305 FunctionNoProtoType, ~351
  FunctionProtoType). ExtInfo is (de)serialized **field-by-field** here (not raw bits), so omitting this
  silently drops the bit across PCH/modules.
- **(recommended)** `clang/lib/AST/ASTContext.cpp` `mergeFunctionTypes` (~11547):
  `if (lbaseInfo.getFar() != rbaseInfo.getFar()) return {};` so a far / non-far redecl doesn't silently merge.
- **(optional)** `clang/lib/AST/TypePrinter.cpp` `printFunctionAfter` (~1204): print
  `__attribute__((far))` when `Info.getFar()` for `-ast-print` parity.
- **No change needed:** `FunctionType::Profile`/`ExtInfo::Profile` hash the raw `Bits` (the bit rides free);
  `adjustFunctionType` round-trips ExtInfo; `ASTImporter` copies ExtInfo wholesale.

### Layer B — Sema: make `far` ride the function-pointer type
- `clang/include/clang/Basic/Attr.td` (`MOSFarCall`): `InheritableAttr` → `DeclOrTypeAttr`. Auto-sets
  `IsType=1` (so the type pass considers it) while keeping decl-merge codegen (so it still attaches to a
  function *decl* — preserves today's F2 direct-call path, which keys on `FD->hasAttr<MOSFarCallAttr>()`).
  Keep `Subjects=[Function]`, `ParseKind="LongCall"`, the spellings. (FastCall is the living precedent: a
  `DeclOrTypeAttr` that still reaches the decl handler.)
- `clang/lib/Sema/SemaType.cpp`: add `case ParsedAttr::AT_LongCall:` to `FUNCTION_TYPE_ATTRS_CASELIST`
  (~149) so `processTypeAttrs`/`distributeTypeAttrsFromDeclarator` route it into the type pass; add an
  `AT_LongCall` branch in `handleFunctionTypeAttr` (~8029) cloned from the `AT_CmseNSCall` block (~8070):
  delay-if-`!unwrapped.isFunctionType()`, **gate on MOS** (`...getTriple().getArch() == llvm::Triple::mos`;
  non-MOS → `return false` so Mips falls through to decl handling unchanged), `EI =
  unwrapped.get()->getExtInfo().withFar(true)`, wrap in an AttributedType
  (`state.getAttributedType(createSimpleAttr<MOSFarCallAttr>(...), type, unwrapped.wrap(S,
  adjustFunctionType(unwrapped.get(), EI)))`).
- The decl-side dispatch (`handleLongCallAttr`, `case AT_LongCall` in `ProcessDeclAttribute`) is **unchanged**
  — a `far` function decl still gets its `MOSFarCallAttr`.

### Layer C — `ConvertType`: pointer-to-far-function → `ptr addrspace(2)`
- `clang/lib/CodeGen/CodeGenTypes.cpp` `Type::Pointer` case (~646): after `unsigned AS =
  getTargetAddressSpace(ETy);`, add: if `ETy->getAs<FunctionType>()` has `getExtInfo().getFar()`, set
  `AS = Context.getTargetAddressSpace(<far LangAS = FirstTargetAddressSpace + 2>)` (= 2). (`getTargetAddressSpace`
  special-cases a bare function pointee → program AS 0, so override here, mirroring the `Type::BlockPointer`
  precedent ~745.) ETy is canonical here, so the far ExtInfo bit is visible.

### Layer D — `fp = far_leaf` materializes the p2 alias address
- Refactor today's `emitMOSFarIndirectCallee` (CGExpr.cpp) into two reusable pieces:
  - `CodeGenModule::getMOSFarDataAlias(StringRef Sym) -> llvm::GlobalVariable*` — the `.set __mos_far_<sym>`
    module-asm + the `external addrspace(2) constant i8` global (idempotent via `getNamedGlobal`). A CGM
    method so `CGExprScalar.cpp` (different TU) can call it.
  - `emitMOSFarStashAndThunk(CGF, FnInfo, llvm::Value *targetI32) -> CGCallee` — the volatile store of
    `targetI32` into `@__mos_far_target` + the `__call_indir_far` thunk callee. Both call sites share it.
- `clang/lib/CodeGen/CGExprScalar.cpp` `CK_FunctionToPointerDecay` (~2899): if the cast's destination type's
  pointee `FunctionType` has `getExtInfo().getFar()`, return
  `ptrtoint`-free the AS2 alias *pointer* value (`CGM.getMOSFarDataAlias(<mangled sym of the decayed
  FunctionDecl>)`) instead of `EmitLValue(E).getPointer()` (the AS0 address). The result is a
  `ptr addrspace(2)` stored into `fp`. (A direct `far_leaf(0x5A)` is looked through by `EmitCallee` before
  any scalar emission, so it never hits this path — no regression.)

### Layer E — `fp(x)` indirect far call
- `clang/lib/CodeGen/CGExpr.cpp` `EmitCall(QualType,...)`: alongside today's direct intercept (keyed on a far
  `FunctionDecl` `TargetDecl`), add an **else** branch keyed on the callee expression's type: if
  `PointeeType->getAs<FunctionProtoType>()->getExtInfo().getFar()` **and** the direct branch didn't fire,
  `ptrtoint` the loaded `Callee.getFunctionPointer()` (an AS2 ptr → i32) and call `emitMOSFarStashAndThunk`.
  Placement stays where today's intercept is (after `EmitCallArgs`, immediately before the inner `EmitCall`)
  so the volatile store can't be clobbered by a nested far call in an argument.

### Layer F — `getPointerWidthV(AS2)` → 32 — DEFERRED (future)
Not needed for the e2e (see Design). Needed for: `sizeof(far_fn_t)`==4, far pointers as struct fields/array
elements, far-pointer arithmetic, far pointers passed/returned by value. Track separately with the existing
`sizeof(far*)==4` TODO item.

## Test

New `examples/65816/far_fnptr_var.c` + `dev/far_fnptr_var.sh` (mirror `far_fnptr.sh`, wire into `dev/run.sh`
+ `dev/xcheck.sh`): the typed-variable surface above. `far_leaf` stays `section(".far_text")` (RTL return).
Keep `far_fnptr.c` (direct surface) as-is — both must pass.

## Build / verify (two phases to isolate the type machinery from codegen)

**Phase 1 (Layers A–C):** rebuild (`dev/run.sh toolchain`; confirm `clang-23` mtime advanced). Verify:
1. A far function type round-trips (compile a TU with `far_fn_t`; no crash; `-ast-print` shows the qualifier
   if TypePrinter wired).
2. `far_fn_t fp;` lowers `fp` to `alloca ptr addrspace(2)` (`-emit-llvm`), proving Layers A+B+C.
3. PCH round-trip smoke (`-emit-pch` + `-include-pch`) preserves the far bit (Layer A serialization).

**Phase 2 (Layers D–E):** rebuild. Verify:
4. `far_fn_t fp = far_leaf; corpus_result = fp(0x5A);` emits the proven shape
   (`store volatile i32 ptrtoint(...), @__mos_far_target` + `call @__call_indir_far`), `-verify-machineinstrs`
   clean, disasm shows `R_MOS_ADDR24_BANK` + `jsl __call_indir_far` + far_leaf `rtl`.
5. e2e `dev/run.sh far_fnptr_var` → `0xFF` on MAME; `dev/run.sh xcheck` (bsnes-jg) agrees.
6. Regression: `dev/run.sh far_fnptr` (direct surface still PASS), corpus 7/7, far_near_call, csmith
   0-mismatch, a16unmerge — proves the type-system + codegen changes are inert for all non-`far` code.

## Landing

Same as F2: gitignored `vendor/` recipes, land in `0001` once `0004`'s relationship to `main` settles. The
new ExtInfo bit + Sema/CodeGen edits touch only `clang/`. The `far_fnptr_var.c` test + this plan commit on
the worktree.

## Result — DONE (2026-06-21)

Built in two phases as planned; all layers landed. The typed-variable surface works end-to-end.

**Phase 1 (Layers A–C) — type machinery, verified before adding codegen:**
- `far_fn_t` lowers a variable/param to **`ptr addrspace(2)`** (`@g_fp = global ptr addrspace(2)`), `near_fn_t`
  to `ptr` (AS0) — the far bit rides the typedef, survives canonicalization, and `ConvertType` maps it to AS2.
- The far `ExtInfo` bit **survives PCH** (`-emit-pch` + `-include-pch` → `g_fp` still `ptr addrspace(2)`) —
  the `TypeProperties.td` field-by-field serialization is correct.
- far_fnptr.c (direct surface) unchanged.
- A spurious `-Wignored-attributes` "only applies to functions" on a far function-pointer typedef was fixed
  by dropping `MOSFarCall`'s `Subjects` (mirroring the CC `DeclOrTypeAttr`s like FastCall, which have none);
  the type pass enforces the function-type requirement. Validated with `clang-tblgen` (the merged
  `ParsedAttrInfoLongCall` no longer emits a `diagAppertainsToDecl`).

**Phase 2 (Layers D–E) — value materialization + indirect call:**
- `far_fn_t fp = far_leaf; corpus_result = fp(0x5A);` compiles **clean (no warnings)** and, after `-Os`, folds
  to the *exact* proven shape (`store volatile i32 ptrtoint(ptr addrspace(2) @__mos_far_far_leaf), @__mos_far_target`
  + `call @__call_indir_far`); `-verify-machineinstrs` clean; disasm shows `R_MOS_ADDR24_BANK` +
  `jsl __call_indir_far` + far_leaf `rtl`.
- **e2e `far_fnptr_var.c`: `far_leaf(0x5A)==0xFF` on MAME + bsnes-jg** (`dev/run.sh far_fnptr_var`, `xcheck`),
  far_leaf in bank `$01`. Differential bar met (host == a16@MAME == a16@bsnes-jg), a16-only (no default leg).

**Regression-clean:** far_fnptr (direct) **0xFF**, corpus **7/7**, far_near_call **0xE0**, a16unmerge,
xcheck (far_fnptr + far_fnptr_var + all far ROMs), csmith **0 mismatch** — the AST `ExtInfo` bit + `ConvertType`
arm + Sema/CodeGen edits are inert for all non-`far` code (the far bit defaults to 0).

**Layer F (`getPointerWidthV(AS2)`→32) remains deferred** — not needed here; tracked for the aggregate/
stored-far-pointer follow-up.

**Files (gitignored `vendor/` recipes; land in `0001` with F2 once `0004` settles):**
`TypeBase.h` (ExtInfo `:15` + `FarMask`/`getFar`/`withFar`/ctor/`getFarAttr`), `TypeProperties.td` (`far`
Property + 2 Creators), `ASTContext.cpp` (`mergeFunctionTypes`), `TypePrinter.cpp`, `Attr.td` (`MOSFarCall` →
`DeclOrTypeAttr`, no `Subjects`), `SemaType.cpp` (`FUNCTION_TYPE_ATTRS_CASELIST` + `handleFunctionTypeAttr`
`AT_LongCall` branch), `CodeGenTypes.cpp` (`Type::Pointer` far→AS2 arm), `CodeGenModule.h`/`CGExpr.cpp`
(`getMOSFarDataAlias` + `emitMOSFarStashAndThunk` refactor + indirect-call branch), `CGExprScalar.cpp`
(`CK_FunctionToPointerDecay` far intercept). Tracked: `examples/65816/far_fnptr_var.c` + `dev/far_fnptr_var.sh`
+ `dev/run.sh`/`dev/xcheck.sh` wiring.

## Risks (from recon)

- **ExtInfo `:14`→`:15` is the make-or-break edit** — without it the bit truncates and the whole approach
  silently no-ops on canonical types.
- **TypeProperties.td is mandatory** (field-by-field serialization) — omit it and the bit drops across
  PCH/modules.
- **MOS-gate the SemaType branch** — `AT_LongCall` is shared with MipsLongCall (a plain InheritableAttr);
  the type-pass branch must `return false` on non-MOS so Mips `long_call` is byte-for-byte unchanged.
- **Direct/indirect double-fire** — the indirect branch must be `else`-gated on the direct branch (a direct
  far call whose type also carries the bit must store the slot once, not twice).
- **Stale-clang gotcha** — flipping `MOSFarCall` to `DeclOrTypeAttr` regenerates tablegen; confirm
  `clang-23` mtime advanced and `isTypeAttr()` is actually true before trusting the type pass.
