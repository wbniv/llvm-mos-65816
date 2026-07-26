| Date | Change |
|------|--------|
| [2026-07-26](https://github.com/wbniv/llvm-mos-65816/commit/a859a32) | docs(oop-in-c): refresh + measure the all-virtual-dispatch design question |

<!--history-meta v1
a859a32	author	Will Norris
a859a32	added	126
a859a32	deleted	0
a859a32	files	1
a859a32	body	Refresh: 13 headers / 113 demos (was 12/29); delete the fictional selector-table\nrow; §4 corrected — the "0 indirect JMPs / LTO devirtualized" claim was a\nmeasurement artifact (grep 'jmp (' misses __call_indir; ||true over a missing\nELF reads 0): ONE indirect call survives even in production. §5: mandel-display\ndiverged (8290 B) — the +338 B figure is historical, labeled as such.\n\nNew §8 — static vs all-virtual dispatch, measured (throwaway/snesgfx-virt-bench\n8ad0f28, 3-mode SNESGFX_DISPATCH experiment, bsnes-jg deterministic):\n  - out-of-line direct BEATS static inline by 15% (a16 register-pressure relief)\n  - vtable indirection proper costs 1.35x on a per-pixel dispatch loop\n  - .text +15% (bench) / +49% (mandel-oop); LTO devirtualizes 0 of 15 sites\n  - correctness identical all modes (0x204F / 0x26EC)\n\ndev/mandel-oop.sh hardened (ELF-existence assert, $TOOL/llvm-objdump, full\nindirect-site pattern, SNESGFX_CFLAGS passthrough); dev/run.sh forwards\nSNESGFX_CFLAGS/BENCH_FRAMES. Investigation doc + charts + re-appliable patch\narchived under docs/investigations/; plan with verification evidence in\ndocs/plans/. TODO.md:371 dated correction appended to the historical record.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
