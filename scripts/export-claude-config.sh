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
FORCE=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=(--dry-run) ;;
        --force)   FORCE=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

DIRS=(skills agents commands hooks rules scripts)

# ---------------------------------------------------------------- preflight
#
# Everything below is checked BEFORE the first rsync, because rsync --delete
# mutates the repo immediately and there is no useful half-done state.
#
# This exists because the first version had only the symlink guard, and running
# it on a freshly installed workstation replaced the repo's 123 skills with the
# empty ~/.claude of a machine that had never been configured. The rsync
# succeeded; only the later `cp` of CLAUDE.md failed, so the error message
# pointed at the wrong thing entirely.
die() { echo "export refused: $*" >&2; exit 1; }

[[ -d "$SRC" ]] || die "no $SRC on this machine"

# Backwards run. If a directory here is already a link into the repo, this
# machine is a consumer of the config, not its source.
for d in "${DIRS[@]}"; do
    if [[ -L "$SRC/$d" && "$(readlink -f "$SRC/$d")" == "$DST/$d" ]]; then
        echo "$SRC/$d is a symlink into this repo — edit the files directly." >&2
        die "this machine is set up by stage 75; nothing to export from it"
    fi
done

# Fresh machine. A configured ~/.claude always has CLAUDE.md; one installed by
# stage 75 has it as a symlink, which the loop above already caught.
[[ -f "$SRC/CLAUDE.md" ]] || die "$SRC/CLAUDE.md is missing — this looks like an
unconfigured machine. To INSTALL the config here, run instead:

    ./install.sh --only 75-claude"

# Wholesale loss. Exporting a source with a fraction of the repo's content means
# the source is not authoritative — a partial install, a wrong HOME, a machine
# mid-setup. Shrinking is legitimate when you delete skills on purpose, so this
# is overridable rather than fatal.
for d in "${DIRS[@]}"; do
    ((FORCE == 0)) || break
    [[ -d "$DST/$d" ]] || continue
    # -L follows symlinks, matching what `rsync -L` will actually write. Without
    # it the 71 linked skills count as 1 file each here but expand to hundreds
    # in the repo, and this check fires on a perfectly good export.
    have_n=$(find -L "$SRC/$d" -type f 2>/dev/null | wc -l | tr -d ' ')
    repo_n=$(find "$DST/$d" -type f 2>/dev/null | wc -l | tr -d ' ')
    ((repo_n > 10)) || continue
    if ((have_n * 2 < repo_n)); then
        echo "  $d: source has $have_n files, repo has $repo_n" >&2
        die "the source is far smaller than the repo, which --delete would erase.
Re-run with --force if you really mean to shrink it."
    fi
done

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
