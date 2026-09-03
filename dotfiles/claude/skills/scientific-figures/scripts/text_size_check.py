#!/usr/bin/env python3
"""Report the smallest and largest text in a PDF figure at its intended print width.

Usage:
  uv run --with pymupdf python text_size_check.py fig.pdf [fig2.pdf ...] [--width-mm 90] [--min-pt 7]
Without --width-mm the PDF's own page width is taken as the print width. With it,
font sizes are scaled by (print width / page width), which is what happens when
\\includegraphics[width=...] rescales the figure. Exit 1 if any text falls below
--min-pt (default 7). Type 3 or unembedded fonts are reported because Elsevier
preflight rejects them.
"""
import sys
from pathlib import Path

import pymupdf as fitz

MM_PER_PT = 25.4 / 72


def check(path: Path, width_mm: float | None, min_pt: float) -> bool:
    doc = fitz.open(path)
    page = doc[0]
    page_w_mm = page.rect.width * MM_PER_PT
    scale = (width_mm / page_w_mm) if width_mm else 1.0
    sizes = []
    for block in page.get_text("dict")["blocks"]:
        for line in block.get("lines", []):
            for span in line["spans"]:
                if span["text"].strip():
                    sizes.append((span["size"] * scale, span["text"].strip()[:30], span["font"]))
    fonts = {f[3]: f[2] for f in page.get_fonts()}  # name -> type
    bad_fonts = [n for n, t in fonts.items() if "Type3" in t]
    if not sizes:
        print(f"{path.name}: no text found (outlined fonts or empty)")
        return True
    smallest = min(sizes)
    largest = max(sizes)
    print(f"{path.name}: page {page_w_mm:.0f} mm wide, printed at {width_mm or page_w_mm:.0f} mm "
          f"(scale {scale:.2f}); text {smallest[0]:.1f} to {largest[0]:.1f} pt; "
          f"smallest: '{smallest[1]}' [{smallest[2]}]")
    if bad_fonts:
        print(f"  Type 3 fonts present: {', '.join(bad_fonts)} (set pdf.fonttype 42)")
    ok = smallest[0] >= min_pt and not bad_fonts
    if smallest[0] < min_pt:
        below = sorted({(round(s, 1), t) for s, t, _ in sizes if s < min_pt})
        print(f"  below {min_pt} pt: " + "; ".join(f"{s} pt '{t}'" for s, t in below[:8]))
    return ok


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    width = None
    min_pt = 7.0
    if "--width-mm" in args:
        i = args.index("--width-mm"); width = float(args[i + 1]); del args[i:i + 2]
    if "--min-pt" in args:
        i = args.index("--min-pt"); min_pt = float(args[i + 1]); del args[i:i + 2]
    ok = all([check(Path(a), width, min_pt) for a in args])
    sys.exit(0 if ok else 1)
