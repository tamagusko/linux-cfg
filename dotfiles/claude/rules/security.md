# Security Rules

## Secrets Management

### Never Store Secrets in Git-Tracked Files

- API keys, tokens, passwords must NEVER appear in committed files
- Use environment variables or `.env` files (which are gitignored)
- `~/.claude/settings.json` IS tracked in linux-cfg, deliberately: it holds only
  `${ENV_VAR}` references and `<placeholder>` strings, never a value. Real values
  belong in the environment or in `settings.local.json`, which is gitignored.
  Keep it that way — the moment a literal token is pasted into `settings.json`,
  it is one commit from a public repository.

### Environment Variables

```python
import os

# GOOD: Read from environment
api_key = os.environ["API_KEY"]

# BAD: Hardcoded secret
api_key = "sk-abc123..."
```

### `.env` File Usage

```bash
# .env (gitignored)
ANTHROPIC_AUTH_TOKEN=sk-ant-...
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_...
WANDB_API_KEY=...
```

```python
# Load in code
from dotenv import load_dotenv
load_dotenv()
```

## Sensitive File Warnings

The following files must NEVER be committed to Git:

| File Pattern | Reason |
|-------------|--------|
| `settings.local.json`, `.mcp.local.json` | Real values for MCP servers and overrides |
| `.env`, `.env.*` | Environment secrets |
| `*.pem`, `*.key` | Private keys |
| `credentials.json` | Service account credentials |
| `*_secret*`, `*_token*` | Named secret files |
| `*.sqlite`, `*.db` | May contain user data |

## Enforcement in linux-cfg

These rules are enforced mechanically, not by memory:

| Layer | What it catches | Where |
|-------|-----------------|-------|
| `.gitignore` deny-rules | secret *filenames* swept up by `git add -A` | `.gitignore` |
| pre-commit scanner | secret *content* in files that are already tracked | `scripts/git-hooks/pre-commit` |
| hygiene audit | state written into symlinked `dotfiles/` dirs; already-committed secrets | `scripts/check-repo-hygiene.sh` |

The scanner is wired up by `git config core.hooksPath scripts/git-hooks`, done
in stage 00. `git commit --no-verify` bypasses it, which is correct for a false
positive and never correct for "I will clean it up later" — linux-cfg is a
public repository and its history is not editable in practice.

Note the layout risk this addresses: `dotfiles/<pkg>` is symlinked to
`~/.config/<pkg>`, so a symlink is not a protective boundary. Whatever an
application writes into a linked directory is already inside the working tree.
Directories that mix config with state or credentials should be copied through
an allowlist instead, the way `scripts/export-claude-config.sh` handles
`~/.claude` — it exports only `agents/`, `commands/`, `hooks/`, `rules/`,
`skills/`, `settings.json` and `CLAUDE.md`, and never `projects/`, `sessions/`
or `file-history/`.

## Code Security

### Prohibited in Source Code

- Hardcoded passwords or API keys
- Hardcoded IP addresses or internal URLs (use config)
- Disabled SSL verification without justification
- `eval()` or `exec()` with user input
- SQL string concatenation (use parameterized queries)

### Pre-Commit Checks

The `security-guard.js` hook automatically checks for:
- Secrets in file content before write/edit operations
- Dangerous bash commands
- Sensitive file modifications

## Token Rotation

If a token is accidentally committed:
1. Immediately rotate the compromised token
2. Use `git filter-branch` or BFG Repo-Cleaner to remove from history
3. Force push the cleaned history
4. Verify the old token is invalidated
