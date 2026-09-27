# Carry-scheduler execution-time measurements

**Later gate investigation (2026-09-27):** the [current-stack report](2026-09-27-competing-carry-gate.md) measures all three scheduler policies, compile time, the ordinary-6502 kernel and additional size exceptions. The gate matches `off` timing on the 30 original SNES growth cases; its broader size trade-offs and possible selection mechanisms are presented for LLVM discussion without a default-selection conclusion. The compiler currently defaults to `always`. The frozen build-pair results below, including the +2.80% interpreter cost, remain dated evidence. Update: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

**Result (2026-09-27):** 0064 reduces elapsed master clocks by **30.45% for the original sum** and **17.61% for rotate**, in both A16 and XY16. It also makes the isolated XY16 `-Oz` L-system interpreter **2.80% slower**. The original zero-cycle-regression acceptance criterion is **not met**. These measurements support targeted gains and measured tradeoffs; they do not establish a universal speed improvement.

**Attribution:** OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0e126-2178-79f3-adba-51b951fb1f96`.

## Scope and method

This completes the execution-time measurement omitted from the [September 26 plan](../plans/2026-09-26-mos-carry-scheduling.md). That plan explicitly required hot-loop cycles; its completion report provided no cycle experiment or documented technical blocker. The omission was a validation gap. Earlier reports and their evidence remain dated records.

The comparison uses the preserved September 26 pre-0064 and 0064 builds, with normal scheduling enabled. It measures four original sum/rotate configurations and all 30 growing census configurations targeting the SNES CPU. The two adapted ordinary-6502 `rotkal` configurations are excluded because they need a 6502 timing harness. Compile-time overhead, the withdrawn upstream extraction, and the current compiler with 0065/0066 are outside these timing results. The [canonical record](../defects/mos-carry-scheduling-pressure.json) remains a **workaround** for the generic pressure-model defect.

[The runner](../../dev/measure-carry-cycles.py) uses the original non-LTO function ROMs and preserved census objects. The eight original ROM hashes match the frozen runtime receipt. All 60 growth-object disassemblies match the immutable September 26 archive. Growth objects are linked with one common preserved candidate linker and SDK, so later compiler patches do not enter the comparison. The original ROMs retain their recorded drivers and layouts; their calls use the same six bank-boundary input triples. Differences in placement and DRAM-refresh phase are part of the observed ROM timings.

[The probe](../../dev/jgxcycles.cpp) uses an independently copied **bsnes-jg 2.1.0** core. [The build script](../../dev/build-cycle-probe.py) inserts hooks immediately before and after an executed CPU instruction. It reads the core's `counter.cpu`, which advances by two master clocks in `CPU::stepOnce`; unsigned subtraction handles wraparound. A native near-call sample includes the function through its RTS and excludes the caller's JSR. Main-region samples end after the instruction that writes the expected oracle result. Nested helper calls, bus wait states, DRAM refresh, and any DMA/interrupt work during the interval are included. The per-address profile separately records instructions executed inside the selected address range.

All ROMs use deterministic entropy zero and no controller input. Each of the **68 ROM/configuration measurements ran twice**, with identical cycle samples and instruction profiles, and matched its frozen or host-computed correctness oracle. Four additional executions isolate the L-system interpreter. These are emulator master-clock measurements, not host wall time, frame counts, or static instruction estimates. Master clocks are used because SNES memory regions have different access speeds; one master clock is not one CPU instruction cycle.

A calibration function executes 64 NOPs and an RTS from SlowROM. It measures **978 clocks**: 64 × 14 for the NOPs, 42 for RTS, and one 40-clock DRAM refresh. Each NOP executes exactly once; the profile records 14 clocks per NOP except 54 for the refresh-overlapping instruction. The profile sum equals the interval. Rebuilding the final probe source produces a byte-identical binary. [Receipt and artifact hashes](../defects/evidence/2026-09-27-mos-carry-timing/receipt.json) retain this check.

## Results that determine the conclusion

| Region and input | Baseline master clocks | 0064 master clocks | Change |
| --- | ---: | ---: | ---: |
| Sum, 24 calls, A16 or XY16, `-Os` | 106,784 | 74,264 | **−30.45%** |
| Rotate, 24 calls, A16 or XY16, `-Os` | 111,192 | 91,608 | **−17.61%** |
| L-system interpreter, XY16, `-Oz` | 17,535,642 | 18,026,532 | **+2.80%** |
| L-system full rewrite + interpretation, XY16, `-Oz` | 190,048,936 | 190,539,826 | +0.26% |
| Spirograph first HUD update, A16, `-Os` | 37,788 | 37,918 | +0.34% |
| Spirograph first HUD update, XY16, `-Os` | 37,748 | 37,932 | +0.49% |

The L-system interval starts at the common `main + 0x14f` generation-exit block, where the inlined interpreter initializes heading 192 and its turtle state. It ends at the `0x8073` result store. Both linked instruction streams are retained, and the probe asserts the entry bytes. The input, machine code, ROM, and result are unchanged from the full-gate run; only the observation interval changes. Its **490,890-clock increase is exactly the full gate's increase**, locating the cost in interpretation rather than the much longer string rewrite. The retained growth review identifies extra indirect frame traffic in this same loop. This is a measured cost of the selected schedule, with no compiler repair attempted in this follow-up.

The HUD observations cover the initial no-input view. DCT timings below cover the first 128 `fill_cell` calls, including helper calls. Renderer `main` timings include setup and presentation waits through the oracle latch; in particular, Avalanche's tiny negative deltas do not demonstrate faster hashing. Differences of a few dozen clocks can reflect layout and refresh phase. Full-gate values must not be presented as isolated hot-loop gains.

## All growing SNES configurations

Positive values mean more elapsed clocks. Each row compares the preserved baseline and candidate census objects over the observation interval named above. `rcundef2` computes the L-system gate through its result store; corpus slices end at their result store. The renderer rows for `lsystem` and `avalanche` include startup.

| Source | Mode | Opt | Baseline clocks | 0064 clocks | Change |
| --- | --- | --- | ---: | ---: | ---: |
| `rcundef2` | a16 | Os | 188,484,110 | 188,498,118 | +0.00743% |
| `avalanche` | a16 | Os | 198,694,804 | 198,694,778 | -0.00001% |
| `lsystem_sim` | a16 | Os | 189,956,310 | 189,999,548 | +0.02276% |
| `dctbloom` | a16 | Os | 20,671,252 | 20,678,740 | +0.03622% |
| `spirograph` | a16 | Os | 37,788 | 37,918 | +0.34402% |
| `rcundef2` | xy16 | Os | 188,054,512 | 188,068,520 | +0.00745% |
| `lsystem` | a16 | Os | 226,941,992 | 226,986,368 | +0.01955% |
| `avalanche` | xy16 | Os | 198,691,986 | 198,691,982 | -0.00000% |
| `lsystem_sim` | xy16 | Os | 190,523,962 | 190,587,078 | +0.03313% |
| `spirograph` | xy16 | Os | 37,748 | 37,932 | +0.48744% |
| `dctbloom` | xy16 | Os | 22,402,656 | 22,410,222 | +0.03377% |
| `bf_vm_sim` | default | Os | 2,112,042 | 2,112,084 | +0.00199% |
| `rotkal_sim` | default | Os | 770,114 | 771,554 | +0.18699% |
| `lsystem` | xy16 | Os | 228,156,066 | 228,229,822 | +0.03233% |
| `avalanche` | a16 | Oz | 200,121,588 | 200,121,580 | -0.00000% |
| `dctbloom` | a16 | Oz | 18,966,374 | 18,973,114 | +0.03554% |
| `rcundef2` | xy16 | Oz | 187,622,394 | 187,734,128 | +0.05955% |
| `lsystem_sim` | xy16 | Oz | 190,048,936 | 190,539,826 | +0.25830% |
| `avalanche` | xy16 | Oz | 200,118,760 | 200,118,738 | -0.00001% |
| `bf_vm_sim` | default | Oz | 2,490,812 | 2,490,854 | +0.00169% |
| `rotkal_sim` | default | Oz | 891,662 | 893,102 | +0.16150% |
| `seqvm_sim` | default | Oz | 1,751,974 | 1,752,150 | +0.01005% |
| `dctbloom` | xy16 | Oz | 19,456,972 | 19,464,068 | +0.03647% |
| `bf_vm_sim` | default | O2 | 2,046,042 | 2,046,084 | +0.00205% |
| `rcundef2` | a16 | O2 | 188,484,700 | 188,498,748 | +0.00745% |
| `lsystem_sim` | a16 | O2 | 189,968,276 | 190,011,514 | +0.02276% |
| `lsystem` | a16 | O2 | 226,811,846 | 226,855,808 | +0.01938% |
| `rcundef2` | xy16 | O2 | 188,055,102 | 188,069,150 | +0.00747% |
| `lsystem_sim` | xy16 | O2 | 190,535,928 | 190,599,004 | +0.03310% |
| `lsystem` | xy16 | O2 | 227,811,388 | 227,884,810 | +0.03223% |

## Disposition and reproducibility

The size optimization remains implemented locally, and the original carry-cliff functions are faster on the measured inputs. The selected policy fails the original zero-regression requirement for measured execution time. Keep the L-system frame traffic and HUD scheduling costs open for profitability work; do not treat the earlier acceptance of byte-size losses as approval of these newly measured timing losses. No generic pressure-model closure, independent review, new upstream submission, or compiler-time claim follows from these results.

[Summary](../defects/evidence/2026-09-27-mos-carry-timing/results.json), [exact commands](../defects/evidence/2026-09-27-mos-carry-timing/commands.json), [linker/SDK identity](../defects/evidence/2026-09-27-mos-carry-timing/identity.json), [emulator identity](../defects/evidence/2026-09-27-mos-carry-timing/emulator-identity.json), and [raw ROM/object/map/disassembly/profile archive](../defects/evidence/2026-09-27-mos-carry-timing/timing-runs.tar.gz) preserve the run. The [interpreter receipt](../defects/evidence/2026-09-27-mos-carry-timing/interpreter-results.json) and [replay script](../defects/evidence/2026-09-27-mos-carry-timing/measure-interpreter.py.txt) retain its narrower interval. Original September 26 sources, compiler identities, and evidence stay unchanged.

From the repository root, with the preserved toolchain worktree available:

```sh
dev/container.sh -- python3 dev/build-cycle-probe.py .scratch/carry-timing
dev/container.sh -- python3 dev/measure-carry-cycles.py \
  .scratch/carry-scheduling .scratch/carry-timing/jgxcycles \
  .scratch/carry-timing/runs --jobs 3
```

The evidence archive includes the already-linked ROMs, so their recorded probe commands can also be replayed without relinking. The source scripts accept an alternate output directory. `--resume` reuses completed rows in an existing run directory; use it only for the same preserved inputs and probe.
