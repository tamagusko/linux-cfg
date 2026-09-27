#!/usr/bin/env bash
# Stage 75 — Claude Code and Codex, from the private ai-config repository.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 75 — AI CONFIG"

# The Claude Code and Codex setup (skills, agents, hooks, plugins, MCP servers)
# moved to a private repository on 2026-09-27. It is shared with a Mac, so its
# installer handles both platforms itself; this stage only fetches it and hands
# over. Without access to that repository (anyone cloning this public one) the
# stage skips and the rest of the install is unaffected.
AI_CONFIG_URL="${AI_CONFIG_URL:-git@github.com:tamagusko/ai-config.git}"
AI_CONFIG_DIR="${AI_CONFIG_DIR:-$HOME/repos/ai-config}"

if [[ ! -d "$AI_CONFIG_DIR/.git" ]] &&
   ! git ls-remote "$AI_CONFIG_URL" >/dev/null 2>&1; then
    warn "ai-config is not accessible ($AI_CONFIG_URL) — skipping"
    exit 0
fi

clone_or_pull "$AI_CONFIG_URL" "$AI_CONFIG_DIR"

args=()
[[ "$DRY_RUN" == "1" ]] && args+=(--dry-run)
[[ "${ASSUME_YES:-0}" == "1" ]] && args+=(--yes)

# A dry run on a fresh machine has cloned nothing, so there is nothing to call.
if [[ ! -x "$AI_CONFIG_DIR/install.sh" ]]; then
    info "would run $AI_CONFIG_DIR/install.sh ${args[*]}"
else
    # Its own log and its own prompts, so it runs attached to the terminal.
    bash "$AI_CONFIG_DIR/install.sh" "${args[@]}"
fi

ok "ai-config stage done"
