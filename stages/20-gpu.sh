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
#
# DKMS, not the prebuilt nvidia-open / nvidia-open-lts pair. A prebuilt module
# is tied to one exact kernel *package* build, while the dependency it declares
# is only `linux-lts`, unversioned. So a rebuild such as 6.18.45-1 -> 6.18.45-2
# upgrades cleanly and leaves no module behind. That happened on 2026-08-23: the
# machine came back from a reboot with no driver, X fell back to a 1024x768
# dummy output named None-1, and all three monitors were gone.
#
# Stage 10 calls the LTS kernel a safety net "with a GPU driver that builds
# kernel modules". DKMS is that driver and the prebuilt packages are not, which
# is why the fallback kernel was exactly as dead as the mainline one.
#
# Headers first, and for both kernels: DKMS builds only where headers are
# present and skips a kernel that has none. Stage 10 installs linux-lts-headers,
# but the mainline kernel arrives with the base install and its headers cannot
# be assumed.
pac dkms linux-headers linux-lts-headers
pac nvidia-open-dkms nvidia-utils nvidia-settings

# A failed DKMS build does not fail the pacman transaction. It prints an error
# somewhere inside a long install log and the transaction still reports success,
# so the first honest symptom is a black screen after the next reboot. Check
# every bootable kernel rather than trusting that log.
if [[ "$DRY_RUN" == "1" ]]; then
    info "dry run — not verifying DKMS module builds"
else
    missing_modules=0
    for kdir in /usr/lib/modules/*/; do
        # pkgbase marks a kernel tree owned by an installed package. A tree left
        # behind by a removed kernel cannot be booted and is not worth warning
        # about.
        [[ -f "$kdir/pkgbase" ]] || continue
        kver="$(basename "$kdir")"
        # Anchored to nvidia.ko so this does not match the unrelated
        # nvidia-wmi-ec-backlight module that ships with the kernel itself.
        if [[ -n "$(find "$kdir" -name 'nvidia.ko*' -print -quit 2>/dev/null)" ]]; then
            ok "nvidia module built for $kver"
        else
            warn "no nvidia module for $kver — booting it would give no display"
            missing_modules=1
        fi
    done
    if ((missing_modules)); then
        warn "recover with: sudo dkms autoinstall"
    fi
fi

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
