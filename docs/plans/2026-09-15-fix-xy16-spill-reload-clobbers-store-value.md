# Fix the `+mos-xy16` X16/Y16 soft-stack spill that clobbers a live accumulator

TODO entry: **Compiler stress-test demo battery** → *Fix in progress (dispatched T4, 2026‑09‑15)*
inside the `#116`–`#118` Cluster G block.

## Context

`#118 retryjmp` (Round 6 Cluster G) found a real `+mos-xy16` **miscompile**, not a
verifier-only complaint —
[investigation](../investigations/2026-09-15-xy16-spill-reload-clobbers-store-value.md).
Host oracle `0x3388`; default and `+mos-a16` agree on target; `+mos-xy16` returns `0x82D4`.
With `-verify-machineinstrs` the same build instead dies with *Using an undefined physical
register* on `STAbsXIdx16 killed renamable $a16` at `-O1`/`-Os`/`-Oz`/`-O2`.

The investigation's provisional root cause — "frame-index elimination materializes a spill
slot's address into the `Imag16` pair `$rs1` while that pair is still live" — is **not** what
is happening, and this plan corrects it. `$rs1` is genuinely dead at that point (`LDAImag16
killed renamable $rs1` reads it out one instruction earlier), and it is the `LDStk` pseudo's
own `@earlyclobber` scratch operand, legitimately assigned by register allocation.

The actual defect is one register up. Post‑RA, pre‑PEI MIR for `retryjmp_gate_crc` `%bb.4`
(`-mllvm -print-before=prologepilog`):

```
  renamable $x16 = LDXImag16 killed renamable $rs2
  dead early-clobber renamable $rs2 = STStk killed renamable $x16, %stack.0, 0
  renamable $a16 = LDAImag16 killed renamable $rs1          ; <- the VALUE, into A16
  renamable $x16, dead early-clobber renamable $rs1 = LDStk %stack.0, 0
  STAbsXIdx16 killed renamable $a16, @rj_result, killed renamable $x16
```

A 16-bit index register has no `(zp)`-indirect load or store on the 65816, so an X16/Y16
soft-stack spill has to be **staged through the accumulator**:
`MOSRegisterInfo::expandLDSTStk` emits `txa; sta (ptr)` outbound and `lda (ptr); tax`
inbound (`vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.cpp`, the `IsXc16` / `IsYc16`
arms). Neither `LDStk` nor `STStk` carries an `A16` operand
(`MOSInstrPseudos.td:229`/`:239` — `(outs unknown:$dst, Imag16:$scratch)`), so **that clobber
is invisible to register allocation**, which happily parked the value bound for
`rj_result[i]` in `A16` across the reload. The reload overwrites `A16` with the spilled
index, and `sta rj_result,x` stores the index expression. The verifier's complaint is the
downstream symptom: `TAX16` kills `$a16`, and the store then re-reads it.

The address materialization the investigation pointed at (`clc; lda __rc0; adc #4; sta
__rc2`) is a *second*, already-handled clobber: `expandAddrLostk` routes through a virtual
`AcRegClass` register that the post-RA scavenger saves and restores when `$a` is live
(`MOSRegisterInfo::saveScavengerRegister`, the `MOS::A` arm). It only reads as a clobber here
because the accumulator's value had already been written off by the undeclared `A16` def
below it.

Same family as fork patch `0011`, as the investigation says, but the mechanism is the
opposite one: `0011` is about the *scavenger's* handling of a live `$p`; this is an expansion
clobber the allocator was never told about.

## Approach

Preserve `A16` locally in the expansion that clobbers it, and only when something is live in
it: `MOSRegisterInfo::expandLDSTStk` becomes a thin wrapper around the existing body
(`expandLDSTStkImpl`) that brackets an X16/Y16 spill with a 16-bit `pha`/`pla` when the
accumulator is live across the pseudo.

