# #126 — Split-Personality Link (`mixedwidth`)

**Status:** DONE + PUBLISHED 2026-08-03 — clean positive, no compiler defect found. Round 7 compiler-probe ROM.

## Question

Can one translation unit safely call between functions with different 65816 target features, or is
the `target` attribute unsupported or ignored? This is the first battery entry to mix width features
per function instead of applying one feature set to the whole program.

## Shape

`mw_default_bridge` repeatedly calls an explicitly `target("mos-a16")` arithmetic function and then
an explicitly `target("no-mos-a16,no-mos-xy16")` byte function. This tests both directions of the
M8 ABI boundary even when the comparison ROM itself is built globally with a16 or xy16 enabled.
The host model executes the same 192-step call-ping-pong chain and folds every result into a CRC.

The visual splits narrow blue A8 byte stripes from broad magenta A16 word bands. Two yellow packets
travel in opposite directions across their central call boundary; the CRC remains live in the HUD.

## Gates

- IR contains `+mos-a16` on `mw_native` and `-mos-a16,-mos-xy16` on `mw_byte`.
- Object disassembly shows `rep #$20` / `sep #$20` in `mw_native`.
- The forced-default `mw_byte` body contains no `rep` or `sep`.
- All target builds use `-verify-machineinstrs`.
- bsnes-jg reads `corpus_result` after 300 frames.

## Result

Host, default, a16, and xy16 all return `0x83B7`. The target attribute is supported, feature state
is function-local, and the ordinary M8/X8 call/return contract safely joins the differently featured
functions. No compiler fix or patch update was needed.

Run with `dev/run.sh mixedwidth`.

## Published demos

- <https://biohack.net/snes/mixedwidth/>
- <https://indri.studio/apps/llvm-mos-65816/snes/mixedwidth/>

Both sites serve visual republish ROM SHA-256
`1746cca920e932bdbf1bc239e3355352bd4c437dbcb72baa6cbd616e40a45463`.
Visual republish commits/releases: biohack.net `6f05515` / `v1.0.368`, indri.studio `061b749` /
`v0.1.138`.
