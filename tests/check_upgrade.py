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
    assert mod.parse_only(None) == ["mise", "pixi", "fetch", "sheldon"]
    assert mod.parse_only(["sheldon,mise"]) == ["mise", "sheldon"]
    assert mod.parse_only(["fetch", "pixi,fetch"]) == ["pixi", "fetch"]
    try:
        mod.parse_only(["unknown"])
    except ValueError:
        pass
    else:
        raise AssertionError("expected ValueError for invalid layer")


def test_version_helpers():
    assert mod.version_key("0.170.0") > mod.version_key("0.169.9")
    assert mod.version_key("1.2.3") > mod.version_key("1.2.3-rc.1")
    assert mod.version_key("26.07") > mod.version_key("26.06")
    assert mod.version_key("2026-05-01") > mod.version_key("2026-02-08")
    assert mod.major_version("24.22.3") == 24
    assert mod.major_version("0.170.0") == 0
    assert mod.major_version("2026-02-08") is None


def test_format_and_resolve():
    node_spec = {"tool": "node", "version": "24.22.3", "track": "24"}
    assert mod.format_mise_spec(node_spec) == "node@24"
    cli_spec = {"tool": "github:xiaosq2000/dotfiles", "version": "0.1.3", "version_prefix": "cli-v"}
    assert mod.format_mise_spec(cli_spec) == "github:xiaosq2000/dotfiles[version_prefix=cli-v]"

    # Normal upgrade.
    res = mod.resolve_mise_upgrade(
        "ripgrep",
        {"tool": "aqua:BurntSushi/ripgrep", "version": "15.2.0"},
        lambda _s: (0, "15.3.0", ""),
    )
    assert res["status"] == "upgrade" and res["new_version"] == "15.3.0"

    # Never downgrade if release-age cooldown hides current pin.
    res = mod.resolve_mise_upgrade(
        "codex",
        {"tool": "aqua:openai/codex", "version": "0.170.0"},
        lambda _s: (0, "0.169.0", ""),
    )
    assert res["status"] == "unchanged"

    # Empty latest output stays unchanged.
    res = mod.resolve_mise_upgrade(
        "codex",
        {"tool": "aqua:openai/codex", "version": "0.170.0"},
        lambda _s: (0, "", ""),
    )
    assert res["status"] == "unchanged"

    # --no-major upgrades within same major when a minor/patch exists.
    def fake_major(spec_str):
        if spec_str.endswith("@1"):
            return (0, "1.9.2", "")
        return (0, "2.0.0", "")

    res = mod.resolve_mise_upgrade(
        "demo",
        {"tool": "aqua:acme/demo", "version": "1.8.0"},
        fake_major,
        no_major=True,
    )
    assert res["status"] == "upgrade" and res["new_version"] == "1.9.2" and res["held_major"] == "2.0.0"

    # --no-major holds when already on latest in current major.
    def fake_major_held(spec_str):
        if spec_str.endswith("@1"):
            return (0, "1.8.0", "")
        return (0, "2.0.0", "")

    res = mod.resolve_mise_upgrade(
        "demo",
        {"tool": "aqua:acme/demo", "version": "1.8.0"},
        fake_major_held,
        no_major=True,
    )
    assert res["status"] == "held" and res["held_major"] == "2.0.0"


def test_rewriters():
    sample = (
        "# Header comment\n"
        "[mise.gitleaks]\n"
        "# Keep comment\n"
        'tool = "aqua:gitleaks/gitleaks"\n'
        'version = "8.30.1"\n'
        "\n"
        "[mise.node]\n"
        'tool = "node"\n'
        'version = "24.22.3"\n'
        'track = "24"\n'
    )
    updated = mod.rewrite_mise_catalog(sample, {"gitleaks": "8.31.0", "node": "24.23.0"})
    assert "# Header comment" in updated and "# Keep comment" in updated
    assert 'version = "8.31.0"' in updated
    assert 'version = "24.23.0"' in updated
    assert 'track = "24"' in updated

    hook = 'import os\nVERSION = "8.30.1"\nOTHER = "1.0"\n'
    new_hook = mod.rewrite_check_secrets_version(hook, "8.31.0")
    assert 'VERSION = "8.31.0"' in new_hook and 'OTHER = "1.0"' in new_hook


