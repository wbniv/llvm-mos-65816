# 2026-09-28 build-determinism gate sweep

## Result

The fixed-compiler sweep completed all 135 demos in the declared set: 132 gates passed and 3 failed. The sweep is complete as an execution record, but the three failed MAME capture legs remain unresolved. Per-demo elapsed seconds and the retained runner output are in [results.tsv](results.tsv). Each log is preserved under [logs/](logs/).

## Scope and compiler

- The original TODO said 138 demos. The executable set contains 135 main-bearing demo sources. The three `snes-video-*` translation units are supporting sources with no `main()` and are excluded from the manifest.
- Compiler: `clang version 23.0.0git`, source revision `8be0546128a55e78c63ca571d466aa72a782cd36`, installed at `build/llvm-mos-install/bin/clang`.
- Backend used by the runner: `build/llvm-mos/bin/llc`, SHA-256 `cf5355d392bd37cdce2606cbb19465db68a63e8ffa911613fabc474ffa2d5f7`. The runner verified the observer-bracket fix in the live `MOSLegalizerInfo.cpp` and that this `llc` was newer than that source before executing each batch.
- Aggregate gate time: 23,749 seconds (6 h 35 min 49 s), the sum of per-demo elapsed seconds. This excludes container startup and batch overhead.

## Apollo Reel input

The historical 20-second Apollo tile corpus was unavailable, so the gate used a reconstructed corpus from the vendored 600-frame excerpt `assets/snes/video/apollo11-daylight-5994p.mp4` (10.01 seconds at 220999/3687 fps). The RGB24 input SHA-256 is `0db7a75b7a87b0fd4a4eb5573c3c10d180369d2b688681c5769ca3966785000d`; the reconstructed tile and palette outputs have SHA-256 `fe2497baf18fd235761f391f806b31e510ae09e397fd88da397ee9277ca60231` and `08fcf73cf96addc6f7672f3789522c3e00cd94f9ccb1bea42b0dcb71b7892057`. Apollo Reel passed with this input. This is reconstructed-input evidence, not a byte-identical reproduction of the historical corpus.

## Failed gates

- `burning-ship`: gate failed after 45 seconds. The host oracle, disassembly, and bsnes-jg assertions passed; the MAME section produced no capture/assertion output in the retained log. See [the burning-ship log](logs/burning-ship.log). The captured evidence does not establish why the MAME step failed.
- `cosmzoom`: gate failed after 40 seconds. The host oracle, disassembly, and bsnes-jg assertions passed; the MAME section produced no capture/assertion output in the retained log. See [the cosmzoom log](logs/cosmzoom.log). The captured evidence does not establish why the MAME step failed.
- `percol`: gate failed after 25 seconds. The host oracle, disassembly, and bsnes-jg assertions passed; the MAME section produced no capture/assertion output in the retained log. See [the percol log](logs/percol.log). The captured evidence does not establish why the MAME step failed.

No gate was rerun after completion. The interrupted full-batch attempt and an earlier stale-toolchain attempt are excluded from this result set; only rows produced by the compiler identity above are included.

## Per-demo results

`results.tsv` is in manifest order and records each gate, exit status, elapsed seconds, source run ID, and retained log path.
