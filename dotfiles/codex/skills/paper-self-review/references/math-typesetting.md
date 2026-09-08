# Math typesetting pass: rules with do/don't examples

M-rules are the user's LaTeX rules. K-rules are mined from Knuth, Larrabee and Roberts, *Mathematical Writing* (Stanford CS 209 notes), minicourse §1, with the point number given. Run `scripts/math_sweep.py` first; it lists candidates, and each candidate is confirmed against the source before it becomes an edit. Docx source: apply the K-rules and the intent of M1 to M3 to equation objects; skip the LaTeX mechanics with a note.

## M1 No `\frac` in inline math

Inline fractions wreck line spacing. Use the slash in running text; keep `\frac` in displayed equations. Knuth's own closing example ("Final truths", p. 112) prefers `n(n+1)(2n+1)/3` to the stacked form.

```latex
% don't
the uncorrected $\chi^2 = \frac{(b-c)^2}{b+c}$ so that
% do
the uncorrected $\chi^2 = (b-c)^2/(b+c)$ so that
```

`\nicefrac` and `\sfrac` exist and are not preferred here.

## M1b The slash is ambiguous beyond two atoms

`$x/yz$` reads as x/(yz) or as (x/y)z. Whenever a slashed expression has more than two atoms on either side, parenthesize explicitly.

```latex
% don't
$x/yz$      $a/2b$      $1/n\log n$
% do
$x/(yz)$ or $(x/y)z$      $a/(2b)$      $1/(n\log n)$
```

Exempt: unit strings (m/km, km/h, trucks/day), whether in text or inside `\text{}`, `\mathrm{}`, `\si{}`.

## M2 Footnote markers near mathematics

A numeric marker on or beside an expression reads as an exponent: `$x$\footnote{...}` prints as x² for footnote 2. Never place one where it can be read as a power. Options, in order of preference:

1. Move the marker onto the preceding word: `the statistic\footnote{...} $x$`.
2. Use a symbolic marker: in tables, `$\dagger$`/`$\ddagger$`/`$*$` with a keyed table note; in text, `\renewcommand{\thefootnote}{\fnsymbol{footnote}}` scoped to the section.
3. Fold the footnote into the sentence.

```latex
% don't
$R^2$\footnote{after enforcement}
% do
$R^2_{\mathrm{enf}}$ (after enforcement)   or   $R^2$$^\dagger$ with a $\dagger$ note
```

## M3 Thin space before the differential

```latex
% don't
\int_0^T f(x)dx          \iint g(x,y)dxdy
% do
\int_0^T f(x)\,dx        \iint g(x,y)\,dx\,dy
```

Respect the document's convention for the d (italic `d` or upright `\mathrm{d}`); enforce only the thin space, on every integral in the document.

## M4 Thin space between number and unit

```latex
% don't        % do
0.5 m/km       0.5\,m/km
80 km/h        80\,km/h
```

## M5 Multi-letter operators upright

Multi-letter names in math italic read as a product of variables.

```latex
% don't        % do
$PCR = \dots$  $\mathrm{PCR} = \dots$   or   \DeclareMathOperator{\PCR}{PCR}
```

## K1 Don't start a sentence with a symbol (Knuth 2)

Applies to sentences, captions, table notes and list items.

```latex
% don't
for one section. $k_i$, $a_i$ and $\tau_i$ are the features of Section~3.
% do
for one section. The features $k_i$, $a_i$ and $\tau_i$ are those of Section~3.
```

## K2 Separate symbols in different formulas by words (Knuth 1)

Including across a sentence boundary, where the period is easy to miss.

```latex
% don't
Consider $S_q$, $q < p$.        ...at $t+1$. $b$ and $c$ are the discordant pairs
% do
Consider $S_q$, where $q < p$.  ...at $t+1$. Here $b$ and $c$ are the discordant pairs
```

## K3 Define every variable at first use (Knuth 11)

At least informally, in the sentence that introduces it; where cheap, state the definition twice in complementary ways. At the final pass this yields a comment (`% REVIEW(K3): $N$ undefined here; first defined in Sec. 3.4`), not moved text.

## K4 Displayed equations are parts of sentences (Knuth 4, 23)

Punctuate a display as the sentence requires (comma if it continues, period if it ends). Remove the colon before a display when the display is the grammatical object of the verb ("let:", "the model satisfies:", "is given by:"); keep it when a complete clause precedes and the display restates or specifies it ("falls below a detection threshold:"). The sentence before a theorem or algorithm is a complete sentence or ends with a colon. A sentence that opens with "Eq." spells it out: "Equation~(3) is the only operation".

```latex
% don't
The rate is defined as:
\begin{equation} \mathrm{PCR} = \dots \end{equation}
% do
The rate is defined as
\begin{equation} \mathrm{PCR} = \dots, \end{equation}
where ...
```

## K5 The "blah" test (Knuth 13)

Readers skim formulas. Replace every formula in the sentence with "blah" and read it: "Let blah denote blah and blah the change since the previous survey" still parses; "blah, blah, blah are the features" does not.

## K6 Words, not logic symbols, in running text (Knuth 3)

```latex
% don't                                  % do
$\forall$ sections, $\exists$ a record   for every section there is a record
$A \implies B$ (in prose)                if A then B
```

Displays and algorithm listings may keep the symbols.

## K7 One symbol per concept, one concept per symbol (Knuth 14, 15)

Indices consistent throughout (`i` over observations, `j` over features, not swapped between sections); no subscripts where set-element notation does the job. Final pass: comment.

## K8 Sticky words and parallelism (Knuth 9)

"This", "also", "therefore" and other conspicuous words are not used in consecutive sentences; parallel ideas take parallel form.

```
% don't
...is therefore documented. The detector is therefore a renewal detector.
% do
...is therefore documented. The detector is thus a renewal detector.   (or drop one)
```

## K9 Numbers and named objects (Knuth 18, 19)

Small numbers spelled out as adjectives ("two passes"), digits as names ("Method 2", "increased by 2"). Capitalize Theorem 1, Lemma 2, Algorithm 3, Section 4, Figure 5.

## K10 Punctuation and relative clauses (Knuth 8, 22, 25)

- A period goes inside parentheses if and only if the whole sentence is inside them. "This is bad, (although intentionally so.)" is wrong on both counts.
- "that" for restrictive clauses, "which" after a comma or preposition.
- Keep "that" after assume and suppose; never write "we have that x = y".
- Two-name compounds take an en dash, consistently: `Diebold--Mariano`, `Benjamini--Hochberg`, never a hyphen in one place and a dash in another.
