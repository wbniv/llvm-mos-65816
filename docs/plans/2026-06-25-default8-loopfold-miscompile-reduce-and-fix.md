# Plan — reduce + root-cause + fix the DEFAULT-8bit 65816 matrix-fold-LOOP miscompile

## Context

A real **default-8bit** (no `+mos-a16`) 65816 codegen miscompile: a CRC fold over a 4-element
`int16_t m[4]`, written as the natural loop, computes a **different** runtime result than the byte-identical
**unrolled** form. The two C forms are semantically identical (no UB; `i ∈ [0,4)`, `m` has 4 elements), so a
differing runtime result is a genuine miscompile. Surfaced by the (shelved) Mandelbrot zoom demo; first
recorded in [docs/investigations/2026-06-25-default8-65816-loopfold-miscompile.md](../investigations/2026-06-25-default8-65816-loopfold-miscompile.md).
Tracked by the `TODO.md` "DEFAULT-8bit … matrix-fold-LOOP miscompile" item.

The fold (in `examples/snes/zoom.h`'s `zoom_fold`):
```c
for (int i = 0; i < 4; i++) {
  crc = zoom_crc16_byte(crc, (uint8_t)m[i]);
  crc = zoom_crc16_byte(crc, (uint8_t)((uint16_t)m[i] >> 8));
}
```
The shipped demo unrolls this as a source-level workaround, so `main` is green; the loop form is the repro.

### What changed (2026-06-25): a FAST host-side repro
The prior record said it reproduces **only** inside the full **hd** multi-bank demo via `dev/run.sh
mandel-zoom` (Docker), and that 3 standalone-minimization attempts failed. New finding: **it also reproduces
in `sd` mode (the single-bank `snes` platform), entirely host-side, in ~10 s** — no container. That makes
cvise reduction tractable (a 10 s interestingness test instead of a container build).

Evidence (host-side, `mos-snes.cfg`, `-Os`, default-8bit):
```
[loop]   ZOOM: FAIL  frames=64 nonzero=64 swaps=3 host=0xF56C rom=0xE60E
[unroll] ZOOM: PASS  frames=64 nonzero=64 swaps=3 zoom_crc=0xF56C (host replay == ROM, bsnes-jg)
```
The `ZOOM` gate replays `zoom.h` host-side over the ROM's ground-truth pad log and compares its rolling CRC
to the ROM's `zoom_crc`; the loop ROM diverges (`0xE60E` ≠ host `0xF56C`), the unrolled ROM agrees.

Repro recipe (self-contained; preserved as `dev/loopfold-repro.sh`, see *Order of execution*): bake the sd
pyramid header, build the `-DJGX_ZOOM` harness + the ROM from a scratch copy of the sources (loop vs unrolled
`zoom_fold`), run the `ZOOM` differential. `loop` → FAIL, `unroll` → PASS. No tracked-tree edits.

## Findings so far

1. **Backend/LTO codegen bug, not the middle-end.** The SNES build is **LTO** (`-mlto-zp=224`), so `-S` emits
   LLVM IR (codegen is deferred to link). The IR is correct — the fold lowers to a real `i<4` loop
   (`icmp eq i16 …, 4`). The defect appears only in the post-LTO machine code (`-Wl,--lto-emit-asm`).
2. **Not loop-vs-straightline.** The optimizer **unrolls** the `i<4` byte loop in *both* forms (the post-LTO
   asm shows straight-line per-byte CRC steps `.LBB0_76/80/84/88/92…`, each with its own 8-iteration bit
   loop). So the source loop-vs-unrolled axis isn't the trigger — both end up unrolled.
3. **Lead — an X-indexed `m[]` load under pressure. → CONFIRMED (2026-06-25) on the minimal repro.** In the
   loop form's fold, the `m[i]` bytes are sourced via **X-indexed stack loads** — `ldy mos8(.Lmain_zp_stk+1),x`
   (high) and `eor mos8(.Lmain_zp_stk),x` (low) — and the code then **immediately reuses `X` as the inner
   CRC bit-counter** (`ldx #8`). The unrolled form's `--lto-emit-asm` has **no `.Lmain_zp_stk,x` indexed
   loads at all** (constant-offset accesses only). A wrong/stale `X` at the indexed load folds the wrong
   `m[]` byte → wrong CRC, matching the register-pressure sensitivity (standalone/minimal versions don't
   exhaust pressure, so the wrong-`X` window doesn't open → they compile correctly).
4. **Default-8bit / baseline.** No `+mos-a16` involved, so per the investigation's caveat this may be an
   **upstream llvm-mos** issue rather than a 65816-fork (#320/#321) one — determine during reduction (does it
   reproduce on `mos6502`, or only `mosw65816`?).

## Approach

1. **Preserve the repro.** Land `dev/loopfold-repro.sh` (the fast host-side sd repro) as the durable artifact;
   it is the cvise interestingness oracle and the regression-gate prototype.
2. **Reduce (cvise/creduce).** Preprocess the failing TU to a single `.c`, then `creduce` it with the
   interestingness test = "builds default-8bit **and** the `ZOOM` differential FAILs while the source-unrolled
   control PASSes" (the fast repro, ~10 s/iteration). Reduce to a minimal `.c` (and ideally a frozen `.ll`).
3. **Classify upstream vs fork.** Re-target the minimal repro at `mos6502` (and stock upstream llvm-mos if
   available). If it reproduces on `mos6502`, it's an **upstream** bug → file there; if `mosw65816`-only, it's
   in the 65816 patches → fix in `vendor/` + regen `0002`.
4. **Root-cause.** From the minimal repro, confirm the mechanism behind finding #3 (trace `X`'s definition into
   the indexed `m[]` load; is `X` clobbered between its set and use, or is the index/address computation
   wrong?). Pin the responsible pass (regalloc / a peephole / address-mode folding).
5. **Fix + regression test.** Land the minimal backend fix (with `-verify-machineinstrs` clean), add a
   hermetic regression (`examples/65816/loopfold.c` + a `.sh`, and/or a frozen `.ll` `llc` gate), and confirm
   the natural loop form now matches the unrolled/host result. Restore `zoom.h` to the loop form (remove the
   unroll workaround) once green, or keep the unroll with a comment pointing at the fixed bug.

**Worktree discipline.** The reduction + fix are exploratory → run on a `throwaway/<slug>` worktree off `main`
(this plan + `dev/loopfold-repro.sh` are the durable artifacts merged back). Reach the prebuilt toolchain via
the main checkout (`build/llvm-mos-install`, `build/install`) rather than rebuilding.

## Order of execution

1. Land `dev/loopfold-repro.sh` + this plan; update the `TODO.md` item with the fast-repro breakthrough.
2. On a throwaway worktree: preprocess the failing TU, write the creduce interestingness script (wraps
   `loopfold-repro.sh`), run `creduce` → minimal `.c`.
3. Classify `mosw65816` vs `mos6502` (upstream vs fork) on the minimal repro.
4. Root-cause the wrong-`X` (or address-fold) defect; identify the pass.
5. Implement the fix; add the regression test(s); `-verify-machineinstrs` clean; differential green.
6. Merge the durable artifacts back to `main`; (optional) drop the `zoom.h` unroll workaround.

## RESULT (2026-06-25): reduction done — minimal repro + confirmed root-cause lead

cvise converged the full `mandel-zoom.c` (151 lines) → **51 lines raw**, hand-cleaned/de-UB'd to a
**43-line** minimal repro: [`spikes/2026-06-25-loopfold-min.c`](spikes/2026-06-25-loopfold-min.c). The
reduction held `zoom.h` **fixed** (host and target must compile the *same* fold) and shrank only the
pressure **context**; the interestingness predicate was the **loop-vs-unroll control on the same
candidate** (loop build ZOOM FAIL ∧ unroll build ZOOM PASS, both pinned to the canonical `host=0xF56C`
scenario) — which rejects any cvise edit that introduces UB or collapses the trigger. Harness (reproduces
the whole run): [`dev/reduce-loopfold.sh`](../../dev/reduce-loopfold.sh) (`setup`/`interesting`/`reduce`).

The repro is **minimal by ablation**: removing *any* one of its four pressure sources —
`snes_ppu_reset_blank()`, the inline palette `REG_CGDATA` loop, `apply_zoom()`'s `REG_CGDATA` loop, or the
`img_hash16` boot loop — makes the bug vanish (loop then matches unroll). That delicate simultaneity is
exactly why the earlier standalone-minimization attempts failed.

**Root-cause lead — CONFIRMED (finding #3).** The post-LTO `--lto-emit-asm` diff (loop vs unroll) shows the
loop form sources the `m[i]` matrix bytes via **X-indexed stack loads** that the unroll form never emits:
```
.LBB0_79:                       ; the i<4 matrix-fold loop (depth 2)
  tax                           ; X = byte offset (i*2) into m[] on the stack
  ldy  mos8(.Lmain_zp_stk+1),x  ; m[i] high byte   <-- X-indexed
  sty  __rc2
  lda  __rc7
  eor  mos8(.Lmain_zp_stk),x    ; m[i] low byte    <-- X-indexed
  ldx  #8                       ; X immediately REUSED as the inner CRC bit-counter
```
The unroll asm has **no `.Lmain_zp_stk,x` indexed loads** (constant-offset only). A wrong/stale `X` at the
indexed load folds the wrong `m[]` byte → wrong CRC (`rom 0xE60E` vs correct `host/unroll 0xF56C`). The
exact wrong-X mechanism (clobber vs bad index arithmetic; which pass) is the root-cause task (Verification
step 4).

**Accumulator-width classification (2026-06-25, on the minimal repro, target-only on bsnes):** the bug is
**8-bit-accumulator (default) only** — `mosw65816` default loop `0xE60E` ≠ unroll `0xF56C`, while
`+mos-a16` (16-bit accumulator) is clean (loop `==` unroll `== host == 0xD351`). `+mos-a16` is 65816-only,
so the defect is in the 65816 8-bit codegen. A `-mcpu=mos6502` build on the SNES platform is **not** a
valid 6502 oracle (65816 crt0/ABI — the correct unroll form returns `0xFF4B`), so upstream-vs-fork is
settled by the responsible pass's provenance during root-cause, all on the 65816.

**Root-cause narrowing (2026-06-25, asm structural diff loop vs unroll):** the loop form is the one that
**materializes `m[]` as a contiguous array in the ZP soft-stack** and folds it via X-indexed loads:
- loop: `.size .Lmain_zp_stk, 16` — `m[]` stored at `+0..+7` (8 stores), fold reads `mos8(.Lmain_zp_stk{,+1}),x`.
- unroll: `.size .Lmain_zp_stk, 2` — `m[]` never arrayed; values stay in registers, no indexed loads.

Two sub-hypotheses **refuted** on the asm: (1) the index ZP slots `__rc5`/`__rc6` are *not* clobbered by the
inner CRC bit-loops (no uses in their block range); (2) `m[]` at `+0..+7` is *not* overwritten between its
store and the fold. So it is **not** a simple index clobber — the defect lives in the `m[]`
materialize-and-index sequence under the surrounding ZP-soft-stack pressure (the spill/reassembly at the
matrix store, or the X-offset induction), a path the unroll form never takes.

**Provisional upstream-vs-fork (pass provenance):** this is **default 8-bit** codegen — ZP soft-stack frame
+ regalloc + indexed addressing, all **upstream llvm-mos** machinery. The fork's `0002` *does* touch
`MOSInstrInfo::loadStoreRegStackSlot`/`copyPhysRegImpl`, but those hunks are **`+mos-a16`-gated** (16-bit-
accumulator spill), and `+mos-a16` tested **clean** — so the buggy default-8bit path doesn't run `0002`'s
additions. **Likely an upstream `llvm-mos` bug.** Definitive confirmation (next): reproduce on a **pristine
(no-`0002`) toolchain**; if it still miscompiles, file upstream.

### MIR dive (#1, 2026-06-25): structure verified correct at every level → a DYNAMIC liveness clobber
Captured MIR through the LTO link (`-Wl,--lto-emit-asm -Wl,-mllvm,-print-after=greedy/mos-late-opt/
mos-static-stack-alloc/mos-zero-page-alloc`). Pass pipeline suspects: `mos-zero-page-alloc`,
`mos-static-stack-alloc`, greedy regalloc, `mos-late-opt`, post-RA scavenger (no per-pass disable flags in
the MOS backend; `llc` standalone does **not** reproduce — the bug needs the exact LTO pipeline/pressure).
What the MIR/asm shows, all **structurally correct**:
- IR: loop form allocates `@zp_stack = [16 x i8]` (m[] is an addressable array) vs unroll `[2 x i8]`.
- After greedy: `m[]` = `%stack.0` (+0..+7); stores hold the right values — `m[3]=%1847:%1856` equals `m[0]`
  is **legitimate CSE** (`zoom_matrix`: `m[0]==m[3]==cos*scale`). Fold: `LDAbsIdx %stack.0+1,%1539` (high)
  + `EORAbsIdx %stack.0,%1539` (low), index `%1539` = the loop offset.
- asm: offset induction 0,2,4,6; byte order low-then-high; **trip count exactly 4** (16-bit counter
  `__rc3:X` exits at 4 — verified the `cpx #4`/`inc;dec __rc3;beq` exit). Index ZP slots `__rc5`/`__rc6` and
  `m[i]`-high slot `__rc2` are **not** clobbered by the inner CRC bit-loops; `m[]` not overwritten between
  store and fold.

So it is **not** a wrong index / wrong value / wrong order / off-by-one — every inspectable structure is
correct, yet the runtime value diverges (`0xE60E` vs `0xF56C`). Conclusion: a **dynamic register/ZP-slot
liveness clobber** under the loop form's pressure (a value the allocator treats as safe is overwritten at
runtime) — consistent with the extreme pressure-sensitivity and invisible to static MIR inspection.

### Pass-disable bisection (#1, 2026-06-25): the disablable passes are NOT the culprit; bug is verifier-clean
Rebuilt the **asserts** toolchain (`dev/run.sh asserts-build`, keeps the shared `-install` clang pristine;
confirmed it reproduces `0xE60E`/`0xF56C`) with default-off `cl::opt` toggles added to the three
*optional* post-RA passes (reverted after). Bisection (judge on the runtime `zoom_crc` of the loop form):
```
baseline (no flag):       0xE60E   (buggy)
-mos-disable-late-opt:    clang ABORTS  (mandatory — absence leaves invalid MIR; asserts catch it)
-mos-disable-scavenging:  clang ABORTS  (mandatory)
-mos-disable-copy-opt:    <no-value>    (non-running ROM)
-verify-regalloc / -verify-coalescing / -verify-machineinstrs:  ALL CLEAN
```
None yield `0xF56C`. So the miscompile is **not** in any disablable peephole, and it survives every
register-allocation/liveness/machine verifier — a **silent miscompile in non-disablable core machinery**
(greedy regalloc / instruction selection / ZP-stack allocation / coalescer) whose own correctness model is
satisfied. Generic `-mllvm` toggles also don't fix it (`-enable-misched=false`, `-enable-post-misched=false`,
`-disable-machine-cse`, `-disable-post-ra` → still `0xE60E`; `-regalloc=basic`/`-join-liveintervals=false`
→ non-running, the MOS target depends on greedy+coalescing; `-regalloc=fast` → out of registers).

