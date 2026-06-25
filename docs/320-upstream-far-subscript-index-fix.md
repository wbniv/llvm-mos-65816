# clang: array-subscript GEP index must use the base pointer's per-address-space index width

**Type:** code-change PR (clang front-end, generic `CGExpr.cpp`).
**Status:** drafted; **Future/blocked** — rides the #320 far-pointer PR (the address space it fixes,
`addrspace(2)` far, is fork-only and not upstream yet, so the bug is not reproducible upstream
standalone). Carried in-fork as part of `patches/llvm-mos/0001-320-far-addrspace.patch`.
**Posting is user-triggered.**

## The bug (silent miscompile)

`clang/lib/CodeGen/CGExpr.cpp`, `CodeGenFunction::EmitArraySubscriptExpr` → the `EmitIdxAfterBase`
lambda, promotes the GEP index to `IntPtrTy` — the **default address space's** pointer-width integer —
for *every* subscript, regardless of the base pointer's address space:

```cpp
// Extend or truncate the index type to 32 or 64-bits.
if (Promote && Idx->getType() != IntPtrTy)
  Idx = Builder.CreateIntCast(Idx, IntPtrTy, IdxSigned, "idxprom");
```

On a target whose address spaces have **different pointer widths**, a subscript through a pointer
*wider* than the default truncates the index. For the MOS 65816 far address space (`addrspace(2)`,
datalayout `p2:32:8`, `getPointerWidthV(AS2)==32`; default AS is 16-bit), `tbl[idx]` with
`int32 idx` lowers to:

```llvm
%2 = shl i32 %idx, 16
%3 = ashr exact i32 %2, 15          ; = sext_i16(idx) * 2   — index truncated to 16 bits
%4 = getelementptr inbounds i8, ptr addrspace(2) @tbl, i32 %3
```

So any index ≥ 32768 becomes "negative" and corrupts the high (bank) bits of the 24-bit far
address: far indexed loads silently only work within a single 64 KiB bank.

### Reproduction (fork, with the #320 far address space)

`examples/65816/farindex.c` on the HiROM platform `platforms/snes-hirom` — a `const FAR uint16_t tbl[]`
spanning banks $C1+, read at indices 100 / 50000 / 90000:

| index | offset | want addr | before fix | after fix |
|---|---|---|---|---|
| 100   | 200      | `$C100C8` ($C1) | `0x0064` ✓ | `0x0064` ✓ |
| 50000 | 100000   | `$C286A0` ($C2) | `0x0000` ✗ | `0xB0E9` ✓ |
| 90000 | 180000   | `$C3BF20` ($C3) | `0x5D5C` ✗ (≈ `tbl[90000 & 0xFFFF]`) | `0xFB06` ✓ |

## The fix

Promote the index to the **base pointer's address-space** index width, not the default `IntPtrTy`:

```cpp
if (Promote) {
  llvm::Type *PromoteTy = IntPtrTy;
  QualType BaseTy = E->getBase()->getType();
  QualType ElemTy;
  if (const PointerType *PT = BaseTy->getAs<PointerType>())
    ElemTy = PT->getPointeeType();
  else if (const ArrayType *AT = getContext().getAsArrayType(BaseTy))
    ElemTy = AT->getElementType();
  if (!ElemTy.isNull()) {
    unsigned TargetAS = getContext().getTargetAddressSpace(ElemTy.getAddressSpace());
    PromoteTy = CGM.getDataLayout().getIntPtrType(getLLVMContext(), TargetAS);
  }
  if (Idx->getType() != PromoteTy)
    Idx = Builder.CreateIntCast(Idx, PromoteTy, IdxSigned, "idxprom");
}
```

**Generically correct:** for single-pointer-width targets `getIntPtrType(TargetAS)` resolves to exactly
`IntPtrTy`, so their codegen is byte-identical. The behaviour only changes for an address space whose
pointer is **wider than the default** — i.e. MOS far (AS2). Narrower address spaces (MOS zp/AS1 8-bit,
packed/AS3 24-bit) already widened to the default harmlessly and are unaffected in practice. After the
fix the GEP carries the full `i32` index (`getelementptr inbounds [2 x i8], ptr addrspace(2) @tbl, i32 %idx`).

## Verification

- `examples/65816/farindex.c` (above) — all three banks read correctly.
- `dev/run.sh k_trig32lut` — libfixmath's ~200 KiB accurate sin LUT in far rodata folds to
  `corpus_result == 0x87F0B404`, host == `+mos-a16` on **MAME + bsnes-jg**.
- Regression-clean: `k_hopalong` (near AS0 subscript) `0x1BBC`, `packed24` (AS3) `0xF3`, far suite
  (`far_indir/arith/call`) PASS, **corpus 7/7** on fixed-clang ROMs.
- `0001` round-trips (reapplying `0001..0007` == live vendor, MOS + clang).

## Posting

Rides the #320 far-pointer PR (it needs AS2 to exist upstream to be testable). When that PR is drafted
(after the design note opens the ABI-blessing discussion), this `CGExpr.cpp` hunk is part of it, with a
`-target mos -mcpu=mosw65816` CodeGen lit test asserting the GEP index is `i32` for an `addrspace(2)`
subscript. If a standalone upstream-LLVM submission is ever wanted, the test would use a synthetic
datalayout/triple whose default pointer is narrower than a non-default AS.

```sh
# (future, after #320 is unblocked) — part of the far-pointer PR, not a standalone post.
# gh pr create --repo llvm-mos/llvm-mos --head wbniv:<far-pointer-branch> --base main ...
```
