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

ROOT = Path(__file__).resolve().parents[2]
JAIL = ROOT / "dot_local/bin/executable_agent-jail"
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
    (home / ".secrets").mkdir(parents=True)
    (home / ".secrets/private.txt").write_text("SECRET_STORE\n")
    (home / ".codex").mkdir(parents=True)
    (home / ".codex/auth.json").write_text('{"token":"CODEX_AUTH"}\n')
    (home / ".pi/agent").mkdir(parents=True)
    (home / ".pi/agent/auth.json").write_text('{"token":"PI_AUTH"}\n')
    (home / ".config/dotfiles").mkdir(parents=True)
    (home / ".config/dotfiles/policy.json").write_text(json.dumps(POLICY))
    (home / "outside.txt").write_text("readonly-outside\n")

    env = {**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config")}

    def run_jail(*args):
        return subprocess.run(
            [sys.executable, str(JAIL), "--workspace", str(ws), *args],
            env=env,
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
    assert str(home / ".secrets") in plan["masked_dirs"]
    assert str(home / ".codex/auth.json") in plan["masked_files"]
    assert str(home / ".pi/agent/auth.json") in plan["masked_files"]
    assert str(ws / ".git/hooks") in plan["ro_overrides"]
    assert str(ws / ".git/config") in plan["ro_overrides"]

    # Agent-scoped plan allows ONLY the invoked agent's own auth file while masking others.
    dry_codex = run_jail("--backend", "bwrap", "--agent", "codex", "--dry-run", "--", "codex")
    assert dry_codex.returncode == 0, dry_codex.stderr
    codex_plan = json.loads(dry_codex.stdout)
    assert str(home / ".codex/auth.json") not in codex_plan["masked_files"]
    assert str(home / ".pi/agent/auth.json") in codex_plan["masked_files"]
    assert str(home / ".ssh/id_ed25519") in codex_plan["masked_files"]

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
