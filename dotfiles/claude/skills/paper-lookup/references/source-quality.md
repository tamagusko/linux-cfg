# Source Quality and Ranking

How to order results so the strongest sources surface first. Applies to every
workflow in this skill, and especially to `duplication-test.md`, where a weak
source can hide a strong one.

## Priority order

Sort by **relevance first**, then by source, in this order:

1. **Already cited in the project's own bibliography** — the strongest signal
2. **Already in the user's Zotero library** — collected, if not yet cited
3. **Prominent indexed journals** — CWTS-core, high field-relative citedness
4. **Preprints from top-100 universities** — where fast-moving fields live
5. **Everything else** — shown, lower down
6. **MDPI** — demoted within its band, never removed

**Nothing is ever dropped for its source.** Every rule here reorders; none
filters. A duplicate published in an obscure venue is still a duplicate, and a
search that hides it has failed at the only job that mattered.

## 1. What the user already has, first

Two places to check, and they hold different things.

**The project's own bibliography.** If the working directory is a paper, its
`.bib` or `.bbl` is the authoritative list of what the user has already engaged
with. Grep it for each candidate's author surname, title fragment, and DOI. A
hit means "already cited" — the strongest possible signal, and it converts a
scary duplication result into a solved one.

**Zotero**, via the configured MCP server (`zotero_search_items`,
`zotero_item_metadata`, `zotero_item_fulltext`). This is the broader library:
what has been collected, not necessarily what a given paper cites.

Check the local bibliography **first**. Measured on a real draft, 2026-08-23: of
four candidates surfaced by a duplication test, the two that mattered were both
cited in `main.bbl` and neither was in Zotero — while Zotero returned 115 items
for "cycling" and 34 for the user's own name, so it was working correctly. The
two stores were simply out of sync, which is normal when a paper's references are
managed in BibTeX.

Searching Zotero alone would have reported the closest known neighbour as an
unknown threat.

### Query quirks

`zotero_search_items` treats a hyphen as OR, so `V-RoAst` matches anything
containing "V" — write `V RoAst`. Use `qmode='everything'` to reach abstracts and
attachment full text; the default covers only title, creator, and year.

### Why it is worth the calls

A paper already held needs no retrieval. More usefully, a duplication test that
surfaces something the user *already collected and forgot* is a different and
more urgent finding than one that surfaces a stranger's work.

## 2. Journal prominence

**OpenAlex does not carry Q1 quartiles.** Quartiles come from Scopus CiteScore or
JCR, neither of which is in this API. Use these proxies and call them proxies:

| Signal | Field | What it means |
|---|---|---|
| `is_core` | `/sources` | In the CWTS Leiden Ranking core set — curated, excludes predatory and marginal venues |
| `summary_stats.2yr_mean_citedness` | `/sources` | Impact-factor-shaped. Compare only *within* a field |
| `summary_stats.h_index` | `/sources` | Venue longevity and influence |

`is_core` is the single best filter. Measured on `"cycling infrastructure"`,
2026-08-23:

```
baseline                       2265
+ core journals only           1034
```

Filter works directly:

```
&filter=title_and_abstract.search:"...",primary_location.source.is_core:true
```

Check a specific venue before trusting it:

```bash
curl -s "https://api.openalex.org/sources?search=Transportation+Research+Part+C&mailto=$EMAIL"
# is_core=True  2yr_mean_citedness=7.51  h_index=234
```

**Never compare citedness across fields.** A 7.51 in transportation is not
weaker than a 15 in molecular biology; the fields cite at different rates.

## 3. Demoting MDPI

The user's preference is that MDPI ranks **below** comparable work — not that it
disappears. Nothing is ever filtered out on the basis of publisher.

Do not use a query filter for this. Demotion is a sort applied after retrieval,
so the query stays complete and the count stays honest. Ask for the publisher in
the response and tag each result:

```
&select=display_name,publication_year,doi,cited_by_count,primary_location
```

`primary_location.source.host_organization_name` carries the publisher;
MDPI's OpenAlex id is `P4310310987`.

### The sort

Rank on venue band first, and let MDPI lose ties within a band:

| Rank | Band |
|---|---|
| 1 | CWTS-core, not MDPI |
| 2 | CWTS-core, MDPI |
| 3 | Not core, not MDPI |
| 4 | Not core, MDPI |

So an MDPI paper in a core journal still outranks a non-core paper from any
publisher. That is the intended behaviour: the preference is a tiebreak against
comparable work, not a claim that MDPI is worse than everything else.

### Relevance outranks venue, always

**Demotion applies only among results of similar relevance.** A paper that
duplicates the user's idea goes at the top whatever its publisher, flagged for
what it is. Sorting a duplicate beneath a loosely-related paper from a better
journal would defeat the purpose of the search.

In practice: establish the relationship first — duplicate, near-neighbour,
adjacent, context — then apply venue ranking *within* each relationship group.

This is not hypothetical. Tested on the user's own Colourways draft, the closest
cycling-domain neighbour was in MDPI *Applied Sciences*, and `is_core` true. It
belongs near the top because of what it is about, and a publisher filter would
have hidden it entirely.

### Say what the ordering was

MDPI results are present, so the user must be able to see why they sit where
they do:

> Ranked by relevance, then venue. Two results are MDPI (marked ·M) and sit
> below comparable non-MDPI work in the same band. Nothing was removed.

## 4. Preprints, ranked by institution

For fast-moving fields — anything VLM, LLM, or deep-learning shaped — the
relevant work is on arXiv months before it is indexed anywhere. Reach it through
OpenAlex rather than the arXiv API, because only OpenAlex carries affiliations.

```
&filter=title_and_abstract.search:"...",type:preprint
```

Then restrict to strong institutions. Build the top-100 list in one request —
`type:education` matters, because ranking institutions by h-index alone puts
research institutes such as IHME and the Broad above every university:

```bash
curl -s "https://api.openalex.org/institutions?filter=type:education&sort=summary_stats.h_index:desc&per_page=100&select=id,display_name&mailto=$EMAIL"
```

Filter works by those ids, OR-ed with `|`. Use `lineage`, not `id`, so that
affiliated labs and hospitals of a university still match:

```
&filter=...,type:preprint,authorships.institutions.lineage:https://openalex.org/I63966007|https://openalex.org/I97018004
```

Measured on `"vision language model"`, 2026-08-23: 26,038 works, 14,546
preprints, 55 preprints from Stanford, 78 from MIT or Stanford.

**A caution on this one.** Institutional prestige is a proxy for attention, not
for correctness, and it correlates strongly with being American and
English-speaking. Use it to decide reading *order* when a search returns more
preprints than anyone can read. Do not use it to decide what exists — in the
user's own field, relevant work comes from European transport groups and
national road authorities that this ranking will bury.

## Reporting

State the policy that produced the ordering:

> Ranked by relevance, then source: 2 already in your Zotero library, 14 from
> CWTS-core journals, 6 preprints from top-100 universities, 3 from MDPI titles
> (·M, demoted within their band). 25 results, none removed.
