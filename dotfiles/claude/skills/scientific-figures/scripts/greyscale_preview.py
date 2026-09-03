#!/usr/bin/env python3
"""Render a figure to greyscale so the colour-only encoding test can be done by eye.

Usage:
  uv run --with pillow python greyscale_preview.py fig.png [fig2.pdf ...] [--out DIR]
Writes <name>_grey.png into DIR (default: current working directory, never the
input folder, so a review run leaves the manuscript untouched). PDF input needs
`pdftoppm` (poppler) on PATH; PNG/JPG need only Pillow. The check is visual:
open the output and ask whether every series, class or region is still
identifiable without colour.
"""
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image


def to_grey(path: Path, out_dir: Path) -> Path:
    out = out_dir / (path.stem + "_grey.png")
    if path.suffix.lower() == ".pdf":
        if not shutil.which("pdftoppm"):
            raise SystemExit("pdftoppm not found; install poppler or pass a PNG")
        tmp = out_dir / (path.stem + "_tmp")
        subprocess.run(["pdftoppm", "-png", "-r", "200", "-singlefile", str(path), str(tmp)], check=True)
        src = tmp.with_suffix(".png")
        Image.open(src).convert("L").save(out)
        src.unlink()
    else:
        Image.open(path).convert("L").save(out)
    return out


if __name__ == "__main__":
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(2)
    out_dir = Path.cwd()
    if "--out" in args:
        i = args.index("--out")
        out_dir = Path(args[i + 1])
        args = args[:i] + args[i + 2:]
    out_dir.mkdir(parents=True, exist_ok=True)
    for arg in args:
        print(to_grey(Path(arg), out_dir))
