# Contributing to QuantEcon Actions

Thank you for your interest in contributing to QuantEcon Actions! This guide will help you understand our development workflow and standards.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Testing Guidelines](#testing-guidelines)
- [Release Process](#release-process)
- [Action Development Standards](#action-development-standards)

## Code of Conduct

We expect all contributors to adhere to professional standards:
- Be respectful and constructive
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- GitHub account
- Access to QuantEcon lecture repositories (for testing)
- Understanding of GitHub Actions composite actions
- Familiarity with Conda, Jupyter Book, and LaTeX

### Local Development Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/quantecon/actions.git
   cd actions
   ```

2. **Review existing actions:**
   - Read each action's `action.yml`
   - Understand input/output schemas
   - Review caching strategies

3. **Set up test repository:**
   - Fork a QuantEcon lecture repository
   - Create test branch
   - Configure secrets (NETLIFY_AUTH_TOKEN, etc.)

## Development Workflow

### Making Changes

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Follow naming conventions:**
   - Feature branches: `feature/description`
   - Bug fixes: `fix/issue-description`
   - Documentation: `docs/description`

3. **Make changes:**
   - Update `action.yml` files
   - Update corresponding `README.md`
   - Update `CHANGELOG.md` (Unreleased section)

4. **Test thoroughly:**
   - Follow [TESTING.md](TESTING.md) strategy
   - Test in controlled environment first
   - Validate across multiple repositories

### Pull Request Process

1. **Update documentation:**
   - Action README with new inputs/outputs
   - Main README if adding new action
   - CHANGELOG with changes

2. **Create pull request:**
   - Clear title describing change
   - Detailed description with context
   - Link to related issues
   - Include test results

3. **Review process:**
   - At least one maintainer review required
   - Address all feedback
   - Ensure CI passes
   - Squash commits if requested

## Testing Guidelines

### Phase 1: Local Validation

**For action.yml changes:**
1. Validate YAML syntax
2. Check all required inputs defined
3. Verify shell script syntax
4. Review cache key generation

**Tools:**
```bash
# Validate YAML
yamllint action.yml

# Check shell scripts
shellcheck action.yml
```

### Phase 2: Controlled Testing

**Test in fork first:**
1. Create test branch in your fork
2. Update workflow to use your fork:
   ```yaml
   - uses: YOUR-USERNAME/actions/setup-lecture-env@test-branch
   ```
3. Verify cache behavior
4. Check output variables
5. Monitor execution time

### Phase 3: Pre-Release Testing

**Test in production-like environment:**
1. Create test branch in quantecon/actions
2. Update one lecture repo to use test branch
3. Run full workflow suite:
   - CI (pull request)
   - Cache rebuild
   - Publish workflow
4. Compare performance metrics
5. Verify no regressions

### Testing Checklist

Before submitting PR:

- [ ] YAML syntax valid
- [ ] All inputs documented in README
- [ ] All outputs documented in README
- [ ] Cache keys properly formatted
- [ ] Shell scripts have error handling
- [ ] Tested in fork successfully
- [ ] Tested in at least one lecture repo
- [ ] Performance metrics collected
- [ ] Documentation updated
- [ ] CHANGELOG updated
- [ ] No breaking changes (or documented)

## Release Process

### Versioning Strategy

We use semantic versioning (MAJOR.MINOR.PATCH):

- **MAJOR**: Breaking changes to inputs/outputs
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

**Tags:**
- Development: `main` branch
- Stable: `v1`, `v1.0`, `v1.0.0`

### Creating a Release

1. **Update CHANGELOG.md:**
   ```markdown
   ## [1.1.0] - 2024-XX-XX
   
   ### Added
   - New feature description
   
   ### Changed
   - Changed behavior
   
   ### Fixed
   - Bug fix description
   ```

2. **Create Git tags:**
   ```bash
   git tag -a v1.1.0 -m "Release v1.1.0"
   git tag -f v1  # Move v1 to latest
   git push origin v1.1.0
   git push origin v1 --force
   ```

3. **Create GitHub release:**
   - Go to Releases → Draft new release
   - Tag: `v1.1.0`
   - Title: `v1.1.0 - Description`
   - Description: Copy from CHANGELOG
   - Publish release

4. **Notify users:**
   - Update lecture repositories
   - Post in team communication channels
   - Update documentation

### Hotfix Process

For critical bugs in production:

1. Create hotfix branch from tag:
   ```bash
   git checkout -b hotfix/critical-bug v1.0.0
   ```

2. Make minimal fix and test

3. Update CHANGELOG:
   ```markdown
   ## [1.0.1] - 2024-XX-XX
   
   ### Fixed
   - Critical bug description
   ```

4. Release as patch version

5. Merge back to main

## Action Development Standards

### File Structure

Each action must have:
```
action-name/
├── action.yml      # Composite action definition
└── README.md       # Comprehensive documentation
```

### action.yml Requirements

```yaml
name: 'Action Name'
description: 'Clear, concise description'
author: 'QuantEcon'

inputs:
  required-input:
    description: 'What this input does'
    required: true
  optional-input:
    description: 'What this input does'
    required: false
    default: 'sensible-default'

outputs:
  output-name:
    description: 'What this output contains'
    value: ${{ steps.step-id.outputs.value }}

runs:
  using: "composite"
  steps:
    - name: Clear step name
      shell: bash -l {0}  # Use -l for conda
      run: |
        # Clear, commented code
        echo "Descriptive output"

branding:
  icon: 'package'
  color: 'blue'
```

### README.md Requirements

Each action README must include:

1. **Overview** - What the action does
2. **Features** - Bullet list of capabilities
3. **Inputs table** - All inputs with descriptions
4. **Outputs table** - All outputs with descriptions
5. **Usage examples** - Basic to advanced
6. **Caching behavior** - How caching works
7. **Performance metrics** - Time savings
8. **Troubleshooting** - Common issues and solutions
9. **Examples** - Real-world workflow snippets

### Code Style

**Shell scripts:**
- Use `set -e` for error handling
- Quote variables: `"${{ inputs.value }}"`
- Use `echo "::group::"` for organized logs
- Provide clear error messages
- Use `||` for non-fatal commands

**YAML:**
- Use 2-space indentation
- Quote string values with special chars
- Use descriptive step names
- Group related steps with comments

### Cache Design Principles

1. **Stable cache keys** - Use stable inputs
2. **Restore keys** - Provide fallbacks
3. **Cache size** - Keep under 2GB per cache
4. **Invalidation** - Clear strategy for when to invalidate
5. **Documentation** - Explain cache behavior in README

### Error Handling

Every action should:
- Validate inputs when possible
- Provide clear error messages
- Use `::error::` for GitHub annotations
- Document common failures
- Gracefully handle missing optional inputs

### Performance Optimization

- Minimize external dependencies
- Cache aggressively but intelligently
- Use parallel operations where safe
- Provide progress indicators for long operations
- Document expected execution times

## Documentation Standards

### Writing Style

- Clear and concise
- Use examples liberally
- Include both simple and complex scenarios
- Explain **why**, not just **how**
- Use emoji for visual scanning (📦 🚀 ⚠️ ✅)

### Code Examples

```yaml
# ✅ GOOD: Complete, runnable example
- uses: quantecon/actions/setup-lecture-env@v1
  with:
    python-version: '3.13'
    install-ml-libs: 'true'

# ❌ BAD: Incomplete, unclear
- uses: setup-lecture-env
  with:
    libs: true
```

### Version References

- Use `@v1` for examples (major version)
- Document specific versions in CHANGELOG
- Update examples when behavior changes

## Questions?

- **Issues:** Open an issue for bugs or feature requests
- **Discussions:** Use GitHub Discussions for questions
- **Contact:** Reach out to QuantEcon maintainers

## Recognition

Contributors will be recognized in:
- GitHub contributors page
- CHANGELOG.md release notes
- Annual contributor acknowledgments

Thank you for contributing to QuantEcon Actions! 🎉
