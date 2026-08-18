#!/usr/bin/env bash
# Stage 20 — NVIDIA driver and CUDA.
#
# Its own top-level stage on purpose. This previously lived inside the
# TensorFlow script, so answering "no" to TensorFlow left the machine with no
# GPU driver at all.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 20 — GPU (NVIDIA + CUDA)"

have lspci || pac pciutils

if ! lspci | grep -qi nvidia; then
    warn "no NVIDIA GPU detected — skipping driver and CUDA"
    exit 0
fi

info "NVIDIA GPU detected:"
run_tty bash -c "lspci | grep -i nvidia"

# Arch news 2025-12-20: NVIDIA 590 dropped Pascal and older, and the main
# packages moved to the open kernel modules:
#   nvidia      -> nvidia-open
#   nvidia-dkms -> nvidia-open-dkms
# The open modules cover Turing (RTX 20 / GTX 16xx) and newer. An RTX 3060 is
# Ampere, so it qualifies and needs no manual intervention.
#
# Pascal or older would instead need nvidia-580xx-dkms from the AUR.
pac nvidia-open nvidia-utils nvidia-settings

# Module build for the LTS fallback kernel installed in stage 10.
pac nvidia-open-lts

# CUDA toolkit and cuDNN. Large (~5GB). PyTorch wheels installed through uv
# bundle their own CUDA runtime, so this is only needed to compile CUDA code or
# to use a system-wide torch.
if confirm "install the full CUDA toolkit + cuDNN (~5GB)?"; then
    pac cuda cudnn
    # nvcc is not on PATH by default on Arch.
    ensure_block "$HOME/.zshrc" "cuda" <<'BLOCK'
export CUDA_HOME=/opt/cuda
export PATH="$CUDA_HOME/bin:$PATH"
BLOCK
else
    info "skipping CUDA toolkit — uv-installed PyTorch wheels ship their own CUDA runtime"
fi

warn "the driver needs a reboot before nvidia-smi will work"
ok "GPU stage done"
