# Prior emulator/testing discussions — checked 2026-09-20

No selected 65816 CI runner was found in the public records searched. This is not
proof that no decision exists: the project's [main community hub is Discord](https://llvm-mos.org/wiki/Community),
whose message history was not available in this research.

## What has been discussed or implemented

| Record | Discussion/result | Relevance to MVN/MVP execution tests |
|---|---|---|
| [Compiler #26](https://github.com/llvm-mos/llvm-mos/issues/26), March–June 2021, closed | John Byrd proposed a TableGen-based family of 65xx emulators, explicitly anticipating 65816. The proposed principal interface was an LLVM emulator checked by lit/FileCheck. mysterymath emphasized independent emulator fidelity and observable bus behavior. | Execution tests inside LLVM were explicitly envisaged; issue closure alone does not establish a shipped 65816 implementation. |
| [Compiler #5](https://github.com/llvm-mos/llvm-mos/issues/5), April–May 2021, closed | Existing simulators were considered as a practical starting point; by May 18, the MOS fork of llvm-test-suite could compile/link/run small programs under the SDK simulator. | The separate end-to-end suite is an established execution-test location. |
| [SDK #78](https://github.com/llvm-mos/llvm-mos-sdk/issues/78), 2022–2023, closed | Headless Mesen-specific integration was hard to maintain. Libretro was proposed as a shared API; the discussion progressed from framebuffer hashes to RAM pass/fail signatures. | Reuse a standard runner/core interface rather than assuming each emulator needs bespoke CI scripting. |
| [SDK #241](https://github.com/llvm-mos/llvm-mos-sdk/pull/241), merged November 19, 2023 | Added Emutest/Libretro Atari/NES tests, RAM signatures, optional framebuffer CRC checks and CI support. | There is shipped platform-emulator test infrastructure, but this is not a selected SNES core. |
| [SDK #268](https://github.com/llvm-mos/llvm-mos-sdk/issues/268), December 12, 2023, still open | Atari800/Emutest crashes motivated a simpler C/C++ Libretro runner maintained inside the SDK. | Emutest is not an unqualified settled preference; acknowledge the replacement proposal. |
| [Compiler #339](https://github.com/llvm-mos/llvm-mos/issues/339), still open | Requests 65C02 `-Os` CI coverage and cautions against a full Cartesian product of CPU/optimization/debug settings. | CPU-specific execution CI is already discussed; keep a proposed 65816 configuration bounded. |
| [LLVM Discourse update](https://discourse.llvm.org/t/tablegen-backend-for-emulator-core/57874/7), February 9, 2026 | John Byrd reports a working MOS 6502 emulation layer, TableGen/SAIL integration and an LLDB prototype; execution testing/CI is a stated use. Early access is offered out of band. | A current alternative exists to ask about. The post does not claim 65816 support or establish public upstream integration. No contact was sent. |
| [Compiler PR #549](https://github.com/llvm-mos/llvm-mos/pull/549), merged 2026 | Author reports end-to-end validation with a patched 65CE02 SDK simulator in addition to MC tests and a machine emulator. | Recent precedent for retaining small MC regressions while citing additional external execution evidence. |

Current checked sources agree with the distinction above: the SDK simulator uses
Fake6502 with 16-bit memory callbacks; MOS MC/CodeGen lit configurations enable the
MOS target but provide no 65816 runner. The [test-suite README](https://github.com/llvm-mos/llvm-test-suite)
documents `TEST_SUITE_RUN_UNDER` and a `mos-sim --cmos` example. The checked current
compiler main is `742d554bf080`; SDK main is `3f6968bbc156`.

## Search coverage and limits

Searched GitHub issues/PRs across the llvm-mos organization for simulator, emulator,
65816, llvm-emu, emutest and test-suite references; read the linked issue bodies and
comments. Read all four compiler GitHub Discussions (including available comments);
none matched the simulator/65816/testing terms. The SDK and test-suite repositories
do not have GitHub Discussions enabled. Also searched public LLVM Discourse and
read the full February 2026 emulator update. No Discord/private chat history was
searched, and no public post was made.

## Separate discussion draft

The simulator material is now in a [standalone discussion draft](65816-simulator-discussion-body.md),
not in the MVN/MVP PR description. It asks about runner choice, test placement,
CI provisioning and execution/result conventions using the research above.
No discussion has been published and no execution harness has been implemented.
The encoding fix can be submitted and merged independently.

## Separate SNES acceptance finding

[The maintainer's October 29, 2025 comment on SDK #415](https://github.com/llvm-mos/llvm-mos-sdk/pull/415#issuecomment-3463891415)
explicitly declines merging until proper 65816 support exists, citing long-term
support problems if users depend on the restricted mode's quirks. It refers to a
Discord discussion unavailable here. A baseline platform is technically possible,
but that does not mean it meets the stated merge policy. Tracking documents now
separate technical dependencies from this acceptance requirement.
