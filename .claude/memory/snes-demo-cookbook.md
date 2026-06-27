---
name: snes-demo-cookbook
description: SNES demo recipe lives at docs/snes-demo-cookbook.md; agent skill at ~/.claude/skills/snes-demo/SKILL.md — read before implementing any new SNES ROM in the compiler stress-test battery
metadata: 
  node_type: memory
  type: reference
  originSessionId: a42b2683-b2fe-4b03-8e81-c6173961180a
---

The full recipe for building and publishing a new compiler stress-test SNES demo is
`docs/snes-demo-cookbook.md` (project-relative). The matching agent skill is
`~/.claude/skills/snes-demo/SKILL.md`, triggered when the user says "implement #N" or
"build the X demo".

**Why:** captures the 6-artifact pattern (algorithm header, SNES ROM, corpus slice, host oracle,
gate script, Taskfile entry), the V-blank DMA budget math, snesgfx component guide, CGRAM
palette programming, 5-way vs 3-way bar decision, and the plan-doc template — so a fresh agent
does not have to rediscover any of it.

**Key reference demos (newest first):**
- `examples/snes/spigot.c` + `examples/65816/pi_spigot.h` — canonical template; carry-chain div/mod + 16×16→32 mul
- `examples/snes/spirograph.c` + `examples/65816/spiro.h` — sin/cos LUT + mul; BitmapCanvas + TextLayer
