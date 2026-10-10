# Public compiler pending-work view

The pending compiler queue on the [open-source page](https://wald3n.com/open-source?status=pending#compiler-work) is derived from this repository's `TODO.md`. The site publisher fetches `origin/main`, parses that file into `src/data/compiler-todo.json`, then verifies, builds, commits, pushes, deploys, and checks the live site. Its implementation is in [`publish-open-source-dashboard.mjs`](https://github.com/wbniv/wald3n.com/blob/main/scripts/publish-open-source-dashboard.mjs).

When a compiler `TODO.md` change alters the public pending queue, publish the compiler commit first, then run `task open-source:publish` in the website repository. The publisher uses the latest published compiler revision, so publishing before the compiler change reaches `origin/main` leaves the page unchanged.

Standing instruction from Will, October 10, 2026: after updating upstream tracking or other documentation that feeds this public view, update https://wald3n.com/open-source as part of the same work. Commit and push the compiler changes first, run `task open-source:publish` in `/home/will/wald3n.com`, and verify the live page. Publication is authorized; record an actual failure if it cannot finish rather than leaving a routine publication reminder.

This record is maintained from `TODO.md` in the compiler repository's document-dependency inventory. Run `python3 dev/docs-deps.py --impact TODO.md` to see it when reviewing pending-work changes; the inventory cannot hash or regenerate the website repository's separate data file.
