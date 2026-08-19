#!/usr/bin/env bash
# Stage 00 — preflight. Refuse to start on a machine this repo does not target.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 00 — PREFLIGHT"

require_not_root

# Arch family only. EndeavourOS ships /etc/os-release with ID=endeavouros and
# ID_LIKE=arch; vanilla Arch has ID=arch.
if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    info "detected: ${PRETTY_NAME:-unknown}"
    case "${ID:-}:${ID_LIKE:-}" in
        arch:*|*:*arch*) ok "Arch-family system" ;;
        *) die "this repo targets Arch / EndeavourOS; found ID=${ID:-?}" ;;
    esac
else
    die "/etc/os-release not readable; cannot confirm this is an Arch-family system"
fi

# Network. Everything downstream downloads something.
if run curl -fsS --max-time 10 https://archlinux.org/ -o /dev/null; then
    ok "network reachable"
else
    die "no network (could not reach archlinux.org)"
fi

# sudo. Ask for the password once, up front, rather than blocking halfway
# through an otherwise unattended run.
info "requesting sudo (once, up front)"
run_tty sudo -v || die "sudo not available for this user"
ok "sudo available"

# Disk. A full TeX Live plus CUDA plus the AUR build cache is not small.
avail_gb=$(df --output=avail -BG / 2>/dev/null | tail -1 | tr -dc '0-9' || echo 0)
if ((avail_gb < 25)); then
    warn "only ${avail_gb}GB free on / — CUDA + TeX Live + AUR builds want ~25GB"
    confirm "continue anyway?" || die "aborted by user (low disk)"
else
    ok "${avail_gb}GB free on /"
fi

# Git hooks for this clone. Done in preflight rather than in a later stage
# because it protects every commit made from the moment the repo exists on a
# machine, and because a leak is not fixable after the fact: this repo is
# public, so a pushed credential must be treated as burned and rotated.
#
# core.hooksPath points git at the versioned directory instead of copying into
# .git/hooks, so an improvement to the scanner reaches every clone on the next
# pull rather than only the machines where someone re-ran the installer.
if [[ -d "$REPO_DIR/.git" ]]; then
    current_hooks="$(git -C "$REPO_DIR" config --local core.hooksPath || true)"
    if [[ "$current_hooks" == "scripts/git-hooks" ]]; then
        ok "git hooks already point at scripts/git-hooks"
    else
        info "pointing git hooks at scripts/git-hooks (secret scanner)"
        run git -C "$REPO_DIR" config core.hooksPath scripts/git-hooks
    fi
else
    warn "not a git clone — skipping the pre-commit secret scanner"
fi

# Filesystem. Snapshots in stage 90 require btrfs; say so now, not later.
root_fs=$(findmnt -no FSTYPE / 2>/dev/null || echo unknown)
info "root filesystem: ${root_fs}"
if [[ "$root_fs" != "btrfs" ]]; then
    warn "root is ${root_fs}, not btrfs — stage 90 will skip snapper and say so"
fi

ok "preflight passed"
