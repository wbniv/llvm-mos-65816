---
name: md-to-html-latex-math
description: "docs previewed via `task md` can now typeset real LaTeX math (```math / $`...`$)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: f54530f3-eece-499c-8d0d-41444818e449
---

The shared `task md` pipeline (`../python-tui-lib/scripts/md-to-html.sh`) now
typesets LaTeX math to self-contained inline SVG. Added 2026-06-26 (python-tui-lib
commit `8d8eac6`); renderer is `scripts/md_math.py` (matplotlib **mathtext**).

Syntax (GitHub-portable):
- ` ```math ` fenced block → centered **display** equation
- `` $`...`$ `` (backtick-guarded) → **inline**, baseline-aligned
- Bare `$...$` is intentionally **NOT** a delimiter — it collides with the
  `$420B` / `$5.99` tokens these docs are full of.

mathtext is a LaTeX *subset*: `\sqrt \frac` super/subscripts Greek `\mathrm
\operatorname \cdot \left|...\right| \sum \int` and `\,/\;/\quad/\qquad` work;
`\lvert`/`\rvert` and alignment environments do **not** → on a parse failure (or
missing matplotlib) it degrades to a red box with the raw LaTeX, never a crash.

The blossom hopalong attractor reads, typeset:
`x' = y - \operatorname{sign}(x)\cdot\sqrt{\left|b\cdot x - c\right|},\quad y' = a - x`
(applied in `docs/plans/2026-06-24-3-snes-blossom-on-screen-interactive-hopalong-attr.md`).

Output is deterministic (fixed `svg.hashsalt`, stripped timestamp) and offline —
no network, no font files, mirrors the mermaid embed model. Self-contained for
print-to-PDF.
