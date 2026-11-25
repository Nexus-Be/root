---
name: helpme-yui
description: Central navigator and advisor for Yui Agent Kit (YuiKit). Analyzes user goals, maps requests to the exact utility, skill, tool, or playbook, explains the rationale, and provides ready-to-run prompts. Use for /helpme-yui, "helpme yui", "yuikit help", or "how to use yuikit".
---

# YuiKit Help & Navigator (`/helpme-yui`)
> **Companion File (Vietnamese):** [`SKILL.vi.md`](SKILL.vi.md)  
> **Authoritative English Specification**

Answers user questions about Yui Agent Kit (`agent-kityui`), diagnoses their current engineering problem, points to the authoritative rule or utility file, and hands them a concrete, ready-to-send prompt or slash command.

---

## Non-Negotiable Invariants

1. **Advisory Gate (Never Prematurely Execute):**  
   When invoked via `/helpme-yui` or a consultation question (e.g. *"how do I do X in YuiKit?"*), the agent **must not** modify source code, create git branches, or start long-running tasks. The agent acts purely as an architect and advisor, handing the user a verified prompt or command to execute intentionally.
2. **Deterministic Source Linking:**  
   Every recommendation must cite the exact markdown file or utility path (e.g., `core-utilities/workflow/compiled.md#1-feature-playbook` or `skills/your-desire/SKILL.md`).
3. **Actionable Handoff:**  
   Conclude every guidance with a clear, self-contained prompt block that the user can copy or send directly in the conversation.

---

## 🧭 The 5 Core Consultation Tracks

When a user asks a question, classify their intent into one of the following 5 tracks:

### Track 1: Starting a Real Task (Code, Bug, Refactoring)
- **Primary Entry Point:** `/your-desire` (`skills/your-desire/SKILL.md`)
- **Core Mechanism:** Gathers the 4 intake coordinates:
  1. **Scale:** `Small` (1-3 files), `Medium` (slice/component), `Large` (multi-phase).
  2. **Goal:** Measurable end state or defect to remove.
  3. **Scope:** Explicit files allowed to be edited; out-of-scope files forbidden.
  4. **Acceptance:** Command output proving success (Exit Code 0).
- **Associated Engineering Playbooks (`core-utilities/workflow/compiled.md`):**
  - **New Feature:** Domain Model first ➔ Failing Test (TDD Red) ➔ Vertical Slice (Green) ➔ Proof-of-Work.
  - **Bug Fix:** Runtime evidence ➔ Automated Repro Test first ➔ Binary-search root cause ➔ Minimal surgical fix ➔ Zero regression proof.
  - **Refactoring:** Pin behavior via characterization tests ➔ Subtract dead weight first ➔ Atomic steps ➔ Cascading reference check.
- **Ready Prompt Handoff:**
  ```text
  /your-desire
  Goal: <state what to build or fix>
  Scale: <Small | Medium | Large>
  Scope: <target files or directories>
  Acceptance: <test command or exit code 0 criteria>
  ```

---

### Track 2: Subagent Teams & Orchestration
- **Global Configuration File:** `~/.agent-kityui/teams.json`
- **Web Dashboard:** `/setup-team` (`skills/setup-team/SKILL.md`)
  - Launches local daemon server on `http://localhost:56123`.
  - Visual team roster, Lead Orchestrator assignment, and custom role descriptions.
- **CLI Fast Switcher:** `/choose-team` (`skills/choose-team/SKILL.md`)
  - Quick, zero-browser team selector directly in chat.
- **Execution Modes:**
  - `multi_agent`: Lead Orchestrator delegates tasks to specialized subagents (`Builder Coder`, `Bug Hunter`, `Zero-Doubt Auditor`).
  - `single_agent`: Main Chat Agent handles the entire workflow sequentially to prevent style drift and preserve uniform code aesthetics.
- **Dynamic Role Substitution:** If the active team lacks a required role, the Chat Agent autonomously assumes that role with explicit log tagging `[Self-Executed: <Role>]`.

---

### Track 3: Memory, Notes, Decisions & Documentation
- **Session Scratchpad & Active Thoughts:** `.agents/notes/YYYY-MM-DD_HHmm-<topic>.md`  
  *Rule:* Single-file master note per topic. Captures open doubts (Pending Doubts). Do not auto-generate notes for simple one-off queries.
- **Locking Invariants & Decisions:** `.agents/decisions/YYYY-MM-DD_HHmm-<decision>.md`  
  *Rule:* Zero-Doubt Closure. 100% of pending doubts in note must be resolved before finalizing a decision.
- **Phased Roadmaps & Handshakes:** `.agents/plans/YYYY-MM-DD_HHmm-plan-<plan>.md`  
  *Rule:* Hierarchical phases ➔ tasks ➔ checklist. Multi-agent handshake: only the final synthesizing agent checks `[x]`.
- **Bifurcated Documentation System (`core-utilities/doc/compiled.md`):**
  - `docs/share/<slug>.md`: Audience without repo access. Strictly self-contained, plain language, zero internal code/repo links.
  - `docs/repo/<slug>.md`: Project members with repo access. Deep links to source interfaces and folders encouraged.
  - *Clean Delivery Mode:* Strips internal AI scratchpads, timestamps, and prompt tags.
- **Business Requirements & Context:** `.agents/contexts/business-context.md` (SRS 7 standard headers).

---

### Track 4: Harness Extension & Project Scaffolding
- **Initialize Harness in Target Repo:** `/setup-yuikit` (`skills/setup-yuikit/SKILL.md`)
  - Provisions presets: `full` (16 packages), `core` (14 packages), or `lean` (9 packages).
  - Merges safe pointers into `AGENTS.md` without polluting preexisting instructions.
- **Author Internal Skills for Repo:** `/writing-yuiskill` (`skills/writing-yuiskill/SKILL.md`)
  - Generates `.agents/skills/<name>/SKILL.md` with valid YAML frontmatter and execution steps.
- **Optimize or Update Harness Assets:** `/optimize-yuikit` (`skills/optimize-yuikit/SKILL.md`)
  - Differentiates between Local overrides (workspace only) and Global updates (`records/` compilation).
- **Freeze & Compact Long Conversations:** `/freeze-conversation` (`skills/freeze-conversation/SKILL.md`)
  - Compresses conversation history into structured artifacts under `.agents/conversations/`.

---

### Track 5: Troubleshooting Common Agent Issues
| Symptom / Failure Mode | Root Cause | YuiKit Solution & Fix |
| :--- | :--- | :--- |
| **Agent crashes or context overflows** | Dumping full files or terminal dumps into the main thread | Use compact file pointers (`.agents/notes/`, `.agents/plans/`) and isolated sandbox tasks. |
| **Agent stops prematurely (`turn_ended`)** | Ending a turn with a confirmation question or an empty tool call | Issue a direct action command; never wait for unnecessary approval on reversible steps. |
| **Checklist marked `[x]` without proof** | Hallucinated completion or untested assumptions | Enforce Proof-of-Work: command output must show Exit Code 0 before completing. |
| **Code style inconsistency** | Uncoordinated subagents with conflicting coding conventions | Switch team execution mode to `single_agent` or assign strict project extra instructions. |

---

## ⚡ Advisory Response Template

When executing `/helpme-yui`, structure the user-facing response with these 3 sections:

1. **Diagnosis & Recommended Path:** State clearly what YuiKit component (skill, utility, or tool) fits the problem and why.
2. **Authoritative References:** List the exact source file path(s) and relevant sections.
3. **Ready-to-Send Prompt:** Provide a pre-formatted block the user can copy and run immediately.
