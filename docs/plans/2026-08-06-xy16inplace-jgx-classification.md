# `xy16inplace` bsnes-jg result classification

**Date:** 2026-08-06 · **Status:** COMPLETE · **Tier:** T2

## Problem

`dev/run.sh xcheck-suite` reported `xy16inplace` as its only bsnes-jg SKIP even though
`dev/xy16inplace.sh` exited zero and printed `RESULT: PASS`. The focused log contained six `????`
values. The script invoked `jgxcheck` with an intentionally wrong expected value (`0x0000`), discarded
stderr (where the mismatch result was printed), and then compared the fallback string `????` across all
three builds. Three missing observations therefore compared equal and produced a false PASS. The aggregate
suite correctly rejected the run because no positive `frames, bsnes-jg` assertion line existed.

## Fix

For each capacity, use the default build only to discover the reference value, then rerun it through
`jgxcheck`'s positive assertion path. Require every default/a16/xy16 execution to:

- exit successfully from `jgxcheck`;
- contain a parsed `got=0x...` equal to the reference; and
- contain the positive `frames, bsnes-jg` result line consumed by `xcheck-suite`.

Missing, malformed, or mismatching emulator output now sets the gate's failure status. The result text no
longer claims a host oracle: this script compares the three target configurations on bsnes-jg.

## Verification

```text
$ dev/run.sh xy16inplace
CAP=1700 default = 0x90AA  SMOKE: PASS ... (ran 600 frames, bsnes-jg)
CAP=1700 a16     = 0x90AA  SMOKE: PASS ... (ran 600 frames, bsnes-jg)
CAP=1700 xy16    = 0x90AA  SMOKE: PASS ... (ran 600 frames, bsnes-jg)
CAP=200  default = 0xDEBD  SMOKE: PASS ... (ran 600 frames, bsnes-jg)
CAP=200  a16     = 0xDEBD  SMOKE: PASS ... (ran 600 frames, bsnes-jg)
CAP=200  xy16    = 0xDEBD  SMOKE: PASS ... (ran 600 frames, bsnes-jg)
-verify xy16 clean
RESULT: PASS

$ dev/run.sh xcheck-suite
PASS  xy16inplace  SMOKE: PASS off=0x8A4 len=2 got=0x90AA (ran 600 frames, bsnes-jg)
RESULT: PASS — 52/52 bsnes-jg value tests agree (second emulator confirmed, MAME not run)
```

`bash -n` and `shellcheck` also pass; the deliberately word-split target-feature bundle carries a scoped
SC2086 suppression.
