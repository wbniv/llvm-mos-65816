# #321 — `corpus-a16`: run the SNES regression corpus under `+mos-a16` (close the coverage gap)

**Date:** 2026-06-19 · **Status:** **DONE / VERIFIED 2026-06-19 — `dev/corpus-a16.sh` landed; 5 PASS +
`globals` XFAIL, exit 0 (see §Verification).** Additive: no `vendor/`, no `0002`, no toolchain rebuild.
**Issue:** #321, ROADMAP M2 (Test Bench / CI).
**Required reading:** [ZP-pressure measurement (surfaced the gap)](2026-06-18-321-zp-pressure-measurement.md) ·
[globals.c RA-failure investigation](../investigations/65816-a16-regalloc-pressure-failure.md) ·
[Tier-1 corpus plan](2026-06-15-321-tier1-broaden-corpus.md).

## Context

The M0/M1 SNES regression corpus (`examples/snes/corpus/` — `arith, control, arrays, structs, funcs,
globals`) is built **DEFAULT 8-bit only** (`dev/run.sh corpus` → 7/7); it is **never exercised under
`+mos-a16`**. That gap hid the `globals.c` `+mos-a16 -Os` register-allocation crash until the ZP-pressure
scan happened to compile the corpus `+mos-a16`. The `a16*`/`k_*` micro-tests cover features in isolation, but
*realistic small programs* under `+mos-a16` had no gate. This wires a **`corpus-a16` differential mode**:
build the corpus programs under `+mos-a16` and assert **host == default == `+mos-a16`** on MAME + bsnes-jg,
with the known `globals.c` crash XFAIL'd. It would have caught `globals.c`, and guards against future such
bugs on realistic code.

## Approach

**New standalone `dev/corpus-a16.sh`**, auto-dispatched as `dev/run.sh corpus-a16` (the dispatcher `exec`s
`/work/dev/<target>.sh`, so **no `dev/run.sh` code change needed**). A hybrid of the two existing harnesses:

- **Iterate the manifest** like `dev/corpus.sh:29–48` (`examples/snes/corpus/expected.tsv`:
  `cfile  symbol  expected  desc`).
- **Per program, call the existing differential engine** like `dev/_check.sh::diff_check`, but pointed at
  the corpus source. `diff_check` can't be reused directly — it hardcodes `examples/65816/$name.c` and
  `exec`s — so `corpus-a16.sh` does the prereq guards once, then calls the engine per program.

**Reused, unchanged:**
- `tools/a16_fuzz.py check --src <c> --name <n> --expected <hex> [--no-bsnes]` → `evaluate()`
  (`tools/a16_fuzz.py:863`): verify-machineinstrs under `+mos-a16` **and** `+mos-xy16`; compile
  `default`/`a16`/`xy16`; run all three on MAME + `a16` on bsnes-jg; assert `host == default == a16 == xy16`
  via the **`corpus_result`** symbol (`map_lookup`, `:904`). **Exit 0 = PASS or XFAIL; exit 1 = FAIL**; prints
  `[STATUS] name …` + `RESULT: …`.
- `KNOWN_ISSUES` (`tools/a16_fuzz.py:800`): `globals.c` fails verify under `+mos-a16` → matches
  `regalloc-out-of-registers` → engine returns **XFAIL**. **No special-casing of `globals.c` needed** — the
  script tallies XFAIL (output contains `known issue`) separately. (If `globals.c` ever starts compiling —
  the upstream bug fixed — it flips to PASS/FAIL, auto-prompting attention.)
- Prereq guards + `--no-bsnes` detection — mirror `dev/_check.sh:15–22`.

**Bonus coverage:** the engine *always* also builds/runs `+mos-xy16`, so `corpus-a16` gates
`default == a16 == xy16` — strictly more than the requested `+mos-a16` (consistent with how `k_*`/`a16*`
already work). A corpus program hitting a *known* crash (`globals` → regalloc; a `$p`-spill →
`scavenger-p-not-gpr`) XFAILs; any **new** crash/mismatch is a real FAIL — the gate doing its job.

**Skip `hello.c`** (its `symbol` is `sentinel`, not `corpus_result` — it's the liveness smoke, not a corpus
computation; the engine assumes `corpus_result`). Filter: process only rows where `symbol == corpus_result`.

## Hand-off instructions (executable steps)

**1. Create `dev/corpus-a16.sh`** (≈45 lines). Skeleton — adjust to match house style in `dev/corpus.sh` /
`dev/_check.sh`:

