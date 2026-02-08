# Future Development

Ideas and longer-term enhancements for QuantEcon Actions.

For the current migration plan and feature parity status, see [PLAN.md](../PLAN.md).

---

## GPU Runner Alternatives

We currently use [RunsOn](https://runs-on.com) with a custom AMI for GPU builds. These are alternative approaches worth monitoring:

### GitHub GPU Runners

GitHub is developing official GPU runner support (currently beta). This would eliminate the need for custom AMI management and RunsOn configuration.

- Simpler setup — just `runs-on: ubuntu-gpu-latest` (or similar)
- No AMI maintenance, no Packer builds
- Managed by GitHub with automatic updates
- Timeline: Unknown — monitor [GitHub's roadmap](https://github.com/github/roadmap)

**Trade-off:** Likely more expensive per-minute than RunsOn. May not offer the same instance flexibility (e.g., specific GPU types).

### GPU Container (nvidia/cuda base)

A QuantEcon container built on `nvidia/cuda` instead of Ubuntu, with CUDA + cuDNN pre-installed alongside the scientific Python stack.

- Would match the container-based workflow pattern used for CPU builds
- Requires GPU-enabled runners (RunsOn or GitHub GPU runners) with `--gpus all`
- Could replace the custom AMI approach entirely

**Trade-off:** Container size would be significantly larger (~15-20GB with CUDA). Pull times may negate setup savings unless layer caching is effective.

---

## Potential New Actions

### Link Checker Action

Wrap `lycheeverse/lychee-action` into a QuantEcon-specific action with:
- Auto-check against `gh-pages` branch
- Issue creation on broken links with deduplication
- Configurable accept codes and exclusion patterns

Currently each repo has its own `linkcheck.yml`. A shared action would standardize this.

### Colab Compatibility Action

Wrap Google Colab container testing into a reusable action:
- Run notebooks inside `us-docker.pkg.dev/colab-images/public/runtime:latest`
- Validate execution against Colab's Python/package versions
- Issue creation on failure

Currently only `lecture-python.myst` has this. Could be useful for other repos.

### Notebook Sync Action

Automate notebook repository sync (e.g., pushing `.ipynb` files to `lecture-python.notebooks`):
- Clone target repo, copy notebooks, commit + push
- Configurable target repo, branch, commit message
- PAT-based authentication

Currently handled as inline steps in `lecture-python.myst/publish.yml`. Only worth building if multiple repos need it.

---

## Build & Performance Enhancements

### Build Monitoring

- Track setup time, build time, total time per repository
- Compare container vs standard runner vs RunsOn performance
- Detect performance regressions via GitHub Actions job summaries
- Dashboard or periodic report

### Parallel Multi-format Builds

- Run HTML, PDF, and notebook builds as separate parallel jobs instead of sequential steps
- Merge outputs in a final assembly job
- Could reduce total workflow time for repos that build all 3 formats

**Trade-off:** More complex workflow structure. Runner costs increase (3 parallel GPU instances). Only beneficial for repos with long build times across multiple formats.

### Container Layer Optimisation

- Investigate splitting the container into a base layer (Ubuntu + LaTeX) and an application layer (Python + packages)
- Would allow faster rebuilds when only Python packages change
- Weekly builds already keep images fresh, so the benefit may be marginal

---

## Documentation & Tooling

### Migration Tooling
- One-command migration script that reads a repo's existing workflows and generates the migrated versions
- Validation tool that compares build outputs before/after migration

### Video Tutorials
- Container workflow walkthrough
- Migration guide screencast
- Troubleshooting common issues

### Performance Benchmarks
- Published comparison data: ubuntu-latest vs container vs RunsOn AMI
- Per-repo build time tracking over time

