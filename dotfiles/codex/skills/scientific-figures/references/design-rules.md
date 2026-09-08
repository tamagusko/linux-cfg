# Design rules and selection rubric

## Contents

1. Accuracy rules
2. Narrative rules
3. Typography and geometry
4. Colour and greyscale: the decision (Rules 0 and 3)
5. Plot-type rules, including the density limits (Rules 1, 2 and 4)
6. Tables
7. Equations and algorithm listings
8. Selection rubric for image variations
9. Common failures and their fixes
10. The set (Rule 6)

## 1. Accuracy rules

- Every plotted value traces to a row in the supplied data. If a quantity cannot be sourced, mark it `⚠️ MISSING: [quantity], assuming [value]` in the design log and leave it out of the figure until cleared.
- **Verify what is plotted against the plotting script, not against the caption.** Open the script, find the column or file each line is drawn from, and check that it is the variant the caption names (enforced vs intrinsic, test vs validation, mean vs median). A caption that describes a different model than the one drawn is the most expensive figure fault there is, and it is invisible in the rendered image.
- Claims written inside schematics (boxes that say "accuracy parity", "100 %", "six tables") are claims. Check each against the results tables and the text; a framework figure is not exempt from the numbers.
- Show uncertainty whenever the data carry it: error bars, shaded bands, or confidence intervals, with the definition stated in the caption (standard deviation, standard error, 95 % CI, number of runs).
- Axes start at zero for bar charts and any chart where length encodes magnitude. Line charts may use a truncated axis only when the caption says so and the axis break is visible.
- Never smooth, interpolate or extrapolate beyond the data range without saying so in the caption.
- A figure or table that reports a significance claim uses the p-value the paper's own protocol prescribes. If the text says secondary tests are judged at a Benjamini-Hochberg threshold, a table cell marked "significant" on the raw p is wrong.
- Generated images depict concepts, architectures and workflows only. They never stand in for measurements, results, maps of real places or photographs of real objects presented as evidence.

## 2. Narrative rules

- One message per figure. If the caption needs more than two sentences to explain what to look at, split the figure or drop panels.
- A figure earns its place by adding information the text cannot carry: a shape, a comparison, a spatial relation. A figure that restates a sentence is removed or merged.
- Figures follow the argument order: problem, method, analysis, results, conclusion. Move any figure that appears before the text can explain it.
- Every figure is referenced in the text before it appears, and interpreted after it appears. "Figure 3 shows the results" is a reference, not an interpretation; the interpretation names what the reader should conclude.
- The paper's headline quantitative result gets a figure, not only a table. If the trade-off the contribution rests on lives in one table and nowhere else, that table is the gap: propose the signature figure (for example, the accuracy-consistency plane with one point per model variant).
- Method figures show what the method does to one real example, including the intermediate quantity the model actually receives. A segmentation figure that shows the input series but not the derived feature explains nothing.
- Multi-panel figures share axes, scales and palettes across panels so the reader compares rather than re-reads.
- Same identifier convention for the same entity across all figures (section IDs, model names, feature names). Build the notation map once and apply it to every label.

## 3. Typography and geometry

