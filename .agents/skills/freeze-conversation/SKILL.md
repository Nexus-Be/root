---
name: freeze-conversation
description: Freeze and compact the current conversation context into a durable artifact under .agents/conversations/. Compresses older turns, preserves high-fidelity recent context with internal file references, and generates a zero-loss kickoff prompt for the next chat session. Use for /freeze-conversation, "compact conversation", "freeze context", or "session handoff".
---

# Freeze Conversation (`/freeze-conversation`)

A dedicated workflow to compress, externalize, and freeze the active conversation state into a durable file within `.agents/conversations/` so a new agent session can resume work without memory loss or context amnesia.

---

## Execution Spine for the Agent

### Step 1: Synthesize State of the Union
Collect and structure the four essential operational dimensions:
1. **Full Context & Problem Space:** What is the overarching architecture, goal, and paradigm?
2. **Execution State:**
   - What has been done? (Completed tasks and established facts).
   - What is actively in progress right now? (Current uncommitted work or partial edits).
   - What will be done next? (Immediate upcoming tasks).
3. **Obstacles & Resolutions:**
   - What roadblocks, bugs, or misunderstandings were encountered?
   - How were they resolved?
   - What unresolved issues or pending doubts remain?

---

### Step 2: Apply Tiered Granularity
Structure the conversation narrative using progressive resolution:
- **Historical Turns (Early in session):** Compress into compact factual bullet points.
- **Recent Turns (Last 3–5 messages):** Retain high-fidelity detail: verbatim user instructions, exact constraints, nuances, and specific instructions that must not be lost.

---

### Step 3: Establish Internal Artifact References
Ground the summary strictly in durable project files using relative markdown links:
- Notes: `.agents/notes/YYYY-MM-DD_HHmm-<topic>.md`
- Decisions: `.agents/decisions/YYYY-MM-DD_HHmm-<decision>.md`
- Plans: `.agents/plans/YYYY-MM-DD_HHmm-plan-<plan>.md`
- Glossary: `.agents/rules/GLOSSARY.md`
- Inventory: `docs/DANH_MUC_TRIEN_KHAI.md`
*AVOID referencing source code line numbers directly to prevent link drift.*

---

### Step 4: Write Frozen Artifact & Generate Kickoff Prompt
1. Write the compiled context to `.agents/conversations/YYYY-MM-DD_HHmm-<conversation-slug>.md`.
2. Format a copy-pasteable Kickoff Prompt at the conclusion of the file and present it prominently in chat for the user to paste into the next conversation window.
