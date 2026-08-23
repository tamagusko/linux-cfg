# Source Quality and Ranking

How to order results so the strongest sources surface first. Applies to every
workflow in this skill, and especially to `duplication-test.md`, where a weak
source can hide a strong one.

## Priority order

1. **Already in the user's Zotero library** — they have read it, or meant to
2. **Prominent indexed journals** — CWTS-core, high field-relative citedness
3. **Preprints from top-100 universities** — where fast-moving fields live
4. **Everything else** — shown, but below the fold

Never *drop* a result for being low-priority. Reorder, and say what the ordering
is. A duplicate published in an obscure venue is still a duplicate.

## 1. Zotero first

The `zotero` MCP server is configured (`zotero_search_items`,
`zotero_item_metadata`, `zotero_item_fulltext`). After assembling results, search
Zotero for each strong candidate by title or DOI and mark the hits.

This matters for two reasons: a paper already in the library needs no retrieval,
and — more useful — a duplication test that surfaces something the user *already
collected* is telling them they knew about the collision and forgot.

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

## 3. Excluding MDPI

The user's default is to avoid MDPI. Its OpenAlex publisher id is
`P4310310987` (1.99M works). Negate with `!`:

```
&filter=...,primary_location.source.host_organization:!https://openalex.org/P4310310987
```

Verified on `"cycling infrastructure"`, 2026-08-23 — the arithmetic is exact:

```
baseline           2265
exclude MDPI       2167
MDPI only            98      (2265 - 98 = 2167)
```

**This is a default, not a rule, and it should be stated in the output.** MDPI is
uneven rather than uniformly poor — some of its titles are well regarded and
`is_core` true. Two cases override the default:

- A **duplication test**. Suppressing a venue cannot make prior work stop
  existing. Run duplication tests with MDPI included, and label the hits.
- The user asks about a specific MDPI paper or journal.

When the filter is applied, say so and give the count that was suppressed, so the
user knows what they are not seeing.

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

> Ranked: 2 already in your Zotero library, then 14 from CWTS-core journals,
> then 6 preprints from top-100 universities. MDPI excluded (98 results
> suppressed); re-run with `--include-mdpi` to see them.
