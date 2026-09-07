# scientific-figures: greyscale-first decision system

Status: built and validated 2026-09-07 (confirmed as proposed: C1 to C5, two-lightness cycle, baseline tests, 190 mm). Skill changes uncommitted in the working tree.
Provenance: Fable 5.1 (inspection, design, build, adjudication); Sonnet for the four RED/GREEN test runs.

## 0. Outcome

- RED (no skill): both agents defaulted to colour with no decision step and no greyscale render. Measured: line figure 3.6 L* between two Okabe-Ito series; bar figure 1.0 L* between a grey and an orange bar, sans-serif, six-entry legend. Rationalisation recorded verbatim: "color and pattern are redundant so the split survives grayscale printing" (not rendered).
- GREEN (skill loaded): both agents recorded `Rule 0: grey`, stayed within the limits (five lines direct-labelled; six models moved to the x-axis with three hatched horizons), ran `palette_check`, `text_size_check` and `greyscale_preview --width-mm`, and reported the measurements. The bar agent caught and fixed its own aspect-ratio fault before delivery.
- Two defects found by the smoke test and fixed before GREEN: `savefig.bbox: tight` made every PDF narrower than its design width (per-figure rescale, a Rule 6 fault), replaced by constrained layout with a standard bbox; the bar example used 6.5 pt text.
- Audit of pavements-ml: `papers/in-progress/pavements-ml/figures/greyscale/audit.md`, four regenerated candidates and their script alongside the untouched originals.


## 1. Existing-skill report

**Location.** `dotfiles/claude/skills/scientific-figures/` in linux-cfg, symlinked as
`~/.claude/skills/scientific-figures`. Tracked (commit b9f6453). No project-level
copy in pavements-ml. Siblings: `scientific-visualization` (Nature/Science
multi-panel meta-skill, colour-oriented), `matplotlib` (exploratory), `seaborn`,
`dataviz` (artifact charts). None of them is the base; they stay untouched.

**Structure (5,400 words plus 4 scripts).**

| File | Words | Role |
|---|---|---|
| `SKILL.md` | 1,614 | Two modes (review / production), verification stance, 3-phase workflow with 2 gates, non-negotiables |
| `references/design-rules.md` | 2,535 | 9 sections: accuracy, narrative, typography/geometry, colour, plot types, tables, equations/algorithms, image rubric, failure table |
| `references/templates.md` | 1,251 | Review report skeleton, figure plan, design log, caption shape, 20-item consistency checklist |
| `assets/paper.mplstyle` | | Serif, 8/7 pt, 90 mm default, Okabe-Ito 6-hue cycle paired with line styles, viridis |
| `scripts/float_audit.py` | | LaTeX float inventory and reference-order flags |
| `scripts/table_check.py` | | Units, precision, constant columns, booktabs |
| `scripts/text_size_check.py` | | Text size at print width, Type 3 fonts (pymupdf) |
| `scripts/greyscale_preview.py` | | Greyscale render for a visual check (Pillow, pdftoppm) |

**Coverage against the seven rules.**

| Rule | Present today | Gap |
|---|---|---|
| 0 Colour decision | Colour is the default ("colour online with greyscale legibility"); Okabe-Ito and viridis named; "colour never carries meaning alone" | No decision step, no named exceptions, greyscale is a check on colour rather than the default |
| 1 Curves | Line styles paired to the 6-hue cycle; "eight colours → reduce to three or four, direct-label" in the failure table | No hard series limit; cycle length is 6 |
| 2 Fills | Nothing | No hatching rules, no value-step rule, no limit |
| 3 Survival gate | `greyscale_preview.py` exists; checklist item "greyscale conversion remains readable" | Visual, advisory, run at the end; no print-size render, no luminance measurement |
| 4 Legends | Direct labels over legends; legend inside axes only where it occludes nothing | "No legend for single series" and "every pattern named" not stated |
| 5 Spec layer | 7 pt min / 8–9 pt target, 0.5 pt lines, serif matching venue, 90/140/190 mm, vector or 600 dpi, no in-figure titles, units on axes, Type 42 fonts, mplstyle | Nearly complete; the only difference is line weight (below) |
| 6 The set | Phase 2 design system; checklist ticks "for the whole set"; notation map | No tool that checks the delivered set; consistency is asserted, not measured |

Rules 0–3 are the real upgrade. Rule 5 is already there and Rule 6 needs a script,
not prose.

