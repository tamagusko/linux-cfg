# Gap Saturation

**Question answered:** is this gap still open, or has the field already filled it?

Run when a research question has survived the duplication test, to judge whether
it is worth pursuing now. Complements `duplication-test.md`: that one asks *has
this been done*, this one asks *is it about to be*.

## The trap that invalidates the naive version

The obvious method — count publications per year, call a rising line "hot" — is
wrong on OpenAlex, because the index itself grows faster than the literature.
Global works per publication year, measured 2026-08-23:

```
2021: 10,735,638
2022: 10,243,791   -4.6%
2023: 10,843,956   +5.9%
2024: 10,742,321   -0.9%
2025: 14,817,755  +37.9%
2026: 29,556,946  +99.5%   <- and 2026 was only eight months old
```

Those jumps are ingestion, not scholarship. A topic growing +40% in 2025 did not
grow at all in relative terms; it merely kept pace with the index. And 2026's
count exceeding a complete 2025 shows the current year cannot be read at face
value in either direction.

**Therefore: always normalise, and never trend on the current year.**

## Step 1 — Get both curves

One call for the topic, one for the corpus:

```bash
# topic
curl -s "https://api.openalex.org/works?filter=title_and_abstract.search:TOPIC&group_by=publication_year&mailto=$EMAIL"

# baseline — same call with no filter
curl -s "https://api.openalex.org/works?group_by=publication_year&mailto=$EMAIL"
```

`group_by` returns every year in a single request, so this is two calls total,
not one per year.

## Step 2 — Work in share of corpus

For each complete year, compute `topic_count / global_count`. Report that share
in parts per million, and trend **the share**, not the count. Drop the current
year entirely, and treat the previous one as provisional.

A topic whose share is flat is being published at the same rate the field always
was. A topic whose share is falling while its raw count rises is *losing*
attention — the single most common misreading this normalisation prevents.

## Step 3 — Read the qualitative signals

Counts alone do not establish saturation. Three cheap checks that carry more
information than the curve:

**Reviews and surveys.** A cluster of them means the field considers itself
mature enough to summarise.

```bash
&filter=title_and_abstract.search:TOPIC,type:review
```

Compare the review count against total. A high ratio is a saturation signal; a
near-zero count in a large literature suggests the field is still moving.

**What the recent top-cited papers actually do.** Fetch the last two complete
years sorted by citations and read the titles. If they already do the thing you
propose, the gap closed while you were reading about it. This beats any count.

**Whether the "gap" is stated by others.** Papers that name an open problem in
their own abstract are evidence the gap is real and recognised — and also that
you have competition.

## Step 4 — Report a judgement, with its basis

| Verdict | Pattern |
|---|---|
| **Open** | Flat or rising share, few reviews, recent work does not address it |
| **Closing** | Rising share and recent top-cited work approaching the question |
| **Saturated** | High review ratio, recent work already answering it |
| **Dormant** | Falling share, little recent work — ask *why* before celebrating |

**Dormant is not the same as open.** A field people left may have been
abandoned for a good reason: the data stopped being collected, the method was
superseded, the result turned out not to matter. Say so rather than presenting
an empty field as an opportunity.

## Field limitation

The same blind spot as the duplication test: this measures the *indexed*
literature. In transportation, a topic active in TRB proceedings and state DOT
reports can look dormant here while being well covered in practice. Say which
corpus the verdict describes.
