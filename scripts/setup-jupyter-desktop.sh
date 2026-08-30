#!/usr/bin/env bash
#
# Make double-clicking a .ipynb open it in JupyterLab, in the right environment.
#
#   ./scripts/setup-jupyter-desktop.sh              install / repair
#   ./scripts/setup-jupyter-desktop.sh --project .  add the current repo as a project
#   ./scripts/setup-jupyter-desktop.sh --status     show what is installed
#   ./scripts/setup-jupyter-desktop.sh --uninstall  undo the file association
#
# Safe to run twice: every step repairs rather than duplicates.
#
# ---------------------------------------------------------------------------
# What this sets up, and why it is shaped this way
# ---------------------------------------------------------------------------
#
# One global JupyterLab, many project kernels.
#
#   uv tool install jupyterlab   ->  a single server binary on PATH
#   uv add --dev ipykernel       ->  per project, registered as a --user kernel
#
# The uv documentation suggests `uv run --with jupyter jupyter lab` instead.
# That is right for terminal use inside one project. It is wrong here: a
# double-click launcher serving ~15 project roots would pay overlay resolution
# on every open. A tool-installed Lab starts immediately, and because kernels
# are registered with `--user` they land in ~/.local/share/jupyter/kernels and
# every Jupyter installation on this machine can see them.
#
# Note that `uv tool install jupyterlab` exposes `jupyter-lab` but NOT the
# `jupyter` dispatcher — that entry point belongs to jupyter-core, which is a
# dependency rather than the requested package. The launcher prefers
# `jupyter-lab` for that reason. ipykernel is installed alongside so notebooks
# outside any project still get a working kernel instead of a dead one.
#
# We deliberately do not use `nbopen`. Its last release was 2023-09-08, and the
# single-instance logic it provides is ~25 lines against jupyter_server's
# stable runtime files — better owned than inherited.
#
# ---------------------------------------------------------------------------
# The MIME detail that will confuse you later
# ---------------------------------------------------------------------------
#
# `xdg-mime query filetype some.ipynb` reports application/json on this system,
# not application/x-ipynb+json. That is the shell tool walking the subclass
# chain (x-ipynb+json is a subclass of json) and stopping at the parent.
#
# GIO — which is what Thunar actually consults — reports application/x-ipynb+json
# correctly, by glob and by content. So the association below is on the right
# type. Verify with `gio mime application/x-ipynb+json`, not with xdg-mime.

set -euo pipefail
IFS=$'\n\t'

BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
STATE_DIR="$HOME/.local/state/notebook-launcher"
LAUNCHER="$BIN_DIR/notebook-open"
DESKTOP="$APP_DIR/notebook-open.desktop"
MIMETYPE="application/x-ipynb+json"
PYTHON_VERSION="3.13"

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAYLOAD="$REPO_DIR/scripts/notebook-open"

