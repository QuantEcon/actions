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
        # Additional utilities
        git \
        curl \
        ca-certificates \
        && rm -rf /var/lib/apt/lists/*

# Install Miniconda
RUN curl -L https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh && \
    bash /tmp/miniconda.sh -b -p /opt/conda && \
    rm /tmp/miniconda.sh && \
    /opt/conda/bin/conda config --set accept_default_config true && \
    /opt/conda/bin/conda install -y mamba -c conda-forge && \
    /opt/conda/bin/conda clean -afy

# Copy environment file and create conda environment
COPY environment.yml /tmp/environment.yml
RUN /opt/conda/bin/mamba env create -f /tmp/environment.yml && \
    /opt/conda/bin/mamba clean -afy && \
    rm /tmp/environment.yml

# Set environment variables to activate the quantecon environment by default
ENV PATH=/opt/conda/envs/quantecon/bin:$PATH
ENV CONDA_DEFAULT_ENV=quantecon

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
