#!/usr/bin/env python3
"""Offline tests for the unified 4-agent control plane and agent-notify hook."""

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tomllib

ROOT = Path(__file__).resolve().parents[1]
RECONCILE = ROOT / "dot_local/libexec/dotfiles/executable_agent-reconcile.py"
NOTIFY = ROOT / "private_dot_agents/hooks/executable_agent-notify.py"
AGENTS = tomllib.loads((ROOT / ".chezmoidata/agents.toml").read_text())["agents"]


def run_reconcile(target, raw, spec):
    result = subprocess.run(
        [sys.executable, str(RECONCILE), target, "--spec", json.dumps(spec)],
        input=raw,
        text=True,
        capture_output=True,
        check=True,
    )
    return result


base_spec = {
    "agents": AGENTS,
    "bundles": ["core", "agent-tools", "research"],
    "claude_profile": "strict",
}

# 1. Claude settings: strict vs remote-control privacy, deny/ask, PreToolUse & Stop hooks
claude_in = json.dumps({
    "theme": "dark",
    "env": {"CUSTOM_VAR": "keep", "DO_NOT_TRACK": "1"},
    "permissions": {"deny": ["Read(~/.custom)"]},
    "hooks": {
        "PreToolUse": [
            {"matcher": "Bash", "hooks": [{"type": "command", "command": "other-hook"}]}
        ]
    },
})
res = run_reconcile("claude-settings", claude_in, base_spec)
strict_out = json.loads(res.stdout)
assert strict_out["theme"] == "dark"
assert strict_out["env"]["CUSTOM_VAR"] == "keep"
assert strict_out["env"]["DISABLE_TELEMETRY"] == "1"
assert strict_out["env"]["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] == "1"
assert "Read(~/.custom)" in strict_out["permissions"]["deny"]
assert "Read(~/.config/chezmoi/key.txt)" in strict_out["permissions"]["deny"]
assert "Bash(gh api:*)" in strict_out["permissions"]["ask"]
assert any(
    h["command"] == AGENTS["hooks"]["key_guard"]
    for g in strict_out["hooks"]["PreToolUse"]
    for h in g["hooks"]
)
assert any(
    h["command"] == "other-hook"
    for g in strict_out["hooks"]["PreToolUse"]
    for h in g["hooks"]
)
assert any(
    h["command"] == AGENTS["hooks"]["notify"]
    for g in strict_out["hooks"]["Stop"]
    for h in g["hooks"]
)
# Idempotency: unchanged input returned byte-for-byte
assert run_reconcile("claude-settings", res.stdout, base_spec).stdout == res.stdout

# Remote-control profile strips conflicting telemetry vars and disables autoupdater
rc_spec = {**base_spec, "claude_profile": "remote-control"}
rc_out = json.loads(run_reconcile("claude-settings", res.stdout, rc_spec).stdout)
for conflict in ("CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "DISABLE_TELEMETRY", "DO_NOT_TRACK", "DISABLE_GROWTHBOOK"):
    assert conflict not in rc_out["env"], conflict
assert rc_out["env"]["DISABLE_AUTOUPDATER"] == "1"
assert rc_out["env"]["DISABLE_ERROR_REPORTING"] == "1"

# 2. Codex config: key-guard permissions, [otel] privacy, MCP injection, sandbox_mode refusal
codex_in = (
    'model = "gpt-6.1"\n\n'
    '[otel]\n'
    'exporter = "otlp"\n'
    'custom_flag = true\n\n'
    '[projects."/tmp/demo"]\n'
    'trust_level = "trusted"\n'
)
mcp_spec = copy.deepcopy(base_spec)
mcp_spec["agents"]["mcp"] = {
    "demo": {
        "targets": ["codex", "agy"],
        "bundles": ["research"],
        "command": "demo-mcp",
        "args": ["--readonly"],
        "env": {"MODE": "safe"},
    },
    "skipped": {
        "targets": ["codex", "agy"],
        "bundles": ["nonexistent"],
        "command": "should-not-appear",
    },
}
codex_res = run_reconcile("codex-config", codex_in, mcp_spec)
codex_parsed = tomllib.loads(codex_res.stdout)
assert codex_parsed["model"] == "gpt-6.1"
assert codex_parsed["default_permissions"] == "key-guard"
assert codex_parsed["otel"]["exporter"] == "none"
assert codex_parsed["otel"]["log_user_prompt"] is False
assert codex_parsed["otel"]["custom_flag"] is True
assert codex_parsed["projects"]["/tmp/demo"]["trust_level"] == "trusted"
assert codex_parsed["mcp_servers"]["demo"] == {
    "command": "demo-mcp",
    "args": ["--readonly"],
    "env": {"MODE": "safe"},
}
assert "skipped" not in codex_parsed["mcp_servers"]
assert run_reconcile("codex-config", codex_res.stdout, mcp_spec).stdout == codex_res.stdout

# Refuses to modify config using sandbox_mode
sandbox_raw = 'sandbox_mode = "workspace-write"\n'
sandbox_res = run_reconcile("codex-config", sandbox_raw, base_spec)
assert sandbox_res.stdout == sandbox_raw and "unchanged" in sandbox_res.stderr

# 3. Codex hooks: preserves Herdr SessionStart and RTK PreToolUse while adding guard & Stop notify
codex_hooks_in = json.dumps({
    "hooks": {
        "PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "rtk hook codex"}]}],
        "SessionStart": [{"hooks": [{"type": "command", "command": "bash herdr.sh"}]}],
    }
})
ch_res = run_reconcile("codex-hooks", codex_hooks_in, base_spec)
ch_out = json.loads(ch_res.stdout)
assert len(ch_out["hooks"]["PreToolUse"]) == 2
assert len(ch_out["hooks"]["SessionStart"]) == 1
assert len(ch_out["hooks"]["Stop"]) == 1
assert run_reconcile("codex-hooks", ch_res.stdout, base_spec).stdout == ch_res.stdout

# 4. Antigravity CLI hooks & MCP: preserves Herdr hook and local MCP servers
agy_hooks_in = json.dumps({
    "herdr": {"PreInvocation": [{"type": "command", "command": "bash herdr.sh", "timeout": 10}]}
})
ah_res = run_reconcile("agy-hooks", agy_hooks_in, base_spec)
ah_out = json.loads(ah_res.stdout)
assert "herdr" in ah_out
assert ah_out["dotfiles-key-guard"]["PreToolUse"][0]["hooks"][0]["command"] == AGENTS["hooks"]["key_guard"]
assert ah_out["dotfiles-agent-notify"]["Stop"][0]["command"] == AGENTS["hooks"]["notify"]
assert run_reconcile("agy-hooks", ah_res.stdout, base_spec).stdout == ah_res.stdout

# Empty MCP config stays valid JSON object when no managed servers apply
assert run_reconcile("agy-mcp", "", base_spec).stdout == "{}\n"
assert run_reconcile("agy-mcp", "{}\n", base_spec).stdout == "{}\n"
# Local MCP server preserved alongside bundle-matched managed server
agy_mcp_in = json.dumps({"mcpServers": {"local-tool": {"command": "local-bin"}}})
am_res = run_reconcile("agy-mcp", agy_mcp_in, mcp_spec)
am_out = json.loads(am_res.stdout)
assert am_out["mcpServers"]["local-tool"] == {"command": "local-bin"}
assert am_out["mcpServers"]["demo"]["command"] == "demo-mcp"
assert "skipped" not in am_out["mcpServers"]
assert run_reconcile("agy-mcp", am_res.stdout, mcp_spec).stdout == am_res.stdout

# 5. Pi settings: preserves local subagent overrides while enforcing inheritGlobalContext
pi_in = json.dumps({
    "deviceId": "dev-1",
    "subagents": {"agentOverrides": {"reviewer": {"model": "custom/model"}}},
})
pi_res = run_reconcile("pi-settings", pi_in, base_spec)
pi_out = json.loads(pi_res.stdout)
assert pi_out["subagents"]["agentOverrides"]["reviewer"] == {
    "model": "custom/model",
    "inheritProjectContext": True,
    "inheritGlobalContext": True,
}
assert pi_out["subagents"]["agentOverrides"]["worker"]["inheritGlobalContext"] is True
assert "~/.pi/agent/extensions/dotfiles-guard.ts" in pi_out["subagents"]["defaultSubagentOnlyExtensions"]
assert run_reconcile("pi-settings", pi_res.stdout, base_spec).stdout == pi_res.stdout

# 6. agent-notify.py contract: agy Stop ALWAYS prints `{}` and exits 0; Claude/Codex silent exit 0
quiet_env = {**os.environ, "DOTFILES_AGENT_NOTIFY": "0"}
agy_stop = subprocess.run(
    [sys.executable, str(NOTIFY)],
    input=json.dumps({"hookEventName": "Stop", "conversationId": "c1", "terminationReason": "NO_TOOL_CALL", "fullyIdle": True}),
    env=quiet_env,
    text=True,
    capture_output=True,
    check=True,
)
assert json.loads(agy_stop.stdout) == {}
claude_stop = subprocess.run(
    [sys.executable, str(NOTIFY)],
    input=json.dumps({"stop_hook_active": False, "cwd": "/tmp/demo"}),
    env=quiet_env,
    text=True,
    capture_output=True,
    check=True,
)
assert claude_stop.stdout == ""

print("ok       Agent control plane: Claude, Codex, agy, Pi reconciliation and agent-notify pass")
