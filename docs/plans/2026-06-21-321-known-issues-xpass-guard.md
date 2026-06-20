# #321: known-issues XPASS guard — surface "drop the entry" the moment a deferred bug is fixed

**Status:** IMPLEMENTED & VERIFIED (2026-06-21). Harness + CI change only (tracked tool/scripts, not
`vendor/`) — no `0002` patch regen.

## Context

The deferred `+mos-a16`/`+mos-xy16` defects are XFAIL'd via `KNOWN_ISSUES` in `tools/a16_fuzz.py`, each with a
deterministic repro and a comment: *"REMOVE this entry when fixed so the signature hard-FAILS again."* But
nothing **surfaces the trigger**: when an upstream/RA fix lands, the repro just silently starts *verifying
clean*, and the stale `KNOWN_ISSUES` entry lingers — ready to mask a future regression of the same signature.

This adds an **XPASS guard**: a check that asserts each known-issue repro **still crashes**
`-verify-machineinstrs` (under **both** `+mos-a16` and `+mos-xy16`) with its **expected signature**, and
**fails loudly** the instant one verifies clean — printing the exact follow-up: drop the `KNOWN_ISSUES` entry
and promote the repro to a positive differential gate.

## Design

- New data table `KNOWN_ISSUE_REPROS = [(repro_path, expected_kid), …]` in `tools/a16_fuzz.py`, maintained
  next to `KNOWN_ISSUES` (drop a `KNOWN_ISSUES` entry → drop its row here too). Seeded with:
  `examples/65816/a16regpress.c → regalloc-out-of-registers`, `examples/65816/a16scavnz.c → scavenger-p-not-gpr`.
  (The third defect `a16-zp-pressure-overflow` has no tracked repro — its `pr15296.c` is a gitignored
  c-torture file and a *link* error, not a verify crash — so it's out of this guard's scope.)
- New subcommand `tools/a16_fuzz.py known-issues` (`cmd_known_issues`): for each repro × {a16, xy16}, run
  `verify_machineinstrs` and require it to FAIL with `classify_known(log) == expected_kid`. Outcomes:
  - **still reproduces** (fail + expected kid) → ok.
  - **XPASS** (verifies clean) → the bug is FIXED → print the drop+promote action, exit 1.
  - **DRIFT** (fails but a *different*/no kid, or repro missing) → signature changed → exit 1.
  Pure host verify (`--target=mos`, no `--config`) — no SDK/emulator/secret needed.
- `dev/known-issues.sh` wrapper (toolchain-only; no `require_bios`/SDK) + `dev/run.sh known-issues` dispatch +
  usage line.
- **CI enforcement (the surfacing):** a `known-issues` step in `smoke.yml`'s `xcheck` job, right after the
  from-source toolchain build — unconditional (no secret), so any push/PR that includes the upstream fix turns
  CI red with the drop+promote instruction.

## Verification (executed 2026-06-21 — raw output + PASS/FAIL)

### Step 1 — Guard PASSES today (both repros still reproduce under both modes)

```
# dev/run.sh known-issues   (container path = CI's exact invocation)
  examples/65816/a16regpress.c   +mos-a16   xfail [regalloc-out-of-registers] (still reproduces)
  examples/65816/a16regpress.c   +mos-xy16  xfail [regalloc-out-of-registers] (still reproduces)
  examples/65816/a16scavnz.c     +mos-a16   xfail [scavenger-p-not-gpr] (still reproduces)
  examples/65816/a16scavnz.c     +mos-xy16  xfail [scavenger-p-not-gpr] (still reproduces)
RESULT: PASS — 4/4 known-issue legs still reproduce (XFAIL regression guard intact)   [exit 0]
```

**PASS** — guard green; the host subcommand (`python3 tools/a16_fuzz.py known-issues`) gives identical output.

### Step 2 — Simulated fix → guard FAILS loudly with the drop+promote action

Point the `regalloc-out-of-registers` row at a clean TU (`a16.c`, which verifies clean) to simulate the bug
being fixed:

```
  examples/65816/a16.c           +mos-a16   XPASS — verifies CLEAN (issue [regalloc-out-of-registers] no longer reproduces)
  examples/65816/a16.c           +mos-xy16  XPASS — verifies CLEAN (issue [regalloc-out-of-registers] no longer reproduces)
  examples/65816/a16scavnz.c     +mos-a16   xfail [scavenger-p-not-gpr] (still reproduces)
  examples/65816/a16scavnz.c     +mos-xy16  xfail [scavenger-p-not-gpr] (still reproduces)
XPASS: 2 known-issue repro/leg(s) NO LONGER REPRODUCE — the deferred bug looks FIXED:
ACTION: drop KNOWN_ISSUES['regalloc-out-of-registers'] (and its KNOWN_ISSUE_REPROS row) in tools/a16_fuzz.py,
        then promote the repro to a POSITIVE gate (host==default==+mos-a16==+mos-xy16).
RESULT: FAIL — known-issue guard tripped (see ACTION/DRIFT above)   [exit 1]
```

**PASS** — XPASS trips a hard failure with the exact follow-up action. (A `DRIFT` branch likewise fails when a
repro crashes with a *different*/no signature or goes missing.)

## Critical files

- `tools/a16_fuzz.py` — `KNOWN_ISSUE_REPROS`, `cmd_known_issues`, the `known-issues` subparser; reuses
  `verify_machineinstrs` + `classify_known` + `KNOWN_ISSUES`.
- `dev/known-issues.sh`, `dev/run.sh` (usage + dispatch), `.github/workflows/smoke.yml` (CI step).
- Predecessors: `docs/plans/2026-06-21-321-xy16-verify-leg-classify-known.md`,
  `docs/plans/2026-06-21-321-xy16-verify-both-legs-hardening.md`.
