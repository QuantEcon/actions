# Versioning

> This describes `main`. For the version you pin, open the manual at that tag. Changes not yet released are under `[Unreleased]` in the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md).

Each step names the version of the action it runs after the `@` in its `uses:` line, as in `quantecon/actions/build-lectures@v0`. This chapter covers which version to name, how a new release reaches your repository, and how the container images, which are versioned separately, change.

## Which version to use

| Reference | What it is | Use it for |
|---|---|---|
| `@v0` | A tag the maintainers move to each new release | Every lecture repository. This is the recommended reference |
| `@v0.14.0`, or any release | One release, which never changes | A repository that must not change until someone edits its workflows |
| `@main`, or a branch name | Whatever that branch holds now | Testing an unreleased change. Never for a site readers use |

Use one reference for every action in a repository. The actions are released together, and the canary tests each release as a set.

The actions are on 0.x. A minor release, such as 0.15.0, can change what an action does in a way that breaks a workflow; the CHANGELOG marks such a change **BREAKING** and says what to change. A patch release, such as 0.14.1, only fixes bugs. `@v0` moves across both. After 1.0.0, a floating `@v1` will move only across releases that keep compatibility.

## How a release reaches your repository

A release is a `vX.Y.Z` tag, with a [GitHub Release](https://github.com/QuantEcon/actions/releases) and a section of the [CHANGELOG](https://github.com/QuantEcon/actions/blob/main/CHANGELOG.md) saying what changed.

- **On `@v0`,** a workflow runs the new release from the first run after the maintainers move `v0`, with no change in your repository. For a release that changes what an action does, they move it only once the release has passed on the canary, [QuantEcon/test-actions-lecture-intro](https://github.com/QuantEcon/test-actions-lecture-intro), a lecture repository kept for testing the actions: its pull-request previews and its cache build run against the new tag first. So a release can exist for a while before `@v0` reaches it.
- **On an exact release,** nothing changes until the reference is edited. If the repository has Dependabot version updates for GitHub Actions, Dependabot proposes the new release as a pull request on its schedule, and merging it is your decision. Without them, nothing tells you. To turn them on, add the ecosystem to `.github/dependabot.yml`:

  ```yaml
  version: 2
  updates:
    - package-ecosystem: github-actions
      directory: /
      schedule:
        interval: weekly
  ```

Before moving an exact reference, read the CHANGELOG sections in between. Its **Deprecated** entries name what a later release removes, and the change to make. A deprecated input keeps working until then, with a warning on every run.

## Pinning one action does not pin the ones it runs

[`build-jupyter-cache`](actions/build-jupyter-cache.md) runs [`setup-environment`](actions/setup-environment.md) and [`build-lectures`](actions/build-lectures.md) as steps of its own, at `@v0`, whatever version the workflow names for `build-jupyter-cache` itself, because GitHub does not allow an expression in `uses:`. So in a repository pinned to an exact release, those two still change when `v0` moves. The other actions run no other action of this repository.

## The manual for your version

This manual describes `main`. For the version a workflow names, open the manual at that tag, at `https://github.com/QuantEcon/actions/tree/<tag>/docs/user`: `v0` for `@v0`, or `v0.14.0` for that release. The manual first shipped in v0.13.0. For an earlier release, read each action's `README.md` at that tag.

## Container images

The QuantEcon container images are versioned apart from the actions. A workflow names one in its `container:` block, and the templates name `:latest`, which moves whenever a change to an image merges. Pin an image by its digest to keep it fixed. [Containers](containers.md) covers when the images change and how to pin one.
