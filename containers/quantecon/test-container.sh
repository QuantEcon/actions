#!/bin/bash
# Test script for QuantEcon container
# Verifies LaTeX and Jupyter Book functionality

set -e  # Exit on any error

echo "=================================================="
echo "QuantEcon Container Test Suite"
echo "=================================================="
echo ""

# Test 1: Pull latest container
echo "Test 1: Pulling latest container..."
docker pull ghcr.io/quantecon/quantecon:latest
echo "✓ Container pulled successfully"
echo ""

# Test 2: XeLaTeX compilation test
echo "Test 2: Testing XeLaTeX compilation..."
docker run --rm -v "$(pwd)":/workspace -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "cd /workspace && xelatex test-xelatex.tex && ls -lh test-xelatex.pdf"
echo "✓ XeLaTeX compilation successful"
echo ""

# Test 3: Jupyter Book HTML build
echo "Test 3: Testing Jupyter Book HTML build..."
docker run --rm -v "$(pwd)":/workspace -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "cd /workspace/minimal-jupyter-book && jb build . --builder html"
echo "✓ Jupyter Book HTML build successful"
echo ""

# Test 4: Jupyter Book PDF build (via LaTeX)
echo "Test 4: Testing Jupyter Book PDF build..."
docker run --rm -v "$(pwd)":/workspace -w /workspace \
  ghcr.io/quantecon/quantecon:latest \
  bash -c "cd /workspace/minimal-jupyter-book && jb build . --builder pdflatex && ls -lh _build/latex/*.pdf"
echo "✓ Jupyter Book PDF build successful"
echo ""

echo "=================================================="
echo "All tests passed! ✓"
echo "=================================================="
