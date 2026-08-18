#!/usr/bin/env bash
# Stage 40 — development toolchain: uv, stow, docker, git defaults.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 40 — DEV TOOLCHAIN"

# ------------------------------------------------------------------------- uv
#
# Python version and environment management. Verified in extra as `uv` 0.12.5
# (2026-08-18).
#
# Why uv rather than system pip, pyenv or conda:
#   - Arch marks the system Python environment externally-managed (PEP 668), so
#     `pip install` outside a venv fails by design. The old pytorch.sh did
#     exactly that and would abort.
#   - Arch bumps system Python quickly, and every bump breaks pip-installed
#     packages in site-packages. uv installs and pins its own interpreters, so a
#     system Python bump cannot break a project.
#   - `uv pip install torch --torch-backend=auto` detects the GPU and picks the
#     matching CUDA wheel index. Choosing that index by hand is how people end
#     up silently training on CPU.
pac uv

ensure_block "$HOME/.zshrc" "uv" <<'BLOCK'
# uv manages Python interpreters and per-project environments.
#   uv python install 3.13         install an interpreter
#   uv init && uv add torch        start a project
#   uv pip install torch --torch-backend=auto
eval "$(uv generate-shell-completion zsh 2>/dev/null || true)"
BLOCK

# --------------------------------------------------------------------- stow
#
# Dotfile symlinking. Replaces the old blind `cp -r dotfiles/* ~/.config/`,
# which overwrote existing config with no backup and no way back.
pac stow

# -------------------------------------------------------------------- docker
#
# docker, docker-compose and docker-buildx come from packages/pacman.txt.
info "enabling docker service"
run sudo systemctl enable --now docker.service

# SECURITY: membership of the docker group is root-equivalent. The docker socket
# can bind-mount the host filesystem, so anyone in this group can read and write
# any file as root without a sudo prompt.
#
# Accepted deliberately here: this is a single-user workstation and rootless
# docker adds real friction for GPU containers. Recorded so the choice is
# explicit rather than a silent side effect.
if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    ok "$USER already in the docker group"
else
    warn "adding $USER to the docker group grants root-equivalent access via the docker socket"
    if confirm "add $USER to the docker group?"; then
        run sudo usermod -aG docker "$USER"
        warn "log out and back in for the group change to take effect"
    else
        info "skipped; use 'sudo docker' instead"
    fi
fi

# ----------------------------------------------------------------------- git
#
# Only settings that are safe to assert. Deliberately not setting user.name or
# user.email: those are identity, they differ per machine and per project, and
# guessing them silently rewrites commit authorship.
info "setting git defaults (identity left untouched)"
run git config --global init.defaultBranch main
run git config --global pull.ff only
run git config --global push.autoSetupRemote true

if ! git config --global user.email >/dev/null 2>&1; then
    warn "git user.name / user.email are not set — set them before committing:"
    warn "  git config --global user.name  'Your Name'"
    warn "  git config --global user.email 'you@example.com'"
fi

ok "dev toolchain done"
