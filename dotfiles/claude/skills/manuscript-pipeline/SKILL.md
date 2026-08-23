---
name: manuscript-pipeline
description: Use when reviewing the state of manuscripts in flight — "where are my papers", "what's the pipeline status", "which submissions have gone quiet", "is the tracker up to date". Reconciles the paper tracker workbook against the papers repo and git history, and reports where they disagree.
---

# Manuscript pipeline status

The tracker workbook is a hand-maintained snapshot; the repo is ground truth for
activity. This skill makes the workbook **derived rather than remembered** by
reporting where the two disagree.

## Run it

```bash
python3 ~/.claude/skills/manuscript-pipeline/scripts/pipeline_status.py
```

Options:

| Flag | Default | Purpose |
|---|---|---|
| `--tracker` | `~/repos/applications/Professor/paper_tracker.xlsx` | `.xlsx` **or `.csv`** |
| `--papers` | `~/repos/papers` | repo to reconcile against |
| `--aliases` | `aliases.json` beside this file | row → directory overrides |
| `--today` | today | for testing |

## Source-agnostic by design

`--tracker` takes `.csv` as readily as `.xlsx`, so a Google Sheets export drops
in with no code change. The Sheet at
`docs.google.com/spreadsheets/d/1IH8GHaj6Pe_YrDGW2nvxa0Fwuqwpps3q0Mpv-nzj1AI`
is **private (HTTP 401)** and cannot be read without one of:

1. authenticating the Google Drive connector — broad Drive access;
2. File → Share → Publish to web as CSV — **makes unpublished titles and
   co-author names readable by anyone with the URL**;
3. File → Download → `.xlsx` into the repo — no exposure, but manual.

Option 2 is the only one that is both automatic and free, and it is the one
that leaks. That trade is the user's to make, not this skill's.

## What it reports

- **Staleness** of the tracker's `Last updated` banner.
- **A row-by-row table**: tracker status beside the matched directory and its
  last commit.
- **Recent activity**, ranked. When the tracker predates most rows (as it does
  when months behind), per-row drift flags are suppressed — flagging 11 of 15
  rows restates the tracker's age rather than telling you anything.
- **Unresolved rows** — a tracker row with no directory.
- **Orphans** — work in `in-progress/` with no tracker row.

## Matching, and why it declines

Directories are named after the project (`ucd-camina`, `colourways_framework`),
so matching is by project-slug containment, then by token coverage. Rows titled
`[full title to be defined]` cannot be matched by any heuristic.

**A wrong match is worse than none**, so ambiguity reports as unmatched — e.g.
`COLOURWAYS` matches both `colourways_framework` and `ucd-colourways` and is
therefore declined. Resolve these once in `aliases.json`, keyed on the row's
Title (preferred) or Project, valued with the directory name.

## It never writes

Output is a report. The workbook is co-author-visible and edits are the user's
to make — the skill proposes, it does not rewrite.
