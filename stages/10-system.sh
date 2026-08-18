#!/usr/bin/env bash
# Stage 10 — keyrings, full system upgrade, build tools, microcode, paru.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 10 — SYSTEM BASE"

# Keyrings first and on their own. A stale keyring makes every later signature
# check fail in a way that looks like a mirror problem.
info "refreshing keyrings"
pac archlinux-keyring
# EndeavourOS ships its own keyring; absent on vanilla Arch, so only if present.
if pacman -Si endeavouros-keyring >/dev/null 2>&1; then
    pac endeavouros-keyring
fi

# Full upgrade. Never a partial upgrade on a rolling distro: -Sy followed by
# installing a package is the classic way to break the system.
info "full system upgrade (this can take a while)"
run_tty sudo pacman -Syu --noconfirm

# Fallback kernel. With a GPU driver that builds kernel modules, one bad
# mainline kernel should not cost a working desktop. This is the second layer of
# the safety net, alongside the snapshots in stage 90.
pac linux-lts linux-lts-headers

# Build prerequisites for anything from the AUR.
pac base-devel git

# CPU microcode. Detected rather than hardcoded, so this still holds if the
# machine changes. A Ryzen 7 5700X resolves to amd-ucode.
if grep -qi 'AuthenticAMD' /proc/cpuinfo; then
    info "AMD CPU detected"
    pac amd-ucode
elif grep -qi 'GenuineIntel' /proc/cpuinfo; then
    info "Intel CPU detected"
    pac intel-ucode
else
    warn "could not identify CPU vendor; skipping microcode"
fi

# paru. Bootstrapped by hand because it is the tool that installs from the AUR.
# Built inside a mktemp directory cleaned up by trap. The previous version ran
# `sudo rm -rf $FOLDER/paru` with an unquoted variable derived from $(pwd),
# which is a root delete over word-split arguments.
if have paru; then
    ok "paru already installed ($(paru --version | head -1))"
else
    info "bootstrapping paru from the AUR"
    build_dir="$(mktemp -d)"
    cleanup_build_dir() { [[ -n "${build_dir:-}" ]] && command rm -rf -- "$build_dir"; }
    trap cleanup_build_dir EXIT
    run git clone https://aur.archlinux.org/paru.git "$build_dir/paru"
    info "PKGBUILD for paru — read this, it builds and installs as root:"
    run_tty cat "$build_dir/paru/PKGBUILD"
    if confirm "proceed with building paru?"; then
        ( cd "$build_dir/paru" && run_tty makepkg -si --noconfirm )
        ok "paru installed"
    else
        die "paru is required for the AUR packages in this repo"
    fi
fi

ok "system base ready"