- Minimum text size 7 pt at final print size; target 8 to 9 pt for labels, matching or one step below the body font. The floor applies to full-size text. Sub- and superscripts in math labels ($R^2$, $t+1$, $10^6$) are set at 70 % and 50 % of the label size by both LaTeX and mathtext, so they fall below 7 pt at any label size the venue allows; `scripts/text_size_check.py` lists them and the reviewer confirms by eye that they are scripts, not labels. Do not enlarge a label to push its subscript over the floor, and do not rewrite notation to dodge the check.
- Data lines 1.0 pt at final print size (Rule 1). Reference and auxiliary lines (zero lines, thresholds, error bars) 0.5 pt, which is the floor for anything that carries information. Gridlines 0.25 pt, light grey, or none.
- Typeface matches the venue body font. Elsevier (elsarticle) and IEEE Transactions set body text in a Times-like serif, so figure text is serif there; sans-serif only for venues whose body font is sans. One typeface per paper, at most two weights. Mixed serif and sans across figures is a defect.
- Single column 90 mm, 1.5 column 140 mm, double column 190 mm unless the venue says otherwise. Design at final size; scaling a large figure down shrinks the text below the minimum.
- No in-figure titles. The caption is the title; a title inside the axes duplicates it and usually carries an em-dash.
- Aspect ratio between 4:3 and 16:9 for single panels. Taller than 4:3 only for stacked panels sharing an x-axis.
- Whitespace is a design element. Leave margin inside the axes so data marks do not touch the frame; check that nothing is clipped at the edge of the exported file.
- Axis labels carry quantity and unit in the form "Travel time (min)". Dimensionless quantities carry no unit ("Recall", "R²"), never a fabricated one. Units in SI; use the venue's convention for exceptions such as km/h.
- Tick labels with consistent decimal places along an axis. No scientific notation in tick labels if a unit prefix removes the need.
- Figure file names carry the printed number (`fig3_...` prints as Figure 3); renumber files when floats move.
- Vector output (PDF or SVG) preferred. Raster output at 600 dpi for line art, 300 dpi minimum for photographs, image overlays and generated images. One raster among vector figures is visible on the page; rebuild it.
- Fonts embedded (matplotlib `pdf.fonttype 42`); `scripts/text_size_check.py` reports Type 3 fonts and the text size at print width.

## 4. Colour and greyscale: the decision (Rules 0 and 3)

Publication figures for Elsevier transport and construction journals, IEEE venues and EU deliverables are printed, photocopied and read as monochrome PDFs. A figure that survives that treatment is strictly more useful than one that does not, so greyscale is the default and colour is a decision that has to be justified. Slides and posters are a different regime and are not covered here.

### Rule 0: run first, once per figure

Greyscale unless one of these five conditions holds. Record the outcome in the design log as `Rule 0: grey` or `Rule 0: colour, exception n`.

| n | Exception | Why greyscale patterns cannot carry it | Palette when used |
|---|---|---|---|
| 1 | A second variable is encoded on the same mark: SHAP dependence coloured by an interacting feature, scatter coloured by a third quantity | The mark already spends shape and position; only value or hue is left, and value alone gives too few steps | cividis or viridis (monotone lightness) |
| 2 | Diverging scale with a meaningful zero: correlation matrix, signed residual map | Sign and magnitude on one axis | RdBu_r or PuOr, cells annotated with values, because both ends of a diverging map go dark in greyscale |
| 3 | Overlay on a photograph or image: segmentation mask, detection box, attention map | The photograph occupies every grey | Okabe-Ito hues at high opacity, one hue per class, class named in the caption |
| 4 | Map with categorical regions or a continuous surface | Regions share borders; hatching over a basemap is illegible | ColorBrewer colour-blind-safe qualitative or sequential set; basemap muted |
| 5 | The venue instructs colour (graphical abstracts, some magazine-style journals) | Not a figure-design reason; a compliance one | Okabe-Ito, same four line styles and markers as the grey figures |

Not exceptions: an ordered category (phase 0, 1, 2; horizons t+1 to t+3), model variants, treatment types, classes in a bar chart, series in a line plot. Line style, marker, lightness and hatching carry all of these. A one-signed matrix (confusion matrix, count table) is drawn in `Greys` with annotated cells and needs no colour.

When colour is used the palette is colour-blind safe and high contrast: Okabe-Ito for categories (first four: `#0072B2 #D55E00 #009E73 #E69F00`), viridis or cividis for sequential data, ColorBrewer CB-safe sets as alternatives. Red-green is never the only contrast. Same colour means the same thing in every figure of the paper. And the figure still passes Rule 3: colour adds a cue, it does not replace lightness, line style, marker or a direct label.

### Rule 3: the greyscale-survival gate

Every figure, colour or not, passes this before delivery. It is a gate, not advice: a failure is a must-fix and goes in the report's first list.

