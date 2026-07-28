| Date | Change |
|------|--------|
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/69fe2db) | Add SNES display quality enforcement |
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/a326ae5) | docs(plan #128): OAM budget proven, not assumed — 11-sprite worst case |
| [2026-07-27](https://github.com/wbniv/llvm-mos-65816/commit/d4471a4) | docs(plan): #128 gravity-chevrons — review pass + TODO entry |

<!--history-meta v1
69fe2db	author	Will Norris
69fe2db	added	57
69fe2db	deleted	78
69fe2db	files	1
a326ae5	author	Will Norris
a326ae5	added	17
a326ae5	deleted	4
a326ae5	files	1
a326ae5	body	User amendment: replace the review pass's "worst case can exceed 16\nsprites" claim with the actual projection arithmetic — 18-px max match x\nmin matrix_scale 152 = 31 screen px = <=4 rail tiles, <=1 row crossing,\nso source <=5 + destination <=5 + packet 1 = 11 <= 16 for the whole\n26-work corpus (verified against lzss-gallery-assets.h: scale min 152,\nwidth min 88). The degradation order is retained as future-proofing with\na new invariant: compute the sprite count before staging, never discover\noverflow by partially filling OAM. Verification split accordingly: real\nassets must fit outright; the degradation path is exercised by a\ndeliberately synthetic future-format span (the old "forced worst case"\ntest was unreachable with real codec output).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
d4471a4	author	Will Norris
d4471a4	added	376
d4471a4	deleted	0
d4471a4	files	1
d4471a4	body	Commits the #128 plan (transparent 3D gravity chevrons + continuous-bracket\nrepack tracker) with review corrections applied:\n\n- Gate facts were stale: the corpus is 26 works and the oracle is the\n  GENERATED GALLERY_CORPUS_ORACLE (currently 0x3D44, recomputed from\n  report.json by dev/lzss-gallery.sh) — the draft said "20-artwork /\n  0xB5D7", both wrong; verification now forbids hardcoding the literal.\n- Sign contradiction fixed: the tuning table listed "upward impulse\n  -0x00C0" while the pseudocode negated it again; contract is now\n  velocity := -TAKEOFF (TAKEOFF = 0x00C0) with the displacement/ground\n  convention made explicit (the 24-frame / 4.5 px math closes).\n- NEW pre-existing bug found auditing load_chevrons()/palette() against\n  the plan: the reserved OBJ colors land at CGRAM 132=0, 133=accent,\n  134=white while every plane-2 tile assumes idx4=accent — today's\n  destination outline and "bright" literal diamond render BLACK. The\n  plan now carries the audit + the contract fix (132=accent, 133=white)\n  and a red/green CGRAM verification step.\n- Packet motion was underspecified against the real redraw cadence\n  (oam_compression fires per 256 input bytes, and newest-event-wins\n  would retarget every hook): added the flight latch/clock rules.\n- Pinned the OAM budget (16 sprites, degradation order: source rails,\n  then source; never destination/packet), tile budget (10 poses = 40\n  tiles + 5 bracket tiles), pose↔glow one-to-one mapping (kills a\n  poses×glow tile-set explosion misread), CGRAM ownership >133 (not\n  "144-159"), direction-switch arrow restore, and nav_target physics\n  seeding. Verification now names the #124 JGX_NAV/JGX_SCRIPT harness.\n\nTODO: filed under the demo battery as T3 (multi-file vs a settled plan).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