**Conflicts that need your ruling.**

| # | Old skill | New rule | Proposed resolution |
|---|---|---|---|
| C1 | Colour default, greyscale as a check | Greyscale default, colour by exception | Adopt the new rule. `paper.mplstyle` cycle becomes black × four line styles; Okabe-Ito moves to an opt-in colour mode used only after a Rule 0 exception is recorded |
| C2 | Minimum data line 0.5 pt | ≥ 1 pt at final size | 1.0 pt for data series (already the mplstyle value); 0.5 pt floor stays for reference and auxiliary lines; 0.25 pt for grid only |
| C3 | Raster: 600 dpi line art, 300 dpi photographs | ≥ 300 dpi raster | Keep the old, stricter split; 300 dpi is the floor for photographs only |
| C4 | Confusion matrices and heatmaps: annotate under ~50 cells | Heatmaps and matrices are a colour exception | Narrow the exception: a one-signed matrix (confusion, counts) is drawn in `Greys` with annotations and needs no colour; colour is justified when a second variable is encoded (SHAP interaction colour) or the scale is diverging. Diverging maps fail the greyscale test by construction (both ends dark), so diverging heatmaps must be annotated or use a luminance-asymmetric map |
| C5 | Six hues, cycle of six | Four-series limit for curves | Cycle length becomes four in both modes. A fifth series is a design decision (direct labels, panels, or supplementary), never a fifth style |

No other contradictions. Typography, sizes, units, titles, vector export, legend
placement and "colour never alone" agree with the new rules and are kept as
written.

## 2. Upgrade design

### 2.1 Scope preamble (new, top of SKILL.md)

Three sentences after the opening paragraph:

> **Publication figures only, greyscale first.** For plots, bars and curves going to
> Elsevier transport and construction journals, IEEE venues and EU deliverables the
> default is greyscale: those figures are printed, photocopied and read as
> monochrome PDFs, and a figure that survives that treatment is strictly more
> useful. Greyscale is not absolute: Rule 0 names the figure types whose meaning
> lives in colour. Slides and posters are a different regime (projected, colour
> tolerant) and belong to scientific-slides and latex-posters.

### 2.2 The decision system (SKILL.md section "Style decisions", ~300 words; full text in design-rules.md)

**Rule 0, run first for every figure.** Greyscale unless one of these holds:

1. two variables share one mark and the second is encoded by colour (SHAP
   dependence coloured by an interacting feature, scatter coloured by a third
   quantity);
2. the scale is diverging with a meaningful zero;
3. overlay on a photograph or image (segmentation mask, detection box);
4. map with categorical regions or a continuous surface;
5. the venue instructs colour.

Recording: the design log carries `Rule 0: grey` or `Rule 0: colour, exception n`.
When colour is used: Okabe-Ito for categories, viridis or cividis for sequential,
ColorBrewer colour-blind-safe sets as alternatives, and the figure still passes
Rule 3.

**Rule 1, curves.** Solid, dashed, dotted, dash-dot: four series. Five or more:
direct labels at the line ends and no legend, or split into panels sharing axes,
or move to supplementary. A legend of six dash patterns is a design failure. Data
lines 1.0 pt at final size.

