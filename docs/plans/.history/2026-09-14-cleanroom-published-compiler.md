| Date | Change |
|------|--------|
| [2026-09-14](https://github.com/wbniv/llvm-mos-65816/commit/a76fb8b) | fix(release-test): ship the fixture's full header closure; report on FAIL too |

<!--history-meta v1
a76fb8b	author	Will Norris
a76fb8b	added	291
a76fb8b	deleted	0
a76fb8b	files	1
a76fb8b	body	Re-verification of the clean-room published-compiler gate against the live\nartifact (apt + product-page tarball, both 0.0.0+git20260625.c49f395) found\ntwo rig defects and one real finding.\n\nRig defects (fixed):\n- dev/Dockerfile.release-test hand-listed the reference program's headers and\n  drifted again (8ac159f added #include "snesgfx/m7title.h" -> ../font16.h), so\n  the gate failed at compile with 'file not found' — a rig fault masquerading\n  as a compiler verdict. Now COPY examples/snes/*.h, examples/snes/snesgfx/ and\n  examples/65816/*.h wholesale; <snes.h>/<stdint.h> still come from the\n  published sysroot.\n- dev/test-release.sh ran `docker run … | tee` under set -euo pipefail, so a\n  failing container aborted the script before the HTML report step. A FAILING\n  gate run therefore produced no report — the case the report exists for.\n  Bracket the pipeline with set +e / PIPESTATUS[0] / set -e.\n\nFinding (recorded in the plan, not papered over): the published package's SDK\npredates the snes.h HAL split (2d23b38 is not an ancestor of c49f395), so the\ncurrent examples/snes/mandel-display.c (0x204F) does not compile with it\n(NMITIMEN_NMI / NMITIMEN_AUTOJOY undeclared) via both apt and tarball. The\nSDK-independent k_mandel passes 0x820B on default-8bit and +mos-a16 via both\nmethods, so published codegen is still correct; the staleness is 31 patch\ncommits + 7 platforms/snes commits behind main (294bc8c).\n\nPlan: docs/plans/2026-09-14-cleanroom-published-compiler.md (raw run output\nunder each verification step). METHOD=local not run: no dist/ tarball and\nproducing one is a shared-tree toolchain rebuild.\n\nCo-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_011AP736JtwzSGYH4bmxDWTa\n(cherry picked from commit 42c62c24c28cc7dffed9072be19a9a866e9a47d9)
-->
