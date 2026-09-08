#!/usr/bin/env python3
"""Rule 3 gate: render a figure as it will be photocopied, in greyscale at print size.

Usage:
  uv run --with pillow python greyscale_preview.py fig.pdf [fig2.png ...] --out DIR [--width-mm 90] [--dpi 300]
Writes <name>_grey.png into DIR (default: current working directory, never the
input folder, so a review run leaves the manuscript untouched). With --width-mm
the output is resampled so that it is exactly that wide at --dpi (default 300),
which is what the reader's printer produces; without it the file renders at its
own size. PDF input needs `pdftoppm` (poppler) on PATH.

The check is visual and binary: open the output and ask whether every series,
class or region is still identifiable and every label legible. Pair it with
palette_check.py, which measures the lightness gaps that this image shows.
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

MM_PER_IN = 25.4


def to_grey(path: Path, out_dir: Path, width_mm: float | None, dpi: int) -> Path:
    out = out_dir / (path.stem + "_grey.png")
    if path.suffix.lower() == ".pdf":
        if not shutil.which("pdftoppm"):
            raise SystemExit("pdftoppm not found; install poppler or pass a PNG")
        tmp = out_dir / (path.stem + "_tmp")
        subprocess.run(["pdftoppm", "-png", "-r", str(dpi), "-singlefile", str(path), str(tmp)], check=True)
        src = tmp.with_suffix(".png")
        img = Image.open(src).convert("L")
        src.unlink()
    else:
        img = Image.open(path).convert("L")
    if width_mm:
        target_w = round(width_mm / MM_PER_IN * dpi)
        target_h = round(img.height * target_w / img.width)
        img = img.resize((target_w, target_h), Image.LANCZOS)
    img.save(out, dpi=(dpi, dpi))
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    out_dir, width_mm, dpi = Path.cwd(), None, 300
    if "--out" in args:
        i = args.index("--out"); out_dir = Path(args[i + 1]); del args[i:i + 2]
    if "--width-mm" in args:
        i = args.index("--width-mm"); width_mm = float(args[i + 1]); del args[i:i + 2]
    if "--dpi" in args:
        i = args.index("--dpi"); dpi = int(args[i + 1]); del args[i:i + 2]
    out_dir.mkdir(parents=True, exist_ok=True)
    for arg in args:
        print(to_grey(Path(arg), out_dir, width_mm, dpi))
