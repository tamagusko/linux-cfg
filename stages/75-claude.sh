#!/usr/bin/env bash
# Stage 75 — Claude Code: the CLI, node for its hooks, and the config tree.
# shellcheck source=lib/common.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

banner "STAGE 75 — CLAUDE CODE"

CLAUDE_DIR="$HOME/.claude"
SRC_DIR="$REPO_DIR/dotfiles/claude"

if [[ ! -d "$SRC_DIR" ]]; then
    die "$SRC_DIR is missing — the checkout is incomplete"
fi

# ---------------------------------------------------------------------- node
#
# Every hook in settings.json is JavaScript. Without node they do not error
# loudly, they simply never run, and the shell looks fine while none of the
# session-start, security-guard or skill-evaluation hooks fire. So this is a
# hard requirement, checked before anything is linked.
if ! have node; then
    info "installing nodejs (required by the Claude Code hooks)"
    pac nodejs npm
fi
ok "node $(node --version 2>/dev/null || echo '?')"

# ----------------------------------------------------------------------- bun
#
# node is not the only runtime the hooks need. The claude-mem plugin ships its
# own hooks — SessionStart, UserPromptSubmit, PostToolUse — and every one of
# them shells out to a launcher that runs the real script under bun. Without
# bun the launcher exits 1 and Claude Code prints
#
#     UserPromptSubmit hook error
#     Failed with non-blocking status code: Error: Bun not found.
#
# on every single prompt. Non-blocking, so nothing breaks, but it is noise on
# every turn and the plugin's memory capture is dead.
#
# Plugins themselves are not vendored (see below) — but the runtime they need
# is a system package, and that is this repo's job.
if ! have bun; then
    info "installing bun (required by the claude-mem plugin hooks)"
    pac bun
fi
ok "bun $(bun --version 2>/dev/null || echo 'missing — claude-mem hooks will warn')"

# --------------------------------------------------------------- claude code
#
# The native installer, which is what this Mac uses: it drops versioned trees
# under ~/.local/share/claude/versions/ and points ~/.local/bin/claude at one.
# Deliberately NOT npm -g: a global npm install ties the CLI's lifetime to the
# node version, and `claude update` cannot manage it.
if have claude; then
    ok "claude already installed ($(claude --version 2>/dev/null || echo 'version unknown'))"
elif confirm "install Claude Code via the official installer?"; then
    # Reviewed before running rather than piped blind from a URL: the script is
    # fetched, its size and first lines shown, and only then executed.
    installer="$(mktemp)"
    run curl -fsSL https://claude.ai/install.sh -o "$installer"
    info "installer fetched: $(wc -l <"$installer" | tr -d ' ') lines, $(wc -c <"$installer" | tr -d ' ') bytes"
    if [[ "$DRY_RUN" != "1" ]]; then
        head -20 "$installer"
        if confirm "run it?"; then
            run_tty bash "$installer"
        else
            warn "skipped — install manually from https://claude.com/claude-code"
        fi
    fi
    command rm -f -- "$installer"
else
    warn "skipping Claude Code install"
fi

# ------------------------------------------------------------------- config
#
# ~/.claude mixes two very different things:
#
#   config  — skills, agents, commands, hooks, rules, CLAUDE.md, settings.json
#   runtime — projects/ (chat history), sessions/, file-history/, todos/,
#             plugins/ (~1GB of marketplace cache), debug/, telemetry/
#
# Only the first belongs in git. So ~/.claude itself is a real directory and
# each config entry inside it is symlinked individually. Symlinking the whole
# of ~/.claude would drag a gigabyte of history into the repo and make every
# session dirty the working tree.
#
# Because these are links, a skill written on either machine lands in the repo,
# where git sees it. That is the point.
mkdir -p "$CLAUDE_DIR"

# settings.json is included knowingly. Claude Code writes to it at runtime
# (enabledPlugins, survey timestamps), so it will show up in `git status` after
# a session. That noise is the price of never silently losing a setting.
LINKS=(skills agents commands hooks rules scripts CLAUDE.md settings.json)

for entry in "${LINKS[@]}"; do
    src="$SRC_DIR/$entry"
    dest="$CLAUDE_DIR/$entry"

    if [[ ! -e "$src" ]]; then
        warn "$entry not in the repo — skipping"
        continue
    fi

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        ok "$entry already linked"
        continue
    fi

    # Real files here are whatever a previous install or Claude Code itself
    # created. Keep a timestamped copy rather than deleting someone's work.
    if [[ -e "$dest" && ! -L "$dest" ]]; then
        backup_file "$dest"
        run rm -rf -- "$dest"
    elif [[ -L "$dest" ]]; then
        run rm -f -- "$dest"
    fi

    if run ln -sfn "$src" "$dest"; then
        ok "linked ~/.claude/$entry -> dotfiles/claude/$entry"
    else
        warn "could not link $entry"
    fi
done

# ------------------------------------------------------------------- plugins
#
# Not vendored. settings.json carries `extraKnownMarketplaces` (8 sources) and
# `enabledPlugins` (27 entries); Claude Code fetches them from those sources.
# Copying the ~1GB plugins/ cache would be both huge and stale.
#
# Whether that fetch happens unprompted on a cold machine has NOT been verified
# here, so this says what to check rather than claiming it is automatic.
info "plugins are fetched from the marketplaces listed in settings.json"
info "after first launch, confirm with:  claude  then  /plugin"

# ---------------------------------------------------------------- mcp secrets
#
# settings.json ships with no live credentials — the MCP entries hold only
# ${GEMINI_API_KEY} (an env reference) and <your-api-key> placeholders. Real
# values go in ~/.config/linux-cfg/secrets.env, which is outside the repo.
SECRETS="$HOME/.config/linux-cfg/secrets.env"
if [[ -e "$SECRETS" ]]; then
    ok "secrets file already present: $SECRETS"
else
    info "creating a secrets template at $SECRETS"
    mkdir -p "$(dirname "$SECRETS")"
    if [[ "$DRY_RUN" != "1" ]]; then
        cat >"$SECRETS" <<'SECRETS_TEMPLATE'
# Credentials for the MCP servers declared in ~/.claude/settings.json.
#
# This file is OUTSIDE the git repository on purpose. Never move it in, and
# never paste a real key into settings.json.
#
# Sourced from ~/.zshrc. Fill in what you use and delete the rest.

# github — the official GitHub plugin's MCP server, which is HTTP and sends this
# as "Authorization: Bearer". A classic PAT needs `repo` for private
# repositories and `read:org` for organisation data; scope it down if you only
# read public ones. Create at https://github.com/settings/tokens
# export GITHUB_PERSONAL_ACCESS_TOKEN=

# nano-banana (Gemini image generation)
# export GEMINI_API_KEY=

# zotero-mcp — also needs the entries in settings.json changed from their
# <your-...> placeholders, or install it with:  uv tool install zotero-mcp
# export ZOTERO_API_KEY=
# export ZOTERO_LIBRARY_ID=
SECRETS_TEMPLATE
        chmod 600 "$SECRETS"
    fi
    ok "wrote $SECRETS (mode 600)"
fi

ensure_block "$HOME/.zshrc" "claude-secrets" <<'BLOCK'
# MCP credentials, kept out of the repo.
[[ -r "$HOME/.config/linux-cfg/secrets.env" ]] && source "$HOME/.config/linux-cfg/secrets.env"
BLOCK

warn "MCP servers needing keys stay inert until you fill in $SECRETS"

ok "claude code stage done"
