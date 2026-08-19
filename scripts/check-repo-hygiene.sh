#!/usr/bin/env bash
#
# Audit this public repo for things that should not be in it.
#
# Two failure modes, both specific to the symlink layout:
#
#   1. dotfiles/<pkg> is symlinked to ~/.config/<pkg>, so an application can
#      write state — caches, tokens, recently-used lists — straight into the
#      working tree. It sits there untracked and invisible until someone runs
#      `git add -A`, at which point it is one push from being public.
#
#   2. A credential pasted into a file that is already tracked. The pre-commit
#      hook catches this at commit time; this script catches what is already
#      committed, including anything added before the hook existed.
#
# Read-only: reports, never changes anything. Exit 1 if anything was found.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
found=0

echo "=== 1. untracked files inside dotfiles/ ==="
# Excludes what .gitignore already covers, since that is the intended state.
untracked="$(git ls-files --others --exclude-standard -- dotfiles/ 2>/dev/null || true)"
if [[ -n "$untracked" ]]; then
    printf '%s\n' "$untracked" | sed 's/^/  /'
    echo "  -> an app wrote these into a linked config dir. Track them if they"
    echo "     are config; add them to .gitignore if they are state."
    found=1
else
    echo "  none"
fi

echo
echo "=== 2. ignored-but-present files inside dotfiles/ ==="
# These are correctly not committed, but their presence means a linked dir is
# accumulating exactly the kind of file this layout is worst at containing.
ignored="$(git ls-files --others --ignored --exclude-standard -- dotfiles/ 2>/dev/null || true)"
if [[ -n "$ignored" ]]; then
    printf '%s\n' "$ignored" | sed 's/^/  /'
    echo "  -> ignored, so safe, but worth knowing they exist."
else
    echo "  none"
fi

echo
echo "=== 3. credentials in tracked content ==="
# Same patterns as scripts/git-hooks/pre-commit, applied to the whole tree
# rather than to one staged diff.
PATTERNS='sk-ant-[A-Za-z0-9_-]{20,}
ghp_[A-Za-z0-9]{30,}
github_pat_[A-Za-z0-9_]{30,}
AIza[A-Za-z0-9_-]{30,}
xox[baprs]-[A-Za-z0-9-]{20,}
AKIA[0-9A-Z]{16}
-----BEGIN (RSA|DSA|EC|OPENSSH|PGP) PRIVATE KEY-----'
hits=0
while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    if out="$(git grep -nIE -e "$pattern" -- . 2>/dev/null | head -5)"; [[ -n "$out" ]]; then
        # Filenames only. Printing the match would copy the secret into the
        # terminal scrollback of whoever ran the audit.
        printf '%s\n' "$out" | cut -d: -f1 | sort -u | sed 's/^/  /'
        hits=1
    fi
done <<< "$PATTERNS"
if (( hits )); then
    echo "  -> a tracked file matches a live-credential pattern. This repo is"
    echo "     public: rotate the credential first, then purge the history."
    found=1
else
    echo "  none"
fi

echo
echo "=== 4. pre-commit hook active ==="
hooks_path="$(git config --local core.hooksPath || true)"
if [[ "$hooks_path" == "scripts/git-hooks" && -x scripts/git-hooks/pre-commit ]]; then
    echo "  active (core.hooksPath = $hooks_path)"
else
    echo "  NOT active — commits are unscanned. Fix with:"
    echo "     git config core.hooksPath scripts/git-hooks"
    found=1
fi

echo
if (( found )); then
    echo "FINDINGS ABOVE — see each section."
    exit 1
fi
echo "OK — nothing to report."
