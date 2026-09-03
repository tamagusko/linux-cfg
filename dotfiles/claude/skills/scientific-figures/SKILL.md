---
name: scientific-figures
description: Use when a manuscript, thesis, deliverable or conference paper needs its visual elements reviewed or produced - "check my figures", "review the equations, figures, tables and algorithms", "do the figures tell the story", "make this figure look better", "I need a diagram for the method", "redesign Figure 3", "fix this table", "design a figure system for the paper", "generate an image for the paper". Covers plots, schematics, tables, equations and algorithm listings as one narrative, from audit to publication-ready files. Not for slides or posters (scientific-slides, latex-posters), not for exploratory plotting (matplotlib, seaborn), and not for reviewing someone else's paper (paper-review).
---

# Scientific figures

A figure in a paper has one job: let an expert reader understand a claim in under ten seconds, then trust it. Most paper figures fail one half. They are beautiful and vague, or accurate and unreadable. This skill forces accuracy first, then narrative, then aesthetics, and it stops for approval before anything expensive is rendered.

Adopt the lens of a scientific illustrator and data-visualisation editor for Q1 journals: reviewer rigour, designer's eye. Nothing is allowed to be beautiful until it is defensible.

## Two modes

Decide from the request before doing anything.

| Request sounds like | Mode | Deliverable |
|---|---|---|
| "review", "check", "assess", "do they work together", "is this publication-ready" | **Review** | One report in the shape of `references/templates.md` §1. Nothing in the manuscript folder changes. |
| "make", "redesign", "produce", "fix", "generate", "design a system" | **Production** | Three phases, two approval gates, files plus design log. |

A review request that ends "and fix them" is production; run the review as Phase 1 and stop at the first gate.

## Verification stance (both modes)

The findings that matter are contradictions between artefacts, and none of them are visible in the rendered image alone.

- **Read the plotting script before judging any data figure.** Find the column or file each line comes from and confirm it is the variant the caption names. Caption says "enforced model", script plots the raw prediction: that is the most expensive fault a figure can have.
- **Compile the manuscript on a copy and look at the pages.** Render every figure file, and the compiled pages that hold tables and listings, to check type size after any scaling, float placement, and that the document builds at all. In review mode, work on a copy: nothing in the manuscript folder changes, and helper scripts write to your scratch directory (`--out`).
- **Check schematic text as claims.** "Accuracy parity", "100 %", "six tables" inside a box are checked against the results tables and the text.
- **Check listings against the code**: initial values, first iteration, branch order.
- Run `scripts/float_audit.py main.tex` and `scripts/table_check.py` on every table source first. They find the mechanical faults (unreferenced floats, floats before their first reference, dangling labels, raster files, `\resizebox`, units in cells) so your attention goes to the scientific ones. `scripts/text_size_check.py` gives the text size at print width, which the eye cannot judge from a screen.
- The check is a separate pass from the build. Whoever produced a figure does not sign off on it; a fresh read that goes back to data and script does.

## What you need before starting

| Input | Why it matters | If missing |
|---|---|---|
| Manuscript source with captions, equations, tables, listings | The narrative decides which figures should exist | Review mode and Phase 1: stop and ask. A single-element production request with an explicit brief: treat the brief as the approved plan and flag what the missing manuscript leaves uncheckable (numbering, reference order, spelling variant, figure limit) |
| Data files and the scripts that produced the figures | Every plotted value must trace to a source | Flag `⚠️ MISSING` and never invent values |
| Existing figures | Decide keep / revise / redesign rather than starting blind | Proceed; treat all figures as new |
| Venue spec: journal, column widths, colour policy, figure limit | Drives font, palette and count | Assume a Q1 Elsevier engineering journal: Times-like serif body font, 90 mm single / 190 mm double column, colour online with greyscale legibility; flag the assumption |
| Rendering tools | Plots need a reproducible script; schematics need vector tools or an image model | matplotlib via `uv run --with matplotlib --with pandas python ...`; TikZ or matplotlib patches for schematics; an image-generation MCP only for illustrations vector tools cannot draw |

Missing inputs that change the structure of the work stop the task. Missing inputs that only change a value get an assumption and a `⚠️ MISSING: [item], assuming [value]` marker that survives into the deliverable.

## Production workflow: three phases, two gates

### Phase 1: narrative audit (stop for approval)

