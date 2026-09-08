# The filter, worked

Every example below is real, drawn from the reviewing corpus at
`~/repos/papers/review/`. The rejected ones were written by the same reviewer as
the admitted ones — the filter is a discipline, not a judgement about anybody.

## Admitted — errors

These pass unconditionally. Note that severity varies enormously and none of
them is excluded for being small.

**A broken algorithm.**
> Algorithm 1, Step 3 and Step 5: The pseudocode contains a critical logical
> error. Step 3 sets TotalCost = f(z), but z is undefined ... Step 5a states "If
> TotalCost <= p: exit the While loop", but the while condition already checks
> TotalCost <= p. As written, the algorithm would exit immediately or never
> terminate correctly.

**A physically impossible unit.**
> L43 — Unit error. "a 100 x 100 mm aggregation grid for the entire city" should
> read "100 x 100 m". A 100 mm grid at city scale is physically absurd.

**A statistic the paper reports but does not confront.**
> the Weibull fit for depth is rejected at alpha = 0.05 and indeed at alpha =
> 0.001. The paper notes "mild model tension" but does not state that the formal
> KS test rejects the model.

**Data contradicting the paper's own definition.**
> (Critical) Data validity: reported pothole widths up to 6-12 m and lengths up
> to 10-20 m are inconsistent with the manuscript's own definition of a pothole.

**A novelty claim refuted by a work the authors themselves cite.**
> The sentence "no pavement software product or optimization algorithm has taken
> into consideration the spatial correlations" is overstated. Yang et al. (2009)
> [2], which the authors themselves cite, explicitly addresses spatial
> clustering of pavement segments.

**A typo — still an error, so still admitted.**
> The word "fascial" is used throughout in place of "fiscal". This appears at
> least six times across the manuscript (pages 3, 4, 5, 8, 18) and must be
> corrected throughout.

## Rejected — suggestions that do not earn their place

**Stock comment.** Appears near-verbatim in three separate reviews of three
different papers:
> Redundant Keywords: The keywords are all terms taken directly from the title.
> Please replace these with new, complementary terms that better facilitate
> searching and indexing.

Rejected because it could have been written before reading the paper. That is
the cleanest possible failure: a comment that fits any manuscript describes none.

**Unactionable complaint.**
> The writing could be more concise and focused.

Rejected because there is nothing to check off. Every neighbouring comment in the
same review names a line, a missing detail, or a fix; this one names nothing.

**Praise-padding plus a visualization preference.**
> Table 8 is a great contribution, and it is excellent, I recommend creating a
> graph.

Rejected twice over: the superlatives carry no information, and table-versus-graph
does not touch validity.

**Reading recommendations dressed as a gap.**
> Strengthen the discussion with state-of-the-art references from 2020-2025.
> Specifically, consult recent works by Prof. Carlo Ratti (MIT) and Prof. Filip
> Biljecki (NUS).

Rejected because it never says what argument is missing. The proof is in the
response: the authors satisfied it by adding five citations, and not one claim
in the paper changed. A citation request that can be discharged without altering
an argument was not load-bearing.

**Typesetting artifact.**
> The caption appears separated from the figure on a different page. Please
> ensure that the figure and its caption remain together.

Rejected because production fixes this automatically. Reviewing the proof rather
than the paper.

**Pure styling.**
> Italicized Formatting: The italicized item "Transport & Mobility" is not usual
> in a scientific paper.

Rejected: "not usual" is not "unclear" and not "wrong".

**Cosmetic trimming.**
> Figures 5 and 6 carry a "Source: Own elaboration based on ANAC data" note that
> is unnecessary; removing it tightens the captions.

Rejected: the paper is equally valid and equally clear either way.

**Indexing preference.**
> Keywords would benefit from adding "Difference-in-Differences" and "Brazil",
> and JEL C21 alongside C23.

Rejected, and the hedge gives it away — "would benefit" is how a suggestion
announces that nothing is wrong.

**Restating the paper as if that were assessment.**
> Wellington and Washington DC show dramatic improvements (21-25% increase in
> <15min accessibility). School accessibility shows greatest improvement across
> all cities.

Rejected because it does no critical work. It re-reports the abstract.

**Language purism.**
> Recomenda-se ajustar o titulo, evitando o uso de termos em ingles no meio da
> frase.

Rejected: no bearing on clarity, correctness or reproducibility.

## Borderline, and how to decide

**Promotional wording in an abstract.**
> "groundbreaking spatial clustering method" is overly promotional. Replace with
> "constraint-based spatial clustering method".

This one turns on what the word is doing. If "groundbreaking" is decoration,
it is a style preference and gets cut. If the abstract is claiming a novelty the
results do not support, that is an overclaim — an error — and it is admitted,
but written as the overclaim rather than as a word choice: name the claim and
the evidence that fails to support it.

The general principle: when a comment could be either, decide by asking what
happens if the authors ignore it. If the paper then asserts something it has not
shown, it was an error. If it merely reads less modestly, it was taste.
