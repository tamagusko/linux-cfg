#!/usr/bin/env python3
"""Clone selected Claude skills and normalize them for local Codex discovery."""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

import yaml


ALLOWED_FRONTMATTER = ("name", "description", "license", "metadata")
IGNORED_NAMES = {
    ".DS_Store",
    ".pytest_cache",
    "__pycache__",
    "node_modules",
}
TEXT_SUFFIXES = {".md", ".txt"}
TRAILING_WHITESPACE_SAFE_SUFFIXES = {
    ".css",
    ".html",
    ".js",
    ".json",
    ".md",
    ".py",
    ".sh",
    ".tex",
    ".txt",
    ".toml",
    ".xml",
    ".xsd",
    ".yaml",
    ".yml",
}
DESCRIPTION_OVERRIDES = {
    "git-workflow": "Manage commits, branches, merge conflicts, pull requests, and Conventional Commits when the user requests Git workflow help.",
    "paper-self-review": "Run the final pre-submission review of the user's own settled manuscript. Use for a last pass or final polish; use paper-review for someone else's manuscript.",
    "docx": "Create, inspect, edit, or convert Word .docx documents when document-specific formatting, comments, tracked changes, or extraction is required.",
    "journal-selection": "Assess and rank journals for a manuscript, including submission strategy after rejection and a second opinion on a named target venue.",
    "scientific-figures": "Audit or produce publication-ready plots, schematics, tables, equations, and algorithm listings as a coherent manuscript visual system.",
    "submission-integrity": "Audit a manuscript before submission for reference errors, self-overlap, text recycling, and passages too close to cited sources.",
    "review-response": "Analyze reviewer comments and draft a professional point-by-point rebuttal or revision response for an academic manuscript.",
    "paper-review": "Write a rigorous referee report for someone else's manuscript or evaluate a revision against an earlier review. Do not use for the user's own draft.",
    "graphify": "Query or update a repository knowledge graph when graphify-out exists, or build a persistent graph from code, documents, papers, images, or video.",
    "daily-coding": "Apply the user's concise coding checklist when writing or modifying source code.",
    "writing-anti-ai": "Edit English or Chinese prose to remove recurring AI-writing patterns and make the result sound natural while preserving meaning and evidence.",
    "venue-templates": "Find and apply venue-specific LaTeX templates and submission formatting for major journals, conferences, posters, and grant proposals.",
    "timesfm-forecasting": "Run zero-shot univariate time-series forecasting with TimesFM, including environment preflight, point forecasts, and prediction intervals.",
    "skill-development": "Create, repair, or reorganize a local skill, improve its trigger description, and verify that its bundled resources and references are coherent.",
    "abstract-writing": "Draft or audit an academic abstract for transportation, civil engineering, AI/ML, or urban analytics, with sentence and word-budget checks.",
    "manuscript-pipeline": "Reconcile the manuscript tracker with the papers repository and Git history to report current submissions, inactivity, and inconsistencies.",
    "results-analysis": "Analyze experimental results with rigorous statistics, model comparisons, significance tests, ablations, and scientific figures.",
    "results-report": "Turn completed experiment artifacts into a structured results report with evidence, interpretation, decisions, and project-memory updates.",
    "paper-lookup": "Search scholarly databases for papers, metadata, citations, abstracts, full text, and open-access copies, or test whether a research idea is novel.",
    "research-ideation": "Develop research questions through literature discovery, gap analysis, method selection, and an actionable research plan.",
    "citation-verification": "Verify academic citations and references for bibliographic accuracy, source support, accessibility, and fabricated or mismatched claims.",
    "obsidian-project-memory": "Maintain a filesystem-first Obsidian knowledge base for a research project, including durable context, plans, experiments, results, and writing.",
    "obsidian-project-bootstrap": "Create or import a research repository into the user's Obsidian project knowledge base and establish its local binding.",
    "obsidian-research-log": "Record research progress, plans, meetings, milestones, and TODOs in the project's Obsidian daily notes and hub.",
    "obsidian-experiment-log": "Record experiment designs, runs, baselines, metrics, failures, ablations, and interpretations in Obsidian project notes.",
    "obsidian-literature-workflow": "Normalize paper notes and synthesize literature inside the filesystem-first Obsidian project knowledge base, including its literature canvas.",
    "obsidian-project-lifecycle": "Detach, archive, purge, rename, or rebuild an Obsidian project knowledge base using the bundled lifecycle workflow.",
    "zotero-obsidian-bridge": "Move Zotero collections, metadata, and full text into durable Obsidian paper notes and refresh the project literature canvas.",
    "lecture-gate": "Run an independent acceptance review of a Quarto RevealJS deck for the user's AI-applied-to-transportation course before teaching it.",
    "lecture-currency": "Scan lecture decks for time-sensitive claims, model names, prices, or facts that may have become outdated between semesters.",
}
REPLACEMENTS = (
    ("${CLAUDE_PLUGIN_ROOT}/skills/", "~/.agents/skills/"),
    ("$CLAUDE_PLUGIN_ROOT/skills/", "~/.agents/skills/"),
    ("~/.claude/skills/", "~/.agents/skills/"),
    ("~/.claude/skills", "~/.agents/skills"),
    ("Claude Code", "Codex"),
    ("AskUserQuestion", "ask the user"),
    ("TodoWrite", "task tracking"),
    ("WebSearch", "web search"),
    ("WebFetch", "open or fetch the source"),
)
SPECIAL_REPLACEMENTS = {
    "git-workflow": (
        ("<<<<<<< HEAD", " <<<<<<< HEAD"),
        ("\n=======\n", "\n =======\n"),
        (">>>>>>> feature/user-management", " >>>>>>> feature/user-management"),
    ),
    "docx": (("Claude", "Codex"),),
    "review-response": (
        ("with Claude", "with Codex"),
        ("Claude automatically", "Codex automatically"),
    ),
    "skill-development": (
        ("create or repair Claude skills", "create or repair skills"),
        (
            "- `references/skill-creator-original.md` - legacy background reference; use for context, not as the live source of truth\n",
            "",
        ),
    ),
    "graphify": (
        (
            "## For the commit hook and native CLAUDE.md integration",
            "## For the commit hook and optional Claude integration",
        ),
        (
            "Run once per project to make graphify always-on in Codex sessions:",
            "This command configures Claude Code only. For Codex, place equivalent graph-first instructions in the project's `AGENTS.md`:",
        ),
    ),
}
DROPPED_PATHS = {
    "skill-development": ("references/skill-creator-original.md",),
}


