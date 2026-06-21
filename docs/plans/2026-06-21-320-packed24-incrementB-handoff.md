# Handoff — build packed-24 (addrspace 3) Increment B, once the F2 far-value work is on `main`

**For:** a fresh agent. **Status when written (2026-06-21):** packed-24 Increment A (the 3-byte *type*)
is built + verified + recorded; Increment B (codegen to *use* packed pointers) is **deferred until the
F2 far-pointer-value work lands on `main`** (the in-flight "Build Reference R + extract (a)-delta →
new-0001 → land" sequence). This is the resume prompt for after that lands.

Read first: the auto-loaded [`CLAUDE.md`](../../CLAUDE.md) + [`agent-handoff.md`](../agent-handoff.md)
(build/test mechanics), and **the source of truth for this task:**
[`2026-06-21-320-five-address-space-model.md`](2026-06-21-320-five-address-space-model.md) — read its
**§0a** (representability + the `MVT::i24` analysis), **§Re-evaluation**, and **§Build packed-24**
(Increment A recipe + the precise Increment-B blocker). This handoff is the orientation; that plan is the detail.

---

## 0. Precondition gate — DO NOT start until F2 is actually on `main`

packed-24 is the 3-byte storage form of a far-pointer **value**, so it must build on F2's now-storable
far value (which makes `getPointerWidthV(AS2)==32` / `PF`-as-value / the `s32↔bytes` merge machinery).
Building before that = rebase + conflict (both touch `getPointerWidthV`, the datalayout, and the far
legalizer rules).

**Verify F2 landed (one command):** rebuild `main`'s toolchain if needed, then
```
dev/measure-far-ptr-value-state.sh
```
If the **`store/load/array/struct far ptr`** rows are **OK under `+mos-a16`** (they FAIL on pre-F2 `main`),
F2 is in — proceed. If they still fail, **STOP — F2 isn't landed; do not start.** Also confirm
`grep -n 'case 2' vendor/llvm-mos/clang/lib/Basic/Targets/MOS.cpp` shows `return 32` (F2's sizeof fix).

---

## 1. What packed-24 is, and what's already done

- **Goal:** `AS_FarPacked` (addrspace 3) — a **3-byte** far pointer for *storing tables of far pointers*
  (banked-asset / jump tables). Opt-in; saves 1 byte/pointer (25%) of storage vs the 4-byte `AS_Far`.
  Measured tradeoff: 3-byte array elements index by **×3** (vs `asl;asl` ×4) — opt-in, so it never
  regresses non-users. No real far-pointer-table code exists yet, so this is a **speculative opt the
  user explicitly directed** — don't re-litigate whether to build it, but keep the gate honest.
- **No `MVT::i24`.** `i24` is not an MVT (only `i1/i2/i4/i8/i16/i32/…`), so a 24-bit *register class*
  is impossible. packed-24 is **memory-only**: 3-byte storage that converts to/from the 32-bit `p2`
  (`Imag32`) — the 24-bit value is never held in a register as 24-bit. (Proof it's representable:
  `_BitInt(24)` already compiles; §0a.)
- **Increment A (the 3-byte TYPE) — DONE + verified.** Apply
  [`spikes/2026-06-21-320-packed24-incrementA.patch`](spikes/2026-06-21-320-packed24-incrementA.patch):
  `AS_FarPacked=3` in the `MOS::AddressSpace` enum + datalayout `p3:24:8` (×2: `MOSTargetMachine.cpp`
  and clang `MOS.cpp`) + clang `getPointerWidthV` `case 3: return 24`. **⚠ rebase note:** that patch is
  against *pre-F2* `c798c31`; its `getPointerWidthV` and datalayout hunks **overlap F2's edits** — apply
  manually: add `case 3: return 24` *alongside* F2's `case 2: return 32`, and add `-p3:24:8` to the
  datalayout F2 ships. Verified by `examples/65816/packed24/incA_sizeof.c` + `incA_storage.c`
  (`sizeof(packed*)==3`, `table[16]==48 B`; corpus 7/7 — AS3 is inert unless code creates one).

## 2. Increment B — the work: codegen to store/load/deref a packed far pointer

The blocker (empirically diagnosed): clang emits `addrspacecast p2↔p3` + `load/store p3`; `PFP` isn't in
the far legalizer rules, and the conversion routes through **`s24`** (24-bit), which the backend doesn't
legalize (only `s8/s16/s32`), and the 3-byte granularity breaks the 2-source merge selector. Pieces:

1. **Wire `PFP = LLT::pointer(3, 24)` into the rules** (mirror `PF`): `G_INTTOPTR {PFP,S24}`,
   `G_PTRTOINT {S24,PFP}`, `G_ADDRSPACE_CAST` cartesian `+PFP`, `G_LOAD/G_STORE` value-type set `+PFP`.
2. **`addrspacecast p2↔p3`** (`legalizeAddrSpaceCast` already does `ptrtoint→trunc/zext→inttoptr`):
   p2→p3 = truncate 32→24 (drop the pad byte); p3→p2 = zero-extend 24→32 (pad=0). Just needs the `s24`
   conversions below to legalize.
3. **The 24-bit boundary — pick the cleanest of these (evaluate, don't assume):**
   - **(a) `s24` as a narrowed width:** teach `G_TRUNC`/`G_ZEXT`/`G_LOAD`/`G_STORE` to narrow `s24` to
     3× `s8`, and add a custom `3×s8↔s24` merge/unmerge **mirroring F2's `legalizeMergeS32FromBytes` /
     `legalizeUnmergeS32ToBytes`** (the 2-source `selectMergeValues` can't do 3 sources — F2 already
     solved the 4-byte analogue; copy that pattern at 3 bytes).
   - **(b) fuse at the memory boundary:** custom-legalize so a `p3` value never stands alone — a `p3`
     load becomes `load 3 bytes + merge-with-zero → p2`, a `p3` store becomes `p2 → low 3 bytes`. The
     value is always `p2`/`Imag32`; `s24`/`p3` exist only transiently at the access. Likely the *truest*
     memory-only form and may be less invasive than a full `s24` width — **try this first.**
   Reuse F2's machinery wherever possible — packed-24 is the 24-bit mirror of what F2 built at 32-bit.
4. **Deref through a packed pointer** (`*pp`): cast `p3→p2`, then the existing far deref (`lda [dp]`).

Files (grep for anchors — line numbers drift): `MOSLegalizerInfo.cpp` (`PF`/`legalizeAddrSpaceCast`/
the `S32↔bytes` merge helpers F2 added), `MOSInstructionSelector.cpp`, `MOSInstrPseudos.td`. Each
toolchain rebuild is ~minutes (warm ccache) — background it, don't block (`docs/agent-handoff.md`).

## 3. Verification gate (the bar)

- **Differential** (`docs/agent-handoff.md` "correctness gate"): host == default == `+mos-a16`@MAME ==
  `+mos-a16`@bsnes-jg, `-verify-machineinstrs` clean. packed-24 is `HasW65816`-gated; **the fuzzer guards
  the DEFAULT build** — your changes must not alter non-AS3 codegen (gate on `AS_FarPacked`).
- **Promote the fixtures:** `examples/65816/packed24/incB_use.c` is the e2e shape (store→load→deref a
  packed far pointer). Make it a real `dev/run.sh packed24` micro-test (store a far ptr into a packed
  slot/table in bank `$01`, read it back, deref, assert a sentinel on **both** emulators) + wire into
  `dev/xcheck.sh`. `incA_sizeof.c`/`incA_storage.c` stay as compile gates.
- **Non-breaking:** `dev/run.sh corpus` 7/7; the far suite green; `dev/run.sh fuzz` 0-mismatch.
- **Measure the win for real:** with packed-24 working, compile a 16-entry far-pointer table both
  `AS_Far` (4-byte) and `AS_FarPacked` (3-byte) and confirm the −16 B (−25%) storage delta + record the
  ×3-index cost. If the realized win is empty/negative in realistic context (lesson #2), say so and
  reconsider — don't ship a net-negative.

## 4. Setup + discipline

- **Compiler-changing worktree off *post-F2* `main`** — `docs/howto-feature-worktree.md` "Compiler-changing
  variant" (`cp -a` vendor + warm `build/`; ~12 GB — check `df -h` first, disk runs tight here). Register
  it in the `agent-handoff.md` worktree table while live.
- **Land in `0001`** (the far-addrspace patch) once it works — packed-24 is part of the #320 far story.
  Regen with `dev/regen-patch.sh`; sanity-check it didn't absorb foreign hunks (`grep -c` a `0002`/`0004`
  symbol). Stage only your files; never `vendor/`.
- **Teardown:** `dev/worktree-teardown.sh <slug>` (raw `git worktree remove` is hook-blocked). Keep the
  durable artifacts on `main` first.
- Commit-message footer + push discipline: per `CLAUDE.md`.

## 5. If it turns into a rabbit hole

Cap at ~3 attempts (`CLAUDE.md` debugging limit). If the `s24`/3-byte handling fights back, fall back to
approach 3(b) (fuse-at-boundary), and if that also stalls, **record the precise new blocker + verdict in
the plan and stop** — packed-24 is a speculative opt, not worth unbounded effort. The Increment A patch +
fixtures already make it cheaply revivable.
