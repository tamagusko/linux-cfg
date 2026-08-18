#!/usr/bin/env bash
#
# Check every name in packages/*.txt against the live repositories and AUR.
#
# Run this on the target machine before a fresh install. It exists because
# package names drift: skypeforlinux-stable-bin outlived the Skype product,
# texlive-most was reorganised out of existence, and python39 outlived Python
# 3.9. A name that resolved in 2022 is not evidence that it resolves today.
#
#   ./scripts/verify-packages.sh
#
# Exit status is 1 if anything failed to resolve, so it is usable in CI or a
# pre-install check.

set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read_list() {
    sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

missing=0

printf '\n=== official repositories ===\n'
while read -r pkg; do
    if info_line=$(pacman -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/{v=$2} /^Repository/{r=$2} END{print r" "v}'); then
        printf '  %-34s OK    %s\n' "$pkg" "$info_line"
    else
        printf '  %-34s ** NOT FOUND **\n' "$pkg"
        missing=$((missing + 1))
    fi
done < <(read_list "$REPO_DIR/packages/pacman.txt")

printf '\n=== AUR ===\n'
if ! command -v paru >/dev/null 2>&1; then
    printf '  paru not installed; skipping AUR checks\n'
else
    while read -r pkg; do
        if info_line=$(paru -Si "$pkg" 2>/dev/null | awk -F': ' '/^Version/{v=$2} /^Maintainer/{m=$2} /^Out-of-date/{o=$2} END{print v"  maint="m"  ood="o}'); then
            printf '  %-34s OK    %s\n' "$pkg" "$info_line"
        else
            printf '  %-34s ** NOT FOUND IN AUR **\n' "$pkg"
            missing=$((missing + 1))
        fi
    done < <(read_list "$REPO_DIR/packages/aur.txt")
fi

printf '\n'
if ((missing > 0)); then
    printf '%d package(s) did not resolve. Fix packages/*.txt before installing.\n' "$missing"
    exit 1
fi
printf 'All package names resolve.\n'
