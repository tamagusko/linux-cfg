# The error sweep

Recall stage. Collect everything; the filter runs later and only on suggestions,
never on errors.

A broader catalogue of methodological and statistical failure modes already
exists at `~/.agents/skills/peer-review/references/common_issues.md` (22
categories). Read it for depth. One correction when you do: that file says "This
is not an exhaustive list", which is the right disclaimer for a textbook and the
wrong posture here. Treat it as a floor, not a ceiling.

## Recompute, do not eyeball

Anything computable gets computed, in a script. A reviewer who does arithmetic
in their head eventually asserts something false in public, and a false claim in
a review costs more credibility than a missed finding.

- Percentages, ratios, rates: do they follow from the counts given?
- Table columns and rows: do they sum to the stated totals?
- Sample sizes: do the numbers in the text, tables and figures agree, and do
  they survive the exclusions the methods describe?
- Unit conversions, and whether the resulting magnitude is physically possible
  at the stated scale.
- Degrees of freedom, and whether they match the design described.
- Reported test statistics against reported p-values, where both appear.
- Effect sizes recomputed from the group statistics given.
- Anything the abstract quantifies, against the results section.

When a number cannot be checked because the input is not reported, that is
itself a finding: say what is missing and why it prevents verification.

## Internal consistency

- Abstract claims against results.
- Text against its own tables and figures.
- Conclusions against what the results actually establish.
- Methods against results: was everything described actually run, and does
  anything appear in results that the methods never mention?
- Notation: every symbol defined before use, used consistently, not reused for
  two different quantities.
- Algorithms and pseudocode traced line by line, including loop conditions and
  termination. Undefined variables and inverted conditions hide here.
- In-text citations against the reference list, both directions.
- Claims attributed to cited works: does the cited work actually say that? A
  novelty claim contradicted by a reference the authors themselves cite is a
  recurring and serious find.

## Method-specific

**Statistics.** Test selection against data type and design; assumptions stated
and checked; multiple comparisons; whether a reported failure to reject is
presented as evidence of no effect; whether a formal test result is softened in
prose. Delegate depth to the `statistical-reviewer` agent.

**Machine learning.** Train/test contamination, including spatial and temporal
leakage; whether the split respects the dependence structure; baselines that are
actually competitive; hyperparameter selection on the test set; metrics
appropriate to class balance; variance across seeds; whether claimed
improvements exceed run-to-run noise.

**Spatial.** Autocorrelation, MAUP, edge effects, projection and grid resolution
consistency, whether aggregation units are justified.

**Causal claims.** Identification strategy against the data structure; parallel
trends where difference-in-differences is used; two-way fixed effects with
staggered treatment and heterogeneous effects; whether the language of the
conclusions exceeds what the design supports.

## Reproducibility

Data availability and provenance; code availability; software versions;
random seeds; enough parameter detail to re-run; whether the described procedure
could in fact be followed by a reader.

## Presentation, but only where it impairs the reader

Figures illegible at print size, or encoding categories indistinguishably.
Missing axis labels or units. Captions that do not stand alone. These are
admitted when they prevent the reader from verifying a claim the paper makes —
a figure that is the sole evidence for the central argument and cannot be read
is a real defect, not a preference.

Typographic and copy-editing points are collected into one comment, never
itemised separately.

## Ethics and integrity

Human subjects approval where required; consent; privacy and anonymisation for
imagery and trajectory data; conflicts and funding disclosure; signs of image
manipulation or duplication; undisclosed overlap with the authors' prior work.
