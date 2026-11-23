#!/usr/bin/env python3
"""Offline tests for the Rust `dotfiles` CLI (`doctor --json`, `agent`, `completion`)."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
assert shutil.which("chezmoi"), "chezmoi is required"


def find_rust_cli():
    override = os.environ.get("DOTFILES_CLI_BIN")
    if override:
        path = Path(override)
        assert path.is_file() and os.access(path, os.X_OK), f"DOTFILES_CLI_BIN not executable: {path}"
        return str(path)
    for candidate in (
        ROOT / "cli/target/release/dotfiles",
        ROOT / "cli/target/debug/dotfiles",
    ):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return str(candidate)
    found = shutil.which("dotfiles")
    assert found, "Rust `dotfiles` binary not found (run `cargo build --manifest-path cli/Cargo.toml` or install via mise)"
    return found


RUST_CLI = find_rust_cli()
CMD = [RUST_CLI]

# 1. --help prints usage and exits 0.
help_res = subprocess.run([*CMD, "--help"], text=True, capture_output=True, check=True)
assert (
    "doctor" in help_res.stdout
    and "jail" in help_res.stdout
    and "upgrade" in help_res.stdout
    and "host" in help_res.stdout
), help_res.stdout

host_help = subprocess.run([*CMD, "host", "--help"], text=True, capture_output=True, check=True)
for sub in ("keymap", "dgpu", "battery", "refresh", "logid"):
    assert sub in host_help.stdout, host_help.stdout
assert "fans" not in host_help.stdout, host_help.stdout

# 2. Unknown subcommand exits 2.
bad_res = subprocess.run([*CMD, "no-such-cmd"], text=True, capture_output=True, check=False)
assert bad_res.returncode == 2, bad_res

# 3. Run `dotfiles doctor --json` inside a disposable applied container home.
with tempfile.TemporaryDirectory(prefix="dotfiles-cli-") as tmp:
    home = Path(tmp)
    cfg = home / ".config/chezmoi/chezmoi.toml"
    state = home / "state.boltdb"
    env = {
        **os.environ,
        "HOME": str(home),
        "XDG_CONFIG_HOME": str(home / ".config"),
        "XDG_STATE_HOME": str(home / ".local/state"),
        "XDG_DATA_HOME": str(home / ".local/share"),
        "XDG_CACHE_HOME": str(home / ".cache"),
        "GIT_CONFIG_NOSYSTEM": "1",
    }
    subprocess.run(
        [
            "chezmoi", "--source", str(ROOT), "--destination", str(home),
            "--config", str(cfg), "--persistent-state", str(state),
            "init", "--apply", "--no-tty", "--exclude", "externals",
            "--promptString", "machine=container", "--promptString", "theme=rose-pine",
        ],
        env=env,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=True,
    )

    # Wrapper so `chezmoi` inside `dotfiles doctor` sees the isolated config/state.
    wrapper_dir = home / "shim"
    wrapper_dir.mkdir()
    real_chezmoi = shutil.which("chezmoi")
    chezmoi_shim = wrapper_dir / "chezmoi"
    chezmoi_shim.write_text(
        f'#!/bin/sh\nexec "{real_chezmoi}" --source "{ROOT}" --destination "{home}" '
        f'--config "{cfg}" --persistent-state "{state}" "$@"\n'
    )
    chezmoi_shim.chmod(0o755)
    test_env = {**env, "PATH": f"{wrapper_dir}{os.pathsep}{env['PATH']}"}

    doc_res = subprocess.run(
        [*CMD, "doctor", "--json"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    report = json.loads(doc_res.stdout)
    assert report["status"] in ("ok", "warn"), report
    assert report["checks"]["chezmoi"]["machine"] == "container", report
    assert report["checks"]["chezmoi"]["theme"] == "rose-pine", report
    assert report["checks"]["secrets"]["policy_json_valid"] is True, report
    assert report["checks"]["shell_git"]["env_sh"] is True, report
    assert report["checks"]["shell_git"]["git_xdg_config"] is True, report
    assert report["checks"]["system"]["status"] == "ok", report
    assert report["checks"]["toolchain"].get("shadow_dotfiles_bin") is None, report

    # Legacy local ~/.local/opt/dotfiles/bin/dotfiles triggers a doctor shadow warning.
    shadow_bin = home / ".local/opt/dotfiles/bin/dotfiles"
    shadow_bin.parent.mkdir(parents=True, exist_ok=True)
    shadow_bin.write_text("#!/bin/sh\n")
    shadow_bin.chmod(0o755)
    shadow_res = subprocess.run(
        [*CMD, "doctor", "--json"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    shadow_report = json.loads(shadow_res.stdout)
    assert shadow_report["checks"]["toolchain"]["shadow_dotfiles_bin"] == str(shadow_bin), shadow_report
    assert shadow_report["checks"]["toolchain"]["status"] == "warn", shadow_report
    shadow_bin.unlink()

    # Loose SSH private key permissions trigger an error exit code.
    bad_key = home / ".ssh/id_test_loose"
    bad_key.write_text("dummy\n")
    bad_key.chmod(0o644)
    loose_res = subprocess.run(
        [*CMD, "doctor", "--json"],
        env=test_env,
        text=True,
        capture_output=True,
        check=False,
    )
    assert loose_res.returncode == 1, loose_res
    loose_report = json.loads(loose_res.stdout)
    assert loose_report["checks"]["secrets"]["status"] == "error", loose_report
    assert loose_report["checks"]["secrets"]["loose_ssh_keys"][0]["name"] == "id_test_loose", loose_report
    bad_key.unlink()

    # `dotfiles agent status --json` and text output succeed cleanly.
    ag_res = subprocess.run(
        [*CMD, "agent", "status", "--json"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    ag_report = json.loads(ag_res.stdout)
    assert ag_report["agent_tools_selected"] is False, ag_report
    assert ag_report["agents"]["codex"]["sandbox_profile"] is False, ag_report

    # Codex sandbox_profile is reported in both JSON and text `dotfiles agent status`.
    codex_cfg = home / ".codex/config.toml"
    codex_cfg.parent.mkdir(parents=True, exist_ok=True)
    codex_cfg.write_text('default_permissions = "key-guard"\n')
    ag_txt = subprocess.run(
        [*CMD, "agent", "status"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    assert "codex" in ag_txt.stdout and "sandbox=ok" in ag_txt.stdout, ag_txt.stdout

    # Explicit `dotfiles jail --mask-gh -- codex` injects -s danger-full-access and --no-daemon.
    (home / ".config/gh").mkdir(parents=True, exist_ok=True)
    (home / ".config/gh/hosts.yml").write_text("github.com:\n  user: demo\n")
    jail_res = subprocess.run(
        [*CMD, "jail", "--backend", "bwrap", "--mask-gh", "--dry-run", "--", "codex", "resume", "--last"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    jail_plan = json.loads(jail_res.stdout)
    assert jail_plan["command"] == ["codex", "-s", "danger-full-access", "--no-daemon", "resume", "--last"], jail_plan
    assert str(home / ".config/gh/hosts.yml") in jail_plan["masked_files"], jail_plan

    # `dotfiles host status --json` and `dotfiles host keymap status --json` succeed cleanly.
    host_res = subprocess.run(
        [*CMD, "host", "status", "--json"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    host_report = json.loads(host_res.stdout)
    assert "keymap" in host_report and "system" in host_report, host_report

    km_res = subprocess.run(
        [*CMD, "host", "keymap", "status", "--json"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    km_report = json.loads(km_res.stdout)
    assert "installed" in km_report and "keyboards" in km_report, km_report

    comp_res = subprocess.run([*CMD, "completion", "zsh"], env=test_env, text=True, capture_output=True, check=True)
    assert comp_res.stdout.startswith("#compdef dotfiles")
    dyn_res = subprocess.run([*CMD, "__complete", "themes"], env=test_env, text=True, capture_output=True, check=True)
    assert "rose-pine:" in dyn_res.stdout

print(f"ok       Rust dotfiles CLI ({RUST_CLI}): help, doctor --json, loose-key detection, agent status, and completion pass")
