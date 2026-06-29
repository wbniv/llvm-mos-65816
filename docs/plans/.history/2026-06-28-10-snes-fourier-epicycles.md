| Date | Change |
|------|--------|
| [2026-06-28](https://github.com/wbniv/llvm-mos-65816/commit/070328f) | feat(snes): #10 Fourier epicycles — many-multiply / sin-cos stress demo |

<!--history-meta v1
070328f	author	Will Norris
070328f	added	121
070328f	deleted	0
070328f	files	1
070328f	body	Demo #10 of the compiler stress-test battery: the many-multiply member. A sum\nof rotating vectors P(t) = Σ c_k·exp(i·2π·f_k·t) traces a baked outline; the\nhot loop is a sin/cos-LUT sweep with FOUR 16×16→32 multiplies per harmonic\n(the complex multiply re·cos−im·sin / re·sin+im·cos) + 32-bit accumulation —\n__mulsi3-dense and divide-free, a distinct profile from the divide-bound\nspirograph (#11) and n-body (#13).\n\nShared examples/65816/epicycles.h drives the host oracle, corpus slice, and ROM.\nCoefficients are the DFT of a 5-pointed star (tools/gen-epicycles-tables.py),\nordered by magnitude; the star is rotated ~23° off-vertical so both re and im\nare non-zero — a symmetric star gives purely-imaginary c_k and folds the\nreal-part multiplies to ×0, halving the intended stress. 8 harmonics.\n\nGate epi_gate_crc = 0x4F6C (32 points spanning the full period). No far pointers\n⇒ full 5-way bar. Verified: dev/run.sh epicycles RESULT PASS (disasm __mulsi3=4\n+ rep/sep=28, divide=0; bsnes-jg host==default==+mos-a16==+mos-xy16 == 0x4F6C;\n-verify-machineinstrs clean all three; UBSan clean). The on-screen star draws\nitself over its dim generating circle (BitmapCanvas bloom + scaffold). MAME leg\npending the SPC700 IPL (bsnes-jg + browser carry the demo bar).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
