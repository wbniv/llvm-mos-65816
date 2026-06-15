# #321 native s16 — `inc a`/`dec a` for the abs `g ± 1` path (and why NOT `inc abs`)

Inc/dec gap, part 2 (completes the bucket; part 1 = register `inc a`/`dec a`,
committed `98c5eac`). A 16-bit `g = g ± 1` on a global compiled to
`clc; lda g; adc #$0001; sta g` (4 instrs). This makes it `lda g; inc/dec a; sta g`
(3 instrs) — dropping the `clc` and shrinking `adc #imm16` to a 1-byte `inc a`/`dec a`.

## Investigation: memory-RMW `inc abs` is NOT viable here

The obvious target was a single `inc abs`/`dec abs` read-modify-write (1 instr). It was
prototyped (new `INCAbs16`/`DECAbs16` pseudos) and **reverted** — it is unsafe on this
platform:

- The 65816 has **no `inc long`** — the RMW instructions (INC/DEC/ASL/…) only have
  absolute (16-bit) and abs,X forms.
- `inc abs` is therefore **DBR-relative** (16-bit). This platform's crt0 leaves DBR=0
  and the compiler addresses **all** data via 24-bit **long** loads/stores (`lda long`,
  `af`), i.e. DBR-independent. `inc abs` would be the *only* construct relying on DBR==0.
- It only *happens* to work today because the linker confines all writable data to
  LoRAM `0x0200–0x1FFF` (`link.ld` `ram` region) and the SNES mirrors that low 8 KB into
  every bank's `$0000–1FFF`, so `inc abs $0200` (DBR=0) and `lda long $7E0200` hit the
  same physical RAM. A global above `0x1FFF`, a non-zero DBR, or a memory-map change
  would silently miscompile — exactly the failure class the dual-emulator gate exists to
  catch, but here avoidable by construction.

So the RMW form is deliberately not provided (a note records this in
`MOSInstrLogical.td`). The accumulator `inc a`/`dec a` keeps the compiler's long
addressing for the memory access, so it is correct under any DBR / memory map.

## Implementation

`selectAlu16Abs`: when the op is `G_ADD16_ABS` immediate with imm `±1` (`0x0001` → inc,
`0xFFFF` → dec; only `G_ADD16_ABS` is ever the immediate form — `G_SUB16_ABS` is
non-commutative, so `g - 1` arrives as `g + 0xFFFF`), emit `lda <g> (LDAbs16); inc/dec a
(INCAcc16/DECAcc16 from part 1); sta <g> (STAbs16)` instead of `clc; lda; adc #imm; sta`.
Same long addressing, one fewer instruction and the carry-init dropped. Covers both the
same-global RMW (`g += 1`) and the cross-global case (`o = a + 1`). The bitwise abs
pseudos are excluded (`& 1` / `| 1` are not inc/dec). The multi-use register-result form
(`selectAlu16AbsLd`) is left on `adc #imm` (a minor consistency follow-up).

## Test

`examples/65816/a16incabs.c` + `dev/a16incabs.sh`: several `g += 1` / `g -= 1` on
globals plus an `o = a + 1` cross-global case. Disasm gate asserts `inc a` (0x1a) /
`dec a` (0x3a) appear, there is **no** `clc` (0x18) feeding them, and — guarding the
deliberate choice — **no** `inc abs` (0xee) / `dec abs` (0xce). Distinctive
`corpus_result`; MAME + bsnes-jg agree; `-verify-machineinstrs` clean.

## Verification steps

1. `dev/run.sh a16incabs` — green on both emulators; disasm shows `lda long; inc/dec a;
   sta long`, no `clc`/`adc #1`, no `inc abs`/`dec abs`.
2. `dev/run.sh a16incdec a16loopred a16abs a16loadfold a16add` — existing inc/dec, add,
   and abs suite still green.
3. Full a16 suite (28 tests) + `dev/run.sh corpus` (7/7).
4. `-mllvm -verify-machineinstrs` clean on a16incabs.
5. `dev/regen-patch.sh` round-trips.

## Verification evidence (2026-06-15)

1. `dev/run.sh a16incabs`:

   ```
   inc a=3  dec a=1  adc #$0001=0  inc/dec abs(ee/ce)=0
   PASS: 3 inc a — native 16-bit increments on globals
   PASS: 1 dec a — native 16-bit decrement on a global
   PASS: no clc; adc #$0001 (the ±1 went to inc/dec a)
   PASS: no DBR-relative inc abs/dec abs RMW (long addressing kept)
   SMOKE: PASS addr=0x7E0208 len=2 got=0x3502 (MAME) / off=0x208 got=0x3502 (bsnes-jg)
   RESULT: PASS
   ```
   Disasm: each `g ± 1` is `lda long; inc/dec a; sta long` (no `inc abs`). PASS.

2. `a16incdec`, `a16loopred`, `a16abs`, `a16loadfold`, `a16add` — all PASS. PASS.

3. Full a16 suite (28 tests) + `dev/run.sh corpus`: all 29 green (`FAIL: NONE`). PASS.

4. `-mllvm -verify-machineinstrs` on a16incabs → `rc=0`. PASS.

5. `dev/regen-patch.sh`: `RESULT: PASS — 0002 round-trips`. PASS.