def test_end_to_end_preserves_proxy_env():
    with tempfile.TemporaryDirectory(prefix="dotfiles-upgrade-") as tmp:
        base = Path(tmp)
        repo = base / "repo"
        home = base / "home"
        stubs = base / "stubs"
        log_file = base / "calls.jsonl"
        (repo / ".chezmoidata").mkdir(parents=True)
        (repo / ".github/scripts").mkdir(parents=True)
        home.mkdir()
        stubs.mkdir()

        mise_toml = repo / ".chezmoidata/mise.toml"
        mise_toml.write_text(
            '[mise.dotfiles-cli]\n'
            'tool = "github:xiaosq2000/dotfiles"\n'
            'version = "0.1.3"\n'
            'version_prefix = "cli-v"\n'
            'bin = "dotfiles"\n'
            '\n'
            '[mise.gitleaks]\n'
            'tool = "aqua:gitleaks/gitleaks"\n'
            'version = "8.30.1"\n'
            '\n'
            '[mise.node]\n'
            'tool = "node"\n'
            'version = "24.22.3"\n'
            'track = "24"\n',
            encoding="utf-8",
        )
        hook_py = repo / ".github/scripts/check-secrets.py"
        hook_py.write_text('VERSION = "8.30.1"\n', encoding="utf-8")

        def make_stub(name, body):
            path = stubs / name
            path.write_text(f"#!/usr/bin/env python3\n{body}\n", encoding="utf-8")
            path.chmod(0o755)

        logger_preamble = (
            "import json, os, sys\n"
            "from pathlib import Path\n"
            'with Path(os.environ["UPGRADE_TEST_LOG"]).open("a") as fh:\n'
            '    fh.write(json.dumps({"cmd": Path(sys.argv[0]).name, "args": sys.argv[1:], '
            '"http_proxy": os.environ.get("http_proxy"), "https_proxy": os.environ.get("https_proxy")}) + "\\n")\n'
        )
        make_stub(
            "mise",
            logger_preamble
            + 'if sys.argv[1:2] == ["latest"]:\n'
            + '    spec = sys.argv[2]\n'
            + '    if spec == "aqua:gitleaks/gitleaks": print("8.31.0")\n'
            + '    elif spec == "node@24": print("24.23.1")\n'
            + '    else: print("9.9.9")\n',
        )
        make_stub(
            "chezmoi",
            logger_preamble
            + f'if sys.argv[1:2] == ["source-path"]: print({str(repo)!r})\n',
        )
        for tool in ("pixi", "sheldon", "dotfiles"):
            make_stub(tool, logger_preamble)
        libexec = home / ".local/libexec/dotfiles"
        libexec.mkdir(parents=True)
        fetch_stub = libexec / "dotfiles-fetch"
        fetch_stub.write_text(f"#!/usr/bin/env python3\n{logger_preamble}\n", encoding="utf-8")
        fetch_stub.chmod(0o755)

        env = {
            **os.environ,
            "HOME": str(home),
            "PATH": f"{stubs}{os.pathsep}{os.environ['PATH']}",
            "UPGRADE_TEST_LOG": str(log_file),
            "http_proxy": "http://proxy.example:1080",
            "https_proxy": "http://proxy.example:1080",
            "GITHUB_TOKEN": "stub-token",
        }

        # 1. Dry run inspects without modifying repo files.
        dry = subprocess.run(
            [sys.executable, str(SCRIPT), "--dry-run"],
            env=env,
            cwd=repo,
            text=True,
            capture_output=True,
            check=True,
        )
        assert "inheriting shell proxy" in dry.stdout
        assert "8.30.1 -> 8.31.0" in dry.stdout
        assert "24.22.3 -> 24.23.1" in dry.stdout
        assert 'version = "8.30.1"' in mise_toml.read_text(encoding="utf-8")
        assert 'VERSION = "8.30.1"' in hook_py.read_text(encoding="utf-8")
        log_file.unlink()

        # 2. Full upgrade updates mise.toml, syncs gitleaks hook, runs all layers,
        # skips self-released dotfiles-cli, and preserves proxy env for every child!
        real = subprocess.run(
            [sys.executable, str(SCRIPT)],
            env=env,
            cwd=repo,
            text=True,
            capture_output=True,
            check=True,
        )
        assert "Next steps" in real.stdout
        new_mise = mise_toml.read_text(encoding="utf-8")
        assert 'version = "0.1.3"' in new_mise  # dotfiles-cli untouched
        assert 'version = "8.31.0"' in new_mise
        assert 'version = "24.23.1"' in new_mise
        assert 'VERSION = "8.31.0"' in hook_py.read_text(encoding="utf-8")

        calls = [json.loads(line) for line in log_file.read_text(encoding="utf-8").splitlines()]
        assert calls, "expected recorded tool invocations"
        for call in calls:
            assert call["http_proxy"] == "http://proxy.example:1080", call
            assert call["https_proxy"] == "http://proxy.example:1080", call
        invoked = [(c["cmd"], c["args"]) for c in calls]
        assert ("mise", ["run", "lock-tools"]) in invoked
        assert ("mise", ["install", "--locked"]) in invoked
        assert ("pixi", ["global", "update"]) in invoked
        assert ("dotfiles-fetch", ["update"]) in invoked
        assert ("sheldon", ["--non-interactive", "lock", "--update"]) in invoked
        assert ("dotfiles", ["doctor"]) in invoked


if __name__ == "__main__":
    test_parse_only()
    test_version_helpers()
    test_format_and_resolve()
    test_rewriters()
    test_end_to_end_preserves_proxy_env()
    print("ok       dotfiles upgrade: version logic, rewriting, gitleaks sync, and proxy env inheritance pass")
