# `+mos-xy16`: a spill-slot address materialization clobbers the live value it is about to store

> **STATUS 2026‑09‑15: OPEN — real `+mos-xy16` MISCOMPILE, not a verifier-only complaint.**
> Found by **#118 `retryjmp`** (Round 6 Cluster G) on its first run. Default‑8‑bit and
> `+mos-a16` are correct; `+mos-xy16` writes the wrong value into a global `uint16_t` array.
> `#118` is therefore **STOPPED and un-gated** — no `expected.tsv` row, no `dev/retryjmp.sh`,
> no visual ROM — per the battery's rule that a demo is never weakened to ship around a defect
> it found. `#116 backtrack` and `#117 csrjmp` are unaffected and shipped.

## Symptom

```
$ build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-xy16 -Os -mllvm -verify-machineinstrs \
    -I examples -c examples/snes/corpus/retryjmp_sim.c -o /tmp/rj.o

*** Bad machine code: Using an undefined physical register ***
- function:    retryjmp_gate_crc
- basic block: %bb.4
- instruction: STAbsXIdx16 killed renamable $a16, @rj_result, killed renamable $x16 :: (store (s16) into %ir.20, align 1)
- operand 0:   killed renamable $a16
*** Bad machine code: Using an undefined physical register ***
- function:    retryjmp_gate_crc
- basic block: %bb.5
- instruction: STAbsXIdx16 killed renamable $a16, @rj_result, killed renamable $x16 :: (store (s16) into %ir.28, align 1)
- operand 0:   killed renamable $a16
fatal error: error in backend: Found 2 machine code errors.
```

Without `-verify-machineinstrs` the compile succeeds and the ROM runs — wrongly:

```
default  SMOKE: PASS off=0x20 len=2 got=0x3388 (ran 600 frames, bsnes-jg)
a16      SMOKE: PASS off=0x20 len=2 got=0x3388 (ran 600 frames, bsnes-jg)
xy16     SMOKE: FAIL off=0x20 len=2 got=0x82D4 want=0x3388
```

Stable at 400, 1200 and 2400 frames. Reading the gate's own working set out of WRAM shows
`rj_result[]` is almost entirely zero on the `+mos-xy16` target where the host oracle has 24
distinct 16-bit values, and `rj_calls` reads `0x0802` where the host counts 117.

## The wrong code

`retryjmp_gate_crc` ends each attempt with `rj_result[rj_attempt] = <value>` — a 16-bit store
to a global array at a 16-bit index. Under `+mos-xy16` the index is computed in `X16`, spilled,
and reloaded; the value is in the accumulator. From the emitted assembly (`-S`, the fault arm
`.LBB1_5`; the success arm at `.LBB1_7` is the same shape):

```asm
	rep	#32
	txa                                     ; A16 = rj_attempt*2 (the index)
	sta	(__rc4)                         ; 2-byte Folded Spill
	lda	__rc2                           ; A16 = rj_acc       — THE VALUE TO STORE
	clc
	sep	#32                             ; ... and it is dropped here
	lda	__rc0                           ; A = soft-SP lo     — A fully overwritten
	adc	#4
	sta	__rc2                           ; __rc2 (which HELD the value) overwritten
	lda	__rc1
	adc	#0
	sta	__rc3                           ; __rc2/__rc3 = soft-SP + 4
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload — A16 = the INDEX
	tax
	sta	rj_result,x                     ; stores the INDEX, not the value
	sep	#32
```

The value is loaded into `A16`, then destroyed twice over: the address materialization
overwrites `A`, and the spill-slot reload overwrites `A16` with the index. What reaches
`rj_result[]` is the index expression.

## Root cause (as far as it was chased)

The frame-index elimination that materializes the spill slot's address (`soft-SP + 4`) into a
zero-page pair picked **`__rc2`/`__rc3` (`$rs1`) while that pair was live**, holding the 16-bit
value destined for the store. The pre-RA MIR confirms the pair carries the live value across the
point where the address computation lands:

