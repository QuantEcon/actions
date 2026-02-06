# Container Validation Results

This document records validation test results for the QuantEcon containers across all lecture repositories and build types.

## Containers

| Container | Image | Size | Description |
|-----------|-------|------|-------------|
| **quantecon** (full) | `ghcr.io/quantecon/quantecon:latest` | ~8GB | Full Anaconda + TexLive |
| **quantecon-build** (lean) | `ghcr.io/quantecon/quantecon-build:latest` | ~3GB | Miniconda + minimal TexLive |

## Lecture Repositories

| Repository | Lectures | Notes |
|-----------|----------|-------|
| `lecture-python-intro` | 46 | Standard, Netlify deployment |
| `lecture-python-programming.myst` | ~40 | Standard, GitHub Pages |
| `lecture-python-advanced.myst` | ~50 | Standard, GitHub Pages |
| `lecture-python.myst` | ~80 | GPU lectures, GitHub Pages |

---

## 6 February 2026

**Test workflow:** [`test-containers-lectures.yml`](../.github/workflows/test-containers-lectures.yml)

**Matrix:** 2 containers × 4 repos × 3 builders = 24 jobs

### Results: 24/24 passing

| Builder | Repository | quantecon-build (lean) | quantecon (full) |
|---------|-----------|:---:|:---:|
| **html** | lecture-python-intro | ✅ 12m | ✅ 13m |
| | lecture-python-programming.myst | ✅ 5m | ✅ 5m |
| | lecture-python-advanced.myst | ✅ 34m | ✅ 36m |
| | lecture-python.myst | ✅ 58m | ✅ 100m |
| **pdflatex** | lecture-python-intro | ✅ 14m | ✅ 14m |
| | lecture-python-programming.myst | ✅ 6m | ✅ 7m |
| | lecture-python-advanced.myst | ✅ 36m | ✅ 38m |
| | lecture-python.myst | ✅ 62m | ✅ 63m |
| **jupyter** | lecture-python-intro | ✅ 12m | ✅ 12m |
| | lecture-python-programming.myst | ✅ 4m | ✅ 5m |
| | lecture-python-advanced.myst | ✅ 34m | ✅ 35m |
| | lecture-python.myst | ✅ 58m | ✅ 58m |

### Run Links

- **Full matrix (24 jobs):** [Run 21733415254](https://github.com/QuantEcon/actions/actions/runs/21733415254)
  - Initial run: 22/24 passed. 2 failures were `pdflatex · lecture-python-advanced.myst` on both containers due to upstream content issue (`text/html` mime type warning in `knowing_forecasts_of_others.md` with `-W` warnings-as-errors).
- **Re-run after upstream fix (2 jobs):** [Run 21737474016](https://github.com/QuantEcon/actions/actions/runs/21737474016)
  - Both `pdflatex · lecture-python-advanced.myst` jobs passed after upstream fix.

### Notes

- Build times are approximate (rounded to nearest minute, measured from job start to completion).
- The lean container (`quantecon-build`) performs comparably to the full container across all builders and repos.
- `lecture-python.myst` HTML build is significantly slower on the full container (~100m vs ~58m on lean) — likely due to conda solver overhead with the larger Anaconda environment during package installation.
- All builds use Jupyter Book 1.0.4post1, Python 3.13, and XeLaTeX for PDF output.