**Rejected: declare the clobber on the pseudo** (`implicit-def dead $a16`, or `Defs=[A16]` in
TableGen). `LDStk`/`STStk` are created by the *spiller*, during register allocation and after
live intervals are built, so a physical-register def added there is not reflected in the
regunit live ranges the allocator checks interference against — it would be an unreliable
fix, and unreliable is the worst thing a miscompile fix can be. It is also unsatisfiable by
recolouring: `Ac16` has exactly one member, so "avoid `A16` here" could only be met by
spilling — which is what the bracket does anyway, but cheaper and only where needed. A
blanket `Defs=[A16]` in TableGen is worse still: `A16` aliases `A`, so it would make every
soft-stack spill on every MOS target clobber the accumulator (lesson 2's blanket-change
trap).

Files:

- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInstrLogical.td` — new `PHA16`/`PLA16` pseudos
  (`PseudoInstExpansion<(PHA_Implied)>` / `(PLA_Implied)`, `MLow = 1`, `Ac16` operand),
  mirroring the existing `TAX16`/`TXA16` idiom directly above them. `pha`/`pla` move two
  bytes when `M=0`; `MOSInsertREPSEP` already supplies the `rep`/`sep #$20` bracket for any
  `MLow=1` op.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSRegisterInfo.{h,cpp}` — the wrapper, a
  `accumulatorLiveAcross()` predicate built on the file's existing `computeLiveBefore()`
  helper (added by patch `0011`), and `pushPullBalanced()` taught to count the new pair.
- `vendor/llvm-mos/llvm/lib/Target/MOS/MOSInsertREPSEP.cpp` — comment only; `PHA16`/`PLA16`
  name no index register, so `requiredXWidth` correctly leaves them `XW_None`.

The gate is conservative in the required direction. `LivePhysRegs::available()` is
alias-aware, so a live 8-bit `$a` answers "live" too — deliberately, since `lda (zp); tax`
destroys `$a` just as thoroughly. A spurious "live" costs one `pha`/`pla` pair (2 B, 7
cycles) and is always semantically harmless; a missed "live" is a miscompile. The estimate
can only err toward "live": the scan runs during PEI's forward walk, so any `LDStk`/`STStk`
*below* the current one is still an unexpanded pseudo naming no accumulator — it can fail to
report a *kill* of `A16`, never invent a *use*.

Zero cost where the accumulator is dead, which is the common case; the `+mos-a16`, default
and 6502 paths are untouched by construction (the bracket is reachable only from the
`Xc16`/`Yc16` arms, which exist only under `+mos-xy16`).

The fix lands in `patches/llvm-mos/0002-321-accum16.patch` (the comprehensive `MOS/` mirror)
via `dev/regen-patch.sh` — it is fork-feature code, not a stock-llvm-mos defect, so no
standalone upstream artifact.

**Constraint on where the edit may touch.** `dev/regen-patch.sh` derives `0002` by mirroring the
live tree and then **reverse-applying** every standalone upstream-bound patch that lives inside
`llvm/lib/Target/MOS/`. `0018-320-imag32-spill.patch` is one of them and it owns two regions of
`expandLDSTStk`: the `Imag32` split block (including its two `expandLDSTStk(LoInstr/HiInstr)`
recursion lines) and three context lines of the `#321 SPILL CONTRACT` comment. Renaming those
recursion calls or inserting comment lines into that block makes `0018` fail to reverse-apply and
the regen aborts — which it did on the first attempt. So the internal recursions stay spelled
`expandLDSTStk` (they short-circuit in the wrapper anyway, since an `Imag16`/`Imag8` half is never
`Xc16`/`Yc16`) and the note about the `A16` clobber goes on the `Xc16`/`Yc16` arm instead of in
the contract comment. The single re-entry that must call `expandLDSTStkImpl` directly is the
body's own offset-0 restart after materializing a pointer — that is the *same* spill, already
bracketed, and a second bracket there would save an accumulator the address chain has just
clobbered.

## Mockups

**None — the backend half has no visible surface** (a register-allocation-adjacent codegen
fix; its review surface is the MIR/disassembly quoted above and the differential gate). The
`#118 retryjmp` visual ROM completed in step 2 gets the battery's standard treatment — a
two-emulator screenshot asserted against the host oracle by `dev/retryjmp.sh` — which is the
demo-battery equivalent of a mockup and is recorded in the verification section, not drawn in
advance.

## Second half: complete `#118 retryjmp`