```
  JSR @rj_work, <regmask ...>, implicit $a, implicit-def $a, implicit-def $x
  renamable $rc2 = COPY $a          ; \ rj_work()'s 16-bit result -> $rs1
  renamable $rc3 = COPY $x          ; /
  ...
  renamable $a16 = LDAImag16 killed renamable $rs1     ; A16 = the result   (still correct here)
  $c = LDCImm 0
  $a = COPY $rc0 ; ADCImm 4 ; $rc2 = COPY killed $a    ; \ soft-SP + 4 written OVER $rs1
  $a = COPY $rc1 ; ADCImm 0 ; $rc3 = COPY killed $a    ; /
  $a16 = LDAIndir16 $rs1 :: (load from %stack.0)       ; A16 = the spilled INDEX
  $x16 = TAX16 killed $a16
  STAbsXIdx16 killed renamable $a16, @rj_result, killed renamable $x16
```

The verifier's message is what a killed-then-reread `$a16` produces; the *defect* is the live
`$rs1` being taken for an address temporary.

This is the same broad family as fork patch `0011` (register-scavenger mishandling around frame
index elimination) but a distinct instance: there the scavenger mishandled `$p`, here it takes a
live `Imag16` value pair.

**Ruled out — the platform `setjmp.S`.** The obvious suspect was an incomplete generalization of
the 2026‑09‑15 `setjmp.S` fix: that file documents an ambient `X=1` (8-bit index) assumption, and
`ldy #0` / `ldx #0` / `stx __rc17` would all be wrong widths if it were entered with 16-bit index
registers. It is not entered that way. In the `+mos-xy16` build the index width at the call site
is 8-bit — the only `rep`/`sep` before `jsr setjmp` are `#32` (accumulator); the first `rep #16`
comes after the call:

```asm
	ldx	#mos16hi(rj_jb)
	stx	__rc3
	jsr	setjmp                          ; <- 8-bit index mode here
	txy
	bne	.LBB1_5
```

`#116 backtrack` (0x7336) and `#117 csrjmp` (0xADD8) both pass `+mos-xy16` on target, with far
more longjmp traffic than `#118`, which independently clears `setjmp.S`.

## Reproduction

Smallest reproduction so far is the corpus slice itself, two files, no platform headers:

```
examples/65816/retryjmp.h
examples/snes/corpus/retryjmp_sim.c
```

```
build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
  -Xclang -target-feature -Xclang +mos-xy16 -Os -mllvm -verify-machineinstrs \
  -I examples -c examples/snes/corpus/retryjmp_sim.c -o /tmp/rj.o
```

Optimization levels: `-O0` clean, `-O1` 1 error, `-Os` / `-Oz` / `-O2` 2 errors. `+mos-a16`
alone clean; `+mos-a16` **and** `+mos-xy16` together reproduces (2 errors). Default clean.

A ~50-line standalone cut (`gate()` + a recursive `work()` with six 16-bit locals live across
the recursive call, one `setjmp` site, three parallel result arrays) reproduces the **verifier**
error under `+mos-xy16 -Os` but happens to run correctly, so it is a weaker witness; the same
cut with `setjmp`/`longjmp` replaced by an ordinary flag-and-return is completely clean, so the
`returns_twice` call is load-bearing for the shape.

Sensitivity inside `retryjmp.h`: deleting *either* `rj_wins++` *or* the `rj_code[rj_attempt] = …`
writes makes the function verify clean, while deleting `rj_calls++` or the `rj_depth[]` write
does not. That is the signature of a pressure/ordering-dependent allocation decision rather than
a specific construct.

## Why this one matters beyond itself

`tools/a16_fuzz.py`'s `KNOWN_ISSUES` classifies **any** log containing
`"Using an undefined physical register"` as `a16-rc-undef-ra-pure-virtual`, a documented
verifier-only XFAIL whose entry states the code is bit-exact correct. This defect produces that
exact string **and** a wrong answer. A slice carrying it would be recorded as a known-issue XFAIL
rather than a miscompile, so the message text alone is not a safe discriminator.

## Status

- `#118 retryjmp` is **STOPPED**: the logic header, the host oracle and the corpus slice are in
  the tree as the repro, deliberately **without** an `expected.tsv` row, a `dev/retryjmp.sh`
  driver, or a visual ROM. Add all of those once the defect is fixed — the host oracle is
  `0x3388`.
- Needs a backend change (register scavenger / frame-index elimination live-range handling) plus
  a full toolchain rebuild and regression sweep. **ESCALATED — out of scope for the demo pass
  that found it.**
