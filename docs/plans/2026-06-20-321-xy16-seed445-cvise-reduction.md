# #321 xy16 — fix the real seed 247/445 miscompile via cvise delta-reduction

**Execution supplement to** [`2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md`] (the canonical
Track-B plan). That plan establishes *what* the bug is and *why* reduction is the path; this one is the
*how* — the interestingness-test design, the cvise run, root-cause, fix, and verification. Fix work runs
on **`wt/321-xy16`** (`/home/will/SRC/llvm-mos-65816-xy16`); reduction runs host-side against `main`'s
prebuilt (unfixed) toolchain. Extends the shared `~/SRC/CLAUDE.md` + the project guide.

## Context

Csmith differential fuzzing found a `+mos-xy16`-only runtime miscompile on two seeds with one signature:
`default == a16 == bsnes` all agree, only the 16-bit-index `xy16` build is wrong (445: `0x0D1D` vs
`0x35E7`; 247: `0x80FE` vs `0x7C73`). Disambiguation (commit `f410115`) ran `xy16@bsnes-jg` — the leg the
original differential omitted — and **both independent emulators produce the SAME wrong xy16 value**, so
this is a **genuine compiler bug**, not a MAME `long,X` artifact. It also **falsified** the earlier
10-agent static analysis's "value-correct at every indexed op" conclusion (`wf_826f3a8e-bff`, which
refuted its own `requiredXWidth` fix 3/3). So we have **no verified root cause**, and lesson #1 applies
hard: **measure, don't assume** — static prediction has already been wrong here twice.

The reliable, theory-free path is **delta-reduction**: shrink seed 445 to a minimal program that still
miscompiles under xy16, then read the small divergence directly. `cvise` is installed (`/usr/bin/cvise`
2.12.0, `clang_delta` backend). Track A (the `requiredXWidth` 8-bit-indexed-family *hardening*) is a
separate, already-scoped latent-defect fix that does **not** change 247/445's output — out of scope here.

## Key design constraint (resolved during exploration)

An **x86 host build is NOT a valid same-width UB oracle.** Csmith's frozen profile uses 16-bit `int`
(`examples/65816/csmith/platform.info: integer size = 2`) and the generated code uses bare `int` loop
counters / array indices (e.g. seed-00445.c `for (i = 0; i < 2; i++) transparent_crc(g_6[i], …)`), which
are 16-bit on target but 32-bit on x86 — host and target compute *different* values. So robustness against
cvise introducing UB must come from a **target-only multi-config differential**, not a native oracle (Risks).

---

## Phase A — `dev-setup` Taskfile target (reproducibility; the user's explicit ask)

Add a `dev-setup` task to `Taskfile.yml` (no such task exists today) that installs the **host-side**
prerequisites the reduction/differential needs, idempotently. Concretely now: `cvise`; make it the home
for future host prereqs ("Everything must be reproducible").

```yaml
  dev-setup:
    desc: "Install host-side dev/test prerequisites (cvise for C-reduction, …). Idempotent; uses sudo apt."
    cmds:
      - |
        set -euo pipefail
        need=()
        command -v cvise >/dev/null || need+=(cvise)
        if [ ${#need[@]} -eq 0 ]; then echo "host prereqs already present: cvise"; exit 0; fi
        echo "installing: ${need[*]}"
        sudo apt-get update -qq
        sudo apt-get install -y "${need[@]}"
```

Stage **only** `Taskfile.yml`; generic dev convenience independent of the xy16 fix; lands on `main`.

---

## Phase B — interestingness test + reduce seed 445 (host-side, against the *current* unfixed toolchain)

Reduction does **not** rebuild the compiler — it runs the already-built `build/llvm-mos-install` toolchain
on `main` against thousands of candidates, all host-side (no Docker, no MAME). Scratch lives in a
gitignored dir; the durable artifact is the interestingness script.

**B0. Seed file.** Start from `build/fuzz-triage/csmith-seed-00445.c` (8966 B — smaller of the two; 247 is
the cross-check). cvise reduces a single self-contained TU, so first **inline the force-included adapter**:
prepend `examples/65816/csmith/csmith_snes.h` and keep `-I vendor/csmith/include` on the build (csmith
runtime headers stay external — cvise only edits the TU).

