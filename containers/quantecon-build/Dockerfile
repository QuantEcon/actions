FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies and LaTeX
# Includes texlive-fonts-extra (bbm.sty) and xindy for PDF builds
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # LaTeX for PDF builds
        texlive-xetex \
        texlive-fonts-recommended \
        texlive-fonts-extra \
        texlive-latex-recommended \
        texlive-latex-extra \
        # Build tools
        latexmk \
        xindy \
        dvipng \
        ghostscript \
        cm-super \
        make \
        # Utilities
        git \
        curl \
        ca-certificates \
        # Fonts for PDF builds (same as full container for consistency)
        fonts-dejavu \
        fonts-freefont-ttf \
        fontconfig \
        # Graphviz for network diagrams
        graphviz \
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
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy FreeSerif fonts to TeX's font directory
RUN mkdir -p /usr/local/share/texmf/fonts/truetype/freefont && \
    cp /usr/share/fonts/truetype/freefont/*.ttf /usr/local/share/texmf/fonts/truetype/freefont/ && \
    mktexlsr

# Create OTF symlinks for FreeFont TTF files
RUN cd /usr/share/fonts/truetype/freefont && \
    for ttf in *.ttf; do \
        otf="${ttf%.ttf}.otf"; \
        ln -sf "$ttf" "$otf"; \
    done

# Build fontconfig cache
RUN fc-cache -f -s -v && \
    mkdir -p /var/cache/fontconfig && \
    chmod 755 /var/cache/fontconfig

# Set fontconfig environment
ENV FONTCONFIG_PATH=/etc/fonts
ENV FONTCONFIG_FILE=/etc/fonts/fonts.conf

# Install Miniconda (smaller than Anaconda)
# Pinned to specific version with SHA256 checksum for supply-chain security
ENV CONDA_DIR=/opt/conda
ENV MINICONDA_VERSION=py313_25.11.1-1
ENV MINICONDA_SHA256=e0b10e050e8928e2eb9aad2c522ee3b5d31d30048b8a9997663a8a460d538cef
RUN curl -L https://repo.anaconda.com/miniconda/Miniconda3-${MINICONDA_VERSION}-Linux-x86_64.sh -o /tmp/miniconda.sh && \
    echo "${MINICONDA_SHA256}  /tmp/miniconda.sh" | sha256sum -c - && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh

# Put conda in path
ENV PATH=$CONDA_DIR/bin:$PATH

# Copy environment file and create conda environment
COPY environment.yml /tmp/environment.yml
RUN conda tos accept && \
    conda env create -f /tmp/environment.yml && \
    # Install Chrome for kaleido (Plotly static image export)
    /opt/conda/envs/quantecon/bin/python -c "import kaleido; kaleido.get_chrome_sync()" && \
    # Aggressive cleanup to reduce size
    conda clean -afy && \
    find /opt/conda -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/conda -name '*.pyc' -delete 2>/dev/null || true && \
    find /opt/conda -name '*.pyo' -delete 2>/dev/null || true && \
    rm -rf /opt/conda/pkgs/* && \
    rm /tmp/environment.yml

# Set environment variables to activate the quantecon environment by default
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon

# Create marker file for container detection by setup-environment action
RUN echo "quantecon-container" > /etc/quantecon-container && \
    echo "image=ghcr.io/quantecon/quantecon-build" >> /etc/quantecon-container && \
    echo "variant=build" >> /etc/quantecon-container && \
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
