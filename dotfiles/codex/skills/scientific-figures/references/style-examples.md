# Worked examples for the style decisions

Three cases that the density limits and Rule 0 exist for. Each shows the decision, the code that implements it with `assets/figstyle.py`, and the gate result. Adapt the code; do not add a fifth line style or a fifth hatch.

Common preamble:

```python
import sys; sys.path.insert(0, "~/.agents/skills/scientific-figures/assets")
import matplotlib.pyplot as plt, pandas as pd, figstyle
```

## 1. Five-series line plot: fixed by direct labels

Data: IRI trajectory over 20 years under five maintenance strategies. Rule 0: grey (strategies are categories; nothing is encoded that a line style cannot carry). Rule 1: five exceeds four, so no legend and no fifth pattern; the series are labelled at the line ends and the cycle's two lightness values plus two line styles plus markers separate them.

```python
figstyle.use("grey", width="single")
df = pd.read_csv("iri_strategies.csv")
fig, ax = plt.subplots()
order = df.groupby("strategy")["iri_m_per_km"].last().sort_values(ascending=False).index
for i, s in enumerate(order):
    g = df[df.strategy == s]
    ax.plot(g.year, g.iri_m_per_km, label=s, markevery=(i, 4))   # cycle supplies colour, style, marker
ax.set_xlabel("Years since treatment")
ax.set_ylabel("IRI (m/km)")
ax.set_xlim(0, 20)
figstyle.too_many_series(ax)          # warns: 5 > 4, which is why the labels below exist
figstyle.label_lines(ax)              # end labels in the line's colour, legend removed
fig.savefig("fig_line.pdf")                  # constrained layout keeps the end labels inside 90 mm
```

With five series the fifth reuses the first entry of the cycle (black solid, circle). That is acceptable only because the labels name every line; if two labelled lines cross near their ends, split into two panels sharing the y-axis (three treatments in one, two in the other) rather than adding a style.

Gate: `palette_check.py '#000000' '#555555'` gives 35.6 L*, pass. Greyscale preview at 90 mm: five labelled lines, legible at 7 pt.

Before (the baseline that fails): five Okabe-Ito hues, the fifth style recycled, no gate. Vermilion and bluish green measured 3.6 L* apart; on a copy the two lower curves are told apart by marker shape alone at 3.5 pt.

## 2. Six-category grouped bar: fixed by value steps

Data: RMSE of six models at three horizons with fold standard deviations. Rule 0: grey. Rule 2: six fill categories exceed four, so hatching is banned; lightness steps from L* 25 to 85 carry the model and the name is printed at each bar.

```python
import numpy as np
figstyle.use("grey", width="double", aspect=0.45)
df = pd.read_csv("rmse_models.csv")
models = ["Linear", "RF", "LightGBM", "M1", "M2", "M3"]          # order from the text, baselines first
horizons = ["t+1", "t+2", "t+3"]
fills = figstyle.bar_fills(len(models))                         # warns and returns six value steps
w = 0.13
fig, ax = plt.subplots()
for i, m in enumerate(models):
    g = df[df.model == m].set_index("horizon").loc[horizons]
    x = np.arange(len(horizons)) + (i - 2.5) * w
    ax.bar(x, g.rmse_m_per_km, w, yerr=g.sd, ecolor="black", capsize=1.5, **fills[i])
    for xi, y in zip(x, g.rmse_m_per_km):                        # Rule 4: name at the bar
        light = figstyle.lightness(fills[i]["facecolor"]) > 55
        ax.text(xi, 0.012 if light else y + g.sd.iloc[0] + 0.008, m, rotation=90,
                ha="center", va="bottom", fontsize=7)          # 7 pt floor (Rule 5)
ax.set_xticks(np.arange(len(horizons)), horizons)
ax.set_xlabel("Forecast horizon")
ax.set_ylabel("RMSE (m/km)")
ax.set_ylim(0, None)
fig.savefig("fig_bar.pdf")
```

Six greys evenly spaced in L* (25, 37, 49, 61, 73, 85) are at least 12 L* apart from their neighbours, which is below the 20 L* gate for two series in one axes. That is why the name is printed at every bar: the lightness orders the models, the label identifies them, and no legend is needed. If the argument is only "M3 beats the baselines", the better figure has two fills, M3 hatched and the rest white, and a table for the rest.

Before: three greys plus three Okabe-Ito hues with hatching, six-entry legend above the axes, sans-serif. Mid grey and vermilion measured 1.0 L* apart.

## 3. SHAP dependence, colour justified

Data: TreeSHAP values of one feature against its value, coloured by the value of the interacting feature. Rule 0: colour, exception 1. Position already carries feature value and SHAP value, the point has no line style, and the interaction is a third continuous variable; lightness alone gives too few distinguishable steps for a continuous colour bar the reader has to read values from.

```python
figstyle.use("colour", width="double", aspect=0.4)              # cividis: monotone lightness
fig, axes = plt.subplots(1, 3, sharey=True)
for ax, feat in zip(axes, ["Current IRI (m/km)", "Age (years)", "KESAL (10$^6$ ESALs)"]):
    sc = ax.scatter(X[feat], shap[feat], c=X["Age (years)"], s=6, alpha=0.6, linewidths=0)
    ax.plot(xs, trend[feat], color="black", lw=1.0)             # the trend stays black
    ax.axhline(0, color="black", lw=0.5, ls="--")
    ax.set_xlabel(feat)
axes[0].set_ylabel("SHAP value (m/km)")
fig.colorbar(sc, ax=axes, label="Age (years)", shrink=0.8)
fig.savefig("fig_shap.pdf")
```

Gate: cividis runs from L* 13 to 91, so the interaction gradient survives greyscale as dark-to-light and the black trend line stays the darkest mark. Design log: `Rule 0: colour, exception 1 (interaction on point colour); Gate: pass, colour bar ends 78 L* apart`.

Not an exception: the same dependence plot with all points one blue and the trend red. Nothing is encoded in the hue, so that figure is Rule 0 grey: points in `#555555` at alpha 0.5, trend black.
