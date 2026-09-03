#!/usr/bin/env python3
"""Check a CSV, markdown or LaTeX (tabular/booktabs) table for publication faults.

Reports:
  - numeric columns whose header carries no unit in ( ) or [ ] and is not a
    known dimensionless quantity (R2, n, p, AUC, ...)
  - numeric columns with inconsistent decimal precision
  - columns where every cell is identical (move to caption or remove)
  - cells that contain a unit that belongs in the header
  - LaTeX only: \\hline or vertical rules (booktabs style expected)

Usage:
  python table_check.py table.csv
  python table_check.py table.md
  python table_check.py results/tables/tab_ablation.tex
  python table_check.py table.tex --unitless "Tuned,Model"   # extra columns to skip
Exit code 0 if no faults, 1 otherwise.

A cell such as "0.756 [0.727, 0.786]" is read as 0.756 with an interval;
the precision check uses the leading number only.
"""
from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

NUM = re.compile(r"^[-+\u2212]?\d[\d,]*\.?\d*(e[-+]?\d+)?$", re.I)
LEAD_NUM = re.compile(r"^[-+\u2212]?\d[\d,]*\.?\d*(?:e[-+]?\d+)?", re.I)
UNIT_IN_CELL = re.compile(r"\d\s*(%|\\%|km/h|m/s|m/km|km|mm|cm|m|s|ms|min|h|kg|t|°C|px|fps|dB|MPa|kPa|Hz)\b")
DIMENSIONLESS = re.compile(
    r"^([nN](_\w+)?|count|rank|index|ratio|share|fraction|R\^?2\S*|R²\S*|r|rho|p|p-?value|q|AUC|F1|IoU|mAP|"
    r"precision|recall|accuracy|acc|PCR\w*|corr\w*|coefficient|coef|beta|weight|score|z|t|F|chi2|"
    r"df|\\?alpha|\\?beta|\\?gamma|\\?lambda|\\?epsilon|fold|seed|trials?|depth|estimators|leaves|"
    r"year|id|no\.?|k|h|horizon)$",
    re.I,
)


def read_markdown(path: Path) -> list[list[str]]:
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if "|" not in line:
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if all(re.fullmatch(r":?-{2,}:?", c) for c in cells):
            continue
        rows.append(cells)
    return rows


def latex_clean(cell: str) -> str:
    """Reduce a LaTeX cell to its visible text: '\\textbf{0.85 {\\scriptsize [..]}}' -> '0.85 [..]'."""
    cell = re.sub(r"\\multicolumn\{\d+\}\{[^}]*\}\{", "{", cell)
    for _ in range(4):
        cell = re.sub(r"\\(textbf|textit|emph|mathrm|mathbf|text|scriptsize|footnotesize|small|tiny|num|SI)\s*\{([^{}]*)\}", r"\2", cell)
        cell = re.sub(r"\{\\(scriptsize|footnotesize|small|tiny|bfseries|itshape)\s+([^{}]*)\}", r"\2", cell)
    cell = re.sub(r"\\(quad|qquad|,|;|!|hspace\{[^}]*\})", " ", cell)
    cell = cell.replace("\\%", "%").replace("\\&", "&").replace("$", "").replace("---", "—").replace("--", "–")
    cell = re.sub(r"[{}]", "", cell)
    return re.sub(r"\s+", " ", cell).strip()


def read_latex(path: Path) -> tuple[list[list[str]], list[str]]:
    text = re.sub(r"(?<!\\)%.*", "", path.read_text(encoding="utf-8"))
    notes = []
    if re.search(r"\\hline", text):
        notes.append("uses \\hline; booktabs rules (\\toprule/\\midrule/\\bottomrule) expected")
    spec = re.search(r"\\begin\{tabular\*?\}(?:\{[^}]*\})?\{([^}]*)\}", text)
    if spec and "|" in spec.group(1):
        notes.append("vertical rules in column spec; remove them")
    body = text
    m = re.search(r"\\begin\{tabular\*?\}(?:\{[^}]*\})?\{[^}]*\}(.*?)\\end\{tabular\*?\}", text, re.S)
    if m:
        body = m.group(1)
    body = re.sub(r"\\(toprule|midrule|bottomrule|hline|cmidrule(\([^)]*\))?\{[^}]*\}|addlinespace(\[[^\]]*\])?)", "", body)
    rows = []
    for raw in re.split(r"\\\\", body):
        if "&" not in raw and not raw.strip():
            continue
        cells: list[str] = []
        for c in raw.split("&"):
            span = re.match(r"\s*\\multicolumn\{(\d+)\}", c)
            cells.extend([latex_clean(c)] * (int(span.group(1)) if span else 1))
        if any(cells):
            rows.append(cells)
    return rows, notes


