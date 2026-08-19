---
description: Ingest a new paper into the personal knowledge base wiki
---

# KB Ingest

Add a new paper to the knowledge base at `~/repos/papers/kb/`.

## Instructions

1. **Read the schema**
   - Read `kb/SCHEMA.md` for conventions and templates

2. **Identify the source**
   - If the user provides a PDF path, extract it to markdown using pymupdf4llm
   - If the user provides a LaTeX file, copy it directly
   - If the user provides a paper title/DOI, search Semantic Scholar for metadata
   - Save the raw extraction to `kb/raw/`

3. **Extract metadata**
   - Title, authors, venue, year, citation count
   - Use Semantic Scholar API if needed: `https://api.semanticscholar.org/graph/v1/paper/search?query=TITLE&fields=title,authors,year,venue,citationCount,abstract`

4. **Create the paper article**
   - Follow the Paper Article template from SCHEMA.md
   - File: `kb/wiki/papers/YYYY-short-title.md`
   - Extract real abstract, contributions, methods, findings from the raw text
   - NEVER fabricate content — only use what's in the paper

5. **Update the wiki**
   - Add entry to `kb/wiki/_index.md` (maintain chronological order)
   - Identify which concept pages in `kb/wiki/concepts/` are relevant
   - Update those concept pages with references to the new paper
   - Add wikilinks to/from related existing papers
   - Update `kb/wiki/meta/collaborators.md` if new co-authors
   - Update `kb/wiki/meta/venues.md` if new venue
   - Update `kb/wiki/_timeline.md` if it changes the research narrative

6. **Report**
   - Show what was created and updated
   - List all new wikilinks added
