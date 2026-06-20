| Date | Change |
|------|--------|
| [2026-06-21](https://github.com/wbniv/llvm-mos-65816/commit/ac4a0c6) | #321 plan: bank ordering-as-value branchless win via 16-bit materialization |

<!--history-meta v1
ac4a0c6	author	Will Norris
ac4a0c6	added	104
ac4a0c6	deleted	0
ac4a0c6	files	1
ac4a0c6	body	The v1 8-bit adc-tail churned rep/sep in the common 16-bit-ambient case (closed\nnet-negative). Plan the RIGHT form: a 16-bit (mode-matched) materialization\n(ROLAcc16 lda #0; rol, or ADCImm16) that stays in the M16 run -> no churn -> banks\nthe win where a16 actually runs (mostly-16-bit). Also sharpen the modest-gains\nmemory: any gain is a PRIORITY, never go/no-go; if the naive impl regresses build\nthe clean form, dont shelve the gain (user 2026-06-21).\n\nCo-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
-->
