# #320 (a) far pointers — `sizeof(far*) == 4` (Layer F: `getPointerWidthV(AS2)` → 32)

**Date:** 2026-06-21 · **Issue:** #320 (a) · **Worktree:** `wt/320-far-followups` · **Builds on:** the typed
far-fn-ptr variable surface ([plan](2026-06-21-320-far-fnptr-typed-variable.md), Layer F was deferred there).

## Goal

Make clang's **C-level** size of a far pointer match its IR width. Today
`MOSTargetInfo::getPointerWidthV(AS2)` returns **16**, so `sizeof(FAR T*) == 2` and
`sizeof(far_fn_t) == 2` — but the LLVM datalayout is `p2:32:8`, so the IR pointer is **4 bytes**. A far
pointer used as a bare local value works anyway (the IR/datalayout drives the alloca/store width), which is
why the typed-variable e2e shipped with this unchanged. The mismatch only bites when the **C-level size**
is load-bearing:

1. `sizeof(FAR T*)` / `_Alignof` must report 4.
2. A far pointer stored as a **struct field or array element**: clang reserves 2 bytes for it but the IR
   store writes 4 — a layout corruption (the next field is clobbered).
3. Far-pointer arithmetic / `ptrdiff_t` at the C level.
4. A far pointer **passed/returned by value** across a function boundary (clang `sizeof` 16 vs the ABI's
   32-bit IR coercion).

## Change (two arms)

