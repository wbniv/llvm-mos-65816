# #321 xy16: both-legs verify hardening — a known `+mos-a16` issue must not mask a new `+mos-xy16` crash

**Status:** IMPLEMENTED & VERIFIED (2026-06-21) in `tools/a16_fuzz.py` `evaluate()`. Python harness change only
(tracked tool, not `vendor/`) — no `0002` patch regen.

## Context

The follow-up to [`2026-06-21-321-xy16-verify-leg-classify-known.md`](2026-06-21-321-xy16-verify-leg-classify-known.md)
(which made the `+mos-xy16` verify leg classify known issues, symmetric with the `+mos-a16` leg). That fix left
one residual: the `+mos-a16` leg **early-returns `XFAIL`** on a known issue *before* the `+mos-xy16` leg runs.
So a program that is a **known `+mos-a16` defect** never has its `+mos-xy16` leg verified — and a *genuinely
new* `+mos-xy16`-only crash on that program (e.g. an X-lattice regression) is **silently hidden** behind the
a16 XFAIL. The `+mos-xy16` leg exists precisely to catch X-lattice regressions; the short-circuit blunts it for
the exact population (16-bit-pressure programs) most likely to expose one.

The intended outcome: **a NEW (unclassified) crash on *either* leg always hard-FAILs**, even when the other leg
is a known XFAIL. A known issue only ever yields `XFAIL` when *neither* leg shows a new crash.

## Design — run both legs, prioritize a NEW crash over a known issue

