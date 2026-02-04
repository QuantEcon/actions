FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install minimal system dependencies and LaTeX
# Using texlive-xetex instead of full texlive to reduce size
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        # Minimal LaTeX for PDF builds
        texlive-xetex \
        texlive-fonts-recommended \
        texlive-latex-recommended \
        texlive-latex-extra \
        # Build tools
        latexmk \
        dvipng \
        ghostscript \
        cm-super \
        make \
        # Utilities
        git \
        curl \
        ca-certificates \
        # Fonts for PDF builds
        fonts-freefont-ttf \
        fontconfig \
        # Graphviz for network diagrams
        graphviz \
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
ENV MINICONDA_VERSION=py313_25.1.1-2
ENV MINICONDA_SHA256=1b971dc4ab40108612ba35fbb6fbe6a8ae66b7ccaad4cbcf096c16c22a5d2fc5
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
