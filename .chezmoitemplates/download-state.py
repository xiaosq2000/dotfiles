"""Back up adopted paths and record ownership after a successful apply.

chezmoi owns downloading, extraction and removal. This helper only records which
existing paths were adopted, so a machine that never selected a resource cannot
accidentally lose a manual installation when that resource is deselected.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile


def run(phase, plan):
    home = Path(plan["home"])
    state = home / ".local/state/dotfiles"
    records = state / "downloads"
    for name, spec in sorted(plan["resources"].items()):
        record = records / (name + ".json")
        if phase == "before":
            if record.exists():
                continue
            backup = state / "backups" / name
            if backup.exists():
                continue
            existing = [p for p in spec["targets"] if os.path.lexists(home / p)]
            if not existing:
                continue
            backup.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
            stage = Path(tempfile.mkdtemp(prefix=name + "-", dir=backup.parent))
            try:
                for relative in existing:
                    source, dest = home / relative, stage / relative
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    if source.is_symlink():
                        dest.symlink_to(os.readlink(source))
                    elif source.is_dir():
                        shutil.copytree(source, dest, symlinks=True)
                    else:
                        shutil.copy2(source, dest)
                (stage / "paths.json").write_text(json.dumps(existing, indent=2) + "\n")
                stage.rename(backup)
            except BaseException:
                shutil.rmtree(stage)
                raise
            print(f"downloads: backed up {name} to {backup}", flush=True)
        else:
            for relative in spec["targets"]:
                path = home / relative
                if not path.exists():
                    raise RuntimeError(f"{name}: expected installed path {path}")
                if spec["kind"] == "font" and path.is_dir():
                    if not any(p.suffix.lower() in {".ttf", ".otf"} for p in path.rglob("*")):
                        raise RuntimeError(f"{name}: archive contained no selected font files")
            records.mkdir(parents=True, exist_ok=True, mode=0o700)
            content = json.dumps(spec, sort_keys=True, indent=2) + "\n"
            if not record.exists() or record.read_text() != content:
                temporary = record.with_suffix(".tmp")
                temporary.write_text(content)
                temporary.replace(record)
    if phase == "after":
        for wanted, binary, target in [
            (plan["fonts"], "fc-cache", ".local/share/fonts"),
            (plan["apps"], "update-desktop-database", ".local/share/applications"),
        ]:
            if not wanted:
                continue
            executable = shutil.which(binary)
            if not executable:
                print(f"downloads: warning: {binary} is unavailable; skipping cache refresh")
            elif (home / target).exists():
                result = subprocess.run([executable, str(home / target)], check=False)
                if result.returncode:
                    print(f"downloads: warning: {binary} failed; retry it after fixing the reported error")
