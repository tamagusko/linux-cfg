---
name: journal-selection
description: Assess and rank journals for a manuscript, including submission strategy after rejection and a second opinion on a named target venue.
metadata:
  codex-migrated-from: dotfiles/claude/skills/journal-selection
---

# Journal Selection

Rank the five best target journals for one manuscript, where "best" is the defensible
optimum of impact, scope fit, and realistic acceptance prospects.

**Core principle: fit is the gate, impact is the ranker.** A high-IF journal that does not
publish this kind of paper is a desk-reject and four wasted months. Establish fit first;
rank only the journals that pass.

## The Iron Law

**Every metric is verified by search at run time. Never from memory.**

Impact factors change every June. Journals migrate quartiles. Special issues open and close.
A remembered IF is a fabricated IF — you cannot tell a 2019 memory from a 2025 one.

**No exceptions:**
- Not for journals you "obviously know" (TR-C, Nature, CBM — verify them too)
- Not for a rough figure ("about 7") — a rough figure is still a claim
- Not when the draft already records one (`PROJECT.md` said IF ~7.4 — re-verify it)
- Not to save time. An unverified number invalidates the whole ranking.

Every metric in the output carries the date it was checked and where it came from.

## Hard Exclusion: no MDPI

**Never recommend an MDPI journal.** Not in the top five, not in the near-misses, not as a
fallback, not "if you need speed". This applies to every MDPI title regardless of quartile
or IF — Sustainability, Sensors, Remote Sensing, Applied Sciences, Smart Cities,
Infrastructures, ISPRS IJGI, Land, Buildings, Electronics, and every other.

Check the publisher when verifying. If the journal's home is `mdpi.com`, drop it before the
fit gate and do not mention it as a candidate.

Stating a fact about an existing placement ("this is currently in revision at Smart Cities")
is reporting, not recommending, and is fine.

## Workflow

1. **Read the paper.** Full text if it exists; abstract + contributions + methods if early.
   Read any `PROJECT.md`, `TODO.md`, `docs/journals.md`, or cover letter in the folder —
   these often name a target or record a rejection history.
2. **Characterise the contribution.** Topic, method, novelty type (new method / new
   evidence / new synthesis), and the audience that needs this result.
3. **Generate 10–15 candidates.** Drive from the paper's content and reference list — the
   journals it cites most are the journals that publish this conversation. Seed with the
   pipeline's clusters (`pipeline_map.md`) and any draft-named target. Drop MDPI titles now.
4. **Verify each candidate** (search, current):
   - Quartile — state which index (JCR or SJR) and which category
   - Impact factor and/or CiteScore, with the year
   - Aims and scope, from the publisher page
   - Recent published papers on this topic — you need 2–3 concrete ones
5. **Apply the fit gate.** A candidate passes only if the scope statement covers it AND the
   journal has recently published work of this kind. Cite the papers. "This journal covers
   transportation" is not fit evidence; "published Chen et al. (2025) on VLM street-image
   auditing in issue 174" is.
6. **Rank the survivors** by impact, weighting Q1 highest. When a strong Q2 with excellent
   fit outranks a marginal Q1 with stretched fit, rank it higher and say so explicitly.
7. **Judge the draft's named target**, if there is one: confirm as rank 1, reposition, or
   argue against — with reasons.
8. **Write the output** in the format below.

## Output Format

Every entry carries all six slots. A missing slot is an incomplete entry.

```markdown
# Target Journals — <paper title>

Verified <YYYY-MM-DD>. Metrics re-verify on each run; do not trust this file after ~3 months.
Draft-named target: <journal, or "none">.

## 1. <Journal> — <Publisher>
- **Metrics:** Q<n> (<JCR|SJR>, <category>), IF <x> (<year>) / CiteScore <y> (<year>) — checked <date>, <source>
- **Fit:** <the argument> Recent: <Author (year), topic, issue>; <Author (year), topic>
- **Realism:** review time <x>; acceptance signals <y>; OA model <z>, APC <amount or "none">;
  special issue: <name + deadline, verified — or "none open">
- **Why this rank:** <one line>

## 2..5 — same six slots

## Considered and excluded
- <Journal> — <one-line reason>  (scope miss, quartile, timeline, publisher policy)

## Verdict on the draft's named target
<Confirmed rank 1 | Repositioned to rank N | Argued against> — <reasoning>

## Open questions
<What would change the ranking: "if the revision strengthens the policy angle, X rises to 2">
```

## Honesty Rules

- **Say when impact loses to fit.** "Q2, but ranked above the Q1 below it because that Q1
  has published nothing on VLM evaluation in three years."
- **Say when you could not verify something.** "Review time not published — no estimate"
  beats an invented number.
- **Flag APCs.** A €3,000 APC is a real constraint, not a footnote.
- **Argue against the draft's target when it is wrong.** The point of the exercise is a
  second opinion, not a rubber stamp.

## Red Flags — stop and re-verify

- An IF appeared in your output without a search behind it
- A quartile with no index named (Q1 *where*?)
- Fit asserted from the journal title alone
- Fit evidence that is a topic area rather than named recent papers
- An MDPI journal anywhere in the recommendations
- A metric with no date

## Common Mistakes

| Mistake | Fix |
|---|---|
| Ranking by IF, then checking fit | Gate on fit first; unfit journals never enter the ranking |
| Trusting the IF recorded in the draft's notes | Re-verify — the note may be two years old |
| Suggesting the journal the paper cites most, unexamined | Citing a journal ≠ that journal publishing your contribution type |
| Five near-identical journals | Span the trade-off: safe fit, reach, fast turnaround |
| Ignoring rejection history in the folder | A rejected venue and its stated reason is the strongest signal available |