1. `scripts/palette_check.py --script make_figures.py` (or the hex list): every series colour's lightness L*, and the smallest pairwise gap. Two series in one axes closer than 20 L* units merge on a copy. Duplicated colours distinguished by line style are not a clash; two different hues at the same lightness are.
2. `scripts/greyscale_preview.py fig.pdf --width-mm 90 --out DIR`: the figure as the reader's printer produces it, greyscale at print width and 300 dpi. Open it and answer three questions: is every series and class identifiable, is every label legible, is any information carried by hue alone.
3. Record `Gate: pass` or `Gate: fail, [what merges]` in the design log. A fail is fixed in the script and re-rendered; it is never waved through because "colour and pattern are redundant". Redundancy that was not rendered is a claim, not a check.

The baseline failure this gate exists for: an author pairs Okabe-Ito vermilion with Okabe-Ito green, states that the line styles make it safe, and ships a figure whose two series sit 3.6 L* apart. Measured, not imagined.

## 5. Plot-type rules, including the density limits (Rules 1, 2 and 4)

### Rule 1: curves

- Series are told apart by line style: solid, dashed, dotted, dash-dot. That is four, and four is the limit for one axes. The default cycle in `assets/paper.mplstyle` has exactly four entries (black solid, black dashed, grey solid, grey dotted, with four markers) so a fifth series recycles the first; `figstyle.too_many_series(ax)` warns when that happens.
- Five or more series: direct labels at the line ends and no legend (`figstyle.label_lines(ax)`), or split into panels that share axes, or move the series that do not carry the argument to supplementary. A legend the reader must ping-pong across six dash patterns is a design failure, not a style choice. Inventing a fifth pattern (long-dash, dash-dot-dot) is not an option.
- Data lines 1.0 pt at final size; markers 3.5 pt, sparse (`markevery`) on dense series; auxiliary lines 0.5 pt.

### Rule 2: fills (bars, areas)

