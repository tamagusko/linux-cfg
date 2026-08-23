# Claude Code workflow audit — 2026-08-23

Evidence: on-disk setup + repos; claude-mem observations from prior Code sessions;
user-supplied usage profile (claude.ai history). Machine is 3 days old, so absence
of a repo is NOT evidence of absence of work (backend/AI-eng/optimisation/webdev).

## Headline

The unexplored territory is mostly **already installed**. The gap is adoption, not
acquisition. Almost nothing needs installing; two things need building; one config
contradicts a rule you wrote; two security findings are still open from April.

## Setup inventory (verified)

- 140 skills, 36 agents, 36 commands, 30 enabled plugins.
- MCP: zotero (0.3.1 = current), nano-banana, stitch, notebooklm, playwright,
  firecrawl, context7, claude-mem.
- Connectors Gmail / Google Calendar / Google Drive: present but **NOT
  authenticated** (their tool surface exposes only `authenticate`).
- Native and unused: `schedule` (cloud routines), `loop`, `xlsx`, Artifact tool.

## Divergences (setup vs actual use)

1. Huge installed surface, narrow real use. Most of the 140 skills are library
   wrappers (matplotlib, polars, sklearn) duplicating what you'd do unaided.
   The four that match your profile are ones you BUILT: paper-review,
   journal-selection, submission-integrity, lecture-gate.
2. `applications/Professor/paper_tracker.xlsx` — "Last updated: 6 April 2026",
   15 manuscripts. 4.5 months stale as of today.
3. `papers/review/paper_review_config.json` pins `analysis: claude-opus-4-8`
   (a generation behind) and has no independent judgement gate — the validate
   step is mechanical-only. This contradicts rules/model-routing.md, which says
   the separate gate is the point.
4. Course: classes 1-2 taught; 3-6 gated awaiting YOUR approval; 7 partial
   (session-limit interrupt 2026-08-21); 8-14 briefed. Class 3 is due 24/08.
5. Security, still open: `papers/.mcp.json` with a literal GEMINI_API_KEY,
   tracked since 2026-04-09; student grades + `emails_alunos.md` tracked in
   `classes` (incl. copies under `_trash_2025/`).

## Ranked recommendations

0. SECURITY (do first, not ranked on time saved)
1. BUILD manuscript-pipeline skill  — reads the workbook + papers/ + git
2. ADOPT native scheduled routine   — weekly pipeline brief (depends on 1)
3. FIX review-pipeline routing      — one config edit + a gate step
4. BUILD lecture-currency sweep     — dated claims in decks

## Skip list

Claude in Excel; Research feature; agentic submission-portal browsing;
Gmail/Drive connectors; mobile; academic-research-skills catalog plugins.
Reasons in the conversation report.
