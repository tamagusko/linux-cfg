#!/usr/bin/env bash
# Stage 70 — zsh, oh-my-zsh, powerlevel10k, and dotfile symlinking via stow.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 70 — DOTFILES"

ZSH_DIR="$HOME/.oh-my-zsh"
ZSH_CUSTOM_DIR="$ZSH_DIR/custom"

# ------------------------------------------------------------------ oh-my-zsh
#
# The previous version piped the installer into zsh with no flags. The installer
# ends by exec'ing an interactive shell, which blocked the parent script, so
# nothing after that line ever ran. --unattended plus RUNZSH/CHSH=no prevents
# both the exec and the interactive chsh prompt.
if [[ -d "$ZSH_DIR" ]]; then
    ok "oh-my-zsh already installed"
else
    info "installing oh-my-zsh (unattended)"
    installer="$(mktemp)"
    run curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$installer"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes run_tty sh "$installer" --unattended
    command rm -f -- "$installer"
    ok "oh-my-zsh installed"
fi

# Plugins and theme into $ZSH_CUSTOM, which survives oh-my-zsh self-update.
# The old script cloned into $ZSH/plugins, which oh-my-zsh owns.
clone_or_pull https://github.com/zsh-users/zsh-syntax-highlighting \
    "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" --depth=1
clone_or_pull https://github.com/zsh-users/zsh-autosuggestions \
    "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" --depth=1
clone_or_pull https://github.com/romkatv/powerlevel10k \
    "$ZSH_CUSTOM_DIR/themes/powerlevel10k" --depth=1

# ---------------------------------------------------------------------- .zshrc
#
# Shipped whole rather than patched with sed. The old approach ran
#   sed 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k/powerlevel10k"/'
# which has an unescaped delimiter and an unbalanced quote, so sed aborted and
# the theme was never set. Owning the file removes that failure mode entirely.
#
# Any linux-cfg blocks written by earlier stages (CUDA paths, uv completion) are
# carried across, so stage order does not matter.
info "installing managed .zshrc"
preserved="$(extract_blocks "$HOME/.zshrc")"
backup_file "$HOME/.zshrc"
if [[ "$DRY_RUN" == "1" ]]; then
    info "would write $HOME/.zshrc from $REPO_DIR/dotfiles/zsh/zshrc"
else
    cp "$REPO_DIR/dotfiles/zsh/zshrc" "$HOME/.zshrc"
    if [[ -n "$preserved" ]]; then
        printf '\n%s\n' "$preserved" >> "$HOME/.zshrc"
        ok "preserved $(grep -c '^# >>> linux-cfg:' <<<"$preserved") existing linux-cfg block(s)"
    fi
    ok "wrote $HOME/.zshrc"
fi

# Default shell. chsh prompts for a password, so it gets a tty.
current_shell="$(getent passwd "$USER" | cut -d: -f7)"
zsh_path="$(command -v zsh)"
if [[ "$current_shell" == "$zsh_path" ]]; then
    ok "zsh is already the default shell"
else
    info "setting zsh as the default shell (will prompt for your password)"
    run_tty chsh -s "$zsh_path"
fi

# ------------------------------------------------------------------------ stow
#
# Symlinks instead of `cp -r dotfiles/* ~/.config/`, which overwrote existing
# config with no backup and no way back. Each directory under dotfiles/ is a
# stow package whose contents land in ~/.config.
mkdir -p "$HOME/.config"

mapfile -t stow_packages < <(
    for d in "$REPO_DIR"/dotfiles/*/; do
        pkg="$(basename "$d")"
        [[ "$pkg" == "zsh" ]] && continue
        printf '%s\n' "$pkg"
    done | sort
)

info "stowing ${#stow_packages[@]} package(s) into ~/.config: ${stow_packages[*]}"
for pkg in "${stow_packages[@]}"; do
    # Back up any real (non-symlink) directory stow would collide with, then
    # clear it so the symlink can be created.
    if [[ -e "$HOME/.config/$pkg" && ! -L "$HOME/.config/$pkg" ]]; then
        backup_file "$HOME/.config/$pkg"
        run rm -rf -- "$HOME/.config/$pkg"
    fi
    if run stow --dir="$REPO_DIR/dotfiles" --target="$HOME/.config" --restow "$pkg"; then
        ok "stowed $pkg"
    else
        warn "stow failed for $pkg — resolve the conflict by hand"
    fi
done

ok "dotfiles stage done"
