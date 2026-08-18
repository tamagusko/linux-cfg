#!/usr/bin/env bash
# Shared helpers for linux-cfg install stages.
# Sourced by install.sh and by each stage when run standalone.

# Guard against double-sourcing.
[[ -n "${LINUX_CFG_COMMON_LOADED:-}" ]] && return 0
LINUX_CFG_COMMON_LOADED=1

set -euo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------- paths & state

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/linux-cfg}"
LOG_FILE="${LOG_FILE:-$STATE_DIR/install-$(date +%Y%m%d-%H%M%S).log}"
DRY_RUN="${DRY_RUN:-0}"

# Packages that were requested but could not be installed. Reported at the end
# instead of aborting the run: one dead AUR package must never take the batch
# down (see README, "Why the AUR loop tolerates failure").
declare -a FAILED_PACKAGES=()
declare -a INSTALLED_PACKAGES=()

mkdir -p "$STATE_DIR"

# ---------------------------------------------------------------------- logging

_ts() { date '+%H:%M:%S'; }

# Everything user-facing goes to both the terminal and the install log.
_log_raw() { printf '%s\n' "$*" | tee -a "$LOG_FILE" >&2; }

log()   { _log_raw "$(_ts) $*"; }
info()  { _log_raw "$(_ts) [ .. ] $*"; }
ok()    { _log_raw "$(_ts) [ OK ] $*"; }
warn()  { _log_raw "$(_ts) [WARN] $*"; }
error() { _log_raw "$(_ts) [FAIL] $*"; }

die() {
    error "$*"
    exit 1
}

banner() {
    _log_raw ""
    _log_raw "═══════════════════════════════════════════════════════════════"
    _log_raw "  $*"
    _log_raw "═══════════════════════════════════════════════════════════════"
}

# ------------------------------------------------------------------- error trap

# Loud failure. Prints the stage, line and command that died, so a failed run is
# never mistaken for a successful one.
_on_err() {
    local exit_code=$?
    error "aborted in ${BASH_SOURCE[1]:-?} at line ${BASH_LINENO[0]:-?}"
    error "failing command: ${BASH_COMMAND}"
    error "exit code: ${exit_code}"
    error "log: ${LOG_FILE}"
    exit "$exit_code"
}
trap _on_err ERR

# ------------------------------------------------------------------- primitives

have() { command -v "$1" >/dev/null 2>&1; }

# run CMD...  — executes, or prints what it would execute under --dry-run.
run() {
    if [[ "$DRY_RUN" == "1" ]]; then
        _log_raw "$(_ts) [DRY ] $(printf '%s ' "$@")"
        return 0
    fi
    _log_raw "$(_ts) [ -> ] $(printf '%s ' "$@")"
    "$@" >>"$LOG_FILE" 2>&1
}

# Same as run(), but lets the command talk to the terminal (for anything
# interactive: sudo prompts, pacman questions, chsh).
run_tty() {
    if [[ "$DRY_RUN" == "1" ]]; then
        _log_raw "$(_ts) [DRY ] $(printf '%s ' "$@")"
        return 0
    fi
    _log_raw "$(_ts) [ -> ] $(printf '%s ' "$@")"
    "$@" 2>&1 | tee -a "$LOG_FILE"
}

require_not_root() {
    [[ ${EUID} -ne 0 ]] || die "do not run this as root; it calls sudo where needed (and paru refuses to run as root)"
}

# Ask once, remember nothing. Returns 0 for yes.
confirm() {
    local prompt="$1" reply
    # A dry run must never block. It is meant to be readable end to end, so it
    # takes the "yes" branch and shows the fullest path through the script.
    if [[ "$DRY_RUN" == "1" ]]; then
        info "would ask: $prompt (dry run assumes yes)"
        return 0
    fi
    if [[ "${ASSUME_YES:-0}" == "1" ]]; then
        info "auto-yes: $prompt"
        return 0
    fi
    while true; do
        read -r -p "$prompt [y/n]: " reply
        case "$reply" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "please answer y or n" ;;
        esac
    done
}

# ------------------------------------------------------------ package installers