Replace the early-return structure with: run the a16 leg; if it is a *new* crash, hard-fail immediately
(unchanged fast path — most failures are here, and xy16 can't change that verdict). Otherwise **always run the
xy16 leg too** (even when a16 is a known issue), and decide by this table:

| `+mos-a16` leg | `+mos-xy16` leg | result | rationale |
|---|---|---|---|
| NEW crash | (not run) | **CRASH (a16)** | a16 new crash is already a hard fail; fast-path early-out |
| known issue | NEW crash | **CRASH (xy16)** | ← **the masking case this hardening closes** |
| clean | NEW crash | **CRASH (xy16)** | unchanged |
| known issue | known issue | **XFAIL** | both deferred defects (the common a16regpress/a16scavnz/globals shape) |
| known issue | clean | **XFAIL** | a16 deferred defect; xy16 happens to verify |
| clean | known issue | **XFAIL** | xy16-only deferred defect |
| clean | clean | proceed to step 2 | happy path |

Priority rule: **a NEW crash on any leg outranks a known issue on the other.** Only when neither leg has a new
crash does a known issue (on either leg) produce `XFAIL`.

### The change (in `evaluate()`, the `if verify:` block)

```python
    # 1) crash detector: -verify-machineinstrs under +mos-a16 AND +mos-xy16 (xy16 implies a16).
    #    Run BOTH legs (unless a16 is itself a NEW crash) so a known a16 issue can never MASK a
    #    genuinely-new xy16-only crash. Priority: a NEW (unclassified) crash on EITHER leg hard-FAILs;
    #    only if neither leg has a new crash does a known issue on either leg yield XFAIL.
    if verify:
        ok_a, vlog_a = verify_machineinstrs(src, WORK / "chk.vo", flags=A16, cflags=cflags)
        kid_a = None if ok_a else classify_known(vlog_a)
        if not ok_a and not kid_a:
            # New, unclassified +mos-a16 crash — hard fail now; the xy16 leg can't change this.
            on_triage("verify-machineinstrs / compiler crash (+mos-a16)", {"verify": vlog_a})
            return "CRASH", "verify-machineinstrs (+mos-a16) failed", None
        # Always verify under +mos-xy16 too — EVEN when the a16 leg is a known issue — so a NEW
        # xy16-only crash on a known-a16 program is never hidden by the a16 XFAIL (the hardening).
        ok_xy, vlog_xy = verify_machineinstrs(src, WORK / "chk_xy.vo", flags=XY16, cflags=cflags)
        kid_xy = None if ok_xy else classify_known(vlog_xy)
        if not ok_xy and not kid_xy:
            # New, unclassified +mos-xy16 crash (e.g. an X-lattice regression) — hard fail even if
            # the a16 leg was a known XFAIL. This is the masking case the hardening closes.
            on_triage("verify-machineinstrs / compiler crash (+mos-xy16)", {"verify": vlog_xy})
            return "CRASH", "verify-machineinstrs (+mos-xy16) failed", None
        # No NEW crash on either leg. If either leg hit a known, already-diagnosed defect → XFAIL.
        kid = kid_a or kid_xy
        if kid:
            return "XFAIL", "known issue [%s]" % kid, None
```

(`kid_a or kid_xy` reports the a16 kid when set, else the xy16 kid; in practice both legs of a pressure defect
produce the same kid — measured for a16regpress/a16scavnz. The `XFAIL` message keeps the `known issue [...]`
shape that `dev/corpus-a16.sh` greps for.)

## Cost & safety

- **Perf:** adds *one* extra `+mos-xy16` verify compile only for programs whose a16 leg is a **known issue**
  (previously short-circuited). That is a tiny minority — the 8 scavenger fuzz seeds (of 500), `globals` in the
  corpus, and the two repros. Clean-a16 programs already ran the xy16 leg; new-a16-crash programs still
  early-out. Negligible.
- **No false regressions:** every *current* known-issue case classifies on **both** legs (a16regpress/a16scavnz
  measured identical kid on both; `globals`, the 8 scavenger seeds → same), so none flips XFAIL→CRASH. The only
  behavior change is the intended one: a known-a16 program that *also* newly crashes under xy16 now CRASHes.
- Confined to the `if verify:` block; the Csmith `verify=False` path and steps 2–3 are untouched.

## Verification (executed 2026-06-21 — raw output + PASS/FAIL under each step)

### Step 1 — Decision-table unit test (mock `verify_machineinstrs`) — the faithful, deterministic proof

```
  a16=new     xy16=clean   -> CRASH verify-machineinstrs (+mos-a16) failed        [PASS]
  a16=knownA  xy16=new     -> CRASH verify-machineinstrs (+mos-xy16) failed       [PASS]   <- masking closed
  a16=knownA  xy16=knownX  -> XFAIL known issue [regalloc-out-of-registers]       [PASS]
  a16=knownA  xy16=clean   -> XFAIL known issue [regalloc-out-of-registers]       [PASS]
  a16=clean   xy16=new     -> CRASH verify-machineinstrs (+mos-xy16) failed       [PASS]
  a16=clean   xy16=knownX  -> XFAIL known issue [scavenger-p-not-gpr]             [PASS]
  a16=clean   xy16=clean   -> proceeds to step 2 (compile)                        [PASS]
DECISION TABLE: ALL PASS
```

The critical row **a16=known + xy16=new-crash → `CRASH`** confirms a known a16 issue no longer masks a new
xy16-only crash. (All failing/known rows return at step 1; the both-clean row proceeds to step 2 — detected by
mocking `compile_rom` to raise a sentinel.) **PASS.**

### Step 2 — No real known-issue flips

```
RESULT: PASS (known issue) — a16regpress: known issue [regalloc-out-of-registers]
RESULT: PASS (known issue) — a16scavnz: known issue [scavenger-p-not-gpr]
```

Both repros still XFAIL (each now runs both legs; both classify). **PASS.**

### Step 3 — Corpus unchanged (`globals` now exercises both legs)

```
  arith PASS   control PASS   arrays PASS   structs PASS   funcs PASS
  globals  XFAIL  known issue [regalloc-out-of-registers]
==> corpus-a16: 5/6 passed, 1 xfail
```

No row flipped — `globals` runs both legs (a16 + xy16 both regalloc-out-of-registers) → still XFAIL. **PASS.**

### Step 4 — Scavenger family stays XFAIL (builtin generator)

```
# dev/run.sh fuzz --gen builtin 1 306
  [xfail] seed   306  known issue [scavenger-p-not-gpr]
==> fuzz: 0/1 PASS, 1 known-issue (xfail)  (0 mismatch, 0 new-crash, 0 error)
```

Seed 306 (the `a16scavnz.c` source seed) now runs both legs; both classify `scavenger-p-not-gpr` → XFAIL, not
CRASH. **PASS.**

## Risks & trade-offs

- **By-signature classification (unchanged).** A new crash sharing a known signature still XFAILs on its own
  leg — the existing trade-off; `KNOWN_ISSUES` comments already require removing each entry when fixed.
- **Reporting on double-known with differing kids (rare).** If the two legs ever produce *different* known
  kids, the message reports the a16 one; the distinction is cosmetic (both are tracked XFAILs).

## Critical files

- `tools/a16_fuzz.py` — `evaluate()` `if verify:` block (the edit); `classify_known()`; `KNOWN_ISSUES`.
- Predecessor plan: `docs/plans/2026-06-21-321-xy16-verify-leg-classify-known.md`.
