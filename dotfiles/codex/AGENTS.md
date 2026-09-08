# Codex global workflow

Use the skills installed in `~/.agents/skills` when their descriptions match the
task. The selected personal skills are Codex-optimized copies maintained under
`dotfiles/codex/skills` in the linux-cfg repository. Resolve bundled resources
from the active skill directory and use the tools available in the session.

## Model routing and orchestration

The root Codex model is GPT-5.6 Sol. When subagents are available and delegation
would save time or improve independent review, assign their models explicitly:

- Use `gpt-5.6-sol` for complex reasoning: architecture, difficult debugging,
  research synthesis, scientific or editorial judgment, planning across several
  components, and final quality decisions.
- Use `gpt-5.6-luna` for mechanical work: inventories, searches, extraction,
  formatting, repetitive edits, deterministic checks, and simple validation.
- For mixed work, have Sol define the approach and acceptance criteria, let Luna
  perform separable mechanical passes, then use Sol for synthesis or any
  judgment-heavy gate.
- Use `gpt-6-astra` selectively as an escalation or independent final reviewer
  when the expected quality gain justifies its higher usage. Appropriate cases
  include high-impact or hard-to-reverse changes, difficult architecture,
  security or data-integrity work, final manuscript or submission review,
  persistent bugs after a serious Sol attempt, large cross-component changes,
  conflicting evidence, unresolved uncertainty, and explicit user requests for
  the strongest available review.

For substantial mixed work, use this sequence when it fits the task:

1. Sol defines the approach and acceptance criteria.
2. Luna performs separable mechanical work.
3. Sol implements, integrates, and runs the normal validation.
4. Astra independently reviews when the risk or complexity meets the escalation
   criteria.
5. Sol applies corrections and reruns the relevant checks.

Delegate independent tasks in parallel when useful. Keep dependent edits and
decisions sequential. Give each subagent a bounded task, relevant paths,
expected output, and explicit model. Review subagent findings before acting on
them. Do not delegate a trivial task when coordination would cost more than the
work.

Watch model usage during sustained work. If usage, rate-limit consumption, or
subagent fan-out appears unusually fast for the value being produced, tell the
user and suggest a concrete adjustment for future work, such as reducing Astra
reviews, lowering reasoning effort, narrowing delegated tasks, or routing more
mechanical work to Luna. Do not silently reduce quality or change the requested
model during the active task.

## Shared conventions

- Respond to the user in English and keep technical terms in English.
- Prefer `uv` for Python package and environment management.
- Use Hydra with OmegaConf for configuration in ML projects when appropriate.
- Follow Conventional Commits when the user requests commits.
- Use `pdfcompile file.tex` for LaTeX compilation when that shell function is
  available.
