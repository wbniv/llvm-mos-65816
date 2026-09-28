| Date | Change |
|------|--------|
| [2026-09-28](https://github.com/wbniv/llvm-mos-65816/commit/26dce1dd) | Reconcile Farblit instruction shapes and retain gate qualification |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/1c5e12fc) | fix(mos): repair far extload legalization and measure carry scheduling |

<!--history-meta v1
26dce1dd	author	Will Norris
26dce1dd	added	48
26dce1dd	deleted	1
26dce1dd	files	1
26dce1dd	body	Map the fully inlined Farblit probes to their generated access forms on the preserved 0066 toolchain. A controlled rdw byte-split MIR experiment restores indexed-load counts from 2/5 to 3/7, explaining the native-word lowering difference. Identify the A16 cp8 range limitation and the misleading aggregate gate labels. Keep compiler code, fixtures and gate expectations unchanged.\n\nRetain source, MIR, assembly, commands, binary identities and fresh runtime evidence in the existing canonical record. Preserve its failing baseline and established legalization repair. Update current summaries and regenerate dependent views.\n\nValidation: all eight emulator assertions pass; all four ROM hashes match the September 27 captures. The unchanged shell gate still fails its two count checks. Staged document dependencies, defect evidence, comment history and whitespace checks pass.\n\nAI assistance: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, high reasoning effort; verified session 01a0e529-62c6-7fc2-a0c6-357800272c63. Earlier contributors' attribution remains in the retained records.
1c5e12fc	author	Will Norris
1c5e12fc	added	39
1c5e12fc	deleted	0
1c5e12fc	files	1
1c5e12fc	body	Replace queued generic far loads with new target instructions and erase the\ngeneric instruction, so eager address selection cannot leave a target pseudo\non the legalizer worklist. Package 0066 with extending-byte MIR coverage and\npreserve the original failing farblit input, toolchain, and red/green evidence.\n\nMeasure the preserved pre-0064 and 0064 ROMs using an independently instrumented\nbsnes-jg core. Sum and rotate take 30.45% and 17.61% fewer master clocks. The\nisolated XY16 Oz L-system interpreter takes 2.80% more. Record these costs and\nstate that the original zero-cycle-regression acceptance criterion is not met.\n\nValidation: original farblit input red/green at Os/O2 in A16/XY16; direct MIR in\nthree width modes; 180 MOS tests pass, two unsupported; eight farblit/pressure\nemulator assertions pass. The existing farblit shell gate still fails its\naggregate opcode-count expectations, retained as a separate qualification.\nTiming: 34 baseline/candidate comparisons repeated identically (136 executions),\nfour isolated interpreter executions, NOP/RTS/refresh calibration, and a\nbyte-identical probe rebuild. Preserve earlier evidence and posted PR text.\n\nAI assistance: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra,\nxhigh reasoning effort; verified session 01a0e126-2178-79f3-adba-51b951fb1f96.
-->