- Up to four categories: white fill, black edge, hatch from `figstyle.HATCHES` (none, `///`, `\\\`, `xxx`). Hatch line width 0.5 pt.
- Five or more: hatching is banned. It renders as noise at 300 dpi and below and thin bars turn into moiré. Use greyscale value steps, evenly spaced in lightness from L* 25 to 85 (`figstyle.value_steps(n)` or `figstyle.bar_fills(n)`, which switches automatically), and print the category name at each bar: inside the light bars, beside the dark ones. A six-entry legend does not satisfy Rule 4 for value steps because six greys cannot be matched back to a legend swatch reliably.
- Grouped bars with a second factor on x: the fill encodes the category with the fewer levels. If both factors exceed four levels, the figure is two panels or a table.
- Bars start at zero, ordered by a meaningful rule (magnitude, category order from the text), never alphabetically by default.

### Rule 4: legends and labels

- Every line style, marker or hatch that appears is named. Direct labels first: at the end of the line, beside or inside the bar, next to the point. A legend is the fallback, and only where it covers no data.
- No legend on a single-series figure; the axis label and caption already say what it is.
- Legend entries show enough of the line to read the pattern (`legend.handlelength` 2.4 in the style).
- A legend is never the reason to keep six styles in one axes; see Rule 1.

### Other plot-type rules

- No 3D effects, no gradients on data marks, no drop shadows, no decorative backgrounds. This includes schematics: flat boxes, one accent colour per concept, drawn in the same palette as the data plots.
- No pie charts. Use a bar chart or a single sentence.
- No dual y-axes. Use two panels sharing x.
- Gridlines light and thin, or none. The data are the darkest thing on the page.
- Remove the top and right spines unless the venue style keeps them.
- Bar charts: bars start at zero, ordered by a meaningful rule (magnitude, category order from the text), not alphabetically by default.
- Scatter plots with many points: reduce marker size and add transparency, or switch to hexbin or 2D density.
- Time series: x-axis in real time units, not sample index, unless the index is the quantity of interest.
- Event markers on a time series follow one stated convention (for example, marker on the first post-event observation) and the caption states it.
- Maps: north arrow, scale bar, and a basemap muted enough that the data layer dominates.
- Confusion matrices and heatmaps: annotate cells with values when there are fewer than about 50 cells; otherwise rely on the colour bar and describe the pattern in the caption. One-signed matrices use `Greys`; a colour map needs a Rule 0 exception (1 or 2).
- A constraint or guarantee the paper claims (monotone, non-negative, bounded) is shown in a figure that makes a violation visible: a difference panel, a residual panel, or marked violations, not an overlay where a violation hides under another line.

## 6. Tables

- A table exists to let the reader compare. Rows are the things compared; columns are the criteria. If the reader compares down columns, transpose.
- Units in the column header, never repeated in cells.
- Numbers right-aligned or decimal-aligned; text left-aligned. Consistent precision within a column.
- Bold or underline the best value per column only when the paper's argument depends on it, and say what bold means in the caption.
- Remove any column whose content is fully stated in the prose, and any column whose cells are all identical (move the value to the caption).
- Horizontal rules at top, below header, and bottom (booktabs). No vertical rules.
- Footnotes for abbreviations and any statistical test used.
- **Never `\resizebox` a table to the text width.** It sets a different type size per table: wide tables end up at 5 pt and narrow ones are blown up above body size. Fix the content instead: drop a column, move intervals to a separate row or supplementary table, abbreviate headers, use `\small` uniformly, or rotate the table. All tables in a paper share one type size.
- Category codes in a table (experiment IDs, class labels, section IDs) are the ones the text defines; a table that lists codes the text never names is a defect of the table, not the text.
- Run `scripts/table_check.py` on every table source (CSV, markdown or LaTeX tabular).

## 7. Equations and algorithm listings

- Every symbol defined at first use, in a sentence, not only in a nomenclature table. Check summation limits and normalising constants (an N that appears in the equation must be defined).
- Notation identical across equations, figures, tables and text. The Phase 2 notation map is the single source of truth. Algorithm listings map their local symbols (k, a, τ) to the feature names the tables use, in the caption.
- Number only equations referenced in the text. Conversely, a rule the paper types inline more than twice (an enforcement step, a threshold test) gets a number, and later mentions cite the number instead of repeating the formula.
- Labels match the current name of the quantity (`eq:pcr`, not a leftover `eq:pcs`).
- **"Algorithm" is the right float name for a listing with declared input, declared output and a terminating procedure.** This is what Elsevier, IEEE, `algorithm2e` and the ML literature call it; pseudocode is the notation, not the object. Keep "Algorithm n". Recommend renaming only when a block is an informal sketch with no defined output, and then prefer rewriting it into a proper listing over inventing a "Pseudocode" float.
- Listings follow one convention (`algorithmic` or `algorithm2e`): indentation for scope, explicit Input and Output lines, numbered lines, no language-specific syntax, comments that define terms rather than wrap onto a second line.
- Check the listing against the code and the text, not only for style: initial values (does k start at 0 or 1, and which does the text and the figure use?), the first iteration (does observation 1 receive an output?), and branch order (does the listing test the condition the text says is primary?). A listing that contradicts the implementation is a must-fix.

## 8. Selection rubric for image variations

When generating schematics with an image tool, produce five variations and score each on the five criteria below, 1 to 5. Choose the highest total. On a tie, choose the simpler image.

| Criterion | 5 means | 1 means |
|---|---|---|
| Accuracy | Nothing depicted contradicts the method, data or notation | Depicts a step, component or relation the paper does not have |
| Clarity | Message readable in under ten seconds at print size | Reader must study it to find the point |
| Simplicity | Every element is necessary | Contains decoration, redundant arrows, or unexplained icons |
| Consistency | Matches the Phase 2 palette, typeface and notation map | Introduces new colours, fonts or symbols |
| Elegance | Balanced layout, clear hierarchy, generous whitespace | Crowded, uneven, or visually noisy |

Record all five scores per variation in the design log even for the rejected ones. The rejects are how the user learns what the tool tends to get wrong.

Prefer a vector schematic (TikZ, matplotlib patches, SVG) over a generated raster whenever the diagram is boxes and arrows. Generated images are for illustrations that vector tools cannot draw economically.

## 9. Common failures and their fixes

| Failure | Fix |
|---|---|
| Caption describes the enforced/final model; script plots the intrinsic/raw one | Plot the variant the caption names, or change the caption; add a panel that makes the difference visible |
| Schematic box claims "parity" or a count the results do not support | Rewrite the box text from the results table; treat schematic text as claims |
| Eight unlabelled colours in one line plot | Reduce to the three or four series that carry the argument; direct-label them; move the rest to supplementary |
| Five series, five colours, fifth line style recycled | Rule 1: four styles maximum; label all five at the line ends with `figstyle.label_lines`, or split into panels |
| Six hatched fills and a six-entry legend | Rule 2: value steps from L* 25 to 85 and the category printed at each bar |
| Colour used for model variants or ordered phases "because Okabe-Ito is safe" | No Rule 0 exception applies; regenerate in the grey cycle. Colour-blind safe is not greyscale safe: vermilion and bluish green are 3.6 L* apart |
| Diverging heatmap (RdBu) delivered without cell values | Both ends are dark in greyscale; annotate every cell or use a one-signed map |
| Sans-serif figure text in an Elsevier or IEEE manuscript | Serif matching the body font; one family across the set (`scripts/set_check.py`) |
| "Colour and pattern are redundant, so it survives greyscale" said, not rendered | Run the gate: `palette_check.py` and `greyscale_preview.py --width-mm`; record the result |
| Legend covers the interesting part of the data | Direct labels, or legend outside axes, or reposition data via axis limits |
| Text unreadable after scaling to column width | Design at final width from the start; regenerate rather than scale |
| `\resizebox{\textwidth}` on every table (shrinks wide ones, enlarges narrow ones) | Remove it; fix content so tables share one type size |
| Figure duplicates a table | Keep whichever supports comparison better; usually the figure for trends, the table for exact values |
| One raster figure (JPEG/PNG with shadows) among vector plots | Rebuild as vector in the paper's palette and typeface |
| Schematic with generated text baked in | Regenerate without text; overlay vector labels |
| Method figure appears before the method section | Move it, or split so that the part the reader can already understand comes first |
| Truncated y-axis makes a small effect look large | Start at zero, or add a visible axis break and say so in the caption |
| Symbols or names differ across figure, table, listing and text | Apply the notation map; regenerate labels |
| Phase, index or counter starts at different values in listing, figure and text | Pick one origin, state it in the text, fix the listing and the figure labels |
| Caption is a title, not an explanation | Rewrite with the three-part caption shape in templates.md |
| In-figure title with an em-dash duplicating the caption | Delete the title; the caption carries it |
| Formula typed inline five times, never numbered | Number it once; cite the number elsewhere |
| "Algorithm 1" flagged as "really pseudocode" | Keep the name if it has input, output and terminates; fix its content instead |
| Headline result exists only in a table | Add the signature figure that plots it |
| Significance marked on raw p when the protocol says adjusted p | Re-mark with the adjusted p, or restrict the claim to the pre-specified primary test |

## 10. The set (Rule 6)

Figures in one paper are a family. One typeface (matching the body font), one weight set, one width pair (single and double column), one palette logic and one Rule 0 policy. A reader notices the odd one out before reading a single label.

- Phase 2 fixes the system once; Phase 3 applies it; delivery measures it. `uv run --with pymupdf python scripts/set_check.py figures/*.pdf --widths 90,190` reports, per file, the page width, the print width it will be scaled to, the smallest text after scaling, the font family, and the number of non-grey colours, and flags every file that differs from the majority.
- A TikZ or Inkscape schematic counts as part of the set: its font must be the same family as the matplotlib figures, or the matplotlib figures must switch to it. Computer Modern next to Times is a defect.
- Files designed at the review-mode text width (elsarticle `[review]`, 122 mm) and printed at 90 mm shrink by 0.74; text that was 7 pt is 5.2 pt. Design at the venue's final widths from the start.
- Colour figures under a Rule 0 exception sit in a greyscale set; `set_check.py` flags them so the exception can be confirmed in the design log rather than discovered by the reader.
