# Workspace Harness Component: Conversation Freezing & Context Compaction
> **Component Identifier:** `core-utilities/conversation`  
> **Target Path in Target Repository:** `.agents/rules/conversation-freezing.md` (manages `.agents/conversations/`)

---

<!-- SECTION:conversation-persistence-principle:START -->
## 1. The Context Externalization Principle
Chat history is ephemeral; disk state is durable. An agent MUST NOT rely on conversation memory across chat sessions.
Whenever a chat reaches a natural milestone, context compaction threshold, or when the user invokes `/freeze-conversation`:
1. The conversation's essential context is frozen into a dedicated file at `.agents/conversations/YYYY-MM-DD_HHmm-<conversation-slug>.md`.
2. The frozen artifact externalizes state into structured markdown with internal cross-references.
3. The new conversation thread resumes simply by reading the frozen context file.
<!-- SECTION:conversation-persistence-principle:END -->

---

<!-- SECTION:freeze-file-structure:START -->
## 2. Standardized Frozen Conversation Structure
Every file in `.agents/conversations/` MUST follow this progressive-fidelity structure:

### A. Metadata & State of the Union
- **Timestamp & Thread Slug:** Exact creation date, compact time, and descriptive slug.
- **Current Status:** What is being done right now, what was just finished, what is next.
- **Active Troubles & Blockers:** Any unresolved problems, confusing points, or technical debt.

### B. High-Fidelity Recent Context (Near-Term Turns)
- Detail increases toward the most recent messages:
  - The last 3–5 turns MUST be captured in high fidelity (verbatim user goals, exact constraints, nuanced instructions).
  - Older turns are compressed into compact bullet points of established facts.

### C. Internal Artifact References (No Brittle Code Lines)
- MUST link to internal project artifacts using relative markdown links:
  - Notes: `.agents/notes/YYYY-MM-DD_HHmm-<topic>.md`
  - Decisions: `.agents/decisions/YYYY-MM-DD_HHmm-<decision>.md`
  - Plans: `.agents/plans/YYYY-MM-DD_HHmm-plan-<plan>.md`
  - Context & Glossary: `.agents/rules/GLOSSARY.md`
- AVOID linking to raw source code line numbers (e.g. `src/file.ts#L45`), which easily drift or break upon edits.

### D. Zero-Loss Handoff Kickoff Prompt
- The file MUST conclude with a self-contained copy-pasteable prompt for the new chat session.
<!-- SECTION:freeze-file-structure:END -->

---

<!-- SECTION:naming-and-lifecycle:START -->
## 3. Naming & Lifecycle Rules
- **Naming Pattern:** `.agents/conversations/YYYY-MM-DD_HHmm-<conversation-name>.md`.
- **Retention:** Kept as historical context snapshots. Never deleted unless explicitly purged by the user.
<!-- SECTION:naming-and-lifecycle:END -->
