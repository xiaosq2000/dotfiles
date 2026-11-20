#!/usr/bin/env python3
"""Offline unit and end-to-end stub tests for `dotfiles upgrade`."""

import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "dot_local/libexec/dotfiles/executable_upgrade-toolchain.py"

loader = importlib.machinery.SourceFileLoader("upgrade_toolchain", str(SCRIPT))
spec = importlib.util.spec_from_loader("upgrade_toolchain", loader)
mod = importlib.util.module_from_spec(spec)
loader.exec_module(mod)


def test_parse_only():
    assert mod.parse_only(None) == ["mise", "pixi", "fetch", "sheldon", "pi"]
    assert mod.parse_only(["sheldon,mise"]) == ["mise", "sheldon"]
    assert mod.parse_only(["pi", "pixi,fetch"]) == ["pixi", "fetch", "pi"]
    try:
        mod.parse_only(["unknown"])
    except ValueError:
        pass
    else:
        raise AssertionError("expected ValueError for invalid layer")


def test_end_to_end_preserves_proxy_env():
    with tempfile.TemporaryDirectory(prefix="dotfiles-upgrade-") as tmp:
        base = Path(tmp)
        home = base / "home"
        stubs = base / "stubs"
        log_file = base / "calls.jsonl"
        home.mkdir()
        stubs.mkdir()

        logger_preamble = (
            "import json, os, sys\n"
            "from pathlib import Path\n"
            'with Path(os.environ["UPGRADE_TEST_LOG"]).open("a") as fh:\n'
            '    fh.write(json.dumps({"cmd": Path(sys.argv[0]).name, "args": sys.argv[1:], '
            '"http_proxy": os.environ.get("http_proxy"), "https_proxy": os.environ.get("https_proxy")}) + "\\n")\n'
        )

        def make_stub(path):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"#!/usr/bin/env python3\n{logger_preamble}\n", encoding="utf-8")
            path.chmod(0o755)

        for tool in ("mise", "pixi", "sheldon", "pi", "dotfiles"):
            make_stub(stubs / tool)
        make_stub(home / ".local/libexec/dotfiles/dotfiles-fetch")

        env = {
            **os.environ,
            "HOME": str(home),
            "PATH": f"{stubs}{os.pathsep}{os.environ['PATH']}",
            "UPGRADE_TEST_LOG": str(log_file),
            "http_proxy": "http://proxy.example:1080",
            "https_proxy": "http://proxy.example:1080",
            "GITHUB_TOKEN": "stub-token",
        }

        # 1. Dry run inspects outdated tools without upgrading.
        dry = subprocess.run(
            [sys.executable, str(SCRIPT), "--dry-run"],
            env=env,
            text=True,
            capture_output=True,
            check=True,
        )
        assert "inheriting shell proxy" in dry.stdout
        dry_calls = [json.loads(line) for line in log_file.read_text(encoding="utf-8").splitlines()]
        dry_invoked = [(c["cmd"], c["args"]) for c in dry_calls]
        assert ("mise", ["outdated"]) in dry_invoked
        assert ("dotfiles-fetch", ["outdated"]) in dry_invoked
        assert ("mise", ["upgrade"]) not in dry_invoked
        assert ("dotfiles", ["doctor"]) not in dry_invoked
        log_file.unlink()

        # 2. Full upgrade runs all 5 layers + doctor and preserves proxy env for every child.
        subprocess.run(
            [sys.executable, str(SCRIPT)],
            env=env,
            text=True,
            capture_output=True,
            check=True,
        )
        calls = [json.loads(line) for line in log_file.read_text(encoding="utf-8").splitlines()]
        assert calls, "expected recorded tool invocations"
        for call in calls:
            assert call["http_proxy"] == "http://proxy.example:1080", call
            assert call["https_proxy"] == "http://proxy.example:1080", call
        invoked = [(c["cmd"], c["args"]) for c in calls]
        assert ("mise", ["upgrade"]) in invoked
        assert ("mise", ["reshim"]) in invoked
        assert ("pixi", ["global", "update"]) in invoked
        assert ("dotfiles-fetch", ["update"]) in invoked
        assert ("sheldon", ["--non-interactive", "lock", "--update"]) in invoked
        assert ("pi", ["update", "--extensions"]) in invoked
        assert ("dotfiles", ["doctor"]) in invoked


if __name__ == "__main__":
    test_parse_only()
    test_end_to_end_preserves_proxy_env()
    print("ok       dotfiles upgrade: 5-layer local upgrades and proxy env inheritance pass")
