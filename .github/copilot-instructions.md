# QuantEcon Actions - Development Guide

**AI assistant guidance for working with this repository.**

## Quick Context

This repository provides **reusable GitHub Actions** for building QuantEcon lecture websites.

**Current phase:** v0.x development - Infrastructure complete, ready for Phase 1 migration testing  
**For details:** See [PLAN.md](../PLAN.md) for migration roadmap and priorities

## Where to Find Information

| Topic | Document |
|-------|----------|
| **Migration roadmap & current priorities** | [PLAN.md](../PLAN.md) |
| **Architecture & design decisions** | [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) |
| **How to migrate lecture repos** | [docs/MIGRATION-GUIDE.md](../docs/MIGRATION-GUIDE.md) |
| **Container usage** | [docs/CONTAINER-GUIDE.md](../docs/CONTAINER-GUIDE.md) |
| **GPU AMI setup** | [docs/GPU-AMI-SETUP.md](../docs/GPU-AMI-SETUP.md) |
| **Testing validation** | [TESTING.md](../TESTING.md) |
| **Quick reference** | [docs/QUICK-REFERENCE.md](../docs/QUICK-REFERENCE.md) |
| **Release process** | [CONTRIBUTING.md](../CONTRIBUTING.md) |
| **Version history** | [CHANGELOG.md](../CHANGELOG.md) |

**Don't duplicate:** Information already in these docs should be referenced, not copied here.

## Repository Structure

```
quantecon/actions/
├── containers/
│   ├── quantecon/          # Full container (~8GB): Anaconda + TexLive
│   └── quantecon-build/     # Lean container (~3GB): Miniconda + minimal TexLive
├── setup-environment/       # Environment setup action
├── build-lectures/          # Jupyter Book build action
├── build-jupyter-cache/     # Cache generation action (weekly)
├── restore-jupyter-cache/   # Cache restore action (PRs)
├── preview-netlify/         # Netlify PR preview action
├── preview-cloudflare/      # Cloudflare Pages PR preview action
├── publish-gh-pages/        # GitHub Pages publishing action
├── templates/               # Workflow templates for lecture repos
└── docs/                    # Comprehensive documentation
```

## Development Practices

### Commits & PRs
- Keep commits focused and atomic
- Update [CHANGELOG.md](../CHANGELOG.md) for user-facing changes
- Breaking changes in 0.x allowed - mark with ⚠️ **BREAKING** in CHANGELOG
- Reference issues/PRs in commit messages

### Testing
Before merging action changes:
1. Test in a lecture repo using `@branch-name` reference
2. Verify workflow completes successfully
3. Document test results in PR description

### Documentation Updates
When changing actions, update:
- Action's `README.md` (inputs/outputs)
- `docs/QUICK-REFERENCE.md` (if inputs added)
- `CHANGELOG.md` (user-facing changes)
- `PLAN.md` (if affects migration status)

## ⚠️ CRITICAL: GitHub CLI Tool Constraints

**ALWAYS use the `create_file` tool for multi-line content** - heredoc and shell escaping break frequently in terminals:

```bash
# ❌ WRONG - heredoc breaks in terminal tool, escaping fails with backticks/variables
cat > /tmp/pr-body.md << 'EOF'
Multi-line content
EOF
gh pr edit 13 --body "Multi-line content with `backticks` and $variables"
gh release create v1.0.0 --notes "Release notes with **markdown**"

# ✅ CORRECT - Use create_file tool to write /tmp files, then reference them in gh commands
# Step 1: Use create_file tool to write /tmp/pr-body.md
# Step 2: Run in terminal:
gh pr edit 13 --body-file /tmp/pr-body.md

# Step 1: Use create_file tool to write /tmp/release-notes.md
# Step 2: Run in terminal:
gh release create v1.0.0 --notes-file /tmp/release-notes.md
```

**This applies to:**
- `gh pr create --body` → use `create_file` for `/tmp/pr-body.md`, then `--body-file /tmp/pr-body.md`
- `gh pr edit --body` → use `create_file` for `/tmp/pr-body.md`, then `--body-file /tmp/pr-body.md`
- `gh release create --notes` → use `create_file` for `/tmp/release-notes.md`, then `--notes-file /tmp/release-notes.md`
- `gh issue create --body` → use `create_file` for `/tmp/issue-body.md`, then `--body-file /tmp/issue-body.md`

**ALWAYS write `gh` command output to a file** - gh CLI is interactive and won't display in terminal:

```bash
# View workflow runs
gh run list --limit 10 > /tmp/gh-runs.txt && cat /tmp/gh-runs.txt

# View specific run logs
gh run view RUN_ID --log > /tmp/gh-logs.txt && cat /tmp/gh-logs.txt

# View failed logs only
gh run view RUN_ID --log-failed > /tmp/gh-failed.txt && cat /tmp/gh-failed.txt
```

**Never run `gh` commands without redirecting to a file first.**

## Common Tasks

### Test Container Locally
```bash
docker pull ghcr.io/quantecon/quantecon:latest
docker run --rm ghcr.io/quantecon/quantecon:latest python --version
```

### Trigger Container Rebuild
```bash
gh workflow run build-containers.yml
```

### View Workflow Runs
```bash
gh run list --limit 10 > /tmp/gh-runs.txt && cat /tmp/gh-runs.txt
gh run view RUN_ID --log > /tmp/gh-logs.txt && cat /tmp/gh-logs.txt
```

## Status

- **Created:** November 2025
- **Updated:** February 9, 2026
- **Current Phase:** Infrastructure complete, ready for production migration (v0.6.0 pending)
- **Containers:** ghcr.io/quantecon/quantecon:latest (full, ~8GB), ghcr.io/quantecon/quantecon-build:latest (lean, ~3GB)
- **Actions:** 7 composite actions complete and tested
- **Next:** Begin Phase 1 migration with lecture-dp repo
