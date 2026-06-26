# Finish the full vendoring of the GCC c-torture/execute suite

## Context

The gcc c-torture/**execute** differential gate (issue #321) is live and green: 1656 **top-level**
`execute/*.c` tests are fetched (gitignored, `dev/fetch-torture.sh`), partitioned by the Phase-0 host
filter (`tools/torture_filter.py` → `examples/65816/torture/{inscope,unsupported}.tsv`), and run through the
4-way differential (`tools/torture_run.py`, also wired into the `torture` CI job). All known a16/xy16
miscompiles it found are fixed; `xfails.tsv` has no data rows.

But the vendoring is **not full**. `dev/fetch-torture.sh` extracts the *entire* `execute/` tree (1862 `.c`),
yet the filter globs **only top-level** `*.c` — so the two subdirectories are silently unaccounted-for:

| Subdir | `.c` files | What they are |
|---|---|---|
| `ieee/` | **68** | single-file IEEE-754 float self-checking tests (`main` + `abort()`) — same shape as top-level |
| `builtins/` | 110 | gcc `__builtin_*` tests: **55 main tests** (`main_test()`, no `main`) + **55 `-lib.c` companions** |
| `builtins/lib/` | 28 | shared harness support (`main.c`, reference impls) — **not tests** |

The filter has a dormant `--subdirs` flag, but it was never validated end-to-end and is **broken**: it keys
the manifest by `cfile.name` (basename), and 5 names collide across top-level/subdir (`920810-1.c`,
`930529-1.c`, `strcpy-2.c`, `strlen-2.c`, `strlen-3.c`) → ambiguous/duplicate keys the runner can't resolve.

"Finishing the full vendoring" = make the committed manifest **account for every real test** in the suite,
so nothing is silently dropped (the filter's own stated invariant: *"every test lands in exactly one
bucket"*). The payoff is **`ieee/`**: 68 single-file float tests that add genuinely new differential coverage
of a16/xy16 handling of `float`/`double` values + the soft-float call ABI — an axis the integer top-level
suite never exercises.

## The gap, precisely

- `vendor/c-torture/execute/` has 1862 `.c` = 1656 top-level + 110 `builtins/` + 28 `builtins/lib/` + 68 `ieee/`.
- Committed `inscope.tsv` (1228) + `unsupported.tsv` (428) = 1656 — **top-level only**; zero `builtins`/`ieee`
  rows (verified: `grep builtins|ieee` over the manifests = none).

## Approach (recommended)

**One code edit (filter only). The runner needs no change** — verified end-to-end: `SRCDIR / "ieee/foo.c"`
resolves transparently, and every output file is a fixed name (`default.sfc`, `a16.sfc`, …) inside a per-test
`mkdtemp`, so a slash in the test name never reaches a filename. xfails/sample/start slicing all operate on
the name string and are slash-safe.

### 1. Fix `tools/torture_filter.py` (the only source change)

- **Manifest key → SRCDIR-relative path.** In `build_one()` (line ~107):
  `name = cfile.name` → `name = str(cfile.relative_to(SRCDIR))`.
  Top-level rows stay byte-identical (`foo.c`); subdir rows become `ieee/foo.c` / `builtins/foo.c`. This
  disambiguates the 5 collisions and lets the runner resolve via `SRCDIR / name`. The regenerated manifest
  diff is **purely additive** — existing 1228 in-scope rows are unchanged.

- **Scan subdirs unconditionally, exclude non-test support files.** In `main()` (lines ~155-157), replace the
  `if args.subdirs:` block with:
  ```python
  tests = sorted(SRCDIR.glob("*.c"))
  tests += sorted(t for t in SRCDIR.glob("*/*.c") if not t.name.endswith("-lib.c"))
  ```
  `*/*.c` (one level) catches `ieee/*.c` + `builtins/*.c` but **not** `builtins/lib/*.c` (two levels) — so the
  28 support files are excluded for free; do **not** use `**/*.c`. The `-lib.c` filter drops the 55 companion
  files. Net scanned: 1656 + 68 + 55 = **1779** real tests. (Drop `--subdirs` or keep it as an accepted
  no-op so the committed manifest is always the full suite.)

- **Honest `builtins/` bucket (no opaque diagnostics).** All 55 builtins main tests define `main_test()` and
  no `main`, so single-file compilation fails with a misleading `undefined symbol: torture_test_main`. Add a
  cheap pre-check in `build_one()`: a `builtins/` test (no `main(`, has `main_test(`) → bucket
  `builtins-multifile`, reason *"gcc builtins multi-file harness (needs lib/main.c + -lib.c companions); not
  single-file linkable"*. This keeps the manifest auditable and acts as a tripwire (XPASS-style) if a future
  companion-link harness ever makes them runnable.

### 2. Regenerate the manifests (host step, you run)

```
FUZZ_ROOT=$PWD MOS_TOOLCHAIN=$PWD/build/llvm-mos-install python3 tools/torture_filter.py   # default -Os
```
Expect: top-level partition reproduced identically + 68 `ieee/` rows partitioned (some in-scope, some
SKIP/unsupported per float/header support) + 55 `builtins/` rows in the new `builtins-multifile` bucket.
Commit `inscope.tsv` + `unsupported.tsv`.

### 3. Run the differential gate on the newly in-scope tests + triage

Run the full 4-way gate over the grown manifest at both opt levels, focusing on the new `ieee/` in-scope rows:
```
dev/run.sh torture 100000 --opt -Os
dev/run.sh torture 100000 --opt -O1
```
DEFAULT build is the oracle, so any ieee test whose (8-bit) default ROM doesn't self-check PASS → SKIP (never
a false FAIL); only a genuine a16/xy16 disagreement is a FAIL. Triage any FAIL as a real defect (root-cause +
fix, or `xfails.tsv` row keyed `ieee/foo.c` if deferred). Record the as-run counts.

### 4. Docs — add current state, preserve dated history

Add a **"Full vendoring (2026-06-26)"** results block; update only forward-looking/summary wording, leave
dated as-run RESULTS/commit-history counts intact:
- `docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md` ~L190-192 — rewrite the load-bearing
  *"`builtins/` and `ieee/` … excluded by design … out of the freestanding integer scope"* narrative.
- `docs/agent-handoff.md` ~L98, `docs/65816-patch-series-review-guide.md` ~L767,
  `docs/investigations/plan-index.md` ~L90 — current-state "1253/1656 in-scope" summaries.
- `TODO.md` ~L362/L368 — promote the `[wip]` item: full vendoring done, ieee coverage added.
- `dev/fetch-torture.sh` ~L59 — extend the final echo to also report ieee/builtins counts (cosmetic).

**Coverage wording (be precise):** there is no a16/65816 multilib, so the soft-float kernels (`__adddf3`,
`__divsf3`, …) link from the single prebuilt 8-bit `common` library and are identical object code across
default/a16/xy16. What +mos-a16 recompiles is the **test's own TU** — float/double load/store/spill, the
soft-float **call ABI** (marshalling 8-byte doubles), and branch-on-fp lowering. Describe it as *"exercises
a16 handling of float/double values and the soft-float call ABI"*, **not** *"soft-float a16 codegen"*.

## Out of scope (explicit non-goals)

- **builtins multi-file harness.** Making the 55 builtins main tests actually *run* requires replicating
  gcc's `builtins.exp` model (link `foo.c` + `foo-lib.c` + `lib/main.c`/helpers, honor `-fno-builtin`
  dg-options). That's a separate feature, not "finishing vendoring." This plan **accounts for** them
  (`builtins-multifile` bucket) and leaves the harness as a noted follow-up.
- Opt-level-aware `xfails.tsv`, runner retry-on-flake — unchanged from the original plan's out-of-scope.
- No CI change: the `torture` job reads the **committed** manifest (never re-runs the filter), so a
  regenerated+committed `inscope.tsv` auto-covers the new tests in both `sampled` and `full` modes.

## Verification

1. **Filter scans the full suite, manifest is additive.** Regenerate; confirm:
   - `grep -c '^[^#]' inscope.tsv` ≥ previous 1228; `grep -E '^ieee/' inscope.tsv | wc -l` > 0.
   - top-level rows unchanged: `git diff inscope.tsv` shows only additions (no top-level deletions/edits).
   - `builtins/` rows all land in the `builtins-multifile` bucket in `unsupported.tsv`; **no**
     `builtins/lib/` or `*-lib.c` rows anywhere (support files excluded).
2. **No basename collisions in the manifest.** `cut -f1 inscope.tsv unsupported.tsv | grep -v '^#' | sort |
   uniq -d` → empty (subdir-prefixed keys are unique).
3. **Runner resolves + runs subdir tests.** `dev/run.sh torture --tests ieee/<an-inscope-name>.c --opt -Os`
   → runs (PASS or SKIP), not "ERROR not found".
4. **Full 4-way sweep green-modulo-known.** `dev/run.sh torture 100000 --opt -Os` then `-O1`: record
   PASS/FAIL/SKIP/XFAIL; 0 FAIL (or each FAIL triaged → fix or `ieee/…` xfails row). Paste raw output.
5. **CI unaffected, broader.** Confirm `.github/workflows/smoke.yml` `torture` job still references only the
   committed manifest (no filter invocation); `full` mode now sweeps the ieee rows.
6. **Docs current.** `task md -- docs/...` preview; the "excluded by design" narrative is replaced; coverage
   wording matches the soft-float nuance above.

## Critical files
- `tools/torture_filter.py` — the only code edit (relative-path key + subdir glob + builtins bucket).
- `tools/torture_run.py` — **no change** (verified); resolves subdir-pathed names already.
- `examples/65816/torture/{inscope,unsupported}.tsv` — regenerated, committed.
- `docs/plans/2026-06-19-321-c-torture-execute-differential-suite.md`, `docs/agent-handoff.md`, `TODO.md` — doc updates.
- `.github/workflows/smoke.yml` — no change (manifest-driven).
