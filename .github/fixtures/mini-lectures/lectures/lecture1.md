---
jupytext:
  text_representation:
    extension: .md
    format_name: myst
    format_version: 0.13
kernelspec:
  display_name: Python 3 (ipykernel)
  language: python
  name: python3
---

# An Executed Lecture

This lecture contains a real executed code cell so that
`execute_notebooks: cache` populates `_build/.jupyter_cache` during the build.

```{code-cell} python3
values = [n ** 2 for n in range(10)]
total = sum(values)
print(f"sum of squares: {total}")
assert total == 285
```
