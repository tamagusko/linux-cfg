#!/usr/bin/env python3
"""Rule 6: check a paper's delivered figure PDFs as one set, not one at a time.

For every PDF: page width (mm), font family (metric clones of Times, Helvetica
and Computer Modern are reported under one name), smallest text (pt, after
optional rescale to a print width), number of distinct non-grey fill and stroke
colours, and whether any Type 3 font is embedded. Then flags every file that
differs from the majority of the set in font family or width class, has text
below the minimum, or uses colour when most of the set is greyscale.

Usage:
  uv run --with pymupdf python set_check.py figures/*.pdf
  uv run --with pymupdf python set_check.py figures/*.pdf --widths 90,190 --min-pt 7
--widths lists the venue's canonical print widths in mm; each figure is assigned
to the nearest one and text is rescaled by (print width / page width) as
\\includegraphics[width=...] would. Exit 1 if anything is flagged.
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

import pymupdf as fitz

MM_PER_PT = 25.4 / 72
# Metric clones of one design count as one family: Times and its free substitutes,
# Helvetica/Arial and theirs, Computer Modern and Latin Modern.
FAMILY_ALIASES = {
    "Times": ["times", "nimbusrom", "termes", "liberationserif", "tinos", "txr", "txsys", "txmi", "ntx", "stix"],
    "Helvetica": ["helvetica", "arial", "nimbussan", "heros", "liberationsans", "arimo"],
    "ComputerModern": ["cmr", "cmmi", "cmsy", "cmex", "cmbx", "cmti", "lmroman", "lmmono", "lmsans"],
}


def canonical_family(name: str) -> str:
    key = name.lower().replace(" ", "")
    for canon, needles in FAMILY_ALIASES.items():
        if any(key.startswith(n) or n in key for n in needles):
            return canon
    return name


def is_grey(rgb: tuple[float, float, float] | None, tol: float = 0.04) -> bool:
    if rgb is None:
        return True
    r, g, b = rgb
    return max(r, g, b) - min(r, g, b) <= tol


def inspect(path: Path, widths: list[float] | None, min_pt: float) -> dict:
    doc = fitz.open(path)
    page = doc[0]
    page_w = page.rect.width * MM_PER_PT
    target = min(widths, key=lambda w: abs(w - page_w)) if widths else page_w
    scale = target / page_w
    sizes, families = [], Counter()
    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            for span in line["spans"]:
                if span["text"].strip():
                    sizes.append(span["size"] * scale)
                    fam = canonical_family(span["font"].split("+")[-1].split("-")[0].split(",")[0])
                    families[fam] += 1
    colours = set()
    for d in page.get_drawings():
        for key in ("fill", "color"):
            c = d.get(key)
            if c is not None and not is_grey(tuple(c)):
                colours.add(tuple(round(x, 2) for x in c))
    type3 = any("Type3" in f[2] for f in page.get_fonts())
    return {
        "file": path.name, "width_mm": page_w, "print_mm": target,
        "min_pt": min(sizes) if sizes else None,
        "family": families.most_common(1)[0][0] if families else "(no text)",
        "families": sorted(families), "n_colours": len(colours), "type3": type3,
        "raster": bool(page.get_images()),
    }


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    widths, min_pt = None, 7.0
    if "--widths" in argv:
        i = argv.index("--widths"); widths = [float(w) for w in argv[i + 1].split(",")]; del argv[i:i + 2]
    if "--min-pt" in argv:
        i = argv.index("--min-pt"); min_pt = float(argv[i + 1]); del argv[i:i + 2]
    rows = [inspect(Path(a), widths, min_pt) for a in argv]
    if not rows:
        return 2
    family_majority = Counter(r["family"] for r in rows).most_common(1)[0][0]
    grey_majority = sum(1 for r in rows if r["n_colours"] == 0) * 2 >= len(rows)
    print("| file | page mm | print mm | min pt | font | colours | flags |")
    print("|---|---|---|---|---|---|---|")
    flagged = 0
    for r in rows:
        flags = []
        if r["family"] != family_majority and r["family"] != "(no text)":
            flags.append(f"font differs from set ({family_majority})")
        if r["min_pt"] is not None and r["min_pt"] < min_pt:
            flags.append(f"text {r['min_pt']:.1f} pt < {min_pt:g}")
        if grey_majority and r["n_colours"] > 0:
            flags.append("colour in a greyscale set (Rule 0 exception recorded?)")
        if r["type3"]:
            flags.append("Type 3 font")
        if r["raster"]:
            flags.append("embedded raster")
        if widths and abs(r["print_mm"] - r["width_mm"]) / r["print_mm"] > 0.10:
            flags.append(f"designed at {r['width_mm']:.0f} mm, prints at {r['print_mm']:.0f} mm (scale {r['print_mm']/r['width_mm']:.2f})")
        flagged += bool(flags)
        mp = f"{r['min_pt']:.1f}" if r["min_pt"] is not None else "—"
        print(f"| {r['file']} | {r['width_mm']:.0f} | {r['print_mm']:.0f} | {mp} | {r['family']} | {r['n_colours']} | {'; '.join(flags)} |")
    print(f"\n{len(rows)} files, {flagged} flagged. Set majority: font {family_majority}, "
          f"{'greyscale' if grey_majority else 'colour'}.")
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
