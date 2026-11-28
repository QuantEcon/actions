---
kernelspec:
  name: python3
  display_name: Python 3
---

# An Executed Lecture

A real code cell, so that the site shows its output only if `myst build --execute` ran it.

```{code-cell} python3
values = [n ** 2 for n in range(10)]
total = sum(values)
print(f"sum of squares: {total}")
assert total == 285
```