def read_table(path: Path) -> tuple[list[list[str]], list[str]]:
    suffix = path.suffix.lower()
    if suffix == ".md":
        return read_markdown(path), []
    if suffix == ".tex":
        return read_latex(path)
    with path.open(newline="", encoding="utf-8") as fh:
        return [row for row in csv.reader(fh)], []


def leading_number(cell: str) -> str | None:
    m = LEAD_NUM.match(cell.strip())
    return m.group(0) if m else None


def decimals(value: str) -> int:
    v = value.strip().replace(",", "")
    if "." in v and "e" not in v.lower():
        return len(v.split(".")[1])
    return 0


def header_has_unit(name: str) -> bool:
    return bool(re.search(r"\(.*\)|\[.*\]", name))


def split_header(rows: list[list[str]]) -> tuple[list[str], list[list[str]]]:
    """Merge leading non-numeric rows (group header + sub-header) into one header."""
    ncols = max(len(r) for r in rows)
    n_header = 1
    while n_header < min(3, len(rows) - 1):
        nxt = rows[n_header]
        numeric = sum(1 for c in nxt if leading_number(c or ""))
        if numeric >= 0.5 * max(1, len([c for c in nxt if c.strip()])):
            break
        n_header += 1
    header = []
    for j in range(ncols):
        parts = [r[j].strip() for r in rows[:n_header] if j < len(r) and r[j].strip()]
        header.append(" ".join(dict.fromkeys(parts)))
    return header, rows[n_header:]


def check(rows: list[list[str]], unitless: set[str]) -> list[str]:
    header, body = split_header(rows)
    faults: list[str] = []
    ncols = max(len(r) for r in rows)
    for j in range(ncols):
        name = header[j].strip() if j < len(header) else f"col{j}"
        cells = [r[j].strip() for r in body if j < len(r) and r[j].strip() not in ("", "—", "–", "-", "n/a", "NA")]
        if not cells:
            continue
        leads = [leading_number(c) for c in cells]
        numeric = [n for n in leads if n]
        if len(numeric) >= max(2, int(0.8 * len(cells))):
            bare = re.sub(r"\(.*?\)|\[.*?\]", "", name).strip()
            if not header_has_unit(name) and name not in unitless and not any(DIMENSIONLESS.match(tok) for tok in bare.split()):
                faults.append(f"Column '{name}': numeric but header has no unit in parentheses (add one, or confirm it is dimensionless)")
            precs = {decimals(n) for n in numeric}
            if len(precs) > 1:
                faults.append(f"Column '{name}': mixed decimal precision {sorted(precs)}")
        if len(set(cells)) == 1 and len(cells) > 1:
            faults.append(f"Column '{name}': every cell is '{cells[0]}'; move to caption or remove")
        for c in cells:
            if UNIT_IN_CELL.search(c):
                faults.append(f"Column '{name}': unit inside cell '{c}'; move unit to header")
                break
    return faults


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    unitless: set[str] = set()
    if "--unitless" in argv:
        unitless = {s.strip() for s in argv[argv.index("--unitless") + 1].split(",")}
    path = Path(argv[1])
    rows, notes = read_table(path)
    if len(rows) < 2:
        print("Table needs a header and at least one data row.")
        return 1
    faults = notes + check(rows, unitless)
    if faults:
        print("\n".join(faults))
        return 1
    print("No table faults found.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
