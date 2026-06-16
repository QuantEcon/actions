# Contributing to QuantEcon Actions

## Development Workflow

1. **Create a feature branch** from `main`
   ```bash
   git checkout -b feature/your-feature
   ```

2. **Make changes** and test locally where possible

3. **Submit a PR** with clear description of changes

4. **Review and merge** - PRs require approval before merging

## Release Process

### Version Strategy

**Current phase:** 0.x development (pre-1.0.0)
- Breaking changes are allowed in minor versions (0.x.0)
- Patch releases for bug fixes (0.x.y)
- Version 1.0.0 will be released when all lecture repos are successfully migrated

**After 1.0.0 release:**
- We'll use floating major tags (`v1`, `v2`, etc.)
- Breaking changes require major version bumps

### Version Tags

We use semantic versioning:

| Reference | Purpose |
|-----------|---------|
| `@v0` | Latest `0.x` release — floating tag, force-moved to each new release (recommended) |
| `@v0.x.y` | A specific pinned release (maximum reproducibility) |
| `@main` | Latest development (testing only) |

During `0.x`, `@v0` is the floating reference. Because minor releases (`0.x.0`) may include
breaking changes, `@v0` can move across a breaking change — consumers needing strict stability
should pin an exact `v0.x.y` tag. After the 1.0.0 release, we'll add floating major tags
(`v1`, `v2`) for stable references.

### Creating a Release

1. **Update CHANGELOG.md**
   - Move `[Unreleased]` items to new `[X.Y.Z]` section
   - Add release date
   - For breaking changes in 0.x, mark with ⚠️ **BREAKING**

2. **Create and push the version tag:**
   ```bash
   git tag -a v0.x.y -m "Release v0.x.y - Description"
   git push origin v0.x.y
   ```

3. **Move the floating `v0` tag to this release** so `@v0` consumers pick it up.
   The `^{}` peels the annotated tag so `v0` points at the release **commit** directly
   (a lightweight tag), not at the `v0.x.y` tag object:
   ```bash
   git tag -f v0 "v0.x.y^{}"
   git push origin v0 --force
   ```

4. **Create GitHub Release** at https://github.com/QuantEcon/actions/releases/new
   - Copy changelog entry as release notes
   - Attach any relevant artifacts

### Breaking Changes

**During 0.x phase (current):**
- Breaking changes are allowed and increment minor version (0.x.0)
- Mark as ⚠️ **BREAKING** in CHANGELOG with migration notes

**After 1.0.0 release:**
- Removing inputs/outputs
- Changing default behavior
- Renaming actions

## Action Development Guidelines

### Inputs

- Use descriptive names with clear defaults
- Document all inputs in action's README.md
- Prefer `'false'` as default for optional features

### Outputs

- Provide useful outputs for downstream steps
- Document output values and when they're available

### Error Handling

- Use `::warning::` and `::error::` annotations
- Provide actionable error messages
- Consider `upload-failure-reports` pattern for debugging

## Testing

Test changes in a lecture repository before merging:

1. Reference your branch: `quantecon/actions/action-name@feature/your-branch`
2. Run workflow and verify behavior
3. Check outputs and error handling

## Documentation

Update these docs when adding features:

| Doc | Update When |
|-----|-------------|
| Action's `README.md` | Any input/output changes |
| `docs/QUICK-REFERENCE.md` | New inputs added |
| `docs/MIGRATION-GUIDE.md` | Workflow patterns change |
| `docs/FUTURE-DEVELOPMENT.md` | Features completed/planned |

## Questions?

Open an issue or discussion at https://github.com/QuantEcon/actions
