---
name: writing-yuiskill
description: Scaffold and author standardized internal AI Agent skills for the current project. Creates .agents/skills/<skill-name>/SKILL.md with valid YAML frontmatter, execution steps, and scripts. Use for /writing-yuiskill, "create skill", or "author agent skill".
---

# Writing Yui Skill (`/writing-yuiskill`)

A dedicated authoring workflow that creates a new, modular AI Agent skill inside the active repository (`.agents/skills/<skill-name>/`).

---

## Execution Spine for the Agent

### Step 1: Elicit Skill Scope & Trigger Conditions
Prompt the user for 4 essential attributes:
1. **Skill Name:** Kebab-case identifier (e.g. `audit-db-schema`, `generate-api-client`).
2. **Trigger Phrase / Scenario:** When should the agent automatically or manually call this skill?
3. **Inputs & Prerequisite Files:** What files, schemas, or variables must exist before execution?
4. **Step-by-Step Actions:** The ordered 3 to 5 steps the agent must follow.

---

### Step 2: Scaffold Directory & Author `SKILL.md`
Create the self-contained skill folder at `.agents/skills/<skill-name>/` with:

```markdown
---
name: <skill-name>
description: <Trigger conditions and purpose in 1-2 concise sentences>
---

# <Skill Title> (`/<skill-name>`)

## 1. Overview & Purpose
- [Brief explanation of what this workflow accomplishes]

## 2. Step-by-Step Instructions
1. **Step 1:** [Inspect and validate prerequisites]
2. **Step 2:** [Execute core logic]
3. **Step 3:** [Verify output against constraints]

## 3. Verification & Acceptance Criteria
- [Criteria showing the skill finished successfully]
```

If the skill requires helper scripts, create `.agents/skills/<skill-name>/scripts/` and make them executable.

---

### Step 3: Register in Local Project Catalog
Update `.agents/catalog.json` and append an entry to `.agents/CATALOG.md` so the new skill is immediately discoverable without restarting the session.

---

### Step 4: Verification Check Gate
1. Validate that `SKILL.md` has correct YAML frontmatter syntax.
2. Confirm the file path exists on disk: `.agents/skills/<skill-name>/SKILL.md`.
3. Inform the user that the skill is ready to be invoked via `/<skill-name>`.
