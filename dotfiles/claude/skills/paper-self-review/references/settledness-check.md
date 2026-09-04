# Settledness check (read-only)

At the final pass the science is settled. These checks confirm that nothing has drifted during the last edits; each finding is a comment (`% REVIEW(S): ...`), never an edit, and each is counted as blocking or not in the change log.

| ID | Check | Blocking if |
|---|---|---|
| S1 | Abstract states problem, method, main quantified result, contribution, and every number in it appears in the body | a number differs |
| S2 | Every contribution claimed in the Introduction is delivered in a named section | one is not |
| S3 | Every number in the prose matches its table or the results file; every `\ref` resolves | a mismatch |
| S4 | Every citation key resolves; no reference is cited only in a removed passage | an unresolved key |
| S5 | Every figure and table is referenced in the text, and its caption names the metric and unit | unreferenced float |
| S6 | Limitations section names the threats the Methods introduce | a threat named in Methods is absent |

Report as `Blocking comments: N` at the end of the change log. Anything else found here is a non-blocking comment.
