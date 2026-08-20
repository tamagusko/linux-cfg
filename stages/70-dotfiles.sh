#!/usr/bin/env bash
# Stage 70 — zsh, oh-my-zsh, powerlevel10k, and dotfile symlinking.
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

# ------------------------------------------------------------------- dotfiles
#
# One symlink per config directory: ~/.config/i3 -> $REPO_DIR/dotfiles/i3
#
# This replaced GNU stow, which was wrong for this layout. `stow --target
# ~/.config i3` links the *contents* of dotfiles/i3 into ~/.config, producing
# ~/.config/config and ~/.config/scripts rather than ~/.config/i3/config — and
# it exits 0 while doing so, so the run reported success while i3 started with
# no config at all. Making stow correct would mean restructuring every package
# as dotfiles/i3/.config/i3/..., which buys nothing here: one symlink per
# directory is easier to read, trivially reversible, and drops a dependency.
#
# Edits made in ~/.config/i3/config land in the repo, where git sees them.
mkdir -p "$HOME/.config"

mapfile -t config_dirs < <(
    for d in "$REPO_DIR"/dotfiles/*/; do
        pkg="$(basename "$d")"
        # Not every dotfiles/ directory belongs under ~/.config:
        #   zsh    -> .zshrc, installed above
        #   claude -> ~/.claude, installed by stage 75
        # Linking either here would put the files somewhere nothing reads them.
        case "$pkg" in
            zsh|claude) continue ;;
        esac
        # An empty directory is a leftover, not a package. `git rm` deletes the
        # files it tracks and leaves the directories behind, so a package this
        # repo has stopped shipping still shows up in this glob — and linking
        # ~/.config/<pkg> at it would replace a working config with nothing.
        # That is not hypothetical: dotfiles/systemd/user/ssh-agent.service was
        # removed in favour of the distro's gcr-ssh-agent unit, and the empty
        # dotfiles/systemd/user/ that survived would have taken
        # ~/.config/systemd/user/sockets.target.wants/ down with it.
        if [[ -z "$(find "$d" -mindepth 1 -not -type d -print -quit 2>/dev/null)" ]]; then
            continue
        fi
        printf '%s\n' "$pkg"
    done | sort
)

# Migration: undo whatever the previous stow-based version left behind. Those
# are loose entries directly in ~/.config pointing into this repo; left alone
# they shadow nothing and make later debugging confusing.
if have stow; then
    for pkg in "${config_dirs[@]}"; do
        stow --dir="$REPO_DIR/dotfiles" --target="$HOME/.config" --delete "$pkg" >/dev/null 2>&1 || true
    done
fi
for entry in "$HOME"/.config/*; do
    [[ -L "$entry" ]] || continue
    target="$(readlink -f "$entry" 2>/dev/null || true)"
    [[ "$target" == "$REPO_DIR/dotfiles/"* ]] || continue

    name="$(basename "$entry")"
    # A link this stage owns points *at* dotfiles/<pkg> and carries that same
    # name: ~/.config/i3 -> dotfiles/i3. Anything else is stow's leftover,
    # which pointed one level deeper — ~/.config/config -> dotfiles/i3/config.
    #
    # The earlier test compared the link's name against the basename of the
    # target's *parent*, which for a correct link is the literal string
    # "dotfiles". So every correct link failed it, and each run deleted all
    # eight before recreating them a few lines below. Self-healing, but it
    # logged "removing stray link" about links that were exactly right, and it
    # left ~/.config with no i3 or kitty at all if the run died in between.
    if [[ "$(dirname "$target")" == "$REPO_DIR/dotfiles" && "$name" == "$(basename "$target")" ]]; then
        continue
    fi

    info "removing stray link from the old stow layout: ~/.config/$name"
    run rm -f -- "$entry"
done

info "linking ${#config_dirs[@]} config director(ies): ${config_dirs[*]}"
for pkg in "${config_dirs[@]}"; do
    src="$REPO_DIR/dotfiles/$pkg"
    dest="$HOME/.config/$pkg"

    # Already pointing where it should.
    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$src" ]]; then
        ok "$pkg already linked"
        continue
    fi

    # A real directory here is the distro's own config — EndeavourOS ships an
    # i3 config. Keep a timestamped copy before replacing it.
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        backup_file "$dest"
        run rm -rf -- "$dest"
    elif [[ -L "$dest" ]]; then
        run rm -f -- "$dest"
    fi

    if run ln -sfn "$src" "$dest"; then
        ok "linked ~/.config/$pkg -> dotfiles/$pkg"
    else
        warn "could not link $pkg"
    fi
done

ok "dotfiles stage done"
