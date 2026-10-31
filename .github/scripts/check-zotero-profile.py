#!/usr/bin/env python3
"""Check Zotero profile setup without changing the real profile."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
from zipfile import ZipFile

root = Path(__file__).resolve().parents[2]
chezmoi = shutil.which("chezmoi")
bash = shutil.which("bash")
assert chezmoi and bash, "chezmoi and bash are required"
template = root / ".chezmoiscripts/run_after_96-zotero-profile.sh.tmpl"
catalog = tomllib.loads((root / ".chezmoidata/downloads.toml").read_text())
version = catalog["downloads"]["better-bibtex"]["tag"].removeprefix("v")
plugin_id = "better-bibtex@iris-advies.com"


def make_plugin(path, ver):
    path.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(path, "w") as package:
        package.writestr("manifest.json", json.dumps({
            "version": ver, "applications": {"zotero": {"id": plugin_id}},
        }))


with tempfile.TemporaryDirectory(prefix="zotero-profile-") as directory:
    home = Path(directory)
    config = home / "chezmoi.toml"
    script = home / "setup.sh"

    def render(machine):
        config.write_text(f'[data]\nmachine = "{machine}"\ntheme = "rose-pine"\n')
        script.write_text(subprocess.check_output([
            chezmoi, "--source", str(root), "--config", str(config),
            "execute-template", "--file", str(template),
        ], text=True))

    def setup():
        return subprocess.run([bash, str(script)], env=dict(os.environ, HOME=str(home)),
                              check=True, text=True, capture_output=True)

    render("laptop")
    assert "profile unavailable" in setup().stderr
    shared = home / ".config/dotfiles/zotero-user.js"
    shared.parent.mkdir(parents=True)
    shared.write_text('// fixture\n')
    zotero = home / ".zotero/zotero"
    profile = zotero / "random.default"
    profile.mkdir(parents=True)
    ini = zotero / "profiles.ini"
    ini.write_text('[Profile0]\nName=default\nIsRelative=1\nPath=random.default\nDefault=1\n')
    link = profile / "user.js"
    result = setup()
    assert "linked" in result.stdout and "package missing" in result.stderr
    assert link.is_symlink() and link.resolve() == shared
    assert not setup().stdout  # A repeated apply is a no-op.

    # Neither a user file nor another link may be replaced.
    link.unlink()
    link.write_text('// user settings\n')
    assert "already exists" in setup().stderr
    assert link.read_text() == '// user settings\n' and not link.is_symlink()
    link.unlink()
    link.symlink_to(profile / "missing")
    assert "already exists" in setup().stderr and link.is_symlink()
    assert os.readlink(link) == str(profile / "missing")
    link.unlink()

    # An ambiguous profile is not modified.
    ini.write_text('[Profile0]\nPath=random.default\n[Profile1]\nPath=other.default\n')
    assert "cannot identify the default profile" in setup().stderr
    assert not link.exists() and not link.is_symlink()

    # A machine without the research bundle does not modify the profile.
    ini.write_text('[Profile0]\nPath=random.default\n')
    render("container")
    setup()
    assert not link.exists() and not link.is_symlink()
    render("laptop")

    plugin = home / ".local/opt/dotfiles/better-bibtex/current/better-bibtex.xpi"
    target = profile / "extensions" / f"{plugin_id}.xpi"
    make_plugin(plugin, version)
    with (profile / ".parentlock").open("w") as lock:
        fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        assert "close Zotero" in setup().stderr
        assert not target.exists()
    assert "installed Better BibTeX" in setup().stdout
    assert target.read_bytes() == plugin.read_bytes()
    assert "installed Better BibTeX" not in setup().stdout

    # A valid older plugin is saved before replacement. A newer one is never downgraded.
    make_plugin(target, "1.0.0")
    old = target.read_bytes()
    backup = home / ".local/state/dotfiles/zotero-plugins" / f"{hashlib.sha256(old).hexdigest()}.xpi"
    assert "installed Better BibTeX" in setup().stdout
    assert backup.read_bytes() == old and target.read_bytes() == plugin.read_bytes()
    make_plugin(target, "9999.0.0")
    newer = target.read_bytes()
    assert "downgrade skipped" in setup().stderr and target.read_bytes() == newer

    # An unmanaged plugin link and an invalid package are left unchanged.
    target.unlink()
    target.symlink_to(profile / "outside.xpi")
    assert "is a symlink" in setup().stderr and target.is_symlink()
    target.unlink()
    target.write_bytes(b"not a zip file")
    assert "installation skipped" in setup().stderr
    assert target.read_bytes() == b"not a zip file"

    # Zotero needs a one-time enable and per-plugin auto-update setting.
    target.write_bytes(plugin.read_bytes())
    state = profile / "extensions.json"
    state.write_text(json.dumps({"addons": [{"id": plugin_id, "active": False,
                                             "applyBackgroundUpdates": 1}]}))
    result = setup()
    assert "enable Better BibTeX" in result.stderr
    assert "automatic updates to Off" in result.stderr
    state.write_text(json.dumps({"addons": [{"id": plugin_id, "active": True,
                                             "applyBackgroundUpdates": 0}]}))
    assert not setup().stderr

print("ok       Zotero profile: linking, locked installs, backup, no downgrade and addon status")
