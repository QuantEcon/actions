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

### Version Tags

We use semantic versioning with a floating major tag:

| Tag | Purpose |
|-----|---------|
| `v1.0.0` | Specific release version |
| `v1` | Floating tag pointing to latest v1.x.x |

### Creating a Release

1. **Update version references** in documentation if needed

2. **Create and push tags:**
   ```bash
   git tag -a v1.x.x -m "Release v1.x.x - Description"
   git push origin v1.x.x
   
   # Update floating major tag
   git tag -fa v1 -m "Update v1 to v1.x.x"
   git push origin v1 --force
   ```

3. **Create GitHub Release** at https://github.com/QuantEcon/actions/releases/new

### Breaking Changes

Breaking changes require a **major version bump** (v1 → v2):
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
