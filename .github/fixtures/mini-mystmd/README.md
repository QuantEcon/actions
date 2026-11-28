# mini-mystmd fixture

The smallest mystmd project that `build-lectures` can build with `engine: mystmd` (#337): a
`myst.yml` with a `site:`, an intro, and one lecture with a code cell. The action harness
([`.github/workflows/test-actions.yml`](../../workflows/test-actions.yml)) copies it into the
workspace at run time.

- `build-mystmd` builds the website with upstream mystmd from npm, in the lean image, as root, and
  checks that the cell's output is on the page. Then it adds a cell that raises to a copy, and
  checks that the build fails.
- `build-engine-inputs` builds it with a stand-in `myst`, which writes what a build would, to test
  the action's commands, its checks of what was written, and what it refuses.

The site template, `book-theme`, is not in this folder: the harness puts a copy pinned by commit
in `_build/templates` before it builds, so that `myst` fetches no template.
