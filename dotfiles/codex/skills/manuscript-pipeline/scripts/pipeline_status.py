#!/usr/bin/env python3
"""Reconcile the manuscript tracker against the papers repo and git history.

The tracker is a snapshot maintained by hand; the repo is ground truth for
activity. This script reports where the two disagree, so the workbook becomes
derived rather than remembered.

Source-agnostic by design: --tracker accepts .xlsx or .csv, so a Google Sheets
CSV export drops in without code changes.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
import zipfile
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path

NS = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
STOPWORDS = {
    "the", "a", "an", "of", "for", "and", "to", "in", "on", "from", "with",
    "full", "title", "be", "defined", "paper", "using", "based", "approach",
}


@dataclass(frozen=True)
class Row:
    """One manuscript as recorded in the tracker."""

    index: int
    project: str
    title: str
    authors: str
    status: str
    venue: str


@dataclass(frozen=True)
class Match:
    """A tracker row resolved against the repo."""

    row: Row
    path: Path | None
    last_commit: date | None


def _shared_strings(zf: zipfile.ZipFile) -> list[str]:
    try:
        raw = zf.read("xl/sharedStrings.xml")
    except KeyError:
        return []
    return [
        "".join(t.text or "" for t in si.iter(NS + "t"))
        for si in ET.fromstring(raw)
    ]


def read_xlsx(path: Path) -> list[list[str]]:
    """Read the first worksheet as a list of row-value lists."""
    with zipfile.ZipFile(path) as zf:
        strings = _shared_strings(zf)
        sheet = ET.fromstring(zf.read("xl/worksheets/sheet1.xml"))
        rows: list[list[str]] = []
        for r in sheet.iter(NS + "row"):
            cells: list[str] = []
            for c in r.iter(NS + "c"):
                v = c.find(NS + "v")
                if v is None or v.text is None:
                    cells.append("")
                elif c.get("t") == "s":
                    cells.append(strings[int(v.text)])
                else:
                    cells.append(v.text)
            rows.append(cells)
    return rows


def read_csv(path: Path) -> list[list[str]]:
    with path.open(newline="", encoding="utf-8-sig") as fh:
        return [list(r) for r in csv.reader(fh)]


def read_tracker(path: Path) -> list[list[str]]:
    if path.suffix.lower() == ".xlsx":
        return read_xlsx(path)
    if path.suffix.lower() == ".csv":
        return read_csv(path)
    raise ValueError(f"unsupported tracker format: {path.suffix} (use .xlsx or .csv)")


def find_header(rows: list[list[str]]) -> int:
    """Locate the header row by its known column labels."""
    for i, r in enumerate(rows[:20]):
        low = [c.strip().lower() for c in r]
        if "title" in low and "status" in low:
            return i
    raise ValueError("no header row containing 'Title' and 'Status' found")


def parse_rows(rows: list[list[str]]) -> list[Row]:
    h = find_header(rows)
    cols = {c.strip().lower(): i for i, c in enumerate(rows[h]) if c.strip()}

    def cell(r: list[str], name: str) -> str:
        for key, idx in cols.items():
            if key.startswith(name):
                return r[idx].strip() if idx < len(r) else ""
        return ""

    out: list[Row] = []
    for i, r in enumerate(rows[h + 1:], start=h + 2):
        title = cell(r, "title")
        if not title:
            continue
        out.append(Row(i, cell(r, "project"), title, cell(r, "authors"),
                       cell(r, "status"), cell(r, "target")))
    return out


def tracker_updated(rows: list[list[str]]) -> date | None:
    """Extract the 'Last updated: <date>' banner if present."""
    for r in rows[:6]:
        for c in r:
            m = re.search(r"last updated:\s*(.+)", c, re.I)
            if not m:
                continue
            for fmt in ("%d %B %Y", "%d %b %Y", "%Y-%m-%d", "%d/%m/%Y"):
                try:
                    return datetime.strptime(m.group(1).strip(), fmt).date()
                except ValueError:
                    continue
    return None


def tokens(text: str) -> set[str]:
    words = re.findall(r"[a-z0-9]+", text.lower())
    return {w for w in words if len(w) > 2 and w not in STOPWORDS}


def candidate_dirs(papers: Path) -> list[Path]:
    out: list[Path] = []
    for sub in ("in-progress", "projects", "review", "published"):
        d = papers / sub
        if d.is_dir():
            out.extend(p for p in d.iterdir() if p.is_dir())
    return out


def load_aliases(path: Path) -> dict[str, str]:
    """Explicit row-title -> directory-name overrides.

    Fuzzy matching cannot resolve rows titled "[full title to be defined]", and
    a wrong match is worse than none. This file is the escape hatch: map once,
    correctly, and the guesswork stops.
    """
    if not path.exists():
        return {}
    try:
        with path.open(encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, json.JSONDecodeError):
        return {}
    return {str(k).strip().lower(): str(v) for k, v in data.items()
            if not str(k).startswith("_")}


def slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", text.lower())


def match_dir(row: Row, dirs: list[Path],
              aliases: dict[str, str] | None = None) -> Path | None:
    """Resolve a tracker row to a repo directory.

    Three rules, most reliable first. Directories here are named after the
    project (`ucd-camina`, `colourways_framework`, `aviation`), so slug
    containment beats token scoring, which mis-linked "Bikeable" to
    `perception-prompts` on the single shared word "perception".
    """
    aliases = aliases or {}
    for key in (row.title.strip().lower(), row.project.strip().lower()):
        target = aliases.get(key)
        if target:
            return next((d for d in dirs if d.name == target), None)

    # Rule 2: the project slug appears in the directory name.
    project = slug(row.project)
    if len(project) >= 4:
        hits = [d for d in dirs if project in slug(d.name)]
        if len(hits) == 1:
            return hits[0]
        if len(hits) > 1:
            exact = [d for d in dirs if slug(d.name) == project]
            if len(exact) == 1:
                return exact[0]
            return None

    # Rule 3: the directory's own tokens are nearly all present in the title.
    want = tokens(row.project) | tokens(row.title)
    if not want:
        return None
    scored = []
    for d in dirs:
        have = tokens(d.name.replace("_", " ").replace("-", " "))
        if not have:
            continue
        cover = len(want & have) / len(have)
        if cover >= 0.75:
            scored.append((cover, d))
    if len(scored) != 1:
        return None
    return scored[0][1]


def last_commit(repo: Path, path: Path) -> date | None:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "log", "-1", "--format=%ad", "--date=short",
             "--", str(path.relative_to(repo))],
            capture_output=True, text=True, timeout=15, check=False,
        )
    except (subprocess.SubprocessError, ValueError):
        return None
    text = out.stdout.strip()
    if not text:
        return None
    try:
        return datetime.strptime(text, "%Y-%m-%d").date()
    except ValueError:
        return None


def build(tracker: Path, papers: Path,
          aliases: dict[str, str] | None = None,
          ) -> tuple[list[Match], date | None, list[Path]]:
    raw = read_tracker(tracker)
    rows = parse_rows(raw)
    dirs = candidate_dirs(papers)
    matches = [
        Match(r, d, last_commit(papers, d) if d else None)
        for r in rows
        for d in (match_dir(r, dirs, aliases),)
    ]
    tracked = {m.path for m in matches if m.path}
    in_progress = papers / "in-progress"
    orphans = [
        p for p in sorted(in_progress.iterdir())
        if in_progress.is_dir() and p.is_dir() and p not in tracked
    ]
    return matches, tracker_updated(raw), orphans


def report(matches: list[Match], updated: date | None, orphans: list[Path],
           today: date) -> str:
    lines: list[str] = ["# Manuscript pipeline status", ""]

    if updated:
        age = (today - updated).days
        flag = "STALE" if age > 30 else "ok"
        lines += [f"Tracker last updated **{updated.isoformat()}** "
                  f"({age} days ago) — {flag}", ""]
    else:
        lines += ["Tracker carries no 'Last updated' banner.", ""]

    lines += ["| # | Project | Status | Repo | Last commit |",
              "|---|---|---|---|---|"]
    for m in matches:
        repo = m.path.name if m.path else "— unmatched"
        commit = m.last_commit.isoformat() if m.last_commit else "—"
        lines.append(
            f"| {m.row.index} | {m.row.project or '—'} | {m.row.status or '—'} "
            f"| {repo} | {commit} |"
        )

    drift = [
        m for m in matches
        if updated and m.last_commit and m.last_commit > updated
    ]
    if drift and updated:
        wholesale = len(drift) >= max(3, len(matches) // 2)
        if wholesale:
            # Flagging 11 of 15 rows is not a signal, it is the tracker's age
            # restated. Rank by recency and show only the live end.
            lines += ["", "## Most recent activity", "",
                      f"The tracker predates repo activity on {len(drift)} of "
                      f"{len(matches)} rows — the whole workbook is behind, so "
                      "per-row drift flags carry no signal. Ranked by last "
                      "commit, newest first:", ""]
            top = sorted(drift, key=lambda m: m.last_commit, reverse=True)[:6]
        else:
            lines += ["", "## Moved since the tracker was updated", "",
                      "The repo has newer activity than the workbook records. "
                      "Verify these statuses first.", ""]
            top = drift
        lines += [f"- **{m.row.project or '—'} · {m.row.title[:34]}** — "
                  f"`{m.path.name}` commit {m.last_commit.isoformat()}, "
                  f"tracker says *{m.row.status or 'no status'}*" for m in top]

    unmatched = [m for m in matches if not m.path]
    if unmatched:
        lines += ["", "## Tracker rows with no repo directory", "",
                  "Either early-stage work with nothing on disk, or a naming "
                  "mismatch this script could not resolve.", ""]
        lines += [f"- {m.row.project or '—'}: {m.row.title[:70]}"
                  for m in unmatched]

    if orphans:
        lines += ["", "## Work on disk with no tracker row", ""]
        lines += [f"- `in-progress/{p.name}`" for p in orphans]

    lines += ["", "---", "",
              "Read-only. Nothing is written back to the tracker; the workbook "
              "is co-author-visible and edits are yours to make."]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--tracker", type=Path,
                    default=Path.home() / "repos/applications/Professor/paper_tracker.xlsx",
                    help=".xlsx or .csv tracker (a Google Sheets CSV export works)")
    ap.add_argument("--papers", type=Path, default=Path.home() / "repos/papers")
    ap.add_argument("--aliases", type=Path,
                    default=Path(__file__).resolve().parent.parent / "aliases.json",
                    help="row-title/project -> directory-name overrides")
    ap.add_argument("--today", type=date.fromisoformat, default=date.today(),
                    help="override today's date (testing)")
    args = ap.parse_args()

    if not args.tracker.exists():
        print(f"error: tracker not found: {args.tracker}", file=sys.stderr)
        return 1
    if not args.papers.is_dir():
        print(f"error: papers repo not found: {args.papers}", file=sys.stderr)
        return 1

    try:
        matches, updated, orphans = build(args.tracker, args.papers,
                                          load_aliases(args.aliases))
    except (ValueError, zipfile.BadZipFile) as exc:
        print(f"error: could not read tracker: {exc}", file=sys.stderr)
        return 1

    print(report(matches, updated, orphans, args.today))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