def selected_skills(path: Path) -> list[str]:
    skills = []
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if line and not line.startswith("#"):
            skills.append(line)
    if len(skills) != 30:
        raise SystemExit(f"expected 30 skills in {path}, found {len(skills)}")
    if len(set(skills)) != len(skills):
        raise SystemExit(f"duplicate skill name in {path}")
    return skills


def split_skill_file(text: str, path: Path) -> tuple[str, str]:
    if not text.startswith("---\n"):
        raise SystemExit(f"missing YAML frontmatter: {path}")
    end = text.find("\n---\n", 4)
    if end < 0:
        raise SystemExit(f"unterminated YAML frontmatter: {path}")
    return text[4:end], text[end + 5 :]


def fallback_identity(frontmatter: str, path: Path) -> dict[str, str]:
    name_match = re.search(r"(?m)^name:\s*(.+?)\s*$", frontmatter)
    description_match = re.search(r"(?m)^description:\s*(.+?)\s*$", frontmatter)
    if not name_match or not description_match:
        raise SystemExit(f"could not recover name and description: {path}")
    description = description_match.group(1).strip().strip("'\"")
    return {"name": name_match.group(1).strip().strip("'\""), "description": description}


def normalize_skill_file(path: Path, slug: str) -> None:
    frontmatter_text, body = split_skill_file(path.read_text(encoding="utf-8"), path)
    try:
        parsed = yaml.safe_load(frontmatter_text) or {}
    except yaml.YAMLError:
        parsed = fallback_identity(frontmatter_text, path)
    if not isinstance(parsed, dict):
        raise SystemExit(f"frontmatter is not a mapping: {path}")

    normalized = {key: parsed[key] for key in ALLOWED_FRONTMATTER if key in parsed}
    normalized["name"] = slug
    description = normalized.get("description")
    if not isinstance(description, str) or not description.strip():
        raise SystemExit(f"missing description: {path}")
    normalized["description"] = DESCRIPTION_OVERRIDES.get(slug, " ".join(description.split()))

    metadata = normalized.get("metadata")
    if not isinstance(metadata, dict):
        metadata = {}
    metadata["codex-migrated-from"] = f"dotfiles/claude/skills/{slug}"
    normalized["metadata"] = metadata

    dumped = yaml.safe_dump(
        normalized,
        allow_unicode=True,
        sort_keys=False,
        width=1000,
    ).strip()
    path.write_text(f"---\n{dumped}\n---\n\n{body.lstrip()}", encoding="utf-8")


