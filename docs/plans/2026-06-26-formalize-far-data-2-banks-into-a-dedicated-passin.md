# Plan — Formalize "Far data > 2 banks" into a dedicated passing gate

## Context

`docs/implementation-status.md:76` carries the deferred item:

> **Far data > 2 banks** — ⬜ Deferred past Inc 3 (far load/store proven for ≤2 banks; multi-bank
> data placement not yet exercised)

**Investigation finding: the capability is already implemented and emulator-verified — it was just
never formalized as its own gate, and the docs went stale.** Specifically:

- The clang fix that makes a far (`addrspace 2`) array index carry into the 24-bit **bank byte** is
  **landed** in `patches/llvm-mos/0001-320-far-addrspace.patch` (the `CGExpr.cpp`
  `EmitArraySubscriptExpr` hunk: promote the GEP index to the base pointer's per-address-space width
  via `getIntPtrType(getLLVMContext(), TargetAS)` → 32-bit for AS2). Before it, indices ≥ 32768
  truncated to 16 bits and mis-addressed the bank.
- `dev/run.sh k_trig32lut` **already exercises far load/store across banks `$C1`–`$C4`** (a ~200 KiB
  libfixmath sin LUT in `.far_rodata`, read via `lda [dp]`, `corpus_result == 0x87F0B404` on
  MAME + bsnes-jg). But it proves this only as a *side-effect* of a trig-accuracy test, and it's slow
  (`SMOKE_SETTLE=720`, ~14 s).
- `examples/65816/farindex.c` is the **minimal cross-3-bank repro** (reads `tbl[100]@$C1`,
  `tbl[50000]@$C2`, `tbl[90000]@$C3` on `platforms/snes-hirom`), but: (a) its header *still* describes
  the **pre-fix broken** state and says "DOCUMENTED-OPEN repro, **not yet a passing gate**"; (b) there
  is no `dev/farindex.sh` and no `dev/run.sh farindex` entry; (c) it has no `corpus_result` fold or
  host oracle, so it can't run the differential.

**Re the user's hint ("there might already be some mandelbrot programs which do this"):** the
Mandelbrot zoom pyramid (`mandel-zoom`, `platforms/snes-zoom`, 8 banks) places data across 8 banks but
accesses it via **DMA** (`bank:addr16`), *not* far load/store — it explicitly "needs no far pointer."
So it does **not** prove the far-load case. The trig sin LUT (`k_trig32lut`) is the program that
actually does. The user's intuition is right that multi-bank work exists; it lives in a different
program and mechanism than the Mandelbrot demos.

**Outcome:** promote the cross-bank far-load proof into a dedicated, fast, committed passing gate
(`dev/run.sh farindex`), then flip the stale docs to ✅ with evidence. This is **formalization +
documentation of already-working codegen** — no new compiler change.

## Approach (recommended)

Build one self-contained micro-test on the existing `platforms/snes-hirom` that reads a `const FAR`
array spanning **three** banks at runtime indices landing in `$C1/$C2/$C3`, folds the reads to
`corpus_result`, and runs the standard a16-only differential (`host == +mos-a16` @ MAME +
bsnes-jg). Reuse the established harness (`dev/_emu.sh`, the `k_trig32lut.sh` shape, the
`gen-sin-lut-asm.py` asm-emit pattern). No platform/linker change is needed — `snes-hirom` already
ships, and its `OUTPUT_FORMAT { … FULL(rom_far) }` always emits a 512 KiB image that
`tools/snes-checksum.py --hirom` accepts.

**Scope decisions (resolved, not asking):**
- **a16-only differential, no default-8-bit leg** — a runtime far pointer is a 32-bit value and its
  s32 legalization is `+mos-a16`-gated (matches every existing `far_*` test, e.g. `dev/far_indir.sh`).
- **Rewrite `farindex.c` in place** rather than add a new file — existing docs already point to it as
  *the* cross-3-bank repro; promoting it keeps those references coherent and fixes the stale header in
  the same edit.
