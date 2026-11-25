# Workspace Harness Component: Repository Skill Management & /writing-yuiskill
> **Component Identifier:** `core-utilities/skill`  
> **Target Path in Target Repository:** `.agents/skills/README.md`

---

<!-- SECTION:skill-directory-structure:START -->
## 1. Internal Skill Architecture & Directory Layout
Every custom skill created for a project MUST reside within `.agents/skills/<skill-name>/` following the Open Agent Skill specification:

```text
.agents/skills/<skill-name>/
├── SKILL.md            # MANDATORY: YAML frontmatter metadata and step-by-step instructions
├── scripts/            # OPTIONAL: Deterministic bash, python, or node helper scripts
└── references/         # OPTIONAL: Deep reference docs (loaded strictly on-demand)
```

### Frontmatter Schema Requirements
```markdown
---
name: <kebab-case-skill-name>
description: A concise 1-2 sentence description explaining what this skill does and the exact trigger conditions.
---
```
<!-- SECTION:skill-directory-structure:END -->

---

<!-- SECTION:scaffolding-with-writing-yuiskill:START -->
## 2. Automated Skill Scaffolding (`/writing-yuiskill`)
Users and agents do not need to construct skill files by hand. Use the dedicated skill `/writing-yuiskill`:
1. **Invocation:** `/writing-yuiskill <skill-name>`
2. **Behavior:** Prompts for trigger conditions, inputs, execution steps, and verification gates, then scaffolds `.agents/skills/<skill-name>/SKILL.md`.
3. **Registry Sync:** Automatically updates `.agents/catalog.json` and `.agents/CATALOG.md` with the new skill.
<!-- SECTION:scaffolding-with-writing-yuiskill:END -->

---

<!-- SECTION:progressive-disclosure-rules:START -->
## 3. Dynamic Context & Progressive Loading
- **Never inline into `AGENTS.md`:** Skills represent dynamic context and must NEVER be pasted directly into `AGENTS.md`.
- **On-Demand Activation:** A skill file is read into memory ONLY when the user calls its slash command (e.g. `/<skill-name>`) or when `/yui-router` matches intent.
<!-- SECTION:progressive-disclosure-rules:END -->
