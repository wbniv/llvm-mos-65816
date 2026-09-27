| Date | Change |
|------|--------|
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/624f4006) | Preserve separate BRK and COP discovery links in the canonical registry |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/489b62df) | Publish near-decoder simulated PR and discovery metadata |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/7894c870) | docs(snes): add discovery-map screenshots |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/afec07f0) | docs(snes): restore compiler-bug map automation |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/9995d9b2) | Revert "docs(snes): automate compiler-bug map updates" |
| [2026-09-27](https://github.com/wbniv/llvm-mos-65816/commit/de844568) | docs(snes): automate compiler-bug map updates |

<!--history-meta v1
624f4006	author	Will Norris
624f4006	added	3
624f4006	deleted	1
624f4006	files	1
624f4006	body	Reconcile biohack commit 458290e with the published gallery follow-up. Associate BRK with PR 586, COP with PR 588, and QSort only with PR 577. Regenerate the discovery map and public export, review dependent summaries, and refresh the document inventory.\n\nValidation: live GitHub PR 586 identity checked; gallery dates, per-defect links, website registry hash, tests, and 166-page production build verified.\n\nAI assistance: OpenAI Codex CLI 0.157.1 (codex-tui), model gpt-6-astra, xhigh reasoning effort; verified session 01a0e061-3427-74a1-90ad-c0ee84b01b85.
489b62df	author	Will Norris
489b62df	added	8
489b62df	deleted	0
489b62df	files	1
489b62df	body	Add an internal review packet for the committed Y-lifetime and near-address\nbank-wrap repairs, retaining the native-width extraction and independent\nreview gates. Link the packet from the investigation and feature-held ledger.\n\nReconcile the website's PR-status and per-defect records into the canonical\ngallery registry. Keep the earlier PRs and simulations, and give the two new\nmechanisms their own September 25/27 dates, evidence, and unposted state.\nRender and validate each defect's date and PR/simulation association, and\nrefresh the public exports and reviewed documentation dependencies.\n\nValidation: generated gallery rows retain the correct four mechanisms and\nassociations. The matching website copy passes 47 tests with one existing\nskip and builds 166 pages; built desktop/mobile views show the new packet\nand dates. GitHub API confirmed recorded states of PRs 577/578/584/588/590.\n\nPreparation and validation: OpenAI Codex CLI 0.157.1 (codex-tui), model\ngpt-6-astra, xhigh reasoning effort; verified session\n01a0e061-3427-74a1-90ad-c0ee84b01b85. Earlier attribution is preserved.
7894c870	author	Will Norris
7894c870	added	10
7894c870	deleted	0
7894c870	files	1
afec07f0	author	Will Norris
afec07f0	added	102
afec07f0	deleted	0
afec07f0	files	1
9995d9b2	author	Will Norris
9995d9b2	added	0
9995d9b2	deleted	102
9995d9b2	files	1
9995d9b2	body	This reverts commit de84456857b7d89d4b6e8923c9f6f536bd8ea6b9.
de844568	author	Will Norris
de844568	added	102
de844568	deleted	0
de844568	files	1
-->