**B1. The interestingness test** — `dev/reduce-xy16.sh` (durable; committed with the fix). Given the
candidate TU in cwd, build **4 configs** with the prebuilt toolchain into unique temp paths, read each
build's `corpus_result` from **bsnes-jg only** (load-insensitive ⇒ parallel-safe; MAME is not), and return
interesting iff the bug-signature holds. Exact commands (lifted from `tools/a16_fuzz.py`):

- Build (per config): `"$MOS_TOOLCHAIN"/bin/mos-clang --config build/install/bin/mos-snes.cfg
  -mcpu=mosw65816 <FEATURE> <OPT> -include <adapter> -I vendor/csmith/include
  -Wl,-Map=out.map -o out.sfc cand.c`
  - default-Os → `<FEATURE>=` *(none)*, `<OPT>=-Os`
  - default-O0 → *(none)*, `-O0`
  - a16-Os → `-Xclang -target-feature -Xclang +mos-a16`, `-Os`
  - xy16-Os → `-Xclang -target-feature -Xclang +mos-xy16`, `-Os`
- Value read-back (per build): offset+len from that build's *own* map via the `corpus_result` line
  (`a16_fuzz.map_lookup`: VMA=`int(f[0],16)`, size=`int(f[2],16)`), then
  `build/jgxcheck out.sfc vendor/bsnes-jg/Database 0x<off> <len> 0x0 180` and parse `got=0x([0-9A-Fa-f]+)`
  from stdout (jgxcheck prints `got=` on both PASS and FAIL; sentinel want `0x0`). No `got=` / timeout ⇒
  that build produced **no value**.
- **Interesting iff** all four compile+link, all four boot and yield a definite value, AND
  `V(default-Os) == V(default-O0) == V(a16-Os)` (trusted oracle self-consistent across opt-level *and* the
  maximally-different a16 codegen — a strong UB filter) **AND** `V(xy16-Os) != V(default-Os)` (miscompile
  persists). Anything else (compile fail, xy16 hang/crash, oracle configs disagreeing, symbol GC'd) ⇒
  **not interesting** — keeps cvise on *this value bug*, away from UB and from drifting into a crash defect.
- Script hygiene: `set -euo pipefail`; `-h/--help` → usage, exit 0; `mktemp` per-config .sfc/.map;
  `|| true` around the value-extraction `grep`.

**B2. Run cvise** from the scratch dir: `cvise --n $(nproc) dev/reduce-xy16.sh cand.c` (cvise copies the
TU into per-worker temp dirs and runs the test there). Expect a sub-50-line TU. If it stalls early, fall
back to `--sllooww` passes or a manual function-level ddmin. Reduce **seed 247** independently and confirm
the two minimal cases share one idiom (validates "one bug").

**B3. Lock the minimal case.** (1) Run the **full 4-way** differential **once** including MAME to confirm
the original signature still holds (`default == a16 == bsnes`, `xy16` wrong on *both* emulators). (2) UB
backstop — the program is now tiny: review by hand and run system `clang -fsanitize=undefined,address
-Wall -Wextra` on it (not a value oracle due to int width, but it catches OOB / uninit / bad shifts);
explicitly reason about whether the divergence is int-width-dependent. Record the minimal `.c`.

---

## Phase C — root-cause the minimal case (multi-angle + adversarial verify)

With a minimal TU, root-causing is tractable. Dump and diff **xy16 vs a16** (a16 is the oracle — it
matches default+bsnes): `-Os --save-temps` asm, and MIR after the X-width pass
(`-mllvm -stop-after=mos-insert-rep-sep` / `-print-after=mos-insert-rep-sep`). Trace the exact
instruction/value where xy16 diverges from a16.

Run as a **Workflow**: N parallel agents on distinct angles (asm value-trace; MIR X-width audit;
`selectXY16` index materialization; the s32/`long` lowering path; reg-pressure/spill diff xy16-vs-a16),
then **adversarial verifiers** that try to *refute* each candidate cause against the real emulator value —
a cause is "confirmed" only when a code change (or a hand-patched ROM) flips the xy16 emulator value to
correct. The prior workflow's static theories were refuted 3/3, so **do not presuppose** the bug is
index-width: the disambiguation says it's a value bug the width-only diff missed.

Candidate surface map (a **guide** for reading the minimal case, *not* a presupposed fix — each unverified,
must survive refutation against the emulator):
- `MOSInstrInfo.cpp` `copyPhysRegImpl` (~680–691) + `MOSInstructionSelector.cpp` `selectXY16` indexed arms
  (~2749/2784/2820/2855): `LDXImag16`/`LDYImag16` move Imag16→X16; they expand to an 8-bit `LDX_ZeroPage`
  (`MOSInstrLogical.td` ~1025/1076) — *if* one runs while X=8, the high index byte is stale. (Prior
  workflow argued these are X8-pinned in real code — exactly the claim to verify, not assume.)
- `MOSInsertREPSEP.cpp` `requiredXWidth`/`insertSwitch` (~163–284) — rep/sep #$10 placement vs XLow/XHigh
  TSFlags; an edge case could leave an index transfer at the wrong width.
- `MOSLegalizerInfo.cpp` s32 merge path (~638–652) + `selectMergeValues`/`selectUnMergeValues` — a
  4-byte/`long` value routed through Imag16 under xy16's higher register pressure.
- The `mos-xy16`/`HasIndex16`/`FeatureIndex16` gate — what it enables and whether it shifts RA enough to
  expose a latent value bug elsewhere.

Cap at 3 verified-or-refuted hypotheses before reporting. Output: the exact defect (file:line + mechanism),
proven by an emulator-value flip.

## Phase B+C — RESULT (2026-06-20): minimal repro + verified root cause

**cvise converged** the 852-line preprocessed seed 445 → **18 lines** (and cvise *removed its own UB on its
own*: the null-pointer loop became a plain `long` counter). De-UB'd / re-minimized canonical repro (**8
lines, UB-free**, `xy16` wrong on both emulators):

