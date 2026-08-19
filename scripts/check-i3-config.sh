#!/usr/bin/env bash
#
# Static checks for dotfiles/i3/config.
#
#   ./scripts/check-i3-config.sh
#
# Exists because two config bugs shipped that neither shellcheck nor a plain
# read caught:
#
#   1. $ws9 / $ws10 were used by keybindings but never defined, so those keys
#      created workspaces literally named "$ws9".
#   2. `set $mon_main DP-5  # big central monitor` — i3's `set` takes the whole
#      rest of the line as the value, so the variable expanded to
#      "DP-5  # big central monitor" and every line using it failed to parse.
#
# Both are invisible until i3 reloads. This catches them beforehand, and runs
# i3's own parser when i3 is installed.

set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-$REPO_DIR/dotfiles/i3/config}"

[[ -r "$CONFIG" ]] || { echo "not readable: $CONFIG" >&2; exit 1; }

fail=0

printf '\n=== 1. trailing comments on set lines ===\n'
# A colour like `set $darkblue #08052b` is fine: the value starts with #.
# A value followed by whitespace then # is not.
if grep -nE '^[[:space:]]*set[[:space:]]+\$[A-Za-z0-9_]+[[:space:]]+[^#[:space:]][^#]*#' "$CONFIG"; then
    printf '  ^ i3 includes the comment in the value. Move it to its own line.\n'
    fail=1
else
    printf '  none\n'
fi

printf '\n=== 2. variables used but never defined ===\n'
defined=$(grep -oE '^[[:space:]]*set[[:space:]]+\$[A-Za-z0-9_]+' "$CONFIG" \
          | grep -oE '\$[A-Za-z0-9_]+' | sort -u)
used=$(grep -vE '^[[:space:]]*#' "$CONFIG" \
       | sed -E 's/^[[:space:]]*set[[:space:]]+\$[A-Za-z0-9_]+//' \
       | grep -oE '\$[A-Za-z0-9_]+' | sort -u)
missing=$(comm -13 <(printf '%s\n' "$defined") <(printf '%s\n' "$used") || true)
if [[ -n "$missing" ]]; then
    printf '  %s\n' "$missing"
    fail=1
else
    printf '  none\n'
fi

printf '\n=== 3. referenced scripts exist and are executable ===\n'
missing_scripts=0
# shellcheck disable=SC2088  # the tilde below is a regex literal, not a path
while read -r path; do
    [[ -n "$path" ]] || continue
    resolved="${path/#\~\/.config\/i3/$REPO_DIR/dotfiles/i3}"
    if [[ ! -e "$resolved" ]]; then
        printf '  MISSING: %s\n' "$path"
        missing_scripts=1; fail=1
    elif [[ ! -x "$resolved" ]]; then
        printf '  NOT EXECUTABLE: %s\n' "$path"
        missing_scripts=1; fail=1
    fi
done < <(grep -oE '~/\.config/i3/scripts/[A-Za-z0-9_.-]+' "$CONFIG" | sort -u)
((missing_scripts == 0)) && printf '  all present\n'

printf '\n=== 4. i3 parser ===\n'
if command -v i3 >/dev/null 2>&1; then
    if i3 -C -c "$CONFIG"; then
        printf '  i3 -C: OK\n'
    else
        printf '  i3 -C reported errors (above)\n'
        fail=1
    fi
else
    printf '  i3 not installed here; run this on the target machine for the real check\n'
fi

printf '\n'
if ((fail)); then
    printf 'FAILED\n\n'
    exit 1
fi
printf 'OK\n\n'