def adapt_text_files(skill_dir: Path, slug: str) -> None:
    for path in skill_dir.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        text = path.read_text(encoding="utf-8")
        adapted = text
        for old, new in REPLACEMENTS:
            adapted = adapted.replace(old, new)
        for old, new in SPECIAL_REPLACEMENTS.get(slug, ()):
            adapted = adapted.replace(old, new)
        adapted = re.sub(
            r"/home/[^/\s\"']+/\.claude/skills/",
            "~/.agents/skills/",
            adapted,
        )
        if adapted != text:
            path.write_text(adapted, encoding="utf-8")


def normalize_text_files(skill_dir: Path) -> None:
    """Normalize generated text without touching binary skill resources."""
    for path in skill_dir.rglob("*"):
        if not path.is_file():
            continue
        raw = path.read_bytes()
        if b"\0" in raw:
            continue
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            continue
        normalized = text.replace("\r\n", "\n").replace("\r", "\n")
        if path.suffix.lower() in TRAILING_WHITESPACE_SAFE_SUFFIXES:
            normalized = "\n".join(line.rstrip(" \t") for line in normalized.split("\n"))
        if normalized:
            normalized = normalized.rstrip("\n") + "\n"
        encoded = normalized.encode("utf-8")
        if encoded != raw:
            path.write_bytes(encoded)


def ignored(_directory: str, names: list[str]) -> set[str]:
    return {
        name
        for name in names
        if name in IGNORED_NAMES or name.endswith((".pyc", ".pyo"))
    }


def clone_skill(source_root: Path, destination_root: Path, slug: str) -> None:
    source = source_root / slug
    destination = destination_root / slug
    if not (source / "SKILL.md").is_file():
        raise SystemExit(f"source skill missing: {source / 'SKILL.md'}")
    if destination.exists() or destination.is_symlink():
        if destination.is_symlink() or destination.is_file():
            destination.unlink()
        else:
            shutil.rmtree(destination)
    shutil.copytree(source, destination, ignore=ignored)
    adapt_text_files(destination, slug)
    for relative_path in DROPPED_PATHS.get(slug, ()):
        path = destination / relative_path
        if path.exists():
            path.unlink()
    normalize_skill_file(destination / "SKILL.md", slug)
    normalize_text_files(destination)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    repo = args.repo.resolve()
    source_root = repo / "dotfiles/claude/skills"
    destination_root = repo / "dotfiles/codex/skills"
    manifest = repo / "dotfiles/codex/skills.txt"
    destination_root.mkdir(parents=True, exist_ok=True)

    for number, slug in enumerate(selected_skills(manifest), start=1):
        clone_skill(source_root, destination_root, slug)
        print(f"{number:02d}. {slug}: cloned and optimized")


if __name__ == "__main__":
    main()
