#!/usr/bin/env python3
"""Rule 3 measurement: do the series colours of a figure survive a greyscale copy?

Reports the CIE L* (lightness) of every colour and the smallest pairwise gap.
Two series in one axes closer than 20 L* units merge on a photocopy; exit 1.

Usage:
  python palette_check.py '#0072B2' '#D55E00' '#009E73'        # hex list
  python palette_check.py --mplstyle assets/paper.mplstyle      # the prop_cycle colours
  python palette_check.py --script make_figures.py              # every 6-digit hex literal in a script
  python palette_check.py ... --min-gap 20
Pure Python; no dependencies. For a rendered file use greyscale_preview.py --width-mm.
"""
from __future__ import annotations

import itertools
import re
import sys
from pathlib import Path

HEX = re.compile(r"#?([0-9a-fA-F]{6})\b")


def lightness(hex_colour: str) -> float:
    h = hex_colour.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (r, g, b)]
    y = 0.2126 * lin[0] + 0.7152 * lin[1] + 0.0722 * lin[2]
    return 116 * (y ** (1 / 3) if y > 0.008856 else 7.787 * y + 16 / 116) - 16


def colours_from_mplstyle(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8")
    m = re.search(r"axes\.prop_cycle\s*:\s*(.+)", text)
    if not m:
        return []
    cyc = re.search(r"cycler\(\s*'color'\s*,\s*\[([^\]]*)\]", m.group(1))
    return ["#" + h for h in HEX.findall(cyc.group(1))] if cyc else []


def colours_from_script(path: Path) -> list[str]:
    seen: list[str] = []
    for h in HEX.findall(path.read_text(encoding="utf-8", errors="replace")):
        c = "#" + h.upper()
        if c not in seen:
            seen.append(c)
    return seen


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    min_gap = 20.0
    if "--min-gap" in argv:
        i = argv.index("--min-gap"); min_gap = float(argv[i + 1]); del argv[i:i + 2]
    colours: list[str] = []
    if "--mplstyle" in argv:
        i = argv.index("--mplstyle"); colours += colours_from_mplstyle(Path(argv[i + 1])); del argv[i:i + 2]
    if "--script" in argv:
        i = argv.index("--script"); colours += colours_from_script(Path(argv[i + 1])); del argv[i:i + 2]
    colours += ["#" + HEX.match(a).group(1).upper() for a in argv if HEX.match(a)]
    # duplicates (same colour twice in a cycle, distinguished by line style) are not a clash
    unique = list(dict.fromkeys(c.upper() for c in colours))
    if not unique:
        print("no colours found")
        return 2
    print("colour   L*")
    for c in unique:
        print(f"{c}  {lightness(c):5.1f}")
    if len(unique) < 2:
        print("single colour: nothing to separate")
        return 0
    worst = min(((abs(lightness(a) - lightness(b)), a, b) for a, b in itertools.combinations(unique, 2)))
    verdict = "pass" if worst[0] >= min_gap else "FAIL"
    print(f"smallest gap {worst[0]:.1f} L* between {worst[1]} and {worst[2]} (min {min_gap:g}): {verdict}")
    if verdict == "FAIL":
        print("These two series merge on a greyscale copy. Give them different line styles or markers "
              "and direct labels, or move one to a lighter/darker value.")
    return 0 if verdict == "pass" else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