**Bisection (#1) exhausted.** Remaining method to pin the exact instruction is the **dynamic trace** (#2):
MAME debugger watchpoint on the diverging ZP byte to catch the clobber live. Given the analysis is already
strong (minimal repro + structure verified correct + localized to verifier-clean core codegen + provisional
upstream), an alternative is to **file upstream now** with this repro+analysis and let the llvm-mos
maintainers (who own the regalloc) pin it.

### Dynamic m[] check (2026-06-25): VALUES are correct — the fold's X-indexed READ is wrong
Exposed `m[]` as a stable WRAM channel (`volatile int16_t m_log[4]; m_log[i]=m[i]` each frame, *direct*
access) and read it back on bsnes for both forms (the bug survives — still `0xE60E`/`0xF56C`):
```
loop:   zoom_crc=0xE60E   m_log = 0x0000000000400040
unroll: zoom_crc=0xF56C   m_log = 0x0000000000400040   (IDENTICAL)
```
The `m[]` **values are byte-identical** between the buggy loop form and the correct unroll form — so
`zoom_matrix` computes/stores `m[]` correctly. `m_log` reads `m[]` *directly*; the fold reads it
*X-indexed*. The fold diverges while reading from a correct array ⇒ **the defect is the fold's X-indexed
read of `m[]` returning the wrong bytes at runtime** (a wrong `X`/index value at the indexed load), NOT a
wrong `m[]` value. This dynamically **confirms finding #3** and **rules out** the value-computation/store
side. The remaining unknown is purely *why X is wrong at the load at runtime* despite the static MIR/asm
showing the offset induction as 0,2,4,6 — i.e. a runtime index/liveness corruption in core codegen, the
exact frame/instruction of which a full dynamic instruction trace (#2) would pin.

### Further grind (2026-06-25): localized to frame 0; mechanism = index threaded through the inner CRC loops
- **Frame-0 divergence.** Sweeping the emulator frame count, the ROM's rolling `zoom_crc` diverges on the
  **very first folded frame** (host `0x9F3D` vs ROM `0xCE8C` after frame 0, where `m={0x3E,0,0,0x3E}`).
- **Not an in-bounds reindex.** A brute-force over index/byte-offset corruption models of the *correct*
  in-bounds `m[]` bytes reproduces neither the frame-0 `0xCE8C` nor the full `0xE60E` — so the fold reads
  bytes that aren't the in-bounds `m[]` values (an OOB/wrong effective address, or values not derivable
  from `m[]` alone). Ground-truth from the transient ZP soft-stack frame (at ZP `0x6c`, 16 B) was too
  timing-fuzzy to capture reliably via post-hoc WRAM reads.
- **Specific to the fold's shape.** Replacing the *direct* `m_log[i]=m[i]` capture with an **indexed loop**
  `for q<4: m_log[q]=m[q]` does **not** miscompile (values stay correct) — so it is **not** a generic
  indexed-array-read bug. The trigger needs the fold's exact structure: the `m[i]` index carried across the
  **two nested 8-iteration `zoom_crc16_byte` bit-loops that reuse `X`** (`ldx #8`). The index must survive
  those inner loops; under this pressure it is corrupted, while the static save/restore slots `__rc5`
  (offset) / `__rc6` (counter) read clean — a runtime register/ZP-slot corruption invisible to static
  inspection and to every machine verifier.

**Status of the pin.** The *mechanism* is now precise (the fold's `m[i]` index is corrupted across the
inner CRC bit-loops that clobber `X`; standalone indexed reads are fine). The *exact instruction/pass*
still requires either an **instruction-level dynamic trace** (logging `X` at the fold load each frame) or
the upstream maintainers' regalloc tooling. Black-box value forensics has reached its limit.

### Instruction-trace attempt (2026-06-25): MAME 0.277 headless-debugger wall
Tried to log `X`/`PC`/`D` at the fold's `m[]` reads via the host MAME 0.277 debugger (the ZP frame is at
direct page `0x6c`, 16 B; the fold's effective read address is `0x6c+X`):
- `-debug` alone tries to open the **Qt GUI** debugger (Wayland errors) — unusable headless.
- `-debug -debugger none -debugscript` runs (debugger banner in `debug.log`) but **`printf` output is
  swallowed** and the `trace` command **writes no file**.
- The Lua API *does* expose `cpu.debug:wpset` headlessly (confirmed; CPU state keys `PC/X/Y/D/CURPC` are
  readable), but passing a **Lua function as the watchpoint action segfaults** MAME 0.277 (the action must
  be a debugger-command string, and string actions can't reach Lua/stdout under `-debugger none`).

So MAME-headless instruction tracing is blocked by tooling. The controllable alternative is to **instrument
the bsnes-jg core** (`vendor/bsnes-jg/src/processor/wdc65816.cpp`, has `r.x`) with an env-gated read hook
and rebuild the core (jgxcheck already links it) — a real but self-owned sub-project.

**Recommended next:** (1) the **pristine no-`0002` build** to make the upstream determination definitive
(the user's gate: "a patch for upstream *if it is in fact upstream*"); (2) the bsnes-core read-hook trace to
pin the exact instruction; then (3) the patch. All three are substantial; the mechanism + repro are already
strong enough to file upstream and let the regalloc owners pin the instruction if preferred.

## Verification

1. **Repro is live + fast.** `dev/loopfold-repro.sh loop` prints `ZOOM: FAIL … host=0xF56C rom=0xE60E`;
   `dev/loopfold-repro.sh unroll` prints `ZOOM: PASS … 0xF56C`. (~10 s each, host-side, no container.)
   ```
   [loop]   ZOOM: FAIL frames=64 nonzero=64 swaps=3 host=0xF56C rom=0xE60E
   [unroll] ZOOM: PASS frames=64 nonzero=64 swaps=3 zoom_crc=0xF56C (host replay == ROM, bsnes-jg)
   ```
   **PASS** — confirmed live this session.
2. **Minimal repro.** `creduce` yields a small `.c` that, default-8bit on `mosw65816`, computes a fold result
   ≠ the host/unrolled value; the source-unrolled control matches. Paste the reduced `.c` + both results.
   ```
   cvise --n 12 (interestingness = loop-build ZOOM FAIL ∧ unroll-build ZOOM PASS, zoom.h fixed):
     151 lines / 8555 B  ->  51 lines / 1073 B   (84 accepted reductions, ~26 min, exit 0)
   Hand-cleaned + de-UB'd (nf=0, sized level_hash[], dropped a dead expr): 43 lines, still reproduces:
     [loop]   ZOOM: FAIL frames=64 nonzero=64 swaps=3 host=0xF56C rom=0xE60E
     [unroll] ZOOM: PASS frames=64 nonzero=64 swaps=3 zoom_crc=0xF56C
   Minimal by ablation — removing ANY one collapses the bug (loop then matches unroll):
     A inline palette REG_CGDATA loop   -> collapses
     B apply_zoom() REG_CGDATA loop     -> collapses
     C img_hash16 boot loop             -> collapses
     D snes_ppu_reset_blank()           -> collapses
   ```
   Reduced `.c`: [`spikes/2026-06-25-loopfold-min.c`](spikes/2026-06-25-loopfold-min.c) (43 lines). Harness:
   [`dev/reduce-loopfold.sh`](../../dev/reduce-loopfold.sh) (`reduce` = setup + cvise; reproduces the run).
   **PASS** — reduced, de-UB'd, verified, and shown minimal by ablation.
3. **Classification.** State whether the minimal repro reproduces on `mos6502` (→ upstream) or only
   `mosw65816` (→ fork); paste the per-target results.
   ```
   target-only loop-vs-unroll on bsnes (read rom zoom_crc), minimal repro:
     mosw65816 default (8-bit A):   loop=0xE60E != unroll=0xF56C   -> BUG
     mosw65816 +mos-a16 (16-bit A): loop=0xD351 == unroll=0xD351   -> clean (loop==unroll==host)
   ```
   So the miscompile is **8-bit-accumulator (default) only** on the 65816 — now confirmed on the minimal
   repro (not just the hd demo); `+mos-a16` (16-bit accumulator) is correct. **A `-mcpu=mos6502` build on the
   SNES platform is NOT a valid 6502 oracle** (the SNES crt0/ABI are 65816): even the known-correct *unroll*
   form returns `0xFF4B != 0xF56C`, so that run is unfaithful — discarded (do not read it as "6502 clean").
   `+mos-a16` is a 65816-only feature, so the bug clearly lives in the 65816 8-bit codegen. Upstream-vs-fork
   is therefore settled by **pass provenance** during root-cause (step 4) — is the pass that emits the bad
   X-indexed load in the shared upstream tree or the fork's `0002`? — with all testing kept on the 65816.
   **Partial → provisionally UPSTREAM** (8-bit-only confirmed; `0002`'s spill hunks are `+mos-a16`-gated and
   a16 is clean, so the default-8bit path is unmodified upstream machinery — see RESULT "Provisional
   upstream-vs-fork". Definitive: reproduce on a pristine no-`0002` toolchain).
4. **Fix.** With the fix, the natural loop form == unrolled == host on the minimal repro AND in the full
   `dev/run.sh mandel-zoom` (hd) and the fast sd repro; `-verify-machineinstrs` clean. **PENDING — root-cause
   narrowed (see RESULT "MIR dive"): the codegen is structurally correct at IR/MIR/asm (m[] values, index,
   order, trip count all verified), so it's a dynamic register/ZP-slot liveness clobber under the loop
   form's pressure. Pinning the exact pass needs a dynamic trace or a pass-disable bisection rebuild.**
5. **Regression test.** The new hermetic test (`loopfold.c`/`.sh` and/or frozen `.ll` `llc` gate) FAILs before
   the fix and PASSes after; wired so the differential catches the class. **PENDING.**
6. **No collateral.** `dev/run.sh corpus` + the a16/xy16 gates stay green (the fix is default-8bit codegen but
   must not regress anything); if the fix is in `vendor/`, regen `0002` and confirm it didn't absorb foreign
   hunks. **PENDING.**

## Risks / open items

- **Reduction may collapse the trigger.** The bug is register-pressure-sensitive; creduce can delete the very
  pressure that opens the wrong-`X` window. Mitigation: the interestingness test requires the *differential*
  to FAIL (not just "compiles"), so creduce can only keep pressure-preserving reductions; if it stalls, fall
  back to a hand-guided reduction from the asm lead (the indexed `m[]` load).
- **Upstream vs fork.** If `mos6502` reproduces, the fix + filing move upstream (queue in
  `docs/upstream-contribution-status.md`); a fork-local workaround/gate may still be wanted meanwhile.
- **LTO interaction.** The defect is post-LTO; confirm it also reproduces in a non-LTO single-TU build (for a
  cleaner `llc`/`.ll` regression) or document that the regression gate must drive the LTO codegen path.
- The `sd`-mode constants (`host=0xF56C`, `rom=0xE60E`) are sd-specific; the **hd** full-demo numbers differ
  (`0xB115` vs `0x456E`) — same class, different image params. Either makes a valid interestingness oracle.