Once the compiler is fixed, ship the deliberately-withheld half, following `#116 backtrack`
and `#117 csrjmp` (commit `ff1ad28`) exactly:

- `examples/snes/corpus/expected.tsv` row for `corpus/retryjmp_sim.c` → `0x3388`.
- `dev/retryjmp.sh` + `dev/retryjmp.lua` (host oracle → ROM build → structure gate →
  bsnes-jg → MAME), closing with `emu_verdict`.
- `examples/snes/retryjmp.c` visual ROM + `dev/run.sh` / `Taskfile.yml` wiring.
- `tools/a16_fuzz.py`: tighten `KNOWN_ISSUES` so `"Using an undefined physical register"`
  alone can no longer classify a slice as the benign `a16-rc-undef-ra-pure-virtual` XFAIL.
  A miscompile that produces that string must be reported as a mismatch.

### Where the regression guard lives

Not a lit test. `0002` mirrors `llvm/lib/Target/MOS/` only, so a file added under
`llvm/test/CodeGen/MOS/` is not captured by the patch and would be lost on the next fresh-clone
bootstrap — which is why fork-feature fixes here are guarded by differential micro-tests rather
than lit. The guard is therefore **step 3 of `dev/retryjmp.sh`**: `-verify-machineinstrs` under
`+mos-xy16` at `-O1`/`-Os`/`-Oz`/`-O2` on the corpus slice, the exact four legs that failed, plus
the 5-way value differential the `expected.tsv` row gives it.

## Out of scope

- Publishing `#118` (or `#116`/`#117`) to biohack.net — the whole Cluster G block is
  explicitly "not yet published" and publishing is user-triggered.
- The suboptimal spill itself. `retryjmp_gate_crc` spills `X16` and reloads it one
  instruction later; that is a register-allocation *quality* issue, independent of the
  correctness bug, and is left alone.
- Upstreaming. `LDStk`/`STStk` staging through `A16` is fork-only (`+mos-xy16`), so there is
  no stock-llvm-mos defect to report.

## Verification

Recorded 2026-09-15 on the rebuilt toolchain (`build/llvm-mos-install/bin/clang-23`, 12:20).

1. **The repro compiles clean under `-verify-machineinstrs` at every failing level.**

```
$ for O in -O1 -Os -Oz -O2; do build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 \
    -Xclang -target-feature -Xclang +mos-xy16 $O -mllvm -verify-machineinstrs \
    -I examples -c examples/snes/corpus/retryjmp_sim.c -o /tmp/rj.o && echo "$O OK"; done
-O1 OK
-Os OK
-Oz OK
-O2 OK
```

**PASS** — all four levels that previously reported *Using an undefined physical register* on
`STAbsXIdx16 killed renamable $a16` now exit cleanly.

2. **Same, with `+mos-a16` and `+mos-xy16` together, and `+mos-a16` alone, and default.**

```
+mos-a16 +mos-xy16 OK
+mos-a16 OK
default OK
```

**PASS** — the combination that reproduced with 2 errors is clean; the two modes that were
already correct stay correct.

3. **The emitted `%bb.4` sequence preserves the value.**

```
$ mos-clang … +mos-xy16 -Os -S examples/snes/corpus/retryjmp_sim.c
	sta	(__rc4)                         ; 2-byte Folded Spill
	lda	__rc2
	pha
	clc
	sep	#32
	lda	__rc0
	adc	#4
	sta	__rc2
	lda	__rc1
	adc	#0
	sta	__rc3
	rep	#32
	lda	(__rc2)                         ; 2-byte Folded Reload
	tax
	pla
	sta	rj_result,x
```

**PASS** — `pha` (PHA16) saves the value before the address chain clobbers `$a`, `pla` (PLA16)
restores it after the reload has overwritten `A16` with the index, and `sta rj_result,x` now
stores the value. Both halves landed *inside* the existing `rep #$20` runs, so the cost is two
bytes and no extra mode switches. (Compare the pre-fix listing in the investigation's
"The wrong code" section, where the value was destroyed twice over.)

4. **`dev/run.sh retryjmp`** — host oracle `0x3388` == `+mos-a16`@bsnes-jg (and MAME).

