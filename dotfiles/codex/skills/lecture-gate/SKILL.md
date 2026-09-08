---
name: lecture-gate
description: Run an independent acceptance review of a Quarto RevealJS deck for the user's AI-applied-to-transportation course before teaching it.
metadata:
  codex-migrated-from: dotfiles/claude/skills/lecture-gate
---

# Lecture gate

The build produces a deck; the gate decides whether it ships. These are separate
jobs and must be separate passes, because the failure this catches is not
sloppiness — it is confident invention. The pipeline has previously fabricated a
quotation that propagated into five artifacts including a student-facing answer
key, and it was caught only because the gate went back to primary sources
instead of re-reading the draft.

So: **re-derive, do not re-read.** A claim is verified when you have opened the
source, not when the deck's own `[src:]` note looks plausible.

Authority: `lecture_pattern.md` in the course root governs. Where a taught deck
disagrees with the pattern, the pattern wins and the taught deck is left alone —
classes already taught are frozen and never retrofitted.

## Step 1 — Mechanical pass

```bash
python3 "$CLAUDE_SKILL_DIR/scripts/check_deck.py" <deck.qmd> [--budget 90]
```

Reports timing-cue coverage against the 90-minute budget, speaker-notes
presence, `[src:]` coverage, bullet density, and title style. It counts only
what is visible on the slide — notes inside `::: {.notes}` are spoken, not
projected, and do not count toward density.

It reports; it does not decide. Treat its output as the first half of the
evidence.

## Step 2 — The ladder

The structural rule, and the one a script cannot check:

1. **Tension** — a research-relevant problem current methods fail at
2. **Core concept** in plain terms
3. **Mechanism**
4. **Realistic complexity**
5. **2026 frontier**

In order, with new notation or jargon introduced only at the step where it is
first needed. **Any slide presupposing a later step is a defect.** Walk the deck
in sequence and name the first slide that reaches forward — that is usually the
only real structural finding, and the rest follow from it.

A class inside an arc may open at the arc's current step with a one-slide recap
of rungs already climbed. That is not a violation.

## Step 3 — Claim verification

Every claim that needs backing carries `[src: DOI/URL]`, and every 2026 claim —
model, benchmark, regulation, deployment — is search-verified at build time.
Unverifiable claims are cut, not softened.

At the gate: open the sources. For each `[src:]`, confirm the source says what
the slide says. For numbers, recompute rather than eyeball; the course ships
per-class verifier scripts precisely because two independent routes to the same
number is the standard here.

Living benchmarks ship as dated observations or not at all. A leaderboard
position with no date is a defect.

## Step 4 — Time budget

Decks are planned to **90 minutes** for a 105-minute slot; the slack absorbs
overrun. The `[t=]` cues must sum to 90 and cover the whole deck — cues that
stop at t=74 leave sixteen minutes unplanned, which is the drift the pattern
flags in class 2.

Blocks: opening 5 / ladder 60–70 / applied 15–20 / synthesis 5.

Audit minutes against the notes' spoken load, not the slide count. The ~14–20
slide band is diagnostic, not a limit: exceeding it by **splitting** is correct,
exceeding it by adding content **minutes** is a defect.

## Step 5 — Hybrid delivery (binds classes 4–14)

No pair work, no breakout rooms. The instructor cannot circulate, so anything
that relied on walking the room must become a self-service check the student can
run — a gate, a known answer, a printed expected output.

Work assigned after class must be self-sufficient: its own verification, its own
reflection prompts, and a staged answer key that unlocks on the student's checks
having **run**, not having **passed**. A stuck student must never be locked out
of the answer.

## Verdict

Two outcomes, and say which plainly:

- **PASS** — or PASS WITH FIXES, listing fixes that do not require a re-gate
- **RETURN** — numbered directives, each naming the slide and what must change

Then update `tracker.md`: `built → gated` on pass. Only the author moves
`gated → approved`.

Keep directives few and load-bearing. A gate that returns twelve directives,
nine of them preferences, costs a re-gate cycle and trains the author to skim.
The same discipline as a good referee report: every item earns its place, and
the ones that do are stated plainly.
