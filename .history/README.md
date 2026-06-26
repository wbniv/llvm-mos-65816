| Date | Change |
|------|--------|
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/5a424df) | docs(roadmap,readme): record the trig differential test as the M2 capstone |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/56f5d80) | docs: record scavenger-fix verification + sweep "deferred scavenger" framing (0011/0012) |
| [2026-06-26](https://github.com/wbniv/llvm-mos-65816/commit/db83872) | docs(README): refresh M2 status — s32 + xy16 landed; remaining is opt refinements + deferred-upstream crashes |
| [2026-06-25](https://github.com/wbniv/llvm-mos-65816/commit/b968ae8) | docs(README): add Downloads section for the interim cross-platform packages |
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/6efabde) | #320 (a) far fn pointers fully done — sync status docs (impl-status, ROADMAP, README, plans) |
| [2026-06-19](https://github.com/wbniv/llvm-mos-65816/commit/181af86) | repo: Apache-2.0 LICENSE + NOTICE, README → M2 status, gitignore transcripts |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/93862b3) | M1 Phase 0: build llvm-mos from source (lean) + green baseline |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/c50a39c) | M0: regression corpus (6 programs) + generalized harness |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/025be2f) | M0: add clean-room repro gate; park CI to manual-only |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/18189b6) | docs: record M0 emulator-run PASS (MAME smoke) in ROADMAP + README |
| [2026-06-14](https://github.com/wbniv/llvm-mos-65816/commit/982b6f3) | M0: implement headless MAME smoke loop (dev/run.sh smoke) |
| [2026-06-13](https://github.com/wbniv/llvm-mos-65816/commit/2fb154f) | Initial commit: llvm-mos 65816 effort + SNES platform (M0) |

<!--history-meta v1
5a424df	author	Will Norris
5a424df	added	6
5a424df	deleted	0
5a424df	files	1
5a424df	body	The trig compiler-test (all 3 phases, both fixed-point widths) is now complete and\nlanded; reflect it in the milestone-narrative docs:\n- ROADMAP step 5 (M2): a capstone paragraph — Phase 1 (Q16.16 libfixmath, s32-libcall\n  payload + the HiROM sin-LUT that fixed a clang far-index bug in 0001), Phase 2 (Q2.14\n  CORDIC direct, zero-libcall native-s16), Phase 3 (derived + CORDIC hyperbolic).\n- README M2 status: a sentence noting the trig workload as the realistic capstone\n  (k_trig32/k_trig16/k_trig16x, both emulators, cross-width accuracy).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
56f5d80	author	Will Norris
56f5d80	added	6
56f5d80	deleted	4
56f5d80	files	1
56f5d80	body	Plan 2026-06-26-321-scavenger-nz-live-p-save-fix: flip status to DONE and paste\nthe raw verification evidence (PASS/FAIL) under each of the 8 numbered steps —\nrelease + asserts repro clean, 121/121 differential fuzz incl. the formerly-XFAIL\n169/173/196, corpus 7/7, a16sub gate, torture 58/0-fail, known-issues 0/0,\n0011/0012 round-trip.\n\nSweep the docs that still described the register-scavenger crash as a deferred,\nupstream-territory, no-fork-patch XFAIL — now that it is FIXED (0011) and the\nLDCImm MC-lowering bug it surfaced is FIXED (0012):\n- README: "two deferred RA/scavenger crashes" -> one (the pr15296 ZP-overflow);\n  ten-patch -> twelve-patch series.\n- ROADMAP §5 + TODO (deferred-core equivalence, the "two pathological XFAILs"\n  Watch item, the next-instrument item): the scavenger-N/Z crash had an\n  orthogonal targeted fix (0011), like globals.c did (0009) — it left the\n  deferred residency core; only the ZP-overflow XFAIL remains.\n- review guide: new §3.11 (0011) + §3.12 (0012) deep-dives; fix §3.9's stale\n  "scavenger XFAIL stays" line.\n- upstream-contribution-status: summary-table row 4 -> fix PR, add row 10 (0012).\n- plan-index: annotate the superseded scavenger-spike / pressure-handoff rows.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
db83872	author	Will Norris
db83872	added	14
db83872	deleted	7
db83872	files	1
db83872	body	The M2 line claimed "in progress: s32; XY16" but both have since landed and are differential-verified\n(s32 micro-test + fuzzer track 2026-06-23; xy16 seeds 247/445 + Track-A hardening + CC boundary). M2's\nacceptance (ROADMAP: correct REP/SEP 16-bit codegen, smaller/faster, corpus green) is met. Remaining is\nincremental optimization refinements + two deferred upstream-territory RA/scavenger crashes (XFAIL'd) —\nNOT the Blossom demo or Yarpgen (those are a payoff showcase + test tooling, not M2 acceptance). Notes\nthe new default-8bit coalescer fix (0010) and that the ten-patch series isn't upstreamed yet.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
b968ae8	author	Will Norris
b968ae8	added	31
b968ae8	deleted	0
b968ae8	files	1
b968ae8	body	Document the three interim preview packages (linux-x86_64 published via\napt.indri.studio; linux-arm64 + windows-x86_64 built locally via task\ncross-build / package-all), the relocatable mos-clang --config invocation,\nand the Windows caveat (wine can't run the binary -> verify on real Windows\nbefore relying on the .zip; per-platform drivers not shipped; keep the DLLs).\nmacOS arm64 noted as deferred. Retires once #320/#321 land upstream.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>\nClaude-Session: https://claude.ai/code/session_013BoyGYjYmgXqoUoMoG8Wan
6efabde	author	Will Norris
6efabde	added	6
6efabde	deleted	2
6efabde	files	1
6efabde	body	Bring the tracking docs current now that #320 (a) far function pointers is fully\nclosed (backend + clang F2 `far`/`long_call` attribute + typed `far_fn_t`\nvariable + sizeof(far*)==4, + a pre-existing far_indir crash fix; verified both\nemulators, pushed origin/wt/320-far-followups):\n\n- implementation-status.md: TL;DR, the far-fn-ptr table row, the M1 verdict, the\n  pending-codegen row, and What's-next #2 all flipped from "BACKEND DONE / only\n  F2 remains" to DONE.\n- ROADMAP.md: mixed-banking + far function pointers marked DONE; only the\n  far-pointer calling convention (0004) remains.\n- README.md: M1 far-pointers line updated (was "far calls deferred pending ABI\n  blessing" — stale; far calls + far fn pointers are done).\n- 2026-06-21-320-far-calls-followups.md: §7 resume + §9 commit trail updated;\n  struck the §0 historical "ONLY remaining piece is F2".\n- Co-located the typed-far_fn_t-variable + far-pointer-sizeof plans on main (they\n  were committed on wt/320-far-followups) so the status-doc cross-links resolve.\n\nAdversarial staleness audit (3-agent workflow) drove these fixes — final grep\nclean, all plan links resolve.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
181af86	author	Will Norris
181af86	added	16
181af86	deleted	12
181af86	files	1
181af86	body	- Add LICENSE (Apache-2.0) and NOTICE (derivative-of-llvm-mos attribution)\n  so the public fork has a clear license matching upstream\n- Refresh README Status from stale "M0 in progress" to accurate M2 snapshot:\n  M0 complete, M1 substantially complete, M2 +mos-a16 working with in-progress\n  s32/XY16 callouts\n- Gitignore docs/transcripts/ to eliminate accidental-commit risk\n- TODO + plan entry for this housekeeping item\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
93862b3	author	Will Norris
93862b3	added	15
93862b3	deleted	0
93862b3	files	1
93862b3	body	Codegen work (M1 #320) can't begin on the prebuilt, immutable toolchain.\nThis stands up a from-source llvm-mos build in the dev container and proves\nthe regression corpus stays green on the self-built compiler.\n\n- dev/toolchain.sh: clone llvm-mos, build clang/lld via the MOS.cmake cache\n  (Release, lld, 1 link job, ccache) -> build/llvm-mos-install. Trims the\n  distribution to clang+lld (idempotent sed drop of clang-tools-extra:\n  clangd/clang-tidy/include-fixer/...), cutting a cold build 39.2 -> 26.1 min.\n- dev/Dockerfile: host clang/lld/ccache (+zlib) to build LLVM; lld + Release\n  keep peak link memory under the 14 GiB host ceiling.\n- dev/build.sh: MOS_TOOLCHAIN selects the toolchain (default prebuilt). CMake\n  can't hot-swap the cross-compiler, so wipe the SDK build tree (only) when\n  MOS_TOOLCHAIN changes, tracked via build/.mos-toolchain.\n- dev/run.sh: `toolchain` target; forward MOS_TOOLCHAIN/BUILD_JOBS.\n\nVerification (2026-06-14): toolchain builds (clang 23.0.0git @ c798c31,\nTarget: mos); MOS_TOOLCHAIN=...llvm-mos-install build+corpus -> 7/7 (byte-\nidentical to prebuilt: same builtins.a, same expected values); default\nprebuilt path round-trips green (self-built<->prebuilt wipe verified both\nways). The self-built compiler is byte-equivalent to the prebuilt — only\nnow it's one we can edit for #320.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
c50a39c	author	Will Norris
c50a39c	added	19
c50a39c	deleted	9
c50a39c	files	1
c50a39c	body	ROADMAP step 2. Turns the one-program liveness bench into a correctness\nbaseline: 6 self-contained C programs each compute a result the host checks\nagainst a manifest, exercising a distinct slice of codegen. This is the\nregression net for when M1/M2 rewrite codegen — same source, same bytes.\n\n- examples/snes/corpus/{arith,control,arrays,structs,funcs,globals}.c — ALU,\n  control flow, arrays+.rodata, structs+pointers, calls+recursion, and the\n  crt0 .data/.bss init. Inputs are volatile to defeat -Os constant-folding;\n  each writes volatile uint16_t corpus_result. expected.tsv is the manifest.\n- dev/_emu.sh: shared run_assert — derives a symbol's WRAM address AND byte\n  length from the linker map (Size column), boots MAME headless, asserts.\n- dev/smoke.lua: SMOKE_LEN — read N bytes little-endian (default 1).\n- dev/smoke.sh: refactored onto _emu.sh (identical behavior).\n- dev/corpus.sh + run.sh `corpus` target: assert every manifest row, N/N table.\n- dev/build.sh: build every examples/snes/**/*.c, not just hello.\n- dev/run.sh: forward SMOKE_WANT/SMOKE_SETTLE/SNES_ROMPATH into the container\n  (so the documented overrides + negative control work via the entrypoint).\n- repro.sh + smoke.yml: run corpus (subsumes the hello liveness row).\n\nVerification (2026-06-14): dev/run.sh corpus -> 7/7 PASS\n(arith 0xA9E9, control 0x1DFB, arrays 0x03E1, structs 0x0340, funcs 0x011E,\nglobals 0xAB55, hello 0x42 — every hand-computed expected matched). Negative\ncontrol (corrupt one expected) -> that row FAIL, 6/7, exit 1. repro + CI below.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
025be2f	author	Will Norris
025be2f	added	8
025be2f	deleted	1
025be2f	files	1
025be2f	body	For a solo private repo, the routine reproducibility gate is local, not\nGitHub minutes + a per-push ROM upload. CI's unique value (from-scratch\nreproducibility) isn't GitHub-specific — it's "fresh checkout, no machine\nstate", which a local script delivers.\n\n- dev/repro.sh (host-side): git archive HEAD -> temp dir (committed files\n  only, no build/ or caches), supply the gitignored SPC700 IPL, then\n  run.sh build + run.sh smoke there. Proven green: "repro OK".\n- dev/run.sh: route `repro` host-side (not an in-container target).\n- .github/workflows/smoke.yml: triggers -> workflow_dispatch only. Proven\n  green once on a clean GH runner (run 27475012894, smoke step executed\n  with BIOS from secret); re-enable push/pull_request when public/upstream\n  or collaborators arrive.\n- README/plan: document repro + the manual-CI decision. Plan verification\n  step 5 (reproducible from clean checkout) -> PASS (both CI + local).\n- TODO: smoke loop -> Done (all 5 steps green); section structure refresh.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
18189b6	author	Will Norris
18189b6	added	4
18189b6	deleted	1
18189b6	files	1
18189b6	body	The smoke loop is implemented and green locally, so the docs that still\ndescribed the emulator-run half as "pending" are now stale.\n\n- ROADMAP step 1: Emulator-run half PASS (2026-06-14, MAME 0.285) with the\n  SMOKE: PASS + negative-control evidence; only the CI run remains (BIOS\n  secret). Cross-links the smoke loop plan.\n- README Status: "And it runs" — dev/run.sh smoke boots the ROM in MAME and\n  reads sentinel==0x42 back from WRAM.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
982b6f3	author	Will Norris
982b6f3	added	12
982b6f3	deleted	0
982b6f3	files	1
982b6f3	body	Boots build/hello.sfc in MAME's snes driver headless and asserts the\nsentinel==0x42 byte in WRAM ($7E0020), closing the run-half of ROADMAP\nverification step 1. Same emulation core drmon debugs against.\n\n- dev/Dockerfile: add mame (own layer after the toolchain so a version\n  bump never re-downloads the toolchain); PATH += /usr/games (Debian\n  installs the binary there, off the default non-login PATH).\n- dev/smoke.lua: clean-room autoboot script (no GPL drmon code) — counts\n  frames, reads the WRAM byte via maincpu program space, prints SMOKE:\n  PASS/FAIL, exits. Verdict travels on stdout (MAME can't set exit code).\n- dev/smoke.sh: BIOS preflight (exit 2 if missing), derive sentinel addr\n  from hello.map, run MAME headless with -rompath/-skip_gameinfo, exit 0\n  iff SMOKE: PASS.\n- .github/workflows/smoke.yml: build + smoke; materializes the SPC700 IPL\n  from the SNES_SPC700_ROM_B64 secret, gates the smoke step on it.\n- .gitignore: /dev/roms/ — the SPC700 IPL is Nintendo content, supplied\n  out-of-band, never committed (mirrors drdevtools' roms/ pattern).\n\nVerification (2026-06-14): MAME 0.285; clean dev/run.sh smoke -> SMOKE:\nPASS exit 0; negative control (SMOKE_WANT=0x99) -> SMOKE: FAIL exit 1;\nmame -verifyroms snes -> "romset snes is good". CI (step 5) pending the\nrepo secret + push. Evidence pasted into the plan.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
2fb154f	author	Will Norris
2fb154f	added	68
2fb154f	deleted	0
2fb154f	files	1
2fb154f	body	Standalone home for bringing an optimizing open-source C compiler to the WDC\n65816 via llvm-mos, with SNES as the first platform.\n\n- platforms/snes/: SNES LoROM SDK platform (crt0, header, link.ld, snes.h,\n  clang.cfg) — builds a valid bootable 32 KiB .sfc from C on the existing 6502\n  backend (65816 boots in emulation mode). PR material for llvm-mos-sdk#415.\n- dev/: containerized build env (Ubuntu 26.04 + pinned llvm-mos toolchain);\n  build.sh vendors upstream llvm-mos-sdk and injects our platform(s), run.sh\n  drives it from the host. Host stays clean.\n- examples/snes/hello.c, tools/snes-checksum.py.\n- docs/ROADMAP.md (M0 SNES bench -> M1 #320 far pointers -> M2 #321 16-bit regs),\n  docs/INVESTIGATION.md (upstream status + contribution rationale).\n\nVerified: dev/run.sh build produces a structurally valid bootable ROM\n(reset $FFFC -> _start, boot path is the crt0, main() compiled, checksum ok).
-->
