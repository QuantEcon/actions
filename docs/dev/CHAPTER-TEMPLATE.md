# Writing an action chapter

Each action has one chapter in the user manual, at `docs/user/actions/<action>.md`. Start from the skeleton below. [setup-environment.md](../user/actions/setup-environment.md) is a finished chapter to compare against.

## What goes where

- **`action.yml` holds every per-input and per-output fact.** The generator copies each `description:` into the chapter's tables verbatim, so write it for a reader. For an input, say what it does, the values it accepts, and when it applies (a mode, or another input it depends on). For an output, say when it is set and what it holds when it is not. The chapter's prose covers behaviour, and does not repeat these facts.
- **The generated blocks are not edited by hand.** After editing an `action.yml`, or adding a chapter, run:

  ```bash
  pip install -r scripts/requirements.txt   # PyYAML, once
  python3 scripts/generate-docs.py
  ```

  It fills the chapter's Inputs and Outputs tables, rewrites the action's `README.md` as a signpost to the chapter, and updates the action table in `docs/user/README.md`. The harness `gate` job runs it with `--check`, and fails when a committed table no longer matches.
- **Examples.** The minimal example is a complete workflow: `name:`, `on:`, `permissions:` and `jobs:`. Anything shorter is a fragment of steps, with no `jobs:` key. The realistic example is a link to the template that uses the action, not a copy of it.

## What the gate checks

`python3 scripts/generate-docs.py --check-examples` reads every `yaml` block under `docs/user` and every workflow in `templates/`, and fails when:

- a block does not parse as YAML;
- a `quantecon/actions/<action>@…` step passes an input its `action.yml` does not declare, or leaves out a required one;
- a complete workflow sets no `permissions:`, at the top or on every job;
- a block has `jobs:` but no `on:`;
- a complete workflow fails actionlint, which the gate runs with `--actionlint`.

To run all of it locally, with an [actionlint](https://github.com/rhysd/actionlint) on your `PATH`:

```bash
python3 scripts/generate-docs.py --check --check-examples --actionlint "$(command -v actionlint)"
```

## Writing rules

These keep the manual readable on GitHub, and cheap to publish later (#179):

- No strikethrough.
- `${{ … }}` only inside backticks or a code block.
- Anything outside `docs/` is linked by its absolute GitHub URL: `https://github.com/QuantEcon/actions/blob/main/<file>`, or `/tree/main/<directory>`.
- File names are unique within `docs/user`.
- GitHub alerts (`> [!NOTE]`) are allowed.
- The chapter describes `main` as it is. It carries no dated notes and no history: those are in the CHANGELOG, the issues and git.

## Skeleton

````markdown
# <action>

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

<What the action does, in a paragraph or a short list. Define any term the input descriptions rely on, such as a mode.>

## When to use it

<When to use it, and when not: the neighbouring action that fits better, or the action that already runs this one for you.>

## Requirements

- **Runner.** <hosted or self-hosted, container or not, and what the action needs on it>
- **Node.** <the Node version the action needs, or None>
- **Permissions.** <the `permissions:` the action's own calls need, and what each is for>
- **Secrets.** <each secret, and where its value comes from>
- **Files in your repository.** <files the action reads, and where a starting point is>
- **Setup outside GitHub.** <every one-time step, spelled out; nothing that exists only in a repository the reader may not be able to open, and no account details>

## Inputs

<!-- BEGIN GENERATED: inputs -->
<!-- END GENERATED -->

## Outputs

<!-- BEGIN GENERATED: outputs -->
<!-- END GENERATED -->

## Examples

### Minimal

```yaml
name: <workflow>
on:
  <trigger>:

jobs:
  <job>:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v7
      - uses: quantecon/actions/<action>@v0
```

### In the templates

<A link to each template that uses the action, and what it does with it.>

## Behaviour

<What it checks, what fails the job, its cache keys, the artifacts it uploads, and what it prints.>

## Troubleshooting

**`<the message, as the action prints it>`.** <The cause, then the fix.>
````