```bash
#!/usr/bin/env bash
# dev/corpus-a16.sh — M0/M1 SNES corpus under +mos-a16 (differential). For each
# examples/snes/corpus/*.c with result symbol corpus_result, assert
#   host(expected) == default@MAME == +mos-a16@MAME == +mos-xy16@MAME == +mos-a16@bsnes-jg
# via the shared engine (tools/a16_fuzz.py check). globals.c -> auto-XFAIL
# (regalloc-out-of-registers). Closes the "corpus only ever built default 8-bit" gap
# (which hid the globals.c crash). Runs INSIDE the dev container; drive: dev/run.sh corpus-a16.
set -euo pipefail
usage() { echo "Usage: dev/run.sh corpus-a16   # examples/snes/corpus/*.c under +mos-a16 (differential, vs expected.tsv)"; exit 0; }
[ "${1-}" = "-h" ] || [ "${1-}" = "--help" ] && usage

ROOT=/work
MANIFEST="$ROOT/examples/snes/corpus/expected.tsv"
TOOL="${MOS_TOOLCHAIN:-$ROOT/build/llvm-mos-install}/bin"
[ -f "$MANIFEST" ] || { echo "no manifest: $MANIFEST"; exit 1; }
[ -x "$TOOL/mos-clang" ] || { echo "FATAL: no from-source toolchain at $TOOL (run: dev/run.sh toolchain)"; exit 1; }
[ -f "$ROOT/build/install/bin/mos-snes.cfg" ] || { echo "FATAL: SDK not built (run: MOS_TOOLCHAIN=$ROOT/build/llvm-mos-install dev/run.sh build)"; exit 1; }
source "$ROOT/dev/_emu.sh"
require_bios || exit $?
NOBSNES=(); { [ -x "$ROOT/build/jgxcheck" ] && [ -d "$ROOT/vendor/bsnes-jg/Database" ]; } || NOBSNES=(--no-bsnes)

echo "==> corpus-a16: $(basename "$MANIFEST")  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg)"
pass=0; fail=0; xfail=0; total=0
while read -r cfile symbol expected desc || [ -n "${cfile:-}" ]; do
  case "${cfile:-}" in ''|\#*) continue ;; esac
  [ "$symbol" = "corpus_result" ] || continue            # skip hello.c (sentinel)
  total=$((total + 1)); name="$(basename "$cfile" .c)"
  out="$(python3 "$ROOT/tools/a16_fuzz.py" check --src "$ROOT/examples/snes/$cfile" \
         --name "corpus-$name" --expected "$expected" "${NOBSNES[@]}" 2>&1)" && rc=0 || rc=$?
  if printf '%s\n' "$out" | grep -q 'known issue'; then
    printf '  %-10s XFAIL  %s\n' "$name" "$(printf '%s\n' "$out" | grep -o 'known issue \[[^]]*\]' | head -1)"; xfail=$((xfail+1))
  elif [ "$rc" -eq 0 ]; then
    printf '  %-10s PASS   %s=%s  %s\n' "$name" "$symbol" "$expected" "$desc"; pass=$((pass+1))
  else
    printf '  %-10s FAIL   %s\n' "$name" "$(printf '%s\n' "$out" | grep -E 'RESULT: FAIL|mismatch|CRASH' | head -1)"; fail=$((fail+1))
  fi
done < "$MANIFEST"
echo "==> corpus-a16: $pass/$total passed, $xfail xfail"
[ "$fail" -eq 0 ]
```

**2. (Optional, recommended)** add a `corpus-a16` line to `dev/run.sh`'s help/targets text (≈ lines 3 /
12–192; *documentation only* — dispatch is automatic). Surgical 1-line edit.

