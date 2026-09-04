---
name: paper-self-review
description: Use for the last review round of the user's own manuscript, the pass immediately before submission when the science is settled and only the delivery is refined. Triggers include "final pass", "last review round", "pre-submission polish", "final polish", "self-review before submission", "one last read before I submit". Not for first drafts, not for drafting or restructuring the abstract (abstract-writing runs before this pass), not for reviewing someone else's paper (paper-review), not for answering reviewers (review-response), not for originality checks (submission-integrity).
version: 0.3.0
---

# Paper Self-Review (the final pass)

The paper is done. This pass corrects and refines the delivery; it never rewrites. Two sweeps (math typesetting, prose), one read-only settledness check, and a change log that names the rule behind every edit and every rule that did not fire.

## Temperament (governs every rule below)

- **T1 Corrections and refinements only.** No paragraph rewritten, no sentence moved across a paragraph boundary, no structure, claim, number, result or citation changed.
- **T2 Meaning-touching fixes become comments, not edits.** LaTeX: a `% REVIEW(rule): ...` line above the sentence. Docx: a document comment.
- **T3 Every edit is tagged with its rule ID** in the change log; rules that did not fire are listed as such.
- **T4 Match the document's register.** Contractions and direct address stay where the manuscript already uses them and are never introduced.
- **T5 Docx source:** math rules apply to equation objects by analogy; LaTeX mechanics are skipped with a note. Never edit a file in a transformed state (an anonymized copy, a tracked-changes export): edit the source and regenerate.
- **T6 Never retype a number.** Manuscript numbers come from results files; a suspect value gets a comment.

## Workflow

1. Locate the source (`main.tex` or `.docx`) and the sections in scope; read them whole before touching anything.
   The abstract is in scope only after abstract-writing has run on it (review mode) and the user has adopted or declined its rewrite; if that has not happened, say so and run abstract-writing first, since this pass may not restructure.
2. Math sweep first, because it is mechanical: run `python3 scripts/math_sweep.py main.tex` for candidates, then adjudicate each one against `references/math-typesetting.md`. A candidate is not a finding until the source confirms it.
3. Prose sweep with `references/prose-rules.md`, paragraph by paragraph in source order.
4. Settledness check with `references/settledness-check.md`: comments only.
5. Compile with the project's compile rule; confirm the page count and that no new warnings appear.
6. Write the change log in the output contract below (see `examples/`).

## Prose pass (detail and examples in `references/prose-rules.md`)

| ID | Rule |
|---|---|
| P1 | The advisor's cut: prefer "to extend to the case of X, we change the metric to Y" over "we need to change". Cut every word that does not strictly need to be there; never claim necessity when describing a choice. Modal padding is the first hunting target. |
| P1b | Necessity of a requirement argued from evidence is not a claim about a choice; keep it. |
| P2 | Classic style: prose is a window onto the subject. Cut metadiscourse and remarks about the writing itself. |
| P3 | Anti-curse-of-knowledge: abbreviations defined at first body use; every "this", "it", "the latter" has one antecedent; no term used before its definition. |
| P4 | Concrete subjects, strong verbs: light verb plus nominalization becomes the verb. |
| P5 | Given before new; one term per referent across a section, no elegant variation. |
| P6 | Cut intensifiers and reflexive hedges; hedge only where the uncertainty is real and quantified; no self-praise. |
| P7 | One idea per sentence, readable left to right, heavy phrase last. Sentences over about 35 words get inspected, not split by reflex. |
| P8 | Elegance is nothing left to remove, in a sentence, an equation or a table note alike. |

## Math typesetting pass (detail in `references/math-typesetting.md`)

| ID | Rule |
|---|---|
| M1 | No `\frac` inline; slash form in running text, `\frac` in displays. |
| M1b | A slash with more than two atoms is ambiguous: parenthesize. Unit strings (m/km) are exempt. |
| M2 | No numeric footnote marker where it reads as an exponent; symbolic marker, relocate, or fold into text. |
| M3 | Thin space before every differential: `\int f(x)\,dx`. |
| M4 | Thin space between number and unit: `0.5\,m/km`. |
| M5 | Multi-letter operators upright: `\mathrm{PCR}`. |
| K1 | No sentence, caption or list item starts with a symbol. |
| K2 | Symbols in different formulas are separated by words, including across a sentence boundary. |
| K3 | Every variable defined at first use; comment if not. |
| K4 | Displayed equations are parts of sentences: punctuate them; no colon before a display unless grammar demands it; the sentence before an algorithm or theorem is complete or ends with a colon. |
| K5 | The sentence still reads with every formula replaced by "blah". |
| K6 | Words, not logic symbols, in running text. |
| K7 | One symbol per concept and one concept per symbol; comment if not. |
| K8 | Sticky words ("this", "also", "therefore") not in consecutive sentences; parallel form for parallel ideas. |
| K9 | Small numbers spelled out as adjectives, digits as names; capitalize Theorem 1, Algorithm 2, Section 3. |
| K10 | Punctuation logical with respect to parentheses; "that" for restrictive clauses and kept after "assume"; never "we have that"; en dash in two-name compounds. |

## Output contract

```
## Final pass: <paper>, <sections>, <date>
### Edits (applied)
| # | Line | Rule | Before | After |
### Comments (meaning-touching, not applied)
| # | Line | Rule | Issue | Suggestion |
### Rules that did not fire
<IDs, one line each, with the reason where informative>
### Blocking comments: <N>
```

## Red flags: stop, and downgrade to a comment

- "This paragraph would read better restructured" (T1).
- "This number looks wrong, I'll fix it" (T6).
- "A footnote here would clarify" (T1, M2).
- Cutting "must" from a sentence that states a requirement the paper argues for (P1b).
- Introducing a contraction because the register allows it (T4).
