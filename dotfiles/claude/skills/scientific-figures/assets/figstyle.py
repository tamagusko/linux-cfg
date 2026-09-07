"""Greyscale-first figure helpers that implement the style decisions of scientific-figures.

Usage inside a figure script:

    import sys; sys.path.insert(0, "/path/to/scientific-figures/assets")
    import figstyle
    figstyle.use("grey", width="double")          # Rule 0 default; "colour" only after an exception
    fig, ax = plt.subplots()
    ...
    figstyle.label_lines(ax)                       # Rule 4: direct labels, no legend
    figstyle.too_many_series(ax)                   # Rule 1: warns at the fifth series
    bars = ax.bar(x, y, **figstyle.bar_fills(n)[i]) # Rule 2: hatch to four, value steps beyond

Everything here is deliberately small. The rcParams live in paper.mplstyle; this
module only switches mode and width, generates fills, places labels and counts.
"""
from __future__ import annotations

import itertools
import math
import warnings
from pathlib import Path

import matplotlib.pyplot as plt
from cycler import cycler

STYLE = Path(__file__).with_name("paper.mplstyle")

# Widths in inches: 90, 140 and 190 mm (Elsevier and IEEE column conventions)
WIDTHS = {"single": 3.54, "onehalf": 5.51, "double": 7.48}

# Rule 1: four entries, two cues each
LINESTYLES = ["-", "--", "-", ":"]
MARKERS = ["o", "s", "^", "D"]
GREYS = ["#000000", "#000000", "#555555", "#555555"]
# Okabe-Ito, first four; the full set is kept for reference only
OKABE_ITO = ["#0072B2", "#D55E00", "#009E73", "#E69F00"]
OKABE_ITO_FULL = OKABE_ITO + ["#CC79A7", "#56B4E9", "#F0E442", "#000000"]
# Rule 2: hatches on white bars with black edges, four categories at most
HATCHES = ["", "///", "\\\\\\", "xxx"]
SERIES_LIMIT = 4
MIN_LSTAR_GAP = 20.0


def use(mode: str = "grey", width: str = "single", aspect: float = 0.66) -> None:
    """Apply paper.mplstyle, then the mode-specific cycle and colour map, then the width."""
    if mode not in ("grey", "colour", "color"):
        raise ValueError("mode must be 'grey' or 'colour'")
    if width not in WIDTHS:
        raise ValueError(f"width must be one of {sorted(WIDTHS)}")
    plt.style.use(str(STYLE))
    colours = GREYS if mode == "grey" else OKABE_ITO
    plt.rcParams["axes.prop_cycle"] = (
        cycler("color", colours) + cycler("linestyle", LINESTYLES) + cycler("marker", MARKERS)
    )
    plt.rcParams["image.cmap"] = "Greys" if mode == "grey" else "cividis"
    w = WIDTHS[width]
    plt.rcParams["figure.figsize"] = (w, w * aspect)


# --- lightness ---------------------------------------------------------------

def _srgb_to_linear(c: float) -> float:
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def _linear_to_srgb(c: float) -> float:
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055


def lightness(hex_colour: str) -> float:
    """CIE L* (0 black to 100 white) of an sRGB hex colour; what a greyscale copy keeps."""
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    y = 0.2126 * _srgb_to_linear(r) + 0.7152 * _srgb_to_linear(g) + 0.0722 * _srgb_to_linear(b)
    return 116 * (y ** (1 / 3) if y > 0.008856 else 7.787 * y + 16 / 116) - 16


def grey_for_lightness(lstar: float) -> str:
    """Neutral grey hex with the requested L*."""
    y = ((lstar + 16) / 116) ** 3 if lstar > 8 else lstar / 903.3
    v = round(255 * _linear_to_srgb(y))
    return "#{0:02X}{0:02X}{0:02X}".format(max(0, min(255, v)))