info() { printf '[ .. ] %s\n' "$*"; }
ok()   { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
die()  { printf '[FAIL] %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

usage() {
    awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"
}

# --------------------------------------------------------------------------
install_jupyter() {
    have uv || die "uv is not installed. Run stage 40-dev first."

    if uv tool list 2>/dev/null | grep -q '^jupyterlab '; then
        ok "JupyterLab already installed as a uv tool"
        return
    fi
    info "installing JupyterLab as a uv tool (with ipykernel for orphan notebooks)"
    uv tool install --python "$PYTHON_VERSION" --with ipykernel jupyterlab
    ok "JupyterLab installed"
}

install_launcher() {
    [[ -r "$PAYLOAD" ]] || die "launcher payload missing: $PAYLOAD"
    mkdir -p "$BIN_DIR" "$STATE_DIR"
    install -m 755 "$PAYLOAD" "$LAUNCHER"
    ok "launcher installed: $LAUNCHER"
}

install_desktop_entry() {
    mkdir -p "$APP_DIR"
    cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Jupyter Notebook
GenericName=Notebook
Comment=Open in JupyterLab using the notebook's own project environment
Exec=$LAUNCHER %f
Icon=jupyter
Terminal=false
NoDisplay=false
StartupNotify=false
MimeType=$MIMETYPE;
Categories=Development;
Keywords=jupyter;notebook;ipynb;python;lab;
EOF
    have update-desktop-database && update-desktop-database "$APP_DIR"
    if have desktop-file-validate; then
        desktop-file-validate "$DESKTOP" || warn "desktop entry validation reported issues"
    fi
    ok "desktop entry installed: $DESKTOP"
}

associate() {
    have xdg-mime || die "xdg-mime not available (install xdg-utils)"
    xdg-mime default "$(basename "$DESKTOP")" "$MIMETYPE"
    local current
    current="$(xdg-mime query default "$MIMETYPE" || true)"
    [[ "$current" == "$(basename "$DESKTOP")" ]] \
        && ok "$MIMETYPE -> $current" \
        || warn "association did not stick (got '${current:-none}')"
}

# --------------------------------------------------------------------------
# Point a repository at this flow: a uv project, its deps, and a named kernel.
add_project() {
    local dir="$1"
    dir="$(cd "$dir" && pwd)" || die "no such directory: $1"
    local name kernel
    name="$(basename "$dir" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_.-' '-')"
    kernel="${name%-}"

    have uv || die "uv is not installed"

    if [[ ! -f "$dir/pyproject.toml" ]]; then
        info "creating uv project in $dir"
        ( cd "$dir" && uv init --bare --no-workspace --vcs none --python "$PYTHON_VERSION" )
    else
        ok "pyproject.toml already present"
    fi

    info "ensuring ipykernel + jupytext are available"
    ( cd "$dir" && uv add --dev ipykernel jupytext )

    info "registering kernel '$kernel'"
    ( cd "$dir" && uv run ipython kernel install --user \
        --env VIRTUAL_ENV "$dir/.venv" \
        --name "$kernel" --display-name "Python ($(basename "$dir"))" )

    ok "project ready: $dir  (kernel: $kernel)"
    printf '\nAdd its dependencies with:  cd %s && uv add pandas matplotlib ...\n' "$dir"
    printf 'Bind a notebook to the kernel so double-click picks it automatically:\n'
    printf '  cd %s && uv run jupytext --set-kernel %s path/to/notebook.ipynb\n' "$dir" "$kernel"
}

status() {
    printf 'JupyterLab tool : '
    uv tool list 2>/dev/null | grep '^jupyterlab ' || echo 'NOT INSTALLED'
    printf 'launcher        : %s\n' "$([[ -x "$LAUNCHER" ]] && echo "$LAUNCHER" || echo 'NOT INSTALLED')"
    printf 'desktop entry   : %s\n' "$([[ -f "$DESKTOP" ]] && echo "$DESKTOP" || echo 'NOT INSTALLED')"
    printf 'xdg association : %s\n' "$(xdg-mime query default "$MIMETYPE" 2>/dev/null || echo none)"
    # sed -n 1p, not head -1: head closes the pipe, gio takes SIGPIPE, and the
    # non-zero status would fire the `|| echo none` on a perfectly good answer.
    printf 'gio association : %s\n' "$(gio mime "$MIMETYPE" 2>/dev/null | sed -n 1p)"
    printf 'log file        : %s\n' "$STATE_DIR/launcher.log"
    echo
    echo 'registered kernels:'
    ls -1 "$HOME/.local/share/jupyter/kernels" 2>/dev/null | sed 's/^/  /' || echo '  (none)'
}

uninstall() {
    info "restoring the previous .ipynb association"
    # There is no "unset default" in xdg-mime; drop our line from mimeapps.list.
    local list="$HOME/.config/mimeapps.list"
    if [[ -f "$list" ]]; then
        sed -i "\|^${MIMETYPE}=notebook-open.desktop\$|d" "$list"
        ok "removed association from $list"
    fi
    rm -f "$DESKTOP" && ok "removed $DESKTOP"
    have update-desktop-database && update-desktop-database "$APP_DIR"
    rm -f "$LAUNCHER" && ok "removed $LAUNCHER"
    echo
    echo "Left in place on purpose (remove by hand if you want them gone):"
    echo "  uv tool uninstall jupyterlab"
    echo "  rm -rf $STATE_DIR"
    echo "  project .venv dirs and ~/.local/share/jupyter/kernels/*"
}

main() {
    case "${1:-}" in
        --help|-h) usage; exit 0 ;;
        --status)  status; exit 0 ;;
        --uninstall) uninstall; exit 0 ;;
        --project) shift; add_project "${1:-.}"; exit 0 ;;
        '') : ;;
        *) die "unknown option: $1  (try --help)" ;;
    esac

    install_jupyter
    install_launcher
    install_desktop_entry
    associate
    echo
    ok "done — double-click any .ipynb"
    printf 'Log: %s\n' "$STATE_DIR/launcher.log"
}

main "$@"
