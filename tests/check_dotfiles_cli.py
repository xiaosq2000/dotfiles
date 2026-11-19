#!/usr/bin/env python3
"""Offline tests for the unified `dotfiles` CLI (`doctor --json`, `agent`, `help`)."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "dot_local/bin/executable_dotfiles"
RUST_CLI = ROOT / "cli/target/release/dotfiles"
assert shutil.which("chezmoi"), "chezmoi is required"

TARGETS = [("python", [sys.executable, str(CLI)])]
if RUST_CLI.is_file() and os.access(RUST_CLI, os.X_OK):
    TARGETS.append(("rust", [str(RUST_CLI)]))

for label, cmd_prefix in TARGETS:
    # 1. --help prints usage and exits 0.
    help_res = subprocess.run([*cmd_prefix, "--help"], text=True, capture_output=True, check=True)
    assert "doctor" in help_res.stdout and "jail" in help_res.stdout and "upgrade" in help_res.stdout, (label, help_res.stdout)

    # 2. Unknown subcommand exits 2.
    bad_res = subprocess.run([*cmd_prefix, "no-such-cmd"], text=True, capture_output=True, check=False)
    assert bad_res.returncode == 2, (label, bad_res)

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

    for label, cmd_prefix in TARGETS:
        doc_res = subprocess.run(
            [*cmd_prefix, "doctor", "--json"],
            env=test_env,
            text=True,
            capture_output=True,
            check=True,
        )
        report = json.loads(doc_res.stdout)
        assert report["status"] in ("ok", "warn"), (label, report)
        assert report["checks"]["chezmoi"]["machine"] == "container", (label, report)
        assert report["checks"]["chezmoi"]["theme"] == "rose-pine", (label, report)
        assert report["checks"]["secrets"]["policy_json_valid"] is True, (label, report)
        assert report["checks"]["shell_git"]["env_sh"] is True, (label, report)
        assert report["checks"]["shell_git"]["git_xdg_config"] is True, (label, report)

        # Loose SSH private key permissions trigger an error exit code.
        bad_key = home / ".ssh/id_test_loose"
        bad_key.write_text("dummy\n")
        bad_key.chmod(0o644)
        loose_res = subprocess.run(
            [*cmd_prefix, "doctor", "--json"],
            env=test_env,
            text=True,
            capture_output=True,
            check=False,
        )
        assert loose_res.returncode == 1, (label, loose_res)
        loose_report = json.loads(loose_res.stdout)
        assert loose_report["checks"]["secrets"]["status"] == "error", (label, loose_report)
        assert loose_report["checks"]["secrets"]["loose_ssh_keys"][0]["name"] == "id_test_loose", (label, loose_report)
        bad_key.unlink()

        # `dotfiles agent status --json` succeeds cleanly.
        ag_res = subprocess.run(
            [*cmd_prefix, "agent", "status", "--json"],
            env=test_env,
            text=True,
            capture_output=True,
            check=True,
        )
        ag_report = json.loads(ag_res.stdout)
        assert ag_report["agent_tools_selected"] is False, (label, ag_report)

        if label == "rust":
            comp_res = subprocess.run([*cmd_prefix, "completion", "zsh"], env=test_env, text=True, capture_output=True, check=True)
            assert comp_res.stdout.startswith("#compdef dotfiles")
            dyn_res = subprocess.run([*cmd_prefix, "__complete", "themes"], env=test_env, text=True, capture_output=True, check=True)
            assert "rose-pine:" in dyn_res.stdout

tested = ", ".join(label for label, _ in TARGETS)
print(f"ok       dotfiles CLI ({tested}): help, doctor --json, loose-key detection, and agent status pass")
