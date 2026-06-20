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

---

## Phase D — fix

Fix at the Phase-C root cause, in `vendor/llvm-mos/` (edited in place). Constraints:
- **HasIndex16-gated** ⇒ `+mos-a16` and DEFAULT builds stay **byte-identical** (verify, don't assume).
- Conservative (lesson #2): a misclassification must only ever *miss a win / add a safe `sep`*, never regress.
- Regenerate the tracked patch with `dev/regen-patch.sh`; sanity-check `0002` didn't absorb foreign hunks
  (`grep -c <foreign-symbol> patches/llvm-mos/0002-*.patch`).
- Add the minimal `.c` as a **regression micro-test** in the xy16 differential set (regression guard).

**Where it runs:** built+tested on **`wt/321-xy16`** (`main`/a16 untouched). The worktree has no built
toolchain; per `docs/howto-feature-worktree.md`, `cp -al` the prebuilt `build/` subdirs in so
`dev/run.sh toolchain` does an **incremental** rebuild. (Phase B ran against `main`'s prebuilt *unfixed*
toolchain — correct; only Phase D needs the rebuilt one.)

---

## Phase E — verify (run each; paste raw output + PASS/FAIL back into this file)

1. **Build:** `dev/run.sh toolchain` on the worktree; confirm fresh `clang-23` mtime (stale-binary gotcha).
2. **Fix works (the headline):** seeds 247 **and** 445 → `0x80FE` / `0x0D1D` on **both** `xy16@MAME` and
   `xy16@bsnes-jg`; the minimal repro agrees 4-way.
3. **No a16/default regression — byte-identical:** diff a16 and DEFAULT disasm of 247/445 + the xy16
   micro-tests pre/post-fix — **zero** change (proves HasIndex16 gating).
4. **No xy16 regression:** `xy16basic`/`xy16ops`/`xy16indiry`/`xy16spill*` PASS; `k_isort` xy16 leg agrees.
5. **No broad regression:** `dev/run.sh fuzz --gen csmith 200 101` + `… 200 301` → 0 *new* mismatch
   (247/445 now PASS); `dev/run.sh torture 60` clean.
6. **`-verify-machineinstrs` clean**; `0002` round-trips; `git diff --cached --name-only` is exactly my
   files (never `vendor/`, a foreign patch, or `docs/transcripts/`).

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

## Deliverables / commits
- `main`: `Taskfile.yml` `dev-setup` task (Phase A).
- `wt/321-xy16`: `dev/reduce-xy16.sh` (interestingness test) + the minimal repro + the `vendor/` fix's
  `patches/llvm-mos/0002-*.patch` regen + the xy16 regression micro-test; update this plan + the canonical
  Track-B plan with verification evidence; on success retire the handoff note + the open xy16 TODO item.

## References
- Canonical Track-B plan [`2026-06-20-321-fix-xy16-csmith-seed247-445-mismatch.md`]; handoff
  [`2026-06-20-321-xy16-csmith-seed247-mismatch-handoff.md`]; the landed X-flag-lattice fix
  [`2026-06-19-321-xy16-xflag-lattice-fix.md`] (`55ec505`). Code: `MOSInsertREPSEP.cpp`,
  `MOSInstructionSelector.cpp` (`selectXY16`), `MOSInstrInfo.cpp` (`copyPhysRegImpl`). Engine:
  `tools/a16_fuzz.py` (`compile_rom`/`evaluate`/`map_lookup`), `dev/jgxcheck.cpp`. Worktree mechanics:
  `docs/howto-feature-worktree.md`.
