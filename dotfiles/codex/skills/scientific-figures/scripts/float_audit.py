#!/usr/bin/env python3
"""Inventory the floats of a LaTeX manuscript and flag narrative faults.

Walks main.tex (following \\input and \\include), lists every figure, table,
algorithm and numbered equation in reading order, and reports:

  - floats never referenced in the text (\\ref, \\cref, \\autoref, \\eqref ...)
  - floats that appear in the source before their first reference
  - floats without a \\label, and references to labels that do not exist
  - numbered equations that are never referenced
  - captions with more than three sentences, or that are titles (no verb, < 6 words)
  - em-dashes ("---" or U+2014) in captions
  - raster graphics (png/jpg) where vector (pdf/eps/svg) is expected
  - graphics files that do not exist, and files in the graphics directory
    that no \\includegraphics uses
  - \\resizebox around tables (type size then varies from table to table)
  - graphics file names whose number disagrees with the printed figure number

Usage:
  python float_audit.py main.tex            # markdown report on stdout
  python float_audit.py main.tex --json     # machine-readable
Exit code 0 when nothing is flagged, 1 otherwise. Section numbers are
approximate (counted from \\section, \\subsection in source order).
"""
from __future__ import annotations

import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

FLOAT_ENVS = {
    "figure": "Fig", "figure*": "Fig", "sidewaysfigure": "Fig",
    "table": "Tab", "table*": "Tab", "sidewaystable": "Tab",
    "algorithm": "Alg", "algorithm*": "Alg", "algorithm2e": "Alg",
    "equation": "Eq", "align": "Eq", "gather": "Eq", "multline": "Eq",
}
RASTER = {".png", ".jpg", ".jpeg", ".tif", ".tiff", ".bmp"}
VECTOR = {".pdf", ".eps", ".svg", ".pgf"}
REF_CMDS = r"(?:ref|eqref|autoref|cref|Cref|figref|tabref|pageref|nameref)"
TITLE_CAPTION_WORDS = 6


@dataclass
class Float:
    kind: str
    env: str
    line: int
    section: str
    labels: list[str] = field(default_factory=list)
    caption: str = ""
    graphics: list[str] = field(default_factory=list)
    resizebox: bool = False
    number: int = 0
    first_ref_line: int | None = None
    n_refs: int = 0
    flags: list[str] = field(default_factory=list)


def strip_comments(text: str) -> str:
    return re.sub(r"(?<!\\)%.*", "", text)


def inline_inputs(path: Path, seen: set[Path] | None = None) -> str:
    """Return the file text with \\input/\\include files spliced in (once each)."""
    seen = seen or set()
    if path in seen or not path.exists():
        return ""
    seen.add(path)
    text = strip_comments(path.read_text(encoding="utf-8", errors="replace"))

    def repl(match: re.Match) -> str:
        target = match.group(2)
        cand = path.parent / target
        if cand.suffix == "":
            cand = cand.with_suffix(".tex")
        return inline_inputs(cand, seen) if cand.exists() else match.group(0)

    return re.sub(r"\\(input|include)\{([^}]+)\}", repl, text)


def balanced_arg(text: str, start: int) -> tuple[str, int]:
    """Return the {...} argument starting at text[start] == '{' and the end index."""
    depth, i = 0, start
    while i < len(text):
        if text[i] == "{":
            depth += 1
        elif text[i] == "}":
            depth -= 1
            if depth == 0:
                return text[start + 1:i], i + 1
        i += 1
    return text[start + 1:], len(text)


def caption_text(body: str) -> str:
    m = re.search(r"\\caption(?:\[[^\]]*\])?\s*\{", body)
    if not m:
        return ""
    cap, _ = balanced_arg(body, m.end() - 1)
    cap = re.sub(r"\\label\{[^}]*\}", "", cap).replace("{,}", ",")
    cap = re.sub(r"\\(text[a-z]{2}|emph|mathrm|mathbf)\{([^}]*)\}", r"\2", cap)
    cap = re.sub(r"\\[A-Za-z]+\*?", " ", cap)
    cap = re.sub(r"[{}$~]", " ", cap)
    return re.sub(r"\s+", " ", cap).strip()


def sentences(text: str) -> int:
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z(])", text.strip())
    return len([p for p in parts if p.strip()])


def line_of(text: str, pos: int) -> int:
    return text.count("\n", 0, pos) + 1


def collect_floats(text: str) -> list[Float]:
    floats: list[Float] = []
    counters: dict[str, int] = {}
    sections: list[tuple[int, str]] = []
    sec_no = [0, 0]
    for m in re.finditer(r"\\(section|subsection)\*?\{", text):
        if m.group(1) == "section":
            sec_no[0] += 1
            sec_no[1] = 0
            sections.append((m.start(), f"{sec_no[0]}"))
        else:
            sec_no[1] += 1
            sections.append((m.start(), f"{sec_no[0]}.{sec_no[1]}"))
    if re.search(r"\\appendix", text):
        sections.append((re.search(r"\\appendix", text).start(), "App"))

    def section_at(pos: int) -> str:
        current = "front"
        for start, name in sections:
            if start <= pos:
                current = name
        return current

    env_re = re.compile(r"\\begin\{(" + "|".join(re.escape(e) for e in FLOAT_ENVS) + r")\}")
    for m in env_re.finditer(text):
        env = m.group(1)
        end = re.search(r"\\end\{" + re.escape(env) + r"\}", text[m.end():])
        body = text[m.end(): m.end() + (end.start() if end else 0)]
        kind = FLOAT_ENVS[env]
        counters[kind] = counters.get(kind, 0) + 1
        fl = Float(kind=kind, env=env, line=line_of(text, m.start()), section=section_at(m.start()), number=counters[kind])
        fl.labels = re.findall(r"\\label\{([^}]+)\}", body)
        fl.caption = caption_text(body)
        fl.graphics = [g.split(",")[0].strip() for g in re.findall(r"\\includegraphics(?:\[[^\]]*\])?\{([^}]+)\}", body)]
        fl.resizebox = bool(re.search(r"\\resizebox", body)) and kind == "Tab"
        floats.append(fl)
    return floats


