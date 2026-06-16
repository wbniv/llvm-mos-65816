| Date | Change |
|------|--------|
| [2026-06-16](https://github.com/wbniv/llvm-mos-65816/commit/d6e07b0) | #321 docs: plan the indirect-s16-load-byte-wise follow-up |

<!--history-meta v1
d6e07b0	author	Will Norris
d6e07b0	added	73
d6e07b0	deleted	0
d6e07b0	files	1
d6e07b0	body	The byte-wise-load fix (7c0fe56) gates only the absolute s16 load; the indirect\nload (G_LOAD16_INDIR) consumed only by G_UNMERGE still round-trips through A16.\nWrite a dedicated plan: the same AllUsesUnmerge guard applies structurally, but —\nunlike the absolute case (two plain `lda abs`) — the byte-wise indirect form is\ntwo `lda (zp),y` and may not beat the native `lda (zp)` + spill, so the plan is\ninvestigation-gated (measure first; skip if it's a wash) and low priority. Point\nthe M2 TODO bullet at it.\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
