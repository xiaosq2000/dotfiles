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
    and "keymap" in help_res.stdout
), help_res.stdout

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

    # `dotfiles agent status --json` succeeds cleanly.
    ag_res = subprocess.run(
        [*CMD, "agent", "status", "--json"],
        env=test_env,
        text=True,
        capture_output=True,
        check=True,
    )
    ag_report = json.loads(ag_res.stdout)
    assert ag_report["agent_tools_selected"] is False, ag_report

    # `dotfiles keymap status --json` succeeds cleanly even without keyd/systemd.
    km_res = subprocess.run(
        [*CMD, "keymap", "status", "--json"],
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
