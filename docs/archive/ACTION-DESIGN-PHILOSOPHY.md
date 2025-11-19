# Action Design: Monolithic vs Modular

**Date:** 19 November 2025  
**Question:** Should we bundle all deployment actions into one "super action" or keep them modular?

---

## The Two Approaches

### Approach A: Monolithic "Super Action"

**Single action that does everything:**

```yaml
# lecture-python-intro/.github/workflows/ci.yml
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      
      # One action to rule them all
      - uses: quantecon/actions/lecture-pipeline@main
        with:
          # Build config
          lecture-dir: 'lectures'
          builder: 'html'
          
          # Netlify deployment
          netlify-site-id: ${{ vars.NETLIFY_SITE_ID }}
          deploy-to-netlify: 'true'
          
          # GitHub Pages deployment
          deploy-to-gh-pages: 'false'
          gh-pages-branch: 'gh-pages'
          
          # PDF build
          build-pdf: 'false'
```

**Characteristics:**
- Single action handles: build, cache, deploy to Netlify, deploy to GH Pages, PDF builds
- Configuration through inputs
- Secrets accessed internally (e.g., `secrets.NETLIFY_AUTH_TOKEN`)
- "Convention over configuration" approach

---

### Approach B: Modular Actions

**Separate actions composed together:**

```yaml
# lecture-python-intro/.github/workflows/ci.yml
jobs:
  build:
    runs-on: ubuntu-latest
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      
      # Build action
      - uses: quantecon/actions/build-lectures@main
        id: build
      
      # Deploy to Netlify
      - uses: quantecon/actions/deploy-netlify@main
        with:
          site-id: ${{ vars.NETLIFY_SITE_ID }}
          auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          publish-dir: ${{ steps.build.outputs.build-path }}
      
      # Optional: Deploy to GitHub Pages
      - uses: quantecon/actions/publish-gh-pages@main
        if: github.ref == 'refs/heads/main'
        with:
          publish-dir: ${{ steps.build.outputs.build-path }}
```

**Characteristics:**
- Each action has single responsibility
- Explicit composition in workflow
- Secrets passed explicitly
- Clear data flow between steps

---

## Comparison

| Aspect | Monolithic Super Action | Modular Actions |
|--------|------------------------|-----------------|
| **Workflow length** | Shorter (~10 lines) | Longer (~20-30 lines) |
| **Simplicity** | Simpler for common case | More explicit |
| **Flexibility** | Limited to inputs | Full workflow control |
| **Learning curve** | Steeper (many inputs) | Gentler (one action at a time) |
| **Debugging** | Harder (black box) | Easier (see each step) |
| **Testing** | Test everything together | Test each action independently |
| **Reusability** | All-or-nothing | Mix and match |
| **Secrets** | Auto-discovered | Explicit passing |
| **Maintenance** | One large action | Multiple small actions |
| **Versioning** | Single version | Independent versions |
| **Custom workflows** | Limited | Full control |
| **Error messages** | Which part failed? | Clear step failure |

---

## Analysis

### When Monolithic Works Well

✅ **Highly standardized workflows**
- All lectures follow exact same pattern
- No variation needed
- "One true way" to deploy

✅ **Simple projects**
- Single deploy target (only Netlify OR GitHub Pages)
- No custom steps needed
- Quick to get started

✅ **Minimal maintenance**
- Updates happen centrally
- Users don't need to understand components

**Example use case:** Corporate product with strict standards, no customization needed.

---

### When Modular Works Well

✅ **Varied workflows**
- Some lectures deploy to Netlify, others to GitHub Pages
- Some build PDF, others don't
- Different preview/production strategies

✅ **Custom steps needed**
- Post-processing after build
- Custom deployment logic
- Integration with other tools

✅ **Debugging and development**
- Easy to test one action at a time
- Clear what failed
- Can swap implementations

✅ **Progressive adoption**
- Start with just build action
- Add deployment later
- Gradually improve

**Example use case:** Research project with diverse needs, community contributions.

---

## Recommendation: **Modular with Optional Convenience Action**

