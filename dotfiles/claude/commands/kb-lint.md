---
description: Run health checks on the personal knowledge base wiki
---

# KB Lint

Check the knowledge base at `~/repos/papers/kb/` for consistency, completeness, and quality issues.

## Instructions

1. **Read the schema**
   - Read `kb/SCHEMA.md` for lint rules and conventions

2. **Check structural integrity**
   - Every paper in `_index.md` has a corresponding `papers/*.md` file
   - Every `papers/*.md` file is listed in `_index.md`
   - No orphan files (wiki pages not linked from anywhere)

3. **Check wikilinks**
   - Scan all `.md` files in `kb/wiki/` for `[[...]]` links
   - Verify each link target exists as a file
   - Report broken links with file and line number

4. **Check article completeness**
   - Every paper article has: Abstract, Key Contributions, Methods, Key Findings, Related Papers, Concepts
   - Every concept article has: Definition, Tamagusko's Contributions, Key Methods, Related Concepts
   - Flag articles with missing or empty sections

5. **Check cross-references**
   - Every paper links to at least one concept
   - Every concept links to at least one paper
   - Find papers that should be linked but aren't (based on shared concepts)

6. **Check metadata consistency**
   - Citation counts in paper articles match `_index.md`
   - All co-authors in paper articles appear in `collaborators.md`
   - All venues in paper articles appear in `venues.md`
   - Timeline covers all publication years

7. **Suggest improvements**
   - Identify potential new concept pages (themes appearing in 3+ papers without a concept page)
   - Suggest missing cross-links between related papers
   - Flag stale information (e.g., citation counts that may need updating)

8. **Report**
   - Summary: total files, total links, health score
   - Issues grouped by severity: errors (broken links), warnings (missing sections), suggestions (improvements)
   - Offer to auto-fix what can be fixed
