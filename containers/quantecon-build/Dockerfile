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

# Node.js 24 LTS, for the Node tools the actions install into this image at run
# time: preview-netlify's netlify-cli (needs node >=22.13) and preview-cloudflare's
# wrangler (refuses to start below node 22). Installed from nodejs.org, pinned by
# version and SHA256 like Miniconda above, and deliberately NOT from conda: every
# jupyterlab build below 4.6 on the defaults channel, including the one the
# Anaconda 2026.07 baseline pins, constrains nodejs to 20.x, so a conda nodejs
# cannot reach 24 without moving the Jupyter stack. Outside conda it cannot touch
# the solve, and placed after the conda layer a Node bump does not re-run it.
# Bump NODE_VERSION and NODE_SHA256 together, from
# https://nodejs.org/dist/v<version>/SHASUMS256.txt; Dependabot does not track them.
ENV NODE_VERSION=24.21.0
ENV NODE_SHA256=6e1db87ef58b8819e5d5402eff1536491b18edd8eb7bee5ef7897876e88dc5ff
RUN curl -fsSL https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.gz -o /tmp/node.tar.gz && \
    echo "${NODE_SHA256}  /tmp/node.tar.gz" | sha256sum -c - && \
    mkdir -p /opt/node && \
    tar -xzf /tmp/node.tar.gz -C /opt/node --strip-components=1 --no-same-owner && \
    rm /tmp/node.tar.gz
# Ahead of the conda env, so a lecture environment that adds a conda nodejs
# cannot shadow the pinned Node.
ENV PATH=/opt/node/bin:$PATH

# Create marker file for container detection by setup-environment action
RUN echo "quantecon-container" > /etc/quantecon-container && \
    echo "image=ghcr.io/quantecon/quantecon-build" >> /etc/quantecon-container && \
    echo "variant=build" >> /etc/quantecon-container && \
    echo "build_date=$(date -Iseconds)" >> /etc/quantecon-container

# Trust every git work tree. In a GitHub Actions container job the runner
# creates the workspace as its own user (uid 1001) and bind-mounts it here,
# while steps run as root (this image declares no USER), so git refuses the
# checkout ("detected dubious ownership", exit 128) in every step after
# actions/checkout. quantecon-book-theme then silently drops each page's
# "Last changed" header, and scripts/detect-changed-lectures.sh silently finds
# no changed lectures. git's ownership check guards shared multi-user machines
# against repositories planted by another user; this image runs one job's own
# checkout, single-tenant and discarded afterwards, so there is nothing for it
# to guard. System scope, so the entry holds whatever HOME a step sets.
# Revisit this if the image is ever run on a shared, long-lived host with
# other users' volumes mounted: there the check has something to guard.
RUN git config --system --add safe.directory '*'

# Set working directory
WORKDIR /workspace

# Verify installation
RUN python --version && \
    conda --version && \
    test "$(node -p process.versions.node)" = "${NODE_VERSION}" && \
    npm --version && \
    jupyter --version && \
    jupyter-book --version && \
    pdflatex --version

# Default command
CMD ["/bin/bash"]
