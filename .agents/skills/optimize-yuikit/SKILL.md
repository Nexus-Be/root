---
name: optimize-yuikit
description: Interactive workflow for optimizing and updating YuiKit tools, skills, utilities, or rules. Supports local-only repo overrides without records, and global plugin updates via on-demand records and compilation. Use for /optimize-yuikit, /customize-yuikit, /update-yuikit, "optimize yuikit", or "update harness".
---

# Optimize YuiKit (`/optimize-yuikit`)
> **Companion File (Vietnamese):** [`SKILL.vi.md`](SKILL.vi.md)  
> **Authoritative English Specification**

Guides users through tailoring, optimizing, or updating any asset in Yui's Agent Kit (Tools, Skills, Utilities, or Rules) across two distinct operational scopes: **Local (Current Workspace Only)** vs **Global (Plugin Repository)**.

---

## Component Architecture & Structural Distinction

Before performing any optimization, the Agent must recognize the structural differences among asset types:

| Asset Type | Standard Structure | Special Handling |
| :--- | :--- | :--- |
| **Core Utilities (`core-utilities/`)** | `default.md`, `template.md`, `compiled.md`, `records/` (on-demand) | Full component structure. Guided by `template.md`. |
| **Rules (`core-utilities/rule/`)** | `default.md`, `template.md`, `compiled.md`, `records/` (on-demand) | Experimental coding standards component. |
| **Tools (`tools/`)** | Scripts (`init-repo.sh`, `agent-pack.sh`, `compile-component.py`) | Automation levers. |
| **Skills (`skills/`)** | **`SKILL.md` ONLY** (+ companion `SKILL.vi.md` if authored) | **NO `template.md`, NO `records/`, NO `default.md`, NO `compiled.md`**. Standalone executable skill definitions. |

---

## Execution Spine for the Agent

### Step 1: Identify Asset Type & Specific Target
Ask or detect which asset the user intends to optimize:
1. **Tool:** Automation scripts (`init-repo.sh`, `agent-pack.sh`, `compile-component.py`).
2. **Skill:** Agent skill definitions (e.g. `setup-yuikit`, `writing-yuiskill`, `freeze-conversation`, `yui-router`, or project-specific skills).
3. **Core Utility / Component:** Workspace utilities (`note`, `decision`, `doc`, `plan`, `context`, `conversation`).
4. **Rule:** Technical coding standards (`rule`).

---

### Step 2: Determine Update Scope (Local vs Global)

The user can explicitly specify whether the update applies **Locally (active repo only)** or **Globally (the plugin repository)**:

```
[ User requests optimization ]
             │
             ├── Is it a SKILL? ───────► Always LOCAL to active repo (.agents/skills/<name>/SKILL.md)
             │
             └── Is it a Utility / Tool / Rule?
                           │
             ┌─────────────┴─────────────┐
             ▼                           ▼
      [ LOCAL Scope ]             [ GLOBAL Scope ]
  (Default for active repo)   (Only when explicitly requested)
             │                           │
  - Read template.md guidance  - Ensure records/ exists on-demand
  - NO record created          - Create YYYY-MM-DD-XX-<slug>.md
  - Overwrite directly in      - Run compile-component.py
    active repo .agents/rules/ - Update compiled.md in plugin kit
```

---

### Step 3: Execution Paths Based on Scope

#### Path A: Optimizing a SKILL (Always Local to Current Repo)
- **Skill Characteristics:** Skills do **NOT** have templates, records, or compiled files.
- **Action:** Create or modify the skill file directly inside the current repository at `.agents/skills/<skill-name>/SKILL.md`.
- **Isolation Guarantee:** The update applies exclusively to the active repository. The global plugin repository remains completely untouched.

#### Path B: Optimizing Utilities / Rules / Tools — LOCAL SCOPE (Default)
When customizing for the current repository only:
1. **Guidance from Template:** Read `template.md` in `core-utilities/<component>/` to inspect **Safe Levers** and **Invariants** to provide informed advice.
2. **No Records Created:** Do **NOT** create any `records/` folder or record markdown files.
3. **Direct Overwrite in Repo:** Write the customized content directly into the active repository (e.g. `.agents/rules/<component>-management.md` or `.agents/rules/<component>.md`).
4. **Global Plugin Untouched:** The central plugin repository (`agent-kityui`) does not record or inherit this local override.

#### Path C: Optimizing Utilities / Rules / Tools — GLOBAL SCOPE (Plugin Update)
Triggered **ONLY** when the user explicitly instructs to update the global plugin repository itself:
1. **Ensure `records/` Directory On-Demand:**
   ```bash
   mkdir -p core-utilities/<component>/records
   ```
2. **Author Override Record:** Create a structured record file at:
   `core-utilities/<component>/records/YYYY-MM-DD-XX-<slug>.md`
3. **Execute Compiler Lever:**
   ```bash
   python3 tools/compile-component.py <component>
   ```
   *(Or via `python3 ~/.agent-kityui/tools/compile-component.py <component>` if calling from an external terminal)*
4. **Verify Clean Compilation:** Ensure `compiled.md` reflects the changes without redundant separators or broken headers.

---

### Step 4: Verification & Report
1. Verify syntax and link integrity of the updated file.
2. If companion files (`*.vi.md`) exist or are created, synchronize them and register into `VI_FILES.md`.
3. Report the updated file location and operational scope clearly to the user.
