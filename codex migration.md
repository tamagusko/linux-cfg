# Codex migration

Date: 2026-09-08

## Migration design

The selected skills are independent Codex-optimized copies under
`dotfiles/codex/skills/`. Their Claude Code sources remain under
`dotfiles/claude/skills/`.

`scripts/migrate-codex-skills.py` recreates the copies in the order recorded in
`dotfiles/codex/skills.txt`. It normalizes frontmatter to the Codex schema,
shortens trigger descriptions, removes Claude-only tool restrictions, rewrites
skill installation paths, and excludes cache artifacts.

`stages/76-codex.sh` installs the copies as links in `~/.agents/skills` and
links the global orchestration instructions to `~/.codex/AGENTS.md`. Complex
subagent work is routed to GPT-5.6 Sol, mechanical work to GPT-5.6 Luna, and
GPT-6 Astra is reserved for risk-based escalation or independent final review.
The workflow also reports unusually fast usage and suggests concrete routing
adjustments without silently changing quality or the requested model.

## Migrated and installed skills

1. `git-workflow` — installed
2. `paper-self-review` — installed
3. `docx` — installed
4. `journal-selection` — installed
5. `scientific-figures` — installed
6. `submission-integrity` — installed
7. `review-response` — installed
8. `paper-review` — installed
9. `graphify` — installed
10. `daily-coding` — installed
11. `writing-anti-ai` — installed
12. `venue-templates` — installed
13. `timesfm-forecasting` — installed
14. `skill-development` — installed
15. `abstract-writing` — installed
16. `manuscript-pipeline` — installed
17. `results-analysis` — installed
18. `results-report` — installed
19. `paper-lookup` — installed
20. `research-ideation` — installed
21. `citation-verification` — installed
22. `obsidian-project-memory` — installed
23. `obsidian-project-bootstrap` — installed
24. `obsidian-research-log` — installed
25. `obsidian-experiment-log` — installed
26. `obsidian-literature-workflow` — installed
27. `obsidian-project-lifecycle` — installed
28. `zotero-obsidian-bridge` — installed
29. `lecture-gate` — installed
30. `lecture-currency` — installed

The overlapping `humanizer` link was retired because `writing-anti-ai` is the
personalized workflow selected for this role. Existing independent Codex skills,
including `systematic-debugging` and `find-skills`, were preserved.

## Validation

- All 30 installed links resolve to `dotfiles/codex/skills/<name>`.
- All 30 skills pass the Codex `quick_validate.py` schema check.
- Skill names match their directory slugs.
- Claude-only execution references and `~/.claude/skills` installation paths
  were removed or adapted. Shared `.claude/project-memory` data paths and
  explicitly scoped Claude Code integrations remain where intentional.
- Python bytecode, `__pycache__`, test caches, virtual environments, and
  `node_modules` were excluded from the copies.
- GPT-6 Astra independent review: PASS. The final gate confirmed the four
  review corrections, all 30 skills, live links, syntax and resource checks,
  migration idempotence, installer collision handling, and Sol/Luna routing.

## Recommended next candidates

These are the strongest candidates for a later migration, in approximate
priority order:

1. `scientific-writing`
2. `scientific-visualization`
3. `scholar-evaluation`
4. `post-acceptance`
5. `literature-review`
6. `scientific-slides`
7. `latex-posters`
8. `code-review-excellence`
9. `bug-detective`
10. `verification-loop`
11. `planning-with-files`
12. `uv-package-manager`
13. `architecture-design`
14. `exploratory-data-analysis`
15. `statistical-analysis`
16. `xlsx`
17. `pptx`
18. `pdf`
19. `markitdown`
20. `webapp-testing`

## Remaining Claude skill candidates

The full remaining inventory is retained for later review. Some entries are
vendored or highly specialized, so presence here does not imply a recommendation.

```text
aeon
agent-identifier
architecture-design
blip-2
brandkit
bug-detective
citation-management
clip
code-review-excellence
command-development
consciousness-council
course-material-creator
daily-paper-generator
dask
database-lookup
debugging
defuddle
design-taste-frontend
design-taste-frontend-v1
dhdna-profiler
doc-coauthoring
eli5
exploratory-data-analysis
ffuf-claude-skill
frontend-design
full-output-enforcement
generate-image
geomaster
geopandas
get-available-resources
google-flights
gpt-taste
high-end-visual-design
hook-development
humanizer
hypothesis-generation
image-to-code
imagegen-frontend-mobile
imagegen-frontend-web
img2threejs
impeccable
industrial-brutalist-ui
infographics
json-canvas
kaggle-learner
latex-conference-template-organizer
latex-posters
literature-review
llava
markdown-mermaid-writing
market-research-reports
markitdown
matlab
matplotlib
mcp-integration
minimalist-ui
modal
networkx
obsidian-bases
obsidian-cli
obsidian-link-graph
obsidian-markdown
obsidian-synthesis-map
optimize-for-gpu
paperzilla
parallel-web
pdf
peer-review
perplexity-search
planning-with-files
playwright-cli
plugin-structure
polars
post-acceptance
pptx
pptx-posters
pufferlib
pymc
pymoo
pytorch-lightning
pyzotero
redesign-existing-projects
research-grants
research-lookup
scholar-evaluation
scientific-brainstorming
scientific-critical-thinking
scientific-schematics
scientific-slides
scientific-visualization
scientific-writing
scikit-learn
scikit-survival
seaborn
segment-anything
shap
simpy
skill-improver
skill-quality-reviewer
stable-baselines3
stable-diffusion
statistical-analysis
statsmodels
stitch-design-taste
sympy
test-driven-development
torch-geometric
transformers
ui-ux-pro-max
umap-learn
uv-package-manager
ux-heuristics
vaex
verification-loop
video-tutorial
web-design-reviewer
webapp-testing
what-if-oracle
whisper
xlsx
```