def collect_refs(text: str) -> dict[str, list[int]]:
    refs: dict[str, list[int]] = {}
    for m in re.finditer(r"\\" + REF_CMDS + r"\*?\{([^}]+)\}", text):
        for label in m.group(1).split(","):
            refs.setdefault(label.strip(), []).append(line_of(text, m.start()))
    return refs


def graphics_dirs(text: str, root: Path) -> list[Path]:
    dirs = [root]
    m = re.search(r"\\graphicspath\{((?:\{[^}]*\})+)\}", text)
    if m:
        dirs += [root / d for d in re.findall(r"\{([^}]*)\}", m.group(1))]
    return dirs


def resolve_graphic(name: str, dirs: list[Path]) -> Path | None:
    for d in dirs:
        p = d / name
        if p.exists():
            return p
        for ext in VECTOR | RASTER:
            if p.with_suffix(ext).exists():
                return p.with_suffix(ext)
    return None


def audit(main: Path) -> tuple[list[Float], list[str]]:
    text = inline_inputs(main)
    floats = collect_floats(text)
    refs = collect_refs(text)
    dirs = graphics_dirs(text, main.parent)
    all_labels = {lab for fl in floats for lab in fl.labels}
    global_flags: list[str] = []
    used_graphics: set[Path] = set()

    for fl in floats:
        if not fl.labels:
            fl.flags.append("no \\label")
        ref_lines = sorted(ln for lab in fl.labels for ln in refs.get(lab, []))
        fl.n_refs = len(ref_lines)
        if fl.labels and not ref_lines:
            fl.flags.append("never referenced" + (" (numbered equation)" if fl.kind == "Eq" else ""))
        elif ref_lines:
            fl.first_ref_line = ref_lines[0]
            if ref_lines[0] > fl.line and fl.kind != "Eq":
                fl.flags.append(f"appears (line {fl.line}) before first reference (line {ref_lines[0]})")
        if fl.kind in ("Fig", "Tab", "Alg"):
            if not fl.caption:
                fl.flags.append("no caption")
            else:
                n = sentences(fl.caption)
                if n > 3:
                    fl.flags.append(f"caption has {n} sentences (max 3)")
                if len(fl.caption.split()) < TITLE_CAPTION_WORDS and fl.kind != "Alg":
                    fl.flags.append("caption is a title, not an explanation")
                if "---" in fl.caption or "\u2014" in fl.caption:
                    fl.flags.append("em-dash in caption")
        if fl.resizebox:
            fl.flags.append("\\resizebox: type size will differ from other tables")
        for g in fl.graphics:
            p = resolve_graphic(g, dirs)
            if p is None:
                fl.flags.append(f"graphic not found: {g}")
                continue
            used_graphics.add(p.resolve())
            m = re.search(r"fig(?:ure)?[_-]?(\d+)", p.stem, re.I)
            if m and int(m.group(1)) != fl.number:
                fl.flags.append(f"file name says fig {int(m.group(1))} but this prints as Fig. {fl.number}")
            if p.suffix.lower() in RASTER:
                fl.flags.append(f"raster graphic ({p.name}); prefer vector unless photograph")

    for label, lines in refs.items():
        if label not in all_labels and not re.match(r"(sec|app|ch|sub|item|ln|line|fn):", label):
            global_flags.append(f"reference to unknown label '{label}' at line {lines[0]}")
    for d in dirs:
        if d == main.parent:
            continue
        for p in sorted(d.iterdir()) if d.is_dir() else []:
            if p.suffix.lower() in VECTOR | RASTER and p.resolve() not in used_graphics:
                global_flags.append(f"unused graphic in {d.name}/: {p.name}")
    return floats, global_flags


def report(floats: list[Float], global_flags: list[str]) -> str:
    out = ["| No. | Env | Line | Sec | Label | First ref | Refs | Caption (start) | Flags |", "|---|---|---|---|---|---|---|---|---|"]
    for fl in floats:
        cap = (fl.caption[:60] + "…") if len(fl.caption) > 60 else fl.caption
        out.append(f"| {fl.kind}. {fl.number} | {fl.env} | {fl.line} | {fl.section} | {', '.join(fl.labels) or '—'} | "
                   f"{fl.first_ref_line or '—'} | {fl.n_refs} | {cap} | {'; '.join(fl.flags)} |")
    flagged = sum(1 for fl in floats if fl.flags)
    out.append("")
    out.append(f"{len(floats)} elements, {flagged} flagged, {len(global_flags)} global issues.")
    out.extend(f"- {g}" for g in global_flags)
    return "\n".join(out)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    main_tex = Path(argv[1])
    if not main_tex.exists():
        print(f"not found: {main_tex}")
        return 2
    floats, global_flags = audit(main_tex)
    if "--json" in argv:
        print(json.dumps({"floats": [fl.__dict__ for fl in floats], "global": global_flags}, indent=2))
    else:
        print(report(floats, global_flags))
    return 1 if global_flags or any(fl.flags for fl in floats) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
