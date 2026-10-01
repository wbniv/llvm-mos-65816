# Carry scheduling's pressure contract under the native-width pressure sets

Status: **landed downstream** (2026‑10‑01), after the user approved the recommendations: native option (a), accepting the upstream design's native residue without renumbering, and the accumulator set kept at every level, accepting the `-O2` clock cost. `0002` now carries the #320/#321 split's native-width pressure-set design, and the new standalone patch **`0071-mos-accumulator-pressure-set`** adds the accumulator set. The installed toolchain is bit-identical to the measured candidate. See [Landing](#landing). Earlier the same day: investigated and measured, then escalated. TODO item: "Resolve the carry-scheduling pressure contract and profitability choice" ([canonical record](../defects/mos-carry-scheduling-pressure.json)). It follows the escalated downstream step of the [native-width pressure-set plan](2026-09-30-native-register-pressure-sets.md#application) (step 6).

Attribution: Claude Code 2.1.285, model Claude Opus 5.5 (`claude-opus-5-5`), `high` reasoning effort; session `310aee67-a99e-4b78-ba48-c560322fe80d`, agent `a0bbc91b2d36f234d`.

No visible surface: compiler change, no mockups.

## Question

The upstream-bound native-width pressure-set design (origin `b145a581`) sets `GeneratePressureSet = 0` on `Ac16`, `Xc16` and `Yc16`. The generated tables then hold upstream's 6 sets instead of 14. Applied downstream, default-mode code grows by 13,427 B (+0.58%) at `-Os`, and native code by about 3 KB. The evidence attributed this to computed-carry scheduling (`0064`/`0067`): it saves 39,209 B with the old sets and 492 B with the new ones. The user chose to keep the downstream sets for now and to retune carry scheduling so that its benefit rests on an explicit signal instead ([decision](2026-09-30-native-register-pressure-sets.md), 2026‑10‑01).

## Method

- Baseline, "current downstream": `build/far-review-defects/candidate/llc`, `f1fa50a225c36607…`. It is also the shared `build/llvm-mos/bin/llc`.
- The upstream design applied downstream: `build/pressure-sets/final/downstream/llc`, `9f9b74f91eab29e1…`.
- Exploration builds come from a private copy of `vendor/llvm-mos` and `build/llvm-mos` in the worktree `/home/will/llvm-mos-65816-carrypress` (branch `wt/carry-pressure-contract`). The copy was current with the shared build: `ninja -n llc` had no work to do before any edit. It carries the upstream design's `vendor-candidate.diff` plus hidden exploration options in `MOSRegisterInfo`. Frozen as `build/carry-press-ir/llc/llc-x1`…`llc-x4` in the main checkout. With every option at its default, `llc-x3` gives the upstream design's size for every one of the 262 default and 276 `+mos-a16` inputs.
- Inputs: the 277 SNES corpus and demo sources of the downstream evidence, emitted by the installed project clang (`clang-23` `254624ba…`) per mode at `-Os`, `-Oz`, `-O2` and `-O3` ([`gen-ir.sh`](../defects/evidence/2026-10-01-carry-pressure-contract/tools/gen-ir.sh)). The `-Os` IR is byte-identical to the IR behind the 2026‑09‑30 numbers. `llc -O2` compiles the `-Os`, `-Oz` and `-O2` IR; `llc -O3` compiles the `-O3` IR. Bytes are `.text`+`.data`+`.rodata` ([`llc-sizes.sh`](../defects/evidence/2026-10-01-carry-pressure-contract/tools/llc-sizes.sh)).

## Root cause

**What 0064/0067 read.** The carry model reads no pressure set. `MOSSchedStrategy` counts live computed `Cc` virtual registers at each boundary from the DAG's data edges (the defining `SUnit` and its users). Its excess above one is the first comparison in `tryCandidate`. After it come the physical `Ac`, `XY` and `Imag8` operand counts, then the generic `RegExcess`, `RegCritical` and `RegMax` comparisons over the pressure sets. `Cc` counts toward `Pc` (limit 4) and `GPR_LSB` (limit 6) in both tables, so the generic trackers never saw carry excess. That is why 0064 exists ([record](../defects/mos-carry-scheduling-pressure.json)).

**What the extra sets supplied.** The one dimension that matters is the accumulator. In the old tables, `Ac` counts toward the `Ac16` set (limit 2, set 0). Upstream's 6 sets count `A` only in `GPR_LSB` (limit 6), together with `X`, `Y`, `C` and `V`. The `X`/`Y` sets (`Xc16`, `Yc16`, limit 4) barely matter: an appended `A16` set alone reproduces the old tables' default-mode MachineLICM and MachineSink behaviour, and adding `X16`/`Y16` sets moves the total by 324 B.

**Where the bytes move.** Three pressure consumers act, and carry scheduling is only one of them. Default mode, `-Os`, 262 inputs, bytes against the current downstream (2,315,097 B):

| Consumers enabled | Old sets, carry on | Old sets, carry off | Upstream sets, carry on | Upstream sets, carry off |
|---|---:|---:|---:|---:|
| All (as shipped) | 0 | +39,209 | +13,427 | +13,919 |
| MachineLICM off | −50,927 | −11,264 | −49,127 | −48,211 |
| MachineLICM and MachineSink off | −26,330 | +13,967 | −25,051 | −24,099 |
| Scheduler pressure tracking off (`-misched-regpressure=false`) | +20,915 | +21,109 | +25,203 | +25,391 |

- **MachineLICM** refuses a hoist that would push any set to its limit (`CanCauseHighRegPressure`). With the accumulator set at limit 2, it declines to lengthen accumulator live ranges across loops. Without it, it hoists more, and at `-Os` that costs bytes. With MachineLICM off, the set change costs 1,800 B instead of 13,427 B.
- **The scheduler**, when it can see the accumulator, keeps accumulator pressure low. On its own that hurts: it interleaves multi-byte arithmetic so that computed carries overlap. In the TEA loop of the new test, the candidate without carry scheduling emits 21 branches on the carry (`bcs`/`bcc`, as in the carry-save sequence); with carry scheduling it emits none. With LICM and Sink off and carry scheduling off, the old sets are 38,066 B worse than the upstream sets. Carry scheduling, checked first, forbids those overlaps; with it on, the old sets are 1,279 B better.
- So carry scheduling's 39 KB under the old sets is mostly the repair of the accumulator dimension's side effect in the scheduler. The accumulator dimension's own gain comes through MachineLICM and MachineSink. Under upstream's sets there is nothing left to repair (carry scheduling saves 492 B), and the MachineLICM gain is gone. Carry scheduling needs no retune; it needs its partner signal back, made explicit.
- With scheduler pressure tracking off, an appended `A16` set (limit 2) and the old tables give the same size for every input (2,336,012 B in total). The `Ac16` accumulator set is the whole default-mode difference in MachineLICM and MachineSink.

**The native residue.** Under `+mos-a16` both tables have an accumulator set, and with scheduler pressure tracking off the old and new tables give the same size for every input (2,443,550 B in total over 276 inputs). The whole residue is therefore in the scheduler's generic comparisons. `+mos-a16`, `-Os`, bytes against the old tables:

| Native sets | Carry on | Carry off |
|---|---:|---:|
| Upstream design: `A16`, `X16`, `Y16` appended after the generated sets | +3,003 | +1,638 |
| Same sets numbered before the generated sets | +972 | +907 |
| `A16` only, numbered first | +402 | +375 |
| `A16` only, numbered first, native classes not counted in their low byte's sets | +210 | not run |

- Numbering explains about half. `RegPressureTracker` reports the first changed set in ID order, and `tryPressure` prefers to raise the set with the higher score, which by default is the ID. The old `Ac16` set was set 0; the appended `A16` is set 6. Ranking the appended sets lowest through `getRegPressureSetScore`, without renumbering, makes it worse (+5,621 B).
- The split `X16`/`Y16` sets (limit 2 each, `XY` in neither) explain most of the rest.
- The last 402 B (carry on) sit in 17 larger and 8 smaller inputs, and two inputs hold 398 B of them: `bitboard64` (+259 B, in `bitboard64_step` and `main`) and `invaders` (+139 B). They were not isolated further (three hypotheses spent: numbering, `X`/`Y` shape, low-byte counting).

## Design

**An explicit accumulator pressure contract.** `MOSRegisterInfo` appends one target-defined pressure set for the accumulator in 8-bit mode, with **limit 1**: the 8-bit accumulator holds one byte. It uses the same hooks and tables as the native-width design, which appends `A16`, `X16` and `Y16` under `+mos-a16`. `Ac` counts toward it, and so does the `A` register unit. Carry scheduling (0064/0067) stays as it is. The contract is written down where carry scheduling lives: the carry model assumes the generic heuristics see the accumulator, and this set is that signal.

- **Limit.** 1 is the honest capacity and wins: at `-Os` it saves 15,117 B against the current downstream, where limit 2 (the old incidental value) saves 1,266 B and limit 3 grows 4,894 B.
- **Level gating: none.** The set is kept at every level. It is smaller at all four levels and faster at `-O3`. At `-O2` it is 0.16% slower than the current downstream, all of it from one sim (see [measurements](#measurements)). Following the native `-O3` gate instead would make default `-O3` code 0.47% larger and 0.30% slower than the current downstream.
- **Native modes are unchanged**: the upstream design as it stands.
- **Placement.** A standalone downstream patch after `0002`, beside 0064/0067, so that `0002` carries the upstream design verbatim. The patch owns the default-mode set and the test expectations it changes.

**Rejected alternatives.**

- *A scheduler-local accumulator signal in `MOSSchedStrategy`.* It cannot reach MachineLICM or MachineSink, where most of the regression is.
- *Retuning carry scheduling alone.* Under the 6 sets the best policy is `always`, 492 B better than `off`. No policy recovers the 13,427 B.
- *Keeping the old generated sets.* That is the incidental contract this replaces. It also keeps default mode different from upstream for reasons nobody chose.
- *Numbering the native sets first.* It closes most of the native residue, but it changes the upstream-bound #321 design, which is not this item's call (see [decision needed](#decision-needed)).

## Measurements

"Candidate" is the design above: the upstream design plus the accumulator set at every level (clean build `llc` `6f303945beb17ab3…`, frozen with its `clang-23` and `lld` in the worktree's `build/carry-press/cand/`). It gives the same size for every input as the exploration build with `-mos-default-gpr-psets=a -mos-gpr-pset-a-limit=1 -mos-default-gpr-psets-o3` at all four levels and in all three modes. "Up" is the upstream design without it. Deltas are against the current downstream (`f1fa50a2`).

**Default mode, 262 corpus and demo inputs** (15 inputs fail to compile on every compiler, as before):

| Level | Current downstream | Up | Candidate | Candidate with the native `-O3` gate |
|---|---:|---:|---:|---:|
| `-Os` | 2,315,097 B | +13,427 (+0.58%) | **−15,117 (−0.65%)** | same |
| `-Oz` | 2,065,125 B | +9,745 (+0.47%) | **−9,342 (−0.45%)** | same |
| `-O2` | 2,785,895 B | +12,537 (+0.45%) | **−20,589 (−0.74%)** | same |
| `-O3` | 3,378,949 B | +15,933 (+0.47%) | **−15,593 (−0.46%)** | +15,933 (+0.47%) |

The same design with the old limit of 2 saves 1,266 B at `-Os`, 802 B at `-Oz`, 6,623 B at `-O2`; limit 3 grows 4,894 B at `-Os`.

**Native modes** (the candidate equals the upstream design here):

| Level | `+mos-a16` | `+mos-a16,+mos-xy16` |
|---|---:|---:|
| `-Os` | +3,003 (+0.12%) of 2,441,232 B | +3,070 (+0.13%) of 2,431,285 B |
| `-Oz` | +1,014 (+0.05%) of 2,177,933 B | +1,081 (+0.05%) of 2,172,436 B |
| `-O2` | +3,517 (+0.12%) of 2,843,519 B | +3,467 (+0.12%) of 2,809,815 B |
| `-O3` | +15,025 (+0.42%) of 3,615,453 B | +15,150 (+0.42%) of 3,566,435 B |

At `-O3`, current downstream fails on 2 `+mos-a16` inputs and 3 `+mos-a16,+mos-xy16` inputs where the upstream design fails on 0 and 1; those are left out of the totals.

**Fixed set** (38 MOS CodeGen tests and 52 corpus IRs of the split's evidence, with per-level size attributes; `-O3` uses the `-O2` inputs at `llc -O3`):

| Level | `mos6502` (57 inputs): up / candidate | `mosw65816` (83): up / candidate | `+mos-a16` (86): up |
|---|---:|---:|---:|
| `-Os` | −609 / **−4,360 (−1.30%)** | +1,681 / **−2,683 (−0.77%)** | +153 (+0.04%) |
| `-Oz` | −449 / **−4,338 (−1.29%)** | +1,664 / **−2,723 (−0.78%)** | +153 (+0.04%) |
| `-O2` | −502 / **−4,329 (−1.28%)** | +1,881 / **−2,934 (−0.83%)** | +147 (+0.04%) |
| `-O3` | −753 / **−4,388 (−1.29%)** | +1,548 / **−3,130 (−0.88%)** | +669 (+0.19%) |

**Master clocks** of the 17 corpus sims, from `main` to the write of the expected result (bsnes-jg cycle probe; all 408 runs pass and are deterministic):

| Level, mode | Current downstream | Up | Candidate |
|---|---:|---:|---:|
| `-O2` default | 351,187,956 | +253,302 (+0.07%) | +545,878 (+0.16%); 9 sims faster, 3 slower |
| `-O3` default | 310,146,318 | +943,748 (+0.30%) | **−630,626 (−0.20%)**; 10 faster, 1 slower |
| `-O2` `+mos-a16` | 352,265,270 | −130,856 (−0.04%) | = up |
| `-O2` `+mos-a16,+mos-xy16` | 349,073,278 | −129,592 (−0.04%) | = up |
| `-O3` `+mos-a16` | 316,112,188 | +448,302 (+0.14%) | = up |
| `-O3` `+mos-a16,+mos-xy16` | 314,118,098 | +47,212 (+0.02%) | = up |

At `-O2` default, `fenwick_sim` alone is +749,216 clocks (+4.5%, +28 B, one more `jmp` in `main`); the other 16 sims are 203,338 clocks faster together. Its cause is not isolated. Numbering the native sets first gives the current downstream's clocks exactly at `-O2` in both native modes and the upstream design's at `-O3`.

## Decision needed

**Decided 2026‑10‑01 (user, through the coordinator):** native option (a), so the native residue is accepted and the split's native sets are not renumbered; and decision 2, keeping the accumulator set at every level including `-O2`. See [Landing](#landing).

ESCALATE: the native half of the bar cannot be met without changing the upstream-bound #321 design, which is the user's call.

1. **Native size.** The candidate leaves native modes as the upstream design has them: +0.05% to +0.13% bytes at `-Os`/`-Oz`/`-O2` and +0.42% at `-O3` against the current downstream. The accumulator-set idea does not apply there, because native mode already has an accumulator set. The measured options, all changes to the #321 design and so to the split series:
    - **(a) Accept** the native residue: +3,003 B `+mos-a16` at `-Os`.
    - **(b) Number the appended native sets before the generated ones:** +972 B at `-Os`, and the current downstream's clocks at `-O2`.
    - **(c) (b) with a single `A16` set natively**, dropping the `X16`/`Y16` sets: +402 B at `-Os`.
    - The `-O3` residue (+0.42%) comes from the user's native `-O3` gate, which drops every appended set at `-O3`. The current downstream still has an accumulator set there, and is 0.14% faster (`+mos-a16`). Revisiting that gate is a separate call.
2. **Default `-O2` clocks.** The candidate is 0.16% slower than the current downstream at `-O2`, all from `fenwick_sim`, and 0.74% smaller. Gating the set off at `-O2` would give the upstream design's +0.45% bytes and +0.07% clocks, which is worse on both counts. The recommendation is to keep it.
3. **Upstream 0064.** The posted PR is unaffected in what it claims: its focused MIR result stands, and its 117 upstream pairs were identical, which is consistent with this finding. Under upstream's 6 sets, carry scheduling is nearly neutral on C code (−492 B here). The large downstream gains it cites, as "separate downstream measurements", came through the incidental accumulator set that upstream does not have. Pairing 0064 with an accumulator pressure set would be a separate upstream proposal, with its own upstream measurements. Nothing about the posted PR or its branch was changed.

**Separate finding: MachineLICM at `-Os`.** Disabling MachineLICM shrinks default code by 2.2% (−50,927 B) and `+mos-a16` code by 3.3% (−81,109 B) against the current downstream. With the candidate it still saves 49,391 B more (−64,508 B default against the current downstream). Its hoists at `-Os` cost bytes on MOS even with the accumulator set. This is a candidate for its own item: gate MachineLICM, or its high-pressure test, at `optsize`/`minsize`, measured for clocks at `-O2`/`-O3`. It was not pursued here.

**Separate observation.** A limit of 1 on the *native* `A16` set (an exploration option only, never a candidate) makes llc fail with "ran out of registers during register allocation" in `dpend_step` (`corpus_dpend_sim`, `double-pendulum`, `+mos-a16`, `-Os`). It is reachable only through that hidden option, so it is recorded here and not filed. It shows that register allocation still has a schedule-dependent exhaustion path.


## Landing

Approved 2026‑10‑01. The landing contract:

- `0002` carries the split design verbatim, without `getLargestRegClassForRegPressureSet`, which the downstream TRI lacks.
- The accumulator set is a new standalone patch after `0002`, registered in `dev/toolchain.sh` and in `dev/regen-patch.sh`.
- A fresh bootstrap is proven.
- The shared `vendor/` gains only these files, and the shared toolchain is rebuilt.
- Records are updated.

Evidence: [`landing/`](../defects/evidence/2026-10-01-carry-pressure-contract/landing/).

- **Patch:** [`patches/llvm-mos/0071-mos-accumulator-pressure-set.patch`](../../patches/llvm-mos/0071-mos-accumulator-pressure-set.patch). It is the measured candidate patch byte for byte.
- **Bootstrap:** `dev/toolchain.sh` applies it after `0070`.
- **`dev/regen-patch.sh`:**
    - `STANDALONE_MOSDIR` lists it after `0070`, so every regen reverses it out of `0002`.
    - `TESTRELS` gains `native-width-default-pressure.ll` and `native-width-pressure-opt-level.ll`. They belong to `0002`, and `0071` updates the first.
- **Shared tree:** before the edit, the shared `vendor/llvm-mos` matched origin's stack (with `0068`) except for three pre-existing foreign items, and all eight landing files matched or were absent. The eight files were copied in and nothing else changed. The foreign items were left untouched:
    - a 2026‑08‑04 extra case in `asm-printer.mir`;
    - a 2026‑09‑23 comment edit in `spill-hoist-scratch-vreg.ll`;
    - an untracked transcript.
- **Installed toolchain:** changed at 2026‑10‑01T03:06Z.
    - Now: `llc` `6f303945beb17ab3…`, `clang-23` `e532fbee9b788713…`, `lld` `0d74dddcab805faf…`.
    - Before: `f1fa50a2…`, `254624ba…`, `c89b04cb…`.
    - The new binaries are bit-identical to the measured candidate, so every measurement above applies to the installed toolchain.

### Landing verification

L1. `0002` round-trips, and every line it changes against origin's `0002` is the split design or its tests.

    ```text
    $ dev/regen-patch.sh            # worktree vendor copy = origin stack + split design + 0071
    RESULT: PASS — 0002 round-trips (MOS dir + focused tests == live vendor)
    llvm/lib/Target/MOS/MOSRegisterInfo.cpp: +125 -0; not in split design 0; split design missing 0
    llvm/lib/Target/MOS/MOSRegisterInfo.h: +25 -0; not in split design 0; split design missing 0
    llvm/lib/Target/MOS/MOSRegisterInfo.td: +6 -0; not in split design 0; split design missing 0
    llvm/lib/Target/MOS/MOSSubtarget.cpp: +1 -0; not in split design 0; split design missing 0
    llvm/test/CodeGen/MOS/native-width-default-pressure.ll: new file, 124 lines (byte-identical to the 2026-09-30 downstream split-design test)
    llvm/test/CodeGen/MOS/native-width-pressure-opt-level.ll: new file, 30 lines (byte-identical to the 2026-09-30 downstream split-design test)
    RESULT: every changed line is the split design or its tests; no foreign hunk
    ```

    PASS.

L2. A fresh bootstrap applies the whole stack and reproduces the built source.

    ```text
    $ git archive 8be0546128a5 | tar -x -C build/bootstrap-proof; git -C build/bootstrap-proof init -q
    $ (apply block of dev/toolchain.sh, each patch via git -C build/bootstrap-proof apply)
    applied 59 patch invocations, failures=0          # last: 0070, 0071
    $ rsync -rlcn --delete --exclude=/.git build/bootstrap-proof/ vendor/llvm-mos/
    (no differences)
    ```

    PASS.

L3. The shared toolchain rebuilds, and the installed tools are recorded.

    ```text
    $ flock -w 14400 build/.heavy-build.lock env BUILD_JOBS=6 dev/run.sh toolchain     # main checkout
    ==> done in 5m 42s ... TOOLCHAIN-rc=0
    e532fbee9b78871393d3f990b72dc66cec8e7d04b3443621f40a7fd8cf3822b9  build/llvm-mos-install/bin/clang-23
    0d74dddcab805faf5e2848e9667af5af8b58bae2a66284099c1f63738e6094e1  build/llvm-mos-install/bin/lld
    6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19  build/llvm-mos/bin/llc
    # = build/carry-press-ir/cand/{clang-23,lld,llc}, the measured candidate
    ```

    PASS.

L4. Lit on the shared build passes: the MOS suites and the focused set.

    ```text
    $ llvm-lit -s -j3 CodeGen/MOS MC/MOS         # shared vendor tests, shared build/llvm-mos
    -- Testing: 196 tests, 3 workers --
      Unsupported:   4 (2.04%)
      Passed     : 192 (97.96%)
    lit-rc=0
    $ llvm-lit -s -j3 <TESTRELS> accumulator-pressure-set.ll char-stats.ll
    -- Testing: 37 tests, 3 workers --
      Unsupported:  3 (8.11%)
      Passed     : 34 (91.89%)
    lit-rc=0
    ```

    PASS.

L5. With the installed `llc`, the size tables and the verifier sweep match the candidate.

    ```text
    $ JOBS=2 size-matrix.sh installed build/carry-press-ir configs.txt "Os Oz O2 O3" "default a16 a16xy16"   # llc = build/llvm-mos/bin/llc
    installed == measured candidate per input (sizes and failures): 12 of 12 level/mode tables
    == Os default: 262 inputs; base 2315097 B   installed 2299980 B   -15117 (-0.65%)
    == Oz default: 262 inputs; base 2065125 B   installed 2055783 B    -9342 (-0.45%)
    == O2 default: 262 inputs; base 2785895 B   installed 2765306 B   -20589 (-0.74%)
    == O3 default: 262 inputs; base 3378949 B   installed 3363356 B   -15593 (-0.46%)
    == Os a16 +3003 (+0.12%) · a16xy16 +3070 (+0.13%)   Oz +1014 / +1081 (+0.05%)
    == O2 a16 +3517 / a16xy16 +3467 (+0.12%)            O3 +15025 / +15150 (+0.42%)
    $ JOBS=2 size-matrix.sh installed ... configs-verify.txt     # -verify-machineinstrs
    installed verifier failures (-verify-machineinstrs) == candidate verifier failures: 12 of 12
    verifier-only failure: O3 a16xy16 truchet.c (repeat sighting of mos-xy16-preserve-x-p-save, also on f1fa50a2)
    $ sha256sum build/llvm-mos/bin/llc      # after the runs
    6f303945beb17ab3c8a568ca135b926633533b592b01dd6677c22d49fcceca19
    ```

    PASS: the tables match [Measurements](#measurements) exactly, and the verifier finds nothing new.

L6. Clocks with the installed `llc` match the candidate.

    ```text
    $ runtime-clocks.py clocks-installed --level O2 --level O3 --modes default,a16,a16xy16 --variant installed=build/llvm-mos/bin/llc
    102 PASS, all reused from the cache (same object hash as the measured candidate)
    installed vs measured candidate: identical object and clocks 102 of 102
    O2 default 351733834 · O2 a16 352134414 · O2 a16xy16 348943686 · O3 default 309515692 · O3 a16 316560490 · O3 a16xy16 314165310
    ```

    PASS: the same totals as [Measurements](#measurements).

L7. SDK rebuild, `corpus` and `corpus-a16`.

    ```text
    # Worktree, with the bit-identical toolchain; SDK and all 296 programs rebuilt from a fresh SDK build tree:
    ==> FAILED (3): ascast ascast_sim lzss-gallery          # the known failures only
    $ dev/run.sh corpus
    ==> corpus: 84/84 passed                                  # MAME
    $ dev/run.sh corpus-a16                                    # step 6 above, same binaries and SDK
    ==> corpus-a16: 83/83 passed, 0 xfail                     # host == default == +mos-a16 == +mos-xy16, MAME + bsnes-jg
    $ dev/run.sh farblit                                       # 0069/0070 gate, worktree, same binaries
    RESULT: PASS — Farblit access shapes verified; host == A16 == A16+XY16 on both emulators: 0x1E56EE65, pressure 0xD695
    ```

    PASS. These ran in the worktree, not the shared `build/`. The shared SDK (`build/install`) was **not** rebuilt. Its libraries were built by the previous compiler, and a `dev/run.sh build` there would not rebuild them: its toolchain stamp is unchanged, and ninja does not track the compiler binary. Wiping the shared SDK build under the agents now using it is the coordinator's call.

## Verification

Evidence: [`docs/defects/evidence/2026-10-01-carry-pressure-contract/`](../defects/evidence/2026-10-01-carry-pressure-contract/README.md). The per-input tables of every run are in its `sizes.tar.gz`.

1. The copied build is current before any edit, and the exploration llc with default options gives the upstream design's size for every input.

    ```text
    $ dev/container.sh -- ninja -C /work/build/llvm-mos -n llc        # worktree copy, before any vendor edit
    ninja: no work to do.
    $ llc-sizes.sh llc-x1 X1-none.tsv def-os.list && cmp X1-none.tsv B-always.tsv && echo "default==B"
    default==B
    $ llc-sizes.sh llc-x1 X1-a16-axy.tsv a16-os.list && cmp X1-a16-axy.tsv B-a16-always.tsv && echo "a16==B"
    a16==B
    $ diff <(up.Os.default.tsv, compiled inputs) <(B-always.tsv)   # llc-x3, per input
    x3 default per-input == B (262 compiled)
    $ diff <(up.Os.a16.tsv, compiled inputs) <(B-a16-always.tsv)
    x3 a16 per-input == B
    ```

    PASS.

2. Default-mode size at `-Os`/`-Oz`/`-O2`/`-O3` over the 262 inputs: the candidate does not grow in total against the current downstream at `-Os`.

    ```text
    $ size-matrix.sh matrix IRROOT configs-default.txt "Os Oz O2 O3" default; matrix-summary.py matrix --modes default
    == Os default: 262 inputs; base 2315097 B; llc failures base=15, candA1=15, candA1o3=15, candA2=15, up=15
       candA1       2299980 B   -15117 (-0.65%)  larger  36 smaller 202
       candA1o3     2299980 B   -15117 (-0.65%)  larger  36 smaller 202
       candA2       2313831 B    -1266 (-0.05%)  larger  67 smaller 120
       up           2328524 B   +13427 (+0.58%)  larger 207 smaller  35
    == Oz default: 262 inputs; base 2065125 B
       candA1o3     2055783 B    -9342 (-0.45%)  larger  36 smaller 200
       up           2074870 B    +9745 (+0.47%)  larger 201 smaller  35
    == O2 default: 262 inputs; base 2785895 B
       candA1o3     2765306 B   -20589 (-0.74%)  larger  44 smaller 187
       up           2798432 B   +12537 (+0.45%)  larger 179 smaller  55
    == O3 default: 262 inputs; base 3378949 B
       candA1       3394882 B   +15933 (+0.47%)  larger 176 smaller  61
       candA1o3     3363356 B   -15593 (-0.46%)  larger  49 smaller 179
       up           3394882 B   +15933 (+0.47%)  larger 176 smaller  61
    # candA1o3 = the candidate (set kept at every level); candA1 = the same with the native -O3 gate.
    $ size-matrix.sh ... configs-clean.txt (clean llc 6f303945)   ->   per input, clean == candA1o3 at Os, Oz, O2, O3
    ```

    PASS: −15,117 B (−0.65%) at `-Os`, and smaller at every level.

3. Native size at every level (276 `+mos-a16`, 276 `+mos-a16,+mos-xy16` inputs): not worse in total than the current downstream.

    ```text
    $ matrix-summary.py matrix --modes a16,a16xy16          # the candidate equals "up" per input in both modes
    == Os a16: 276 inputs; base 2441232 B       up 2444235 B    +3003 (+0.12%)  larger 148 smaller  13
    == Os a16xy16: 276 inputs; base 2431285 B   up 2434355 B    +3070 (+0.13%)  larger 143 smaller  12
    == Oz a16: 274 inputs; base 2177933 B       up 2178947 B    +1014 (+0.05%)  larger  46 smaller  17
    == Oz a16xy16: 274 inputs; base 2172436 B   up 2173517 B    +1081 (+0.05%)  larger  42 smaller  17
    == O2 a16: 274 inputs; base 2843519 B       up 2847036 B    +3517 (+0.12%)  larger 143 smaller  22
    == O2 a16xy16: 273 inputs; base 2809815 B   up 2813282 B    +3467 (+0.12%)  larger 136 smaller  24
    == O3 a16: 275 inputs; base 3615453 B       up 3630478 B   +15025 (+0.42%)  larger 148 smaller  75
    == O3 a16xy16: 274 inputs; base 3566435 B   up 3581585 B   +15150 (+0.42%)  larger 139 smaller  82
    ```

    FAIL, escalated: native is worse at every level. See [decision needed](#decision-needed).

4. The fixed set (38 MOS CodeGen tests + 52 corpus IRs, `mos6502`, `mosw65816`, `+mos-a16`) at each level.

    ```text
    $ fixed/run.sh; matrix-summary.py fixed --modes mos6502,mosw65816,a16
    == Os mos6502: 57 inputs; base 335153 B      cand -4360 (-1.30%)   up  -609 (-0.18%)
    == Os mosw65816: 83 inputs; base 348577 B    cand -2683 (-0.77%)   up +1681 (+0.48%)
    == Os a16: 86 inputs; base 342428 B                                up  +153 (+0.04%)
    == Oz mos6502: 57 inputs; base 335113 B      cand -4338 (-1.29%)   up  -449 (-0.13%)
    == Oz mosw65816: 83 inputs; base 348524 B    cand -2723 (-0.78%)   up +1664 (+0.48%)
    == Oz a16: 86 inputs; base 342306 B                                up  +153 (+0.04%)
    == O2 mos6502: 57 inputs; base 337871 B      cand -4329 (-1.28%)   up  -502 (-0.15%)
    == O2 mosw65816: 83 inputs; base 352121 B    cand -2934 (-0.83%)   up +1881 (+0.53%)
    == O2 a16: 86 inputs; base 345333 B                                up  +147 (+0.04%)
    == O3 mos6502: 57 inputs; base 340094 B      candkeep -4388 (-1.29%)   up  -753 (-0.22%)
    == O3 mosw65816: 83 inputs; base 355287 B    candkeep -3130 (-0.88%)   up +1548 (+0.44%)
    == O3 a16: 86 inputs; base 346717 B                                up  +669 (+0.19%)
    # 33 mos6502 and 7 mosw65816 inputs fail on every compiler (65816-only IR among them); candkeep = the candidate.
    ```

    PASS for default modes; native as in step 3.

5. Clocks at `-O2`/`-O3` on the 17 corpus sims, every mode.

    ```text
    $ dev/container.sh -- python3 runtime-clocks.py clocks --level O2 --level O3 --modes default,a16,a16xy16 --jobs 3 \
        --variant base=llc-base --variant up=llc-x4 "--variant=cand=llc-x4:-mos-default-gpr-psets=a -mos-gpr-pset-a-limit=1 -mos-default-gpr-psets-o3" \
        --variant upfirst=llc-x4:-mos-gpr-psets-first
    408 PASS (all deterministic)
    $ clocks-summary.py results.tsv --ref base --vs up
    == O2 default:  base 351,187,956 | up +253,302 (+0.07%) | cand +545,878 (+0.16%), -348 B, faster 9 slower 3
    == O3 default:  base 310,146,318 | up +943,748 (+0.30%) | cand -630,626 (-0.20%), -950 B, faster 10 slower 1
    == O2 a16:      base 352,265,270 | up = cand -130,856 (-0.04%) | upfirst = base
    == O2 a16xy16:  base 349,073,278 | up = cand -129,592 (-0.04%) | upfirst = base
    == O3 a16:      base 316,112,188 | up = cand = upfirst +448,302 (+0.14%)
    == O3 a16xy16:  base 314,118,098 | up = cand = upfirst +47,212 (+0.02%)
    # O2 default per sim: fenwick_sim +749,216 (+28 B); the other 16 sims -203,338 together.
    $ (clean llc 6f303945 on the same 102 IR/level/mode jobs)   ->   clean llc objects equal to the measured cand objects: 102 of 102
    ```

    PASS at `-O3`. At `-O2` the candidate is 0.16% slower than the current downstream (one sim), and 0.74% smaller; kept, see [decision needed](#decision-needed).

6. The candidate toolchain builds. MOS lit passes. `-verify-machineinstrs` over the corpus IR is clean. `dev/run.sh corpus-a16` passes (host == default == `+mos-a16` == `+mos-xy16` on MAME and bsnes-jg).

    ```text
    $ flock -w 14400 build/.heavy-build.lock env BUILD_JOBS=6 dev/run.sh toolchain     # worktree
    [37/45] Linking CXX executable bin/clang-23 ... ==> done in 2m 42s          TOOLCHAIN-rc=0
    llc 6f303945beb17ab3 · clang-23 e532fbee9b788713 · lld 0d74dddcab805faf
    $ llvm-lit -s -j4 CodeGen/MOS MC/MOS        # before updating the two expectations
    FAIL: CodeGen/MOS/char-stats.ll; FAIL: CodeGen/MOS/native-width-default-pressure.ll   (Passed 190, Unsupported 4)
    # char-stats: mos6502 140 -> 142 B; native-width-default-pressure: 79 -> 84 B (mos6502), 77 -> 82 B (mosw65816);
    # regenerated with update_llc_test_checks.py --llc-binary cand/llc, as part of the candidate patch
    $ llvm-lit -s -j2 CodeGen/MOS MC/MOS
    -- Testing: 196 tests, 2 workers --
      Unsupported:   4 (2.04%)
      Passed     : 192 (97.96%)
    lit-rc=0
    $ accumulator-pressure-set.ll red/green (llc | FileCheck), mos6502 / mosw65816
    base f1fa50a2 PASS / PASS · up 9f9b74f9 FAIL / FAIL · candidate 6f303945 PASS / PASS · candidate -mos-carry-sched=off FAIL / FAIL
    $ size-matrix.sh verify ... (-verify-machineinstrs; candidate and current downstream; 4 levels x 3 modes)
    every level and mode: the candidate's failures are exactly its failures without the verifier, except
    O3 a16xy16: truchet.c fails only under the verifier, on the current downstream too
    (PH $p "Using an undefined physical register" after MOS Insert REP/SEP; a repeat sighting of
    mos-xy16-preserve-x-p-save, appended to that record). The current downstream also has that one.
    $ MOS_TOOLCHAIN=/work/build/llvm-mos-install bash dev/build.sh    # SDK and programs rebuilt with the candidate
    ==> FAILED (3): ascast ascast_sim lzss-gallery      # the three known failures, reproduced on the baseline (far-prerequisite plan, step 6)
    $ find build/install -name '*.a' -newer build/carry-press/cand/llc | wc -l
    77
    $ dev/run.sh corpus-a16                                          # worktree; SPC700 IPL present, no skips
    ==> corpus-a16: expected.tsv  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg; settle=1000)
    ==> corpus-a16: 83/83 passed, 0 xfail
    CORPUS-rc=0
    ```

    PASS. The candidate toolchain builds; lit passes after the two expectation updates that belong to the candidate; the verifier sweep adds nothing the current downstream does not already have; the differential passes 83/83 on MAME and bsnes-jg.
