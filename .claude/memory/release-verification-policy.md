---
name: release-verification-policy
description: "llvm-mos-65816 published-compiler release verification — always test on release, no periodic CI smoke, produce an HTML report"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0d634f7b-7b68-4904-a099-2545ed4cae74
---

For the llvm-mos-65816 published SNES compiler, releases are verified by a **clean-room
emulator test on every release** (the `METHOD=local` gate inside `dev/package-release.sh` /
`task package`: acquire the just-built tarball's `mos-snes-clang`, compile
`examples/snes/mandel-display.c` default-8bit + +mos-a16, run in bsnes-jg, assert WRAM
CRC `0x9103`). Each run produces a self-contained HTML **report** (`dev/release-report.py`)
with the timestamped compile+emulation log, the SNES screenshots, config, package details,
and a names+sizes table of the bundled `.md`/`.pdf` docs (release bundles the sibling
`../indri.studio/public/docs` via `RELEASE_DOCS_DIR`). Report filenames carry a UTC
run-timestamp; the publish path copies the canonical one to `dist/<name>-release-report.html`.

**Why:** the user wants verification tied to the *act of releasing*, not to a timer, and
wants every release to leave human-reviewable evidence (log + screenshots + package/doc info).

**How to apply:** do NOT propose or add a periodic/scheduled CI `release-smoke` job — that
was explicitly declined (2026-06-25). `METHOD=apt` / `METHOD=tarball` exist only as *manual*
post-deploy confirmations. When touching release/packaging, keep the on-release gate +
report intact. Details: [[../../docs/plans/2026-06-25-test-published-snes-compiler.md]] (plan
"Release policy" + §D). Related: [[modest-gains-worth-doing]].
