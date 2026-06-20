# #321 xy16: classify known-issue crashes under `+mos-xy16` too (symmetric XFAIL in `evaluate()`)

**Status:** IMPLEMENTED & VERIFIED (2026-06-21). One-spot Python harness change to `tools/a16_fuzz.py`
(tracked tool file, not `vendor/` — no `0002` patch regen).

## Context

The differential engine `tools/a16_fuzz.py` `evaluate()` runs a per-program MIR-verify
(`-verify-machineinstrs`) crash gate under **both** `+mos-a16` and `+mos-xy16` (xy16 implies a16), then
compiles + runs the ROMs. Its verify gate (step 1 of the 3 numbered steps) was **asymmetric**:

- The **`+mos-a16` leg** (`evaluate()`, the first verify) runs `classify_known()` on the verify log → a known,
  already-diagnosed defect returns **`XFAIL`** ("known issue [...]").
- The **`+mos-xy16` leg** did **not** call `classify_known()` — it unconditionally returned **`CRASH`** →
  `cmd_check` prints `RESULT: FAIL`.

So a program tripping the `+mos-xy16` verify with a *known* signature was mis-reported as a hard failure
instead of a tracked XFAIL. The two known-XFAIL repros **`examples/65816/a16regpress.c`**
(`regalloc-out-of-registers`) and **`examples/65816/a16scavnz.c`** (`scavenger-p-not-gpr`) fail MIR-verify
under both feature modes. Both are **deliberately-deferred deep defects** (the RA single-accumulator residency
problem and the pristine-upstream register-scavenger N/Z-liveness bug — see the investigations); the codegen
fix is out of scope here. Outcome wanted: the engine reports these as **XFAIL** under `+mos-xy16` exactly as it
already does under `+mos-a16`, while a genuinely *new* xy16 crash still hard-FAILs.

Refs: `docs/investigations/65816-a16-regalloc-pressure-failure.md`,
`docs/investigations/65816-a16-scavenger-nz-liveness.md`. Known-issue registry: `KNOWN_ISSUES` consumed by
`classify_known()`.

## The fix — one spot, mirror the a16 leg

In `evaluate()` (`tools/a16_fuzz.py`), the `+mos-xy16` verify leg now classifies known issues before declaring
a crash, symmetric with the a16 leg:

```python
        ok_xy, vlog_xy = verify_machineinstrs(src, WORK / "chk_xy.vo", flags=XY16, cflags=cflags)
        if not ok_xy:
            # Symmetric with the +mos-a16 leg above: a known, already-diagnosed defect
            # (regalloc-out-of-registers, scavenger-p-not-gpr, …) fires under +mos-xy16 too —
            # xy16 IMPLIES a16 — so classify it XFAIL, not a spurious hard CRASH. An unmatched
            # xy16 crash still hard-FAILs (e.g. a genuine X-lattice regression) …
            kid = classify_known(vlog_xy)
            if kid:
                return "XFAIL", "known issue [%s]" % kid, None
            on_triage("verify-machineinstrs / compiler crash (+mos-xy16)", {"verify": vlog_xy})
            return "CRASH", "verify-machineinstrs (+mos-xy16) failed", None
```

The step-2 compile path already runs `classify_known(str(e))` on `CompileError`/timeout for all three builds,
and the a16 verify leg already classifies. This closes the single remaining gap.

### Measurement finding (the short-circuit nuance)

The a16 verify leg early-returns `XFAIL` **before** the xy16 leg runs. Measurement (step 2 below) shows **both
repros crash the a16 verify**, so via the standard `check` path they **already** XFAIL at the a16 leg — the
xy16-leg gap is **latent** for them. The fix is therefore latent-gap closure: it changes the outcome only for a
program that *passes* a16 verify but *fails* xy16 verify with a known signature, or for any harness/sweep that
reaches the xy16 leg directly (e.g. verifying each feature independently). Step 3 proves the leg now classifies
by exercising it directly.

## Verification (executed 2026-06-21 — raw output + PASS/FAIL under each step)

