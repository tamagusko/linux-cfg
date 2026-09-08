#!/usr/bin/env bash
# Stage 76 — Codex: shared skills and global orchestration instructions.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 76 — CODEX"

CODEX_DIR="$HOME/.codex"
AGENTS_DIR="$HOME/.agents"
SRC_DIR="$REPO_DIR/dotfiles/codex"
CODEX_SKILLS="$SRC_DIR/skills"
SKILL_LIST="$SRC_DIR/skills.txt"

[[ -r "$SRC_DIR/AGENTS.md" ]] || die "$SRC_DIR/AGENTS.md is missing"
[[ -r "$SKILL_LIST" ]] || die "$SKILL_LIST is missing"

mkdir -p "$CODEX_DIR" "$AGENTS_DIR/skills"

link_config() {
    local src="$1" dest="$2" label="$3"

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        ok "$label already linked"
        return
    fi

    if [[ -e "$dest" && ! -L "$dest" ]]; then
        backup_file "$dest"
        if [[ -d "$dest" ]]; then
            run rm -rf -- "$dest"
        else
            run rm -f -- "$dest"
        fi
    elif [[ -L "$dest" ]]; then
        run rm -f -- "$dest"
    fi

    run ln -sfn "$src" "$dest"
    ok "linked $label"
}

link_config "$SRC_DIR/AGENTS.md" "$CODEX_DIR/AGENTS.md" "~/.codex/AGENTS.md"

skill_number=0
while IFS= read -r skill; do
    [[ -n "$skill" && "$skill" != \#* ]] || continue
    skill_number=$((skill_number + 1))

    src="$CODEX_SKILLS/$skill"
    dest="$AGENTS_DIR/skills/$skill"
    [[ -r "$src/SKILL.md" ]] || die "selected skill is missing: $src/SKILL.md"

    link_config "$src" "$dest" "$(printf '%02d' "$skill_number"). $skill installed"
done < "$SKILL_LIST"

# This previously managed link is superseded by the tailored writing-anti-ai
# skill. Remove it only when it still points into this repository.
retired="$AGENTS_DIR/skills/humanizer"
if [[ -L "$retired" && "$(readlink -f "$retired")" == "$REPO_DIR/dotfiles/claude/skills/humanizer" ]]; then
    run rm -f -- "$retired"
    ok "retired duplicate skill humanizer"
fi

if [[ -f "$CODEX_DIR/config.toml" ]] && grep -Eq '^model[[:space:]]*=[[:space:]]*"gpt-5\.6-sol"' "$CODEX_DIR/config.toml"; then
    ok "Codex default model is gpt-5.6-sol"
else
    warn "set model = \"gpt-5.6-sol\" in ~/.codex/config.toml"
fi

ok "Codex stage done"
