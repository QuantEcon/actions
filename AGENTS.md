# AGENTS.md

Guidance for coding agents working in this repository. The documents below hold the facts; this file points at them and does not repeat them.

QuantEcon Actions is a set of composite GitHub Actions, workflow templates and container images that build, preview and publish QuantEcon's lecture sites. It is on 0.x, and lecture repositories use it as `quantecon/actions/<action>@v0`.

## Where to look

| For | Read |
|---|---|
| How the repository is built, and why | [docs/dev/ARCHITECTURE.md](docs/dev/ARCHITECTURE.md) |
| How a change is tested: the action harness, the container checks, the canary | [docs/dev/TESTING.md](docs/dev/TESTING.md) |
| Building, testing and updating the container images | [docs/dev/CONTAINERS.md](docs/dev/CONTAINERS.md) |
| Current priorities, consumers, rollout and dependency policy | [docs/dev/PLAN.md](docs/dev/PLAN.md) |
| Writing an action's chapter, and the checks it must pass | [docs/dev/CHAPTER-TEMPLATE.md](docs/dev/CHAPTER-TEMPLATE.md) |
| What each action does, every input and output, and the guides | [docs/user/README.md](docs/user/README.md) |
| The development workflow, releases, staged releases, and which doc to update | [CONTRIBUTING.md](CONTRIBUTING.md) |
| What has changed, and what is unreleased | [CHANGELOG.md](CHANGELOG.md) |

## Rules that are easy to miss

- **An input's or output's description lives in its `action.yml`.** After editing one, run `python3 scripts/generate-docs.py` and commit what it writes: the manual's tables and each action's README are generated, and CI fails when they differ.
- **A change to what an action does** gets an entry under `## [Unreleased]` in the CHANGELOG, a harness job that shows the change and can fail, and ships in a staged release.
- **Do not add a `paths:` filter to `.github/workflows/test-actions.yml`.** Its `gate` job decides relevance; see CONTRIBUTING.md.
- **Pass values to `run:` scripts through `env:`,** not `${{ }}` in the script text, and find an action's files from `$GITHUB_ACTION_PATH`, never `${{ github.action_path }}`, which is wrong inside a container job.
- **A merge that changes `containers/**`** rebuilds both images and moves `:latest` for every consumer at once.
- **The docs describe the project as it is.** No dated status notes, "corrected on" paragraphs or struck-through items: history belongs in the CHANGELOG, the issues and git.

## Checks to run before a pull request

```bash
pip install -r scripts/requirements.txt
python3 scripts/generate-docs.py --check --check-examples --actionlint "$(command -v actionlint)"
actionlint
```

The last command lints `.github/workflows/`, as the gate does. actionlint lints `run:` scripts only when it finds `shellcheck` on your `PATH`, so have one there. Run `shellcheck` on any other shell you change.
