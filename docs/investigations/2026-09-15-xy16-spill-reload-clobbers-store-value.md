# `+mos-xy16`: an X16/Y16 soft-stack spill clobbers the live accumulator it is staged through

> **STATUS 2026‑09‑15: RESOLVED.** Fixed the same day —
> [§ Resolution](#resolution-2026-09-15). The title and the "Root cause" section below record
> the *provisional* diagnosis this investigation reached; it was **wrong in its mechanism** and
> the resolution section corrects it. Kept verbatim rather than rewritten, because the wrong
> turn is the instructive part: the instruction the verifier points at was two clobbers
> downstream of the actual defect.
>
> Found by **#118 `retryjmp`** (Round 6 Cluster G) on its first run. Default‑8‑bit and
> `+mos-a16` were correct; `+mos-xy16` wrote the wrong value into a global `uint16_t` array.
> `#118` was **STOPPED and un-gated** while it was open — no `expected.tsv` row, no
> `dev/retryjmp.sh`, no visual ROM — per the battery's rule that a demo is never weakened to
> ship around a defect it found. All three are now shipped and gated.
> `#116 backtrack` and `#117 csrjmp` were never affected.

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

**Closed 2026‑09‑15, two ways** (`tools/a16_fuzz.py`):

1. The `a16-rc-undef-ra-pure-virtual` predicate now requires **every** undefined operand the
   verifier names to be an *imaginary* register (`$rcN`/`$rsN`/`$rlN`) — cause #2 is by
   construction about an `Imag16` value bound across a call's regmask. One real-register operand
   (`$a16`, exactly this defect) disqualifies the whole log.
2. More importantly, `evaluate()` **no longer short-circuits on a known-issue verify failure**.
   The program is still built and run 4-way, and a value disagreement is a `FAIL` regardless of
   which XFAIL the verify log matched. Every `KNOWN_ISSUES` entry asserts "the code is still
   bit-exact correct"; that claim is what makes an XFAIL safe, so it is now *checked* rather than
   assumed.

## Status

- ~~`#118 retryjmp` is **STOPPED**~~ — **shipped 2026‑09‑15 with the fix.** The
  `expected.tsv` row (`0x3388`), `dev/retryjmp.{sh,lua}` and the visual ROM
  `examples/snes/retryjmp.c` all landed; `dev/retryjmp.sh` additionally carries the
  `+mos-xy16 -verify-machineinstrs` regression gate at `-O1`/`-Os`/`-Oz`/`-O2`, the exact legs
  that failed here.
- Needs a backend change (register scavenger / frame-index elimination live-range handling) plus
  a full toolchain rebuild and regression sweep. **ESCALATED — out of scope for the demo pass
  that found it.**

---

## Resolution (2026-09-15)

**The provisional root cause above is wrong, and the correction matters.** `$rs1` is *not* taken
while live. Read the pre-PEI MIR again:

```
  renamable $x16 = LDXImag16 killed renamable $rs2
  dead early-clobber renamable $rs2 = STStk killed renamable $x16, %stack.0, 0
  renamable $a16 = LDAImag16 killed renamable $rs1          ; <- $rs1 DIES here
  renamable $x16, dead early-clobber renamable $rs1 = LDStk %stack.0, 0
  STAbsXIdx16 killed renamable $a16, @rj_result, killed renamable $x16
```

`LDAImag16 killed renamable $rs1` reads the pair out one instruction before the elimination
point, so `$rs1` is genuinely dead there; and the pair the address lands in is the `LDStk`
pseudo's own `@earlyclobber $scratch` operand (`MOSInstrPseudos.td:229`), legitimately assigned
by register allocation. Nothing about that is a bug.

**The actual defect is one register up: the value is in `A16`, and the `LDStk` destroys `A16`
without ever telling the allocator.**

A 16-bit index register has no `(zp)`-indirect load or store on the 65816, so an X16/Y16
soft-stack spill has to be **staged through the accumulator**:
`MOSRegisterInfo::expandLDSTStk` emits `txa; sta (ptr)` outbound and `lda (ptr); tax` inbound.
Neither `LDStk` nor `STStk` carries an `A16` operand, so that clobber is invisible to register
allocation — which parked the value bound for `rj_result[i]` in `A16` across the spill. The
reload overwrote `A16` with the spilled index and `sta rj_result,x` stored the index expression.

The two clobbers the "wrong code" section blames are both downstream of that:

- The address materialization (`clc; lda __rc0; adc #4; sta __rc2`) *is* clobbering `$a`, but
  that path is already handled: `expandAddrLostk` routes through a virtual `AcRegClass` register
  that the post-RA scavenger saves and restores whenever `$a` is live
  (`MOSRegisterInfo::saveScavengerRegister`, the `MOS::A` arm). It reads as an unguarded clobber
  here only because the `LDAIndir16` below it fully redefines `A16`, so backward liveness
  correctly reports `A16` dead at the scavenge point — the accumulator's value had already been
  written off.
- The verifier's *Using an undefined physical register* on `STAbsXIdx16` is the last symptom in
  the chain: `TAX16` kills `$a16`, and the store then re-reads it.

Same family as fork patch `0011`, as guessed, but the opposite mechanism: `0011` is about the
*scavenger's* handling of a live `$p`; this is an expansion clobber the allocator was never told
about.

### The fix

`MOSRegisterInfo::expandLDSTStk` becomes a thin wrapper around the existing body
(`expandLDSTStkImpl`). When the register being spilled is `Xc16`/`Yc16` **and** the accumulator
is live across the pseudo, the wrapper brackets the whole expansion with a 16-bit push/pull:

- **`PHA16` / `PLA16`** — new pseudos in `MOSInstrLogical.td`, `PseudoInstExpansion` of
  `PHA_Implied`/`PLA_Implied` with `MLow = 1`, so `MOSInsertREPSEP` runs them inside a `rep #$20`
  and `pha`/`pla` move both bytes. They are not selectable; the expansion is their only emitter.
- **`accumulatorLiveAcross()`** — built on the `computeLiveBefore()` helper patch `0011` already
  added to this file. `LDStk`/`STStk` name no accumulator operand, so liveness before the pseudo
  equals liveness after it. `LivePhysRegs::available()` is alias-aware, so a live 8-bit `$a`
  answers "live" too — deliberately: `lda (zp); tax` destroys `$a` just as thoroughly, which
  makes this a *generalization*, not a narrowing to the reported shape.
- The save must precede the pointer materialization (which scavenges `$a`) and the restore must
  follow the whole sequence, which is why the bracket lives in the wrapper rather than in the
  `Xc16`/`Yc16` arms. `pushPullBalanced()` counts the new pair so the scavenger's hard-stack
  balance test stays exact.

**Rejected: declaring the clobber on the pseudo** (`implicit-def dead $a16`, or `Defs=[A16]` in
TableGen). These pseudos are created by the *spiller*, during register allocation and after live
intervals are built, so a physical-register def added there is not reflected in the regunit live
ranges the allocator checks interference against — unreliable, which is the worst property a
miscompile fix can have. It is also unsatisfiable by recolouring (`Ac16` has exactly one member,
so only a spill could satisfy it), and a blanket `Defs=[A16]` would make *every* soft-stack spill
on *every* MOS target clobber the accumulator, since `A16` aliases `A`.

Erring is one-sided by construction: a spurious "live" costs one `pha`/`pla` pair (2 B, 7 cycles)
and is always semantically harmless; a missed "live" is a miscompile. The estimate can only err
toward "live" — the scan runs during PEI's forward walk, so any `LDStk`/`STStk` *below* the
current one is still an unexpanded pseudo naming no accumulator, and can therefore only fail to
report a *kill* of `A16`, never invent a *use*.

### Emitted code

```asm
	rep	#32
	txa
	sta	(__rc4)                         ; 2-byte Folded Spill
	lda	__rc2                           ; A16 = rj_acc — THE VALUE
	pha                                     ; <- PHA16, inside the same rep run
	clc
	sep	#32
	lda	__rc0 ; adc #4 ; sta __rc2      ; address materialization (clobbers $a)
	lda	__rc1 ; adc #0 ; sta __rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload — A16 = the index
	tax
	pla                                     ; <- PLA16, the value is back
	sta	rj_result,x                     ; stores the VALUE
	sep	#32
```

`MOSInsertREPSEP` folded both halves into the *existing* `rep #$20` runs, so the fix costs
exactly two bytes here and no extra mode switches.

### Blast radius

Measured, not asserted: across all 117 corpus slices compiled `+mos-xy16 -Os`, the gate fires
**twice in total, both in `retryjmp_sim.c`** (counted at the MIR level with
`-mllvm -print-after=prologepilog | grep PHA16`). Every other program is unchanged — the wrapper
emits nothing when the accumulator is dead, and the expansion body is untouched. The default and
`+mos-a16` paths cannot reach the bracket at all: it is guarded on `Xc16`/`Yc16`, register
classes that exist only under `+mos-xy16`.

### Verification

`docs/plans/2026-09-15-fix-xy16-spill-reload-clobbers-store-value.md` carries the numbered
verification record with raw output.
