# Duplication Test

**Question answered:** has this idea already been done, and by whom?

Run before committing to a project, a proposal, or a paper. The output is a
ranked list of the closest existing work plus an explicit statement of what was
searched — never a verdict of "novel".

## The one rule

**Absence of results is not evidence of novelty.** An empty result set is far
more often a badly phrased query than an untouched field. A duplication test
that returns nothing has failed until you have shown the query works, by running
a deliberately broad version of it and getting hits.

Report the queries you ran. The user cannot judge the coverage of a search they
cannot see.

## Step 1 — Decompose the idea into facets

Take the abstract, aim, or one-line pitch, and split it:

| Facet | Example |
|---|---|
| Problem | pavement distress assessment |
| Method | convolutional segmentation |
| Data / domain | street-level imagery, urban arterials |
| Outcome | condition index correlated with manual survey |

Facets matter because prior work usually collides on **three of four**. A paper
doing the same method on different data is not duplication; it is the closest
neighbour, and the user needs to see it either way.

## Step 2 — Quote your phrases, then go tight to loose

**A bare string of terms is not an AND.** `title_and_abstract.search` with
several unquoted words is fuzzy: the count drops, which looks like precision,
but the results are junk. Measured 2026-08-23 on a real idea, the unquoted
five-term query returned 152 works whose top hits included an editorial on
materials science, a gastroenterology paper, and three book indexes.

Quote every multi-word concept. Quoted phrases match as phrases, and multiple
quoted phrases do compose as AND:

```bash
# unquoted, 5 terms -> 152, and the top results are noise
...filter=title_and_abstract.search:vision%20language%20model%20cycling%20safety

# one quoted phrase -> 26,038 real phrase matches
...filter=title_and_abstract.search:%22vision%20language%20model%22

# two quoted phrases -> 1. This is the duplication-test query.
...filter=title_and_abstract.search:%22vision%20language%20model%22%20%22cycling%20infrastructure%22
```

Use plain `search=` only to prove a topic exists at all, never to conclude
anything. And when a rung returns a handful of results, **read the titles**
before reporting the count — a small number is exactly when fuzzy matching does
the most damage, and the count alone will not show it.

Then run a **ladder**, and keep every rung:

1. All four facets ANDed — near-exact prior work
2. Drop the outcome — same method, same data
3. Drop the data — same method, different domain
4. Method alone, filtered to recent years — who else is active

Rung 1 returning zero while rung 3 returns hundreds is the normal and
informative result. Rung 1 *and* rung 4 returning zero means the query is wrong.

Useful additions:

```bash
# top prior work by influence, trimmed response
&sort=cited_by_count:desc&per_page=10&select=id,display_name,publication_year,cited_by_count,doi

# only recent, to catch work that would scoop rather than precede
&filter=title_and_abstract.search:...,from_publication_date:2024-01-01
```

## Step 3 — Cover what OpenAlex misses

OpenAlex alone is not a duplication test. Query in parallel:

| Source | Why it is needed here |
|---|---|
| **arXiv** | Preprints scoop; they appear months before indexing |
| **Semantic Scholar** | Recommendations surface neighbours that share no keywords |
| **Crossref** | Very recent DOIs, before OpenAlex enrichment |

Semantic Scholar's recommendations endpoint is the highest-value call in this
whole workflow: give it the single closest paper found so far, and it returns
work that a keyword search structurally cannot reach.

### Known blind spots — state them in the output

- **Grey literature is largely absent.** Technical reports, standards, and
  agency publications are poorly indexed. In transportation specifically, TRB /
  **TRID**, state DOT reports, and TRB Annual Meeting papers are a real hole —
  a duplication test in that field is incomplete without a manual TRID check.
- **Theses and dissertations** are patchy.
- **Non-English work** is under-represented relative to its actual volume.

## Step 4 — Report

Rank the closest work and assign each a relationship, not a score:

| Relationship | Meaning |
|---|---|
| **Duplicate** | Same problem, method, and data. The idea is done. |
| **Near-neighbour** | Three facets match. Differentiation must be argued explicitly. |
| **Adjacent** | Same method elsewhere, or same problem by other means. Cite it. |
| **Context** | Shares vocabulary only. |

Order by the policy in `source-quality.md`: relationship first, then source
within each relationship group. Never let venue ranking move a duplicate below a
merely-adjacent paper — the relationship is the finding, the venue is a detail.

Close with the queries run and the rungs that returned nothing, then:

> No duplicate found across N queries spanning OpenAlex, arXiv, and Semantic
> Scholar. This is not a novelty finding — grey literature and TRID were not
> searched.
