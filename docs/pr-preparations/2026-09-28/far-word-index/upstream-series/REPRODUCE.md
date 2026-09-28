# Reproduce the extracted compiler checks

Preparation: OpenAI Codex CLI 0.157.1 (session source `vscode`), model `gpt-6-astra`, `xhigh` reasoning effort; session `01a0e67f-298f-7a21-80af-06f867085f84`.

## Source reconstruction and LLVM regressions

Prerequisites: Git, CMake, Ninja, a supported C++ compiler, Python and the usual LLVM build dependencies. `series.json` pins the base, patch order, hashes, and every resulting Git tree. From this packet directory, first inspect the manifest. Point `packet` at its absolute directory, then use a clean clone:

```sh
git clone https://github.com/llvm-mos/llvm-mos.git llvm-mos-review
cd llvm-mos-review
git checkout --detach 26d7c2c1eebf98ca194b92609ba4e7540bfc6ef6
git am "$packet"/patches/*.patch
cmake -S llvm -B build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_ASSERTIONS=ON -DLLVM_TARGETS_TO_BUILD='MOS;X86'
cmake --build build --target llc llvm-mc FileCheck llvm-objdump llvm-size opt -j4
build/bin/llvm-lit -v llvm/test/CodeGen/MOS llvm/test/MC/MOS \
  llvm/test/CodeGen/X86/virtregrewriter-x86-copy-contracts.mir \
  llvm/test/CodeGen/X86/virtregrewriter-x86-undef-high-byte-result.mir
```

The `git am` commit IDs can differ because committer metadata changes. Compare trees with the manifest. The local reconstruction check applies each patch to a separate Git index with whitespace errors rejected, and verifies every intermediate tree.

The native foundation reuses the independently prepared 0065 extraction, with its extra EOF blank line removed; no 0065 near-store profitability policy is included. The final packaged source tree was rebuilt after the EOF cleanup and a four-line comment rewrite; the resulting llc is byte-identical to the tested candidate (see `validation/comment-polish.json`). Original and final source identities are retained. The pre-0070 binary is from the same prerequisites; its source differs from the corresponding packaged tree only by that EOF blank line and comment wording.

## Sensitivity checks

`check-sensitivity.py` expects the recorded project layout: compiler source at `build/far-word-upstream/source`, candidate `llc` at `build/far-word-upstream/candidate/llc`, and `FileCheck` at `build/far-word-upstream/build/bin/FileCheck`. Place your rebuilt tools there or adapt those path variables, then run:

```sh
python3 "$packet/check-sensitivity.py" --root /absolute/path/to/llvm-mos-65816
```

It generates fresh outputs, runs FileCheck positively, then changes exactly one opcode token for each negative case. Expected result: six positive outputs pass and 228 wrong substitutions fail with FileCheck status 1. The mutated text is an assertion-sensitivity input, not valid executable MIR.

## Frozen-IR backend/runtime replay

`runtime.py` records its exact commands and returns an error for any compiler, execution-oracle, or repeat-profile disagreement. It compiles the retained post-LTO inputs with separate pre-0070 and candidate backends. `-disable-spill-hoist` is explicit in both, matching the existing driver setting. The known 0033 hoisting issue is outside this series. 0028 fixes a different identity-copy contract and is included.

The frozen post-LTO bitcode is the authoritative replay input. The source archive also includes `hopalong.h` recovered from the original recorded project revision `dfdf05ff66ea2f19c31052306841926b88f67889`; this is a Git reconstruction, not a separately captured preprocessed source. Its bytes match the current tracked header.

Restore the archived input paths under a project checkout and provide the pinned existing frontend/linker, SDK, table assembly, MAME, and calibrated `jgxcycles-verified` probe identified in the validation receipts. The runner uses those existing components only to link and execute the extracted backend's fixture objects. Binaries are retained locally and identified by hashes; rebuilding the LLVM backend alone does not reconstruct this complete SDK/emulator environment.

```sh
python3 "$packet/runtime.py" --root /absolute/path/to/llvm-mos-65816
```

Use a fresh `build/far-word-upstream/runtime` output directory for a new run so the retained evidence is not overwritten. Farblit/boundary inputs use the existing HiROM table; pressure uses the existing LoROM configuration. Three fixtures × two feature modes × three optimization levels × three variants give 54 configurations; baseline/default Farblit at O3 adds four. Each runs MAME once and the calibrated bsnes probe twice.

The emitted ROM hash identifies the actual executed program. A separate relink against the captured SDK inputs checks linkage reproducibility. No SNES implementation or platform configuration is part of the proposed compiler patches. The existing published demos are supporting context, not freshly rebuilt measurements of this series.

## Retained intermediate failures

The archive also retains the initial missing-native-cost failure, missing-0018 spill assertion, missing-0028 undefined-lane failure, spill-hoist abort, and the broader A8 bridge limitation. 0040 was tried when distinguishing the scratch-register symptom, did not repair the hoisting issue, and is excluded from the final series. These are diagnostic attempts, not passes in the final matrix. The new native-cost record preserves matching-input red/green evidence and the exact original compiler identities.
