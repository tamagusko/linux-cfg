#!/usr/bin/env python3
"""Find claims in Quarto lecture decks that rot with time.

`lecture-gate` checks a deck's structure. This checks its truth decay: model
names, prices, context windows, benchmark figures, dated statements and links
that were accurate when written and quietly stop being so.

It flags candidates for human re-verification. It never decides what is true.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# Each rule: (category, compiled pattern, why it rots).
RULES: list[tuple[str, re.Pattern[str], str]] = [
    ("model", re.compile(
        r"\b(GPT[- ]?[0-9o][\w.\-]*|o[1-9]\b|Claude\s+(?:Opus|Sonnet|Haiku|Fable)?\s*[0-9][\w.\-]*"
        r"|Gemini\s*[0-9][\w.\-]*|Llama\s*[0-9][\w.\-]*|Mistral\s*\w+|DeepSeek[\w.\-]*"
        r"|Qwen[\w.\-]*|Grok[\w.\-]*)", re.I),
     "model generations are superseded every few months"),
    ("price", re.compile(
        r"(US\$|\$|€|£)\s?[0-9][0-9.,]*\s*(?:/|per\s)?\s*(?:M|million|1M|k|1k)?\s*tokens?"
        r"|\$[0-9][0-9.,]*\s*(?:/|per)\s*(?:month|mo|user|seat)", re.I),
     "list prices change without notice"),
    ("context", re.compile(
        r"\b[0-9]{1,4}\s?(?:k|K|M)\s?(?:token|context)|\bcontext window of [0-9][\w,.]*", re.I),
     "context limits grow"),
    ("benchmark", re.compile(
        r"\b(?:state[- ]of[- ]the[- ]art|SOTA|accuracy|F1|mAP|BLEU|MMLU|HumanEval|"
        r"top[- ]1|top[- ]5)\b[^.\n]{0,40}?\b[0-9]{1,3}(?:\.[0-9]+)?\s?%", re.I),
     "leaderboards move"),
    ("dated", re.compile(
        r"\b(?:as of|currently|at present|today|right now|the latest|newest|"
        r"most recent|state of the art in)\b", re.I),
     "undated present-tense claim"),
    ("year", re.compile(r"\b(?:in|since|by)\s+20(?:1[0-9]|2[0-9])\b"),
     "year reference may need advancing"),
    ("link", re.compile(r"https?://[^\s)\">]+"),
     "link rot"),
]

SKIP_DIRS = {"old", "_trash_2025", "_review", ".venv", ".git", "img", "_site"}


@dataclass(frozen=True)
class Hit:
    path: Path
    line: int
    category: str
    text: str


def strip_code(lines: list[str]) -> list[str]:
    """Blank out fenced code blocks: pinned versions there are correct, not rot."""
    out, in_fence = [], False
    for ln in lines:
        if ln.lstrip().startswith("```"):
            in_fence = not in_fence
            out.append("")
            continue
        out.append("" if in_fence else ln)
    return out


def sweep(path: Path) -> list[Hit]:
    try:
        raw = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    hits: list[Hit] = []
    for i, line in enumerate(strip_code(raw), start=1):
        if not line.strip():
            continue
        for cat, pat, _why in RULES:
            for m in pat.finditer(line):
                frag = m.group(0).strip()
                if len(frag) < 2:
                    continue
                hits.append(Hit(path, i, cat, frag))
    return hits


def taught_classes(root: Path) -> set[int]:
    """Class numbers the tracker marks taught/closed.

    Those decks are frozen by course rule and never retrofitted, so flagging
    stale claims in them is noise, not a finding.
    """
    tracker = root / "tracker.md"
    if not tracker.exists():
        return set()
    out: set[int] = set()
    for line in tracker.read_text(encoding="utf-8", errors="replace").splitlines():
        m = re.match(r"\|\s*(\d+)\s*\|\s*([^|]+)\|", line)
        if m and "taught" in m.group(2).lower():
            out.add(int(m.group(1)))
    return out


def decks(root: Path, skip: set[int] | None = None) -> list[Path]:
    skip = skip or set()
    found = []
    for p in sorted(root.rglob("*.qmd")):
        if any(part in SKIP_DIRS for part in p.parts):
            continue
        m = re.search(r"class(\d+)", p.stem)
        if m and int(m.group(1)) in skip:
            continue
        found.append(p)
    return found


def report(hits: list[Hit], root: Path, files: int, only: set[str]) -> str:
    why = {c: w for c, _p, w in RULES}
    lines = [f"# Lecture currency sweep", "",
             f"{files} deck(s) under `{root}`; "
             f"{len(hits)} claim(s) to re-verify.", ""]
    if not hits:
        lines.append("Nothing flagged.")
        return "\n".join(lines)

    by_cat: dict[str, list[Hit]] = {}
    for h in hits:
        if only and h.category not in only:
            continue
        by_cat.setdefault(h.category, []).append(h)

    for cat, _pat, _w in RULES:
        group = by_cat.get(cat)
        if not group:
            continue
        seen: set[tuple[str, int]] = set()
        lines += ["", f"## {cat} — {why[cat]}", ""]
        for h in group:
            key = (str(h.path), h.line)
            if key in seen:
                continue
            seen.add(key)
            rel = h.path.relative_to(root)
            lines.append(f"- `{rel}:{h.line}` — {h.text}")
    lines += ["", "---", "",
              "Candidates only. Each needs a human check against a primary "
              "source; this script cannot know what is currently true."]
    return "\n".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("root", nargs="?", type=Path,
                    default=Path.home() / "repos/classes/ime/ai_applied_transport_2026",
                    help="course root to sweep")
    ap.add_argument("--only", default="",
                    help="comma-separated categories to report")
    ap.add_argument("--include-taught", action="store_true",
                    help="also sweep decks the tracker marks taught/closed "
                         "(frozen by course rule, so excluded by default)")
    args = ap.parse_args()

    if not args.root.is_dir():
        print(f"error: not a directory: {args.root}", file=sys.stderr)
        return 1

    skip = set() if args.include_taught else taught_classes(args.root)
    files = decks(args.root, skip)
    if skip:
        print(f"<!-- skipped taught/closed: {sorted(skip)} -->")
    hits = [h for f in files for h in sweep(f)]
    only = {c.strip() for c in args.only.split(",") if c.strip()}
    print(report(hits, args.root, len(files), only))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
