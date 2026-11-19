---
name: herdr
description: "Control Herdr, a terminal multiplexer for coding agents. Use only when the user explicitly mentions Herdr or asks to use Herdr to inspect or control panes, tabs, workspaces, commands, or another agent. Do not use merely because a task could benefit from a background terminal, delegation, or parallel work. Requires HERDR_ENV=1."
disable-model-invocation: true
---

# Herdr

Verify Herdr context before issuing any command; stop if the check fails:

```bash
test "${HERDR_ENV:-}" = 1
```

## Discovery and primitives

The installed `herdr` binary is the authority for flags. Never run bare `herdr` (launches TUI) or omit args on mutating subcommands (`herdr workspace create` executes immediately).

| Group | Purpose |
| --- | --- |
| `herdr workspace` / `tab` / `pane` / `worktree` | Layout topology, raw shell execution, output reading |
| `herdr agent` | Recognized coding agents inside panes (`idle`, `done`, `working`, `blocked`, `unknown`) |
| `herdr machine` | Saved SSH machine profiles (`--machine <label-or-id>` prefix) |
| `herdr status` / `session` / `notification` | Server status, sessions, notifications |

- IDs are opaque handles (`w1`, `w1:t1`, `w1:p1`) scoped to one server; always parse IDs from JSON output.
- Caller context env vars: `$HERDR_WORKSPACE_ID`, `$HERDR_TAB_ID`, `$HERDR_PANE_ID`. Prefer `--current` for the calling pane.
- After `pane move`, use `.result.move_result.pane.pane_id` or the live agent name (not `previous_pane_id`).
- Agent names match `[a-z][a-z0-9_-]{0,31}` and are unique per server; `agent start` requires an idle shell pane and never creates layout.

## Common workflows

**Inspect live state:**
```bash
herdr workspace list
herdr pane list --workspace "$HERDR_WORKSPACE_ID"
herdr agent list
```

**Start and prompt a sibling agent** (default: split current tab in `$PWD`, keep user focus):
```bash
herdr pane layout --pane "$HERDR_PANE_ID"   # wide -> right, tall -> down
herdr pane split --current --direction right --cwd "$PWD" --no-focus
herdr agent start reviewer --kind codex --pane <pane-id> [-- <agent-args...>]
herdr agent prompt reviewer "Review the diff and report actionable findings." --wait --timeout 120000
herdr agent get reviewer
herdr agent read reviewer --source recent-unwrapped --lines 120
```

- `--wait` waits for activity within 5s, then settles on `idle`, `done`, or `blocked`; use `--until blocked` only when waiting specifically for input prompts.
- Send UI keys with `herdr agent send-keys <name> esc` / `ctrl+c`. If `blocked`, inspect `agent get`/`agent read` and ask the user before answering.
- On timeout or `agent_prompt_stalled`, inspect state before retrying — do not blindly re-submit.

**Run a command in a sibling pane:**
```bash
herdr pane split --current --direction right --cwd "$PWD" --no-focus
herdr pane run <pane-id> "mise run check"
herdr pane wait-output <pane-id> --match "OK" --timeout 120000
herdr pane read <pane-id> --source recent-unwrapped --lines 120
```

| `--source` | Meaning |
| --- | --- |
| `visible` | Current viewport |
| `recent` | Recent output including soft wraps |
| `recent-unwrapped` | Soft wraps joined (default for logs/transcripts) |
| `detection` | Plain-text bottom buffer used for agent detection |

**Remote SSH machine** (use `--machine <label-or-id>` consistently on discovery and actions; do not combine with `--session`/`--remote`; never pass local pane IDs or `--current`):
```bash
herdr --machine <label-or-id> agent list
herdr --machine <label-or-id> agent prompt <name> "<prompt>" --wait --timeout 120000
```

## Safety rules

- Always pass `--no-focus` for background splits unless the user asked to switch focus.
- Do not close workspaces, tabs, panes, or sessions you did not create without explicit user instruction; never add `workspace close --group` to bypass `workspace_group_close_required`.
- Only add, remove, enable, or disable `herdr machine` profiles when asked; never run `herdr machine reconnect` or approve server replacement without user consent.
- Use `--trust-repository` only after user verification of the repo.
- Never run `herdr server stop` or kill the main Herdr process from an active session.
- Exit codes: `1` = JSON server error on stderr, `2` = CLI syntax error.
