# #320 Inc 4 Ph2 M+D — measure far-ptr CC cycles, then land the winner default-on

**Date:** 2026-06-21 · **Status:** PLANNED → in progress · **Scope:** the closing two phases of the
far-pointer CC study on `wt/320-far-cc`. All four variants are built + two-emulator-verified (A0–A3a) and
byte-censused; this plan adds the **cycle** half of the measurement and then **ships the winner** as the
default far-ptr calling convention. **Builds on:**
[the build-all-variants plan](2026-06-20-320-far-pointer-cc-build-all-variants.md) (M/D phases) +
[the variant-d sub-plan](2026-06-21-320-far-cc-variant-d-stack.md).

## Where we are

| variant | flag | `.text` (round-trip source) | status |
|---|---|---|---|
| **(a) Imag32** | `+mos-farcc-imag32` | **70 B** | landed `10a5fc0` — **byte winner** |
| (b) Imag16+bank | `+mos-farcc-split` | 86 B | landed `741a8c2` |
| (c) A:X+Y | `+mos-farcc-axy` | 102 B | landed `02953e7` |
| (d) soft-stack | `+mos-farcc-stack` | 174 B | landed `ebaa515` — dominated |

Bytes already point hard at **(a)**. The go/no-go also asks for "**not materially slower in cycles**" — so M
adds the cycle evidence, and D applies the verdict.

## M — the cycle harness (net-new; the metric is emulated time)

**Verified this session:** MAME 0.285's Lua exposes **no `total_cycles()`** (nil), but `manager.machine.time`
is a readable attotime. Emulated time is exactly proportional to CPU cycles (one fixed master clock), so it
is a sound cycle proxy for a **differential** (variant-vs-variant) comparison. Build:

1. **`examples/65816/farcc_bench.c`** — a variant-agnostic workload: write a START sentinel to `$7E00F0`,
   run the far-ptr round-trip (the same `make_far_ptr()`/`deref_far()` as the gate source) in a loop of N
   (≈1000) `volatile`-anchored iterations so the optimizer can't elide the cross-call passing, write an END
   sentinel to `$7E00F2`, then the usual `corpus_result` so correctness is still checkable. Built with each
   `+mos-farcc-*` flag (variant = flag, as the gates do).
