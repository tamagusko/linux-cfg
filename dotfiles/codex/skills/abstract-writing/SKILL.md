---
name: abstract-writing
description: Draft or audit an academic abstract for transportation, civil engineering, AI/ML, or urban analytics, with sentence and word-budget checks.
metadata:
  codex-migrated-from: dotfiles/claude/skills/abstract-writing
---

# Abstract writing

Seven sentences of argument, a completeness check, a counted budget, present
tense, nothing signposted: four layers, one workflow, run in order. The model
writes; `scripts/abstract_audit.py` counts.

**Governing rule:** the reader is deciding whether to download. Findings, in
numbers, are what they need and what authors most often leave out.

## Before writing

1. **Mode.** Draft, or review of an existing abstract. In review mode the
   manuscript is never edited: diagnosis and rewrite go to the user. The
   rewrite may add facts the original omitted when the body states them.
2. **Length.** Target 150 words, floor 100, ceiling 250; a lower venue limit
   replaces the ceiling. Check the project's venue notes (`plan/`, `CLAUDE.md`)
   and say whether the limit is verified or assumed.
3. **Keywords.** The 5 or 6 phrases a searcher would type; the manuscript's
   list when it exists. The list is in scope: a keyword the abstract cannot
   carry naturally is swapped, not stuffed in.
4. **Numbers.** Only figures the body already quotes, traced to the results
   file. Never retype or re-round.
5. **Sources.** The whole manuscript; early in a project, results and
   conclusions, and say so.

## Layer 1: the spine (draft)

Easterbrook's six sentences with results split from execution, so seven
roles. Write them as full sentences in the author's voice before any prose.

| Role | The sentence answers | Rule |
|---|---|---|
| topic | What is this about, for a reader who knows the field but not this work? | One sentence. |
| question | What is the one research question? | If the paper cannot be stated as one question, stop and report that: the abstract is not the problem. |
| gap | Why has nobody answered it adequately? | The specific gap this work fills. Never a survey. |
| idea | What is the new approach? | One sentence, named if the paper names it. |
| execution | How was it done: data, scale, experiments? | Longest sentence allowed, still readable aloud in one breath. |
| results | What was found, in numbers? | Every claim carries a figure, attributed to the right variant or condition. |
| impact | What does it mean and who should care? | Implication, not the result restated. State the reach: general, generalizable, or this case. |

Filled example (illustrative figures):

> [topic] Cities audit cycling infrastructure by sending surveyors to walk the
> network. [question] Can street-level imagery replace the field audit?
> [gap] Previous work classifies single images; none scores whole corridors
> against an audit standard. [idea] This paper scores each corridor by
> aggregating per-image detections of the audit's twelve attributes.
> [execution] The model is trained on 14,200 annotated Mapillary images from
> Dublin and evaluated against surveyor scores on 312 corridors in two other
> cities. [results] Corridor scores agree with surveyors at kappa 0.78, and the
> model flags 9% of corridors for a field visit. [impact] A city can audit its
> network from imagery it already holds and send surveyors only where the
> model is unsure.

Merge into one paragraph within the length; sentences may fuse or split, every
role keeps its words. Keep the tags in a working copy for the script.

## Layer 2: completeness (check)

The paragraph must answer all five, each pointing at the sentence that does it:
**motivation** (why anyone cares), **problem and scope** (what, and how far the
claim reaches), **approach and extent** (how, and how much: one dataset or
twenty), **results in numbers** ("raises the consistent share from 74% to
81%", never "significantly better"; a vague quantifier survives only for a
genuine order-of-magnitude claim, and then says so), **conclusions** with their
generality stated.

Three search-era rules: self-contained (no "below", section, figure or
citation), hedged where the limit is real ("may", "suggests"), every keyword
present verbatim. An inflected form ("monotone" for "Monotonic") is accepted
only when the verbatim form would misread in the sentence.

## Layer 3: the counted audit

```
python3 ~/.agents/skills/abstract-writing/scripts/abstract_audit.py TAGGED.txt --tex main.tex --limit N
```

Budget shares are of the abstract's own length, loosened five points from
LSE's 200-to-300-word bands to fit 150 words and seven roles:

| Element | Budget | At 150 words |
|---|---|---|
| others' work (topic, question, gap) | ≤ 25% | ≤ 37 |
| own approach (idea) | ≥ 15% | ≥ 22 |
| methods and data (execution) | 15 to 40% | 22 to 60 |
| findings (results) | the remainder, never < 25% | ≥ 38 |
| value (impact) | ≥ 10% | ≥ 15 |

Budget misses are warnings; findings win ties. Two judgement checks the script
only sets up, answered in one line each: **title alignment** (title themes
recur; no major abstract theme is absent from the title) and the **download
test** (would the title plus the first three lines make a stranger download
this?).

## Layer 4: conventions and voice

- Present tense for the work: "this paper shows". Not "showed", not "will show".
- Zero signposting. "This article sets out to examine whether X holds" becomes
  "Whether X holds is untested". Cut, do not rephrase.
- One paragraph; two only when the venue asks.
- Positive framing without overclaiming: the numbers carry it. A claim true at
  one horizon or condition names that condition.
- The limit is met by the author's own cuts, never left to an editor.
- Voice: active, concrete verbs, numbers over adjectives, one term per
  referent, no em-dashes, none of: leverage, robust, delve, cutting-edge,
  holistic, seamless, transformative, groundbreaking.

Hard checks (the script fails the abstract on any hit; a hit is fixed, not
argued): over the ceiling or under the floor; a vague quantifier with no number
in its sentence; signposting; AI vocabulary; em-dash; future tense on the work;
outward reference; a missing keyword; a spine role with no words. Warnings
(direction words without a number, budget misses, inflected keywords) are
adjudicated and the decision stated.

Results pair, for calibration:

> vague: "The constrained model significantly outperforms the baseline."
> numeric: "The constraint raises the share of physically consistent forecasts
> from 77% to 81% at no accuracy cost."

## Review mode

Same layers, as diagnostics: map the original onto the seven roles (missing,
fused), run the checklist quoting the offending phrase, script the tagged
original, then write the rewrite and script it too; deliver both audits side by
side. A number the original attributes to the wrong variant is the headline
finding, above any style point.

## Output contract

```
## Abstract: <paper>, <venue>, <limit, verified or assumed>, <mode>, <date>
### Spine
<seven tagged sentences>
### Abstract (<N> words)
<the paragraph>
### Completeness
| element | sentence | verdict |
### Audit
<script output>
<title alignment and download test, one line each>
### Keywords: <list, each verbatim / inflected / missing>
### Recommendation (review mode): adopt / adopt with edits / keep original, and why
```

## Red flags: stop and go back a layer

- Prose before the seven sentences exist.
- A results sentence without a figure in it ("improves accuracy").
- A "question" that needs two sentences.
- A keyword dropped into a sentence that would not otherwise say it.
- A number attributed to the whole method when the table gives it to one part.
- The word count came from reading, not from the script.
- Rewriting the manuscript's abstract in place during a review.
