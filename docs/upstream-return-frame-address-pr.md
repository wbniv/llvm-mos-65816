# [MOS] Legalize llvm.returnaddress and llvm.frameaddress

`__builtin_return_address` and `__builtin_frame_address` reach a backend error
on MOS; for example `void *f(void) { return __builtin_return_address(0); }`:

```text
fatal error: error in backend: unable to legalize instruction: %0:_(p0) = G_INTRINSIC intrinsic(@llvm.returnaddress), 0 (in function: f)
```

GlobalISel hands both intrinsics to the target's `legalizeIntrinsic`, which had
no case for them. Five gcc c-torture files use them (`20010122-1`, `20030323-1`,
`20030811-1`, `pr17377`, `frame-address`).

## Semantics

MOS has two stacks and no frame chain on either, so only level 0 can be
answered; other levels produce `0`, which is what SelectionDAG's generic
expansion of `FRAMEADDR`/`RETURNADDR` returns.

- `__builtin_frame_address(0)` is the incoming soft stack pointer: the address
  just above the function's soft-stack frame, where its stack arguments begin.
  It is a fixed frame object at offset 0, so the existing frame-index lowering
  produces it (`FP + StackSize`, i.e. the incoming `__rc0`) and no frame pointer
  is forced.
- `__builtin_return_address(0)` is the word `JSR`/`JSL` pushed on the hard stack
  plus one: both push the address of their own last byte, and `RTS`/`RTL` add
  one. SPC700 `CALL` pushes the return address itself, so it gets no adjustment.
  For a `JSL`-called function the bank byte is not part of the 16-bit result.
- An interrupt handler has no C return address (`P` sits above the interrupted
  `PC`, and the 65816 handler prologue pushes more), so it returns `0`.

## Implementation

How deep the pushed word sits below the stack pointer at the point of the read
depends on what the prologue and the register scavenger pushed ahead of it
(callee-saved registers, `PHA`/`PLA` brackets around frame-index expansions,
`PHP`), none of which exists before frame lowering. So:

1. The legalizer emits two `G_RETURN_ADDRESS_BYTE` (low and high byte) in
   place, merges them, `G_INTTOPTR`, and `G_PTR_ADD 1`. The opcode has
   `hasSideEffects`, so nothing moves or CSEs it.
2. The selector turns each into `ReturnAddressByte` (`Ac` result plus an `Xc`
   scratch) or, on the 65816, `ReturnAddressByteSR` (`Ac` result only), so
   register allocation handles the clobbers like any other instruction.
3. A new pass, `MOSLowerReturnAddress`, runs at the end of `addPreSched2`, after
   both scavenger passes and the late optimizer. It computes the hard-stack
   depth at the start of every block by forward dataflow over the CFG (every
   path into a block must agree, which `RTS` needs anyway), adds the pushes
   that precede each pseudo within its block, and expands it:
   - 6502 family (8-bit `S`, stack in page 1; SPC700 through its `TSX` and
     `LDA abs,X` equivalents): `tsx` ; `lda $0101+d+byte,x`
   - 65816 (16-bit `S` anywhere in bank 0): `lda 1+d+byte,s`

`MFI.setReturnAddressIsTaken(true)` is recorded; `setFrameAddressIsTaken` is
not, since the frame address needs no frame pointer.

Tests: `llvm/test/CodeGen/MOS/return-frame-address.ll` (mos6502 at `-O0` and
`-O2`, mosw65816 at `-O2`, MachineVerifier on: plain read, read displaced by a
callee-saved push, level 1, interrupt handler, frame address with and without a
frame, frame address level 1) and `llvm/test/CodeGen/MOS/return-address-spc700.ll`
(the SPC700 forms and the missing `+1`).

Validated on llvm-mos `742d554bf08042b8df93d791c335260fadd16643` (`llc`,
assertions enabled):

- Both tests fail on the unpatched `llc` (the backend error above) and pass
  with the change, every RUN line.
- The five torture files compile at `-O0`, `-O2` and `-Os` as IR through the
  patched `llc` with `-verify-machineinstrs` (15/15).
- c-torture corpus differential, unpatched vs patched `llc`, 1,390 files ×
  `-O0`/`-O2`/`-Os`: the 15 compilations above are repaired, 0 newly fail, 36
  fail on both sides for unrelated reasons, and all 4,119 pairs that compile on
  both sides produce byte-identical assembly.
- MOS CodeGen + MC lit suites: 143 pass, 1 unsupported, 0 fail.
- Executed on SNES emulators (MAME and bsnes-jg) through the project's torture
  harness with the rebuilt toolchain: `20010122-1`, `20030323-1` and `20030811-1`
  pass in every configuration. `pr17377` and `frame-address` self-check FAIL for
  reasons outside the builtins: whole-program optimization turns `y` into a tail
  jump to `f` (the global `x` is dead), so `f` is entered from five call sites and
  the two return addresses it reports are those sites' (verified against the
  linked ROM); and `frame-address` compares the frame address against locals that
  live in the zero page under the static stack, not on the soft stack.

Assisted-by: Claude Code CLI 2.1.278 using Claude Fable 5.1 (`claude-fable-5-1`,
`high` reasoning effort) for the design, implementation, tests, validation and
PR drafting.
