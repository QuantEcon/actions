#!/bin/bash
# Check available LaTeX package versions on GitHub Actions runner
# Run this on ubuntu-latest to get current versions for latex-requirements.txt

echo "=== LaTeX Package Versions on $(lsb_release -d | cut -f2) ==="
echo ""

packages=(
  "texlive-latex-recommended"
  "texlive-latex-extra"
  "texlive-fonts-recommended"
  "texlive-fonts-extra"
  "texlive-xetex"
  "texlive-luatex"
  "latexmk"
  "xindy"
  "dvipng"
  "ghostscript"
  "cm-super"
)

echo "Updating package cache..."
sudo apt-get update -qq

echo ""
echo "Available versions:"
echo "-------------------"

for pkg in "${packages[@]}"; do
  version=$(apt-cache policy "$pkg" 2>/dev/null | grep Candidate | awk '{print $2}')
  if [ -n "$version" ]; then
    printf "%-30s %s\n" "$pkg" "$version"
  else
    printf "%-30s %s\n" "$pkg" "NOT FOUND"
  fi
done

echo ""
echo "To update latex-requirements.txt, copy the output above and add ="
echo "Example: texlive-latex-recommended=2023.20240207-1"
