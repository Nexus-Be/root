---
name: setup-yuikit
description: Interactive setup checklist for provisioning or referencing Yui's Agent Workspace Harness (utilities, skills, tools, templates) into the target repository. Safely merges navigation guidance into AGENTS.md without conflicts. Use for /setup-yuikit, /setup-workspace-yuikit, "setup yuikit", or "install agent harness".
---

# Setup YuiKit (`/setup-yuikit`)
> **Companion File (Vietnamese):** [`SKILL.vi.md`](SKILL.vi.md)  
> **Authoritative English Specification**

Provisions, references, or initializes standardized AI Agent workspace utilities, skills, tools, and starter templates from Yui's Agent Kit into the current repository (or a designated directory).

---

## Execution Spine for the Agent

### Step 1: Detect Target Workspace & Mode Selection
1. **Target Path:** Defaults to the active repository root (`.`), or a user-specified path.
2. **Inspect Existing Instructions:** Check if `AGENTS.md` or `AGENT.md` already exists.
3. **Usage vs Download Mode:**
   - **Use / Reference Mode:** If the user only wants to reference global harness utilities without copying full asset files, configure pointers directly in `AGENTS.md`.
   - **Download / Provision Mode (Default):** Copy clean active rules (`compiled.md`), starter templates, and tools directly into the target `.agents/` workspace.

---

### Step 2: Present Workspace Assets Checklist
Present an interactive checklist for the user to choose which assets to install or reference:

#### A. Pre-configured Presets
- **Preset 1: Full Workspace Harness (Full - 16 packages)**
  - All 8 Core Utilities (`note`, `decision`, `doc`, `plan`, `skill`, `context`, `conversation`, `rule`).
  - All Standard Starter Templates (`notes`, `decisions`, `plans`, `glossary`, `spec-kit`).
  - Essential Skills (`setup-yuikit`, `optimize-yuikit`, `writing-yuiskill`, `freeze-conversation`, `yui-router`).
  - Standard Tools (`init-repo.sh`, `agent-pack.sh`, `compile-component.py`).
- **Preset 2: Core Workspace (Core - 14 packages)**
  - Essential operational utilities without experimental rules.
  - Standard starter templates and skills.
- **Preset 3: Token-Saving Workspace (Lean - 9 packages)**
  - Minimal execution footprint (`note`, `decision`, `plan`, `context`, `conversation`, router, starter templates).

#### B. Custom Component Selection
The user may also select individual items across categories:
- **Core Utilities (`core-utilities/`):** `note/`, `decision/`, `doc/`, `plan/`, `skill/`, `context/`, `conversation/`, `rule/`.
- **System Skills (`skills/`):** `setup-yuikit/`, `optimize-yuikit/`, `writing-yuiskill/`, `freeze-conversation/`, `yui-router/`.
- **Automation Tools (`tools/`):** `init-repo.sh`, `agent-pack.sh`, `compile-component.py`.
- **Starter Templates (`core-utilities/template/`):** Notes, Decisions, Plans, Glossary, Spec-Kit.

---

### Step 3: Provision Plural Working Directories in `.agents/`
Run the installer tool or execute provisioning directly:
```bash
bash tools/init-repo.sh /path/to/target --preset full
```
*(If running outside the plugin repository, ensure `tools/init-repo.sh` is called relative to the plugin installation root or via `bash ~/.agent-kityui/tools/init-repo.sh`)*

**Automated Target Bootstrapping:**
The installer automatically creates all necessary plural operational directories inside the target repository:
1. `.agents/notes/` — Single-file master logs, active discussions, pending doubts memo pad.
2. `.agents/decisions/` — Immutable architecture decisions with Zero-Doubt Closure.
3. `.agents/plans/` — Phased roadmaps, micro-tasks, and Multi-Agent Checklist Handshake gates.
4. `.agents/contexts/` — Business domain context and automated 7-header SRS slots.
5. `.agents/conversations/` — Frozen and compacted session context archives.
6. `.agents/skills/` — Custom project-specific AI Agent skills.
7. `.agents/rules/` — Active runtime rules compiled cleanly from YuiKit.
8. `docs/` — Human-facing guides, diagrams, and manual test scripts.

> **Cleanliness Guarantee:**
> The plugin repository (`agent-kityui`) does not ship with empty `records/` folders. All working folders are created dynamically in the target workspace during setup.

**Asset Copy & Catalog Generation:**
1. Copy ONLY clean `compiled.md` files as active rules inside `.agents/rules/`.
2. Copy selected templates into their respective folders.
3. Preserve any pre-existing user template files (never overwriting custom templates).
4. Generate `.agents/catalog.json` and `.agents/CATALOG.md` indexing installed utilities.

---

### Step 4: Non-Destructive `AGENTS.md` Merge
- **If `AGENTS.md` does not exist:** Create a new file with the YuiKit harness block.
- **If `AGENTS.md` exists with tags:** Update only the block between `<!-- YUI-AGENT-KIT:START -->` and `<!-- YUI-AGENT-KIT:END -->`.
- **If `AGENTS.md` exists without tags:** Append the block to the end of the file after a `---` separator. All user custom rules remain 100% intact.

---

### Step 5: Verification & Report
1. Confirm exactly 1 tagged block in `AGENTS.md`.
2. Verify all markdown links in `.agents/CATALOG.md` resolve to existing files.
3. Report a compact summary to the user.
