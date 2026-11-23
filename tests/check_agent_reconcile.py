#!/usr/bin/env python3
"""Offline tests for the unified 4-agent control plane and agent-notify hook."""

import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]
RECONCILE = ROOT / "dot_local/libexec/dotfiles/executable_agent-reconcile.py"
NOTIFY = ROOT / "private_dot_agents/hooks/executable_agent-notify.py"
AGENTS = tomllib.loads((ROOT / ".chezmoidata/agents.toml").read_text())["agents"]
POLICY = tomllib.loads((ROOT / ".chezmoidata/policy.toml").read_text())["policy"]


def run_reconcile(target, raw, spec, extra_args=None):
    cmd = [sys.executable, str(RECONCILE), target, "--spec", json.dumps(spec)]
    if extra_args:
        cmd.extend(extra_args)
    result = subprocess.run(
        cmd,
        input=raw,
        text=True,
        capture_output=True,
        check=True,
    )
    return result


base_spec = {
    "agents": AGENTS,
    "policy": POLICY,
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

# 2. Codex config: key-guard permissions from policy.toml (existing paths only),
# [otel] privacy, MCP injection, idempotency, and sandbox_mode refusal.
codex_in = (
    'model = "gpt-6.1"\n\n'
    '[otel]\n'
    'exporter = "otlp"\n'
    'custom_flag = true\n\n'
    '[projects."/tmp/demo"]\n'
    'trust_level = "trusted"\n'
)
with tempfile.TemporaryDirectory(prefix="dotfiles-reconcile-codex-") as tmp:
    fake_home = Path(tmp)
    (fake_home / ".secrets").mkdir(parents=True)
    (fake_home / ".secrets/api.txt").write_text("SECRET\n")
    (fake_home / ".config/chezmoi").mkdir(parents=True)
    (fake_home / ".config/chezmoi/key.txt").write_text("AGE-SECRET-KEY-TEST\n")
    (fake_home / ".claude").mkdir(parents=True)
    (fake_home / ".claude/.credentials.json").write_text("{}\n")
    (fake_home / ".codex").mkdir(parents=True)
    (fake_home / ".codex/auth.json").write_text("{}\n")
    (fake_home / ".ssh/config.d").mkdir(parents=True)
    (fake_home / ".ssh/config").write_text("Host demo\n")
    (fake_home / ".ssh/known_hosts").write_text("demo ssh-ed25519 AAAA\n")
    (fake_home / ".ssh/id_ed25519").write_text("DEFAULT_KEY\n")
    (fake_home / ".ssh/id_ed25519.pub").write_text("ssh-ed25519 AAAA\n")
    (fake_home / ".ssh/custom_deploy_key").write_text("CUSTOM_KEY\n")
    (fake_home / ".ssh/custom_deploy_key.pub").write_text("ssh-ed25519 AAAA\n")
    (fake_home / ".ssh/private_keys").mkdir(parents=True)

    mcp_spec = copy.deepcopy(base_spec)
    mcp_spec["home"] = str(fake_home)
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

    fs_rules = codex_parsed["permissions"]["key-guard"]["filesystem"]
    # Existing policy dirs/files and custom-named ~/.ssh/ keys are denied.
    for glob_pat in AGENTS["codex"]["deny_globs"]:
        assert fs_rules[glob_pat] == "deny", fs_rules
    assert fs_rules["/etc/ssh/ssh_config.d"] == "deny", fs_rules
    assert fs_rules["~/.secrets"] == "deny", fs_rules
    assert fs_rules["~/.config/chezmoi/key.txt"] == "deny", fs_rules
    assert fs_rules["~/.claude/.credentials.json"] == "deny", fs_rules
    assert fs_rules["~/.ssh/custom_deploy_key"] == "deny", fs_rules
    assert fs_rules["~/.ssh/private_keys"] == "deny", fs_rules
    # Codex's own auth, non-existent policy paths, public ~/.ssh entries, and
    # id_* keys already covered by deny_globs must not emit exact deny paths.
    for forbidden_entry in (
        "~/.codex/auth.json",
        "~/.aws/credentials",
        "~/.netrc",
        "~/.git-credentials",
        "~/.cargo/credentials",
        "~/.pi/agent/auth.json",
        "~/.ssh/id_ed25519",
        "~/.ssh/id_ed25519.pub",
        "~/.ssh/custom_deploy_key.pub",
        "~/.ssh/config",
        "~/.ssh/known_hosts",
        "~/.ssh/config.d",
    ):
        assert forbidden_entry not in fs_rules, f"unexpected deny entry {forbidden_entry}: {fs_rules}"

    # Idempotency fast-path and --home CLI injection match byte-for-byte.
    assert run_reconcile("codex-config", codex_res.stdout, mcp_spec).stdout == codex_res.stdout
    cli_home_spec = {k: v for k, v in mcp_spec.items() if k != "home"}
    cli_home_res = run_reconcile("codex-config", codex_in, cli_home_spec, extra_args=["--home", str(fake_home)])
    assert cli_home_res.stdout == codex_res.stdout

    # Adding and later removing a secret file updates exact deny paths cleanly.
    aws_creds = fake_home / ".aws/credentials"
    aws_creds.parent.mkdir(parents=True)
    aws_creds.write_text("[default]\n")
    added = tomllib.loads(run_reconcile("codex-config", codex_res.stdout, mcp_spec).stdout)
    assert added["permissions"]["key-guard"]["filesystem"]["~/.aws/credentials"] == "deny"
    assert added["projects"]["/tmp/demo"]["trust_level"] == "trusted"
    aws_creds.unlink()
    removed = tomllib.loads(run_reconcile("codex-config", codex_res.stdout, mcp_spec).stdout)
    assert "~/.aws/credentials" not in removed["permissions"]["key-guard"]["filesystem"]

    # Refuses to modify config using sandbox_mode
    sandbox_raw = 'sandbox_mode = "workspace-write"\n'
    sandbox_res = run_reconcile("codex-config", sandbox_raw, {**base_spec, "home": str(fake_home)})
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

# Antigravity RTK plugin hook is wrapped fail-open while keeping all other fields intact
rtk_hooks_in = json.dumps({
    "rtk-rewrite": {
        "enabled": True,
        "PreToolUse": [
            {
                "matcher": "run_command",
                "hooks": [{"type": "command", "command": "rtk hook antigravity", "timeout": 10}],
            }
        ],
    }
})
rtk_res = run_reconcile("agy-rtk-hooks", rtk_hooks_in, {})
rtk_out = json.loads(rtk_res.stdout)
rtk_cmd = rtk_out["rtk-rewrite"]["PreToolUse"][0]["hooks"][0]["command"]
assert rtk_cmd != "rtk hook antigravity" and "rtk hook antigravity" in rtk_cmd, rtk_cmd
assert run_reconcile("agy-rtk-hooks", rtk_res.stdout, {}).stdout == rtk_res.stdout
# Verify the fail-open command prints valid allow JSON and exits 0 when `rtk` is missing
fallback = subprocess.run(
    ["sh", "-c", rtk_cmd],
    env={"PATH": "/usr/bin:/bin"},
    text=True,
    capture_output=True,
    check=True,
)
assert json.loads(fallback.stdout) == {"decision": "allow"}, fallback
assert fallback.stderr == "", fallback

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