- **Do not add a separate "distinct scalars in 3 banks via absolute-long (`lda long`/AF)" case** — the
  single-object absolute-long cross-bank read is already gated by `far-bank1` (`lda $018000`, bank
  `$01`); forcing three small scalars into distinct HiROM banks is pure linker scaffolding that proves
  nothing new. The indexed-array-spanning-3-banks case is the stronger proof (it exercises the exact
  bank-byte-carry defect this item was deferred on). Cite `far-bank1` as corroboration in the docs.

## Files to create / modify

**Create — `tools/gen-farindex-lut-asm.py`** (model on `tools/gen-sin-lut-asm.py`): emit `tbl` as
`.far_rodata` asm, `N = 98304` entries (= 3 × 32768 = 192 KiB = exactly banks `$C1/$C2/$C3`),
`tbl[i] = (i + (i >> 16)) & 0xFFFF`. Sections/format identical to the sin-LUT generator
(`.section .far_rodata,"a",@progbits` / `.global tbl` / `.balign 2` / `tbl:` / 16 `.2byte` per row).

> **Why `i + (i>>16)` and not `i & 0xFFFF`:** with plain `i & 0xFFFF` the bank-`$C3` read *aliases its
> own bug* — `90000` truncated to a signed i16 is `24464`, and `tbl[24464] == 24464 == 90000 & 0xFFFF`,
> so that read alone would not detect a regression. Adding `+(i>>16)` makes the stored value depend on
> the bank ordinal, so **each** of the three reads independently distinguishes a correct load from a
> mis-addressed one.

**Rewrite — `examples/65816/farindex.c`** into the differential micro-test shape (model the
`#ifdef HOST` split on `examples/65816/k_trig32.c:158-166`, the volatile-globals + spin on
`examples/65816/a16eqval.c:16-27`):
- Keep `extern const FAR uint16_t tbl[];` (incomplete type dodges the 16-bit-`size_t`
  "array too large" rejection; the generated asm is the sole definition).
- `volatile int32_t i0=100, i1=50000, i2=90000;` (volatile → forces runtime 32-bit far-ptr arithmetic
  → `lda [dp]`, not a constant-folded absolute-long).
- A documented **value contract**: target reads `tbl[i]`; host (`-DHOST`) computes the identical closed
  form `(uint16_t)((uint32_t)i + ((uint32_t)i >> 16))` — equal by construction, no >64 KiB host array.
- Fold the three reads (rotate-left-1 + xor) into `volatile uint32_t corpus_result;` then `for(;;){}`.
  Host build prints the value so the driver can pin the golden.
- Replace the stale header comment with a **passing-gate** description (fix landed in `0001`; reads
  `$C1/$C2/$C3`; a16-only; driven by `dev/run.sh farindex`).

**Create — `dev/farindex.sh`** (model closely on `dev/k_trig32lut.sh`, trimmed; a16-only; in-container):
0. `python3 tools/gen-farindex-lut-asm.py "$BUILD/farindex_tbl.s"`.
1. Compile `+mos-a16 -verify-machineinstrs -c` clean; `llvm-objdump -dr`; **disasm gates** (here-strings,
   per the pipefail note `k_trig32lut.sh:62-63`): `R_MOS_ADDR24_BANK.*\btbl\b` present **and**
   `lda [dp]` opcode `a7` present.
2. **Host oracle**: `cc -DHOST -O2`; assert `host == WANT` (pin `WANT` from this output; keep the
   `command -v cc` SKIP fallback).
3. Build the `+mos-a16` HiROM ROM via `mos-snes-hirom.cfg` + `tools/snes-checksum.py --hirom`.
4. **MAME**: `source dev/_emu.sh; require_bios; run_assert "$AROM" "$AMAP" corpus_result "$WANT"`.
5. **bsnes-jg**: the `build/jgxcheck` + `vendor/bsnes-jg/Database` block via `_emu_map_lookup`.
6. `emu_verdict "$rc" "far table spanning 3 banks (\$C1/\$C2/\$C3) read via lda [dp] folds to $WANT, host == +mos-a16 (both emulators)"`.