### Best of Both Worlds

**Create both:**

1. **Core modular actions** (main approach)
   - `build-lectures` - Build with caching
   - `deploy-netlify` - Netlify deployment
   - `publish-gh-pages` - GitHub Pages deployment
   - `build-pdf` - PDF generation

2. **Convenience "preset" action** (optional shortcut)
   - `lecture-pipeline` - Common pattern pre-configured
   - Composes the modular actions internally
   - Good default for simple cases

### Implementation

#### Core Modular Actions (Primary)

```yaml
# Recommended: Full control
jobs:
  build-and-deploy:
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build lectures
        uses: quantecon/actions/build-lectures@main
        id: build
      
      - name: Deploy preview
        if: github.event_name == 'pull_request'
        uses: quantecon/actions/deploy-netlify@main
        with:
          site-id: ${{ vars.NETLIFY_SITE_ID }}
          auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          publish-dir: lectures/_build/html
          alias: pr-${{ github.event.number }}
      
      - name: Deploy production
        if: github.ref == 'refs/heads/main'
        uses: quantecon/actions/deploy-netlify@main
        with:
          site-id: ${{ vars.NETLIFY_SITE_ID }}
          auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          publish-dir: lectures/_build/html
          production: true
```

#### Convenience Preset Action (Optional)

```yaml
# lecture-pipeline/action.yml
name: 'Lecture Pipeline'
description: 'Complete build and deploy pipeline (convenience wrapper)'

inputs:
  # Build
  lecture-dir:
    default: 'lectures'
  
  # Netlify
  netlify-site-id:
    description: 'Netlify site ID'
    required: false
  netlify-deploy-preview:
    default: 'true'
  netlify-deploy-production:
    default: 'true'
  
  # GitHub Pages
  gh-pages-enabled:
    default: 'false'

runs:
  using: "composite"
  steps:
    - uses: quantecon/actions/build-lectures@main
      id: build
      with:
        lecture-dir: ${{ inputs.lecture-dir }}
    
    - uses: quantecon/actions/deploy-netlify@main
      if: inputs.netlify-site-id != '' && github.event_name == 'pull_request' && inputs.netlify-deploy-preview == 'true'
      with:
        site-id: ${{ inputs.netlify-site-id }}
        auth-token: ${{ env.NETLIFY_AUTH_TOKEN }}  # Expected in environment
        publish-dir: ${{ steps.build.outputs.build-path }}
        alias: pr-${{ github.event.number }}
    
    # ... etc
```

**Usage of convenience action:**
```yaml
# For simple cases
steps:
  - uses: actions/checkout@v4
  - uses: quantecon/actions/lecture-pipeline@main
    env:
      NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
    with:
      netlify-site-id: ${{ vars.NETLIFY_SITE_ID }}
```

---

## Why Modular is Better for QuantEcon

### 1. Diverse Deployment Needs

Not all lectures have same deployment:
- Some use Netlify preview + production
- Some use GitHub Pages
- Some deploy to custom servers
- Some want PDF artifacts only

**Modular allows:** Each repo chooses what it needs.

### 2. Progressive Enhancement

Lectures can start simple and add complexity:
```yaml
# Week 1: Just build
- uses: quantecon/actions/build-lectures@main

# Week 2: Add Netlify preview
- uses: quantecon/actions/build-lectures@main
- uses: quantecon/actions/deploy-netlify@main
  if: github.event_name == 'pull_request'

# Week 3: Add production deploy
- uses: quantecon/actions/deploy-netlify@main
  if: github.ref == 'refs/heads/main'
  with:
    production: true
```

### 3. Clear Responsibility

Each action has one job:
- **build-lectures**: Build and cache
- **deploy-netlify**: Netlify deployment
- **publish-gh-pages**: GitHub Pages

Easy to:
- Understand what each does
- Debug when something fails
- Replace one without affecting others

### 4. Community Contributions

Modular actions are easier for community:
- Understand one action at a time
- Contribute improvements to specific action
- Test changes in isolation
- Document each action separately

### 5. Mix and Match

