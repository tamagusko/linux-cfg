#!/usr/bin/env python3
"""Count and check an abstract: word budget per element, hard-check violations,
keyword coverage and title alignment.

This is the mechanical half of the abstract-writing skill. The model decides
whether an abstract is good; this script decides what is *in* it, with real
counts, so the audit table never contains estimated numbers.

Input is the abstract as plain text (LaTeX tolerated), optionally tagged by
role so the per-element table can be produced. Tags are square-bracketed and
start each span:

    [topic] Road pavements do not heal ... [question] Can a model ...
    [gap] ... [idea] ... [execution] ... [results] ... [impact] ...

Untagged text still gets the total count and every hard check.

Usage:
    abstract_audit.py ABSTRACT.txt --tex main.tex            # title + keywords from the .tex
    abstract_audit.py --tex main.tex                         # abstract, title, keywords from the .tex
    abstract_audit.py ABSTRACT.txt --title "..." --keywords "a; b; c" [--limit 250] [--target 150]

Exit status 1 when a hard check fails, 0 otherwise.
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

ROLES = ["topic", "question", "gap", "idea", "execution", "results", "impact"]

# Layer 3 budget elements as shares of the abstract's own length. The LSE bands
# (others <= 20%, methods >= 20%) assume 200-300 words; with a 150-word target
# and three spine roles on the "others" side they are loosened by five points.
# Findings get whatever remains and never less than a quarter.
BUDGET = {
    "others (topic+question+gap)": (["topic", "question", "gap"], None, 0.25),
    "approach (idea)": (["idea"], 0.15, None),
    "methods (execution)": (["execution"], 0.15, 0.40),
    "findings (results)": (["results"], 0.25, None),
    "value (impact)": (["impact"], 0.10, None),
}

FLOOR, TARGET, CEILING = 100, 150, 250

# A quantity word is fine when a digit sits in the same sentence.
NUMBER = r"(\d|\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|twenty|thirty|fifty|hundred|thousand|half|third|quarter|fold|percent|per cent)\b)"
EVALUATIVE = r"\b(accurate(ly)?|effective(ly)?|efficient(ly)?|reliabl[ey]|precise(ly)?|powerful|promising)\b"
VAGUE = r"\b(significant(ly)?|substantial(ly)?|considerabl[ey]|dramatic(ally)?|great(ly)?|marked(ly)?|notabl[ey]|vast(ly)?|much (better|worse|higher|lower|faster)|improv(e|es|ed|ing|ement)|outperform(s|ed|ing)?|superior|enhanc(e|es|ed|ing)|boost(s|ed)?)\b"
DIRECTION = r"\b(reduc(e|es|ed|ing)|increas(e|es|ed|ing)|rais(e|es|ed|ing)|lower(s|ed|ing)?|better|worse|higher|faster|slower)\b"
SIGNPOST = r"(this (paper|article|study|work) (sets out|aims|seeks|attempts|intends|is organi[sz]ed)|we (set out|aim|seek|attempt|intend) to|section \d|\bbelow\b|the following|as follows|described (below|later|in section)|presented (below|later)|\bherein\b|in what follows|the remainder of|rest of (the|this) paper)"
AI_VOCAB = r"(?<!-)\b(leverag(e|es|ed|ing)|robust(ly|ness)?|delv(e|es|ed|ing)|cutting-edge|holistic(ally)?|seamless(ly)?|transformative|groundbreaking|underscor(e|es|ed|ing)|pivotal|crucial(ly)?|landscape|unlock(s|ed|ing)?|harness(es|ed|ing)?|paradigm|in today's|state-of-the-art)\b"
FUTURE = r"\b(this (paper|article|study|work)|we|the (paper|article|study)) (will|shall)\b"
PAST_ON_WORK = r"\b(this (paper|article|study|work)|we) (showed|proposed|developed|presented|found|introduced|demonstrated|investigated|examined|has shown|have shown|has proposed|have proposed)\b"
OUTWARD = r"(\\cite\w*\{|\[\d+(,\s*\d+)*\]|\bet al\.|\b(figure|fig\.|table|equation|eq\.|algorithm|appendix|section)\s*(\d|~?\\ref))"
HEDGES = r"\b(may|might|could|suggest(s|ed)?|likely|appear(s|ed)? to|tend(s)? to|indicate(s)? that)\b"

STOP = set("a an the of for and or in on to with by from at as is are was were be been this that these those we our its it into than via using use used based between across within without over under toward towards against per not no do does did which where when while any every each one thus also then there here such both yet but if so can".split())


@dataclass
class Report:
    hard_fails: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    lines: list[str] = field(default_factory=list)

    def fail(self, msg: str) -> None:
        self.hard_fails.append(msg)

    def warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def out(self, msg: str = "") -> None:
        self.lines.append(msg)


# ---------------------------------------------------------------- text utils

def strip_latex(text: str, comments: bool = False) -> str:
    """Drop LaTeX markup. Comment stripping is only safe on .tex input; a plain
    text abstract uses % as a percent sign."""
    text = text.replace("\\%", "\x00")
    if comments:
        text = re.sub(r"%.*", "", text)
    text = text.replace("\x00", "%").replace("\\&", "&").replace("~", " ")
    text = re.sub(r"\\(emph|textbf|textit|text|mbox)\{([^}]*)\}", r"\2", text)
    text = re.sub(r"\\sep\b", ";", text)
    text = re.sub(r"\\[a-zA-Z]+\*?(\[[^\]]*\])?", " ", text)  # remaining commands
    text = re.sub(r"[{}$]", "", text)
    return re.sub(r"[ \t]+", " ", text).strip()


def words(text: str) -> list[str]:
    return [w for w in re.split(r"\s+", text) if re.search(r"[A-Za-z0-9]", w)]


def sentences(text: str) -> list[str]:
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z0-9(\[])", text.strip())
    return [p for p in parts if words(p)]


def stem(token: str) -> str:
    t = re.sub(r"[^a-z0-9-]", "", token.lower())
    for suf in ("ically", "ations", "ation", "ingly", "ency", "ancy", "ness", "ing", "ies", "ers", "ally", "ical", "ity", "ent", "ant", "ous", "ive", "ed", "es", "er", "al", "ic", "ly", "s"):
        if len(t) > len(suf) + 3 and t.endswith(suf):
            t = t[: -len(suf)]
            break
    return t


def same_stem(a: str, b: str) -> bool:
    return a == b or (min(len(a), len(b)) >= 4 and (a.startswith(b) or b.startswith(a)))


def content_stems(text: str) -> list[str]:
    parts = [p for w in words(text) for p in w.split("-")]
    return [stem(p) for p in parts if p.lower().strip(".,;:()") not in STOP and len(stem(p)) > 2]


# ---------------------------------------------------------------- parsing

def parse_tagged(text: str) -> tuple[dict[str, str], str]:
    """Return {role: span} and the untagged plain abstract."""
    spans: dict[str, str] = {}
    tag_re = re.compile(r"\[(" + "|".join(ROLES) + r")\]", re.I)
    matches = list(tag_re.finditer(text))
    if not matches:
        return {}, text
    for i, m in enumerate(matches):
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        role = m.group(1).lower()
        spans[role] = (spans.get(role, "") + " " + text[m.end():end]).strip()
    plain = tag_re.sub("", text)
    return spans, re.sub(r"\s+", " ", plain).strip()


def from_tex(path: Path) -> tuple[str, str, list[str]]:
    src = path.read_text(encoding="utf-8")
    abstract = re.search(r"\\begin\{abstract\}(.*?)\\end\{abstract\}", src, re.S)
    title = re.search(r"\\title\{(.*?)\}\s*$", src, re.M | re.S)
    kw = re.search(r"\\begin\{keyword\}(.*?)\\end\{keyword\}", src, re.S)
    if not kw:
        kw = re.search(r"\\keywords?\{(.*?)\}", src, re.S)
    keywords = []
    if kw:
        body = strip_latex(kw.group(1), comments=True)
        keywords = [k.strip() for k in re.split(r"[;,\n]", body) if k.strip()]
    return (
        strip_latex(abstract.group(1), comments=True) if abstract else "",
        strip_latex(title.group(1), comments=True) if title else "",
        keywords,
    )


# ---------------------------------------------------------------- checks

def keyword_status(keyword: str, abstract: str) -> str:
    if re.search(re.escape(keyword.lower()), abstract.lower()):
        return "verbatim"
    kw_stems = [stem(w) for w in words(keyword)]
    ab_stems = [stem(w) for w in words(abstract)]
    for i, s in enumerate(ab_stems):
        if not same_stem(s, kw_stems[0]):
            continue
        window = ab_stems[i : i + len(kw_stems) + 2]
        if all(any(same_stem(k, w) for w in window) for k in kw_stems):
            return "inflected"
    return "MISSING"


def find_all(pattern: str, text: str) -> list[str]:
    return sorted({m.group(0).strip() for m in re.finditer(pattern, text, re.I)})


def run(abstract: str, spans: dict[str, str], title: str, keywords: list[str], limit: int, target: int) -> Report:
    r = Report()
    total = len(words(abstract))
    ceiling = min(CEILING, limit)
    sents = sentences(abstract)
    paragraphs = [p for p in re.split(r"\n\s*\n", abstract) if p.strip()]

    r.out("## Length")
    r.out(f"| words | floor | target | ceiling | sentences | longest sentence | paragraphs |")
    r.out(f"|---|---|---|---|---|---|---|")
    longest = max((len(words(s)) for s in sents), default=0)
    r.out(f"| {total} | {FLOOR} | {target} | {ceiling} | {len(sents)} | {longest} | {len(paragraphs)} |")
    if total > ceiling:
        r.fail(f"{total} words exceeds the ceiling of {ceiling}")
    if total < FLOOR:
        r.fail(f"{total} words is under the floor of {FLOOR}")
    if len(paragraphs) > 2:
        r.fail(f"{len(paragraphs)} paragraphs; one is the norm, two the maximum")
    for s in sents:
        if len(words(s)) > 35:
            r.warn(f"sentence of {len(words(s))} words fails the one-breath test: \"{s[:70]}...\"")

    r.out()
    r.out("## Word budget per element")
    if spans:
        r.out("| element | words | share | budget | verdict |")
        r.out("|---|---|---|---|---|")
        for name, (roles, lo, hi) in BUDGET.items():
            n = sum(len(words(spans.get(role, ""))) for role in roles)
            share = round(n / total, 2) if total else 0  # compare on the printed percent
            budget = []
            if lo is not None:
                budget.append(f"≥ {lo:.0%}")
            if hi is not None:
                budget.append(f"≤ {hi:.0%}")
            ok = (lo is None or share >= lo) and (hi is None or share <= hi)
            verdict = "ok" if ok else "OUT OF BUDGET"
            if not ok:
                r.warn(f"{name}: {n} words ({share:.0%}), budget {' '.join(budget)}")
            r.out(f"| {name} | {n} | {share:.0%} | {' '.join(budget)} | {verdict} |")
        missing = [role for role in ROLES if role not in spans]
        if missing:
            r.fail("spine roles with no words: " + ", ".join(missing))
    else:
        r.out("(untagged input: tag the spans with [topic] [question] [gap] [idea] [execution] [results] [impact] to get the table)")

    r.out()
    r.out("## Hard checks")
    checks = [
        ("vague quantifier with no number in its sentence", None),
        ("signposting", find_all(SIGNPOST, abstract)),
        ("AI vocabulary", find_all(AI_VOCAB, abstract)),
        ("em-dash", find_all(r"—|\s--\s|–", abstract)),
        ("future tense on the work", find_all(FUTURE, abstract)),
        ("outward reference (not self-contained)", find_all(OUTWARD, abstract)),
    ]
    vague_hits: list[str] = []
    evaluative_hits: list[str] = []
    for s in sents:
        if re.search(NUMBER, s, re.I):
            continue
        for m in re.finditer(VAGUE, s, re.I):
            vague_hits.append(f"\"{m.group(0)}\" in: {s[:80]}")
        for m in re.finditer(EVALUATIVE, s, re.I):
            evaluative_hits.append(f"\"{m.group(0)}\" in: {s[:80]}")
        for m in re.finditer(DIRECTION, s, re.I):
            evaluative_hits.append(f"\"{m.group(0)}\" in: {s[:80]}")
    checks[0] = (checks[0][0], vague_hits)
    r.out("| check | hits |")
    r.out("|---|---|")
    for name, hits in checks:
        r.out(f"| {name} | {'; '.join(hits) if hits else 'none'} |")
        if hits:
            r.fail(f"{name}: {'; '.join(hits)}")
    r.out(f"| evaluative or direction word with no number (warning) | {'; '.join(evaluative_hits) if evaluative_hits else 'none'} |")
    if evaluative_hits:
        r.warn("evaluative or direction word with no number in its sentence: " + "; ".join(evaluative_hits))
    past = find_all(PAST_ON_WORK, abstract)
    r.out(f"| past tense on the work (warning) | {'; '.join(past) if past else 'none'} |")
    if past:
        r.warn("past tense describing the paper itself: " + "; ".join(past))
    hedges = find_all(HEDGES, abstract)
    r.out(f"| hedges present (information) | {'; '.join(hedges) if hedges else 'none'} |")

    r.out()
    r.out("## Keywords")
    if keywords:
        r.out("| keyword | status |")
        r.out("|---|---|")
        for k in keywords:
            st = keyword_status(k, abstract)
            r.out(f"| {k} | {st} |")
            if st == "MISSING":
                r.fail(f"keyword absent from the abstract: {k}")
            elif st == "inflected":
                r.warn(f"keyword present only in inflected form: {k}")
    else:
        r.out("(no keywords supplied)")

    r.out()
    r.out("## Title alignment")
    if title:
        t_stems = {s for s in content_stems(title)}
        a_stems = set(content_stems(abstract))
        absent = sorted(t for t in t_stems if not any(same_stem(t, a) for a in a_stems))
        r.out(f"title: {title}")
        r.out(f"title themes absent from the abstract: {', '.join(absent) if absent else 'none'}")
        if absent:
            r.warn("title themes absent from the abstract: " + ", ".join(absent))
        freq: dict[str, int] = {}
        for s in content_stems(abstract):
            freq[s] = freq.get(s, 0) + 1
        extra = [s for s, _ in sorted(freq.items(), key=lambda kv: -kv[1]) if s not in t_stems][:8]
        r.out(f"frequent abstract themes not in the title (judge whether any is major): {', '.join(extra)}")
    else:
        r.out("(no title supplied)")

    r.out()
    r.out("## Download test (title plus the first three lines, about 45 words)")
    r.out(f"**{title}**" if title else "(no title)")
    r.out(" ".join(words(abstract)[:45]) + (" ..." if total > 45 else ""))

    r.out()
    r.out("## Verdict")
    r.out(f"hard failures: {len(r.hard_fails)}")
    for f in r.hard_fails:
        r.out(f"- FAIL: {f}")
    r.out(f"warnings: {len(r.warnings)}")
    for w in r.warnings:
        r.out(f"- warn: {w}")
    return r


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("abstract", nargs="?", type=Path, help="abstract text, optionally tagged by role")
    ap.add_argument("--tex", type=Path, help="manuscript .tex to read title/keywords (and the abstract if none given)")
    ap.add_argument("--title", default="")
    ap.add_argument("--keywords", default="", help="semicolon-separated")
    ap.add_argument("--limit", type=int, default=CEILING, help="venue word limit (default 250)")
    ap.add_argument("--target", type=int, default=TARGET)
    args = ap.parse_args()

    title, keywords, abstract_text = args.title, [], ""
    if args.tex:
        tex_abstract, tex_title, tex_kw = from_tex(args.tex)
        title = title or tex_title
        keywords = tex_kw
        abstract_text = tex_abstract
    if args.keywords:
        keywords = [k.strip() for k in args.keywords.split(";") if k.strip()]
    if args.abstract:
        abstract_text = strip_latex(args.abstract.read_text(encoding="utf-8"))
    if not abstract_text:
        ap.error("no abstract: give a file or --tex with a \\begin{abstract} block")

    spans, plain = parse_tagged(abstract_text)
    report = run(plain, spans, title, keywords, args.limit, args.target)
    print("\n".join(report.lines))
    return 1 if report.hard_fails else 0


if __name__ == "__main__":
    sys.exit(main())
