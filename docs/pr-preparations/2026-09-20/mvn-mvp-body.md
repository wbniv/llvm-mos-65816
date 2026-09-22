`mvn #127, #0` currently emits `54 7f 00`, causing the 65816 to copy from bank 0 into bank 127. The assembly operand order is source,destination, but the hardware consumes destination,source. `mvp` has the same mismatch.

Swap the two fields in `Inst816MemoryMove` and exchange the operands' `imm8`/`imm8at2` encoder types so symbolic bank relocations target the corresponding bytes too. The syntax stays source,destination; `mvn #127, #0` emits `54 00 7f` and those bytes disassemble back to the same operands.

The [W65C816S datasheet](https://www.westerndesigncenter.com/wdc/documentation/w65c816s.pdf) (§3.5.9, page 19) specifies destination in the second instruction byte and source in the third. LLVM MOS's operand names and assembly format already use source,destination. The existing all-opcodes test uses identical bank values, which cannot distinguish their order.

The regression covers both instructions with distinct banks, the 0/255 boundaries, object disassembly, symbolic fixup/ELF relocation offsets, and forward-defined bank constants. This was encountered while copying SNES video data between banks in [SVX2 FastROM Animated Video](https://biohack.net/snes/svx2-fastrom-video/). The published ROM uses the downstream bank-order correction; the regression itself requires no ROM assets or native-width compiler extensions.

Validated against upstream [`742d554bf080`](https://github.com/llvm-mos/llvm-mos/commit/742d554bf08042b8df93d791c335260fadd16643) using freshly built Release/assertions-enabled MOS tools. All five targeted checks fail before the fix and pass afterward. MOS MC and CodeGen suites: 130 passed, one unsupported, zero failures.
