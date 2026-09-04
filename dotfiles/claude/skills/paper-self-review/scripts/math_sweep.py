#!/usr/bin/env python3
"""List math-typesetting candidates in a LaTeX source for the final pass.

Candidates, not findings: every line reported here is adjudicated against
references/math-typesetting.md before it becomes an edit. Rule IDs match
that file. With --prose the sweep also lists modal padding (P1) and sticky
words in consecutive sentences (K8).
"""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Iterator
from dataclasses import dataclass
from itertools import pairwise
from pathlib import Path

DISPLAY_ENVS = (
    "equation", "equation*", "align", "align*", "gather", "gather*",
    "multline", "multline*", "eqnarray", "displaymath", "algorithmic",
    "tikzpicture",
)
# Lines that are pseudo-code or table rows, where a leading symbol is not a sentence.
NOT_A_SENTENCE = re.compile(r"&|\\;|\\tcp|\\Kw[A-Z]|\\u?If|\\Else|\\For|\\While|\\Return")
UNIT_WORDS = r"(?:m/km|km/h|trucks/day|mm|km|MB|ms|kg|kN|MPa|GPa|Hz|s|h|min|m)"
MODAL_PADDING = re.compile(
    r"\b(we need to|we must|we have to|it is necessary to|in order to|"
    r"it should be noted that|it is worth noting that|note that|"
    r"it is important to|it is essential to|due to the fact that|"
    r"a number of|serves? to|allows? (?:us )?to|is able to|are able to|"
    r"in the context of)\b",
    re.IGNORECASE,
)
STICKY = ("this", "also", "therefore", "thus", "however", "moreover")
LOGIC_SYMBOLS = re.compile(r"\\(?:implies|forall|exists|therefore|Rightarrow|Leftrightarrow|iff)\b")
KNOWN_WORDS = {
    "sin", "cos", "tan", "log", "exp", "max", "min", "arg", "lim", "sup", "inf",
    "det", "dim", "ker", "mod", "gcd", "deg", "sgn", "Pr", "var", "cov",
}


@dataclass(frozen=True)
class Candidate:
    """One suspicious location."""

    line: int
    rule: str
    snippet: str

    def render(self) -> str:
        return f"{self.line}: {self.rule}: {self.snippet.strip()}"


def strip_comments(text: str) -> str:
    """Remove LaTeX comments, keeping escaped percent signs."""
    return re.sub(r"(?<!\\)%.*", "", text)


def mask_display_math(text: str) -> str:
    """Blank displayed math so inline rules do not fire inside it."""
    for env in DISPLAY_ENVS:
        pattern = re.compile(
            r"\\begin\{" + re.escape(env) + r"\}.*?\\end\{" + re.escape(env) + r"\}",
            re.DOTALL,
        )
        text = pattern.sub(lambda m: "\n" * m.group(0).count("\n"), text)
    text = re.sub(r"\\\[.*?\\\]", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.DOTALL)
    text = re.sub(r"\$\$.*?\$\$", lambda m: "\n" * m.group(0).count("\n"), text, flags=re.DOTALL)
    return text


def inline_math(line: str) -> Iterator[str]:
    """Yield the contents of each $...$ or \\(...\\) span on a line."""
    for m in re.finditer(r"(?<!\\)\$(?!\$)(.+?)(?<!\\)\$|\\\((.+?)\\\)", line):
        yield m.group(1) or m.group(2) or ""


def strip_text_units(math: str) -> str:
    """Remove \\text{}, \\mathrm{}, \\si{} arguments (unit strings are exempt from M1b)."""
    return re.sub(r"\\(?:text|mathrm|textrm|si|unit|SI)\{[^{}]*\}", " ", math)


def atoms(fragment: str) -> int:
    """Count atoms (letters, numbers, commands, groups) in a slash operand.

    A parenthesized group counts as one atom, and so does a group followed only
    by an exponent, so (b-c)^2 is unambiguous while 2b or n\\log n is not.
    """
    fragment = fragment.strip()
    fragment = re.sub(r"\^(?:\{[^{}]*\}|\S)", "", fragment)  # exponents do not add atoms
    fragment = re.sub(r"_(?:\{[^{}]*\}|\S)", "", fragment)  # nor do subscripts
    if re.fullmatch(r"\((?:[^()]|\([^()]*\))*\)", fragment) or re.fullmatch(r"\{[^{}]*\}", fragment):
        return 1
    tokens = re.findall(r"\\[A-Za-z]+|[A-Za-z]|\d+(?:\.\d+)?|\{[^{}]*\}|\((?:[^()]|\([^()]*\))*\)", fragment)
    return len(tokens)


