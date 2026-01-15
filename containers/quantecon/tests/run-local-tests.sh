#!/bin/bash
# Local test script for replicating container tests on macOS ARM
# Run from the tests/ directory

set -e

echo "=============================================="
echo "LOCAL TEST SUITE"
echo "=============================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v xelatex >/dev/null 2>&1 || { echo "ERROR: xelatex not found. Install MacTeX."; exit 1; }
command -v jupyter-book >/dev/null 2>&1 || { echo "ERROR: jupyter-book not found. Install with: pip install jupyter-book"; exit 1; }
command -v fc-list >/dev/null 2>&1 || { echo "WARNING: fc-list not found. Install fontconfig with: brew install fontconfig"; }

echo "✓ xelatex found: $(xelatex --version | head -1)"
echo "✓ jupyter-book found: $(jupyter-book --version)"
echo ""

# Check for DejaVu Serif fonts (used by test-xelatex.tex)
echo "Checking for DejaVu Serif fonts..."
if fc-list 2>/dev/null | grep -i "dejavu serif" >/dev/null; then
    echo "✓ DejaVu Serif fonts found"
else
    echo "⚠ DejaVu Serif fonts NOT found. Install with: brew install --cask font-dejavu"
fi
echo ""

# Test 1: Standalone XeLaTeX with DejaVu Serif
echo "============================================="
echo "TEST 1: Standalone XeLaTeX Compilation"
echo "============================================="
cd "$(dirname "$0")"
rm -f test-xelatex.{pdf,log,aux,synctex.gz}

if xelatex test-xelatex.tex 2>&1 | tee /tmp/local-xelatex-test.log; then
    if [ -f test-xelatex.pdf ]; then
        echo "✅ SUCCESS: test-xelatex.pdf created ($(ls -lh test-xelatex.pdf | awk '{print $5}'))"
        open test-xelatex.pdf
    else
        echo "❌ FAILURE: PDF not created"
        exit 1
    fi
else
    echo "❌ FAILURE: XeLaTeX compilation failed"
    grep -i "error\|cannot be found" /tmp/local-xelatex-test.log || true
    exit 1
fi
echo ""

# Test 2: Jupyter Book HTML build
echo "=============================================="
echo "TEST 2: Jupyter Book HTML build"
echo "=============================================="
cd minimal-jupyter-book
rm -rf _build

if jb build . --builder html 2>&1 | tee /tmp/local-jb-html.log; then
    echo "✅ SUCCESS: HTML build completed"
    ls -lh _build/html/index.html
else
    echo "❌ FAILURE: HTML build failed"
    exit 1
fi
echo ""

# Test 3: Jupyter Book PDF build
echo "=============================================="
echo "TEST 3: Jupyter Book PDF build"
echo "=============================================="
if jb build . --builder pdflatex 2>&1 | tee /tmp/local-jb-pdf.log; then
    echo "✅ SUCCESS: PDF build completed"
    ls -lh _build/latex/*.pdf
    open _build/latex/*.pdf
else
    echo "❌ FAILURE: PDF build failed"
    echo ""
    echo "Error context:"
    grep -B 5 -A 5 -i "error\|cannot be found\|freeserif" /tmp/local-jb-pdf.log || true
    exit 1
fi

echo ""
echo "=============================================="
echo "ALL TESTS COMPLETED"
echo "=============================================="
echo "Logs saved to:"
echo "  - /tmp/local-xelatex-test.log"
echo "  - /tmp/local-jb-html.log"
echo "  - /tmp/local-jb-pdf.log"