# pac PKG...  — official repo packages, one batch. --needed makes it idempotent.
pac() {
    (($# > 0)) || return 0
    info "pacman: $(printf '%s ' "$@")"
    if run sudo pacman -S --needed --noconfirm "$@"; then
        INSTALLED_PACKAGES+=("$@")
        ok "pacman: $(printf '%s ' "$@")"
    else
        FAILED_PACKAGES+=("$@")
        error "pacman failed for: $(printf '%s ' "$@")"
        return 1
    fi
}

# aur PKG...  — AUR packages, ONE AT A TIME, continuing past failures.
#
# Deliberate exception to the fail-loud rule. A batched `paru -S a b c` aborts
# entirely if any single name is unresolvable, which is how one retired package
# (skypeforlinux-stable-bin) previously prevented every other AUR package from
# installing. Misses are collected and reported at the end of the run.
aur() {
    (($# > 0)) || return 0
    have paru || die "paru not found; run stage 10-system first"
    local pkg
    for pkg in "$@"; do
        info "aur: $pkg"
        if run paru -S --needed --noconfirm "$pkg"; then
            INSTALLED_PACKAGES+=("$pkg")
            ok "aur: $pkg"
        else
            FAILED_PACKAGES+=("$pkg")
            warn "aur: $pkg FAILED — continuing (see summary at end)"
        fi
    done
    return 0
}

# read_package_list FILE — echoes package names, skipping blanks and # comments.
read_package_list() {
    local file="$1"
    [[ -f "$file" ]] || die "package list not found: $file"
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$file"
}

# ------------------------------------------------------- idempotent file edits

# backup_file PATH — timestamped copy, once per run, never overwriting an
# existing backup of the same name. Replaces blind `cp` over user config.
backup_file() {
    local target="$1"
    [[ -e "$target" ]] || return 0
    local stamp backup
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="${target}.linux-cfg-bak.${stamp}"
    info "backing up $target -> $backup"
    run cp -a "$target" "$backup"
}

# ensure_block FILE MARKER < content
#
# Writes a delimited block into FILE, replacing any previous block with the same
# marker. This is what makes shell-rc edits re-runnable: appending with >>
# duplicates on every run.
ensure_block() {
    local file="$1" marker="$2"
    local begin="# >>> linux-cfg:${marker} >>>"
    local end="# <<< linux-cfg:${marker} <<<"
    local content
    content="$(cat)"

    if [[ "$DRY_RUN" == "1" ]]; then
        _log_raw "$(_ts) [DRY ] ensure_block ${marker} in ${file}"
        return 0
    fi

    touch "$file"
    # Strip any existing block, then append the fresh one.
    local tmp
    tmp="$(mktemp)"
    awk -v b="$begin" -v e="$end" '
        $0 == b { skip = 1 }
        skip != 1 { print }
        $0 == e { skip = 0 }
    ' "$file" > "$tmp"
    {
        printf '%s\n' "$begin"
        printf '%s\n' "$content"
        printf '%s\n' "$end"
    } >> "$tmp"
    mv "$tmp" "$file"
    ok "ensure_block ${marker} in ${file}"
}

# extract_blocks FILE — echoes every "# >>> linux-cfg:NAME >>>" block found in
# FILE, inclusive of its markers. Used when a managed file is replaced wholesale
# (e.g. ~/.zshrc) so that blocks written by earlier stages survive, making the
# order of stages irrelevant.
extract_blocks() {
    local file="$1"
    [[ -f "$file" ]] || return 0
    awk '
        /^# >>> linux-cfg:.* >>>$/ { inblock = 1 }
        inblock == 1 { print }
        /^# <<< linux-cfg:.* <<<$/ { inblock = 0 }
    ' "$file"
}

# clone_or_pull URL DEST [EXTRA_ARGS...] — replaces `git clone`, which fails on
# every re-run and then silently leaves a stale checkout in place.
clone_or_pull() {
    local url="$1" dest="$2"
    shift 2
    if [[ -d "$dest/.git" ]]; then
        info "updating $dest"
        run git -C "$dest" pull --ff-only
    else
        info "cloning $url -> $dest"
        run git clone "$@" "$url" "$dest"
    fi
}

# --------------------------------------------------------------------- summary

print_summary() {
    banner "SUMMARY"
    log "installed / already present: ${#INSTALLED_PACKAGES[@]} package(s)"
    if ((${#FAILED_PACKAGES[@]} > 0)); then
        error "${#FAILED_PACKAGES[@]} package(s) FAILED:"
        local pkg
        for pkg in "${FAILED_PACKAGES[@]}"; do
            error "  - $pkg"
        done
        log ""
        log "These did not install. Check the name against the AUR, then either"
        log "fix packages/aur.txt or install by hand. Nothing else was skipped."
    else
        ok "no package failures"
    fi
    log "full log: $LOG_FILE"
}