A far **data** pointer (`FAR void*`) carries `address_space(2)` on its pointee, so its size flows from the
target AS width. A far **function** pointer (`far_fn_t`) carries its far-ness as the `FunctionType::ExtInfo`
far bit (function types can't be AS-qualified), so the pointee reports the *default* AS — both the C-level
`sizeof` and the IR `ConvertType` have to special-case it. We fixed the IR side already (the typed-variable
work's `ConvertType` `Type::Pointer` arm → `ptr addrspace(2)`); this layer fixes the C-level side to match.

1. **`lib/Basic/Targets/MOS.cpp` `getPointerWidthV(LangAS)`** — return **32** for the far AS (target AS 2),
   alongside the existing `case 1` (zero page → 8). Fixes far **data** pointers (`sizeof(FAR void*) == 4`).
   Alignment is already correct (`PointerAlign = 8` = 1 byte, matches `p2:32:8`; no `getPointerAlignV`
   override).
   ```cpp
   case 1: return 8;   // zero page
   case 2: return 32;  // Far: 24-bit address in a 32-bit pointer (p2:32:8). #320.
   default: return 16;
   ```
2. **`lib/AST/ASTContext.cpp` `getTypeInfoImpl` `Type::Pointer` case** — if the pointee is a far-attributed
   `FunctionType` (`getExtInfo().getFar()`), use the far AS (`getLangASFromTargetAS(2)`) for the width/align,
   mirroring the `ConvertType` arm. Fixes far **function** pointers (`sizeof(far_fn_t) == 4`) — without this,
   `sizeof(far_fn_t)` stayed 2 even after arm 1, since the far fn-ptr pointee reports the default AS.

## Blast radius (why this is safe)

- **AS2 is far-only.** `getPointerWidthV(AS2)` is read *only* for `addrspace(2)` pointer types, which only
  far data/function pointers ever have. **Non-`far` code never sees AS2**, so the change is inert for the
  whole corpus / csmith / torture suites (proven by the differential fuzzer).
- **Existing far-data tests are value-level.** `far_cast`/`far_store`/`far_indir`/`far_arith` and
  `far_fnptr`/`far_fnptr_var` pass far pointers as runtime values (`lda [dp]`, `fp++`, a JSL'd thunk), never
  stored in an aggregate or passed/returned by value, so `sizeof` does not enter their codegen. They must
  stay byte-identical.
- **Pointer arithmetic stride is the POINTEE size**, not the pointer size, so `far_arith` (`fp++` on a
  `FAR uint8_t*`) is unaffected.
- This is the fix the existing TODO item ("`sizeof(far*)==2`, clang `getPointerWidthV` lacks …") names.

## Test

New `examples/65816/far_sizeof.c` + `dev/far_sizeof.sh` (wire into `dev/run.sh` + `dev/xcheck.sh`): exercise
the cases the size change unlocks, on real silicon —
- `_Static_assert(sizeof(FAR void*) == 4)` and `sizeof(far_fn_t) == 4` (compile-time gate).
- A **stored** far pointer that only lays out correctly at size 4: e.g. a small struct
  `{ FAR const uint8_t *p; uint8_t tag; }` (or a 2-element far-pointer array) written then read back, with a
  `corpus_result` that would be wrong if `p` were 2 bytes (the IR 4-byte store would clobber `tag`). Deref
  the stored far pointer and combine with `tag` so the asserted value proves both the pointer survived and
  the adjacent field was not clobbered.
- a16-gated like the other far tests (32-bit far value legalization).

## Verification

**All steps PASS (2026-06-21)** — raw evidence consolidated in *Result — DONE* below.

1. `_Static_assert(sizeof(FAR void*) == 4 && sizeof(far_fn_t) == 4)` compiles (was 2 before). **PASS.**
2. `dev/run.sh far_sizeof` → expected value on MAME; `dev/run.sh xcheck` (bsnes-jg) agrees.
3. **No regression** — every existing far test byte-identical / same verdict:
   `dev/run.sh far_cast|far_store|far_indir|far_arith|far_call|far_near_call|far_fnptr|far_fnptr_var`,
   `xcheck` all far ROMs.
4. corpus **7/7**; csmith differential fuzz **0 mismatch** (AS2-only ⇒ inert for non-`far`).
5. `-verify-machineinstrs` clean on far_sizeof.

## Result — DONE (2026-06-21)

Both arms landed; `sizeof(FAR void*) == 4` **and** `sizeof(far_fn_t) == 4` (the function-pointer arm in
`getTypeInfoImpl` was necessary — arm 1 alone left far fn ptrs at 2, since their far-ness is an `ExtInfo`
bit). `far_sizeof.c` e2e: a far pointer in a struct field (`%struct.holder = { ptr addrspace(2), i8 }`, tag
at offset 4) derefs (`lda [dp]`) to **0xD1** on **MAME + bsnes-jg**, adjacent field intact;
`-verify-machineinstrs` clean. Regression: far_fnptr/far_fnptr_var **0xFF**, far_call **0xF3**, far_near_call
**0xE0**, far_cast/store/arith **0xF3**, corpus **7/7**, **csmith 0-mismatch** (the AS2-only width change is
inert for non-`far` code).

### Pre-existing crash surfaced + fixed: `far_indir` (`isFarSymbol` over-fire)
Running `far_indir` (the first time this session — its build had been silently failing in the xcheck loop)
revealed a compiler **SIGSEGV** — **proven pre-existing** (it still crashed with this layer's sizeof change
reverted; a minimal repro uses none of the far-pointer features; the LLVM backend was untouched all session,
so it dates to ≥ `579b911`). **Root cause:** `MOSInstructionSelector.cpp` `isFarSymbol` treated **any**
`.far*`-sectioned symbol as far, including `.far_rodata` **data**; far_indir deliberately takes
`&bank1_sentinel` as a **near** 16-bit address (it OR's in the bank by hand), so it over-triggered 24-bit
materialization (`buildFarAddrWords`/`selectAddrLoHi`) into a 16-bit context → crash. **Fix:** restrict the
`.far*` section check to **functions** (`isa<Function>(GO)`) — far `.far_text` functions stay far (far_fnptr
unaffected; bank reloc preserved), far **data** must opt in via `address_space(2)` (the `AS_Far` check), and a
plain (AS0) `.far_rodata` datum taken as a near pointer keeps a near 16-bit address. far_indir now
**0xF3** (compiles, `-verify-machineinstrs` clean, MAME + bsnes-jg). Gitignored `vendor/` recipe (recorded in
the far-calls-followups plan §6 Gap A); user-approved fix-now (2026-06-21).

## Landing

Same as F2 / the typed-variable work: the `getPointerWidthV` edit is a gitignored `vendor/` recipe (recorded
here); the `far_sizeof.c` test + this plan are tracked on the worktree. Lands in `0001` with the rest of (a)
once `0004`'s relationship to `main` settles.

## Risk

- The change widens far-pointer **debug-info** width (correctly) to 32 — a harmless visible `-g` diff.
- If any *existing* far test stores a far pointer in an aggregate (it shouldn't — verify in step 3), its
  layout — and verdict — would shift; that would be a *fix*, but treat any verdict change as a finding to
  explain, not silently accept.
