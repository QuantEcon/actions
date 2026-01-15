# Repository Setup Guide

This guide walks through setting up the `quantecon/actions` repository on GitHub.

## 📋 Repository Creation Checklist

### Step 1: Create GitHub Repository

1. **Go to GitHub:** https://github.com/organizations/quantecon/repositories/new

2. **Repository settings:**
   - Repository name: `actions`
   - Description: `Reusable GitHub Actions for QuantEcon lecture builds`
   - Visibility: **Public** (required for GitHub Actions marketplace)
   - Initialize: **Don't** initialize with README (we have one)

3. **Create repository**

### Step 2: Initialize Local Repository

```bash
# Navigate to the actions directory
cd /Users/mmcky/work/quantecon/actions

# Initialize git repository
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: QuantEcon Actions v1.0.0

- setup-environment: Flexible environment with Conda, LaTeX, ML libs
- build-lectures: Jupyter Book builds with caching
- deploy-netlify: Netlify PR preview deployment
- publish-gh-pages: GitHub Pages publishing

Includes comprehensive documentation, testing strategy, and migration guide."

# Add remote
git remote add origin https://github.com/quantecon/actions.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Create Initial Release

```bash
# Create version tags
git tag -a v1.0.0 -m "Release v1.0.0 - Initial stable release"
git tag -a v1 -m "Major version v1"

# Push tags
git push origin v1.0.0
git push origin v1
```

### Step 4: Create GitHub Release

1. **Go to:** https://github.com/quantecon/actions/releases/new

2. **Release settings:**
   - Tag: `v1.0.0`
   - Release title: `v1.0.0 - Initial Release`
   - Description:
   
   ```markdown
   # QuantEcon Actions v1.0.0
   
   First stable release of QuantEcon composite actions for building and deploying lecture materials.
   
   ## 🎯 Actions Included
   
   - **setup-environment** - Flexible Conda/LaTeX/ML environment setup with caching
   - **build-lectures** - Jupyter Book builds with execution caching
   - **deploy-netlify** - Netlify PR preview deployment with smart comments
   - **publish-gh-pages** - GitHub Pages publishing
   
   ## 📊 Performance Improvements
   
   - **Conda setup:** ~5-6 min saved (with cache)
   - **Container setup:** ~2 min total (vs 7-8 min without)
   - **Total savings:** 5-6 minutes per workflow
   
   ## 📚 Documentation
   
   - [README.md](README.md) - Documentation index
   - [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture overview
   - [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) - Step-by-step migration
   - [QUICK-REFERENCE.md](QUICK-REFERENCE.md) - Cheat sheet
   - Individual action READMEs with detailed usage
   
   ## 🚀 Quick Start
   
   See [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md) for converting existing workflows.
   
   ## ✅ Tested On
   
   - lecture-python.myst
   - lecture-python-programming.myst  
   - lecture-python-intro
   - lecture-python-advanced.myst
   ```

3. **Publish release**

### Step 5: Repository Settings

#### General Settings

1. **Features:**
   - ✅ Issues
   - ✅ Discussions (optional)
   - ❌ Projects (not needed)
   - ❌ Wiki (use docs instead)

2. **Pull Requests:**
   - ✅ Allow squash merging
   - ✅ Allow merge commits
   - ❌ Allow rebase merging
   - ✅ Always suggest updating PR branches
   - ✅ Automatically delete head branches

#### Branch Protection (main)

1. **Go to:** Settings → Branches → Add rule

2. **Settings:**
   - Branch name pattern: `main`
   - ✅ Require pull request before merging
   - ✅ Require approvals: 1
   - ✅ Dismiss stale approvals
   - ✅ Require status checks (if CI added)
   - ❌ Require signed commits (optional)
   - ❌ Require linear history (optional)
   - ✅ Include administrators

#### Topics

Add repository topics for discoverability:
- `github-actions`
- `composite-actions`
- `quantecon`
- `jupyter-book`
- `conda`
- `latex`
- `netlify`
- `github-pages`

### Step 6: Add Secrets (For Testing)

If setting up test workflows in this repo:

1. **NETLIFY_AUTH_TOKEN** - From Netlify account settings
2. **NETLIFY_SITE_ID** - From test Netlify site

### Step 7: Add Collaborators

1. **Go to:** Settings → Collaborators and teams

2. **Add team:** `quantecon/core` with **Admin** access

3. **Individual collaborators:** As needed with appropriate permissions

## 📦 Repository Structure

After setup, structure should be:

```
quantecon/actions/
├── .github/
│   └── workflows/
│       └── build-containers.yml
├── .gitignore
├── LICENSE
├── README.md
├── containers/
│   └── quantecon/
│       ├── Dockerfile
│       ├── environment.yml
│       └── README.md
├── docs/
│   ├── ARCHITECTURE.md
│   ├── CONTAINER-GUIDE.md
│   ├── MIGRATION-GUIDE.md
│   └── QUICK-REFERENCE.md
├── setup-environment/
│   ├── action.yml
│   └── README.md
├── build-lectures/
│   ├── action.yml
│   └── README.md
├── deploy-netlify/
│   ├── action.yml
│   └── README.md
└── publish-gh-pages/
    ├── action.yml
    └── README.md
```

## 🔄 Next Steps

1. **Test in lecture repositories:**
   - Start with `lecture-python-programming.myst` (simplest)
   - Validate caching behavior
   - Measure performance improvements

2. **Migrate lecture repositories:**
   - Follow [MIGRATION-GUIDE.md](MIGRATION-GUIDE.md)
   - One repository at a time
   - Monitor for issues
   - Document any problems

3. **Gather feedback:**
   - Monitor workflow execution times
   - Check cache hit rates
   - Collect user feedback
   - Track any issues

4. **Iterate and improve:**
   - Address issues found during migration
   - Optimize based on real-world usage
   - Update documentation as needed
   - Plan v1.1.0 features

## 📞 Support

After repository setup:
- **Issues:** https://github.com/quantecon/actions/issues
- **Discussions:** https://github.com/quantecon/actions/discussions
- **Docs:** https://github.com/quantecon/actions#readme

## ✅ Verification Checklist

Before considering setup complete:

- [ ] Repository created on GitHub
- [ ] All files committed and pushed
- [ ] Tags created (v1.0.0, v1)
- [ ] GitHub release published
- [ ] Branch protection configured
- [ ] Topics added for discoverability
- [ ] Team access configured
- [ ] README displays correctly on GitHub
- [ ] All action READMEs render properly
- [ ] Links in documentation work
- [ ] Actions show up in repository actions tab

## 🎉 Success Criteria

Setup is successful when:

1. ✅ Repository accessible at https://github.com/quantecon/actions
2. ✅ Release v1.0.0 published
3. ✅ Documentation renders correctly
4. ✅ Actions can be referenced: `quantecon/actions/ACTION@v1`
5. ✅ Ready for testing in lecture repositories

---

**Created:** November 2024  
**Updated:** January 2026  
**Version:** 1.0.0  
**Maintainer:** QuantEcon Team