```c
volatile short corpus_result;
long crc32_context, func_1_g_8; int g_21 = 535; volatile int g_59; char g_110_2;
void crc32_byte(char b) { crc32_context = b; }
void func_12(int x) { (void)x; g_59; }
void main(){ func_1_g_8=0;
  for(; func_1_g_8<=0; func_1_g_8+=1){ int *l_20=&g_21; func_12((*l_20)--); char *l_109=&g_110_2; *l_109|=g_21; }
  crc32_byte(g_21>>8); corpus_result=crc32_context; }
```
Signature (both emulators): `default = a16 = default-O0 = 0x0002`, **`xy16 = 0x0000`**. Exposing the full
`g_21` instead of `g_21>>8` gives `default=0x0216`, **`xy16=0x0016`** — `g_21`'s **high byte `0x02` is
zeroed** under xy16.

**ROOT CAUSE (verified by reading the post-LTO disasm + two emulator-value confirmations):** a 16-bit value
(`g_21`, selected into the **`Xc16`** register class — `%0:xc16 = G_LOAD16_ABS @g_21`) is held **live in the
X index register across a `sep #$10`** that `MOSInsertREPSEP` inserts to perform an unrelated **8-bit `ldy
g_110_2`**. On the 65816, **narrowing the index width to 8-bit forces `XH`/`YH` (the X/Y high bytes) to
zero** — destroying `g_21`'s high byte. The later `rep #$10; stx __rc2` then stores the corrupted `0x00xx`.
This explains *both* load-bearing pieces the reduction kept: the call+pointer (`func_12((*l_20)--)`) forces
`g_21` into `X16`; the `*l_109 |= g_21` line's 8-bit `g_110_2`→`Y` load forces the index-narrowing `sep`.
Both emulators agreeing on `0x0000` confirms they correctly zero `XH` — so it is unambiguously a **compiler**
bug (the codegen wrongly assumed `XH` survives the narrowing).

**This is NOT the `requiredXWidth` tweak the plan anticipated — it is a register-MODEL gap.** `XH`/`YH` are
modeled as registers (`MOSRegisterInfo.td:114`, sub-regs of `X16`/`Y16`), but **nothing models the index
narrowing as clobbering them**: `SEP_Immediate` carries no `Defs`, and `MOSInsertREPSEP` runs **post-register-
allocation** anyway. So the register allocator freely kept a 16-bit `Xc16` value live across an 8-bit-index
op — an impossible situation on hardware (X and Y *share* one index-width flag, so a live 16-bit index value
pins the index flag to 16-bit for its whole live range; any 8-bit-index op in that range is illegal).

