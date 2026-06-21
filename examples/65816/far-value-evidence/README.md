# Far-pointer value-type — compile evidence

Small, inspectable C programs that **demonstrate, by compiling (or failing to compile)**, exactly what
the far pointer (`addrspace 2`) can and can't do today. These back the claims in the five-address-space
plan ([`docs/plans/2026-06-21-320-five-address-space-model.md`](../../../docs/plans/2026-06-21-320-five-address-space-model.md))
and the upstream note ([`docs/320-upstream-far-pointer-note.md`](../../../docs/320-upstream-far-pointer-note.md)).

> ⚠ These are **evidence fixtures, not green tests** — several *intentionally fail to compile*. They are
> in their own subdirectory so the test harness (`examples/65816/*.c`) does not run them.

**Reproduce:** `dev/measure-far-ptr-value-state.sh` (compiles every file below, both default and
`+mos-a16`). Toolchain used here: `mos-clang` @ `c798c31`. Per-file command:

```
mos-clang --target=mos -mcpu=mosw65816 -Os -std=c23 -mllvm -verify-machineinstrs \
  [-Xclang -target-feature -Xclang +mos-a16] -c <file>.c -o /dev/null
```

## Results

| file | demonstrates | default | +mos-a16 |
|------|--------------|---------|----------|
| `t1_deref_const_far.c` | deref a **constant** far address | **OK** | **OK** |
| `t2_near_to_far.c` | near→far cast + deref (transient) | no-legalize | **OK** |
| `m1_bitint24.c` | a genuine **24-bit value** through GISel | **OK** | **OK** |
| `s1_store_far_global.c` | **store** a far ptr → global | verify-FAIL | verify-FAIL |
| `s2_load_far_global.c` | **load** a far ptr ← global | no-legalize | no-legalize |
| `s3_array_far.c` | **array** of far ptrs | no-legalize | no-legalize |
| `s4_struct_far.c` | far ptr **struct field** | no-legalize | no-legalize |
| `c1_far_to_near.c` | far→near narrowing cast | verify-FAIL | verify-FAIL |
| `c2_dp_to_near.c` | dp→near cast (can **segfault** w/o `-verify`) | verify-FAIL | verify-FAIL |
| `z1_sizeof.c` | `sizeof(far*)` | **`2 == 4`** ✗ | **`2 == 4`** ✗ |

**Reading:** a far pointer is a complete **address mechanism** (rows `t1`/`t2` — transient deref works,
`+mos-a16`-gated) but an **incomplete value type** (rows `s*` — can't be stored/loaded/aggregated;
`z1` — wrong `sizeof`; `c*` — narrowing casts fail). That gap is the *desirable* M1 far-pointer
completion work, not a dead end.

> **⏱ This table is the PRE-F2 snapshot** (`mos-clang` @ `c798c31`, before the far-fn-ptr "F2" agent's
> far-value work landed on `main`). **Post-F2** (`0001`+`0004`+`0005`): under **`+mos-a16`**, `s1`–`s4`
> (store/load/array/struct), `z1` (`sizeof==4`), and `c1` (far→near) all pass. Two residuals are tracked +
> closed in [`docs/plans/2026-06-22-320-far-value-residuals.md`](../../../docs/plans/2026-06-22-320-far-value-residuals.md):
> (a) **`c2` dp→near** is a pre-existing **upstream** bug (the 8-bit `addrspace(1)` pointer *argument* gets a
> 16-bit `RS` reg → illegal `COPY`; reproduces on plain `mos6502`) — filed upstream
> ([`docs/320-upstream-dp-arg-cc-issue.md`](../../../docs/320-upstream-dp-arg-cc-issue.md)); (b) the
> **default** column for `s*` stays FAIL **by design** — a far pointer's 32-bit `s32↔bytes` bridge is
> `+mos-a16`-gated, so 8-bit far storage is a clean compile-time `unable to legalize` rejection (no object,
> no miscompile).

## Verbatim failures (the storage gap)

`s1_store_far_global.c` — the `p2` value store isn't legalized:

```
G_STORE %0:_(p2), %3:_(p0) :: (store (p2) into @G, align 1, !tbaa !6)
# (-> "Found N machine code errors")
```

`s3_array_far.c` — and the symmetric load:

```
fatal error: error in backend: unable to legalize instruction:
  %8:_(p2) = G_LOAD %6:_(p0) :: (load (p2) from %ir.2, align 1) (in function: r)
```

## Why this means we do **not** need `MVT::i24`

`m1_bitint24.c` is the proof. A genuine 24-bit value compiles clean (both modes) and lowers to a
**3× byte** path — no 24-bit register, no `MVT::i24`:

```
<f>:
  af …  lda  (byte 0)        ; load the 3 bytes into A / X / Y
  ae …  ldx  (byte 1)
  ac …  ldy  (byte 2)
  18    clc
  69 00 adc  #$0             ; byte-wise add chain …
  8f …  sta
  8a    txa / 69 00 adc / 8f sta
  98    tya / 69 01 adc  #$1 ; carry reaches byte 3 (the bank byte)
  8f …  sta
  60    rts
```

GISel's `LLT` already represents `s24`/`p24`; the backend narrows to bytes. The only place `MVT` would
bite is a **dedicated 24-bit register class** (`MOSReg*Class` lists an MVT value type — `[i8]`/`[i16]`/
`[i32]`), which a `[i24]` class would require — but packed-24's win is **3-byte memory storage**, not a
24-bit register, and that needs `LLT` + the existing 32-bit working class, not a new core MVT. See the
plan's *0a* section.
