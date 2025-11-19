# Documentation Index

This directory contains documentation for the QuantEcon Actions project.

---

## 📋 Implementation Documents (Start Here)

### [ARCHITECTURE-SUMMARY.md](./ARCHITECTURE-SUMMARY.md)
**Overview of the finalized three-pillar architecture:**
- 🐳 Containerized Environment (Docker + GHCR)
- 🧩 Modular Actions (build, deploy-netlify, publish-gh-pages)
- 💾 Two-Layer Caching (environment + build)

**Read this first** to understand the overall approach and design decisions.

### [NEXT-STEPS-CONTAINERS.md](./NEXT-STEPS-CONTAINERS.md)
**Week-by-week implementation roadmap:**
- Week 1: Container infrastructure
- Week 2: Testing with one lecture
- Week 3: Documentation
- Week 4-5: Rollout to all lectures

**Use this** as your implementation guide with code samples and tasks.

---

## 📚 Existing Documentation

### [SETUP.md](./SETUP.md)
Setup and configuration guide for current actions (pre-container).

### [MIGRATION-GUIDE.md](./MIGRATION-GUIDE.md)
Guide for migrating lecture repositories to use the unified actions.

### [QUICK-REFERENCE.md](./QUICK-REFERENCE.md)
Quick reference for common tasks and patterns.

---

## 📦 Archive

### [archive/](./archive/)
Detailed analysis and historical documents:
- Container architecture options explored
- UV vs Conda/Mamba comparison
- Modular vs monolithic action design analysis
- Previous optimization work (cache optimization phase)

**See:** [archive/README.md](./archive/README.md) for details on archived documents.

---

## 🚀 Getting Started

1. **Understand the architecture:** Read [ARCHITECTURE-SUMMARY.md](./ARCHITECTURE-SUMMARY.md)
2. **Start implementing:** Follow [NEXT-STEPS-CONTAINERS.md](./NEXT-STEPS-CONTAINERS.md)
3. **Reference archived analysis:** Check [archive/](./archive/) if you need deeper context

---

## Document Status

| Document | Status | Purpose |
|----------|--------|---------|
| ARCHITECTURE-SUMMARY.md | ✅ Current | Final architecture overview |
| NEXT-STEPS-CONTAINERS.md | ✅ Current | Implementation roadmap |
| SETUP.md | 🔄 Active | Current setup guide |
| MIGRATION-GUIDE.md | 🔄 Active | Migration instructions |
| QUICK-REFERENCE.md | 🔄 Active | Quick reference |
| archive/* | 📦 Archived | Design analysis documents |

---

**Last Updated:** 19 November 2025
