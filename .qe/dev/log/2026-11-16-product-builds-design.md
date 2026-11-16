# Design note: building products from QuantEcon/lectures, 2026-11-16

*A raw record under QEP-7: a design note for
[QuantEcon/project-monorepo#77](https://github.com/QuantEcon/project-monorepo/issues/77), which asks
for one build workflow that builds any product on either engine, and for the changes it needs here.
It was written by a Claude Code session working QuantEcon/project-monorepo
(<https://claude.ai/code/session_01WT8bMXuHMiWb8victibwcU>), against `QuantEcon/actions` at
`d65e694` (v0.21.0). It proposes; it decides nothing. The decisions it asks for are listed at the
end, and what happens next is recorded on the issues it names. This file is not edited after it
lands.*

## The setting

[QuantEcon/lectures](https://github.com/QuantEcon/lectures) holds every lecture of the six series
once, in a flat pool, `lectures/<slug>.md` with `lectures/_static/`. Since 2026-11-15 all six series
are in it (328 lectures). Each published series becomes a **product**: a folder
`products/<key>/` with its own `_toc.yml`, `_config.yml` and product pages (an `about` or `intro`
page, `status`, `zreferences`), built from the pool. The folders do not exist yet
([QuantEcon/project-monorepo#21](https://github.com/QuantEcon/project-monorepo/issues/21)), and each
series keeps building and publishing from its own repository until its cutover
([QuantEcon/project-monorepo#82](https://github.com/QuantEcon/project-monorepo/issues/82)).

Two build tests in the planning repository showed what one product's build is on Jupyter Book 1:
a one-line copy that puts the product's own pages beside the pool lectures, then

    jb build <stage> --toc products/<key>/_toc.yml --config products/<key>/_config.yml -W -n --keep-going

Products differ in what they run on: intermediate, programming and jax build on a RunsOn GPU
runner (`g4dn.2xlarge`), the other three on `ubuntu-latest`, with time limits from 600 to 7,200
seconds. Each series' `publish.yml` makes three builds, `pdflatex`, `jupyter` and `html`, from a
restored cache. The destination engine is mystmd (Jupyter Book 2); the switch is decided later,
so the build must take the engine as an input from the start.

## The first question: where the build workflow lives

#77 proposes a reusable `build-product.yml` (`workflow_call`) **in this repository**. This
repository's own rule, in [ARCHITECTURE.md](../../../docs/dev/ARCHITECTURE.md#which-actions-live-here),
is that *a reusable workflow belongs where its job's purpose belongs*. A product build's purpose
is QuantEcon/lectures': it reads that repository's `products/` folders and its pool, its matrix is
that repository's list of products, and it has one caller.

| | In `QuantEcon/lectures` | In `QuantEcon/actions` |
|---|---|---|
| Callers | one, the repository it builds | one, `QuantEcon/lectures` |
| Versioning | changes with the products it builds, in the same pull request | a `v0` release, gated by the canary, which has no product to build |
| What it couples | the products' layout, which lives there | this repository to a layout it does not own |
| What it reuses from here | every composite action, at `@v0` as today | the same |

**Proposal:** the product build is a workflow in QuantEcon/lectures (a matrix job, or a reusable
workflow inside that repository if more than one of its workflows needs it). This repository
supplies what the build's steps need, as composite actions, and owns nothing that knows what a
product is. That changes #77's first acceptance criterion; the other criteria are unchanged.

## What the composite actions lack for a product build

Each gap was checked against `d65e694`.

1. **No engine input.** `build-lectures` runs `jb build` (`build-lectures/action.yml`, the build
   step), and its checks are Jupyter Book 1's: `-n` and `-W`, the warnings log of a `jupyter`
   build, the error outputs read from the execution cache. A mystmd build is `myst build --html`
   (and `--pdf`, `--ipynb`) run from the folder that holds `myst.yml`. **Proposal:** an `engine`
   input on `build-lectures`, `jb1` by default; with `myst`, the action runs `myst build` with the
   builder's flag and documents which of its checks apply. The mystmd leg is non-publishing and
   `continue-on-error` in the caller's matrix until the engine switch, so this input can ship
   before every check has a mystmd equivalent, as long as the chapter says which do.
2. **A product's toc and configuration need nothing new on Jupyter Book 1.** `source-dir` stays
   `lectures`, and `extra-args` carries `--toc products/<key>/_toc.yml --config
   products/<key>/_config.yml -W --keep-going` (`jb build` takes both options; `extra-args` is
   split on whitespace, and none of these paths holds a space). The copy of the product's pages
   is a step in the caller's job. **Proposal:** no input; a worked example in the
   `build-lectures` chapter. `build-jupyter-cache` already passes `extra-args` through to each of
   its builds (it did not when #77 was written).
3. **The caches cannot tell two products in one repository apart.** `build-jupyter-cache` saves
   `build-<env>-<update>-<run id>` and `jupyter-cache-<env>-<update>-<source>-<run id>`, and
   `restore-jupyter-cache` restores the newest key by prefix, so a product would restore whichever
   product saved last. `restore-jupyter-cache` already takes a `key`; `build-jupyter-cache`
   takes none. The `<source>` hash covers `source-dir/**/*.md`, all 328 pool lectures, so any
   lecture change misses every product's exact key (the fallback without the source hash still
   restores). **Proposal:** a `key-prefix` input on both cache actions, empty by default (today's
   keys), which the caller sets to the product key. If QuantEcon/lectures keeps the plan's
   current choice, `actions/cache` keyed `jb1-<key>-<env hash>` in its own workflow, with no
   shared cache built on the old stack, this item is not needed until a product adopts the cache
   actions, and can wait.
4. **Two products' previews on one pull request overwrite one comment.** `scripts/preview-comment.cjs`
   finds its comment by a marker per provider, `<!-- quantecon-preview:<provider> -->`, so a
   second product's preview replaces the first's. Its links to changed lectures are
   `<deploy url>/<path>.html`, which is Jupyter Book 1's layout; mystmd serves `/<slug>`. And
   `scripts/detect-changed-lectures.sh` lists every added or modified `.md` directly under
   `lectures-dir` (skipping `_*` files and `intro.md`), whatever a toc lists; a `_toc.yml` in
   that folder only decides whether the folder's name is stripped from the links. With
   `lectures-dir` set to the pool, it would list every changed pool lecture, including those a
   product does not publish, and, since the pool holds no `_toc.yml`, keep `lectures/` in each
   link, where a product's site serves the lecture at its root.
   **Proposal:** on all three preview actions (`preview-netlify`, `preview-cloudflare` and
   `preview-workers`, which share both scripts), a `preview-key` input added to the marker and
   the heading (empty by default: today's marker), a `link-style` input (`html` by default, or
   `slug`), and a `toc` input naming the `_toc.yml` whose files count as the product's lectures,
   which also strips the pool folder from the links.
5. **Runner class and time limit** are the caller's job settings (`runs-on`, `timeout-minutes`),
   which a composite action cannot set and does not need to. Nothing here.

## A proposed order

Each of the changes below is one pull request here, with a chapter update, a harness job that
fails on today's code, a CHANGELOG entry and a staged release, as CONTRIBUTING.md asks. None
changes what an existing caller gets: every new input defaults to today's behaviour.

1. The preview inputs (item 4). The first products' pull requests need them, and they are small.
2. The `engine` input (item 1), so the caller's matrix has the axis from the start.
3. The cache `key-prefix` (item 3), when a product first uses the cache actions.

In QuantEcon/lectures, after #21 lands the product folders: the product-build workflow, with a
matrix over products (`fail-fast: false`), runner class and time limit as product fields, and the
triggers #77 lists. `dp` is the first product through it
([QuantEcon/project-monorepo#25](https://github.com/QuantEcon/project-monorepo/issues/25)).

## Decisions this asks for

1. **Where the product build lives:** in QuantEcon/lectures, as proposed, or a reusable workflow
   here, as #77 first proposed.
2. **Whether the three input changes are wanted here,** in the order above, each as its own issue.
3. **For item 3,** whether QuantEcon/lectures uses the cache actions at all before the engine
   switch, or `actions/cache` directly as the plan has it now.