2. **`dev/probe-cycles.lua`** — boot the ROM, poll WRAM: when `$7E00F0` is set record `t0 =
   manager.machine.time`; when `$7E00F2` is set record `t1`; print a greppable `CYCLES: <Δ attoseconds>`
   line (and a human ns figure). Deterministic on MAME (and re-runnable on bsnes-jg only for the correctness
   sentinel; the *timing* number is MAME's).
3. **`dev/measure-far-cc.sh`** — for each variant: build `farcc_bench.c` with its flag, capture `.text`
   bytes (the `dev/measure-a16-threading.sh:33` `text_bytes` awk) + the `CYCLES:` Δ from probe-cycles.lua,
   and emit the N-way `prog | a | b | c | d | Δ` table (bytes + time), inner-loop isolated by the two
   sentinels. Every cell's ROM is correctness-checked (`corpus_result == 0xF3`) so a fast-but-wrong cell
   can't win.

**Fallback:** if the two-sentinel time read proves flaky, fall back to the fixed-frame iteration-count proxy
(run a fixed wall of frames, read how many loop iterations the program completed — more iterations = faster
codegen). Deterministic on both emulators.

## D — land the winner as the default far-ptr CC

Expected verdict (pending M): **(a) Imag32** — smallest, register-resident (so also fewest memory accesses
⇒ fewest cycles), and the simplest/most-consistent. The decision then **ships the capability**: a far pointer
crossing a call should *just work* with no flag (today it errors).

- **Make (a) default-on:** `MOSSubtarget::farPtrCC()` returns `Imag32` when **no** `+mos-farcc-*` feature is
  set (change the final `return None` → `return Imag32`). The b/c/d feature checks run first, so the flags
  still select them for the measurement spike; absent any flag the far ptr now uses Imag32 instead of
  erroring. `getRegisterTypeForCallingConv` already keys on `farPtrCC() != None`, so it starts sizing a
  crossing far ptr at i32 by default — exactly the intended ship.
- **Byte-identical default is preserved:** the corpus/kernels contain **no** far pointers, so their codegen
  is unchanged; the only behavioural delta is "far-ptr-across-call compiles (Imag32) instead of erroring",
  which is the whole point of #320 Inc 4. Verified by corpus 7/7 + all far ROMs `0xF3` on both emulators.
- **Patch home:** the winner stays in **`0004-320-far-cc.patch`** (it is the permanent far-CC patch).
  Promoting into `0001` is **not** clean — `0004` deliberately stacks on `0002` because the `Imag32`
  `AnyRegBank` line is shared with the a16 work (per `dev/regen-patch-0004.sh`'s header). So D keeps the
  default-on Imag32 + the shared 4-byte (dis)assembly in `0004`; the losing variants (b/c/d) **stay in
  `0004` as the inert measured spike** (each still gated off-by-default), retained on the worktree like
  `wt/321-frame-abi`. (A later cleanup could split the winner out, but that's not required to ship.)
- **Upstream:** draft the #320 CC evidence paragraph (the measured table + verdict) and queue it in
  `docs/upstream-contribution-status.md` — posting stays user-triggered.

## Phased

| Phase | Deliverable | Gate |
|---|---|---|
| **M1** | `farcc_bench.c` + `probe-cycles.lua` + `measure-far-cc.sh`; the bytes+time table for a/b/c/d. | Table emitted; every cell `0xF3`-correct; (a) not materially slower than any other (expected: fastest). |
| **D1** | `farPtrCC()` default → Imag32; a no-flag far-ptr-across-call compiles + round-trips. | A far ptr crosses a call **without any flag** and reads `0xF3` on MAME + bsnes-jg; `-verify-machineinstrs` clean; **corpus 7/7**; all far ROMs `0xF3` (no regression); `0004` round-trips. |
| **D2** | Decision record + upstream evidence paragraph; status docs → RESOLVED (winner = Imag32). | Parent plan + handoff + TODO show the verdict; `docs/upstream-contribution-status.md` carries the queued note. |

## Critical files

- New: `examples/65816/farcc_bench.c`, `dev/probe-cycles.lua`, `dev/measure-far-cc.sh`.
- Reuse: `examples/65816/farcc_imag32.c` (the `make_far_ptr`/`deref_far` leaves), `dev/_emu.sh`,
  `dev/measure-a16-threading.sh:33` (`text_bytes`), `dev/measure-zp-pressure.sh` (table model).
- D: `vendor/.../MOS/MOSSubtarget.h` (`farPtrCC()` default), then `dev/regen-patch-0004.sh`.
- Docs: the parent plan, the variant-d sub-plan, `docs/agent-handoff.md`, `TODO.md`,
  `docs/upstream-contribution-status.md`.

## Verification

The project **differential** throughout: host == default == variant on MAME + bsnes-jg, `-verify-machineinstrs`
clean. M cells are correctness-gated (`0xF3`) before their timing counts. D's headline test is the **no-flag**
far-ptr round-trip (the capability that errored before now works), plus corpus 7/7 and every far ROM `0xF3`.

## Out of scope / non-goals

- **Not** building variant (d) hardware-`,S` (recorded-and-dropped; see the sub-plan).
- **Not** splitting the winner out of `0004` into `0001` (blocked by the shared `AnyRegBank`/a16 line; a
  future cleanup, not required to ship).
- **Not** posting upstream (the evidence paragraph is prepared; posting is user-triggered).
- **Not** absolute cycle counts (MAME exposes only emulated time here) — the measurement is a differential
  time proxy, which is all the go/no-go needs.
