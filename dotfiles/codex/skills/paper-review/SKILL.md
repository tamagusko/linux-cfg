---
name: paper-review
description: Write a rigorous referee report for someone else's manuscript or evaluate a revision against an earlier review. Do not use for the user's own draft.
metadata:
  codex-migrated-from: dotfiles/claude/skills/paper-review
---

# Peer review

The job is a review where **every comment earns its place**. A review in which
each item is load-bearing reads as senior; one padded with preferences and
courtesies reads as junior, and buries the findings that matter among things
that do not.

That produces a deliberate asymmetry, and it is the whole point of this skill:

- **Errors: maximum recall.** Every one, whatever its size. A units mistake and
  a broken identification strategy both go in.
- **Suggestions: maximum precision.** Only those without which the paper is
  deficient. Cleverness is not a qualification.

Most reviewing tools fail by treating both the same and filling to a length.

## Before writing anything

Establish three things. Ask if they are not obvious; guessing wastes the review.

1. **Venue and its form.** A conference short paper is not judged by journal
   standards, and many venues supply a form with fields or a rubric rather than
   a free-text box. Fit the form; do not impose a template on it.
2. **Round.** A first review reads the manuscript. A revision round checks the
   rebuttal against the previous review, point by point, and says for each
   whether it was actually addressed.
3. **Language.** Match the venue, and see `references/invariants.md` — Brazilian
   Portuguese reviewing is not translated English.

## Workflow

**1. Read the whole manuscript first.** Do not begin listing comments while
reading. Early findings distort into a theory the rest of the paper is then read
to confirm.

**2. Sweep for errors.** Work through `references/error_sweep.md`. This stage is
about recall, so collect everything; filtering comes later. Recompute anything
computable — arithmetic, percentages, unit conversions, degrees of freedom,
whether the numbers in a table sum to the total claimed in the text. Use a script.
Mental arithmetic is how a reviewer ends up asserting something false in public.

**3. Collect candidate suggestions,** without judging them yet. Separating
generation from filtering keeps the filter honest; judging as you go tends to
admit whatever you happened to think of first.

**4. Apply the two gates.** See below and `references/filter_examples.md`.

**5. Order and write.** Identification, methodology and data validity first;
then robustness and reproducibility; then interpretation and overclaiming; then
presentation. Write in the voice described in `references/invariants.md`.

## The two gates

**Errors pass unconditionally.** If it is wrong, it goes in, however small. In
one corpus review `"fascial"` appeared six times for `"fiscal"` — typo-class, and
still an error, so it belongs. Severity decides *where* a comment sits, never
*whether* it appears.

**Suggestions face one question:** *would a competent editor accept this paper
with this left unaddressed?* If yes, cut it. Not "is this true", not "is this a
good idea" — those admit almost anything.

A useful test for the hardest cases: **could this comment have been written
before reading the paper?** If so it is a stock comment, not a finding. The
corpus contains a keyword complaint repeated near-verbatim across three
different reviews, which is what that failure looks like in practice.

**When you cannot verify a concern, it becomes a question, never an accusation.**
Put it in a `Questions for authors` section, or state the branch explicitly:
"Two interpretations are possible, and the manuscript must resolve which
applies. (a) ... (b) ...". Confidence is calibrated honestly: an error stated as
an error, a judgement as a judgement, a question as a question.

**One exception to the filter.** On revision rounds, a brief courtesy opening or
closing is allowed even though it carries no reviewable content. It does real
work in a relationship that spans months. Keep it to one sentence, and never let
it substitute for a verdict.

## Writing the comments

Every comment does three things, and the corpus is consistent on all three:

1. **Opens with the location** — `Algorithm 1, Step 3`, `L43`, `Abstract,
   line 10`, `Equação (1), Seção 3.1`. A comment the authors cannot locate is a
   comment they cannot act on.
2. **States the evidence**, including the number and why it matters.
3. **Names the fix** in the same comment. Diagnosis without a remedy shifts work
   onto the authors that the reviewer has already done.

Errors take obligation: *must be corrected*, *should read*. Suggestions take
hedged first person: *I would soften to ...*, *Consider ...*. That contrast is
how a reader tells the two apart at a glance, so do not blur it.

Consolidate all typographic and copy-editing points into a single comment.
Fifteen separate items for fifteen typos buries the methodology.

## Length

There is no word target. The number of comments follows from the number of
defects, and nothing else. A short review of a sound paper is a good review, and
padding one to look thorough is the failure this skill exists to prevent.

For orientation only, from the corpus: conference reviews run 380–600 words,
journal reviews 900–3,400.

## Output

Plain text when the destination is a submission form — no Markdown, since it
will not render. Match the venue's own structure: if it supplies fields or a
rubric, fill those; otherwise a recommendation line, a short general assessment,
then numbered comments.

Use one continuous numbering sequence across severity headings rather than
restarting under each. Verdict vocabulary is standardised in
`references/invariants.md`; use it exactly, since the corpus drifts here and the
drift is a defect rather than a style.

Before delivering, re-read each comment against the manuscript and confirm the
claim is true. A review that asserts something false about the paper costs more
credibility than a review that missed something.

## References

- `references/error_sweep.md` — what to sweep for, and what to recompute
- `references/filter_examples.md` — admitted vs rejected, from real reviews
- `references/invariants.md` — voice, verdict vocabulary, Portuguese register

Delegate where a specialist is better: the `statistical-reviewer` agent for
statistical validity, the `citation-verification` skill for reference checking.