Candidate fix approaches (all xy16/`HasIndex16`-gated; correctness = the 4-way differential, zero regressions):
- **(A) Model the clobber for regalloc:** make instructions that require 8-bit index (`requiredXWidth==XW_X8`)
  implicitly clobber `XH`/`YH`, so the allocator spills any live 16-bit index value across them. Correct and
  general; breadth/possible-pessimization risk; closest to the true hardware model.
- **(B) Steer instruction selection** away from `Xc16`/`Yc16` for `G_LOAD16_ABS`-style values that aren't
  genuine index uses (prefer `A16`/`Imag16`), so the 16-bit value never lands in an index reg it can't keep.
  More localized; risks moving rather than fixing the problem.
- **(C) Spill in `MOSInsertREPSEP`:** at a narrowing point where `XH`/`YH` is live, save/restore the 16-bit
  index value around the `sep`. Most localized to the symptom; complex (post-RA spill insertion + liveness).

Saved repros: `/tmp/xy16-reduce-445/SAVED-minimal-v1.c` (8-line UB-free), `…-cvise18.c` (raw cvise output).

**Full root-cause + the explored approaches:** [`docs/investigations/65816-xy16-index16-highbyte-clobber.md`](../investigations/65816-xy16-index16-highbyte-clobber.md).

---

## Phase D — fix — **DONE via approach B** (commit `2d8ab51`)

