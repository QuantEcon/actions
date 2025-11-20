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
        # Fonts for XeLaTeX
        fonts-freefont-ttf \
        fontconfig \
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
        && rm -rf /var/lib/apt/lists/* \
        && fc-cache -f -s \
        && mkdir -p /root/.fonts \
        && ln -s /usr/share/fonts/truetype/freefont /root/.fonts/freefont \
        && fc-cache -fv

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
    conda clean -afy && \
    rm /tmp/environment.yml

# Set environment variables to activate the quantecon environment by default
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon

# Set OSFONTDIR to help XeTeX find system fonts (needed for latexmk subprocess)
ENV OSFONTDIR=/usr/share/fonts

# Rebuild font cache after conda environment is active (system-wide for Docker)
RUN fc-cache -f -s

# Set working directory
WORKDIR /workspace

# Verify installation
RUN python --version && \
    conda --version && \
    jupyter --version && \
    jupyter-book --version && \
    pdflatex --version && \
    echo "=== Checking FreeSerif font ===" && \
    fc-list | grep -i freeserif

# Default command
CMD ["/bin/bash"]
