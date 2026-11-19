#!/usr/bin/env python3
"""Reconcile shared agent policy from .chezmoidata/agents.toml into native configs.

Called by thin chezmoi modify_ shims across Claude Code, Codex, Antigravity CLI
(agy), and Pi. Reads the current target file from stdin and writes the
reconciled file to stdout. Always fails open (returns stdin verbatim with a
warning on stderr) so malformed local state or missing optional tools never
abort `chezmoi apply`.

Compatible with Python 3.10+ (Ubuntu 22.04 on imrl). Only `codex-config` needs
`tomllib` (Python 3.11+) or `tomli`.
"""

import argparse
import copy
import json
import re
import sys

TOML_HEADER = re.compile(r"^\s*\[\[?\s*([^\]]+?)\s*\]\]?\s*(#.*)?$")
TOML_TOP_DEFAULT = re.compile(r"^\s*default_permissions\s*=\s*(.*?)\s*(#.*)?$")
CODEX_COMMENT = [
    "# Managed by chezmoi from .chezmoidata/agents.toml (agent-reconcile.py).",
    "# Edits to managed sections are overwritten on the next apply. See docs/secrets.md.",
]
# Also strip legacy comment lines written by the pre-Wave-3 modify script.
LEGACY_CODEX_COMMENTS = {
    "# Set by chezmoi from dot_codex/modify_private_config.toml, so an edit to",
    "# this profile is undone by the next apply. See docs/secrets.md.",
    *CODEX_COMMENT,
}


def warn(target, message):
    sys.stderr.write(f"agent-reconcile ({target}): {message}\n")


def selected_mcp(spec, target_name):
    """Return {name: server_cfg} from agents.mcp matching target_name and bundles."""
    bundles = set(spec.get("bundles") or [])
    registry = (spec.get("agents") or {}).get("mcp") or {}
    out = {}
    for name, cfg in sorted(registry.items()):
        if not isinstance(cfg, dict):
            continue
        targets = cfg.get("targets") or []
        if target_name not in targets:
            continue
        req_bundles = cfg.get("bundles") or []
        if req_bundles and not (bundles & set(req_bundles)):
            continue
        entry = {}
        if "url" in cfg:
            entry["url"] = cfg["url"]
        elif "command" in cfg:
            entry["command"] = cfg["command"]
            if cfg.get("args"):
                entry["args"] = list(cfg["args"])
            if cfg.get("env"):
                entry["env"] = dict(cfg["env"])
        else:
            continue
        out[name] = entry
    return out


def upsert_hook_group(groups, command, matcher, hook_entry):
    """Upsert a PreToolUse/Stop hook group identified by command, keeping unrelated hooks."""
    merged = []
    found = False
    for group in groups:
        if not isinstance(group, dict):
            merged.append(group)
            continue
        hooks = group.get("hooks", [])
        ours = [h for h in hooks if isinstance(h, dict) and h.get("command") == command]
        if not ours:
            merged.append(group)
            continue
        found = True
        others = [h for h in hooks if not (isinstance(h, dict) and h.get("command") == command)]
        if others:
            kept = copy.deepcopy(group)
            kept["hooks"] = others
            merged.append(kept)
        new_group = {"hooks": [copy.deepcopy(hook_entry)]}
        if matcher is not None:
            new_group["matcher"] = matcher
        merged.append(new_group)
    if not found:
        new_group = {"hooks": [copy.deepcopy(hook_entry)]}
        if matcher is not None:
            new_group["matcher"] = matcher
        merged.append(new_group)
    return merged