```
==> host oracle: retryjmp gate hash = 0x3388
==> built build/retryjmp.sfc (+mos-a16); corpus_result @ WRAM 0x48
==> xy16 verifier gate (the A16-clobber regression guard)
    PASS  +mos-xy16 -O1 -verify-machineinstrs clean
    PASS  +mos-xy16 -Os -verify-machineinstrs clean
    PASS  +mos-xy16 -Oz -verify-machineinstrs clean
    PASS  +mos-xy16 -O2 -verify-machineinstrs clean
==> structure gate (setjmp + longjmp present, rj_work a real recursive jsr frame)
    PASS  setjmp=1  longjmp=1  rj_work refs=148  rep#$20=27
==> bsnes-jg: render + assert (build/retryjmp-jg.png, frame 600)
SMOKE: PASS off=0x48 len=2 got=0x3388 (ran 600 frames, bsnes-jg)
==> MAME (under Xvfb): snapshot + assert (build/retryjmp-mame.png)
    SHOT: PASS corpus=0x3388 (snapshot at frame 600)

RESULT: PASS — Retry-On-Fault Ladder on SNES; corpus hash 0x3388 host == +mos-a16, both emulators agree; +mos-xy16 -verify clean at -O1/-Os/-Oz/-O2
```

**PASS** — the on-target value is `0x3388`, the host oracle. Before the fix it was `0x82D4`.
The SPC700 IPL is present locally, so the MAME leg **actually ran** (no SKIP). Both
`build/retryjmp-{jg,mame}.png` written; the ladder renders with faulted attempts as red stubs at
the baseline, the clean attempt climbing green, and the HUD reading `A03 D1/6 C02 R=FF78`.

5. **`dev/run.sh corpus`** — no regression against the recorded 65/65 baseline.

```
  backtrack_sim PASS  corpus_result=0x7336  …
  csrjmp_sim PASS  corpus_result=0xADD8  …
  retryjmp_sim PASS  corpus_result=0x3388  #118 setjmp/longjmp RE-ENTRY gate …
==> corpus: 66/66 passed
```

**PASS** — 66/66 against the 65/65 baseline; the +1 is the new `retryjmp_sim` row.

6. **`dev/run.sh corpus-a16`** — 4-way `host==default==+mos-a16==+mos-xy16`.

```
  backtrack_sim PASS   corpus_result=0x7336  …
  csrjmp_sim PASS   corpus_result=0xADD8  …
  retryjmp_sim PASS   corpus_result=0x3388  #118 setjmp/longjmp RE-ENTRY gate …
==> corpus-a16: 65/65 passed, 0 xfail
```

**PASS** — 65/65 against the recorded 64/64 baseline; the +1 is the new `retryjmp_sim` row, and
`0x3388` is exactly the host oracle. (The trailing `dev/run.sh: line 456: ANT:+-e: command not
found` in the log is not a test result: `dev/run.sh` was edited *while this run was in flight*
and bash re-reads a script incrementally, so the wrapper resumed at a shifted byte offset after
`docker run` returned. The in-container verdict line above is the authoritative one, and
`bash -n dev/run.sh` parses clean. Lesson: do not edit `dev/run.sh` during a long run.)

7. **`dev/run.sh build`** — the full example set builds.

```
build rc=0 programs=261
```

**PASS** — 261 against the 260 baseline; the +1 is the new `examples/snes/retryjmp.c` demo ROM
(`retryjmp  32768 bytes`).

8. **The xy16 micro-test suite stays green.**

