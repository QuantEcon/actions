# GPU AMI Setup Guide

Guide for building a RunsOn custom AMI for GPU-accelerated lecture builds (lecture-python.myst).

---

## Overview

QuantEcon uses [RunsOn](https://runs-on.com) with a custom Ubuntu AMI for GPU builds. The AMI provides:
- NVIDIA GPU drivers
- Conda/Miniconda Python environment
- LaTeX for PDF builds
- Container mode marker file for `setup-environment` action

**Key insight:** When using `jax[cuda13]` (bundled CUDA), you only need **GPU drivers** — the CUDA toolkit, cuDNN, and NCCL are bundled in the JAX pip wheel.

---

## System Requirements

### Required: NVIDIA GPU Drivers

**For JAX with CUDA 13 (current):**
- **NVIDIA driver version >= 580** (Linux)
- **GPU compute capability >= 7.5** (Turing+ architecture: RTX 20xx, A100, H100, etc.)

**For JAX with CUDA 12 (legacy):**
- **NVIDIA driver version >= 525** (Linux)
- **GPU compute capability >= 5.2** (Maxwell+ architecture: GTX 900 series and newer)

**Verify driver installation:**
```bash
nvidia-smi  # Should show driver version >= 580
```

### NOT Required: CUDA Toolkit Installation

When repos use `pip install "jax[cuda13]"`, the wheel **bundles all CUDA libraries**:
- ✅ CUDA toolkit (13.0) — bundled in wheel
- ✅ cuDNN (9.8) — bundled in wheel
- ✅ NCCL (2.19) — bundled in wheel

**Do NOT install** via system package managers:
- ❌ `apt-get install cuda`
- ❌ `conda install cuda-toolkit`
- ❌ `conda install cudnn`

This eliminates "CUDA version hell" — the only system dependency is the NVIDIA driver.

**Reference:** [JAX Installation - NVIDIA GPU](https://docs.jax.dev/en/latest/installation.html#nvidia-gpu)

---

## AMI Build Process

### 1. Base OS

Start with Ubuntu 24.04 LTS (recommended):

```bash
# Example: AWS EC2 base AMI
ami-0c55b159cbfafe1f0  # Ubuntu 24.04 LTS, x86_64
```

Or use Packer to automate AMI builds from scratch.

### 2. Install NVIDIA Drivers

**Option 1: From Ubuntu repositories (simpler)**

```bash
sudo apt-get update
sudo apt-get install -y nvidia-driver-580  # or nvidia-driver-latest
```

**Option 2: From NVIDIA's official repository (recommended for latest drivers)**

```bash
# Add NVIDIA package repository
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt-get update

# Install latest driver (not the full CUDA toolkit)
sudo apt-get install -y nvidia-driver-latest

# Reboot to load driver
sudo reboot
```

**Verify after reboot:**

```bash
nvidia-smi
# Expected output:
# +-----------------------------------------------------------------------------------------+
# | NVIDIA-SMI 580.xx.xx              Driver Version: 580.xx.xx      CUDA Version: 13.0     |
# +-----------------------------------------------------------------------------------------+
# | GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
# ...
```

**Note:** The "CUDA Version" shown by `nvidia-smi` is the **maximum CUDA version the driver supports**, not an installed toolkit. JAX brings its own.

### 3. Install Miniconda and Base Environment

```bash
# Download Miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh

# Install to /opt/conda (system-wide)
sudo bash /tmp/miniconda.sh -b -p /opt/conda

# Add to PATH for all users
echo 'export PATH="/opt/conda/bin:$PATH"' | sudo tee -a /etc/profile.d/conda.sh
source /etc/profile.d/conda.sh

# Initialize conda
conda init bash

# Update base environment
conda update -y -n base conda
conda install -y -n base python=3.13 pip
```

### 4. Install LaTeX (for PDF builds)

```bash
sudo apt-get install -y \
  texlive-xetex \
  texlive-fonts-recommended \
  texlive-fonts-extra \
  texlive-latex-extra \
  latexmk \
  xindy
```

### 5. Create Container Mode Marker File

This allows `setup-environment` to detect the AMI and skip redundant installations:

```bash
sudo bash -c 'cat > /etc/quantecon-container << EOF
quantecon-container
image=quantecon_ubuntu2404
variant=gpu
build_date=$(date -Iseconds)
nvidia_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)
EOF'
```

**Example marker content:**

```
quantecon-container
image=quantecon_ubuntu2404
variant=gpu
build_date=2026-02-09T12:00:00+00:00
nvidia_driver=580.13.03
```

### 6. Pre-install Common Scientific Packages (Optional)

To speed up builds, pre-install common scientific Python packages in the base environment:

```bash
# Core scientific stack
conda install -y -c conda-forge \
  numpy scipy pandas matplotlib seaborn \
  jupyter jupyterlab ipython ipykernel \
  quantecon

# Jupyter Book dependencies
pip install -U \
  jupyter-book \
  jupytext \
  sphinx-multitoc-numbering \
  quantecon-book-theme
```

**Note:** Lecture-specific packages (JAX, PyTorch, numpyro) should be installed by each repo's workflow via `environment-update.yml`, not baked into the AMI. This keeps AMI builds simple and avoids version drift.

### 7. Clean Up and Finalize

```bash
# Clean conda cache
conda clean -y --all

# Clean apt cache
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

# Remove temporary files
rm -rf /tmp/*

# Clear shell history (for Packer builds)
cat /dev/null > ~/.bash_history
history -c
```

---

## Packer Build Template (Example)

```hcl
# quantecon-gpu-ami.pkr.hcl
packer {
  required_plugins {
    amazon = {
      source  = "github.com/hashicorp/amazon"
      version = "~> 1"
    }
  }
}

source "amazon-ebs" "quantecon_gpu" {
  ami_name      = "quantecon_ubuntu2404_gpu_{{timestamp}}"
  instance_type = "g4dn.xlarge"  # GPU instance for driver testing
  region        = "us-east-1"
  
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"]  # Canonical
    most_recent = true
  }
  
  ssh_username = "ubuntu"
  
  tags = {
    Name        = "quantecon-gpu-ubuntu2404"
    Environment = "production"
    Version     = "{{timestamp}}"
  }
}

build {
  sources = ["source.amazon-ebs.quantecon_gpu"]
  
  provisioner "shell" {
    inline = [
      # Update system
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      
      # Install NVIDIA driver
      "wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-keyring_1.1-1_all.deb",
      "sudo dpkg -i cuda-keyring_1.1-1_all.deb",
      "sudo apt-get update",
      "sudo apt-get install -y nvidia-driver-latest",
      
      # Install Miniconda
      "wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh",
      "sudo bash /tmp/miniconda.sh -b -p /opt/conda",
      "echo 'export PATH=\"/opt/conda/bin:$PATH\"' | sudo tee -a /etc/profile.d/conda.sh",
      "source /etc/profile.d/conda.sh",
      "/opt/conda/bin/conda init bash",
      
      # Install LaTeX
      "sudo apt-get install -y texlive-xetex texlive-fonts-recommended texlive-fonts-extra texlive-latex-extra latexmk xindy",
      
      # Create marker file
      "sudo bash -c 'cat > /etc/quantecon-container << EOF",
      "quantecon-container",
      "image=quantecon_ubuntu2404",
      "variant=gpu",
      "build_date=$(date -Iseconds)",
      "nvidia_driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)",
      "EOF'",
      
      # Clean up
      "/opt/conda/bin/conda clean -y --all",
      "sudo apt-get clean",
      "sudo rm -rf /var/lib/apt/lists/*",
    ]
  }
}
```

**Build the AMI:**

```bash
packer init quantecon-gpu-ami.pkr.hcl
packer build quantecon-gpu-ami.pkr.hcl
```

---

## Using the AMI in Workflows

Once the AMI is built, reference it in RunsOn workflows:

```yaml
jobs:
  build:
    runs-on: "runs-on=${{ github.run_id }}/family=g4dn.2xlarge/image=quantecon_ubuntu2404/disk=large"
    steps:
      - uses: actions/checkout@v4
      
      - uses: quantecon/actions/setup-environment@v1
        with:
          environment-update: 'environment-update.yml'
        # Detects /etc/quantecon-container marker → skips Miniconda/LaTeX install
      
      - uses: quantecon/actions/build-lectures@v1
```

**Repo's `environment-update.yml` specifies ML packages:**

```yaml
name: quantecon
channels:
  - conda-forge
dependencies:
  - quantecon
  - pip:
    - jax[cuda13]      # Bundles CUDA 13.0 + cuDNN 9.8 + NCCL 2.19
    - numpyro
    - torch            # PyTorch also bundles its own CUDA
    - quantecon-book-theme
```

---

## Verification

After building the AMI, launch a test EC2 instance to verify:

```bash
# 1. Check NVIDIA driver
nvidia-smi
# Should show driver >= 580, GPU detected

# 2. Check marker file
cat /etc/quantecon-container
# Should show image=quantecon_ubuntu2404, variant=gpu

# 3. Check conda
conda --version
# Should show Miniconda

# 4. Test JAX install (simulates workflow)
conda create -n test python=3.13 -y
conda activate test
pip install "jax[cuda13]"
python -c "import jax; print(jax.devices())"
# Should show: [cuda(id=0)]

# 5. Check LaTeX
xelatex --version
# Should show XeTeX version
```

---

## Maintenance

### Updating the AMI

**When to rebuild:**
- NVIDIA releases new driver versions (quarterly-ish)
- Major Python version updates (e.g., 3.13 → 3.14)
- LaTeX package requirements change
- Security updates for base OS

**Versioning:**
- Use timestamp or semantic versioning in AMI name
- Tag AMIs: `quantecon_ubuntu2404_gpu_20260209`
- Keep 2-3 previous versions for rollback

### Driver Updates

JAX supports forward compatibility — newer drivers can run older CUDA versions. To stay current:

```bash
# On the AMI
sudo apt-get update
sudo apt-get install --only-upgrade nvidia-driver-latest
```

Then rebuild the AMI and update RunsOn configuration.

---

## Troubleshooting

### `nvidia-smi` not found after reboot

**Cause:** Driver not loaded

**Fix:**
```bash
# Check driver installation
dpkg -l | grep nvidia-driver

# Reload modules
sudo modprobe nvidia

# Reboot if needed
sudo reboot
```

### JAX doesn't detect GPU

**Cause:** Usually driver version too old

**Fix:**
```bash
# Check JAX requirements
python -c "import jax; print(jax.devices())"

# If shows [cpu], check driver
nvidia-smi

# Ensure driver >= 580 for CUDA 13
sudo apt-get install --only-upgrade nvidia-driver-latest
```

### "libcuda.so.1: cannot open shared object file"

**Cause:** CUDA driver library not in library path

**Fix:**
```bash
# Find libcuda.so
find /usr -name libcuda.so.1 2>/dev/null

# Add to LD_LIBRARY_PATH (typically not needed with proper driver install)
export LD_LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
```

---

## Architecture Notes

### Why AMI instead of GPU Container?

**Advantages of RunsOn AMI:**
- `actions/cache` works normally (containers have caching limitations)
- Direct hardware access, no virtualization overhead
- Simpler NVIDIA driver management (no Docker daemon configuration)
- Compatible with all GitHub Actions features

**Disadvantages:**
- Requires AMI maintenance and rebuilds
- Slower to iterate vs pulling a container
- Per-cloud-provider setup

**Future:** If GitHub launches official GPU runners, we may sunset the custom AMI approach. See [FUTURE-DEVELOPMENT.md](FUTURE-DEVELOPMENT.md).

### JAX Bundled CUDA vs System CUDA

When you `pip install "jax[cuda13]"`, you get:
- `jaxlib` with CUDA runtime embedded
- Python extension modules linked against bundled CUDA
- All JAX kernels pre-compiled for CUDA 13

**How it works:**
1. JAX wheel includes `libcudart.so.13`, `libcublas.so.13`, etc. in the wheel
2. At runtime, JAX loads these libraries via Python's import mechanism
3. These libraries talk to `/usr/lib/x86_64-linux-gnu/libcuda.so.1` (from NVIDIA driver)
4. Driver talks to GPU hardware

**Layer separation:**
```
┌─────────────────────────┐
│   JAX Python Package    │  pip install "jax[cuda13]"
├─────────────────────────┤
│   Bundled CUDA Toolkit  │  Included in wheel (13.0)
│   (cublas, cudnn, etc)  │
├─────────────────────────┤
│   NVIDIA Driver (580+)  │  System install (apt-get)
├─────────────────────────┤
│   GPU Hardware (RTX)    │  RunsOn EC2 instance
└─────────────────────────┘
```

Only the driver needs to be on the system. Everything above it comes from pip.

---

## References

- [JAX Installation - NVIDIA GPU](https://docs.jax.dev/en/latest/installation.html#nvidia-gpu)
- [NVIDIA Driver Downloads](https://www.nvidia.com/Download/index.aspx)
- [CUDA Compatibility Guide](https://docs.nvidia.com/deploy/cuda-compatibility/)
- [RunsOn Documentation](https://runs-on.com/guides/)
- [Packer AWS Builder](https://developer.hashicorp.com/packer/plugins/builders/amazon)

---

## Quick Reference

| Component | Required Version | Installation Method |
|-----------|------------------|---------------------|
| **NVIDIA Driver** | >= 580 (CUDA 13) | `apt-get install nvidia-driver-latest` |
| **CUDA Toolkit** | N/A | Bundled in `jax[cuda13]` wheel |
| **cuDNN** | N/A | Bundled in `jax[cuda13]` wheel |
| **Python** | 3.13+ | Miniconda |
| **GPU** | Compute 7.5+ | EC2 g4dn/p3/p4 instances |

**One-liner test:**
```bash
python -c "import jax; print('GPU detected!' if jax.devices()[0].platform == 'gpu' else 'CPU only')"
```
