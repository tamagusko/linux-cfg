---
description: Query the personal knowledge base wiki to answer research questions
---

# KB Query

Answer questions by researching the knowledge base at `~/repos/papers/kb/`.

## Instructions

1. **Read the schema**
   - Read `kb/SCHEMA.md` for structure and conventions

2. **Understand the question**
   - The user's question follows this command: $ARGUMENTS
   - Determine which parts of the wiki are relevant

3. **Research the wiki**
   - Start with `kb/wiki/_index.md` to identify relevant papers
   - Read relevant `kb/wiki/papers/*.md` articles
   - Read relevant `kb/wiki/concepts/*.md` articles
   - If needed, go deeper into `kb/raw/` for full paper text
   - Cross-reference findings across multiple articles

4. **Synthesize the answer**
   - Cite specific papers using wikilinks: [[paper-name]]
   - Quote actual findings and numbers from the wiki
   - If the wiki doesn't contain enough information, say so explicitly
   - Never fabricate information not found in the KB

5. **Output format**
   - Answer directly in the conversation
   - If the answer is substantial, offer to save it as a new wiki page
   - If the question reveals a gap in the KB, note it as a lint suggestion

6. **Example queries**
   - "What methods have I used across all pavement papers?"
   - "What are the gaps in my cycling safety work?"
   - "Draft a related work section using my publications"
   - "Which of my papers could I cite for a proposal on urban mobility?"
   - "What is the progression of my ML methods from 2020 to 2026?"
   - "Who have I collaborated with most?"
