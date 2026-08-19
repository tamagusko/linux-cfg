#!/usr/bin/env bash
#
# Print the connected outputs with geometry, position and rotation, then the
# three `set $mon_*` lines for dotfiles/i3/config.
#
# Output names are not stable across machines, GPUs or even cable changes, so
# the i3 config keeps them in three variables at the top. This prints what to
# put there.
#
#   ./scripts/monitors.sh

set -euo pipefail
IFS=$'\n\t'

command -v xrandr >/dev/null 2>&1 || {
    echo "xrandr not found (X11 only — this does not apply under Wayland)" >&2
    exit 1
}

printf '\n=== connected outputs ===\n\n'
printf '  %-12s %-12s %-12s %s\n' OUTPUT RESOLUTION POSITION ORIENTATION
printf '  %-12s %-12s %-12s %s\n' ------ ---------- -------- -----------

# Example xrandr lines:
#   DP-5 connected primary 2560x1440+1920+0 (normal left inverted ...) 597mm x 336mm
#   DP-2 connected 1440x2560+4480+0 left (normal left inverted ...) 597mm x 336mm
xrandr --query | awk '
    $2 == "connected" {
        out = $1
        geom = ""
        for (i = 2; i <= NF; i++) {
            if ($i ~ /^[0-9]+x[0-9]+\+[0-9-]+\+[0-9-]+$/) { geom = $i; gi = i; break }
        }
        if (geom == "") next

        split(geom, a, "+")
        res = a[1]; pos = a[2] "," a[3]
        split(res, r, "x")
        w = r[1]; h = r[2]

        rot = "landscape"
        if ($(gi+1) == "left" || $(gi+1) == "right" || $(gi+1) == "inverted") rot = $(gi+1)
        if (h > w) rot = rot " (PORTRAIT)"
        if (index($0, "primary")) rot = rot " [primary]"

        printf "  %-12s %-12s %-12s %s\n", out, res, pos, rot
    }
'

printf '\n=== suggested lines for dotfiles/i3/config ===\n\n'

# Heuristics, stated plainly so a wrong guess is obvious rather than silent:
#   vertical = taller than wide
#   main     = largest remaining area
#   small    = smallest remaining area
xrandr --query | awk '
    $2 == "connected" {
        geom = ""
        for (i = 2; i <= NF; i++)
            if ($i ~ /^[0-9]+x[0-9]+\+[0-9-]+\+[0-9-]+$/) { geom = $i; break }
        if (geom == "") next
        split(geom, a, "+"); split(a[1], r, "x")
        w = r[1]; h = r[2]; area = w * h
        if (h > w) { vert = $1; next }
        if (area > maxarea) {
            if (main != "") { small = main; smallarea = mainarea }
            main = $1; maxarea = area; mainarea = area
        } else if (small == "" || area < smallarea) {
            small = $1; smallarea = area
        }
    }
    END {
        printf "set $mon_main   %s\n", (main  != "" ? main  : "<UNDETECTED>")
        printf "set $mon_vert   %s\n", (vert  != "" ? vert  : "<UNDETECTED>")
        printf "set $mon_small  %s\n", (small != "" ? small : "<UNDETECTED>")
    }
'

printf '\nCheck these against the table above before pasting — the guesses are\n'
printf 'by geometry alone (taller-than-wide = vertical, largest = main).\n\n'