def reconcile_claude_settings(raw, spec):
    agents = spec["agents"]
    privacy = agents["privacy"]
    hooks_cfg = agents["hooks"]
    claude = agents["claude"]
    profile = spec.get("claude_profile") or privacy["claude_profile_default"]
    if profile not in privacy["claude_profiles"]:
        raise ValueError(f"unknown claude_profile {profile!r}")

    before = json.loads(raw) if raw.strip() else {}
    if not isinstance(before, dict):
        raise ValueError("top level is not a JSON object")
    after = copy.deepcopy(before)

    perms = after.setdefault("permissions", {})
    if not isinstance(perms, dict):
        raise ValueError("'permissions' is not a JSON object")
    deny = perms.setdefault("deny", [])
    if not isinstance(deny, list):
        raise ValueError("'permissions.deny' is not a JSON array")
    deny.extend(rule for rule in claude.get("deny", []) if rule not in deny)
    ask = perms.setdefault("ask", [])
    if not isinstance(ask, list):
        raise ValueError("'permissions.ask' is not a JSON array")
    ask.extend(rule for rule in claude.get("ask", []) if rule not in ask)

    env = after.setdefault("env", {})
    if not isinstance(env, dict):
        raise ValueError("'env' is not a JSON object")
    if profile == "remote-control":
        for key in privacy.get("claude_remote_control", {}).get("conflicts", []):
            env.pop(key, None)
    env.update(privacy.get("claude_common_env", {}))
    env.update(privacy["claude_profiles"][profile])

    hooks = after.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("'hooks' is not a JSON object")
    pre = hooks.setdefault("PreToolUse", [])
    if not isinstance(pre, list):
        raise ValueError("'hooks.PreToolUse' is not a JSON array")
    hooks["PreToolUse"] = upsert_hook_group(
        pre,
        hooks_cfg["key_guard"],
        hooks_cfg["claude_guard_matcher"],
        {"type": "command", "command": hooks_cfg["key_guard"]},
    )
    stop = hooks.setdefault("Stop", [])
    if not isinstance(stop, list):
        raise ValueError("'hooks.Stop' is not a JSON array")
    hooks["Stop"] = upsert_hook_group(
        stop,
        hooks_cfg["notify"],
        None,
        {"type": "command", "command": hooks_cfg["notify"]},
    )

    if after == before and raw.strip():
        return raw
    return json.dumps(after, indent=2, ensure_ascii=False) + "\n"


def reconcile_codex_hooks(raw, spec):
    hooks_cfg = spec["agents"]["hooks"]
    before = json.loads(raw) if raw.strip() else {}
    if not isinstance(before, dict):
        raise ValueError("top level is not a JSON object")
    after = copy.deepcopy(before)

    hooks = after.setdefault("hooks", {})
    if not isinstance(hooks, dict):
        raise ValueError("'hooks' is not a JSON object")
    pre = hooks.setdefault("PreToolUse", [])
    if not isinstance(pre, list):
        raise ValueError("'hooks.PreToolUse' is not a JSON array")
    hooks["PreToolUse"] = upsert_hook_group(
        pre,
        hooks_cfg["key_guard"],
        hooks_cfg["codex_guard_matcher"],
        {
            "type": "command",
            "command": hooks_cfg["key_guard"],
            "statusMessage": "Checking for private key paths",
            "timeout": 10,
        },
    )
    stop = hooks.setdefault("Stop", [])
    if not isinstance(stop, list):
        raise ValueError("'hooks.Stop' is not a JSON array")
    hooks["Stop"] = upsert_hook_group(
        stop,
        hooks_cfg["notify"],
        None,
        {
            "type": "command",
            "command": hooks_cfg["notify"],
            "timeout": 5,
        },
    )

    if after == before and raw.strip():
        return raw
    return json.dumps(after, indent=2, ensure_ascii=False) + "\n"


