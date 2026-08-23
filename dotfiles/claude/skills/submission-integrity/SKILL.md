---
name: submission-integrity
description: Audit a manuscript for integrity risks before it is submitted — reference correctness, self-overlap with the author's own published and in-progress work, and passages sitting too close to the sources they cite. Use whenever a paper is about to go out: "check my paper before I submit", "plagiarism check", "am I recycling too much of my own work", "is this too close to the source", "check my references", "run an originality check", "self-plagiarism", "text recycling". This is the only originality screen the manuscript gets before the publisher runs iThenticate, so it stands in for a tool the author cannot access. Not for reviewing someone else's manuscript (that is paper-review), and not for building a plagiarism complaint against a third party.
---

# Pre-submission integrity audit

The journal will run iThenticate or Turnitin. The author cannot. This audit is
the only screen the manuscript gets before that one, so its job is to catch what
the editor's similarity report would catch afterwards — when catching it is
expensive and looks like misconduct rather than an oversight.

Self-overlap matters as much as third-party copying here. Journals treat text
recycling and redundant publication as integrity violations in their own right,
and a prolific author's real exposure is a methods paragraph reused from their
own prior paper, not a stolen one.

Two failure modes to avoid in equal measure: softening a real risk because it is
awkward, and inflating standard phrasing into a finding. Both destroy the audit's
usefulness. A shared funding acknowledgement is not plagiarism; say so.

## Permission protocol

The audit runs in three phases, and **each phase's plan is presented for
approval before it executes**. State which files will be read, which external
lookups will run, and what will be compared against what. Nothing is fetched or
compared before the go-ahead.

Once a phase is approved it runs **exhaustively, not sampled**. Caution belongs
in asking; it does not belong in the comparison.

## Scope

Confirm the manuscript file first — a paper directory usually holds several
candidates (`main.tex`, `main_old.tex`, `main_diff.tex`), and auditing the wrong
one wastes the whole run.

**Self-overlap corpus**
- `/home/tamagusko/repos/papers/published/` — every paper in it, in full
- `/home/tamagusko/repos/papers/in-progress/` — the author's other live papers,
  because two parallel submissions overlapping each other is the redundant
  publication trap, and it is read-only here

**Source-overlap corpus** — the reference PDFs held for this paper, usually in
the paper's own `references/` folder. Every held PDF the manuscript cites.

**Scholar is a completeness cross-check only.** The profile at
`https://scholar.google.com/citations?user=_mJ4dr0AAAAJ&hl=en` is consulted to
see whether any published paper is missing from the folder. A missing paper is
declared as a coverage gap; it is never silently skipped, and Scholar is not
used as a comparison source.

## Phase 1 — Reference integrity

For every entry: does it exist (DOI resolves), does the metadata match (authors,
year, title, venue), does the in-text citation match the entry, and are there
orphans in either direction — cited but not listed, listed but not cited.

Then the harder check: **does the cited source actually support the sentence
citing it?** Spot-verify against held PDFs. Where the source is not held, the
verdict is `unverifiable — not held`, never a guess.

Verdicts: `verified` / `metadata error` / `unsupported claim` / `unverifiable`.

The `citation-verification` skill covers the bibliographic mechanics; use it
rather than reimplementing them.

## Phase 2 — Self-overlap

Run the mechanical pass first:

```bash
python3 "$CLAUDE_SKILL_DIR/scripts/overlap.py" <manuscript> \
    --against ~/repos/papers/published/ ~/repos/papers/in-progress/
```

It reports every run of matching words with both passages side by side, and what
fraction of the manuscript sits inside a run. Defaults are 8-word shingles and a
12-word minimum run; lower `--min-run` to widen the net at the cost of noise.

**Then read for what the script cannot see.** Shingling is blind to reworded
duplication by construction, so a clean mechanical run narrows the human task
rather than ending it. Read the methods and background sections against the
closest prior paper and ask whether the same content is being presented twice.
Substantive-claim duplication — the same finding offered as new in two papers —
is a redundant-publication risk even when every sentence differs.

Check figures and tables too. The script sees text only.

## Phase 3 — Source overlap

Same script, pointed at the held reference PDFs. Then read for the three
patterns string matching misses:

- **quoted without marks** — the source's words, no quotation marks
- **structural tracking** — the source's sentence shape with synonyms substituted
- **mosaic** — source phrases stitched together with the author's connectives

The test to apply: placed next to its source, would this passage look derivative
to a similarity report or to a vigilant reviewer?

For passages whose sources are *not* held — claims citing papers without a local
PDF, and methods boilerplate that may echo the open literature — propose
targeted web searches of distinctive phrases. List the target passages for
approval rather than searching everything; this is a spot-check standing in for
a web-corpus check, and it should be aimed at the highest-risk sentences.

## Severity

| Level | Meaning |
|---|---|
| **critical** | Would trip the journal's screen, or constitutes redundant publication. Must fix. |
| **advisory** | Close enough to warrant rewording for safety. |
| **noted** | Technically similar but standard and defensible. Recorded, no action. |

A worked example of `noted`, from a real run: a 14-word funding acknowledgement
shared with the author's own prior paper. Identical text, zero risk — projects
have fixed funding statements. Flagging that as a finding would train the author
to ignore the report.

Every `critical` and `advisory` finding carries a proposed rewrite that preserves
the technical meaning while breaking the textual dependence. Where a rewrite
would change the meaning, hand it to the author instead of guessing.

## Reporting

Every overlap finding shows **both passages side by side** with locations. Every
reference verdict shows what was checked. Suspicion is not evidence and does not
appear.

Close with a coverage statement, because the value of this audit depends on the
author knowing its edges:

- what was compared exhaustively
- what was only spot-checked
- what the journal's screen will see that this could not — the paywalled
  publisher corpus, principally
- any published paper missing from the folder

The point is submission with known risk rather than assumed safety.

## Applying fixes

Work on a versioned copy. **Never overwrite the original**, and deliver a diff.
References are untouched except for approved corrections. After rewriting,
re-run the affected comparison to confirm the dependence is actually broken.

Overlaps with a parallel in-progress paper are reported, never resolved — which
paper keeps the passage is the author's call, not the auditor's.
