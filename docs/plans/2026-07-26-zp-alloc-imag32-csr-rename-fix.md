# Fix `MOSZeroPageAlloc` Imag32 CSR rename — far pointer `[dp]` reads garbage under LTO zp-alloc

**Status:** in progress (2026-07-26). Root-cause fix for the
[far-rodata-read investigation](../investigations/2026-07-26-far-rodata-read-under-pressure-title-upload.md);
supersedes its "register pressure" hypothesis — the real trigger is **`-mlto-zp` CSR renaming**, not RA
spilling.

## Root cause (proven from the failing binary + source)

The disassembly of the failing `fft_far.sfc` (`_title_reserve`, the FONT16 upload loop) shows the far
pointer being assembled into zp bytes `$c4..$c7` (symbolized `__zp_bss…` — the **zp static stack**)
while the read is `lda [$14]` — the original `__rc20` quad. **Zero writes to `$14..$17` anywhere before
the use.** The single-function `llc` replay of the same LTO bitcode emits correct, consistent code — the
divergence needs the module-level zp budget, which comes from `mos-snes.cfg`'s **`-mlto-zp=224`**.

Mechanism (all in `llvm/lib/Target/MOS/MOSZeroPageAlloc.cpp` + `MOSMCInstLower.cpp`):

1. With a zp budget, `MOSZeroPageAlloc` picks callee-saved imaginary registers and "silently renames"
   them to zp-static-stack slots: it records `CSRZPOffsets[Reg] = offset`, frame lowering stops
   saving/restoring them, and `MOSMCInstLower` rewrites any **operand register found in the map** to
   `<fn>_zp_stk + offset`.
2. The candidate logic understands `Imag8` bytes and has a special case for **`Imag16` pairs** ("used as
   a 16-bit pointer → the two halves cannot be assigned independently"), which also records **both**
   sub-bytes *and the pair register itself* in `CSRZPOffsets`, so both 8-bit and 16-bit operand forms
   get rewritten.
3. **`Imag32` (the fork's far-pointer quad, patch `0002`/#320) does not exist in this pass.** For
   `_title_reserve`, the far pointer lives in `RL5` = `rc20..rc23` = `RS10:RS11` — squarely in the
   callee-saved range. The pass renames the four **bytes** individually; every 8-bit def is rewritten at
   MC lowering; but `LDA_IndirectLong`'s pointer operand is the **super-register `RL5`**, absent from
   `CSRZPOffsets`, so it falls through to the imag-symbol path and still emits `[__rc20]`. Defs go to
   the renamed slots, the use reads the stale quad → garbage glyphs.

Two latent hazards, one visible: (a) the missed super-register rewrite (what we hit); (b) **adjacency**
— as four independent size-1 candidates the quad's bytes are not guaranteed consecutive slots, and
`[dp]` needs 4 consecutive bytes in order even if (a) were fixed.

Why every earlier synthetic repro passed: tiny leaf programs leave the caller-saved `RL1..RL3` quads
free, so the far pointer never lands in a callee-saved quad and the pass never touches it. The "register
pressure" correlation was real but the mechanism was CSR selection, not spilling.

Why the gate CRC stayed green while the render broke: `corpus_result` never reads the title.

## Fix (mirrors the existing Imag16 idiom, same file)

1. **Candidate creation:** before the Imag16 check, look for an `Imag32` super-register of the saved
   byte with live uses. If found, promote to a single **size-4 candidate** (dedup via `Imag32Regs`),
   accounting benefit for all four bytes. This guarantees atomic selection + 4 consecutive offsets
   (fixes (b)).
2. **Offset assignment:** an `Imag32` arm in the `CSRZPOffsets` recording, entering the **quad, both
   Imag16 sub-pairs (`sublo16`/`subhi16`), and all four Imag8 bytes** at the right offsets — so every
   operand form (8/16/32-bit) is rewritten consistently at MC lowering (fixes (a)).

No change to `MOSMCInstLower` — its existing map lookup does the right thing once the map is complete.

## Verification — ALL PASS (2026-07-26)

1. Rebuild toolchain (`dev/run.sh toolchain` incremental); `0002` regen via `dev/regen-patch.sh`.

```
[3/12] Building CXX object lib/Target/MOS/CMakeFiles/LLVMMOSCodeGen.dir/MOSZeroPageAlloc.cpp.o
==> done in 0m 20s: clang version 23.0.0git (...8be0546128a55e78c63ca571d466aa72a782cd36)
RESULT: PASS — 0002 round-trips (reapplied MOS dir == live vendor)
```

**PASS.** NB the regen folded `0016`/`0017` into `0002` (both MOS-dir-only — the documented steady
state); `dev/toolchain.sh`'s list is now `0001 → 0002 → 0006`(generic hunks), verified to apply cleanly
to pristine `8be054612` with the fix present in the worktree copy.

2. The failing repro — `fft` + `TITLE_FONT16_FAR`:

```
8bb0: a7 c4   lda [$c4]     (was: a7 14 = lda [$14] with defs writing $c4..$c7)
```

**PASS** — the `[dp]` operand now names the renamed quad; the rendered title
(`build/fft-far-fixed.png`) shows "RADIX-2 DIT" in real 16×16 Waldo with drop-shadow, pixel-matching
the near-font control.

3. `mandel-double` + `TITLE_FONT16_FAR`: **PASS** — gate `RESULT: PASS ... 0x0EDF host == +mos-a16`
   (2200 frames, bsnes-jg), disasm shape unchanged (`__muldf3=8 __add/subdf3=12 rep/sep=31`), and
   `build/md-title-fixed.png` renders "MANDELBROT" in the real shadowed Waldo face — on the demo the
   font never fit before. 64 KB two-bank ROM.

4. No regression:
   - **near inertness, byte-level:** `fft` default-8 (`6013840a…`) and a16-near (`56db34fb…`) —
     **byte-identical** to the pre-fix toolchain.
   - `dev/run.sh xcheck`: **16/16 far ROMs PASS**.
   - full `dev/run.sh build`: **232 programs**, and the pre/post ROM-hash diff shows **exactly one ROM
     changed: `mandel-oop`** — an a16/far demo evidently also on the Imag32-rename path (a likely
     second silent victim). Its gate: `RESULT: PASS ... corpus_result==0x204F on host == +mos-a16`.
     Every other ROM byte-identical; none grew (`mandel-double` 65536 B is the only >32 KB demo ROM).

5. `-verify-machineinstrs`: **VERIFY-CLEAN** on both far-font builds.

## Upstream posture

The pass is upstream llvm-mos; `Imag32` is fork-only (#320). The fix rides with the #320 series (fold
into `0002` via regen), not a standalone upstream PR — noted in
[upstream-contribution-status](../upstream-contribution-status.md) only when #320 goes up.
