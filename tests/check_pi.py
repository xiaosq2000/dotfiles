#!/usr/bin/env python3
"""Check Pi settings preservation and unpinned package installation without network access."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[1]
BASELINE = tomllib.loads((ROOT / ".chezmoidata/agents.toml").read_text())["agents"]["pi"]
WANTED = {name: f"npm:{name}" for name in BASELINE["packages"]}

with tempfile.TemporaryDirectory(prefix="dotfiles-pi-") as temporary:
    base = Path(temporary)
    home = base / "home"
    home.mkdir()
    config = base / "chezmoi.toml"
    config.write_text('[data]\nmachine = "workstation"\ntheme = "rose-pine"\n')
    environment = {**os.environ, "HOME": str(home)}
    command = ["chezmoi", "--source", str(ROOT), "--destination", str(home),
               "--config", str(config), "--persistent-state", str(base / "state.boltdb")]

    def render(path):
        return subprocess.check_output(command + ["execute-template", "--file", str(ROOT / path)],
                                       env=environment, text=True)

    modify = render("private_dot_pi/private_agent/modify_private_settings.json.tmpl")
    installer = render(".chezmoiscripts/run_after_95-pi-packages.sh.tmpl")

    def merge(raw):
        return subprocess.run(["sh", "-c", modify], input=raw, env=environment,
                              text=True, capture_output=True, check=True)

    name = next(iter(WANTED))
    local = {"source": "npm:local-only", "extensions": []}
    fixture = {
        "deviceId": "local-device", "theme": "local-theme", "custom": {"keep": True},
        "packages": [local, f"npm:{name}", f"npm:{name}@old",
                     {"source": f"npm:{name}@other", "extensions": []}, f"npm:{name}-extra"],
    }
    first = merge(json.dumps(fixture)).stdout
    parsed = json.loads(first)
    assert all(parsed[key] == value for key, value in BASELINE["settings"].items())
    assert {key: parsed[key] for key in ("deviceId", "theme", "custom")} == {
        key: fixture[key] for key in ("deviceId", "theme", "custom")}
    assert parsed["packages"] == [local, WANTED[name], f"npm:{name}-extra"] + [
        source for other, source in WANTED.items() if other != name]
    assert merge(first).stdout == first
    compact = json.dumps(parsed, separators=(",", ":"))
    assert merge(compact).stdout == compact
    assert set(json.loads(merge("").stdout)["packages"]) == set(WANTED.values())
    for raw in ("invalid JSON\n", "[]\n", '{"packages":null}\n'):
        result = merge(raw)
        assert result.stdout == raw and "unchanged" in result.stderr

    # Custom npmCommand is preserved untouched.
    custom_out = json.loads(merge(json.dumps({"npmCommand": ["pnpm"]})).stdout)
    assert custom_out["npmCommand"] == ["pnpm"]

    target = home / ".pi/agent/settings.json"
    target.parent.mkdir(parents=True)
    target.write_text(first)
    managed_pi = home / ".local/share/mise/shims/pi"
    managed_pi.parent.mkdir(parents=True)
    managed_pi.write_text('''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

with Path(os.environ["PI_TEST_LOG"]).open("a") as log:
    log.write(json.dumps({"args": sys.argv[1:], "http_proxy": os.environ.get("http_proxy")}) + "\\n")
if os.environ.get("PI_TEST_FAIL"):
    sys.exit(1)
assert sys.argv[1] == "install"
pkg = sys.argv[2].removeprefix("npm:")
manifest = Path.home() / ".pi/agent/npm/node_modules" / pkg / "package.json"
manifest.parent.mkdir(parents=True, exist_ok=True)
manifest.write_text(json.dumps({"name": pkg, "version": "1.0.0"}))
''')
    managed_pi.chmod(0o755)
    log = base / "calls.jsonl"
    stubs = base / "bin"
    stubs.mkdir()
    for tool in ("node", "npm", "pi"):
        stub = stubs / tool
        stub.write_text("#!/bin/sh\nexit 99\n")
        stub.chmod(0o755)
    environment.update({"PATH": str(stubs) + os.pathsep + os.environ["PATH"],
                        "PI_TEST_LOG": str(log), "http_proxy": "http://proxy.example:8080"})

    def install(**extra):
        return subprocess.run(["bash", "-c", installer], env={**environment, **extra},
                              text=True, capture_output=True, check=True)

    def calls():
        return [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []

    install()
    assert {call["args"][1] for call in calls()} == set(WANTED.values())
    assert all(call["args"][0] == "install" and call["http_proxy"] == "http://proxy.example:8080" for call in calls())
    count = len(calls())
    install()
    assert len(calls()) == count
    assert target.read_text() == first

    # Upgraded local versions are left untouched; missing manifests are installed and retry on failure.
    manifest = home / ".pi/agent/npm/node_modules" / name / "package.json"
    manifest.write_text(json.dumps({"name": name, "version": "9.9.9"}))
    install()
    assert len(calls()) == count

    manifest.unlink()
    install(PI_TEST_FAIL="1")
    install(PI_TEST_FAIL="1")
    assert len(calls()) == count + 2
    install()
    assert calls()[-1]["args"] == ["install", WANTED[name]]
    assert json.loads(manifest.read_text())["name"] == name

    # Invalid settings must not trigger an installation or stop apply.
    target.write_text("invalid JSON\n")
    count = len(calls())
    install()
    assert len(calls()) == count
    target.write_text(first)
    managed_pi.rename(managed_pi.with_name("pi-disabled"))
    manifest.unlink()
    install()
    assert len(calls()) == count

    # Bundle gating must not install packages in a container profile.
    config.write_text('[data]\nmachine = "container"\ntheme = "rose-pine"\n')
    installer = render(".chezmoiscripts/run_after_95-pi-packages.sh.tmpl")
    install()
    assert len(calls()) == count

print("Pi settings preservation, duplicate removal, unpinned package install and env inheritance pass.")
