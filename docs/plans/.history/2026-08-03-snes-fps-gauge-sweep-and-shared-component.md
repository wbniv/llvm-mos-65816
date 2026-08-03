| Date | Change |
|------|--------|
| [2026-08-03](https://github.com/wbniv/llvm-mos-65816/commit/9ab0eb7) | docs(plan): FPS gauge sweep + extract it to one shared component |

<!--history-meta v1
9ab0eb7	author	Will Norris
9ab0eb7	added	135
9ab0eb7	deleted	0
9ab0eb7	files	1
9ab0eb7	body	Follow-on from the live 59.1/60.1 defect. The sweep is done and recorded in the\nplan, because it changes the scope: only two ROMs draw a gauge, and the reel's\nis correct only by an accident of call placement — it samples one VBlank early\nAND one present early, so two off-by-ones cancel. Apollo was copied from it,\nmoved the call after the deadline wait for a good and unrelated reason, and the\ncancellation silently broke. Both readings were captured from the running\nconsoles as the before-baseline rather than reasoned about.\n\nSecond finding: no gate has ever asserted the displayed number. fps_tenths is\nexported by the reel and read by nothing, which is why a wrong gauge reached a\npublished page and was found by a human watching it.\n\nPlan proposes examples/snes/video_fps.h (header-only static inline, matching\nvideo_hud.h), "sample AFTER the present" as the explicit contract, and a gate\nstep in both scripts that reads dashboard_fps out of WRAM. Mockup bundle shows\nthe four HUD states including the two wrong ones.\n\nTODO item is deliberately unranked: the ranking hook denies a tier marker from\nanyone but Fable. Suggested tier is stated in prose for the orchestrator.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