def value_steps(n: int, lo: float = 25.0, hi: float = 85.0) -> list[str]:
    """n neutral greys evenly spaced in L* from lo (dark) to hi (light). Rule 2 beyond four fills."""
    if n < 1:
        return []
    if n == 1:
        return [grey_for_lightness(lo)]
    return [grey_for_lightness(lo + (hi - lo) * i / (n - 1)) for i in range(n)]


def min_lightness_gap(colours: list[str]) -> tuple[float, tuple[str, str] | None]:
    """Smallest pairwise L* difference in a list of colours, and the offending pair."""
    best, pair = math.inf, None
    for a, b in itertools.combinations(colours, 2):
        gap = abs(lightness(a) - lightness(b))
        if gap < best:
            best, pair = gap, (a, b)
    return (best if pair else math.inf), pair


# --- fills, labels, counts ----------------------------------------------------

def bar_fills(n: int) -> list[dict]:
    """Per-category bar kwargs. Up to four: white with hatch. Beyond: greyscale value steps.

    Hatching past four categories renders as noise in a print PDF and is not offered.
    """
    if n <= SERIES_LIMIT:
        return [dict(facecolor="white", edgecolor="black", hatch=HATCHES[i]) for i in range(n)]
    warnings.warn(
        f"{n} fill categories: hatching stops at {SERIES_LIMIT} (Rule 2); using L* value steps. "
        "Print the category name at each bar; do not rely on a legend.", stacklevel=2)
    return [dict(facecolor=c, edgecolor="black") for c in value_steps(n)]


def label_lines(ax, pad: float = 0.01, min_gap: float = 0.045, fontsize: float | None = None) -> None:
    """Write each line's label at its right end in the line's colour and drop the legend.

    Labels that would collide are pushed apart vertically (in axes fraction). Lines
    whose label starts with '_' are skipped, as matplotlib's legend does.
    """
    lines = [ln for ln in ax.get_lines() if not ln.get_label().startswith("_") and len(ln.get_xdata())]
    if not lines:
        return
    to_axes = ax.transData + ax.transAxes.inverted()
    items = []
    for ln in lines:
        x, y = ln.get_xdata()[-1], ln.get_ydata()[-1]
        _, ya = to_axes.transform((x, y))
        items.append([ya, ln])
    items.sort(key=lambda t: t[0])
    for i in range(1, len(items)):
        if items[i][0] - items[i - 1][0] < min_gap:
            items[i][0] = items[i - 1][0] + min_gap
    for k in range(len(items) - 2, -1, -1):
        if items[k + 1][0] - items[k][0] < min_gap:
            items[k][0] = items[k + 1][0] - min_gap
    xa_max = max(to_axes.transform((ln.get_xdata()[-1], 0))[0] for ln in lines)
    for ya, ln in items:
        ax.text(xa_max + pad, ya, ln.get_label(), transform=ax.transAxes,
                color=ln.get_color(), ha="left", va="center",
                fontsize=fontsize or plt.rcParams["legend.fontsize"], clip_on=False)
    leg = ax.get_legend()
    if leg is not None:
        leg.remove()


def too_many_series(ax, limit: int = SERIES_LIMIT) -> int:
    """Count plotted series and warn past the Rule 1 limit. Returns the count."""
    n = len([ln for ln in ax.get_lines() if len(ln.get_xdata()) > 1])
    if n > limit:
        warnings.warn(
            f"{n} series in one axes exceeds the limit of {limit} (Rule 1). Direct-label all of them, "
            "split into panels sharing axes, or move series to supplementary. Do not add a fifth line style.",
            stacklevel=2)
    return n


__all__ = ["use", "WIDTHS", "GREYS", "OKABE_ITO", "OKABE_ITO_FULL", "LINESTYLES", "MARKERS", "HATCHES",
           "SERIES_LIMIT", "MIN_LSTAR_GAP", "lightness", "grey_for_lightness", "value_steps",
           "min_lightness_gap", "bar_fills", "label_lines", "too_many_series"]