def _toml_value(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        return json.dumps(value)
    if isinstance(value, list):
        return "[" + ", ".join(_toml_value(v) for v in value) + "]"
    raise TypeError(f"unsupported TOML value: {type(value).__name__}")


def _toml_key(key):
    if re.fullmatch(r"[A-Za-z0-9_-]+", key):
        return key
    return json.dumps(key)


def reconcile_codex_config(raw, spec):
    try:
        import tomllib
    except ImportError:
        import tomli as tomllib  # type: ignore[no-redef]

    agents = spec["agents"]
    codex = agents["codex"]
    otel_want = dict(agents["privacy"]["codex_otel"])
    mcp_want = selected_mcp(spec, "codex")
    profile = codex["profile"]

    profile_want = {
        "description": codex["description"],
        "extends": codex["extends"],
        "filesystem": {
            **{g: "deny" for g in codex["deny_globs"]},
            codex["ssh_drop_ins"]: "deny",
            ":workspace_roots": dict(codex["workspace_roots"]),
        },
        "network": {"enabled": True},
    }

    before = tomllib.loads(raw) if raw.strip() else {}
    if "sandbox_mode" in before or "sandbox_workspace_write" in before:
        raise ValueError("it sets sandbox_mode, which Codex says not to combine with default_permissions")

    # Preserve existing non-managed keys in [otel] if any.
    existing_otel = before.get("otel")
    if existing_otel is not None and not isinstance(existing_otel, dict):
        raise ValueError("[otel] is not a table")
    merged_otel = {**(existing_otel or {}), **otel_want}

    # Fast-path idempotency: if everything managed already matches, return raw verbatim.
    existing_mcp = before.get("mcp_servers") or {}
    if (
        raw.strip()
        and before.get("default_permissions") == profile
        and (before.get("permissions") or {}).get(profile) == profile_want
        and before.get("otel") == merged_otel
        and all(existing_mcp.get(name) == cfg for name, cfg in mcp_want.items())
    ):
        return raw

    def table_is_managed(table):
        norm = re.sub(r"[\s\"']", "", table)
        if norm == f"permissions.{profile}" or norm.startswith(f"permissions.{profile}."):
            return True
        if norm == "otel":
            return True
        for name in mcp_want:
            clean = re.sub(r"[\s\"']", "", name)
            if norm == f"mcp_servers.{clean}" or norm.startswith(f"mcp_servers.{clean}."):
                return True
        return False

    kept = []
    old_default = None
    in_top, in_managed = True, False
    for line in raw.splitlines():
        m = TOML_HEADER.match(line)
        if m:
            in_top = False
            in_managed = table_is_managed(m.group(1))
        if in_managed or line in LEGACY_CODEX_COMMENTS:
            continue
        if in_top:
            d = TOML_TOP_DEFAULT.match(line)
            if d:
                old_default = d.group(1)
                continue
        kept.append(line)

    blocks = list(CODEX_COMMENT)
    blocks.append("[otel]")
    for k, v in merged_otel.items():
        blocks.append(f"{_toml_key(k)} = {_toml_value(v)}")
    blocks.append("")

    blocks.append(f"[permissions.{profile}]")
    blocks.append(f"description = {json.dumps(profile_want['description'])}")
    blocks.append(f"extends = {json.dumps(profile_want['extends'])}")
    blocks.append("")
    blocks.append(f"[permissions.{profile}.filesystem]")
    for path, access in profile_want["filesystem"].items():
        if isinstance(access, str):
            blocks.append(f"{json.dumps(path)} = {json.dumps(access)}")
    blocks.append("")
    blocks.append(f'[permissions.{profile}.filesystem.":workspace_roots"]')
    for path, access in profile_want["filesystem"][":workspace_roots"].items():
        blocks.append(f"{json.dumps(path)} = {json.dumps(access)}")
    blocks.append("")
    blocks.append(f"[permissions.{profile}.network]")
    blocks.append("enabled = true")

    for name, cfg in mcp_want.items():
        blocks.append("")
        blocks.append(f"[mcp_servers.{_toml_key(name)}]")
        for k, v in cfg.items():
            if k == "env":
                continue
            blocks.append(f"{_toml_key(k)} = {_toml_value(v)}")
        if cfg.get("env"):
            blocks.append("")
            blocks.append(f"[mcp_servers.{_toml_key(name)}.env]")
            for ek, ev in sorted(cfg["env"].items()):
                blocks.append(f"{_toml_key(ek)} = {_toml_value(ev)}")

    body = "\n".join(kept).strip("\n")
    default_line = f'default_permissions = "{profile}"'
    out = default_line + "\n" + (body + "\n\n" if body else "\n") + "\n".join(blocks) + "\n"

    after = tomllib.loads(out)

    def without_managed(cfg):
        c = copy.deepcopy(cfg)
        c.pop("default_permissions", None)
        c.pop("otel", None)
        perms = c.get("permissions")
        if isinstance(perms, dict):
            perms.pop(profile, None)
            if not perms:
                c.pop("permissions")
        mcps = c.get("mcp_servers")
        if isinstance(mcps, dict):
            for name in mcp_want:
                mcps.pop(name, None)
            if not mcps:
                c.pop("mcp_servers")
        return c

    if without_managed(after) != without_managed(before):
        raise ValueError("the edit would have changed unmanaged sections of config.toml")
    if after.get("default_permissions") != profile or after["permissions"][profile] != profile_want:
        raise ValueError("the edit did not produce the expected key-guard profile")
    if after.get("otel") != merged_otel:
        raise ValueError("the edit did not produce the expected [otel] table")
    for name, cfg in mcp_want.items():
        if (after.get("mcp_servers") or {}).get(name) != cfg:
            raise ValueError(f"the edit did not produce [mcp_servers.{name}]")
    if old_default not in (None, json.dumps(profile)):
        warn("codex-config", f"replaced default_permissions = {old_default} with {json.dumps(profile)}")
    return out


def reconcile_agy_hooks(raw, spec):
    hooks_cfg = spec["agents"]["hooks"]
    before = json.loads(raw) if raw.strip() else {}
    if not isinstance(before, dict):
        raise ValueError("top level is not a JSON object")
    after = copy.deepcopy(before)

    after["dotfiles-key-guard"] = {
        "PreToolUse": [
            {
                "matcher": hooks_cfg["agy_guard_matcher"],
                "hooks": [
                    {
                        "type": "command",
                        "command": hooks_cfg["key_guard"],
                        "timeout": 10,
                    }
                ],
            }
        ]
    }
    after["dotfiles-agent-notify"] = {
        "Stop": [
            {
                "type": "command",
                "command": hooks_cfg["notify"],
                "timeout": 5,
            }
        ]
    }

    if after == before and raw.strip():
        return raw
    return json.dumps(after, indent=2, ensure_ascii=False) + "\n"


def reconcile_agy_mcp(raw, spec):
    mcp_want = selected_mcp(spec, "agy")
    if not mcp_want:
        return raw if raw.strip() else "{}\n"
    before = json.loads(raw) if raw.strip() else {}
    if not isinstance(before, dict):
        raise ValueError("top level is not a JSON object")
    after = copy.deepcopy(before)
    servers = after.setdefault("mcpServers", {})
    if not isinstance(servers, dict):
        raise ValueError("'mcpServers' is not a JSON object")
    for name, cfg in mcp_want.items():
        servers[name] = copy.deepcopy(cfg)
    if after == before and raw.strip():
        return raw
    return json.dumps(after, indent=2, ensure_ascii=False) + "\n"


def reconcile_pi_settings(raw, spec):
    pi_cfg = spec["agents"]["pi"]
    before = json.loads(raw) if raw.strip() else {}
    if not isinstance(before, dict):
        raise ValueError("settings must be a JSON object")
    packages = before.get("packages", [])
    if not isinstance(packages, list):
        raise ValueError("packages must be an array")
    after = copy.deepcopy(before)
    after.update(copy.deepcopy(pi_cfg.get("settings", {})))

    wanted = {name: f"npm:{name}@{version}" for name, version in pi_cfg.get("packages", {}).items()}
    merged = []
    seen = set()
    for entry in packages:
        source = entry.get("source") if isinstance(entry, dict) else entry
        name = next(
            (
                n
                for n in wanted
                if isinstance(source, str) and (source == f"npm:{n}" or source.startswith(f"npm:{n}@"))
            ),
            None,
        )
        if name is None:
            merged.append(entry)
        elif name not in seen:
            merged.append(wanted[name])
            seen.add(name)
    merged.extend(source for name, source in wanted.items() if name not in seen)
    after["packages"] = merged

    sub_policy = pi_cfg.get("subagents") or {}
    if sub_policy:
        sub = after.setdefault("subagents", {})
        if not isinstance(sub, dict):
            raise ValueError("'subagents' must be a JSON object")
        req_exts = sub_policy.get("defaultSubagentOnlyExtensions") or []
        if req_exts:
            exts = sub.setdefault("defaultSubagentOnlyExtensions", [])
            if not isinstance(exts, list):
                raise ValueError("'subagents.defaultSubagentOnlyExtensions' must be an array")
            exts.extend(ext for ext in req_exts if ext not in exts)
        inherit_agents = sub_policy.get("inherit_global_context_agents") or []
        if inherit_agents:
            overrides = sub.setdefault("agentOverrides", {})
            if not isinstance(overrides, dict):
                raise ValueError("'subagents.agentOverrides' must be a JSON object")
            for agent_name in inherit_agents:
                entry = overrides.setdefault(agent_name, {})
                if not isinstance(entry, dict):
                    raise ValueError(f"'subagents.agentOverrides.{agent_name}' must be an object")
                entry["inheritProjectContext"] = True
                entry["inheritGlobalContext"] = True

    if after == before and raw.strip():
        return raw
    return json.dumps(after, indent=2, ensure_ascii=False) + "\n"


HANDLERS = {
    "claude-settings": reconcile_claude_settings,
    "codex-config": reconcile_codex_config,
    "codex-hooks": reconcile_codex_hooks,
    "agy-hooks": reconcile_agy_hooks,
    "agy-mcp": reconcile_agy_mcp,
    "pi-settings": reconcile_pi_settings,
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("target", choices=sorted(HANDLERS))
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--spec", help="JSON control-plane payload")
    group.add_argument("--spec-file", help="Path to JSON control-plane payload (e.g. /dev/fd/3)")
    args = parser.parse_args()

    raw = sys.stdin.read()
    try:
        if args.spec_file:
            with open(args.spec_file, encoding="utf-8") as fh:
                spec = json.load(fh)
        else:
            spec = json.loads(args.spec)
        output = HANDLERS[args.target](raw, spec)
    except Exception as error:
        warn(args.target, f"left file unchanged: {error}")
        output = raw
    sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
