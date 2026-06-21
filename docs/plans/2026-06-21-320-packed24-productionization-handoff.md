# Handoff — packed-24 (addrspace 3): realistic-use validation + access-cost cleanup

> ## ✅ Task A DONE + static-init reloc FIXED (2026-06-22)
>
> **Task A (measure the win) — done.** `dev/run.sh measure-packed24`: packed-24 wins **≈N bytes at every
> table size, break-even N≥1** — in an *indexed table walk* the access code is equal (far loads only 3 of its
> 4 entry bytes; the ×3-vs-×4 stride is a constant), so the feared "×3-index + byte-2-long" cost does **not**
> apply to indexed table access. The −25% storage win is real and realizable.
>
> **But Task A surfaced a blocker — now FIXED.** The realistic shape (a *statically-initialized* table of
> packed far pointers) did **not link**: each 3-byte entry emitted a single `R_MOS_ADDR8` (no 3-byte data
> fixup exists; `getDataKindForSize(3)` is unreachable → degrades to `FK_Data_1`). Increment B had only
> covered the *runtime* store/load path. Fixed via a generic `AsmPrinter::emitNonStandardSizedConstant` hook
> + a MOS override that emits the `ADDR24 SEGMENT_LO/HI/BANK` triple for an `AS_FarPacked` constant — landed
> in the updated **`0006`**. Verified: `dev/run.sh packed24_table` links + `0xA5` on MAME **and** bsnes-jg
> (each static entry's bank byte survives); corpus 7/7; fuzz 0-mismatch; round-trip-clean. Full record:
> [2026-06-22-320-packed24-static-init-reloc-fix.md](2026-06-22-320-packed24-static-init-reloc-fix.md).
>
> **Still open:** **Task B** (byte-2 absolute-long cost) — but the measurement shows it only affects *direct
> single-slot* access, not indexed tables, so its value is now marginal. **Task C** (ergonomic spelling) and
> **zero-bank (AS4)** remain as separate threads. The original handoff (below) is preserved.

**For:** a fresh agent. **Status when written (2026-06-21):** packed-24 **Increment A (the 3-byte type)
and Increment B (store/load/deref codegen) are DONE + verified + landed** on `main` as
[`patches/llvm-mos/0006-320-packed24.patch`](../../patches/llvm-mos/0006-320-packed24.patch) (commit
`ebfc95e`). The feature works and is differential-clean on both emulators. What it has **not** had is a
*realistic-context* measurement (lesson #2/#3) — the −25% storage win was measured on a synthetic table,
and the access path has a known, confirmed inefficiency that eats into the win. This handoff is the
resume prompt for closing that loop.

Read first: the auto-loaded [`CLAUDE.md`](../../CLAUDE.md) + [`agent-handoff.md`](../agent-handoff.md)
(build/test mechanics, the worktree table), and the **source of truth:**
[`2026-06-21-320-five-address-space-model.md`](2026-06-21-320-five-address-space-model.md) §**Build
packed-24 → Increment B** (the full record of what was built + how) and the prior
[Increment-B handoff](2026-06-21-320-packed24-incrementB-handoff.md) (the implementation notes).

---

## 0. Setup — reuse the existing worktree (it is RETAINED, not torn down)

The compiler-changing worktree **`wt/320-packed24-incB`** at
`/home/will/SRC/llvm-mos-65816-packed24-incB` is still live (own `vendor/` + warm `build/`, post-F2 +
all of `0001`–`0006` applied; user policy keeps worktrees until upstream merge). **Work there**, not on
`main`'s hot tree. Sanity-check the toolchain is current before starting:
```
cd /home/will/SRC/llvm-mos-65816-packed24-incB
build/llvm-mos-install/bin/mos-clang --target=mos -mcpu=mosw65816 -Xclang -target-feature -Xclang +mos-a16 \
  -Os -std=c23 -mllvm -verify-machineinstrs -c examples/65816/packed24/incB_use.c -o /dev/null && echo OK
dev/run.sh packed24   # the e2e differential — expect corpus_result == 0xF3 (MAME) + xcheck (bsnes-jg)
```
If `vendor/` was disturbed by another agent, rebuild from the patch stack
(`git -C vendor/llvm-mos checkout -- . && git -C vendor/llvm-mos clean -fdq`, then apply
`patches/llvm-mos/*.patch` in order, then `dev/run.sh toolchain`).

---

## 1. The work — two concrete tasks, in priority order

### Task A — measure the win in REALISTIC 16-bit-ambient context (the load-bearing one)

The whole justification for packed-24 is "saves 1 byte/pointer on *tables of far pointers stored in
memory*." We have a synthetic number (16-entry table: **64 B → 48 B, −25%** storage) but NOT a
whole-program, realistic-access measurement. Per governing lessons #2 (a native op isn't automatically
smaller — measure operand residency + schedule) and #3 (only *genuine* gains; a synthetic win that
evaporates in context is a no-go):

1. Build a realistic banked-asset / jump-table shape — e.g. an array of far pointers to functions or
   data in bank `$01`, **walked at runtime** in a 16-bit-ambient loop (not a leaf), both `AS_Far`
   (4-byte) and `AS_FarPacked` (3-byte). Put it in `examples/65816/packed24/` as a measurement fixture.
