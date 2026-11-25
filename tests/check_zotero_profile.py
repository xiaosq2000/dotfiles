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
from zipfile import ZipFile

root = Path(__file__).resolve().parents[1]
chezmoi = shutil.which("chezmoi")
bash = shutil.which("bash")
assert chezmoi and bash, "chezmoi and bash are required"
template = root / ".chezmoiscripts/run_onchange_after_96-zotero-profile.sh.tmpl"
bbt_version = "9.0.71"
bbt_id = "better-bibtex@iris-advies.com"
extra_version = "0.1.7"
extra_id = "extra-meta@dotfiles.local"
arxiv_version = "0.4.2"
arxiv_id = "arxiv@allanchain.github.com"


def make_plugin(path, plugin_id, ver):
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
            chezmoi, "--source", str(root), "--destination", str(home), "--config", str(config),
            "execute-template", "--file", str(template),
        ], env=dict(os.environ, HOME=str(home)), text=True))

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
    assert "linked" in result.stdout
    assert "Better BibTeX package missing" in result.stderr
    assert "Extra Meta package missing" in result.stderr
    assert "arXiv Workflow package missing" in result.stderr
    assert link.is_symlink() and link.resolve() == shared
    assert not setup().stdout  # Repeated apply is a no-op for user.js.

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

    # A machine without the research bundle renders empty and does not touch the profile.
    ini.write_text('[Profile0]\nPath=random.default\n')
    render("container")
    assert script.read_text() == ""
    setup()
    assert not link.exists() and not link.is_symlink()
    render("laptop")

    bbt_pkg = home / ".local/opt/dotfiles/better-bibtex/current/better-bibtex.xpi"
    extra_pkg = home / ".local/opt/dotfiles/extra-meta/current/extra-meta.xpi"
    arxiv_pkg = home / ".local/opt/dotfiles/arxiv-workflow/current/arxiv-workflow.xpi"
    bbt_target = profile / "extensions" / f"{bbt_id}.xpi"
    extra_target = profile / "extensions" / f"{extra_id}.xpi"
    arxiv_target = profile / "extensions" / f"{arxiv_id}.xpi"
    make_plugin(bbt_pkg, bbt_id, bbt_version)
    make_plugin(extra_pkg, extra_id, extra_version)
    make_plugin(arxiv_pkg, arxiv_id, arxiv_version)

    with (profile / ".parentlock").open("w") as lock:
        fcntl.lockf(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        locked = setup()
        assert "close Zotero" in locked.stderr
        assert not bbt_target.exists() and not extra_target.exists() and not arxiv_target.exists()

    installed = setup()
    assert "installed Better BibTeX" in installed.stdout
    assert "installed Extra Meta" in installed.stdout
    assert "installed arXiv Workflow" in installed.stdout
    assert bbt_target.read_bytes() == bbt_pkg.read_bytes()
    assert extra_target.read_bytes() == extra_pkg.read_bytes()
    assert arxiv_target.read_bytes() == arxiv_pkg.read_bytes()
    assert (extra_target.stat().st_mode & 0o777) == 0o644
    assert (arxiv_target.stat().st_mode & 0o777) == 0o644
    assert not setup().stdout

    # A valid older plugin is saved before replacement. A newer one is never downgraded.
    make_plugin(bbt_target, bbt_id, "1.0.0")
    old = bbt_target.read_bytes()
    backup = home / ".local/state/dotfiles/zotero-plugins" / f"{hashlib.sha256(old).hexdigest()}.xpi"
    assert "installed Better BibTeX" in setup().stdout
    assert backup.read_bytes() == old and bbt_target.read_bytes() == bbt_pkg.read_bytes()
    make_plugin(bbt_target, bbt_id, "9999.0.0")
    newer = bbt_target.read_bytes()
    assert "downgrade skipped" in setup().stderr and bbt_target.read_bytes() == newer

    # An unmanaged plugin link and an invalid package are left unchanged.
    bbt_target.unlink()
    bbt_target.symlink_to(profile / "outside.xpi")
    assert "is a symlink" in setup().stderr and bbt_target.is_symlink()
    bbt_target.unlink()
    bbt_target.write_bytes(b"not a zip file")
    assert "installation skipped" in setup().stderr
    assert bbt_target.read_bytes() == b"not a zip file"

    # Zotero needs a one-time enable and per-plugin auto-update setting for BBT and arXiv Workflow.
    bbt_target.write_bytes(bbt_pkg.read_bytes())
    state = profile / "extensions.json"
    state.write_text(json.dumps({"addons": [{"id": bbt_id, "active": False,
                                             "applyBackgroundUpdates": 1}]}))
    result = setup()
    assert "enable Better BibTeX" in result.stderr
    assert "automatic updates to Off" in result.stderr
    state.write_text(json.dumps({"addons": [
        {"id": bbt_id, "active": True, "applyBackgroundUpdates": 0},
        {"id": extra_id, "active": False, "applyBackgroundUpdates": 1},
    ]}))
    result = setup()
    assert "enable Extra Meta" in result.stderr
    assert "automatic updates to Off" not in result.stderr
    state.write_text(json.dumps({"addons": [
        {"id": bbt_id, "active": True, "applyBackgroundUpdates": 0},
        {"id": extra_id, "active": True, "applyBackgroundUpdates": 1},
        {"id": arxiv_id, "active": False, "applyBackgroundUpdates": 1},
    ]}))
    result = setup()
    assert "enable arXiv Workflow" in result.stderr
    assert "automatic updates to Off" in result.stderr
    state.write_text(json.dumps({"addons": [
        {"id": bbt_id, "active": True, "applyBackgroundUpdates": 0},
        {"id": extra_id, "active": True, "applyBackgroundUpdates": 1},
        {"id": arxiv_id, "active": True, "applyBackgroundUpdates": 0},
    ]}))
    assert not setup().stderr

    # Template hash tracks only Zotero plugin entries in downloads.lock.json,
    # so updating unrelated downloads (like kitty) does not mark the script pending.
    lock_file = home / ".local/state/dotfiles/downloads.lock.json"
    lock_file.parent.mkdir(parents=True, exist_ok=True)
    lock_data = {
        "resources": {
            "kitty": {"sha256": "kitty-v1"},
            "better-bibtex": {"sha256": "bbt-v1"},
            "extra-meta": {"sha256": "extra-v1"},
            "arxiv-workflow": {"sha256": "arxiv-v1"},
        }
    }
    lock_file.write_text(json.dumps(lock_data))
    render("laptop")
    rendered_v1 = script.read_text()
    assert "# better-bibtex lock: bbt-v1" in rendered_v1
    assert "# extra-meta lock: extra-v1" in rendered_v1
    assert "# arxiv-workflow lock: arxiv-v1" in rendered_v1

    lock_data["resources"]["kitty"]["sha256"] = "kitty-v2"
    lock_file.write_text(json.dumps(lock_data))
    render("laptop")
    assert script.read_text() == rendered_v1

    lock_data["resources"]["better-bibtex"]["sha256"] = "bbt-v2"
    lock_file.write_text(json.dumps(lock_data))
    render("laptop")
    assert "# better-bibtex lock: bbt-v2" in script.read_text()
    assert script.read_text() != rendered_v1

print("ok       Zotero profile: linking, locked installs, backup, no downgrade and addon status")
