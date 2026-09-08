---
name: lecture-currency
description: Scan lecture decks for time-sensitive claims, model names, prices, or facts that may have become outdated between semesters.
metadata:
  codex-migrated-from: dotfiles/claude/skills/lecture-currency
---

# Lecture currency sweep

`lecture-gate` checks a deck's **structure**. This checks its **truth decay**:
claims that were accurate when written and quietly stopped being so.

## Run it

```bash
python3 ~/.agents/skills/lecture-currency/scripts/currency_sweep.py [COURSE_ROOT]
```

Defaults to `~/repos/classes/ime/ai_applied_transport_2026`.

| Flag | Purpose |
|---|---|
| `--only model,price` | restrict to categories |
| `--include-taught` | also sweep frozen decks (see below) |

## What it flags

| Category | Why it rots |
|---|---|
| `model` | model generations are superseded every few months |
| `price` | list prices change without notice |
| `context` | context limits grow |
| `benchmark` | leaderboards move |
| `dated` | undated present-tense claims: "currently", "the latest", "as of" |
| `year` | year references that may need advancing |
| `link` | link rot |

## Two deliberate exclusions

**Fenced code blocks are blanked before matching.** A pinned model id or version
inside a code cell is correct by design, not decay — flagging it would train you
to ignore the report.

**Decks the tracker marks `taught` are skipped by default.** The course rule is
that taught decks are closed and never retrofitted, so a stale claim in one is
not actionable. The run prints which classes it skipped. Use `--include-taught`
when preparing the next year's rebuild, where those decks *are* in scope.

## It does not decide what is true

Every hit is a candidate for a human check against a primary source. The script
has no knowledge of current model names, prices or leaderboards — claiming
otherwise would be exactly the failure mode the sweep exists to catch.
