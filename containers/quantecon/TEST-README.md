# Container Testing

This directory contains tests for the QuantEcon container to verify LaTeX and Jupyter Book functionality.

## Test Files

- `test-xelatex.tex` - Minimal XeLaTeX document for testing font support and compilation
- `minimal-jupyter-book/` - Minimal Jupyter Book project for testing HTML and PDF builds
- `test-container.sh` - Automated test script that runs all tests

## Running Tests

To run all tests:

```bash
cd containers/quantecon
./test-container.sh
```

The script will:
1. Pull the latest container from GHCR
2. Test XeLaTeX compilation with fontspec and unicode
3. Test Jupyter Book HTML build
4. Test Jupyter Book PDF build via pdflatex

## Manual Testing

Test XeLaTeX:
```bash
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  xelatex test-xelatex.tex
```

Test Jupyter Book HTML:
```bash
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "cd minimal-jupyter-book && jb build . --builder html"
```

Test Jupyter Book PDF:
```bash
docker run --rm -v $(pwd):/workspace -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "cd minimal-jupyter-book && jb build . --builder pdflatex"
```

## Expected Output

All tests should complete successfully with:
- `test-xelatex.pdf` generated
- `minimal-jupyter-book/_build/html/` directory with HTML output
- `minimal-jupyter-book/_build/latex/test-book.pdf` generated
