# Round 6 Cluster G (#116–#118) — hardening the 65816-native `setjmp.S` fix

> **STATUS 2026‑09‑15: BLOCKED — the cluster did its job on its first run.** #116 `backtrack` is
> written and host-verified (`0x7336`), and it immediately surfaced an **OPEN, high-severity
> runtime defect**: `longjmp`'s page‑1 hard-stack reconstruction **never executes**, so every
> `longjmp` leaves `S` in page 0 and any return out of the `setjmp` frame `rts`-es into the zero
> page — i.e. **bug #35 is still live**, hidden from `corpus/setjmp_sim.c` because that guard never
> returns from its `setjmp` frame. Root cause, byte-level proof and a 12‑line repro:
> [`docs/investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md`](../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md).
> Per the battery's own rule — *demos exist to find compiler bugs* — the gate is **not weakened**
> to let a demo ship. #116 is committed un-gated (no `expected.tsv` row, no `dev/backtrack.sh`);
> #117 `csrjmp` and #118 `retryjmp` are **not started**, because both fail for the same reason.
> Fixing the runtime is separate, higher-tier work.


Three SNES stress-test demos that escalate past `corpus/setjmp_sim.c` (one frame, one jump, no
live callee-saved registers) into the three corners where a page‑1‑S‑reconstruct /
CSR‑restore‑offset / re‑entry defect would hide.

- Bug under guard: **#35** — the SDK's common `mos-platform/common/c/setjmp.S` is 6502-only;
  `longjmp`'s `tax; txs` restore drops the native 16‑bit `S` into page 0, so `longjmp` `rts`-es to
  garbage. Fixed 2026‑07‑02 by a shadowing `platforms/snes/setjmp.S` that reconstructs the page‑1
  16‑bit `S` (`ora #$0100; tcs`) and reads/writes the return address stack-relative.
- Records: [investigation](../investigations/2026-06-30-setjmp-longjmp-65816-native-stack-bug.md) ·
  [fix plan](2026-07-02-35-setjmp-longjmp-65816-fix.md) ·
  [cluster spec](../investigations/2026-06-27-compiler-stress-test-demo-ideas.md) (lines ~1361‑1445).

**Mockups:** none. The visible surface of each demo is a real SNES frame, and the gate itself
produces it — `build/<demo>-{mame,jg}.png` are emulator screenshots, which is stronger evidence
than a hand-drawn mockup. This matches every other demo plan in `docs/plans/2026-07-02-*`.

## The bar

Each demo carries the project differential plus the cluster's own multi-mode requirement:

| Leg | Where it runs |
|---|---|
| host oracle | `tools/<demo>-sim.c` built with the host `cc` |
| default‑8‑bit @ MAME | `dev/run.sh corpus` (manifest row) |
| default‑8‑bit == `+mos-a16` == `+mos-xy16` @ MAME, `+mos-a16` @ bsnes‑jg | `dev/run.sh corpus-a16` (the differential engine, `tools/a16_fuzz.py check`) |
| `+mos-a16` @ MAME **and** @ bsnes‑jg, with a screenshot | `dev/run.sh <demo>` |
| `-verify-machineinstrs` clean under `+mos-a16` and `+mos-xy16` | inside the `corpus-a16` engine |

Reconciling the spec's "5‑way bar (`setjmp`/`longjmp` must be correct in default **and**
`+mos-a16` **and** `+mos-xy16`)" with what the harness actually enforces: the five agreeing
legs are **host == default@MAME == `+mos-a16`@MAME == `+mos-xy16`@MAME == `+mos-a16`@bsnes‑jg**,
which is precisely what a `corpus/` manifest row buys (the same structure `corpus/setjmp_sim.c`
= `0x2007` already uses). The per-demo `dev/<demo>.sh` adds the rendered `+mos-a16` ROM asserted
on both emulators plus a disasm/structure gate. So every demo ships a `corpus/<demo>_sim.c`
slice **and** a `dev/<demo>.sh` driver — the corpus slice is what makes the bar five-way.

## #116 `backtrack` — the flagship guard

8‑queens, six independent searches (column order rotated per run so each search takes a
different path).

- `bt_descend(row)` is `noinline` and recursive: it `setjmp`s its own choice point
  `bt_cp[row]`, places the first safe column, and recurses. It **never returns** — every exit is
  a `longjmp`.
- On a dead end at depth `d`, `bt_backjump(d)` walks to the **deepest ancestor `k` that still has
  a safe, untried column** and `longjmp`s straight to `bt_cp[k]`, unwinding `d − k` `jsr` frames
  in one jump. Skipping ancestors whose remaining columns are all unsafe is sound (they would be
  exhausted immediately), so the search stays a complete, deterministic backtracking search while
  the unwind depth varies from 1 frame to many.
- A full board `longjmp`s to `bt_root` — `BT_N + 1` frames at once.
- All state that changes between `setjmp` and `longjmp` is file-scope, never a clobbered local.
- Gate CRC folds the six solution grids, the `solved` flags, `visits`, `backs`, the **summed
  unwind depth** `bt_frames`, the total event count, and the recorded event trace. A botched
  unwind corrupts the counters *and* the board.
- Visual: the recorded trace is replayed on a 8×8 board (2×2 tiles per cell) — the board fills,
  then snaps back on each backtrack, with the abandoned rows flashing.

## #117 `csrjmp` — the CSR-restore-offset guard