### Step 1 — Host MIR-verify: which leg trips + the signature

```
=== a16regpress +mos-a16 ===
error: <unknown>:0:0: ran out of registers during register allocation in function 'main'  (exit 1)
=== a16regpress +mos-xy16 ===
error: <unknown>:0:0: ran out of registers during register allocation in function 'main'  (exit 1)
=== a16scavnz +mos-a16 ===
*** Bad machine code: Illegal physical register for instruction ***  $p is not a GPR register.  (exit 1)
=== a16scavnz +mos-xy16 ===
*** Bad machine code: Illegal physical register for instruction ***  $p is not a GPR register.  (exit 1)
```

Both fail under **both** modes with signatures matched by `KNOWN_ISSUES` (`regalloc-out-of-registers` /
`scavenger-p-not-gpr`). No predicate broadening needed. **PASS.**

### Step 2 — End-to-end `check` is XFAIL, not FAIL

```
RESULT: PASS (known issue) — a16regpress: known issue [regalloc-out-of-registers]
RESULT: PASS (known issue) — a16scavnz: known issue [scavenger-p-not-gpr]
```

(Identical pre- and post-edit: both XFAIL at the a16 leg, confirming the short-circuit nuance above.) **PASS.**

### Step 3 — Direct unit exercise proves the xy16 leg now classifies

```
a16regpress  xy16 verify ok=False -> classify_known='regalloc-out-of-registers'  => leg returns XFAIL
a16scavnz    xy16 verify ok=False -> classify_known='scavenger-p-not-gpr'        => leg returns XFAIL
```

With the old code these returned `CRASH`; with the fix the xy16 leg returns `XFAIL (known issue [...])`. **PASS.**

### Step 4 — No suite regression (the change is confined to the failing-xy16-verify branch)

```
# dev/run.sh xy16ops
RESULT: PASS — G_LOAD_ABS_IDX16+LDXImag16+LDAbsXIdx16 B2 path under +mos-xy16; corpus_result==0x2A42; both emulators agree

# dev/run.sh corpus-a16
  arith    PASS   control  PASS   arrays  PASS   structs PASS   funcs PASS
  globals  XFAIL  known issue [regalloc-out-of-registers]
==> corpus-a16: 5/6 passed, 1 xfail
```

`xy16ops` (a program that *passes* the xy16 verify) is unaffected; `corpus-a16` is unchanged (5/6 PASS,
`globals` still XFAIL — no PASS→FAIL flip). The `git diff` confirms the edit is entirely inside the
`if not ok_xy:` branch, so no passing/cleanly-failing program can change behavior. **PASS.**

## Risks & trade-offs

- **By-signature masking (accepted, symmetric with today).** A *new* xy16 crash sharing a known signature
  would XFAIL — the same trade-off the a16 leg already makes; `KNOWN_ISSUES` comments mandate removing each
  entry when fixed so the signature hard-FAILs again.
- **Out of scope:** the underlying RA-pressure / register-scavenger codegen bugs — no narrow low-risk fork-side
  fix (deferred Phase-3 / upstream). This change only fixes *reporting*; the deferral + `KNOWN_ISSUES` guards
  stand.
- **Optional follow-up (not implemented):** the a16-leg early-return means a known-a16 program never has its
  xy16 leg verified, so a *new* xy16-only crash on such a program is currently hidden. Closing that means
  running both legs and XFAILing only when no leg shows an *unmatched* crash — more complex; record as a
  follow-up, not part of this change.

## Critical files

- `tools/a16_fuzz.py` — `evaluate()` xy16 verify leg (the edit); `classify_known()`; `KNOWN_ISSUES`;
  `cmd_check`.
- `examples/65816/a16regpress.c`, `examples/65816/a16scavnz.c` — the two repros (verification inputs).
- `docs/investigations/65816-a16-regalloc-pressure-failure.md`,
  `docs/investigations/65816-a16-scavenger-nz-liveness.md` — why the underlying fix is deferred.