1. List every equation, figure, table and listing in reading order (start from the `float_audit.py` table).
2. For each, state its role in the argument, whether it fulfils it, and the action: keep, revise, redesign, merge, move or remove. A figure that repeats the text is removed or merged; one whose caption needs more than two sentences is split.
3. Find gaps: places where the reader must follow a method or believe a result and no visual helps. The headline quantitative result gets a figure; if it lives only in a table, that is the first gap.
4. Check equations: notation consistent, every variable defined, each one necessary, any rule typed inline more than twice gets a number. Figures inherit their symbols from the equations, so notation drift starts here.
5. Judge each "Algorithm" by the criterion in `references/design-rules.md` §7. A listing with input, output and a terminating procedure keeps the name; fix its content, not its label.
6. Output the figure plan (`references/templates.md` §2) and stop.

### Phase 2: design system (stop for approval)

7. Propose one visual system for the whole paper from `references/design-rules.md`, starting from `assets/paper.mplstyle`: palette (max six hues, colour-blind safe, greyscale-distinguishable), typeface matching the venue body font, sizes, line weights, markers, axis and grid rules, and a notation map linking every symbol in the equations to its label in figures, tables and listings.
8. Render the hardest figure in the system as proof, then stop. If the system survives that one it survives the rest.

Gates are for interactive sessions. When nobody can approve (subagent, batch run, one-figure brief), record the plan and the design system in the design log and continue; the log is what the user approves afterwards.

### Phase 3: production

9. **Data plots.** Each from the supplied data with a reproducible script saved beside the figure. Direct labels over legends. Never draw a value that is not in the data.
10. **Schematics.** Vector first (TikZ, matplotlib patches, SVG) in the paper's palette and typeface. If an image model is used, generate five variations, score them with the rubric in `references/design-rules.md` §8, keep the best, log all five. Generated images depict concepts only, never data; overlay labels as vector text.
11. **Tables.** Rows are the things compared, units in headers, decimals aligned, one type size for all tables, no `\resizebox`. Run `scripts/table_check.py` on every source.
12. Write one caption and one in-text reference sentence per element in the shapes of `references/templates.md` §4.
13. Deliver: figure files (vector preferred, 600 dpi if raster), scripts, design log, and the consistency checklist (`references/templates.md` §5) filled in after the greyscale check.

With more than ten elements, fix the plan and design system first, then process elements one at a time with the same instructions so quality does not drift.

## Review mode output

Use the report skeleton in `references/templates.md` §1. Must-fix items are contradictions between artefacts (caption vs script, listing vs text, schematic vs results), plotted values with no source in the data, and a document that does not build. Each names the two things that disagree and where they live. Presentation faults go under should-fix. A sound element gets one line. No padding: the number of items follows from the number of defects.

## Non-negotiable constraints

The full list with rationale is in `references/design-rules.md`. The ones that most often break:

- Every plotted value traces to a data row, and the variant drawn is the variant the caption names.
- One message per figure. No in-figure titles.
- No 3D, gradients on data marks, drop shadows, dual y-axes or pie charts.
- Minimum 7 pt text and 0.5 pt lines at final print size.
- Axis labels carry quantity and unit: "Speed (km/h)".
- Colour never carries meaning alone; pair it with shape, line style or direct labels.
- Identical symbols and names across equations, figures, tables, listings and text.
- Match the manuscript's spelling variant in captions and labels. No em-dashes in captions, labels or your own prose.
- Do not rewrite manuscript prose beyond the reference sentences.

## Bundled resources

- `references/design-rules.md`: full constraint list, the algorithm-naming criterion, the five-criterion selection rubric, and common failures with fixes. Read before Phase 2 and before writing a review.
- `references/templates.md`: review report skeleton, figure plan table, design log entry, caption shape, consistency checklist.
- `assets/paper.mplstyle`: matplotlib style implementing the defaults (serif, Okabe-Ito with paired line styles, 90 mm default width). Switch the marked lines for a sans-serif venue.
- `scripts/float_audit.py main.tex`: float inventory with reference-order, label, caption, raster and `\resizebox` flags.
- `scripts/table_check.py table.{csv,md,tex}`: units, precision, constant columns, units in cells, booktabs.
- `scripts/text_size_check.py fig.pdf --width-mm 90`: smallest and largest text at print width, Type 3 font check (needs `uv run --with pymupdf`).
- `scripts/greyscale_preview.py fig.{png,pdf} --out DIR`: greyscale render for the colour-only check (needs `uv run --with pillow`; writes to DIR, never beside the input).
