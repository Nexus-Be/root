---
name: choose-team
description: Fast in-chat CLI switcher to inspect and switch the active subagent team globally in ~/.agent-kityui/teams.json without opening a browser. Use for /choose-team, "choose team", "switch team", or "select subagent team".
---

# Choose Subagent Team (`/choose-team`)
> **Companion File (Vietnamese):** [`SKILL.vi.md`](SKILL.vi.md)  
> **Authoritative English Specification**

Provides rapid in-chat inspection and switching of the active Subagent Team in `~/.agent-kityui/teams.json`. This skill is purely CLI and conversation-driven: it **never launches a web browser or opens graphical windows**. For visual configuration, mode toggles, and dashboard controls, use `/setup-team`.

---

## Non-Negotiable Invariants

1. **Global Scope Invariant:** Subagent teams are strictly global. All conversations and workflows in the workspace share the single active team designated by `active_team_id`. Per-conversation team partitioning is strictly forbidden.
2. **Terminal-First Execution:** Does not launch background daemons or web servers. Operates deterministically via `tools/team_manager.py`.

---

## Execution Spine for the Agent

### Step 1: Read Existing Teams
Run the team manager helper to inspect available teams:
```bash
python3 ~/.agent-kityui/tools/team_manager.py list
```
If `~/.agent-kityui/teams.json` does not exist or has zero teams, inform the user and recommend initializing via `/setup-team`.

### Step 2: Handle Direct Selection
If the user supplied a team ID or name as an argument (e.g., `/choose-team team-core-dev`):
1. Switch the active team immediately:
   ```bash
   python3 ~/.agent-kityui/tools/team_manager.py set-active <team-id>
   ```
2. Report the new active team, its assigned Lead Orchestrator, and member subagents.

### Step 3: Present Interactive Selection (When No Argument Given)
If no argument was provided:
1. Parse the available teams and identify which one is currently `[ACTIVE]`.
2. Present a structured `AskQuestion` card allowing the user to select their desired active team.
3. Upon selection, execute `python3 ~/.agent-kityui/tools/team_manager.py set-active <team-id>` and confirm.

### Step 4: Display Team Summary
Print the active roster:
- Team Name & ID
- Active Execution Mode (`Multi-Agent` or `Single Main Agent`)
- Lead Orchestrator designation (or notify that default to the active Chat Agent is enabled)
- Subagent list with role keys and configured models (`inherit` by default)
