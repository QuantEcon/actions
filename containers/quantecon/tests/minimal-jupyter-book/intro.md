---
jupytext:
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
kernelspec:
  display_name: Python 3
  language: python
  name: python3
---

# Introduction

Minimal book used to smoke-test a QuantEcon container image. Every code block
below is a `{code-cell}`, not a fenced snippet, so it actually runs during the
build and a broken image fails it.

Each cell **asserts** rather than merely printing. A cell that imports cleanly
but computes the wrong answer is exactly the sort of breakage a smoke test
should catch, and printing alone would not.

## Math Test

Here is a simple equation:

$$
E = mc^2
$$

## Numerical stack

```{code-cell} python3
import numpy as np
import scipy.linalg as sla

A = np.array([[2.0, 1.0], [1.0, 3.0]])
eigvals = np.sort(sla.eigvalsh(A))

# Exact: (5 ± √5)/2
expected = np.sort([(5 - np.sqrt(5)) / 2, (5 + np.sqrt(5)) / 2])
assert np.allclose(eigvals, expected), f"eigenvalues wrong: {eigvals} != {expected}"
print(f"numpy {np.__version__}: eigenvalues {eigvals}")
```

## Dataframes

```{code-cell} python3
import pandas as pd

df = pd.DataFrame({"g": ["a", "a", "b"], "x": [1.0, 3.0, 5.0]})
means = df.groupby("g")["x"].mean()

assert means["a"] == 2.0 and means["b"] == 5.0, f"groupby wrong: {means.to_dict()}"
print(f"pandas {pd.__version__}: group means {means.to_dict()}")
```

## Matplotlib rendering

Renders to a real PNG buffer rather than just constructing a figure — that is
what exercises the backend and the font stack.

```{code-cell} python3
import io
import matplotlib
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(4, 2))
ax.plot(np.linspace(0, 1, 50), np.linspace(0, 1, 50) ** 2)
ax.set_title("smoke test")

buf = io.BytesIO()
fig.savefig(buf, format="png")
png = buf.getvalue()

assert png.startswith(b"\x89PNG"), "matplotlib did not produce a PNG"
assert len(png) > 1000, f"matplotlib PNG suspiciously small ({len(png)} bytes)"
print(f"matplotlib {matplotlib.__version__}: rendered {len(png)} byte PNG")
plt.close(fig)
```

## Plotly static export (kaleido → chromium)

The highest-value cell here. This is the path that broke in #85: kaleido v1
dropped its bundled chromium, and because a GitHub Actions `container:` job
forces `HOME=/github/home` rather than `/root`, a chromium provisioned under
`/root` at image build time became unreachable at run time. Both images pin
`kaleido<1.0` for exactly that reason — this cell is what would notice if the
pin were lost or the resolved chromium moved again.

```{code-cell} python3
import plotly
import plotly.graph_objects as go

fig = go.Figure(go.Scatter(x=[1, 2, 3], y=[1, 4, 9]))
img = fig.to_image(format="png")

assert img.startswith(b"\x89PNG"), "plotly/kaleido did not produce a PNG"
assert len(img) > 1000, f"plotly PNG suspiciously small ({len(img)} bytes)"
print(f"plotly {plotly.__version__}: kaleido exported {len(img)} byte PNG")
```