A `setjmp` brackets a parametric-curve (harmonograph) evaluation with 14 simultaneously-live
coefficient bytes — the width of the `__rc18..__rc31` callee-saved block the fix renumbers.

- The coefficients are loaded, the `setjmp` is taken, a `noinline` worker scribbles over every
  callee-saved slot and `longjmp`s back, and the coefficients are then used to render.
- An off-by-one in the restore offsets corrupts exactly one coefficient → one axis of the curve
  warps visibly and the CRC diverges.
- Gate CRC folds the post-`longjmp` coefficient vector **and** the rendered curve samples.

## #118 `retryjmp` — the re-entry guard

One `setjmp` site re-entered many times.

- A `noinline` recursive `rj_work(depth, …)` carries many locals (deep soft stack) and `longjmp`s
  back to the single `setjmp` on a simulated fault, from a depth that varies per attempt.
- The `setjmp` site must stay re-enterable: soft-SP restore × page‑1 `S` reconstruct × return
  address rewrite all interact on every retry.
- Gate CRC folds the retry-outcome sequence (attempt index, fault code, depth, work result).
- Visual: a progress bar advancing per successful attempt plus a depth gauge.

## Files

Per demo `<d>` ∈ {`backtrack`, `csrjmp`, `retryjmp`}:

- `examples/65816/<d>.h` — shared host+target logic (the gate)
- `examples/65816/sjcompat.h` — shared `setjmp`/`longjmp` declarations (new, used by all three)
- `examples/snes/<d>.c` — demo ROM
- `examples/snes/corpus/<d>_sim.c` + a row in `examples/snes/corpus/expected.tsv`
- `tools/<d>-sim.c` — host oracle
- `dev/<d>.sh` + `dev/<d>.lua` — driver + MAME assert
- `Taskfile.yml` — `task <d>` / `task <d>-play`

## Verification

1. `dev/run.sh backtrack`
2. `dev/run.sh csrjmp`
3. `dev/run.sh retryjmp`
4. `dev/run.sh corpus`
5. `dev/run.sh corpus-a16`
6. `dev/run.sh build` (full example battery)
7. `dev/title-charset.sh`

### Results (2026‑09‑15) — BLOCKED at step 1

**Step 1 — `dev/run.sh backtrack`: NOT RUN.** There is no `dev/backtrack.sh`: the demo's gate would
have to assert a value the runtime cannot currently produce, and weakening it is forbidden. The
equivalent evidence, produced directly:

Host oracle (`tools/backtrack-sim.c`, `cc -O2 -Wall -Wextra`):

```
backtrack visits=265 backs=83 frames=201 events=348 traced=348
backtrack gate_crc = 0x7336
```

`-verify-machineinstrs`, all three modes, clean (exit 0 each):

```
--- flags: default
  exit=0
--- flags: -Xclang -target-feature -Xclang +mos-a16
  exit=0
--- flags: -Xclang -target-feature -Xclang +mos-xy16
  exit=0
```

Target, bsnes-jg, `corpus/backtrack_sim.c` linked with `--config mos-snes.cfg`, 1200 frames:

```
default corpus_result@0x200 -> SMOKE: FAIL off=0x200 len=2 got=0x0000 want=0x7336
a16     corpus_result@0x200 -> SMOKE: FAIL off=0x200 len=2 got=0x0000 want=0x7336
xy16    corpus_result@0x200 -> SMOKE: FAIL off=0x200 len=2 got=0x0000 want=0x7336
```

Bisected from there to a 12‑line repro that has nothing to do with N‑Queens
([`sjreturn_min.c`](../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes/sjreturn_min.c)) —
`longjmp` back into a non‑`main` function which then *returns*:

```
SMOKE: FAIL off=0x20 len=2 got=0x1111 want=0xF00D
```

and to the byte-level cause in `platforms/snes/setjmp.S:170‑173`. Full write-up:
[the investigation](../investigations/2026-09-15-longjmp-page1-reconstruct-never-executes.md).

**Steps 2, 3 — `csrjmp`, `retryjmp`: NOT STARTED.** Both are `setjmp`/`longjmp` demos and would fail
identically; building them now would produce two more un-gateable ROMs and no new information.

**Steps 4, 5 — `corpus`, `corpus-a16`: not affected by this change.** Both iterate
`examples/snes/corpus/expected.tsv`, and this change adds no manifest row (see step 1 for why).
The corpus content they execute is byte-identical to before.

**Step 6 — `dev/run.sh build`:** run; result recorded in the commit message / hand-off.

**Step 7 — `dev/title-charset.sh`: not applicable.** No demo ROM with a title card ships here.

## Deferred

- #117 `csrjmp` and #118 `retryjmp` — designed above, not implemented. Blocked on the `longjmp`
  defect; pick them up in the same pass that lands the fix, since they are its natural guards.
- `dev/backtrack.sh` + `dev/backtrack.lua` + the `expected.tsv` row + the `Taskfile.yml` entries for
  #116 — all deliberately withheld until `backtrack_gate_crc()` can reach `0x7336` on target.
- The visual half of #116 (`examples/snes/backtrack.c`: trace replay on an 8×8 board with the
  snap-back animation) is specified above but not written — it would be an ungateable ROM today.
- `corpus/setjmp_sim.c` is not a sufficient guard for this bug class. Whatever fixes the runtime
  should also add a guard that *returns* from the `setjmp` frame.
