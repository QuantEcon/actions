# `.qe/` — how this repository is worked

This folder holds QuantEcon's project-management records for `QuantEcon/actions`, under
[QEP-7](https://github.com/QuantEcon/qeps) (Project Management Protocols). Everything about
*how the repository is worked* lives here; everything about *what the actions do* stays in the
repository's own documentation (`docs/`, `README.md`, `CONTRIBUTING.md`).

## Files and their lifecycles

| Path | Writer | Lifecycle |
|---|---|---|
| `README.md` | people | live: this contract |
| `dev/log/YYYY-MM-DD-<id>.md` | agents, people | raw, append-only: a dated record of one session or review, never edited after it lands |
| `dev/decisions/D-YYYY-MM-DD-<slug>.md` | people | raw, append-only: one decision per file; superseded by a new record, never rewritten |

Not present yet: `project.yml`, `NEXT-STEPS.md`, the generated views (`ROADMAP.md`, `DIGEST.md`,
`snapshot.json`) and the distilled pages under `dev/`. This repository hosts several project
trackers (issues typed `Project`), so none is declared here as *the* project; each tracker's
body is the state register for its project.

## Rules

- **Public content.** This repository is public: no credentials, no unpatched-vulnerability
  specifics, and absolute dates only.
- **Nothing here is ignored by version control**, and there is no scratch location in the tree.
- **History is not state.** What happened goes in `dev/log/` and in a tracker's comments; where a
  project stands now goes in its tracker's `## Where we stand (verified YYYY-MM-DD)` section.
