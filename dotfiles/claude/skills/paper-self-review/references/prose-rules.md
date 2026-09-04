# Prose pass: rules with examples

Sources: the advisor's rule (P1), Pinker, *The Sense of Style* (P2 to P7), Knuth, Larrabee and Roberts, *Mathematical Writing* §1 (P6 point 12, P7 point 17). Each rule is applied at the sentence level under the temperament in SKILL.md: an edit that changes meaning becomes a comment.

## P1 The advisor's cut (verbatim teaching case)

Prefer

> ...to extend to the case of X, we change the metric to Y

over

> ...to extend to the case of X, **we need to** change the metric to Y

The "need to" claims a necessity the author cannot guarantee (someone may find a way without it), and it is longer. Generalization: **cut every word that does not strictly need to be there, and never claim necessity when describing a choice.**

First hunting target, modal padding attached to a design choice:

| Cut | Keep or replace with |
|---|---|
| we need to, we must, we have to, it is necessary to | the bare verb |
| in order to | to |
| it should be noted that, it is worth noting that, note that | nothing |
| it is important to, it is essential to | nothing, or the reason itself |
| due to the fact that | because |
| a number of | several, or the number |
| serves to, allows us to, is able to | the bare verb |
| in the context of | in |

## P1b The guard: requirement versus choice

A necessity the paper argues from evidence or from the problem statement is a claim, not padding. Keep it.

- Keep: "A deployable forecasting component for a PMS must deliver three properties at once" (the sentence states the requirement the paper then argues).
- Cut: "To guarantee consistency we must therefore clip the output" becomes "To guarantee consistency we clip the output".

Test: would removing "must" weaken an argument the paper makes, or only soften a description of what the authors did? Only the second is cut.

## P2 Classic style: the window

The reader and writer are equals looking at the subject; the prose does not point at itself. Cut signposting and metadiscourse that describes the writing rather than the subject.

- "It should be noted that the constraint is exact" becomes "The constraint is exact."
- "In this section we describe the metrics" at the head of a section titled Metrics: cut, unless the sentence also says something the title does not.
- A roadmap paragraph that a venue expects stays; hedged versions of it ("we will attempt to") are tightened.

## P3 The curse of knowledge

The expert cannot remember not knowing. Three checks, each yielding a comment or a one-word edit:

1. Every abbreviation is defined at its first use in the body (abstract and captions count as separate first uses if the venue reads them standalone).
2. Every "this", "it", "the latter", "such" has exactly one plausible antecedent. If two, name the referent.
3. No term is used before the sentence that defines it. If "the hard layer" appears two paragraphs before its definition, comment; do not move text.

## P4 Concrete subjects, strong verbs

Light verb plus nominalization becomes the verb. Pattern: perform, conduct, carry out, undertake, make, provide, achieve, exhibit + a noun ending in -tion, -ment, -ance, -sis.

- "an analysis was performed" becomes "we analyzed"
- "provides an improvement in accuracy" becomes "improves accuracy"
- "exhibits a dependence on" becomes "depends on"

Passive voice stays when the agent is unknown or irrelevant ("the sections were surveyed annually").

## P5 Given before new; one term per referent

A sentence opens with what the reader already holds and ends with the new information; consecutive sentences chain on the shared term. Within a section, one referent has one name: the same object is not "the model", then "the learner", then "the predictor". Elegant variation reads as three objects.

- Before: "The predictor is tuned per variant. Reset-Clock features enter the learner. The model is then clipped."
- Comment (not edit, since choosing the term touches the author's vocabulary): "three names for one object; pick one".

## P6 Hedges, intensifiers, self-praise

Cut "very", "quite", "rather", "somewhat", "clearly", "obviously", "of course", "interestingly". Hedge only where uncertainty is real and, if possible, quantified: "may" with a stated condition beats "might possibly". No superlatives for the authors' own work (Knuth 12): "novel", "powerful", "significant" outside its statistical sense, "robust" without the test that shows it.

- "a novel and powerful framework that clearly outperforms" becomes "a framework that outperforms"

## P7 One idea per sentence; left-to-right readability

A sentence is read once. Garden paths (Knuth 17: "In the theory of rings, groups and other algebraic structures are treated") are repaired by reordering within the sentence, never by splitting a paragraph. Heavy phrases go last. Sentences over about 35 words are inspected: if they carry two ideas, split at the conjunction; if one idea with necessary qualifications, leave them.

## P8 Elegance is nothing left to remove

Applied wherever it applies:

- sentence: drop the word that survives every other rule and still adds nothing;
- equation: drop redundant parentheses and `\left ... \right` where plain delimiters fit; drop a restated definition;
- table note: one clause per symbol, no sentence that repeats the caption.
