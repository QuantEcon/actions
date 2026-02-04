FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and LaTeX
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Core LaTeX distribution (latest from Ubuntu 24.04 repos)
        texlive-latex-recommended \
        texlive-latex-extra \
        texlive-fonts-recommended \
        texlive-fonts-extra \
        texlive-xetex \
        texlive-luatex \
        # Build tools
        latexmk \
        xindy \
        dvipng \
        ghostscript \
        cm-super \
        make \
        # Additional utilities
        git \
        curl \
        ca-certificates \
        # FreeSerif fonts for PDF builds
        fonts-freefont-ttf \
        # DejaVu fonts for XeLaTeX
        fonts-dejavu \
        fontconfig \
        # Chrome dependencies for kaleido (Plotly static image export)
        libnss3 \
        libatk-bridge2.0-0 \
        libcups2 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxrandr2 \
        libgbm1 \
        libxkbcommon0 \
        libpango-1.0-0 \
        libcairo2 \
        libasound2t64 \
        && rm -rf /var/lib/apt/lists/*

# Copy FreeSerif fonts to TeX's font directory (fixes latexmk subprocess font access)
# This ensures fonts are found even when latexmk spawns xelatex with different environment
RUN mkdir -p /usr/local/share/texmf/fonts/truetype/freefont && \
    cp /usr/share/fonts/truetype/freefont/*.ttf /usr/local/share/texmf/fonts/truetype/freefont/ && \
    mktexlsr

# Create OTF symlinks for FreeFont TTF files
# Sphinx's default fontpkg for xelatex specifies Extension=.otf, but Ubuntu provides .ttf files
# Creating .otf symlinks allows fontspec to find the fonts with Sphinx's default configuration
RUN cd /usr/share/fonts/truetype/freefont && \
    for ttf in *.ttf; do \
        otf="${ttf%.ttf}.otf"; \
        ln -sf "$ttf" "$otf"; \
    done

# Build system-wide fontconfig cache (not user-specific)
# This is critical for latexmk subprocess which may run with different HOME
RUN fc-cache -f -s -v && \
    mkdir -p /var/cache/fontconfig && \
    chmod 777 /var/cache/fontconfig

# Set fontconfig environment to ensure fonts are found in any context
ENV FONTCONFIG_PATH=/etc/fonts
ENV FONTCONFIG_FILE=/etc/fonts/fonts.conf

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN curl -L https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

# Put conda in path
ENV PATH=$CONDA_DIR/bin:$PATH

# Copy environment file, accept ToS, and create conda environment
COPY environment.yml /tmp/environment.yml
RUN conda tos accept && \
    conda env create -f /tmp/environment.yml && \
    # Install Chrome for kaleido (Plotly static image export)
    /opt/conda/envs/quantecon/bin/python -c "import kaleido; kaleido.get_chrome_sync()" && \
    conda clean -afy && \
    rm /tmp/environment.yml

# Set environment variables to activate the quantecon environment by default
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon

# Create marker file for container detection by setup-environment action
RUN echo "quantecon-container" > /etc/quantecon-container && \
    echo "image=ghcr.io/quantecon/quantecon" >> /etc/quantecon-container && \
    echo "build_date=$(date -Iseconds)" >> /etc/quantecon-container

# Set working directory
WORKDIR /workspace

# Verify installation
RUN python --version && \
    conda --version && \
    jupyter --version && \
    jupyter-book --version && \
    pdflatex --version

# Default command
CMD ["/bin/bash"]
