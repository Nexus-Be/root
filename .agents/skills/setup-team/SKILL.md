---
name: setup-team
description: Launch the local Web Dashboard server on port 56123 in the background and open the visual subagent team management interface. Use for /setup-team, "setup team", "manage teams", "team dashboard", or "configure subagents".
---

# Setup Subagent Teams Dashboard (`/setup-team`)
> **Companion File (Vietnamese):** [`SKILL.vi.md`](SKILL.vi.md)  
> **Authoritative English Specification**

Launches and connects to the visual Subagent Team Management Web Dashboard on local port `56123`. This skill ensures the server runs as a detached background daemon to prevent terminal timeouts and provides an intuitive browser interface to configure teams, switch between Multi-Agent and Single Agent modes, assign the Lead Orchestrator, customize role descriptions, and toggle the single global active team.

---

## Non-Negotiable Invariants

1. **Non-Blocking Execution (Anti-Timeout):** The web server must ALWAYS be checked via `--check` and launched via `--daemon`. The agent must never run `tools/team-server.py` in the foreground during chat turns to avoid 30-second terminal command timeouts.
2. **Server Reuse Invariant (Never Run Duplicate Processes):** If the server is already active on port 56123, the agent **MUST NOT** spawn another daemon or restart it. Simply present the live URL immediately.
3. **Localhost Binding:** Binds strictly to `127.0.0.1:56123`. Access is restricted to the local developer machine.
4. **Single Global Active Team:** Changes made on the dashboard update `~/.agent-kityui/teams.json` globally.

---

## Execution Spine for the Agent

### Step 1: Check Server Status (Idempotent Ping)
Execute the check command via the global tool path:
```bash
python3 ~/.agent-kityui/tools/team-server.py --check
```
- If the exit code is 0 (already running), **do NOT launch or restart**. Proceed immediately to Step 3.
- If the exit code is non-zero (not running), proceed to Step 2.

### Step 2: Launch Background Daemon
Execute the detached background daemon launcher:
```bash
python3 ~/.agent-kityui/tools/team-server.py --daemon
```
The command detaches the process, closes stdin/stdout/stderr, and returns in less than 500ms without blocking the IDE session.

### Step 3: Present Dashboard Access Link & Guidance
Present a formatted markdown link for the user:
👉 **[Open Subagent Team Management Dashboard (http://localhost:56123)](http://localhost:56123)**

Highlight the dashboard features for the user:
- **⚙️ Multi-Agent vs Single Agent Toggle:** Switch between delegating to subagents or running everything strictly through the main chat agent.
- **⚡ 1-Click Auto-fill Core Roster:** Automatically provisions the 3 core workers (`Builder Coder`, `Bug Hunter`, `Zero-Doubt Auditor`) with model `inherit`. Lead Orchestrator defaults to the Chat Agent.
- **👑 Custom Orchestrator Option:** Allows optionally adding an explicit `Lead Orchestrator` subagent if a specialized model (e.g. Opus 5) is desired instead of the chat model.
- **🛡️ Protected Base & Extra Descriptions:** Standard role definitions are locked for safety; project-specific instructions can be freely added in the `extra_description` field.
- **⭐ Global Active Team Toggle:** Click to set the active team across the workspace.
- **💾 Atomic Save:** Writes updates directly to `~/.agent-kityui/teams.json`.
