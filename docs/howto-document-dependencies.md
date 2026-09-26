# Keep dependent documents consistent

Use [the document inventory](document-dependencies.md) to find repository documents
and [the dependency manifest](document-dependencies.json) for declared source and
derivative relationships. This covers the documentation as a whole, including
plans, investigations, PR drafts, reviews, summaries, and generated browser views.
The inventory discovers Markdown and reStructuredText throughout the Git file
set, and HTML/JSON documents under `docs`. Untracked, non-ignored documents are
included in worktree mode. Vendored code, raw transcripts, frozen evidence, and
editor history are excluded from prose discovery but remain valid link targets.

Implementation and initial inventory: OpenAI Codex CLI 0.157.0 (`codex-tui`),
model `gpt-6-astra`, `xhigh` reasoning effort; session metadata verified for this
work. Existing documents retain their own authorship and evidence dates.

## What the relationships mean

- **Generated:** an explicit source list, generator command, and hashes of the
  exact source/output bytes. Source or output changes require regeneration.
  Local browser copies are listed alongside their tracked counterparts.
- **Maintained:** a current summary with declared inputs and a review receipt.
  A source change requires checking the summary, correcting it where necessary,
  and recording what was reviewed. A fixed compiler defect does not imply a
  published PR or a completed independent review.
- **Reference:** an automatically discovered Markdown, HTML, or structured-record
  link. It identifies possible impact, not a claim that the referring document
  derives every statement from that source or has been audited for freshness.
- **Dated record:** a document in a dated record path. Preserve the original
  evidence and attribution. Decide whether a qualification, follow-up, or current
  summary needs updating; do not rewrite a captured baseline to match today.

Reference links can be circular. Explicit derivation cycles are rejected. Broken
historical reference links are not silently treated as verified dependencies;
only declared inputs are required to exist by the blocking check. Link discovery
does not infer dependencies from unlinked prose or prove that a document's claims
are correct. Register known semantic dependencies explicitly.

## Workflow for every document change

1. Inspect the incoming references before finishing a change:

   ```sh
   python3 dev/docs-deps.py --impact docs/defects/selectiondag-inline-asm-register-bounds.json
   ```

   The report follows dependencies transitively and names the source through
   which each document is affected. Review current summaries, previews, plans,
   and follow-up records as appropriate; do not assume all references need edits.
   Add `--direct` to inspect immediate dependents first.

2. Register new generated documents in `generated`, including every input that
   can change the output (templates and renderer code included). Register current
   summaries in `maintained` with their semantic inputs. `sources` supports paths
   and globs; a `{ "glob": ..., "fields": [...] }` selector fingerprints only the
   listed JSON fields, such as a defect's status and identified fix. New matching
   files also invalidate the receipt.

3. Update the affected prose, then acknowledge an actual summary review:

   ```sh
   python3 dev/docs-deps.py --review docs/upstream-pending-work.md \
     --note "Describe the status and dependency claims checked and corrected" \
     --attribution "Actual tool/version, exact model ID, reasoning effort"
   ```

   The tool does not infer review from a changed timestamp or a successful build.
   Do not acknowledge a document merely to clear the check. Review actions update
   only the named maintained documents; unrelated stale documents remain flagged.

4. Regenerate registered outputs and the inventory, then check:

   ```sh
   python3 dev/docs-deps.py --refresh
   python3 dev/docs-deps.py
   ```

   A renderer-only invocation does not update the dependency receipt; use
   `--refresh` for the complete workflow.
   Registered generators run in dependency order.

5. Stage the changed sources, derivative outputs, manifest, and inventory together.
   The pre-commit hook runs `python3 dev/docs-deps.py --staged`, reading index
   blobs, so an unstaged correction cannot conceal stale staged documentation.
   The local `/tmp` copies are refreshed by the generator but are not Git blobs.
   For a partial commit, `python3 dev/docs-deps.py --staged --write-index` writes
   an inventory of exactly the staged documents. Stage that generated inventory
   and rerun `--staged`; the write command does not certify unstaged fixes.

Use `--write-index` when only discovered links or the document inventory changed.
The command still reports unresolved generated/maintained dependencies; it does
not acknowledge them. The initial inventory is broad discovery, not a retrospective
certification that every existing document is current. Extend explicit declarations
as documents are reviewed or new derived views are created.
