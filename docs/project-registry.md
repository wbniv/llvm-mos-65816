# Registry references in retained evidence

The frozen [initial patch-roundtrip log](defects/evidence/2026-09-26-mos-carry-scheduling/carry-patch-roundtrip.log)
and [successful retry log](defects/evidence/2026-09-26-mos-carry-scheduling/carry-patch-roundtrip-retry.log)
include output from the shared Git hook's registry-writer audit. Its
`projects.json writer manifest` message refers to the shared environment audit.
The carry-scheduling patch and evidence publication add no registry access.
The shared registry's [canonical contract](https://github.com/wbniv/homedir/blob/main/docs/projects-json.md)
documents that infrastructure.

Documentation: OpenAI Codex CLI 0.157.1 (`codex-tui`), model `gpt-6-astra`, `xhigh` reasoning effort; verified session `01a0dd01-d72e-76f2-bf27-a796e0f7d994`.