def _operand(math: str, start: int, step: int) -> str:
    """Walk from a slash outward, keeping balanced groups, until an operator or space."""
    opener, closer = ("(", ")") if step > 0 else (")", "(")
    depth = 0
    i = start
    while 0 <= i < len(math):
        ch = math[i]
        if ch in "({[" and (ch == opener or opener in "({[" and ch in "({["):
            depth += 1
        elif ch in ")}]" and (ch == closer or closer in ")}]" and ch in ")}]"):
            depth -= 1
            if depth < 0:
                break
        elif depth == 0 and ch in " =<>+-,;:":
            break
        i += step
    lo, hi = (start, i) if step > 0 else (i + 1, start + 1)
    return math[lo:hi]


def slash_candidates(math: str) -> Iterator[str]:
    """M1b: slashed expressions with more than two atoms on either side."""
    math = strip_text_units(math)
    for m in re.finditer(r"/", math):
        left = _operand(math, m.start() - 1, -1)
        right = _operand(math, m.start() + 1, +1)
        if atoms(left) > 1 or atoms(right) > 1:
            yield f"{left}/{right}"


def scan_line(lineno: int, line: str, prose: bool) -> list[Candidate]:
    found: list[Candidate] = []
    for math in inline_math(line):
        if "\\frac" in math:
            found.append(Candidate(lineno, "M1 inline \\frac", math))
        for s in slash_candidates(math):
            found.append(Candidate(lineno, "M1b ambiguous slash", s))
        if LOGIC_SYMBOLS.search(math):
            found.append(Candidate(lineno, "K6 logic symbol inline", math))
        for w in re.findall(r"(?<![\\A-Za-z{])[A-Za-z]{3,}(?![A-Za-z}])", math):
            if w not in KNOWN_WORDS:
                found.append(Candidate(lineno, "M5 italic multi-letter name", f"{w} in ${math}$"))
    # M2: footnote marker touching math.
    if re.search(r"\$\s*\\footnote(?:mark)?\b", line):
        found.append(Candidate(lineno, "M2 footnote beside math", line[:120]))
    # M3: integral whose differential lacks a thin space.
    for m in re.finditer(r"\\i+nt\b[^$]*", line):
        seg = m.group(0)
        if re.search(r"(?<![,;!\s])(?:\\mathrm\{d\}|(?<![A-Za-z\\])d)(?=[A-Za-z])", seg):
            found.append(Candidate(lineno, "M3 differential spacing", seg[:100]))
    # M4: number followed by a plain space (or nothing) and a unit.
    for m in re.finditer(r"\d(?: |\}?)" + UNIT_WORDS + r"\b(?![-\w])", line):
        if "\\," not in line[max(0, m.start() - 3): m.end()]:
            found.append(Candidate(lineno, "M4 number-unit space", line[max(0, m.start() - 12): m.end() + 4]))
    # K1/K2: a sentence, caption, item or note starting with a symbol.
    for m in re.finditer(r"(?:(?<=[.!?])\s+|\\caption\{|\\item\s+|\\tnote\{[^}]*\}\s*|^\s*)(\$[^$]+\$)", line):
        before = line[: m.start(1)].rstrip()
        if not before.strip() and NOT_A_SENTENCE.search(line):
            continue
        prefix = line[max(0, m.start() - 25): m.start()].strip()
        # A formula ending the previous sentence makes this a symbol collision (K2) as well.
        rule = "K2 symbol after symbol-ending sentence" if re.search(r"\$[.!?]$", before) else "K1 sentence starts with symbol"
        found.append(Candidate(lineno, rule, f"...{prefix} {m.group(1)}"))
    if prose:
        for m in MODAL_PADDING.finditer(line):
            found.append(Candidate(lineno, "P1 modal padding", line[max(0, m.start() - 30): m.end() + 30]))
        sentences = re.split(r"(?<=[.!?])\s+", line)
        for a, b in pairwise(sentences):
            for w in STICKY:
                if re.search(rf"\b{w}\b", a, re.IGNORECASE) and re.search(rf"\b{w}\b", b, re.IGNORECASE):
                    found.append(Candidate(lineno, f"K8 sticky word '{w}'", f"{a[-40:]} | {b[:40]}"))
    return found


def sweep(path: Path, prose: bool) -> list[Candidate]:
    text = mask_display_math(strip_comments(path.read_text(encoding="utf-8")))
    out: list[Candidate] = []
    for i, line in enumerate(text.splitlines(), start=1):
        out.extend(scan_line(i, line, prose))
    return out


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tex", type=Path, help="LaTeX source file")
    parser.add_argument("--prose", action="store_true", help="also list P1 modal padding and K8 sticky words")
    parser.add_argument("--lines", help="restrict to a line range, e.g. 69-224")
    args = parser.parse_args(argv)
    if not args.tex.exists():
        print(f"not found: {args.tex}", file=sys.stderr)
        return 2
    candidates = sweep(args.tex, args.prose)
    if args.lines:
        lo, hi = (int(x) for x in args.lines.split("-"))
        candidates = [c for c in candidates if lo <= c.line <= hi]
    for c in candidates:
        print(c.render())
    print(f"# {len(candidates)} candidate(s); adjudicate each against references/math-typesetting.md", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