**3. Run + verify** (needs a built toolchain + SDK + BIOS; **quiet box** — concurrent MAME load flakes the
settle window): `dev/run.sh corpus-a16`. Expected: `arith/control/arrays/structs/funcs` **PASS**, `globals`
**XFAIL** → `==> corpus-a16: 5/5 passed, 1 xfail`, exit 0. Paste raw output into this plan's Verification
section + promote to `[x]`.
   - **If a non-`globals` program FAILs/crashes:** it's a *new* `+mos-a16`/`+mos-xy16` bug on realistic code
     (the gate working). Triage like `globals.c`: if it's a known family it XFAILs automatically; if new,
     file it + add a `KNOWN_ISSUES` entry (XFAIL, don't block) or fix. Record the finding.

**4. Docs + TODO** (same commit): add a Test-Bench/CI TODO line for `corpus-a16` (the gate closing the
"corpus never built `+mos-a16`" gap, `globals` XFAIL'd); one-line back-reference from
`2026-06-18-321-zp-pressure-measurement.md` (the gap it closes).

**5. Commit (hot tree):** stage ONLY your files (`dev/corpus-a16.sh`, optional `dev/run.sh`, this plan, TODO,
the zp-pressure back-ref). Verify `git diff --cached --name-only`; **never** `vendor/`, `0002`, `.o`, foreign
plans, `docs/transcripts/`. `TODO.md` carries other agents' hunks → stage your hunk surgically (filtered
`git apply --cached`, per the `97e58e4`/`e30f01c` pattern). End the message with the Co-Authored-By line.
Don't push unless asked.

## Verification — VERIFIED 2026-06-19 (raw output below; steps kept verbatim)

1. `dev/run.sh corpus-a16` → table + `5/5 passed, 1 xfail` (globals = `regalloc-out-of-registers`), exit 0.

   ```
   ==> corpus-a16: expected.tsv  (default == +mos-a16 == +mos-xy16, MAME + bsnes-jg)
     arith      PASS   corpus_result=0xA9E9  8/16/32-bit integer ALU
     control    PASS   corpus_result=0x1DFB  loops / if / switch
     arrays     PASS   corpus_result=0x03E1  arrays + .rodata lookup table
     structs    PASS   corpus_result=0x0340  struct layout + pointer deref
     funcs      PASS   corpus_result=0x011E  calls + recursion (soft stack)
     globals    XFAIL  known issue [regalloc-out-of-registers]
   ==> corpus-a16: 5/6 passed, 1 xfail
   EXIT_CODE=0
   ```
   **PASS** — arith/control/arrays/structs/funcs PASS (host == default == `+mos-a16` == `+mos-xy16` on
   MAME + bsnes-jg), `globals` auto-XFAIL'd via `KNOWN_ISSUES` (`regalloc-out-of-registers`, **no
   special-casing in the script**), exit 0. **Denominator note:** the summary prints **`5/6 passed, 1 xfail`**
   not the predicted `5/5` — `total` counts all 6 `corpus_result` programs incl. the XFAIL'd `globals`, which
   matches the sibling `dev/corpus.sh`'s `$pass/$total` convention (kept for house consistency). Substance of
   the step — 5 PASS, globals XFAIL, exit 0 — fully met.

2. `dev/run.sh corpus-a16 -h` → usage, exit 0.

   ```
   Usage: dev/run.sh corpus-a16   # examples/snes/corpus/*.c under +mos-a16 (differential, vs expected.tsv)
   EXIT=0
   ```
   **PASS**.

3. **No regression:** `dev/run.sh corpus` (default 8-bit) still **7/7**; `a16*`/`k_*` suite + `fuzz`
   unaffected (additive; no `vendor/`/`0002` change).

   ```
   ==> corpus: expected.tsv
     hello      PASS  sentinel=0x42 …    arith 0xA9E9  control 0x1DFB  arrays 0x03E1
     structs 0x0340   funcs 0x011E   globals PASS corpus_result=0xAB55  (crt0 .data/.bss)
   ==> corpus: 7/7 passed
   # spot-check a16 micro-test:
   ==> a16eqval … RESULT: PASS — s16 global equality native 16-bit, 0x0101 (default==+mos-a16, both emulators)
   ```
   **PASS** — default corpus 7/7 (incl. `globals`==0xAB55: it compiles clean DEFAULT 8-bit — the very gap
   `corpus-a16` closes); `a16eqval` micro-test PASS. Additive change — no `vendor/`/`0002` touched.

4. Patch sanity: `0002` NOT regenerated (this touches no `vendor/`).

   ```
   0002 UNCHANGED (good — no vendor/ touched, not regenerated)
   git status (mine): M TODO.md  M dev/run.sh  M docs/plans/2026-06-18-…zp-pressure…
                      ?? dev/corpus-a16.sh  ?? docs/plans/2026-06-19-…corpus-a16-differential-mode.md
                      (no vendor/, no .o, no foreign plans)
   ```
   **PASS**.

## Out of scope

- Fixing `globals.c` (deferred — upstream scavenger/regalloc, XFAIL'd; reevaluate at M2 wrap-up).
- Wiring `corpus-a16` into CI (`smoke.yml`/`xcheck`) — sensible follow-on once green locally.
- New corpus programs.
