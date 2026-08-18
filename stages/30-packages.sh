#!/usr/bin/env bash
# Stage 30 — bulk package installation from packages/*.txt
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 30 — PACKAGES"

mapfile -t pacman_pkgs < <(read_package_list "$REPO_DIR/packages/pacman.txt")
mapfile -t aur_pkgs    < <(read_package_list "$REPO_DIR/packages/aur.txt")

# ------------------------------------------------------------- official repos
#
# Validate names BEFORE installing. Official repo names are stable and
# checkable, so an unknown name here is a bug in this repo and should stop the
# run loudly rather than half-install and continue.
info "validating ${#pacman_pkgs[@]} official package name(s)"
unknown=()
for pkg in "${pacman_pkgs[@]}"; do
    pacman -Si "$pkg" >/dev/null 2>&1 || unknown+=("$pkg")
done

if ((${#unknown[@]} > 0)); then
    error "these names are not in the official repositories:"
    for pkg in "${unknown[@]}"; do
        error "  - $pkg"
    done
    die "fix packages/pacman.txt (a renamed or removed package) before continuing"
fi
ok "all official package names resolve"

pac "${pacman_pkgs[@]}"

# ---------------------------------------------------------------------- AUR
#
# One at a time, continuing past failures. See lib/common.sh aur() for why.
info "installing ${#aur_pkgs[@]} AUR package(s), one at a time"
aur "${aur_pkgs[@]}"

ok "package stage done"