Approach **A′** (pre-RA `XH`/`YH` clobber) and **#2** (scheduler/liveness) were both implemented/investigated
and **refuted** — they founder on the same rock: the conflict (a 16-bit value held in X across an 8-bit-index
op) is created *at register allocation*, invisible to any earlier pass. **Approach B** root-fixes it
*upstream* of that: in `MOSInstructionSelector.cpp` `selectXY16`'s `G_LOAD16_ABS` case, the over-eager direct
`LDXAbs16`/`LDYAbs16` (which created the spurious `Xc16` value in the first place) now fires **only when the
loaded value is genuinely used as an index** (has a non-COPY user); otherwise the dst is reclassed to
`Imag16` and lowered through the accumulator (`selectMem16Abs`'s `LDAbs16`→`STAImag16`). ≈22 lines,
`HasIndex16`-gated ⇒ a16/DEFAULT byte-identical **by construction** (`selectXY16` is unreachable without
`+mos-xy16`). Genuine-index codegen is unchanged (no regression); only the spurious-spill shape — the bug —
is diverted, and the result is *smaller* (the pointless `ldx`/`sep` round-trip is gone).

**Where it ran:** on `main` (the integration branch carrying the current `0002` + the incremental build
tree; the historical `wt/321-xy16` worktree is on an older branch). `0002` was regenerated via a **clean temp
reconstruction** (pristine + committed `0001`/`0002`/`0003` + just this fix) so a concurrent worker's
uncommitted **#320 far-pointer** `vendor/` changes were **not** absorbed. No standalone micro-test was added
— seeds 247 + 445 are deterministic and live in the csmith corpus (the 101–500 sweep is the regression
guard); a minimal standalone test would compile to all-X8 under LTO and not exercise the X=16 ambient (same
caveat as `55ec505`).

---

## Phase E — verify — **RESULT (2026-06-20): all PASS**

1. **Build:** `dev/run.sh toolchain` (incremental, on `main`).
   ```
   ==> done in 0m 12s: clang version 23.0.0git (…/llvm-mos.git c798c31416f7)
   ```
   **PASS** — fresh `clang-23` (re-linked).
2. **Fix works (the headline):** minimal + 247 + 445, all four configs, both emulators.
   ```
   minimal:  default=0x0002  default-O0=0x0002  a16=0x0002  xy16=0x0002   (want 0x0002)
   seed 445: default=0x0D1D  default-O0=0x0D1D  a16=0x0D1D  xy16=0x0D1D   (want 0x0D1D)
   seed 247: default=0x80FE  default-O0=0x80FE  a16=0x80FE  xy16=0x80FE   (want 0x80FE)
   csmith harness (incl. MAME):  [ ok ] seed 247 0x80FE (all agree) · [ ok ] seed 445 0x0D1D (all agree)
   ```
   **PASS** — xy16 now matches the oracle everywhere (was 247:0x7C73, 445:0x35E7).
3. **No a16/default regression — byte-identical:** the fix is entirely inside `selectXY16`, reached only
   under `STI.hasIndex16()` (`MOSInstructionSelector.cpp:280`) → **unreachable** for a16/DEFAULT.
   **PASS by construction** (gating — stronger than a spot byte-diff; steps 2 & 5 also show default/a16
   values unchanged).
4. **No xy16 regression:** the xy16 micro-test suite.
   ```
   xy16basic  PASS (0x0042)
   xy16ops    PASS (0x2A42, both emulators)   <- genuine index path (LDXImag16/LDAbsXIdx16) UNCHANGED
   xy16indiry PASS (0x7E5A)
   xy16spill  PASS
   xy16spillr PASS (0x3457)
   ```
   **PASS** — genuine-index codegen untouched (the fix diverts only the spurious-spill shape).
5. **No broad regression:** csmith sweep + c-torture.
   ```
   ==> csmith: 182/200 PASS, 0 xfail, 18 skip  (0 mismatch, 0 crash, 0 error)   [seeds 101–300]
   ==> csmith: 186/200 PASS, 0 xfail, 14 skip  (0 mismatch, 0 crash, 0 error)   [seeds 301–500]
   ==> torture-run: 60 PASS, 0 FAIL, 0 SKIP, 0 XFAIL (of 60)  [default==+mos-a16==+mos-xy16, MAME + bsnes-jg]
   ```
   **PASS** — 0 mismatch/crash/error over 400 csmith seeds (247 + 445 pass in-sweep); c-torture 60/60 clean.
6. **`-verify-machineinstrs` clean; `0002` round-trips; staged exactly my files.**
   ```
   verify-machineinstrs (xy16, minimal):              CLEAN (no verifier errors)
   git apply --check 0002 on pristine+0001+0003:      CLEAN ✓
   git diff --cached --name-only:  TODO.md  patches/llvm-mos/0002-321-accum16.patch   (no vendor/, no foreign)
   ```
   **PASS** — and the `0002` regen via a clean temp reconstruction left the concurrent #320 far-pointer
   `vendor/` work untouched (0 far-pointer symbols absorbed).

---

## Risks & mitigations

- **cvise introduces UB → false reduction.** Mitigated by the 3-config trusted-oracle agreement
  (`default-Os == default-O0 == a16-Os`) *plus* the tiny-case hand+sanitizer UB review (B3). No x86 oracle
  is possible (16-bit `int`), so this layered guard is the substitute.
- **Reducer drifts to a different bug** (xy16 crash, or a16's known s32-merge gap). Mitigated: the test
  requires xy16 to **boot and produce a value that differs**; the a16 build must *succeed and agree*.
- **MAME flakiness under parallel load.** The hot loop uses **bsnes-jg only** (load-insensitive); MAME is
  used once in B3 and in Phase E, never inside the loop.
- **The fix theory is wrong** (static prediction refuted twice). Mitigated by Phase C's adversarial-verify
  gate — a cause is accepted only when a change flips the *emulator* value.
- **Hot shared `main` tree.** Reduction writes only gitignored scratch; the fix lands on `wt/321-xy16`; the
  Taskfile change stages only `Taskfile.yml`.

## Deliverables / commits (all on `main`)
- `ba93049` — Phase A `Taskfile.yml` `dev-setup` task + `dev/reduce-xy16.sh` (cvise interestingness test).
- `4a7a46b` · `8de0bd9` · `4d148dd` · `a199678` · `6e5df4b` — the investigation record (root cause; the
  refuted A′ + #2; the M2 upstream entry; approach B verified).
- **`2d8ab51`** — the fix: `patches/llvm-mos/0002-*.patch` (`selectXY16` genuine-index gate) + TODO mark.
- The handoff note and the open xy16 TODO item are marked **resolved** — this plan's Phase E is the
  verification record; the full root-cause arc lives in the investigation doc.

## References
- Canonical Track-B plan [`2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md`]; handoff
  [`2026-06-20-321-xy16-csmith-seed247-mismatch-handoff.md`]; the landed X-flag-lattice fix
  [`2026-06-19-321-xy16-xflag-lattice-fix.md`] (`55ec505`). Code: `MOSInsertREPSEP.cpp`,
  `MOSInstructionSelector.cpp` (`selectXY16`), `MOSInstrInfo.cpp` (`copyPhysRegImpl`). Engine:
  `tools/a16_fuzz.py` (`compile_rom`/`evaluate`/`map_lookup`), `dev/jgxcheck.cpp`. Worktree mechanics:
  `docs/howto-feature-worktree.md`.
