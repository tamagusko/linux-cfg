#!/usr/bin/env bash
#
# Re-export ~/.claude into dotfiles/claude/.
#
#   ./scripts/export-claude-config.sh [--dry-run]
#
# Only needed on a machine where ~/.claude is NOT symlinked to this repo — in
# practice, the Mac this config was first grown on. On a machine set up by
# stage 75 the links already point here, so edits land in the repo directly and
# running this would be a no-op at best.
#
# What it filters out, and why each one matters:
#
#   gsd-*         get-shit-done is deliberately not part of this setup.
#   symlinks      65 skills link to ~/.agents/skills and 6 to ~/.orchestra.
#                 Neither exists on a fresh machine, so rsync -L copies the
#                 real contents instead of shipping 71 dangling links.
#   .git/         one vendored skill carries its own repository. Nested inside
#                 a tracked tree git turns it into a gitlink and the contents
#                 are silently never committed.
#   __pycache__/  build artefacts, architecture-specific, pure noise.
#
# Runtime state (projects/, sessions/, plugins/, file-history/, telemetry/,
# debug/) is never exported. That is ~2.4GB of chat history and marketplace
# cache with no business in version control.

set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$HOME/.claude"
DST="$REPO_DIR/dotfiles/claude"

DRY=()
[[ "${1:-}" == "--dry-run" ]] && DRY=(--dry-run)

[[ -d "$SRC" ]] || { echo "no $SRC on this machine" >&2; exit 1; }

# Refuse to run backwards. If ~/.claude/skills is already a link into the repo,
# rsyncing it back over itself is at best pointless and at worst destructive.
if [[ -L "$SRC/skills" && "$(readlink -f "$SRC/skills")" == "$DST/skills" ]]; then
    echo "$SRC is already linked to this repo — edit the files directly." >&2
    echo "This script is only for exporting from an unlinked machine." >&2
    exit 1
fi

DIRS=(skills agents commands hooks rules scripts)

for d in "${DIRS[@]}"; do
    [[ -d "$SRC/$d" ]] || { echo "skip $d (absent)"; continue; }
    rsync -aL --delete --delete-excluded "${DRY[@]}" \
        --exclude='gsd-*' \
        --exclude='.DS_Store' \
        --exclude='*.log' \
        --exclude='.git/' \
        --exclude='__pycache__/' \
        --exclude='*.pyc' \
        --exclude='node_modules/' \
        --exclude='.venv/' \
        "$SRC/$d/" "$DST/$d/"
    echo "exported $d"
done

if [[ ${#DRY[@]} -eq 0 ]]; then
    cp "$SRC/CLAUDE.md" "$DST/CLAUDE.md"

    # settings.json is filtered rather than copied: strip every GSD hook and the
    # GSD statusline, which are the only entries carrying absolute macOS paths.
    python3 - "$SRC/settings.json" "$DST/settings.json" <<'PY'
import copy, json, sys

src, dst = sys.argv[1], sys.argv[2]
d = json.load(open(src))
dropped = 0

hooks = d.get("hooks", {})
for ev in list(hooks):
    groups = []
    for g in hooks[ev]:
        kept = [h for h in g.get("hooks", []) if "gsd-" not in h.get("command", "")]
        dropped += len(g.get("hooks", [])) - len(kept)
        if kept:
            g = copy.deepcopy(g)
            g["hooks"] = kept
            groups.append(g)
    if groups:
        hooks[ev] = groups
    else:
        del hooks[ev]

if "gsd-" in d.get("statusLine", {}).get("command", ""):
    del d["statusLine"]
    dropped += 1

with open(dst, "w") as f:
    json.dump(d, f, indent=2)
    f.write("\n")
print(f"exported settings.json (dropped {dropped} GSD entries)")
PY

    # The kb-* commands point at a knowledge base by absolute path. ~ survives
    # the move between /Users and /home; /Users/<name> does not.
    sed -i.bak "s|$HOME/repos/papers/kb/|~/repos/papers/kb/|g" "$DST"/commands/kb-*.md 2>/dev/null || true
    command rm -f "$DST"/commands/kb-*.md.bak 2>/dev/null || true
fi

echo
echo "--- verification ---"
printf 'symlinks left   : %s (must be 0)\n' "$(find "$DST" -type l | wc -l | tr -d ' ')"
printf 'gsd-* left      : %s (must be 0)\n' "$(find "$DST" -name 'gsd-*' | wc -l | tr -d ' ')"
printf 'nested .git     : %s (must be 0)\n' "$(find "$DST" -name '.git' | wc -l | tr -d ' ')"
# Deliberately narrow: this machine's own home and Homebrew prefix. A generic
# /Users/ search matches documentation examples ("/Users/name/plugins/...") and
# WSL paths in unrelated skills, which are not portability problems and would
# make this check cry wolf every run.
printf 'machine paths   : %s (must be 0)\n' "$(grep -rIl -e "$HOME" -e '/opt/homebrew' "$DST" 2>/dev/null | wc -l | tr -d ' ')"
printf 'size            : %s\n' "$(du -sh "$DST" | cut -f1)"
echo
echo "Now review with: git -C '$REPO_DIR' status --short dotfiles/claude"
