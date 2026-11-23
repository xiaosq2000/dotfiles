#!/usr/bin/env python3
"""Test agent-jail planning, policy unification, and live bwrap/Landlock isolation."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]
JAIL = ROOT / "dot_local/libexec/dotfiles/executable_agent-jail"
POLICY = tomllib.loads((ROOT / ".chezmoidata/policy.toml").read_text())["policy"]

# Verify check-secrets.py reads the exact same policy.toml lists.
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / ".github/scripts"))
import importlib.util

spec = importlib.util.spec_from_file_location("check_secrets", ROOT / ".github/scripts/check-secrets.py")
cs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cs)
assert list(cs.PROTECTED) == POLICY["repo"]["protected_source_dirs"]
assert cs.HOME_EXCEPTIONS == set(POLICY["repo"]["home_path_exceptions"])

with tempfile.TemporaryDirectory(prefix="dotfiles-jail-") as tmp:
    base = Path(tmp)
    home = base / "home"
    ws = home / "work"
    (ws / ".git/hooks").mkdir(parents=True)
    (ws / ".git/config").write_text("[core]\n\trepositoryformatversion = 0\n")
    (ws / ".git/hooks/pre-commit").write_text("#!/bin/sh\nexit 0\n")

    # Seed realistic secret fixtures in the disposable home.
    (home / ".ssh").mkdir(parents=True)
    (home / ".ssh/id_ed25519").write_text("SECRET_SSH_KEY\n")
    (home / ".ssh/id_ed25519.pub").write_text("ssh-ed25519 AAAAC3PUBLIC\n")
    (home / ".ssh/config").write_text("Host demo\n")
    (home / ".config/chezmoi").mkdir(parents=True)
    (home / ".config/chezmoi/key.txt").write_text("SECRET_AGE_KEY\n")
    (home / ".config/chezmoi/chezmoi.toml").write_text('[data]\nmachine = "test"\n')
    (home / ".config/gh").mkdir(parents=True)
    (home / ".config/gh/hosts.yml").write_text("github.com:\n  user: demo\n")
    (home / ".cargo").mkdir(parents=True)
    (home / ".cargo/credentials.toml").write_text("[registry]\ntoken = \"CARGO_SECRET\"\n")
    (home / ".secrets").mkdir(parents=True)
    (home / ".secrets/private.txt").write_text("SECRET_STORE\n")
    (home / ".claude").mkdir(parents=True)
    (home / ".claude.json").write_text('{"numStartups":1}\n')
    (home / ".codex").mkdir(parents=True)
    (home / ".codex/auth.json").write_text('{"token":"CODEX_AUTH"}\n')
    (home / ".pi/agent").mkdir(parents=True)
    (home / ".pi/agent/auth.json").write_text('{"token":"PI_AUTH"}\n')
    machine_pixi = base / "external-pixi"
    machine_pixi.mkdir(parents=True)
    alt_ws = base / "alt-work"
    alt_ws.mkdir(parents=True)
    extra_dir = base / "datasets"
    extra_dir.mkdir(parents=True)
    env_extra_dir = base / "env-extra"
    env_extra_dir.mkdir(parents=True)

    policy_with_machine = json.loads(json.dumps(POLICY))
    policy_with_machine["jail"]["machine_rw_dirs"] = [str(machine_pixi)]
    (home / ".config/dotfiles").mkdir(parents=True)
    (home / ".config/dotfiles/policy.json").write_text(json.dumps(policy_with_machine))
    (home / "outside.txt").write_text("readonly-outside\n")

    env = {
        **os.environ,
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
    }
    env.pop("DOTFILES_AGENT_JAIL", None)
    env.pop("DOTFILES_AGENT_JAIL_BACKEND", None)
    env.pop("DOTFILES_NO_JAIL", None)
    env.pop("DOTFILES_JAIL_RW", None)
    env.pop("DOTFILES_JAIL_MASK_GH", None)

    def run_jail(*args, extra_env=None, pass_workspace=True):
        cmd = [sys.executable, str(JAIL)]
        if pass_workspace:
            cmd.extend(["--workspace", str(ws)])
        cmd.extend(args)
        merged_env = {**env, **(extra_env or {})}
        return subprocess.run(
            cmd,
            env=merged_env,
            text=True,
            capture_output=True,
            check=False,
        )

    # 1. Dry-run plan check (works everywhere, including restricted CI containers).
    dry_generic = run_jail("--backend", "bwrap", "--dry-run", "--", "/bin/true")
    assert dry_generic.returncode == 0, dry_generic.stderr
    plan = json.loads(dry_generic.stdout)
    assert str(home / ".ssh/id_ed25519") in plan["masked_files"]
    assert str(home / ".ssh/id_ed25519.pub") not in plan["masked_files"]
    assert str(home / ".ssh/config") not in plan["masked_files"]
    assert str(home / ".config/chezmoi/key.txt") in plan["masked_files"]
    assert str(home / ".config/gh/hosts.yml") not in plan["masked_files"]
    assert str(home / ".cargo/credentials.toml") in plan["masked_files"]
    assert str(home / ".cargo") in plan["rw_dirs"]
    assert str(machine_pixi) in plan["rw_dirs"]
    assert str(home / ".secrets") in plan["masked_dirs"]
    assert str(home / ".codex/auth.json") in plan["masked_files"]
    assert str(home / ".pi/agent/auth.json") in plan["masked_files"]
    assert str(ws / ".git/hooks") in plan["ro_overrides"]
    assert str(ws / ".git/config") in plan["ro_overrides"]

    # --mask-gh explicitly masks ~/.config/gh/hosts.yml.
    dry_mask_gh = run_jail("--backend", "bwrap", "--mask-gh", "--dry-run", "--", "/bin/true")
    assert dry_mask_gh.returncode == 0, dry_mask_gh.stderr
    assert str(home / ".config/gh/hosts.yml") in json.loads(dry_mask_gh.stdout)["masked_files"]

    # Claude profile binds ~/.claude.json RW alongside ~/.claude.
    dry_claude = run_jail("--backend", "bwrap", "--wrap", "claude", "--dry-run")
    assert dry_claude.returncode == 0, dry_claude.stderr
    claude_plan = json.loads(dry_claude.stdout)
    assert str(home / ".claude.json") in claude_plan["rw_files"]

    # Agent-scoped plan allows ONLY the invoked agent's own auth file while masking others,
    # and auto-adapts codex sandbox flag + -C/--add-dir + DOTFILES_JAIL_RW.
    dry_codex = run_jail(
        "--backend",
        "bwrap",
        "--wrap",
        "codex",
        "--dry-run",
        "--",
        "-C",
        str(alt_ws),
        "--add-dir",
        str(extra_dir),
        "hello",
        extra_env={"DOTFILES_JAIL_RW": str(env_extra_dir)},
        pass_workspace=False,
    )
    assert dry_codex.returncode == 0, dry_codex.stderr
    codex_plan = json.loads(dry_codex.stdout)
    assert str(home / ".codex/auth.json") not in codex_plan["masked_files"]
    assert str(home / ".pi/agent/auth.json") in codex_plan["masked_files"]
    assert str(home / ".ssh/id_ed25519") in codex_plan["masked_files"]
    assert codex_plan["workspace"] == str(alt_ws.resolve())
    assert str(extra_dir.resolve()) in codex_plan["rw_dirs"]
    assert str(env_extra_dir.resolve()) in codex_plan["rw_dirs"]
    assert codex_plan["command"][:4] == ["codex", "-s", "danger-full-access", "--no-daemon"]

    # Explicit user --sandbox flag on codex is preserved while still injecting --no-daemon.
    dry_codex_ro = run_jail("--backend", "bwrap", "--wrap", "codex", "--dry-run", "--", "--sandbox", "read-only")
    assert dry_codex_ro.returncode == 0, dry_codex_ro.stderr
    assert json.loads(dry_codex_ro.stdout)["command"] == ["codex", "--no-daemon", "--sandbox", "read-only"]

    # Explicit --no-daemon is not duplicated; explicit --remote suppresses --no-daemon.
    dry_codex_nodaemon = run_jail("--backend", "bwrap", "--wrap", "codex", "--dry-run", "--", "--no-daemon", "hello")
    assert dry_codex_nodaemon.returncode == 0, dry_codex_nodaemon.stderr
    assert json.loads(dry_codex_nodaemon.stdout)["command"] == ["codex", "-s", "danger-full-access", "--no-daemon", "hello"]

    for remote_args in (
        ["--remote", "ws://127.0.0.1:9000"],
        ["--remote=unix:///tmp/demo.sock"],
        ["resume", "--remote", "ws://127.0.0.1:9000"],
    ):
        dry_remote = run_jail("--backend", "bwrap", "--wrap", "codex", "--dry-run", "--", *remote_args)
        assert dry_remote.returncode == 0, dry_remote.stderr
        cmd_out = json.loads(dry_remote.stdout)["command"]
        assert cmd_out == ["codex", "-s", "danger-full-access", *remote_args], cmd_out

    # Explicit `agent-jail --mask-gh -- codex <subcmd>` injects flags before subcommands.
    for subcmd_args in (
        ["resume", "--last"],
        ["fork", "--last"],
        ["exec", "summarize"],
    ):
        dry_sub = run_jail("--backend", "bwrap", "--mask-gh", "--dry-run", "--", "codex", *subcmd_args)
        assert dry_sub.returncode == 0, dry_sub.stderr
        sub_plan = json.loads(dry_sub.stdout)
        assert sub_plan["command"] == ["codex", "-s", "danger-full-access", "--no-daemon", *subcmd_args], sub_plan
        assert str(home / ".config/gh/hosts.yml") in sub_plan["masked_files"]
        assert str(home / ".codex/auth.json") not in sub_plan["masked_files"]

    # Codex passthrough subcommands and meta flags receive no injected flags.
    for passthrough_args in (["--version"], ["login"]):
        dry_pt = run_jail("--backend", "bwrap", "--dry-run", "--", "codex", *passthrough_args)
        assert dry_pt.returncode == 0, dry_pt.stderr
        assert json.loads(dry_pt.stdout)["command"] == ["codex", *passthrough_args]

    # --wrap agy injects --dangerously-skip-permissions for interactive runs only.
    dry_agy = run_jail("--backend", "bwrap", "--wrap", "agy", "--dry-run")
    assert dry_agy.returncode == 0, dry_agy.stderr
    assert json.loads(dry_agy.stdout)["command"] == ["agy", "--dangerously-skip-permissions"]

    # Verify DOTFILES_NO_JAIL=1 and DOTFILES_AGENT_JAIL=1 wrapper semantics with stub binaries.
    stub_bin = base / "stub-bin"
    stub_bin.mkdir()
    for name in ("codex", "agy"):
        stub = stub_bin / name
        stub.write_text("#!/bin/sh\nprintf 'JAIL=%s ARGS=%s\\n' \"${DOTFILES_AGENT_JAIL:-0}\" \"$*\"\n")
        stub.chmod(0o755)
    stub_env = {"PATH": f"{stub_bin}:{env.get('PATH', '')}"}

    r_no_jail_codex = run_jail("--wrap", "codex", "--", "hi", extra_env={**stub_env, "DOTFILES_NO_JAIL": "1"})
    assert r_no_jail_codex.returncode == 0 and r_no_jail_codex.stdout.strip() == "JAIL=0 ARGS=hi", r_no_jail_codex

    r_nested_codex = run_jail("--wrap", "codex", "--", "hi", extra_env={**stub_env, "DOTFILES_AGENT_JAIL": "1"})
    assert r_nested_codex.returncode == 0
    assert r_nested_codex.stdout.strip() == "JAIL=1 ARGS=-s danger-full-access --no-daemon hi", r_nested_codex

    # Verify interactive dot_zshrc and dot_bashrc wrap claude/agy/pi but run codex directly.
    shell_stub_bin = base / "shell-stub-bin"
    shell_stub_bin.mkdir()
    for name in ("claude", "codex", "agy", "pi"):
        s = shell_stub_bin / name
        s.write_text(f"#!/bin/sh\nprintf 'DIRECT:{name}:%s\\n' \"$*\"\n")
        s.chmod(0o755)
    fake_jail = home / ".local/libexec/dotfiles/agent-jail"
    fake_jail.parent.mkdir(parents=True, exist_ok=True)
    fake_jail.write_text("#!/bin/sh\nprintf 'JAILED:%s\\n' \"$*\"\n")
    fake_jail.chmod(0o755)

    zshrc_text = (ROOT / "dot_zshrc").read_text(encoding="utf-8")
    bashrc_text = (ROOT / "dot_bashrc").read_text(encoding="utf-8")
    assert "codex()" not in zshrc_text and "codex:" not in zshrc_text
    assert "codex()" not in bashrc_text and "codex:" not in bashrc_text

    # Extract the agent-jail wrapper blocks and run them in real bash and zsh.
    zsh_block_start = zshrc_text.index("unjail()")
    zsh_block_end = zshrc_text.index("\nsetup_texlive()", zsh_block_start)
    zsh_block = zshrc_text[zsh_block_start:zsh_block_end]

    bash_block_start = bashrc_text.index("unjail()")
    bash_block_end = bashrc_text.index("\n# Proxy client", bash_block_start)
    bash_block = bashrc_text[bash_block_start:bash_block_end]

    shell_env = {**env, "PATH": f"{shell_stub_bin}:{env.get('PATH', '')}"}
    for shell_bin, has_def, block in (
        ("bash", "_has() { command -v \"$1\" >/dev/null 2>&1; }", bash_block),
        ("zsh", "has() { command -v \"$1\" >/dev/null 2>&1; }", zsh_block),
    ):
        if not shutil.which(shell_bin):
            continue
        script = "\n".join([
            has_def,
            block,
            'claude hi',
            'agy hi',
            'pi hi',
            'codex hi',
        ])
        sh_res = subprocess.run([shell_bin, "-c", script], env=shell_env, text=True, capture_output=True, check=True)
        lines = sh_res.stdout.strip().splitlines()
        assert lines == [
            "JAILED:--wrap claude -- hi",
            "JAILED:--wrap agy -- hi",
            "JAILED:--wrap pi -- hi",
            "DIRECT:codex:hi",
        ], (shell_bin, lines, sh_res.stderr)

    r_no_jail_agy = run_jail("--wrap", "agy", "--", "hi", extra_env={**stub_env, "DOTFILES_NO_JAIL": "1"})
    assert r_no_jail_agy.returncode == 0
    assert r_no_jail_agy.stdout.strip() == "JAIL=0 ARGS=--dangerously-skip-permissions hi", r_no_jail_agy

    r_passthrough_agy = run_jail("--wrap", "agy", "--", "--version", extra_env=stub_env)
    assert r_passthrough_agy.returncode == 0
    assert r_passthrough_agy.stdout.strip() == "JAIL=0 ARGS=--version", r_passthrough_agy

    # 2. Live bwrap enforcement (when permitted by host/container).
    bwrap_ok = bool(shutil.which("bwrap")) and subprocess.run(
        ["bwrap", "--ro-bind", "/", "/", "--dev", "/dev", "--proc", "/proc", "--", "/bin/true"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    ).returncode == 0
    if bwrap_ok:
        # Masked files yield zero secret bytes (/dev/null EOF or EACCES on nodev mounts);
        # public SSH files remain readable.
        r = run_jail("--backend", "bwrap", "--", "/bin/cat", str(home / ".ssh/id_ed25519"))
        assert r.stdout == "" and "SECRET_SSH_KEY" not in r.stdout, r
        r = run_jail("--backend", "bwrap", "--", "/bin/cat", str(home / ".config/chezmoi/key.txt"))
        assert r.stdout == "" and "SECRET_AGE_KEY" not in r.stdout, r
        r = run_jail("--backend", "bwrap", "--", "/bin/ls", "-A", str(home / ".secrets"))
        assert r.returncode == 0 and r.stdout.strip() == "", r
        r = run_jail("--backend", "bwrap", "--", "/bin/cat", str(home / ".ssh/id_ed25519.pub"))
        assert r.returncode == 0 and "AAAAC3PUBLIC" in r.stdout, r
        # Workspace is writable; outside and .git/hooks are read-only.
        r = run_jail("--backend", "bwrap", "--", "/bin/sh", "-c", "echo ok > probe.txt")
        assert r.returncode == 0 and (ws / "probe.txt").read_text() == "ok\n", r
        r = run_jail("--backend", "bwrap", "--", "/bin/sh", "-c", f"echo bad > {home / 'outside.txt'}")
        assert r.returncode != 0, "bwrap allowed write outside workspace"
        r = run_jail("--backend", "bwrap", "--", "/bin/sh", "-c", f"echo bad > {ws / '.git/hooks/pre-commit'}")
        assert r.returncode != 0, "bwrap allowed write to .git/hooks"
        # gh hosts.yml is readable by default (for gh pr/run) and masked with --mask-gh.
        r = run_jail("--backend", "bwrap", "--", "/bin/cat", str(home / ".config/gh/hosts.yml"))
        assert r.returncode == 0 and "github.com" in r.stdout, r
        r = run_jail("--backend", "bwrap", "--mask-gh", "--", "/bin/cat", str(home / ".config/gh/hosts.yml"))
        assert r.stdout == "" and "github.com" not in r.stdout, r
        # ~/.cargo is RW while ~/.cargo/credentials.toml stays masked.
        r = run_jail("--backend", "bwrap", "--", "/bin/cat", str(home / ".cargo/credentials.toml"))
        assert r.stdout == "" and "CARGO_SECRET" not in r.stdout, r
        # Agent profile allows own auth while masking other agent auth.
        r = run_jail("--backend", "bwrap", "--agent", "codex", "--", "/bin/cat", str(home / ".codex/auth.json"))
        assert r.returncode == 0 and "CODEX_AUTH" in r.stdout, r
        r = run_jail("--backend", "bwrap", "--agent", "codex", "--", "/bin/cat", str(home / ".pi/agent/auth.json"))
        assert r.stdout == "" and "PI_AUTH" not in r.stdout, r
        print("ok       agent-jail live bwrap enforcement passed")

    # 3. Live Landlock enforcement (when active in kernel).
    probe_ll = run_jail("--backend", "landlock", "--", "/bin/true")
    if probe_ll.returncode == 0:
        r = run_jail("--backend", "landlock", "--", "/bin/cat", str(home / ".ssh/id_ed25519"))
        assert r.returncode != 0 and "SECRET_SSH_KEY" not in r.stdout, r
        r = run_jail("--backend", "landlock", "--", "/bin/cat", str(home / ".config/chezmoi/key.txt"))
        assert r.returncode != 0 and "SECRET_AGE_KEY" not in r.stdout, r
        r = run_jail("--backend", "landlock", "--", "/bin/cat", str(home / ".secrets/private.txt"))
        assert r.returncode != 0 and "SECRET_STORE" not in r.stdout, r
        r = run_jail("--backend", "landlock", "--", "/bin/cat", str(home / ".ssh/id_ed25519.pub"))
        assert r.returncode == 0 and "AAAAC3PUBLIC" in r.stdout, r
        r = run_jail("--backend", "landlock", "--", "/bin/sh", "-c", "echo ll > ll.txt")
        assert r.returncode == 0 and (ws / "ll.txt").read_text() == "ll\n", r
        r = run_jail("--backend", "landlock", "--", "/bin/sh", "-c", f"echo bad > {home / 'outside.txt'}")
        assert r.returncode != 0, "landlock allowed write outside workspace"
        # Agent profile allows own auth while still blocking other agent auth under Landlock.
        r = run_jail("--backend", "landlock", "--agent", "codex", "--", "/bin/cat", str(home / ".codex/auth.json"))
        assert r.returncode == 0 and "CODEX_AUTH" in r.stdout, r
        r = run_jail("--backend", "landlock", "--agent", "codex", "--", "/bin/cat", str(home / ".pi/agent/auth.json"))
        assert r.returncode != 0 and "PI_AUTH" not in r.stdout, r
        print("ok       agent-jail live Landlock enforcement passed")

print("ok       agent-jail policy unification and sandbox checks passed")
