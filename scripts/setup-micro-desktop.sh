#!/usr/bin/env bash
#
# Make double-clicking a text file open it in micro, inside kitty.
#
#   ./scripts/setup-micro-desktop.sh              install / repair
#   ./scripts/setup-micro-desktop.sh --status     show what is installed
#   ./scripts/setup-micro-desktop.sh --uninstall  undo the file associations
#
# Safe to run twice: every step repairs rather than duplicates.
#
# ---------------------------------------------------------------------------
# Why a local desktop entry instead of the packaged one
# ---------------------------------------------------------------------------
#
# The micro package ships /usr/share/applications/micro.desktop with
# Terminal=true and leaves the choice of terminal to GLib. GLib does not know
# kitty: it looks for xdg-terminal-exec, then walks a fixed list (ptyxis,
# gnome-terminal, xfce4-terminal, ... xterm), so on this machine a double-click
# would land in xfce4-terminal with its own font and palette.
#
# The entry written here has the same id, micro.desktop, so it shadows the
# packaged one (~/.local/share/applications wins over /usr/share) and every
# existing "micro.desktop" reference in mimeapps.list keeps working. It runs
# kitty directly with Terminal=false, so the editor opens in the configured
# terminal with the Dracula palette and Nerd Font from dotfiles/kitty.
#
# ---------------------------------------------------------------------------
# Which MIME types, and the tool that lies about them
# ---------------------------------------------------------------------------
#
# .txt, .conf, .ini, .log  -> text/plain (and its subclasses)
# .py                      -> text/x-python, text/x-python3
# .json                    -> application/json
# .yaml, .yml              -> application/yaml (x-yaml, text/yaml are aliases)
#
# `xdg-mime query filetype` reports text/plain for .py and .yaml on this
# system; GIO, which is what Thunar consults, reports the specific type. The
# associations below are on the specific types. Verify with `gio mime`, not
# with `xdg-mime query filetype`.

set -euo pipefail
IFS=$'\n\t'

APP_DIR="$HOME/.local/share/applications"
DESKTOP="$APP_DIR/micro.desktop"
TERMINAL="${TERMINAL:-kitty}"
MIMETYPES=(
    text/plain
    text/x-python
    text/x-python3
    application/json
    application/yaml
)

info() { printf '[ .. ] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

# --------------------------------------------------------------------------
install_desktop_entry() {
    have micro || die "micro is not installed (it is in packages/pacman.txt)"
    have "$TERMINAL" || die "terminal '$TERMINAL' not found on PATH"
    mkdir -p "$APP_DIR"
    cat > "$DESKTOP" <<ENTRY
[Desktop Entry]
Type=Application
Version=1.0
Name=Micro
GenericName=Text Editor
Comment=Edit text files in a terminal
Exec=$TERMINAL --title micro micro %F
Icon=micro
Terminal=false
StartupNotify=false
MimeType=$(IFS=';'; printf '%s;' "${MIMETYPES[*]}")text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-perl;application/xml;text/html;text/css;text/x-sql;text/x-diff;
Categories=Utility;TextEditor;Development;
Keywords=text;editor;syntax;terminal;
ENTRY
    have update-desktop-database && update-desktop-database "$APP_DIR"
    if have desktop-file-validate; then
        desktop-file-validate "$DESKTOP" || warn "desktop entry validation reported issues"
    fi
    ok "desktop entry installed: $DESKTOP"
}

associate() {
    have xdg-mime || die "xdg-mime not available (install xdg-utils)"
    local m current
    for m in "${MIMETYPES[@]}"; do
        xdg-mime default "$(basename "$DESKTOP")" "$m"
        current="$(xdg-mime query default "$m" || true)"
        [[ "$current" == "$(basename "$DESKTOP")" ]] \
            && ok "$m -> $current" \
            || warn "$m: association did not stick (got '${current:-none}')"
    done
}

status() {
    printf 'desktop entry   : %s\n' "$([[ -f "$DESKTOP" ]] && echo "$DESKTOP" || echo 'NOT INSTALLED')"
    printf 'exec line       : %s\n' "$(sed -n 's/^Exec=//p' "$DESKTOP" 2>/dev/null || echo none)"
    echo
    local m
    for m in "${MIMETYPES[@]}"; do
        # sed -n 1p, not head -1: head closes the pipe, gio takes SIGPIPE.
        printf '%-20s %s\n' "$m" "$(gio mime "$m" 2>/dev/null | sed -n 1p)"
    done
}

uninstall() {
    info "removing the micro defaults from mimeapps.list"
    # There is no "unset default" in xdg-mime; drop our lines from the file.
    local list="$HOME/.config/mimeapps.list" m
    if [[ -f "$list" ]]; then
        for m in "${MIMETYPES[@]}"; do
            sed -i "\|^${m}=micro.desktop\$|d" "$list"
        done
        ok "removed associations from $list"
    fi
    rm -f "$DESKTOP" && ok "removed $DESKTOP (the packaged entry is visible again)"
    have update-desktop-database && update-desktop-database "$APP_DIR"
}

main() {
    case "${1:-}" in
        --help|-h) usage; exit 0 ;;
        --status)  status; exit 0 ;;
        --uninstall) uninstall; exit 0 ;;
        '') : ;;
        *) die "unknown option: $1  (try --help)" ;;
    esac

    install_desktop_entry
    associate
    echo
    ok "done — double-click any .txt, .py, .json, .yaml or .conf"
}

main "$@"
