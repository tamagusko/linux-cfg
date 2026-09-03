# Design rules and selection rubric

## Contents

1. Accuracy rules
2. Narrative rules
3. Typography and geometry
4. Colour
5. Plot-type rules
6. Tables
7. Equations and algorithm listings
8. Selection rubric for image variations
9. Common failures and their fixes

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

- Minimum text size 7 pt at final print size; target 8 to 9 pt for labels, matching or one step below the body font.
- Minimum line weight 0.5 pt for data lines; 0.25 pt is acceptable for gridlines only.
- Typeface matches the venue body font. Elsevier (elsarticle) and IEEE Transactions set body text in a Times-like serif, so figure text is serif there; sans-serif only for venues whose body font is sans. One typeface per paper, at most two weights. Mixed serif and sans across figures is a defect.
- Single column 90 mm, 1.5 column 140 mm, double column 190 mm unless the venue says otherwise. Design at final size; scaling a large figure down shrinks the text below the minimum.
- No in-figure titles. The caption is the title; a title inside the axes duplicates it and usually carries an em-dash.
- Aspect ratio between 4:3 and 16:9 for single panels. Taller than 4:3 only for stacked panels sharing an x-axis.
- Whitespace is a design element. Leave margin inside the axes so data marks do not touch the frame; check that nothing is clipped at the edge of the exported file.
- Axis labels carry quantity and unit in the form "Travel time (min)". Dimensionless quantities carry no unit ("Recall", "R²"), never a fabricated one. Units in SI; use the venue's convention for exceptions such as km/h.
- Tick labels with consistent decimal places along an axis. No scientific notation in tick labels if a unit prefix removes the need.
- Figure file names carry the printed number (`fig3_...` prints as Figure 3); renumber files when floats move.
- Vector output (PDF or SVG) preferred. Raster output at 600 dpi for line art, 300 dpi minimum for photographs and generated images. One raster among vector figures is visible on the page; rebuild it.
- Fonts embedded (matplotlib `pdf.fonttype 42`); `scripts/text_size_check.py` reports Type 3 fonts and the text size at print width.

## 4. Colour

- Maximum six hues in the paper's palette. Fewer is better.
- Palette is colour-blind safe (test against deuteranopia and protanopia) and distinguishable when converted to greyscale. Okabe-Ito and the matplotlib "viridis" family both pass. Run `scripts/greyscale_preview.py` on the final files.
- Colour never carries meaning alone. Pair it with marker shape, line style or direct labelling.
- Sequential data use a sequential map; diverging data use a diverging map with a neutral midpoint at the meaningful zero; categorical data use qualitative hues. Ordered categories (phase 0, 1, 2; horizons t+1 to t+5) are sequential data, not categorical.
- Do not use red-green pairs as the only contrast.
- Same colour means the same thing in every figure of the paper. Build the mapping once in Phase 2 and reuse it. The lowest-contrast colour never goes on the most important series.

## 5. Plot-type rules

- No 3D effects, no gradients on data marks, no drop shadows, no decorative backgrounds. This includes schematics: flat boxes, one accent colour per concept, drawn in the same palette as the data plots.
- No pie charts. Use a bar chart or a single sentence.
- No dual y-axes. Use two panels sharing x.
- Prefer direct labelling at the end of lines or beside bars over a legend. If a legend is unavoidable, place it inside the axes only where it does not occlude data.
- Gridlines light and thin, or none. The data are the darkest thing on the page.
- Remove the top and right spines unless the venue style keeps them.
- Bar charts: bars start at zero, ordered by a meaningful rule (magnitude, category order from the text), not alphabetically by default.
- Scatter plots with many points: reduce marker size and add transparency, or switch to hexbin or 2D density.
- Time series: x-axis in real time units, not sample index, unless the index is the quantity of interest.
- Event markers on a time series follow one stated convention (for example, marker on the first post-event observation) and the caption states it.
- Maps: north arrow, scale bar, and a basemap muted enough that the data layer dominates.
- Confusion matrices and heatmaps: annotate cells with values when there are fewer than about 50 cells; otherwise rely on the colour bar and describe the pattern in the caption.
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
