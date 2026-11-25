---
name: your-desire
description: Master workflow launcher to kick off a task with 4-coordinate intake (Scale, Goal, Scope, Acceptance), active team delegation, dynamic role substitution, and proof-of-work verification. Use for /your-desire, "start task", "my desire", or "execute goal".
---

# Your Desire (`/your-desire`)
> **Companion File (Vietnamese):** [`SKILL.vi.md`](SKILL.vi.md)  
> **Authoritative English Specification**

The master entry-point skill for executing software tasks through the active Subagent Team. Gathers the 4 required coordinates (Scale, Goal, Scope, Acceptance Criteria), initializes a phased roadmap, delegates tasks using dynamic role substitution, and enforces proof-of-work verification before marking completion.

---

## Non-Negotiable Invariants

1. **Strict Proof-of-Work Gate:** No checklist item `[ ]` can be marked `[x]` based on conversational claims or "it compiles" assumptions. Concrete command output or test passes must be observed.
2. **Multi-Agent Checklist Handshake:** Subagents report results and file pointers; only the Lead Orchestrator marks `[x]` on the master plan checklist.
3. **Graceful Self-Execution Fallback:** If the active team lacks a required role (e.g. Coder or Auditor), the active Chat Agent automatically self-executes that role, tagging logs with `[Self-Executed: <Role>]`.
4. **Style Drift Prevention (Execution Mode):** When the active team is set to `execution_mode: single_agent`, the Chat Agent runs the workflow end-to-end without subagent delegation to guarantee 100% unified code style.
5. **Zero-Doubt Closure:** Before concluding a task, any pending doubts in `.agents/notes/` must be resolved.

---

## Execution Spine for the Lead Orchestrator

### Step 1: Intake Framing (4 Coordinates)
Elicit or confirm the 4 coordinates from the user:
1. **Scale:**
   - `Small`: 1-3 files, isolated bug fix or localized tweak.
   - `Medium`: Single feature slice, component refactoring, integration tests.
   - `Large`: Multi-phase architecture, cross-system migration, new subsystem.
2. **Goal:** The core value to deliver or defect to eliminate.
3. **Scope:** Explicit files allowed to be modified, and non-negotiable boundaries.
4. **Acceptance Criteria:** Concrete pass predicate or test command that proves success.

### Step 2: Read Active Team & Execution Mode
Query the active team configuration via the global tool path:
```bash
python3 ~/.agent-kityui/tools/team_manager.py active
```
Inspect `execution_mode` (`multi_agent` vs `single_agent`), the Lead Orchestrator status, and available member subagents.

### Step 3: Initialize Phased Roadmap
Create `.agents/plans/YYYY-MM-DD_HHmm-plan-<topic-slug>.md` following the standard template:
- Header: Topic, Timestamp, Goal, 4 Coordinates.
- Architecture / Data Shape: Define types, interfaces, and state transitions first.
- Vertical Slices: Sequential phases with distinct verification commands.

### Step 4: Delegation & Execution Loop
Depending on `execution_mode`:
- **Single Agent Mode (`single_agent`):**
  The Chat Agent sequentially executes: Failing test first -> Minimal code slice -> Verify -> Next slice.
- **Multi-Agent Mode (`multi_agent`):**
  The Orchestrator delegates tasks to team subagents via `Task`:
  - **Prompt Assembly:** Combine `base_description` + `extra_description` + specific task brief.
  - **Coder Role:** Delegate vertical slice authoring (or self-execute if missing).
  - **Auditor Role:** Delegate adversarial verification and edge-case probing (or self-execute if missing).

### Step 5: Verification & Zero-Doubt Closure
1. Re-run verification commands directly to inspect output.
2. Mark `[x]` on verified items.
3. Check `.agents/notes/` for any unresolved doubts.
4. Report the final deliverable with verifiable proof to the user.
