# Templates

Use these shapes exactly. Consistency across many figures is the point of having a template; a slightly different table per figure defeats it.

## 1. Review report (audit-only requests)

When the user asks for a review, audit or assessment of the visual elements and not for production, the deliverable is one Markdown file with this skeleton. Nothing in the manuscript folder is changed.

```
# Review of equations, figures, tables and algorithms as storytelling elements

Manuscript: [title], [main file] compiled [date] ([pages] pages).
Scope: [n] numbered equations, [n] algorithm listings, [n] figures ([body]/[appendix]), [n] tables ([body]/[appendix]).
Provenance: [model], [what was inspected: every figure file rendered; every table source read; which claims were verified against code rather than against the manuscript]. Output of scripts/float_audit.py and scripts/table_check.py attached or summarised.
This is an assessment. Nothing in [folders] was changed.

## 1. Verdict
[Two sentences: do the elements tell the right story in the right order, and where is the visual layer weaker than the argument.]

**Must fix before submission (scientific consistency)**
1. [Element]: [what contradicts what, with the evidence: file, line, script function, table cell]
...

**Should fix (presentation)**
[numbered, continuing the sequence]

**Gap:** [the missing element, one sentence, or "none"]

## 2. Equations        (per element: Role / Fulfils it? / Fix)
## 3. Algorithm listings
## 4. Figures
## 5. Tables
## 6. Storytelling and gaps
## 7. Ordered action list
```

Rules for the report:

- Must-fix means a contradiction between two artefacts (caption vs script, listing vs text, schematic vs results table, table cell vs protocol), a plotted value with no source in the data, or a manuscript that does not compile. Presentation faults never go in must-fix, however ugly.
- Every must-fix item names the two things that disagree and where each lives. "Figure 3 is misleading" is not a finding; "Figure 3 plots `pred_intrinsic` (plot_figures.py:88) while the caption says enforced" is.
- One continuous numbering across the two severity headings.
- Recommendations are concrete enough to execute: which panel, which axis, which column, which sentence.
- Do not pad. A sound element gets "Role / Fulfils it? Yes / Fix: nothing" and one line.

## 2. Figure plan (Phase 1 output)

One row per final element, in reading order. Include elements to be removed so the user sees the whole decision.

```
No. | Type | Narrative role | Section | Status | Action | Rationale
```

Example rows:

```
Fig. 1 | Schematic | Shows the four-stage detection pipeline the reader needs before section 3 | 3.1 | New | Create | Text describes the pipeline in 300 words; a schematic replaces most of it
Fig. 3 | Line plot | Shows detector recall falls with occlusion, the core result | 4.2 | Revise | Redesign | Eight unlabelled colours and a truncated y-axis; single panel, three series, direct labels
Fig. 4 | Scatter | Accuracy against consistency, one point per model variant: the paper's signature result | 5.1 | New | Create | The trade-off the contribution rests on lives only in Tab. 2
Tab. 2 | Table | Exact per-class precision and recall for reproducibility | 4.2 | Keep | Revise | Add units to headers, align decimals, remove the "notes" column repeated in text, drop \resizebox
Fig. 5 | Bar chart | Compares runtime across models | 4.4 | Existing | Remove | Values already in Tab. 3 and the difference is one sentence
Alg. 1 | Algorithm | Specifies the phase-segmentation procedure | 3.3 | Existing | Revise | Keep the name; initialise k to 0 to match text and Fig. 2; add output for observation 1; add caption line mapping k, a, τ to feature names
```

After the table, list the `⚠️ MISSING` items and stop for approval.

## 3. Design log entry (one per element, Phase 3)

```
### Fig. [n]: [short title]
Role: [one sentence]
Source: [data file and column(s), or "conceptual"]; verified against [script:function]
Rule 0: [grey | colour, exception n: one clause]
Series / fills: [n], within limit | over limit, handled by [direct labels | panels | value steps]
Variations: [filenames of the five candidates, or "n/a" for data plots]
Scores (Accuracy / Clarity / Simplicity / Consistency / Elegance), or "n/a" for data plots:
  v1: 4/3/2/5/3 = 17
  v2: 5/4/5/5/4 = 23
  v3: ...
Chosen: v2, because [one sentence]
Rejected: v1 [one clause]; v3 [one clause]; ...
File: [path], [width mm], [vector | 600 dpi]
Script: [path or "n/a"]
Gate: [pass | fail: what merges]; smallest L* gap [n] (palette_check.py); preview at [width] mm
```

## 4. Caption shape

Three parts, three sentences at most: what is shown and under what condition; what the reader should notice; how the numbers were obtained.

```
[Figure noun] of [what is shown] for [condition]. [One sentence on what to notice]. [Data source, method or uncertainty note].
```

Example:

```
Roughness (IRI) of one pavement section from 1990 to 2018 with the phase index assigned by the segmentation step. The clock resets at the two documented rehabilitations and not at the 2003 seal coat, which the model treats as within-phase. Points are LTPP survey values; vertical lines mark the first post-event survey.
```

What does not go in a caption: the figure's title repeated, a description of the encoding the legend already gives, advice to the reader, or a fourth sentence. Definitions of symbols go in the caption only when they are local to the figure.

In-text reference sentence: name the figure and the conclusion, not only the existence. The first reference precedes the float in the source.

```
Weak:   Figure 3 shows the recall results.
Strong: Recall falls below 0.8 once occlusion exceeds 40 % (Figure 3), which sets the operating limit adopted in Section 5.
```

## 5. Consistency checklist (fill in at delivery)

Tick each item for the whole set, not per figure.

- [ ] `scripts/float_audit.py main.tex` runs clean, or every remaining flag is explained
- [ ] Every figure and table is referenced in the text before it appears and interpreted after
- [ ] Reading order matches argument order (problem, method, analysis, results, conclusion)
- [ ] Each data figure was checked against the plotting script: the variant drawn is the variant the caption names
- [ ] Every claim written inside a schematic agrees with the results tables and text
- [ ] Rule 0 recorded for every figure; every colour figure names its exception
- [ ] No axes holds more than four line styles or four hatches; five or more series are direct-labelled, split or moved; five or more fills use value steps with names at the bars
- [ ] One palette logic, one typeface (matching the venue body font), one marker set across all figures; no in-figure titles; `scripts/set_check.py figures/*.pdf --widths 90,190` clean
- [ ] Every symbol and name in figures, tables and listings appears in the notation map with the same form as in the equations and text
- [ ] All text at or above 7 pt at final width (`scripts/text_size_check.py --width-mm`); all lines at or above 0.5 pt; nothing clipped at the file edge
- [ ] Axis labels carry quantity and unit
- [ ] Uncertainty shown and defined wherever the data carry it
- [ ] Every plotted value traceable to a data file; no open `⚠️ MISSING` markers
- [ ] No pie charts, dual axes, 3D, gradients or shadows
- [ ] Gate passed for every figure: `scripts/palette_check.py` smallest gap at or above 20 L*, `scripts/greyscale_preview.py --width-mm` at print width inspected, result in the design log
- [ ] Figure count within venue limit
- [ ] Captions follow the three-part shape; none exceed three sentences; no em-dashes
- [ ] Tables: `scripts/table_check.py` clean, one type size across all tables, no `\resizebox`
- [ ] Algorithm listings agree with the text and the code on initial values, first iteration and branch order
- [ ] Vector files delivered where possible; raster at 600 dpi otherwise
- [ ] Scripts delivered for every data plot
- [ ] Design log complete, including rejected variations
