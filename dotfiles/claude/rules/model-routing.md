# Model Routing

Three tiers, by the kind of thinking a task needs rather than by how hard it
looks. This has been the working practice for months and is visible in the
provenance headers of most deliverables; it is written here so a new session
does not have to reconstruct it from plan documents.

| Tier | Use for | Why |
|---|---|---|
| **Fable** | Orchestration, adjudication, verification gates, synthesis across sources, final quality decisions | Judgement that has to hold a whole artefact in view and decide whether it passes |
| **Opus** | Scoped builds — writing a deck, a section, a module; citation and claim verification; structural review against a spec | Bounded work with a clear target, where accuracy matters more than breadth |
| **Sonnet** | Mechanics — inventories, git diff extraction, format validation, bibliography integrity, repetitive passes | Deterministic or near-deterministic work where the answer is checkable |

## The gate is a separate model, and that is the point

The tier that matters most is Fable as an **independent gate** on work another
model produced. Building and checking in the same pass does not work: a model
that has just written a deck is the worst judge of whether the deck is right.

This is not theoretical. The lecture pipeline caught a fabricated quotation that
had propagated into five artefacts, including a student-facing answer key,
because the gate re-derived every claim from primary sources instead of
re-reading what the builder wrote. Absent the gate, that ships.

Apply the same shape elsewhere: a build pass, then a separate verification pass
that goes back to sources rather than to the draft.

## Where this is already encoded

- `papers/review/paper_review_config.json` — `analysis` vs `mechanical` roles,
  with the split documented in the config itself
- Agent frontmatter in `dotfiles/claude/agents/` — judgement-heavy agents pinned
  `model: opus`, throughput agents `model: sonnet`
- Deliverable provenance headers, e.g. the Colourways improvement plan and the
  McKenzie compliance report, which name the tier used for each stage

## In practice

State the routing in the provenance header of any multi-stage deliverable, the
way the existing plan documents do. It costs one line and makes the artefact
auditable: a reader can see which claims came from a gate and which from a
first draft.

When delegating to subagents, route explicitly rather than letting everything
inherit the session model. A twelve-agent fan-out of mechanical inventory work
does not need the judgement tier, and a single adjudication does not want the
mechanical one.

Do not route by cost. Route by whether being wrong would be caught downstream.
