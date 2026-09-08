#!/usr/bin/env python3
"""Mechanical gate checks for a Quarto RevealJS lecture deck.

Reports what can be counted: timing-cue coverage, speaker-notes presence,
source-note coverage, bullet density, and title style. It does not decide
whether the deck passes -- the ladder-order rule and claim verification need
judgement and a second pass over primary sources, which is the gate agent's job.

Every threshold here comes from lecture_pattern.md. Where the pattern says a
figure is diagnostic rather than binding (the ~14-20 slide band), this reports
it as an observation, not a violation.

Usage:
    check_deck.py path/to/classN.qmd [--budget 90]
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

BUDGET_MIN = 90
MAX_BULLETS = 6           # split above this, per the density rule
MIN_MIN_PER_SLIDE = 2.0   # "≈2 min or more per substantive slide"

# A topic title names a subject; an assertion title makes a claim. Heuristic
# only -- flagged for the human, never counted as a defect.
TOPIC_HINT = re.compile(r"^(overview|introduction|background|objectives?|agenda|"
                        r"outline|summary|conclusion|methods?|results?|"
                        r"class objectives|references)\b", re.I)


@dataclass
class Slide:
    title: str
    line: int
    body: list[str] = field(default_factory=list)

    @property
    def visible(self) -> list[str]:
        """Body lines actually shown on the slide.

        Speaker notes live in a ::: {.notes} fence and are spoken, not
        projected, so they must not count toward slide density. Counting them
        flagged 24 slides on the reference deck, none of which were dense --
        a checker that cries wolf on the best deck in the course teaches the
        author to ignore it.
        """
        out, in_notes = [], False
        for line in self.body:
            if "::: {.notes}" in line:
                in_notes = True
                continue
            if in_notes:
                if line.strip() == ":::":
                    in_notes = False
                continue
            out.append(line)
        return out

    @property
    def bullets(self) -> int:
        return sum(1 for l in self.visible if re.match(r"\s*[-*+]\s+\S", l))

    @property
    def has_notes(self) -> bool:
        return any("::: {.notes}" in l for l in self.body)

    @property
    def smaller(self) -> bool:
        return any("{.smaller}" in l for l in self.visible)

    @property
    def tabular(self) -> bool:
        return any(l.lstrip().startswith("|") for l in self.visible)


def parse(path: Path) -> list[Slide]:
    slides: list[Slide] = []
    for n, line in enumerate(path.read_text(errors="replace").splitlines(), 1):
        if line.startswith("## "):
            slides.append(Slide(line[3:].strip(), n))
        elif slides:
            slides[-1].body.append(line)
    return slides


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("deck", type=Path)
    ap.add_argument("--budget", type=int, default=BUDGET_MIN)
    args = ap.parse_args()

    if not args.deck.is_file():
        print(f"error: no such deck: {args.deck}", file=sys.stderr)
        return 1

    text = args.deck.read_text(errors="replace")
    slides = parse(args.deck)
    cues = [int(m) for m in re.findall(r"\[t=(\d+)\s?min\]", text)]
    srcs = len(re.findall(r"\[src:", text))

    print(f"\n{args.deck.name} — {len(slides)} content slides\n")

    # --- timing ------------------------------------------------------------
    print("TIMING")
    if not cues:
        print("  DEFECT  no [t=Nmin] cues at all; the block plan is unverifiable")
    else:
        last = max(cues)
        print(f"  cues: {', '.join(f't={c}' for c in sorted(cues))}")
        if last < args.budget - 10:
            print(f"  DEFECT  cues stop at t={last} against a {args.budget}-min budget. "
                  f"The final {args.budget - last} min are unplanned — this is the drift "
                  f"the pattern flags in class 2.")
        elif last > args.budget:
            print(f"  DEFECT  cues run to t={last}, over the {args.budget}-min budget")
        else:
            print(f"  ok      cues reach t={last} within the {args.budget}-min budget")
        if len(slides):
            print(f"  observation  {args.budget / len(slides):.1f} min/slide average "
                  f"(pattern wants ≈{MIN_MIN_PER_SLIDE:.0f}+ for substantive slides; "
                  f"audit against the notes' spoken load, not this number)")

    # --- notes -------------------------------------------------------------
    missing = [s for s in slides if not s.has_notes]
    print("\nSPEAKER NOTES")
    print(f"  {len(slides) - len(missing)}/{len(slides)} slides carry ::: {{.notes}}")
    for s in missing:
        print(f"  DEFECT  line {s.line}: no notes — {s.title[:64]}")

    # --- sources -----------------------------------------------------------
    print("\nSOURCE NOTES")
    if srcs == 0:
        print("  DEFECT  no [src:] notes anywhere. The pattern requires a source note on "
              "every claim needing backing, and every 2026 claim search-verified.")
    else:
        print(f"  {srcs} [src:] notes present — the gate still has to re-derive each one")

    # --- density -----------------------------------------------------------
    print("\nSLIDE DENSITY")
    dense = [s for s in slides if s.bullets > MAX_BULLETS]
    for s in dense:
        print(f"  DEFECT  line {s.line}: {s.bullets} bullets (>{MAX_BULLETS}) — split — {s.title[:52]}")
    for s in slides:
        if s.smaller and not s.tabular:
            print(f"  DEFECT  line {s.line}: {{.smaller}} on non-tabular content — split instead")
    if not dense:
        print(f"  ok      no slide exceeds {MAX_BULLETS} bullets")

    # --- titles ------------------------------------------------------------
    topic = [s for s in slides if TOPIC_HINT.match(s.title)]
    print("\nTITLES")
    if topic:
        print(f"  review  {len(topic)} topic-style titles; the pattern prefers assertions")
        for s in topic[:5]:
            print(f"          line {s.line}: {s.title[:60]}")
    else:
        print("  ok      no obviously topic-style titles")

    print("\nNOT CHECKED HERE — these need the gate agent, not a script:")
    print("  ladder order (Tension → Core → Mechanism → Complexity → Frontier),")
    print("  whether any slide presupposes a later step, whether each [src:] claim")
    print("  actually says what the slide says, and hybrid-delivery compliance.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
