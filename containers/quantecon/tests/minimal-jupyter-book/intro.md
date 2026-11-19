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
import numpy as np  # imported here too: keeps a failure here attributable to matplotlib

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

## Plotly static export (kaleido → Chrome)

The highest-value cell here. kaleido 1 bundles no browser: it drives a Chrome
it has to find. This is the path that broke in #85: a GitHub Actions
`container:` job forces `HOME=/github/home` rather than `/root`, so a Chrome
provisioned under `/root` at image build time was unreachable at run time.
Each image now installs Chrome at a fixed path and names it in `BROWSER_PATH`
(#342).

In an image, the cell first checks that the export goes through that Chrome.
On its own the export would also pass with kaleido 0.2's bundled browser, or
with a Chrome fetched under the build's `HOME`. A job with another `HOME`
would not find that Chrome, but `docker run`, which keeps the build's `/root`,
would. Outside an image, as in `run-local-tests.sh`, kaleido uses whatever
Chrome it finds.

```{code-cell} python3
import os
from importlib.metadata import version

if os.path.exists("/etc/quantecon-container"):
    # The pin in both images' environment.yml: a kaleido bump changes it here too.
    assert version("kaleido") == "1.5.2", f"kaleido {version('kaleido')}, expected 1.5.2"

    from choreographer.browsers.chromium import Chromium
    from choreographer.cli.defaults import default_download_path

    browser = os.environ.get("BROWSER_PATH", "")
    assert browser and os.access(browser, os.X_OK), f"BROWSER_PATH=[{browser}] is not an executable"
    found = Chromium.find_browser(skip_local=False)
    assert found == browser, f"kaleido would launch [{found}], not BROWSER_PATH [{browser}]"
    # Where kaleido_get_chrome downloads to, and where kaleido looks first.
    assert not default_download_path.parent.exists(), f"a Chrome download directory exists: {default_download_path.parent}"
    print(f"kaleido {version('kaleido')}: Chrome at {browser}")

import plotly
import plotly.graph_objects as go

fig = go.Figure(go.Scatter(x=[1, 2, 3], y=[1, 4, 9]))
img = fig.to_image(format="png")

assert img.startswith(b"\x89PNG"), "plotly/kaleido did not produce a PNG"
assert len(img) > 1000, f"plotly PNG suspiciously small ({len(img)} bytes)"
print(f"plotly {plotly.__version__}: kaleido exported {len(img)} byte PNG")
```