```
  xy16basic   rc=0 : RESULT: PASS — +mos-xy16 accepted, X-flag lattice inert for M16-only ops, corpus_result==0x0042
  xy16spill   rc=1 : RESULT: FAIL
  xy16spillr  rc=0 : RESULT: PASS — LDXImag16+LDAbsXIdx16 indexed access under +mos-xy16; corpus_result==0x3457; both emulators agree
  xy16ops     rc=0 : RESULT: PASS — G_LOAD_ABS_IDX16+LDXImag16+LDAbsXIdx16 B2 path under +mos-xy16; corpus_result==0x2A42; both emulators agree
  xy16indiry  rc=0 : RESULT: PASS — G_LOAD_INDIR_IDX16+LDYImag16+LDIndirYIdx16 (zp),Y16 B2 path; corpus_result==0x7E5A
  xy16call    rc=0 : RESULT: PASS — 16-bit index held across a clobbering call; corpus_result==0x7E5A
  xy16inplace rc=0 : RESULT: PASS — in-place memmove/memcpy over a 16-bit-indexed buffer; -verify clean
  a16spill    rc=1 : RESULT: FAIL
  a16spillr   rc=0 : RESULT: PASS — soft-stack Ac16 spill compiles clean and computes 0x3457; both emulators agree
  a16spillir  rc=0 : RESULT: PASS — hermetic .ll: soft-stack Ac16 spill compiles clean and the spill path is exercised
  a16frameidx rc=0 : RESULT: PASS — stack s[i] compared at frame+2*i -> 0x4321; both emulators agree
  a16scavnz   rc=0 : RESULT: PASS — FIXED a16/xy16 scavenger crash: compiles clean + corpus_result==0x22A6
```

**PASS with two PRE-EXISTING failures that are not this change.** `xy16spill` and `a16spill`
each fail *only* their own structural self-check:

```
  PASS: clean (exit 0)                                   <- step 1, -verify-machineinstrs
  FAIL: expected an Ac16 static-stack spill (STAbs16/LDAbs16 $a16, %stack); found 0
        — test no longer guards the regression           <- step 2, the self-check
  PASS: default clean                                    <- step 3
```

Three independent lines of evidence say this is drift in the **stack-model** decision, not a
regression from this fix:

1. `a16spill` uses `+mos-a16` **only**. This change is gated on `Xc16RegClass`/`Yc16RegClass`,
   register classes that exist only under `+mos-xy16` — it is unreachable there, yet the failure
   is identical.
2. The assertion greps MIR printed after `virtregrewriter`. The only functional edit runs inside
   `eliminateFrameIndex`, i.e. during PEI — strictly *later* in the pipeline, so it cannot alter
   that dump.
3. `PHA16` count is **0** in both `examples/65816/xy16spill.c` and `examples/65816/a16spill.c`, so
   the fix's only emitting path never fires; the wrapper otherwise forwards straight to the
   unmodified body.

What actually changed: both functions now receive a **soft** stack rather than a static one, so
the `Ac16` spill comes out as `STStk`/`LDStk` instead of `STAbs16`/`LDAbs16`:

```
$ mos-clang … {+mos-a16,+mos-xy16} -Os -mllvm -print-after=virtregrewriter -c examples/65816/xy16spill.c
default : static-stack-spill-ops=0  softstack-Stk-ops=0
+mos-a16: static-stack-spill-ops=0  softstack-Stk-ops=2
+mos-xy16: static-stack-spill-ops=0  softstack-Stk-ops=2
   24B  dead early-clobber renamable $rs1 = STStk killed renamable $a16, %stack.0, 0
  328B  renamable $a16, dead early-clobber renamable $rs1 = LDStk %stack.0, 0
```

That is a `MOSFrameLowering::usesStaticStack` / `MOSNonReentrant` question, untouched here.
Reported as a separate finding; the tests are honest about it ("test no longer guards the
regression") and the invariant they exist for is still checked by the sibling `a16spillr` /
`a16spillir` (soft-stack Ac16), which pass.

9. **`dev/run.sh fuzz --gen builtin 50 1`** — 50/50, 0 mismatch.

```
  [ ok ] seed    50  0xEAD4 (all agree)
==> fuzz: 50/50 PASS, 0 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

**PASS** — the 4-way builtin fuzz track is clean.

10. **`tools/a16_fuzz.py` discriminator.**

```
$ python3 -c "... classify_known on captured verifier logs ..."
newton   -> a16-rc-undef-ra-pure-virtual
retryjmp -> None
mixed    -> None
empty    -> None
```

**PASS** — the existing witness (`$rcN` operands) still classifies as the benign XFAIL; the #118
signature (`$a16`) no longer does, and a log carrying both refuses to classify. Separately,
`evaluate()` no longer short-circuits on a known-issue verify failure, so even a log that *does*
match the XFAIL is still value-checked 4-way and a mismatch is a `FAIL`.

11. **`patches/llvm-mos/0002-321-accum16.patch` regenerated, no foreign content.**

```
$ dev/regen-patch.sh
==> [verify] diff -rq reapplied MOS dir vs live vendor MOS dir
RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)