**Rule 2, fills.** Hatching (`///`, `\\\`, `xxx`, `...`) on white bars with black
edges: four categories. Five or more: greyscale value steps, perceptually spaced
from L* 25 to 85, with the category name printed beside or inside the bar.
Hatching past four is banned; it renders as noise at 300 dpi and below.

**Rule 3, the gate.** Every figure, colour or not, is rendered at its print width,
converted to greyscale, and checked: each series and class identifiable, each
label legible, no information carried by hue alone. Two measurements make it
objective: `palette_check.py` reports the lightness (L*) of every series colour
and fails when two series in one axes sit closer than 20 L* units;
`greyscale_preview.py --width-mm` renders at print size and 300 dpi. The gate
runs before delivery and its result goes in the design log. Failing the gate is
a must-fix.

**Rule 4, legends.** Every line style or hatch that appears is named, by direct
label first, legend second. Legend inside the axes only where it covers nothing.
No legend on a single-series figure.

**Rule 5, spec (retained, one change).** 7 pt minimum, 8–9 pt target, one
typeface matching the venue body font, 90 / 140 / 190 mm canonical widths and
design at final size, vector export, 600 dpi line art or 300 dpi photographs,
no in-figure titles, quantity and unit on every axis, data lines 1.0 pt, aux lines
0.5 pt, grid 0.25 pt. Nothing ships from matplotlib defaults; every script starts
with `plt.style.use(paper.mplstyle)`.

**Rule 6, the set.** One typeface, one weight set, one width pair, one palette
logic and one Rule 0 policy per paper. `set_check.py` reads every delivered PDF
and reports font families, page widths, smallest text and colour count per file,
flagging any file that differs from the majority. Runs as the last step of
Phase 3 and in review mode.

### 2.3 Where each piece lands

| File | Change |
|---|---|
| `SKILL.md` | Preamble; new "Style decisions" section (Rules 0–3 compact, 4–6 one line each); Phase 2 step 7 rewritten to "record the Rule 0 decision per figure"; Phase 3 step 13 adds `set_check.py`; non-negotiables and resource list updated. Net +250 words |
| `references/design-rules.md` | §3 line weights (C2); §4 rewritten as "Colour and greyscale: the decision" with the Rule 0 tree, palettes, gate procedure; §5 gets the Rule 1 and Rule 2 limits, hatch and value-step rules, legend rules; §9 gains four failures (six hatched categories, six-dash legend, diverging heatmap in greyscale, colour-only class encoding) |
| `references/style-examples.md` (new) | Three worked examples with before/after code: 5-series line plot fixed by direct labels; 6-category bar fixed by value steps; SHAP dependence justified under Rule 0 exception 1 with the greyscale fallback stated |
| `references/templates.md` | Design log gains `Rule 0:` and `Gate:` lines; checklist gains Rule 1/2 limits, gate pass, `set_check.py` clean |
| `assets/paper.mplstyle` | Greyscale-first rewrite (block below) |
| `assets/figstyle.py` (new, ~120 lines) | `use(mode="grey" \| "colour", width="single" \| "double")`; `GREYS`, `OKABE_ITO`, `HATCHES`; `value_steps(n)`; `bar_fills(n)` that raises past four hatches; `label_lines(ax)` for end-of-line labels; `too_many_series(ax)` warning at five |
| `scripts/palette_check.py` (new) | Colours from a hex list, an mplstyle, or a matplotlib figure pickle; L* per colour and min pairwise gap; exit 1 under 20 |
| `scripts/set_check.py` (new) | Cross-file consistency of delivered PDFs (pymupdf): fonts, widths, min text, colour count |
| `scripts/greyscale_preview.py` | Add `--width-mm` (render at print width, 300 dpi) |

### 2.4 The rcParams block (`assets/paper.mplstyle`, greyscale-first)

```
# Geometry: design at final width. 3.54 in = 90 mm, 5.51 in = 140 mm, 7.48 in = 190 mm
figure.figsize      : 3.54, 2.36
figure.dpi          : 150
savefig.dpi         : 600
savefig.bbox        : tight
savefig.pad_inches  : 0.02
savefig.format      : pdf
pdf.fonttype        : 42
ps.fonttype         : 42
svg.fonttype        : none

# Typography: one serif family (Elsevier, IEEE); 8 pt labels, 7 pt ticks, floor 7 pt
font.family         : serif
font.serif          : Times New Roman, Times, Nimbus Roman, TeX Gyre Termes, Liberation Serif, STIXGeneral
mathtext.fontset    : stix
font.size           : 8
axes.labelsize      : 8
axes.titlesize      : 8
xtick.labelsize     : 7
ytick.labelsize     : 7
legend.fontsize     : 7

# Axes: no titles, no top/right spines, data darkest on the page
axes.linewidth      : 0.6
axes.spines.top     : False
axes.spines.right   : False
axes.grid           : False
axes.axisbelow      : True
axes.xmargin        : 0.03
axes.ymargin        : 0.05
axes.formatter.use_mathtext : True
grid.linewidth      : 0.25
grid.color          : 0.85

# Marks: Rule 1 and Rule 5 weights
lines.linewidth     : 1.0
lines.markersize    : 3.5
lines.markeredgewidth : 0.6
errorbar.capsize    : 2
patch.linewidth     : 0.6
patch.edgecolor     : black
patch.force_edgecolor : True
hatch.linewidth     : 0.5
hatch.color         : black

# Legend: direct labels first; a legend, if any, is quiet
legend.frameon      : False
legend.handlelength : 2.2
legend.borderaxespad: 0.3

# Rule 0 default: greyscale. Four entries = the Rule 1 limit. Identity is carried
# by line style; value adds a second cue. A fifth series recycles the first and
# must be caught by figstyle.too_many_series().
axes.prop_cycle     : cycler('color', ['000000', '000000', '555555', '555555']) + cycler('linestyle', ['-', '--', '-', ':']) + cycler('marker', ['o', 's', '^', 'D'])

# Colour maps: Greys by default; viridis/cividis only after a Rule 0 exception
image.cmap          : Greys
```

The colour mode (`figstyle.use("colour")`) swaps only the cycle and cmap:
Okabe-Ito `['0072B2', 'D55E00', '009E73', 'E69F00']` with the same four line
styles and markers, `image.cmap: cividis`. Everything else is shared, which is
what Rule 6 requires.

Note on the cycle: two lightness values × two line styles gives each series two
independent cues, which survives both photocopying and 1 pt reduction better
than four styles at one value. If you prefer the literal four-style ladder
(solid, dashed, dotted, dash-dot, all black) that is a one-line change; say so.

### 2.5 Embedded examples (style-examples.md)

1. **Five-series line plot.** Before: five colours, legend upper right. After:
   four series in the grey cycle plus the fifth as a panel or, when all five must
   share axes, all in `#000000`/`#555555` with `label_lines()` at the right edge
   and no legend; caption names the series order.
2. **Six-category bar.** Before: six hatch patterns, legend. After: bars in
   `value_steps(6)` from L* 25 to 85, categories printed inside the light bars
   and beside the dark ones, ordered by magnitude.
3. **SHAP dependence, colour justified.** Rule 0 exception 1: the point colour
   encodes the interacting feature, which no line style can carry. Palette
   cividis (monotone lightness, so the interaction still reads in greyscale);
   the smoothed trend in black; log line "Rule 0: colour, exception 1;
   Gate: pass, ΔL* 41 between colour-bar ends".

### 2.6 Testing plan (writing-skills discipline)

- RED: two single-shot subagents with no skill loaded, asked to produce (a) a
  five-series line figure and (b) a six-category bar for a CBM paper from a
  synthetic CSV. Record the choices verbatim (expected: colour cycle, legends,
  no greyscale check).
- GREEN: same prompts with the rewritten skill. Pass criteria: Rule 0 recorded,
  limits respected, gate run.
- Application test: the pavements-ml audit (§3).

Cost: four short subagent runs, Sonnet tier (mechanical build task with a
checkable answer). Skip if you would rather go straight to the audit.

## 3. Validation target: pavements-ml (preview only, full audit after build)

Manuscript `main.tex` (elsarticle[review], target Construction and Building
Materials) includes four figures from `figures/`; the graphical abstract is a
separate PNG. `cagb-pavement/figures/` is a legacy set and is out of scope.

| Figure | Current state | Likely Rule 0 decision |
|---|---|---|
| Fig. 1 framework (TikZ) | Already monochrome, Computer Modern, natural size | Grey; compliant; typeface differs from the matplotlib figures (Rule 6 finding) |
| Fig. 2 Reset-Clock on section 8-7781 | Three Okabe-Ito phase colours plus grey; legend; 5.6–5.8 pt annotations; 4.8 in wide | Grey: phase is an ordered category, line style and marker carry it. Text below 7 pt is a Rule 5 fault |
| Fig. 3 accuracy vs consistency (signature) | Orange/blue for M0/M3, grey references, direct labels, 6.5 pt labels | Grey candidate: two model series, direct-labelled already; value plus marker replaces hue. Text size fault again |
| Fig. 4 SHAP dependence 2×3 | Single blue scatter, red trend; colour carries nothing | Grey: no exception applies (points are one class); the current colour is decoration |
| Graphical abstract | Full colour, multi-colour boxes | Out of the publication-figure regime by venue instruction (Elsevier asks for colour); note only |

Width: the scripts design at 4.8 in (122 mm, the review-mode text width). CBM
prints at 90 / 190 mm. Fig. 3 (4.8 × 5.4 in) placed single-column scales 0.74×,
taking its 6.5 pt labels to 4.8 pt. This is the venue parameter to fix before
regenerating anything: double column 190 mm for Figs. 2–4, or redesign for 90 mm.

Regenerated versions will be written to `figures/greyscale/` beside the
originals; `make_main_figures.py` and `make_shap_figure.py` are not modified,
the regeneration scripts live in the same new folder.
