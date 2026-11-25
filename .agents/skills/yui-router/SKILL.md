---
name: yui-router
description: Intelligent context router for Yui Agent Kit. Analyzes user task intent and dispatches to the exact workspace utility, skill, or template without loading unnecessary files. Use for /yui-router, /route, or when determining what workflow rules apply to a task.
---

# Yui Skill Router (`/yui-router`)

Intelligent context router that classifies user intent and dynamically activates the matching workspace utility or skill under the **Progressive Disclosure** model.

---

## 🧭 Context Dispatch Matrix

When receiving a user prompt, the Agent evaluates the request against this matrix:

| User Intent | Slash Command | Target Utility / File to Load | Mandatory Action |
| :--- | :--- | :--- | :--- |
| **Requirements analysis, business logic, SRS** | `/srs` or `/context` | `.agents/contexts/business-context.md` | Slot conversation into matching 7-header SRS structure. |
| **Explicit request to log session notes, scratchpads, doubts** | `/note` | `.agents/notes/YYYY-MM-DD_HHmm-<topic>.md` | Record turn ONLY upon explicit instruction; do NOT auto-write on casual chat. |
| **Settling a decision, finalizing options** | `/decision` | `.agents/decisions/YYYY-MM-DD_HHmm-<decision>.md` | Check notes for pending doubts (Zero-Doubt Closure), lock invariants. |
| **Roadmaps, phased planning, task breakdown** | `/plan` | `.agents/plans/YYYY-MM-DD_HHmm-plan-<plan>.md` | Phases ➔ Tasks ➔ Multi-Agent Checklist Handshake gates. |
| **Human documentation, user guides, manual tests** | `/doc` | `docs/share/<slug>.md` or `docs/repo/<slug>.md` | Bifurcated docs: share docs (zero repo links, plain prose) vs repo docs (codebase links). Clean delivery. |
| **Authoring a new internal agent skill** | `/writing-yuiskill` | `.agents/skills/writing-yuiskill/SKILL.md` | Scaffold `.agents/skills/<name>/SKILL.md` with valid YAML frontmatter. |
| **Harness navigation, general guidance, how to use YuiKit** | `/helpme-yui` | `skills/helpme-yui/SKILL.md` | Central advisor: diagnose problem, cite rules, and provide ready-to-run prompts. |
| **Provisioning or referencing harness into repo** | `/setup-yuikit` | `.agents/skills/setup-yuikit/SKILL.md` | Display interactive utilities checklist, merge safely into `AGENTS.md`. |
| **Optimizing or updating workspace harness (Local/Global)** | `/optimize-yuikit` | `.agents/skills/optimize-yuikit/SKILL.md` | Optimize tools, skills, utilities, or rules (local override without records vs global update). |
| **Freezing & compacting session context** | `/freeze-conversation` | `.agents/skills/freeze-conversation/SKILL.md` | Freeze context into `.agents/conversations/YYYY-MM-DD_HHmm-<slug>.md`. |
| **Clarifying ambiguous business terms** | `/glossary` | `.agents/rules/GLOSSARY.template.md` | Halt execution, elicit two-way definition, commit to glossary. |
| **Token budget & progressive disclosure** | `/token` or `/tier` | `.agents/rules/note-management.md` | Grep/Offset navigation, avoid reading >300 lines, single-file logging. |

---

## ⚡ Progressive Disclosure Execution

1. **Acknowledge in 1 sentence:** Notify the user which utility or rule is activated.
2. **Load exactly 1 file:** Open strictly the file required for the task.
3. **Persist state (strictly upon explicit instruction or official milestone):**
   - Notes ➔ `.agents/notes/YYYY-MM-DD_HHmm-<topic>.md` (only when user asks to record note/log)
   - Decisions ➔ `.agents/decisions/YYYY-MM-DD_HHmm-<decision>.md`
   - Plans ➔ `.agents/plans/YYYY-MM-DD_HHmm-plan-<plan>.md`
   - Docs ➔ `docs/share/<slug>.md` (external, self-contained) or `docs/repo/<slug>.md` (internal)