$ git diff patches/llvm-mos/0002-321-accum16.patch | grep "^-" | grep -vE "^---|^-@@" | grep -cE "^--"
0
```

**PASS** — the delta is purely additive (zero removed lines beyond `@@` renumbering) and every
added line is this change's own text: the `PHA16`/`PLA16` defs, the `pushPullBalanced` cases, the
`accumulatorLiveAcross` predicate, the wrapper, the `MOSRegisterInfo.h` declaration and four
comment blocks. No standalone-patch content absorbed. The **first** regen attempt aborted at
`reversing 0018-320-imag32-spill.patch … patch does not apply` because the edit had renamed the
two `expandLDSTStk(LoInstr/HiInstr)` recursion lines and inserted comment lines that `0018` owns
as context; restoring both is what made it round-trip (see **Approach**).

12. **Blast radius.**

```
$ for O in -Os -O1 -O2 -Oz; do  # 117 corpus slices each, +mos-xy16,
                                # -mllvm -print-after=prologepilog | grep -c PHA16
-Os  retryjmp_sim.c: PHA16=2   total 2 across 1 of 117
-O1  retryjmp_sim.c: PHA16=1   total 1
-O2  retryjmp_sim.c: PHA16=2   total 2
-Oz  retryjmp_sim.c: PHA16=2   total 2
```

**PASS** — the gate fires only in the program that carries the bug. Every other corpus program is
untouched at every optimization level.

13. **Object identity across the final rebuild.**

```
OBJECT-IDENTICAL: all 351 corpus objects byte-identical across the rebuild
```

**PASS** — 117 slices × {default, `+mos-a16`, `+mos-xy16`} at `-Os`, hashed before and after the
rebuild that picked up the `0018`-compatibility edit. The edit is codegen-neutral, so the
`corpus-a16 65/65` result above transfers to the shipping binary.

14. **`dev/run.sh known-issues`** — unchanged behaviour.

```
==> known-issues XPASS guard: each KNOWN_ISSUES repro must still crash verify (+mos-a16 AND +mos-xy16)
  examples/snes/corpus/newton_sim.c +mos-a16   XPASS — verifies CLEAN (issue [a16-newton-step-rc-undef] no longer reproduces)
  examples/snes/corpus/newton_sim.c +mos-xy16  XPASS — verifies CLEAN (issue [a16-newton-step-rc-undef] no longer reproduces)
RESULT: FAIL — known-issue guard tripped
```

**FAIL — pre-existing, and not reachable by this change.** The guard verifies at `-Os`, and
`newton_sim.c` is clean at `-Os` under both modes (`PHA16=0`, `verify-errors=0` in both), so the
fix's only emitting path never fires there and its codegen is produced entirely by unmodified
code. The XPASS branch does not consult `classify_known` at all, so the tightened discriminator
cannot have produced it either. Note the guard was *already* red before this change on a second,
independent count: its `KNOWN_ISSUE_REPROS` row expects kid `a16-newton-step-rc-undef`, an entry
that was removed from `KNOWN_ISSUES` long ago, so even a crashing newton would have reported
`DRIFT — signature [a16-rc-undef-ra-pure-virtual] != [a16-newton-step-rc-undef]`.

The real content of the finding is that the `a16-rc-undef-ra-pure-virtual` XFAIL's own stated
repros have drifted: `lsystem_sim.c` at `-Os` (its primary witness) and `newton_sim.c` at `-Os`
now both verify **clean**; only `newton_sim.c` at `-O1` still reproduces. Deciding whether cause
#2 is genuinely fixed — and therefore whether to drop the XFAIL entry and promote the repros to
positive gates — is its own investigation and is deliberately **not** done here: dropping it
would also discard the discriminator this change just hardened. Escalated as a separate item.
