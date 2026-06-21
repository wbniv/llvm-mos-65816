| Date | Change |
|------|--------|
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/cc940f1) | #321 DWARF step 6 — Step 5: regression tests (dev/run.sh dwarf + staged lit) |

<!--history-meta v1
cc940f1	author	Will Norris
cc940f1	added	32
cc940f1	deleted	0
cc940f1	files	1
cc940f1	body	Compiler-side regression for the DWARF round-trip. No vendor/llvm-mos edits — the\nDWARF content + the <output>.elf companion are already correct (Steps 1/4), so\nthis is pure regression hygiene, and the vendor `.ll` route was redirected:\n  - dev/regen-patch.sh mirrors only llvm/lib/Target/MOS, so a file under\n    llvm/test/ is lost on a clean vendor rebuild (not patch-durable).\n  - full llvm-lit can't run here (container-configured build/llvm-mos lacks\n    count/not; can't rebuild host-side — /work paths).\n\nDelivered:\n  - dev/dwarf.sh + dev/run.sh dwarf — durable, tracked, in-repo gate. Runs the\n    real --config -g build and asserts SHAPES (not addresses): the <output>.elf\n    companion is emitted + has .debug_info, --verify clean, addr_size 0x04,\n    frame_base DW_OP_regx RS0, the 16-bit local has a DW_OP_regx RSn location,\n    subprogram low/high_pc, line table + end_sequence. Gate 7/7 PASS.\n  - dev/lit/DebugInfo/MOS/dwarf-65816.ll (+ README) — the upstream-PR lit form,\n    staged in a tracked dir, verified via the manual llc|llvm-dwarfdump|FileCheck\n    pipeline (all RUN lines pass). Queued in upstream-contribution-status.md with\n    the <output>.elf doc note.\n\nROADMAP step 6 implementation is complete + end-to-end verified. Remaining is\nuser-triggered upstream posting + 2 manual VS Code GUI-pane confirmations.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