Settle budget far smaller than `k_trig32lut` (only 3 loads, no heavy compute):
`SMOKE_SETTLE=120 SMOKE_SECONDS=4 JG_FRAMES=240` (env-overridable; the driver must `export`
`SMOKE_SECONDS` itself — `dev/run.sh` does not forward it).

**Modify — `dev/run.sh`** (help strings only; dispatch is auto via `dev/<TARGET>.sh` at line ~383):
add `farindex` to the bracketed target list near line 3, and a `farindex` block to the `--help` heredoc
after the `far_tail` entry (~line 116).

**Modify — docs (record the formalized gate):**
- `docs/implementation-status.md:76` — flip ⬜ → ✅ with the `dev/run.sh farindex` evidence (3-bank
  `tbl`, `lda [dp]`, golden, both emulators) and note `k_trig32lut` independently corroborates; depends
  on the `0001` clang fix. Optionally touch the M1 verdict paragraph (lines 79–84).
- `TODO.md` — add a `## Done` entry (top, dated `2026-06-26`, matching the existing
  `- YYYY-MM-DD — [slug] **title** …` format) recording the new gate + golden + corroboration.
- `docs/ROADMAP.md` — M1 step 3 already says "≥2 banks PASS"; add one sentence that
  `dev/run.sh farindex` now formalizes the >2-bank case (`$C1/$C2/$C3`), no status flip.

## Verification

Prereqs (already built in this tree): `dev/run.sh toolchain`; `MOS_TOOLCHAIN=$PWD/build/llvm-mos-install
dev/run.sh build` (builds SDK incl. `snes-hirom`); `dev/run.sh xcheck` once (builds `build/jgxcheck`).

1. **The new gate is green:**
   ```
   dev/run.sh farindex
   ```
   Expect: disasm gate PASS (`R_MOS_ADDR24_BANK tbl` + `a7`), host oracle == `WANT`
   (hand-estimate `0x0001D8A1`; **pin to the host oracle's actual printout**), MAME `SMOKE: PASS`,
   bsnes-jg PASS, `RESULT: PASS`.
2. **The independent corroborator still passes** (shared far machinery, the >2-bank reference):
   ```
   dev/run.sh k_trig32lut   # folds 0x87F0B404
   ```
3. **No regressions:**
   ```
   dev/run.sh far_indir     # runtime far deref gate still 0xF3
   dev/run.sh corpus        # 6502 corpus 7/7
   ```
4. **Docs reflect reality:** `docs/implementation-status.md:76` reads ✅ with the gate name + golden;
   `farindex.c` header no longer says "not yet a passing gate"; `TODO.md` Done entry present.

## Risks / edge cases

- **Host/target value coupling** — the generator formula and the `-DHOST` `READ` macro are
  hand-maintained; the Step-2 `host == WANT` assert is the net that catches any drift. Comment the
  contract in both files.
- **`WANT` is hand-derived** — confirm it from the host oracle output before trusting; never hardcode
  blind.
- **A7 vs absolute-long** — `volatile` indices + offsets > 16-bit X range force a full 32-bit far
  pointer → `lda [dp]` (A7); the disasm gate asserts it.
- **No SDK/platform rebuild** — `snes-hirom` already ships and is built by `dev/run.sh build`; the
  512 KiB `FULL(rom_far)` image is checksum-tool-compatible.

## Commit

Stage only the files above (new generator + driver, rewritten `farindex.c`, `dev/run.sh`, the three
doc files). Verify `git diff --cached --name-only` is exactly that set — never `vendor/`, a foreign
patch, or `docs/transcripts/`. No `0002`/`0001` patch change (the compiler fix is already landed).
Triage any `## Inbox` the commit hooks add to `TODO.md`. End the message with the project's
`Co-Authored-By:` trailer.
