# #320 packed-24 residuals — measure-and-close Task B + Task C

**Date:** 2026-06-22 · **Status:** CLOSED (no codegen — both residuals resolve without packed-24-specific
work) · **Parent:** [packed-24 productionization handoff](2026-06-21-320-packed24-productionization-handoff.md)
· **Related:** [static-init reloc fix](2026-06-22-320-packed24-static-init-reloc-fix.md) ·
[five-address-space model](2026-06-21-320-five-address-space-model.md) ·
[zero-bank measure-and-close](2026-06-22-320-zerobank-as4-measure-and-close.md) (the sibling pattern).

## Context

packed-24 (`addrspace 3`, `AS_FarPacked` — the 3-byte storage form of a far pointer) is **built, landed,
and differential-clean** on `main` as [`0006-320-packed24.patch`](../../patches/llvm-mos/0006-320-packed24.patch).
The productionization batch had three tasks. **Task A is done + verified:** the realistic-context
measurement (`dev/run.sh measure-packed24`) shows packed wins at every table size with break-even N≥1, and
the static-init relocation bug it surfaced (a packed static table didn't link) is FIXED + verified on MAME
+ bsnes-jg (`dev/run.sh packed24_table` → `0xA5`), landed in `0006`. This note disposes of the **last two
residuals** — both close on verified evidence, neither needs packed-24-specific code:

| Residual | Verdict |
|---|---|
| **B** — byte-2 absolute-long access cost | **CLOSED — already built as `0007`** (the cost is general, not packed-specific; `0007` *is* the realization of Task B). |
| **C** — `__far_packed` ergonomic spelling | **CLOSED — precondition unmet** (no AS2 spelling exists to mirror; building one alone is the forbidden one-off). |

With A done and B/C closed, the **packed-24 productionization thread is complete**.

## Task B → CLOSED: it is `0007`, the general near-abs bank-relaxation

The inefficiency is real but **not a packed-24 bug**. A packed access stores/loads its 3 bytes via plain
absolute stores; bytes 0,1 (`STX`/`STY`/`LDX`/`LDY`) have **no** absolute-long form so were already `abs`
(`8e/8c/ae/ac`), and **only byte 2** (the A-register byte) bloated to absolute-long (`8f/af`,
`R_MOS_ADDR24`) even though the slot is a *near* (bank-0) global. That A-register-to-near-global growth is
the **general** 65816 assembler behavior — `MOSAsmBackend::fixupNeedsRelaxationAdvanced` relaxes a near,
non-zero-page symbol all the way to long with no near-vs-far discrimination on the bank step — affecting
~284 sites in the `a16*.c` corpus alone, packed or not. It became safe to keep these `abs` (`8d/ad`) only
after the DBR=0 crt0 contract (`phk; plb`, 2026-06-18) — the same reason the `inc abs` RMW was rejected.

All three packed bytes route through the **shared** selector path — `legalizePackedPtrAccess` →
`tryAbsoluteAddressing` → `G_LOAD_ABS`/`G_STORE_ABS`
([`MOSLegalizerInfo.cpp:2298,2305,2359,2365`](../../vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp)) —
and the abs-vs-long decision lives in the **assembler** (`MOSAsmBackend.cpp`), not in the packed legalizer.
So the fix belongs there, once, for everyone — which is exactly what was built:

> **`0007` is the realization of Task B.** Its plan
> ([`wt/320-near-abs-bank-relax` · `2026-06-22-65816-near-abs-bank-relax.md`](2026-06-22-65816-near-abs-bank-relax.md))
> states: *"this is the realization of **Task B** … ('fix the byte-2 absolute-long access cost').
> Investigation showed the cost is **not** packed-24-specific — it is a general 65816 assembler issue — so
> it lands as its own stacked patch (`0007`), independent of the packed-24 patch (`0006`)."* (§Origin.)
> One hunk in `MOSAsmBackend.cpp`; near-global absolute accesses stay 16-bit (`8d/ad`) for **all** near
> pointers. §4: *"This near-abs fix additionally trims the direct packed-pointer access pattern … byte-2
> `8f/af` → `8d/ad`, −2 B."* It is **feature-complete + verified on the full `0001–0007` combined stack on
> both emulators** (§5: packed24 `0xF3`, packed24_table pass, MAME + bsnes-jg), and conservative (a
> misclassification can only miss the size win, never emit a wrong-bank access).

A packed-**local** byte-2 fix would be the wrong shape (governing lesson #2 — build the clean form, don't
ship a blanket/duplicate): it would duplicate the DBR-discrimination logic at the legalizer level, help
only packed (missing every other near-global A-register access), and risk the DBR≠0 miscompile `0007`
carefully gates. It is also marginal in reach — Task A proved the byte-2 cost touches only *direct
single-slot* access; the indexed table walks that justify packed-24 are equal-cost without it (and, with
`0007`, packed wins **more**: net **−21 B at N=16** vs −17 B before — `0007` §4).

**Action: none on the packed side.** Task B is delivered by `0007`. Loose end (separate thread, not this
note): `0007` is committed on `wt/320-near-abs-bank-relax` (`ff02726`) but not yet folded into `main`'s
patch stack (`main` carries `0001–0006`). When the combined stack lands, the packed byte-2 win is automatic.

## Task C → CLOSED: no AS2 spelling to mirror

The handoff's own rule: add a packed spelling *only if* AS2 already has one to mirror; otherwise leave it,
don't invent a one-off. **The precondition is unmet.** No ergonomic spelling exists for *any* MOS address
space — no `__far` keyword, no `__far_packed`/`__zp`/`__dp` macro, no `<mos.h>` SDK typedef, no MOS
address-space attribute in `clang/.../Attr.td` or `SemaMOS.*`. Every far / dp / packed user writes a
**per-file local `#define`**:

```
#define FAR    __attribute__((address_space(2)))   // examples/65816/far_*.c, packed24/*.c
#define PACKED __attribute__((address_space(3)))   // examples/65816/packed24/*.c
#define DP     __attribute__((address_space(1)))   // examples/65816/far-value-evidence/*.c
```

There is nothing to mirror, so shipping `__far_packed` alone is precisely the forbidden one-off.

**Revival condition (if ever wanted):** a *shared* `<mos.h>` / `<mos/addressing.h>` SDK header defining
`MOS_FAR` / `MOS_DP` / `MOS_PACKED` (and a future `MOS_ZEROBANK`) **together** — a foundational SDK
decision orthogonal to packed-24, arguably an upstream `llvm-mos-sdk` concern. Not opened here.

## Net effect — packed-24 productionization thread complete

Task A done + verified; Task B is `0007`; Task C closed-as-unmet. No packed-24-specific work remains. The
five-address-space model was already formally complete (AS0/1/2 ship, AS3 built with a measured win, AS4
measured-null). The old `wt/320-packed24-incB` worktree is already torn down (commit `f168003`, 12 G
reclaimed) — the handoff's "reuse the worktree" §0 is stale and superseded by this note.

## Verification — evidence integrity + non-regression (a measure-and-close, no new codegen)

This note edits only docs + `TODO.md`; it cannot perturb codegen (no `vendor/`/patch edits), so the bar is
*reproduce the evidence* and *confirm the existing gates are untouched*.

**1. Task C — only per-file local `#define`s exist; nothing to mirror.**
```
$ grep -rhniE '#define[[:space:]]+(FAR|PACKED|DP)[[:space:]]+__attribute__\(\(address_space' examples/ | sort -u
#define DP __attribute__((address_space(1)))
#define FAR __attribute__((address_space(2)))
#define PACKED __attribute__((address_space(3)))
$ grep -rliE '__far_packed|#[[:space:]]*define[[:space:]]+__far\b|<mos\.h>|<mos/' examples/ platforms/ vendor/llvm-mos/clang/lib/Headers/
(no output)
```
PASS — no shared spelling; Task C precondition unmet.

**2. Task B — `0007` owns the fix and covers packed byte-2; the 3 packed bytes share `tryAbsoluteAddressing`.**
```
$ grep -nE 'legalizePackedPtrAccess|tryAbsoluteAddressing|G_LOAD_ABS|G_STORE_ABS' \
    vendor/llvm-mos/llvm/lib/Target/MOS/MOSLegalizerInfo.cpp | head
2298:    if (tryAbsoluteAddressing(Helper, MRI, MI, true))
2305:    if (tryAbsoluteAddressing(Helper, MRI, MI, false))
2359:bool MOSLegalizerInfo::tryAbsoluteAddressing(...)
2365:  unsigned Opcode = isa<GLoad>(MI) ? MOS::G_LOAD_ABS : MOS::G_STORE_ABS;
```
PASS — abs-vs-long is an assembler decision, not packed-specific; `0007` plan §Origin/§4/§5 confirms it is
Task B's realization, covers packed byte-2 (`8f/af → 8d/ad`, −2 B), verified `0001–0007` on both emulators.

**3. Non-regression on the current (`0001–0006`) stack** — unchanged by construction; the standing gates
remain: `dev/run.sh packed24` (`0xF3`), `dev/run.sh packed24_table` (`0xA5` MAME + bsnes-jg),
`dev/run.sh corpus` 7/7, `dev/run.sh fuzz 50 1` 0-mismatch, `-verify-machineinstrs` clean.

**4. Backlog consistent** — `TODO.md` M2 five-space item shows B+C struck with their resolutions; the
productionization handoff carries a stale-banner pointing here; no orphaned "still open: B/C" text remains.

## Follow-up (separate threads — not this note)

- **Integrate `0007` onto `main`'s patch stack** (its own merge step). Once landed, optionally harden the
  `packed24_table` disasm gate to assert byte-2 is `8d/ad` (zero `8f/af` to a near global) as the durable
  regression guard for the Task-B-via-`0007` win.
- **Post the #320 upstream design note** — user-triggered (queued in
  [`upstream-contribution-status.md`](../upstream-contribution-status.md)).