Different lectures can compose differently:
```yaml
# Lecture A: Netlify only
- uses: quantecon/actions/build-lectures@main
- uses: quantecon/actions/deploy-netlify@main

# Lecture B: GitHub Pages only
- uses: quantecon/actions/build-lectures@main
- uses: quantecon/actions/publish-gh-pages@main

# Lecture C: Both!
- uses: quantecon/actions/build-lectures@main
- uses: quantecon/actions/deploy-netlify@main
- uses: quantecon/actions/publish-gh-pages@main
```

### 6. Better Error Messages

When deployment fails, you immediately know which action:
```
❌ deploy-netlify failed: Authentication token invalid
✅ build-lectures succeeded
```

vs monolithic:
```
❌ lecture-pipeline failed: (which step?)
```

### 7. Independent Versioning

Can update deployment logic without rebuilding:
```yaml
- uses: quantecon/actions/build-lectures@v1.2.0
- uses: quantecon/actions/deploy-netlify@v2.0.0  # New version!
```

vs monolithic forces everything to update together.

---

## Workflow Length Concerns

**Your concern:** "trying to minimise the ci.yml workflow"

**Reality check:**

Modular approach (current best practice):
```yaml
jobs:
  build-and-deploy:
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/build-lectures@main
        id: build
      - uses: quantecon/actions/deploy-netlify@main
        if: github.event_name == 'pull_request'
        with:
          site-id: ${{ vars.NETLIFY_SITE_ID }}
          auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          publish-dir: ${{ steps.build.outputs.build-path }}
          alias: pr-${{ github.event.number }}
```
**~15 lines** - clear, explicit, debuggable

Monolithic approach:
```yaml
jobs:
  build-and-deploy:
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      - uses: quantecon/actions/lecture-pipeline@main
        env:
          NETLIFY_AUTH_TOKEN: ${{ secrets.NETLIFY_AUTH_TOKEN }}
        with:
          netlify-site-id: ${{ vars.NETLIFY_SITE_ID }}
          netlify-deploy-preview: 'true'
          netlify-deploy-production: 'auto'
          gh-pages-enabled: 'false'
```
**~12 lines** - shorter but less clear

**Difference: 3 lines**

Is saving 3 lines worth:
- ❌ Less flexibility
- ❌ Harder debugging  
- ❌ Black box behavior
- ❌ All-or-nothing updates

**Answer: No.** The brevity is not worth the trade-offs.

---

## GitHub Actions Community Standards

**Standard practice:** Modular, composable actions

**Examples from popular projects:**

```yaml
# Rust projects
- uses: actions/checkout@v4
- uses: actions-rs/toolchain@v1
- uses: actions-rs/cargo@v1
- uses: codecov/codecov-action@v3

# Node projects
- uses: actions/checkout@v4
- uses: actions/setup-node@v4
- uses: actions/cache@v4
- uses: netlify/actions/cli@master

# Python projects
- uses: actions/checkout@v4
- uses: actions/setup-python@v5
- uses: actions/cache@v4
- uses: pypa/gh-action-pypi-publish@release/v1
```

**Pattern:** Small, focused actions composed together.

**Why:** This is the GitHub Actions model. Fighting it creates friction.

---

## Recommended Architecture

### Core Actions (Modular)

1. **build-lectures** (already designed)
   - Builds with Jupyter Book
   - Handles caching
   - Uploads artifacts

2. **deploy-netlify** (existing, maybe improve)
   - Takes publish-dir input
   - Handles auth
   - Supports preview/production

3. **publish-gh-pages** (existing)
   - Deploys to GitHub Pages
   - Handles branch management

### Standard Workflow Template

Create a **template workflow** in docs:

```yaml
# docs/workflows/standard-ci.yml (template)
name: Build and Deploy
on: [pull_request, push]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    container:
      image: ghcr.io/quantecon/quantecon:latest
      credentials:
        username: ${{ github.actor }}
        password: ${{ secrets.GITHUB_TOKEN }}
    
    steps:
      - uses: actions/checkout@v4
      
      # Build
      - name: Build lectures
        uses: quantecon/actions/build-lectures@main
        id: build
      
      # Deploy preview to Netlify (PRs)
      - name: Deploy preview
        if: github.event_name == 'pull_request'
        uses: quantecon/actions/deploy-netlify@main
        with:
          site-id: ${{ vars.NETLIFY_SITE_ID }}
          auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          publish-dir: ${{ steps.build.outputs.build-path }}
          alias: pr-${{ github.event.number }}
      
      # Deploy production to Netlify (main branch)
      - name: Deploy production
        if: github.ref == 'refs/heads/main'
        uses: quantecon/actions/deploy-netlify@main
        with:
          site-id: ${{ vars.NETLIFY_SITE_ID }}
          auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          publish-dir: ${{ steps.build.outputs.build-path }}
          production: true
```

**Instructions:** Copy this template, customize as needed.

**Benefits:**
- Standard starting point
- Easy to understand
- Easy to customize
- Shows best practices

---

## Decision Matrix

| Criterion | Monolithic | Modular | Winner |
|-----------|-----------|---------|---------|
| Workflow brevity | 10-12 lines | 15-20 lines | Monolithic |
| Clarity | Lower | Higher | **Modular** ✅ |
| Flexibility | Limited | Full | **Modular** ✅ |
| Debuggability | Harder | Easier | **Modular** ✅ |
| Testability | Monolithic | Isolated | **Modular** ✅ |
| Maintainability | Single large file | Small focused files | **Modular** ✅ |
| Community standard | Rare | Common | **Modular** ✅ |
| Learning curve | Steeper | Gentler | **Modular** ✅ |
| Customization | Via inputs | Via workflow | **Modular** ✅ |
| Error clarity | Unclear | Clear | **Modular** ✅ |

**Score: Modular wins 9-1**

---

## Final Recommendation

### ✅ Use Modular Actions

**Create:**
1. Core modular actions (build, deploy-netlify, publish-gh-pages)
2. Standard workflow template in docs
3. Clear documentation for each action

**Don't create:**
- ❌ Monolithic "super action"
- ❌ Overly complex convenience wrappers

**Why:**
- Follows GitHub Actions best practices
- More maintainable (small focused actions)
- More flexible (compose as needed)
- Better debugging (clear failures)
- Easier community contributions
- Standard patterns reduce cognitive load

**The 3-line difference in workflow length is not worth the loss of clarity, flexibility, and maintainability.**

### Implementation

Keep your existing modular structure:
- ✅ `build-lectures/` - Build and cache
- ✅ `deploy-netlify/` - Netlify deployment  
- ✅ `publish-gh-pages/` - GitHub Pages
- ✅ `setup-latex/` - LaTeX setup (deprecated by container)

Add standard workflow templates in docs for easy copy-paste.

---

## Example: How It Looks In Practice

### Typical Lecture Repo

```yaml
# lecture-python-intro/.github/workflows/ci.yml
name: Build and Deploy
on: [pull_request, push]

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    container: ghcr.io/quantecon/quantecon:latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/build-lectures@main
        id: build
      
      - uses: quantecon/actions/deploy-netlify@main
        if: github.event_name == 'pull_request'
        with:
          site-id: ${{ vars.NETLIFY_SITE_ID }}
          auth-token: ${{ secrets.NETLIFY_AUTH_TOKEN }}
          publish-dir: lectures/_build/html
          alias: pr-${{ github.event.number }}
```

**This is:**
- ✅ Clear (can see exactly what happens)
- ✅ Flexible (easy to add/remove steps)
- ✅ Debuggable (know which action failed)
- ✅ Standard (follows GitHub Actions patterns)
- ✅ Maintainable (update actions independently)

**18 lines total - perfectly reasonable for a CI/CD workflow.**

---

## Conclusion

**Stick with modular actions.**

The small increase in workflow length (3-5 lines) is far outweighed by the benefits of clarity, flexibility, maintainability, and following industry best practices.

Provide good documentation and templates to make it easy to get started, but keep the actions focused and composable.
