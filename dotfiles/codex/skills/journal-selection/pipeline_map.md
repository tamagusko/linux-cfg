# Pipeline Map

Warm-start context for candidate generation: the topic clusters the author's active
manuscripts occupy, and the venues their current drafts already name.

**Scope rule:** calibration comes from `/home/tamagusko/repos/papers/in-progress/` only.
Published papers and citation history carry no weight. A venue belongs here only if a
current draft or its notes names it.

Last synced: 2026-08-23. Re-sync when papers enter or leave the pipeline.
Venues listed here are seeds for the candidate pool, not endorsements — every one still
goes through run-time verification and the fit gate.

## Clusters

| ID | Cluster | Papers |
|---|---|---|
| C1 | Cycling safety & perception from street-level / first-person imagery | colourways_framework, cycleai, perception-prompts |
| C2 | VLM/LLM as a measurement instrument (model-agnostic architecture, prompt DOE, human–model agreement) | colourways_framework, perception-prompts |
| C3 | Pavement performance ML: reliability, physical constraints, honest evaluation | pavements-ml, ltpp-iri-prediction |
| C4 | Pavement asset management, empirical/statistical (LTPP M&R) | ltpp-iri |
| C5 | Statistical methodology for human-subject study design | pairwise-sample-size |
| C6 | Air transport accessibility & network analysis | aviation/new_paper |

C1, C2 and C5 are coupled: the 385-rule sizes the perception-prompts survey, which produces
ground truth of the kind Colourways validates against.

## Papers and draft-named targets

| Paper | Contribution | Stage | Named target (source) |
|---|---|---|---|
| `colourways_framework` | Model-agnostic VLM platform for cycling infrastructure safety; CycleRAP-aligned prompt, thin adapter, Dublin first-person video pilot | Drafting; results are `[AUTHOR-TO-FILL]` | Transportation Research Part C (`TODO.md:4`, `plan/trc-improvement-plan.md`) |
| `pavements-ml` | CAGB — two-layer defense guaranteeing physical consistency in LTPP IRI forecasts | Two submission bundles built | Construction and Building Materials (`submission_CB/`, 2026-06); Expert Systems with Applications (`letter/`, 2026-04) |
| `ltpp-iri` | Empirical ΔIRI per M&R intervention type; 27 LTPP codes → 4 groups; non-parametric | Full draft | Construction and Building Materials (`PROJECT.md`) |
| `ltpp-iri-prediction` | M&R as feature not exclusion; regime-stratified evaluation; conformal miscoverage at high IRI | Draft, no cover letter | **none** |
| `pairwise-sample-size` | The 385-Rule — unified sample size for binary/ternary pairwise comparisons | Bundle built, post-transfer | Computers in Human Behavior Reports; see `docs/journals.md` for the author's own six-venue analysis |
| `perception-prompts` | Pairwise cyclist-perception survey + Sequential DOE evaluating Gemma 4 prompt configurations | Data collection; no manuscript yet | none |
| `aviation/new_paper` | Multidimensional Brazilian air-transport accessibility metric, 72 airports 2000–2025 | Verified against code outputs | Journal of Air Transport Management (notes) |
| `cycleai` | Bikeable — GSV object detection + TrueSkill pairwise perception ranking | **Already placed** — round-1 revision | (currently at Smart Cities; MDPI, so never re-recommended) |

`in-progress/attention/` is not a manuscript — it is a plagiarism assessment report. Excluded.

## Rejection history — the strongest available signal

| Paper | Venue | Outcome | Stated reason |
|---|---|---|---|
| pairwise-sample-size | Statistics & Probability Letters | Rejected | 6-page cap; paper is now 9 pages |
| pairwise-sample-size | MethodsX | Reviewed, transferred out | Framing fit better elsewhere |
| pairwise-sample-size | J. Statistical Planning and Inference | Transfer declined | 400+ days submission-to-print |
| pairwise-sample-size | J. Multivariate Analysis | Transfer declined | Wrong scope — not multivariate |

## Not a target

`ISPRS J. Photogrammetry & Remote Sensing` appears in `colourways_framework/TODO.md` as a
bibliography fix for the `Liang2025` citation, not as a submission target. Do not seed it
from that mention.
