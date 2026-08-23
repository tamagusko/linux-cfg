#!/usr/bin/env python3
"""Find verbatim and near-verbatim text overlap between a manuscript and a corpus.

This is the mechanical half of a pre-submission integrity audit. It answers one
question exactly: which runs of words in the manuscript also appear in documents
the author already has. Reworded duplication is invisible to it by construction,
so a clean run here is not a clean bill of health -- it narrows what a human
still has to read for.

The method is word-level shingling. Text is normalised (lowercased, punctuation
dropped, whitespace collapsed) and cut into overlapping n-word windows. Windows
present in both documents are matched, then adjacent matches are merged back
into runs, so a 40-word copied passage reports as one finding rather than 33.

Usage:
    overlap.py MANUSCRIPT --against FILE_OR_DIR [FILE_OR_DIR ...] [-n 8] [--min-run 12]
"""

from __future__ import annotations

import argparse
import json
import logging
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path

logger = logging.getLogger(__name__)

TEXT_SUFFIXES = {".txt", ".md", ".tex", ".bbl"}
PDF_SUFFIXES = {".pdf"}

# 8 words is short enough to catch a recycled clause and long enough that
# ordinary academic phrasing ("the results show that the proposed") does not
# match by coincidence. Runs are reported only at --min-run words or longer.
DEFAULT_SHINGLE = 8
DEFAULT_MIN_RUN = 12


@dataclass(frozen=True)
class Run:
    """One contiguous overlapping passage."""

    source: str
    words: int
    manuscript_text: str
    source_text: str
    manuscript_word_index: int


def extract(path: Path) -> str:
    """Return plain text for a manuscript or corpus file."""
    suffix = path.suffix.lower()
    if suffix in PDF_SUFFIXES:
        try:
            out = subprocess.run(
                ["pdftotext", "-q", str(path), "-"],
                capture_output=True, text=True, timeout=180, check=True,
            )
            return out.stdout
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, FileNotFoundError) as exc:
            logger.warning("could not extract %s: %s", path.name, exc)
            return ""
    if suffix in TEXT_SUFFIXES:
        text = path.read_text(errors="replace")
        if suffix in {".tex", ".bbl"}:
            # Strip comments and command names; keep the prose inside braces.
            text = re.sub(r"(?<!\\)%.*", " ", text)
            text = re.sub(r"\\[a-zA-Z@]+\s*(\[[^\]]*\])?", " ", text)
            text = text.replace("{", " ").replace("}", " ")
        return text
    return ""


def normalise(text: str) -> list[str]:
    """Lowercase, drop punctuation and digits-only tokens, split into words."""
    text = re.sub(r"[^\w\s]", " ", text.lower())
    return [w for w in text.split() if not w.isdigit()]


def shingles(words: list[str], n: int) -> dict[tuple[str, ...], list[int]]:
    """Map each n-word window to every position where it occurs."""
    index: dict[tuple[str, ...], list[int]] = {}
    for i in range(len(words) - n + 1):
        index.setdefault(tuple(words[i:i + n]), []).append(i)
    return index


def find_runs(ms_words: list[str], src_words: list[str], source: str,
              n: int, min_run: int) -> list[Run]:
    """Return merged overlapping runs between one manuscript and one source."""
    src_index = shingles(src_words, n)
    ms_index = shingles(ms_words, n)

    hits = sorted(i for sh, positions in ms_index.items() if sh in src_index for i in positions)
    if not hits:
        return []

    runs: list[Run] = []
    start = prev = hits[0]
    for i in hits[1:] + [None]:  # sentinel closes the final run
        if i is not None and i == prev + 1:
            prev = i
            continue
        length = prev - start + n
        if length >= min_run:
            ms_text = " ".join(ms_words[start:start + length])
            src_pos = src_index[tuple(ms_words[start:start + n])][0]
            src_text = " ".join(src_words[src_pos:src_pos + length])
            runs.append(Run(source, length, ms_text, src_text, start))
        if i is not None:
            start = prev = i
    return runs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manuscript", type=Path)
    parser.add_argument("--against", type=Path, nargs="+", required=True,
                        help="files or directories to compare against")
    parser.add_argument("-n", "--shingle", type=int, default=DEFAULT_SHINGLE)
    parser.add_argument("--min-run", type=int, default=DEFAULT_MIN_RUN)
    parser.add_argument("--json", type=Path, help="also write findings as JSON")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s", stream=sys.stderr)

    ms_words = normalise(extract(args.manuscript))
    if len(ms_words) < args.shingle:
        logger.error("manuscript yielded %d words -- extraction failed?", len(ms_words))
        return 1
    logger.info("manuscript: %s (%d words)", args.manuscript.name, len(ms_words))

    targets: list[Path] = []
    for t in args.against:
        targets.extend(sorted(p for p in t.rglob("*") if p.is_file()) if t.is_dir() else [t])
    targets = [t for t in targets
               if t.suffix.lower() in PDF_SUFFIXES | TEXT_SUFFIXES
               and t.resolve() != args.manuscript.resolve()]

    all_runs: list[Run] = []
    skipped: list[str] = []
    for t in targets:
        src_words = normalise(extract(t))
        if len(src_words) < args.shingle:
            skipped.append(t.name)
            continue
        all_runs.extend(find_runs(ms_words, src_words, str(t), args.shingle, args.min_run))

    all_runs.sort(key=lambda r: -r.words)
    covered = {i for r in all_runs for i in range(r.manuscript_word_index,
                                                  r.manuscript_word_index + r.words)}

    print(f"\ncompared against {len(targets)} documents; {len(all_runs)} runs "
          f">= {args.min_run} words; {len(covered) / len(ms_words):.1%} of the "
          f"manuscript sits inside at least one run\n")
    if skipped:
        print(f"NOT COMPARED (no text extracted -- likely scanned): {', '.join(skipped)}\n")

    for r in all_runs:
        print(f"--- {r.words} words | {Path(r.source).name}")
        print(f"    manuscript: {r.manuscript_text[:300]}")
        print(f"    source    : {r.source_text[:300]}\n")

    if args.json:
        args.json.write_text(json.dumps([r.__dict__ for r in all_runs], indent=1))
        logger.info("wrote %s", args.json)

    # A clean mechanical run says nothing about reworded reuse.
    print("Mechanical matching only. Reworded duplication does not appear here "
          "and still needs a human read.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