2. Measure **net** bytes with `llvm-objdump --section-headers` / `llvm-size`: storage saved on the table
   **minus** the extra access code (the ×3 index math + the byte-2 long-access cost, Task B) summed over
   the call sites. Decide bytes first, cycles as tiebreaker (`docs/agent-handoff.md` methodology).
3. **Verdict, recorded honestly:** if the realized win is positive in realistic context → great, record
   the number and the break-even table size (how many entries before the table savings beat the
   per-access overhead). If it's a wash/negative in realistic code → say so plainly (lesson #3); packed-24
   stays a correct, opt-in, differential-clean feature but its *use* is documented as "only worth it for
   large, rarely-walked tables." Either outcome is a success (it's measured, not assumed).

### Task B — fix the byte-2 absolute-long access cost

Confirmed inefficiency: a packed access stores/loads byte 0 and 1 via `abs` (`8e`/`8c`/`ae`/`ac`, 3-byte
`R_MOS_ADDR16`) but **byte 2 via absolute-LONG** (`8f`/`af`, 4-byte `R_MOS_ADDR24`):
```
6: 8e 00 00     stx  g          (abs)
9: 8c 00 00     sty  g+1        (abs)
c: 8f 00 00 00  sta  g+2        (ADDR24 / long)   <- 1 byte wasted; g is a NEAR global
```
Root cause to confirm: `legalizePackedPtrAccess` emits three plain 8-bit `G_LOAD`/`G_STORE` to
`(p0 base + const offset)`; bytes 0/1 select `abs` but the **A-register** byte-2 access selects
absolute-long. STX/STY have no long form (forced to abs), so only the A-path is affected — likely a
`selectAddressingMode` default for an A-register access to a near global, or an artifact of the
`G_PTR_ADD`+offset 2. Investigate (`-print-after=legalizer` then the selector), then make byte 2 select
`abs` (`8d`/`ad`) when the base pointer is near (AS0). **Gate conservatively** — a misclassification must
only ever miss the optimization, never emit a wrong-bank access. ~1 byte saved per packed access site;
small but it's exactly the kind of amplified-across-every-program win lesson #3 says to bank, and it
directly improves Task A's net number.

### Task C (stretch) — an ergonomic clang spelling

Users currently write `__attribute__((address_space(3)))`. A `__far_packed` macro/keyword or a
`<mos.h>` typedef (mirroring however `far`/`__far` is spelled for AS2) would make packed tables
writable without raw attributes. Only do this if AS2 already has such a spelling to mirror; otherwise
leave it (don't invent a one-off).

---

## 2. Verification gate (the bar — unchanged house rules)

- **Differential:** host == default == `+mos-a16`@MAME == `+mos-a16`@bsnes-jg; `-verify-machineinstrs`
  clean. `dev/run.sh packed24` stays green (and any new measurement fixture that *runs* must pass on
  both emulators).
- **Non-breaking:** `dev/run.sh corpus` 7/7; the far suite green; `dev/run.sh fuzz 50 1` 0-mismatch.
  Task B touches `selectAddressingMode`/the byte access — that path is shared, so **the fuzzer guarding
  the default build is the real gate**: prove default + non-AS3 codegen is byte-identical (gate any
  change on `AS_FarPacked` / the near-base condition).
- **Land** in `0006-320-packed24.patch` (regen `dev/regen-patch-0006.sh`, round-trip-verified). Stage
  only your files; never `vendor/`. Push discipline + commit footer per `CLAUDE.md`.

---

## 3. Other open threads (lower priority — not this batch unless asked)

- **zero-bank (AS4)** — the last of asiekierka's five spaces (a far-typed pointer the compiler knows is
  in bank `$00`, accessed via 16-bit `abs`). 0b census measured ~0 users (≈ a near pointer), so it's a
  likely **measured null** — but the five-space model isn't *complete* until it's measured and closed
  like frame-ABI. Recipe: five-space plan §Phase 2.
- **Upstream the #320 design note** (C1 single-datalayout finding + the retracted pow2 premise + the
  census + now the packed-24 *built* evidence). Posting is **user-triggered**; the artifact is
  [`docs/320-upstream-far-pointer-note.md`](../320-upstream-far-pointer-note.md), queued in
  [`upstream-contribution-status.md`](../upstream-contribution-status.md).
- **Environmental, not a defect:** `far_near_call` fails to *link* in the packed24 worktree because
  `__call_near_from_far` lives in the SNES *platform* library (`platforms/snes/call-near-from-far.s`),
  which the warm-copied SDK predates. A clean SDK/platform rebuild fixes it; it is unrelated to
  packed-24 and its compile is clean. (If you do a full-suite `dev/run.sh xcheck`, rebuild the platform
  first or expect that one link error.)

## 4. If Task A's verdict is "net-negative in realistic context"

That's a legitimate close, not a failure (lesson #3): packed-24 ships as a *correct, opt-in,
differential-clean* capability with a documented "use only when the table dwarfs the access sites"
caveat. Record the number + break-even in the plan and stop — do not chase micro-opts to force a win
that isn't there. The feature already pays for itself the moment a real large far-pointer table exists.
