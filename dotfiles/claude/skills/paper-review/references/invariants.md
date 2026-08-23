# Voice and invariants

Derived from 31 reviews at `~/repos/papers/review/` — 24 English, 7 Portuguese.

**There is no house template, and inventing one would be a fabrication.**
Structure varies by venue, by round, and even within a single manuscript's
review chain: one paper's round 1 is unnumbered thematic bullets and its round 2
is a verification table. Numbering restarts per subsection in two venues and
runs flat 1 to 38 in others. The editor-confidential block appears in two files
out of twenty-four.

So fit the venue's own form. What follows are the traits that do hold across the
corpus, each supported by several independent documents.

## The five invariants

**1. Diagnosis and fix in the same comment.** Universal — all 31 reviews. Never
state a problem and leave the remedy to the authors.

**2. Location opens the comment.** `Algorithm 1, Step 3`, `L43`, `Abstract,
line 10`, `Methodology, Algorithm 4, Step 2`, `Equação (1), Seção 3.1`.

**3. Modal split between errors and suggestions.** Errors take obligation —
*must be corrected*, *should read*, *This must be resolved*. Suggestions take
hedged first person — *I would soften to ...*, *Consider ...*. Never blur these:
the contrast is how a reader sorts mandatory from optional at a glance.

**4. Explicit branching when a concern cannot be settled from the text.**
> Two interpretations are possible, and the manuscript must resolve which
> applies. (a) ... (b) ...

**5. A separate home for genuine questions.** A `Questions for authors` section
holds what the reviewer cannot determine, kept apart from what the reviewer
asserts.

## Verdict vocabulary

The corpus drifts badly here — `Major Revision` and `Major Revisions`, `Minor
Review` for `Minor Revision`, `Recomendation` misspelled, `MAJOR REVISION
REQUIRED`, and several reviews with no verdict line at all. That is a defect,
not a style. Standardise on:

```
Recommendation: Accept
Recommendation: Minor Revision
Recommendation: Major Revision
Recommendation: Major Revision (borderline reject)
Recommendation: Reject
```

Exactly one line, exactly these strings, always present.

## Prose

Active voice. US English. No em dashes or en dashes as punctuation. No AI-marker
vocabulary: delve, crucial, pivotal, multifaceted, landscape, underscore,
leverage, it is worth noting. No filler, no hedging stacks, no rule-of-three
padding.

Acknowledge when a concern is minor or when a choice was defensible — the review
is balanced, not hostile. Soften overclaims rather than demanding removal, and
propose the replacement wording.

## Output mechanics

Plain text for submission forms: no `#`, `**`, backticks, bullet characters or
link syntax, since none of it renders in the box it is pasted into.

Numbering runs continuously across severity headings rather than restarting
under each, so authors and editors can refer to "comment 14" unambiguously.

## Brazilian Portuguese

Used for ANPET. It is a different register, not translated English — writing
English conventions in Portuguese words gets it wrong.

**Impersonal, third person, no direct address.** Never *você*. The authors are
*os autores* even in thanks: *"Desejo sucesso aos autores na continuidade da
pesquisa"* — the authors, not you.

**Recommendations are impersonal:** *"Recomenda-se ajustar o título ..."*,
*"Recomenda-se incluir explicitamente os limites estaduais"*. Not *eu
recomendo*, not *você deveria*.

**Polite imperative for requests:** *"Favor esclarecer."*

**Opening and closing courtesies are conventional here** in a way they are not
in English: *"Agradeço aos autores pela submissão"*, *"Desejo sucesso aos
autores na continuidade da pesquisa"*.

English reviews, by contrast, address authors directly: *"I really hope you will
produce a final document."*

Verdict in Portuguese: *Recomendado* / *Recomendado com ressalvas* / *Não
recomendado*. Note the corpus supports only *Recomendado* directly; the other
two are the natural completions of the scale and should be confirmed against the
venue's own form before use.

## ANPET's form (n = 1, treat as a one-off)

One ANPET review in the corpus is a filled evaluation form rather than free
text: a nine-item rubric (a-i, scored 1-4) with per-criterion justification,
then `Parecer conclusivo`, then `Comentário para Autor`, then `Comentário para
DC` — a confidential note to the scientific committee.

This rests on a single document. Follow whatever form the venue actually
supplies for the current review rather than assuming this one recurs.

## Sample-size honesty

Well supported, five or more independent documents each: the five invariants,
the modal split, the presence of location-led comments.

Thin, one or two documents each: the editor-confidential block, the ANPET rubric,
the verification-table format for revision rounds, numbering restarts per
subsection. Do not treat any of these as a rule.

Excluded from voice derivation: `j-geographical-systems/review2.md` and the
`municipal-engineer-ice/academic_review_*` pair use star ratings and emoji
headers unlike the other twenty reviews. They are scaffold output, not this
reviewer's voice.
